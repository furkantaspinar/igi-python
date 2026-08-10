"""
BESCHAEFTIGTE 06_Selbständige_Mithfam PAGS2025
Migriert aus: 06_Selbständige_Mithfam.sas

Selbständige insgesamt (einschl. mithelfende Familienangehörige)

Benötigte Input Variablen:
- Beschäftigtenanzahl von Bedirect (früher Quadress, davor Bisnode)
- Neu in PAGS25: Selbständige auf Kreisebene vom Amt inkl. mithelf.
  Angehörige --> keine Unterscheidung mehr zwischen Selbstständigen und
  deren mithelf. Angehörigen (ot_mithfam entfällt)

Vorgehen:
Die Anzahl der Selbständigen vom Amt auf Kreisebene wird über je
Wirtschaftszweig verteilt und anschließend auf Ortsteil aggregiert. Die
Zahl gibt somit die Selbständigen am Arbeitsort an (inklusive mithelfenden
Familienangehörigen). (Quelle: DIW, destatis)

Nicht übersetzt: die proc freq/means-Diagnoseblöcke (Imputationscheck,
kleinst-Verteilung, Prüfung, finale Summenkontrolle) - ohne Einfluss auf
die Zieltabellen. Ebenso nicht eingelesen: mitarbeiter_staffel:/
br_abt_hptcode/ags8, die im SAS-Keep stehen, aber nur für diese
Diagnoseblöcke gebraucht werden. Der S5-Dedup (proc sort/by last.ags20)
entfällt, weil S4 durch "group by ags20" bereits eindeutig ist.
"""

from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import text  # noqa: F401

from igi_base import get_engine, get_logger, load_environment
from igi_base.sas import sas_round, sas_sum


def main() -> None:
    load_environment(Path(__file__).parent / ".env")
    logger = get_logger(__name__)

    engine = get_engine("i360prod-sos_scheduler_user", env_var="PROD_DB")
    engine_roh = get_engine(
        "i360processing-sos_scheduler_user", env_var="PROCESSING_DB"
    )

    # Tabellen ins Work ziehen
    # Kreisdaten (leider noch von 2022)
    kreis = pd.read_sql_table(
        table_name="kr_selbst_2022", con=engine_roh, schema="roh_genesis"
    )

    # Firmendaten
    firmen = pd.read_sql_table(
        table_name="bedirect_vie_20250409",
        con=engine,
        schema="bedirect",
        columns=[
            "ags27",
            "ags20",
            "ags11",
            "ags5",
            "mitarbeiter_real",
            "br_absch_hptcode",
        ],
    )

    # Beschäftigte im Dienstleistungssektor
    s1 = firmen
    # Einordnung in Wirtschaftszweige
    bedingungen = [
        s1["br_absch_hptcode"] == 1,  # (A) Land-, Forstwirtschaft und Fischerei
        s1["br_absch_hptcode"].isin(
            [2, 4, 5]
        ),  # (B-E ohne C) Produzierendes Gewerbe ohne Baugewerbe
        s1["br_absch_hptcode"] == 3,  # (C) Verarbeitendes Gewerbe
        s1["br_absch_hptcode"] == 6,  # (F) Baugewerbe
        s1["br_absch_hptcode"].isin(
            [7, 8, 9, 10]
        ),  # Handel, Verkehr, Gastgewerbe, Information/Kommunikation
        s1["br_absch_hptcode"].isin(
            [11, 12, 13, 14]
        ),  # Finanz-, Versicherungs-, Unternehmensdienstl., Grundstücke
        s1["br_absch_hptcode"].isin(
            [15, 16, 17, 18, 19, 20, 21]
        ),  # Öffentliche/sonstige Dienstl., Erziehung, Gesundheit
    ]
    branchen_codes = [1, 2, 3, 4, 5, 6, 7]
    s1["br_code"] = np.select(bedingungen, branchen_codes, default=np.nan)

    # Durchschnittliche Anzahl Mitarbeiter nach Branche und SB
    s2 = s1
    mitarbeiter_gerundet = sas_round(s2["mitarbeiter_real"])
    s2["ma_br"] = mitarbeiter_gerundet.groupby(
        [s2["ags20"], s2["br_code"]], dropna=False
    ).transform("mean")

    # Anpassungen
    s3 = s2
    # Beschäftigten-Zahl
    s3["besch"] = s3["mitarbeiter_real"]
    # Missings mit Durchschnittswerten ersetzen
    fehlt_mit_durchschnitt = s3["mitarbeiter_real"].isna() & s3["ma_br"].notna()
    s3.loc[fehlt_mit_durchschnitt, "besch"] = sas_round(
        s3.loc[fehlt_mit_durchschnitt, "ma_br"]
    )
    s3 = s3[s3["ags27"].fillna("") != ""]

    # Gesamtanzahl je Kreis und Branche
    for n in range(1, 8):
        s3[f"besch_br{n}"] = np.where(s3["br_code"] == n, s3["besch"], 0)

    s4 = s3.groupby("ags20", as_index=False).agg(
        ags11=("ags11", "first"),
        ags5=("ags5", "first"),
        br1_anz=("besch_br1", "sum"),
        br2_anz=("besch_br2", "sum"),
        br3_anz=("besch_br3", "sum"),
        br4_anz=("besch_br4", "sum"),
        br5_anz=("besch_br5", "sum"),
        br6_anz=("besch_br6", "sum"),
        br7_anz=("besch_br7", "sum"),
        ags20_besch=("besch", "sum"),
    )

    # Kreisdaten anspielen
    s6 = s4.merge(kreis, on="ags5", how="left")

    # Aggregieren auf Kreisebene
    s7 = s6
    for n in range(1, 8):
        s7[f"br{n}_kr"] = s7.groupby("ags5")[f"br{n}_anz"].transform("sum")
    s7["ags5_besch"] = s7.groupby("ags5")["ags20_besch"].transform("sum")

    # Eichen an Kreisdaten
    s8 = s7
    for n in range(1, 8):
        br_kr_sicher = s8[f"br{n}_kr"].replace(0, np.nan)
        s8[f"br{n}_geeicht"] = sas_round(
            s8[f"br{n}_anz"] / br_kr_sicher * s8[f"kr_selbst_br{n}"]
        )

    geeicht_spalten = [f"br{n}_geeicht" for n in range(1, 8)]
    s8["sb_selbst"] = sas_sum(s8, geeicht_spalten)

    # Prüfung zeigt: nach der Eichung pro Branche stimmt die Kreissumme
    # nicht exakt mit der amtlichen Zahl überein - daher wird die Differenz
    # nochmal verteilt (zwei Runden).

    # Differenz nochmal verteilen
    p1 = s8[["ags5", "ags11", "ags20", "sb_selbst", "kr_selbst"]].copy()
    p1["ags5_selbst"] = p1.groupby("ags5")["sb_selbst"].transform("sum")

    p2 = p1
    p2["delta"] = p2["kr_selbst"] - p2["ags5_selbst"]
    ags5_selbst_sicher = p2["ags5_selbst"].replace(0, np.nan)
    p2["sb_selbst_2"] = p2["sb_selbst"] / ags5_selbst_sicher * p2["delta"]
    p2.loc[p2["ags5_selbst"] == 0, "sb_selbst_2"] = 0
    p2["sb_selbst_neu"] = sas_round(sas_sum(p2, ["sb_selbst", "sb_selbst_2"]))

    # Zweite Runde: Differenz nochmal verteilen
    p3 = p2[["ags5", "ags11", "ags20", "sb_selbst_neu", "kr_selbst"]].copy()
    p3["ags5_selbst"] = p3.groupby("ags5")["sb_selbst_neu"].transform("sum")

    p4 = p3
    p4["delta"] = p4["kr_selbst"] - p4["ags5_selbst"]
    ags5_selbst_sicher2 = p4["ags5_selbst"].replace(0, np.nan)
    p4["sb_selbst_2"] = p4["sb_selbst_neu"] / ags5_selbst_sicher2 * p4["delta"]
    p4.loc[p4["ags5_selbst"] == 0, "sb_selbst_2"] = 0
    p4["sb_selbst"] = sas_round(sas_sum(p4, ["sb_selbst_neu", "sb_selbst_2"]))
    logger.info(
        "Selbständige verteilt: %d Zeilen, Summe=%.0f", len(p4), p4["sb_selbst"].sum()
    )

    # Abspeichern in Ordner

    # Auf SB - SAS speichert hier sb_selbst_neu (nur die erste
    # Verteilungsrunde), nicht das doppelt nachverteilte sb_selbst; so im
    # Original, hier bewusst genauso übernommen.
    sb_selbst = p4[p4["ags20"].fillna("") != ""][["ags20", "sb_selbst_neu"]]  # noqa: F841 (für auskommentierten to_sql-Write unten)

    # Auf OT
    # ot_selbst = (
    #     p4[p4["ags11"].fillna("") != ""]
    #     .groupby("ags11", as_index=False)["sb_selbst"]
    #     .sum()
    #     .rename(columns={"sb_selbst": "ot_selbst"})
    # )

    # Validierung gegen SAS-Referenz (vor dem Push):
    # validate(
    #     df_py=ot_selbst,
    #     ref_path=Path(__file__).parent / "sas/datensatz/ot_selbst.sas7bdat",
    #     pk="ags11",
    #     cols=["ot_selbst"],
    #     tolerance=1,
    # )

    # sb_selbst.to_sql(
    #     name="sb_selbst",
    #     con=engine,
    #     schema="SCHEMA",
    #     if_exists="replace",
    #     index=False,
    # )
    # ot_selbst.to_sql(
    #     name="ot_selbst",
    #     con=engine,
    #     schema="SCHEMA",
    #     if_exists="replace",
    #     index=False,
    # )
    # logger.info("Gespeichert: SB=%d Zeilen, OT=%d Zeilen", len(sb_selbst), len(ot_selbst))

    engine.dispose()
    engine_roh.dispose()


if __name__ == "__main__":
    main()
