"""
SOZIALESCHICHT SozialeSchicht25 PAGS2025
Migriert aus: SozialeSchicht25.sas
Bearbeiterin:
AnW 26. April 2024
BEN 27.05.2025

Berechnet CASA_SOZ_SCH (soziale Schicht je AGS27) auf Basis des
Wohnungspreises (CASA_WH_PREIS): daraus wird eine kalkulatorische
Nettobelastung (BEL_K) und ein daraus abgeleitetes Monatseinkommen
(MON_EINK) bestimmt, das anhand fester Schwellenwerte in 5 Schichten
eingeteilt wird.

Ausprägungen CASA_SOZ_SCH:
-99=k.A.
1=Oberschicht
2=obere Mittelschicht
3=Mittelschicht
4=untere Mittelschicht
5=Unterschicht

Nicht übersetzt: proc sort by ags5 (in pandas für groupby nicht nötig);
p50 aus proc means (wird berechnet, aber nie weiterverwendet); JAHR_EINK
(wird berechnet, aber nirgends weiterverwendet); PROC means data=GES4 p10
p40 p60 p90 (reines Diagnose-Log, die abgelesenen Werte sind unten als
Konstanten übernommen); der Vergleich mit soz_sch_24 (proc freq) sowie der
abschließende "Kurze Prüfung"-Block (tst-Tabelle) - reine Diagnose des
SAS-Entwicklers ohne Einfluss auf die Zieltabelle.
"""

from pathlib import Path

import pandas as pd
from sqlalchemy import text  # noqa: F401

from igi_base import get_engine, get_logger, load_environment, validate
from igi_base.sas import sas_round


def main() -> None:
    load_environment(Path(__file__).parent / ".env")
    logger = get_logger(__name__)

    engine = get_engine(env_var="PROD_DB")

    # proc sql; create table wh_preis as select a.ags27, b.wh_preis
    # from ags27 a left join z_ags27_ben_0522_wh_preis b on a.ags27=b.ags27;
    ags27 = pd.read_sql_table(
        table_name="ags27", con=engine, schema="variablen2025", columns=["ags27"]
    )
    wh_preis_tabelle = pd.read_sql_table(
        table_name="z_ags27_ben_0522_wh_preis",
        con=engine,
        schema="sas_dbupdate",
        columns=["ags27", "casa_wh_preis"],
    ).rename(columns={"casa_wh_preis": "wh_preis"})

    wh_preis = ags27.merge(wh_preis_tabelle, on="ags27", how="left")

    # data GES; set wh_preis;
    # BEL_K=round(WH_PREIS*5.5/1200,1);
    # AGS5=substr(AGS27,1,5);
    ges = wh_preis.copy()
    ges["bel_k"] = sas_round(ges["wh_preis"] * 5.5 / 1200, ndigits=1)
    ges["ags5"] = ges["ags27"].str[:5]
    logger.info("GES erstellt: %d Zeilen", len(ges))
    # /*23.503.292*/

    # *Schichten nach Perzentilen einteilen;;
    # PROC means data=GES noprint; output p25=p25 p75=p75 out=GES2; var BEL_K; by AGS5;
    p25_je_ags5 = ges.groupby("ags5")["bel_k"].quantile(0.25).reset_index()
    p25_je_ags5 = p25_je_ags5.rename(columns={"bel_k": "p25"})

    p75_je_ags5 = ges.groupby("ags5")["bel_k"].quantile(0.75).reset_index()
    p75_je_ags5 = p75_je_ags5.rename(columns={"bel_k": "p75"})

    ges2 = p25_je_ags5.merge(p75_je_ags5, on="ags5")

    # PROC SQL; create table GES3 as select a.*, b.* from GES a left join GES2 b on a.AGS5=b.AGS5;
    ges3 = ges.merge(ges2, on="ags5", how="left")

    # DATA GES4; set GES3;
    # if BEL_K le p25 then MON_EINK=BEL_K*3;
    # if BEL_K gt p25 and BEL_K le p75 then MON_EINK=BEL_K*4;
    # if BEL_K gt p75 then MON_EINK=BEL_K*5;
    # JAHR_EINK=MON_EINK*12;
    ges4 = ges3.copy()
    ges4["mon_eink"] = float("nan")

    ist_bis_p25 = ges4["bel_k"] <= ges4["p25"]
    ist_p25_bis_p75 = (ges4["bel_k"] > ges4["p25"]) & (ges4["bel_k"] <= ges4["p75"])
    ist_ueber_p75 = ges4["bel_k"] > ges4["p75"]

    ges4.loc[ist_bis_p25, "mon_eink"] = ges4["bel_k"] * 3
    ges4.loc[ist_p25_bis_p75, "mon_eink"] = ges4["bel_k"] * 4
    ges4.loc[ist_ueber_p75, "mon_eink"] = ges4["bel_k"] * 5
    logger.info("GES4 erstellt: %d Zeilen", len(ges4))

    # ******************;;
    # DATA GES5; set GES4;
    # CASA_SOZ_SCH=-99;
    # if MON_EINK ne . then do;
    # if MON_EINK le 2364 then CASA_SOZ_SCH=5; *p10;
    # if 2364 <MON_EINK <= 5132 then CASA_SOZ_SCH=4; *p10-p40;
    # if 5132  <MON_EINK <= 7280 then CASA_SOZ_SCH=3;*p40-p60;
    # if 7280 <MON_EINK <= 13630 then CASA_SOZ_SCH=2;*p60-p90;
    # if 13630 <MON_EINK  then CASA_SOZ_SCH=1;*p90;
    # end;
    ges5 = ges4.copy()
    ges5["casa_soz_sch"] = -99

    # Hinweis: bei fehlendem MON_EINK (NaN) sind alle Vergleiche unten
    # automatisch False, daher bleibt CASA_SOZ_SCH in diesen Zeilen bei -99
    # (entspricht dem "if MON_EINK ne . then do ... end;" in SAS).
    ist_schicht5 = ges5["mon_eink"] <= 2364
    ist_schicht4 = (ges5["mon_eink"] > 2364) & (ges5["mon_eink"] <= 5132)
    ist_schicht3 = (ges5["mon_eink"] > 5132) & (ges5["mon_eink"] <= 7280)
    ist_schicht2 = (ges5["mon_eink"] > 7280) & (ges5["mon_eink"] <= 13630)
    ist_schicht1 = ges5["mon_eink"] > 13630

    ges5.loc[ist_schicht5, "casa_soz_sch"] = 5  # p10
    ges5.loc[ist_schicht4, "casa_soz_sch"] = 4  # p10-p40
    ges5.loc[ist_schicht3, "casa_soz_sch"] = 3  # p40-p60
    ges5.loc[ist_schicht2, "casa_soz_sch"] = 2  # p60-p90
    ges5.loc[ist_schicht1, "casa_soz_sch"] = 1  # p90
    logger.info(
        "Verteilung CASA_SOZ_SCH:\n%s",
        ges5["casa_soz_sch"].value_counts(dropna=False).sort_index(),
    )

    # => etwas mehr missings...

    # *Speichern;;
    # data exp; set GES5 (keep=ags27 casa_soz_sch); run;
    exp = ges5[["ags27", "casa_soz_sch"]]

    # Validierung gegen SAS-Referenz (vor dem Push)
    validate(
        df_py=exp,
        ref_query=(
            "SELECT ags27, casa_soz_sch "
            "FROM sas_dbupdate.z_ags27_ben_0527_soz_schicht"
        ),
        engine=engine,
        pk="ags27",
        cols=["casa_soz_sch"],
        tolerance=0,
    )

    # *In die DB laden;;
    # %sas_to_pg(from=exp, to=z_ags27_ben_0527_soz_schicht, ..., pk=ags27);
    # exp.to_sql(
    #     name="z_ags27_ben_0527_soz_schicht",
    #     con=engine,
    #     schema="sas_dbupdate",
    #     if_exists="replace",
    #     index=False,
    # )
    # with engine.begin() as conn:
    #     conn.execute(
    #         text(
    #             "ALTER TABLE sas_dbupdate.z_ags27_ben_0527_soz_schicht "
    #             "ADD PRIMARY KEY (ags27)"
    #         )
    #     )
    logger.info("Gespeichert: %d Zeilen", len(exp))

    engine.dispose()


if __name__ == "__main__":
    main()
