"""
BESCHAEFTIGTE 10_ERWTPERS_AO PAGS2025
Migriert aus: 10_ERWTPERS_AO.sas

Erwerbstätige am Arbeitsort nach Wirtschaftszweig

Inputdaten: Beschäftigtenzahlen aus den Firmendaten (Bedirect)
Amtliche Zahlen zu ERWERBSTÄTIGEN (NICHT Sozialversicherungspflichtig
Beschäftigte) auf Kreis.

ANMERKUNG (aus dem SAS-Original): Falls keine aktuellen (zum Gebietsstand
passenden) kreisgenauen Zahlen zu Erwerbstätigen vorhanden sind, werden die
Gesamtzahlen stattdessen an aktuelle Bundesland-Zahlen aus der
"Erwerbstätigenrechnung des Bundes und der Länder" geeicht (siehe
https://www.statistikportal.de/de/etr/ergebnisse/erwerbstaetige-personen/erwerbstaetige-jahresdurchschnitt).
2025 waren die Kreisdaten aktuell, daher entfällt dieser Fallback (im
SAS-Original entsprechend auskommentiert, siehe KR_01 oben).

ANMERKUNG aus PAGS24: Durch Kundenrückfragen ist aufgefallen, dass die
Berechnung so wie sie in PAGS23 durchgeführt wurde bei den ERWT_AO gesamt
gut passt, aber bei den ERWT nach Branchen extrem abweicht. Daher wurde
die Berechnung überarbeitet: Eichen an amtlichen Daten nach Branchen auf
Kreisebene, mit Anpassung der Ergebnisvariablen an die Branchengliederung
der amtlichen Daten (Land-/Forstwirtschaft/Fischerei; Produzierendes
Gewerbe ohne Bau-/verarbeitendes Gewerbe; Verarbeitendes Gewerbe;
Baugewerbe; Handel/Verkehr/Gastgewerbe/Information/Kommunikation;
Finanz-/Versicherungs-/Unternehmensdienstleistungen/Grundstücks- und
Wohnungswesen; Öffentliche und sonstige Dienstleistungen/Erziehung/
Gesundheit). Das ist der Grund für die zweistufige Eichung (eich1-eich7)
weiter unten.

Vorgehen:
Als Basis werden OT_BE_AO + OT_SELBST (Sozialversicherungspflichtig
Beschäftigte + Selbständige) genutzt, das reicht aber nicht an die
amtliche ERWT-Zahl auf Kreisebene heran. Die Restdifferenz wird anhand
der (nach Branche imputierten) Mitarbeiterzahlen aus den Firmendaten
verteilt, anschließend zweimal an die amtlichen Kreiszahlen (gesamt und
je Branche) geeicht und zum Schluss gerundet, wobei Rundungsdifferenzen
auf die größte Branche bzw. auf "sonstige" (B99) gepackt werden.

WICHTIG - DB-vermittelte Abhängigkeit: Dieses Skript liest die Outputs von
05_SvB_AO und 06_Selbständige_Mithfam nicht aus deren SAS-Zwischendateien,
sondern aus der bereits nach Postgres geschriebenen Tabelle
variablen2025.ags11_ot_soz (Spalten OT_BE_AO, OT_SELBST). Der Postgres-Push
von 05 und 06 muss also vorher erfolgt sein.

Nicht übersetzt: der einleitende Eichungsblock an Bundeslandzahlen
(KR_01, auskommentiert im Original - 2025 lagen aktuelle Kreiszahlen vor,
daher entfällt das Eichen an BL), alle proc means/freq/univariate/
sgplot/corr-Diagnoseblöcke, die Zwischenkontrollen (CHECK, tst, tst1-tst5,
kr_agg1/2, kr_chk1, ert_00/01, ERT_kr_00, checks_01, match1, chk_alo-
Export) sowie der eich2/eich3/eich3b-Zwischenschritt vor der finalen
Eichung eich4-eich7 - dieser wird in eich4 direkt neu berechnet
(kr_ot_erwt_ao_n etc. aus eich3b fließen nirgends in eich4 ein außer über
die dort erneut aggregierten Werte). Alles ohne Einfluss auf FINAL3/FINAL4.

Auch nicht übersetzt: "data datab_03; set home.datab_03; run;" (SAS-Zeile
311) liest aus einer im SAS-Original nie definierten Library "home" und
würde die frisch berechnete DATAB_03 mit einem undefinierten Fremdwert
überschreiben - vermutlich eine Session-Altlast im SAS-Original, kein
gewollter Schritt.
"""

from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import text  # noqa: F401

from igi_base import get_engine, get_logger, load_environment, validate  # noqa: F401
from igi_base.sas import sas_round, sas_sum

BRANCHEN = range(1, 8)


def main() -> None:
    load_environment(Path(__file__).parent / ".env")
    logger = get_logger(__name__)

    engine = get_engine("i360prod-sos_scheduler_user", env_var="PROD_DB")
    engine_roh = get_engine("i360processing-sos_scheduler_user", env_var="PROCESSING_DB")

    # da noch keine Daten von 2023 veröffentlicht, werden die von 2022 verwendet
    kr = pd.read_sql_table(
        table_name="kr_erwt_br_2022", con=engine_roh, schema="roh_genesis"
    )

    # Hauptbranche 3 ist in der 2 enthalten. Für weitere Rechnungen wird die
    # 3 aus der 2 entfernt (Gesamtzahl bleibt erhalten)
    kr_00 = kr
    kr_00["kr_erwt_br2"] = kr_00["kr_erwt_br2"] - kr_00["kr_erwt_br3"]
    br_spalten = [f"kr_erwt_br{n}" for n in BRANCHEN]
    delta = kr_00["kr_erwt_ges"] - sas_sum(kr_00, br_spalten)
    kr_00["kr_erwt_br3"] = kr_00["kr_erwt_br3"] + delta

    # 2025 lagen aktuelle Kreiszahlen vor, daher entfällt das Eichen an
    # Bundeslandzahlen der "Erwerbstätigenrechnung des Bundes und der Länder"
    # (im SAS-Original als KR_01 auskommentiert)
    kr_02 = kr_00

    # Ortsteildaten
    ot_00 = pd.read_sql_table(
        table_name="ags11_ot_soz",
        con=engine,
        schema="variablen2025",
        columns=["ags11", "ot_be_ao", "ot_selbst"],
    )
    ot_00["ags5"] = ot_00["ags11"].str[:5]
    ot_00["ot_erwt_basis"] = sas_sum(ot_00, ["ot_be_ao", "ot_selbst"]).fillna(0)

    ot_01 = ot_00.drop(columns=["ot_be_ao", "ot_selbst"])
    ot_01["kr_erwt_basis"] = ot_01.groupby("ags5")["ot_erwt_basis"].transform("sum")

    # Firmendaten - PAGS25 = Bedirect
    firm = pd.read_sql_table(
        table_name="bedirect_vie_20250409",
        con=engine,
        schema="bedirect",
        columns=[
            "ags27",
            "ags11",
            "ags5",
            "br_absch_hptcode",
            "mitarbeiter_real",
        ],
    )
    firm = firm[firm["ags27"] != ""]

    # Teilweise missings, sollen später dann über Mittelwerte nach Branche
    # auf OT, GEM, KR aufgefüllt werden
    datab_00a2 = firm
    datab_00a2["mitarbeiter_estm_anp"] = datab_00a2["mitarbeiter_real"]
    datab_00a2 = datab_00a2[datab_00a2["ags11"] != ""]

    # Auffüllen bei fehlenden Mitarbeiterzahlen
    # auf OT
    datab_00b = datab_00a2
    datab_00b["mn_mitarbeiter_estm_anp"] = sas_round(
        datab_00b.groupby(["ags11", "br_absch_hptcode"])[
            "mitarbeiter_estm_anp"
        ].transform("mean")
    )

    # auf Gemeinde
    datab_00c = datab_00b
    datab_00c["ags8"] = datab_00c["ags11"].str[:8]
    datab_00c["mn2_mitarbeiter_estm_anp"] = sas_round(
        datab_00c.groupby(["ags8", "br_absch_hptcode"])[
            "mitarbeiter_estm_anp"
        ].transform("mean")
    )

    # auf Kreis
    datab_00d = datab_00c
    datab_00d["mn3_mitarbeiter_estm_anp"] = sas_round(
        datab_00d.groupby(["ags5", "br_absch_hptcode"])[
            "mitarbeiter_estm_anp"
        ].transform("mean")
    )

    # Insgesamt nach Branche
    datab_00e = datab_00d
    datab_00e["mn4_mitarbeiter_estm_anp"] = sas_round(
        datab_00e.groupby("br_absch_hptcode")["mitarbeiter_estm_anp"].transform("mean")
    )

    # Missings ersetzen mit Mittelwerten (der Reihe nach: OT vor Gemeinde vor
    # Kreis vor Gesamt-Branchenmittel, wie in der SAS-If-Kaskade)
    datab_00f = datab_00e
    datab_00f["mitarbeiter_estm_anp"] = (
        datab_00f["mitarbeiter_estm_anp"]
        .fillna(datab_00f["mn_mitarbeiter_estm_anp"])
        .fillna(datab_00f["mn2_mitarbeiter_estm_anp"])
        .fillna(datab_00f["mn3_mitarbeiter_estm_anp"])
        .fillna(datab_00f["mn4_mitarbeiter_estm_anp"])
    )
    datab_00f = datab_00f.drop(
        columns=[
            "mn_mitarbeiter_estm_anp",
            "mn2_mitarbeiter_estm_anp",
            "mn3_mitarbeiter_estm_anp",
            "mn4_mitarbeiter_estm_anp",
            "ags8",
        ]
    )

    # Einordnung in Wirtschaftszweige
    datab_01 = datab_00f[datab_00f["ags27"] != ""].rename(
        columns={"mitarbeiter_estm_anp": "mitarbeiter_imp"}
    )
    bedingungen = [
        datab_01["br_absch_hptcode"] == 1,  # (A) Land-, Forstwirtschaft und Fischerei
        datab_01["br_absch_hptcode"].isin(
            [2, 4, 5]
        ),  # (B-E ohne C) Prod. Gewerbe ohne Bau-/verarb. Gewerbe
        datab_01["br_absch_hptcode"] == 3,  # (C) Verarbeitendes Gewerbe
        datab_01["br_absch_hptcode"] == 6,  # (F) Baugewerbe
        datab_01["br_absch_hptcode"].isin(
            [7, 8, 9, 10]
        ),  # Handel, Verkehr, Gastgewerbe, Info/Kommunikation
        datab_01["br_absch_hptcode"].isin(
            [11, 12, 13, 14]
        ),  # Finanz-, Versicherungs-, Unternehmensdienstl.
        datab_01["br_absch_hptcode"].isin(
            [15, 16, 17, 18, 19, 20, 21]
        ),  # Öffentl./sonst. Dienstl., Erziehung
    ]
    for n, bedingung in zip(BRANCHEN, bedingungen):
        datab_01[f"casa_anz_firm_b{n}"] = np.where(bedingung, 1, np.nan)
    datab_01["casa_anz_firm_b99"] = np.where(
        datab_01["br_absch_hptcode"].isna(), 1, np.nan
    )

    # Mitarbeiter auf AGS5 und AGS11 aggregieren
    for n in BRANCHEN:
        datab_01[f"_ma_b{n}"] = np.where(
            datab_01[f"casa_anz_firm_b{n}"] == 1, datab_01["mitarbeiter_imp"], 0
        )
    datab_01["_ma_b99"] = np.where(
        datab_01["casa_anz_firm_b99"] == 1, datab_01["mitarbeiter_imp"], 0
    )

    datab_02 = datab_01.groupby("ags11", as_index=False).agg(
        ags5=("ags5", "min"),
        **{f"ot_datab_ma_hbr0{n}": (f"_ma_b{n}", "sum") for n in BRANCHEN},
        ot_datab_ma_hbr99=("_ma_b99", "sum"),
    )

    # Missings mit 0 füllen
    datab_02b = datab_02.fillna(0)
    hbr_spalten = [f"ot_datab_ma_hbr0{n}" for n in BRANCHEN] + ["ot_datab_ma_hbr99"]
    datab_02b["ot_mitarbeiter"] = sas_sum(datab_02b, hbr_spalten)

    datab_03 = datab_02b[datab_02b["ags11"] != ""].copy()
    datab_03["kr_mitarbeiter"] = datab_03.groupby("ags5")["ot_mitarbeiter"].transform(
        "sum"
    )
    for spalte in hbr_spalten:
        kr_spalte = spalte.replace("ot_", "kr_")
        datab_03[kr_spalte] = datab_03.groupby("ags5")[spalte].transform("sum")

    # Anspielen der Kreisdaten und Eichen
    datab_04 = datab_03.merge(kr_02, on="ags5", how="left").merge(
        ot_01[["ags11", "kr_erwt_basis"]], on="ags11", how="left"
    )

    # SELBST und ERWT_AO werden als Basis verteilt, die Differenz zu den
    # amtlichen Kreiszahlen wird anhand der Mitarbeiter verteilt
    datab_05a = datab_04.merge(
        ot_00[["ags11", "ot_erwt_basis"]], on="ags11", how="left"
    )

    # Wenn Basis größer als amtliche Gesamtzahl, dann amtliche Zahl gleich
    # setzen, wenn relative Abweichung kleiner als 1.3
    differenz_rel = sas_round(
        datab_05a["kr_erwt_basis"] / datab_05a["kr_erwt_ges"], ndigits=2
    )
    anpassen = (datab_05a["kr_erwt_basis"] > datab_05a["kr_erwt_ges"]) & (
        differenz_rel < 1.3
    )
    datab_05a.loc[anpassen, "kr_erwt_ges"] = datab_05a.loc[anpassen, "kr_erwt_basis"]

    datab_05a["rest_differenz"] = datab_05a["kr_erwt_ges"] - datab_05a["kr_erwt_basis"]
    kr_mitarbeiter_sicher = datab_05a["kr_mitarbeiter"].replace(0, np.nan)
    datab_05a["delta_basis"] = datab_05a["rest_differenz"] * (
        datab_05a["ot_mitarbeiter"] / kr_mitarbeiter_sicher
    )
    minmax_df = datab_05a[["ot_erwt_basis", "delta_basis"]]
    datab_05a["mini"] = minmax_df.min(axis=1)
    datab_05a["maxi"] = minmax_df.max(axis=1)

    datab_05b = datab_05a
    datab_05b["kr_mini"] = datab_05b.groupby("ags5")["mini"].transform("sum")
    datab_05b["kr_maxi"] = datab_05b.groupby("ags5")["maxi"].transform("sum")

    datab_05 = datab_05b
    datab_05["ot_erwt_ao_"] = (
        datab_05["kr_mini"] * (datab_05["ot_mitarbeiter"] / kr_mitarbeiter_sicher)
    ) + datab_05["maxi"]

    ot_mitarbeiter_sicher = datab_05["ot_mitarbeiter"].replace(0, np.nan)
    for n in BRANCHEN:
        datab_05[f"ot_erwt_ao_b0{n}"] = datab_05["ot_erwt_ao_"] * (
            datab_05[f"ot_datab_ma_hbr0{n}"] / ot_mitarbeiter_sicher
        )
    datab_05["ot_erwt_ao_b99"] = datab_05["ot_erwt_ao_"] * (
        datab_05["ot_datab_ma_hbr99"] / ot_mitarbeiter_sicher
    )
    b_spalten = [f"ot_erwt_ao_b0{n}" for n in BRANCHEN] + ["ot_erwt_ao_b99"]
    datab_05["ot_erwt_ao_anz"] = sas_sum(datab_05, b_spalten)

    # Anpassungen bei Branchen, bei denen eine Abrundung auf 0 eine Firma
    # ohne Mitarbeiter hinterlassen würde
    for spalte in b_spalten:
        knapp_ueber_0 = (datab_05[spalte] < 0.5) & (datab_05[spalte] > 0)
        datab_05.loc[knapp_ueber_0, spalte] = 1

    # Werte runden und finalisieren
    datab_06 = datab_05
    for spalte in b_spalten:
        datab_06[spalte] = sas_round(datab_06[spalte])
    datab_06["ot_erwt_ao_anz"] = sas_sum(datab_06, b_spalten)

    fehlt_ganz = datab_06["ot_erwt_ao_anz"].isna()
    datab_06.loc[fehlt_ganz, "ot_erwt_ao_anz"] = sas_round(
        datab_06.loc[fehlt_ganz, "ot_erwt_basis"]
    )

    alle_missing_und_0 = datab_06["ot_erwt_ao_b01"].isna() & (
        datab_06["ot_erwt_ao_anz"] == 0
    )
    datab_06.loc[alle_missing_und_0, b_spalten] = 0

    datab_06["delta1"] = datab_06["ot_erwt_basis"] - datab_06["ot_erwt_ao_anz"]
    delta1_positiv = datab_06["delta1"] > 0
    datab_06.loc[delta1_positiv, "ot_erwt_ao_b99"] += datab_06.loc[
        delta1_positiv, "delta1"
    ]
    datab_06.loc[delta1_positiv, "ot_erwt_ao_anz"] += datab_06.loc[
        delta1_positiv, "delta1"
    ]

    # Werte vorerst finalisieren
    datab_06["kr_ot_erwt_ao_anz"] = datab_06.groupby("ags5")[
        "ot_erwt_ao_anz"
    ].transform("sum")

    datab_11 = datab_06[["ags11", "ot_erwt_ao_anz"] + b_spalten].rename(
        columns={"ot_erwt_ao_anz": "ot_erwt_ao"}
    )

    datab_12 = datab_11
    datab_12["summe"] = sas_sum(datab_12, b_spalten)
    summe_null = datab_12["summe"] == 0
    datab_12.loc[summe_null, ["ot_erwt_ao"] + b_spalten] = np.nan
    datab_12["ags5"] = datab_12["ags11"].str[:5]

    # Da es zu den amtlichen Zahlen vom Kreis noch große Abweichungen gibt,
    # noch eine abschließende Runde daran eichen
    eich1 = datab_12.merge(kr_02, on="ags5", how="left")

    eich3 = eich1
    for n in BRANCHEN:
        kr_hbr = eich3.groupby("ags5")[f"ot_erwt_ao_b0{n}"].transform("sum")
        eich3[f"ot_erwt_ao_b0{n}_n"] = eich3[f"ot_erwt_ao_b0{n}"] * (
            eich3[f"kr_erwt_br{n}"] / kr_hbr.replace(0, np.nan)
        )
    eich3["ot_erwt_ao_b99_n"] = eich3["ot_erwt_ao_b99"]
    kr_ot_erwt_ao = eich3.groupby("ags5")["ot_erwt_ao"].transform("sum")
    eich3["ot_erwt_ao_n"] = eich3["ot_erwt_ao"] * (
        eich3["kr_erwt_ges"] / kr_ot_erwt_ao.replace(0, np.nan)
    )

    for n in BRANCHEN:
        spalte_n, spalte = f"ot_erwt_ao_b0{n}_n", f"ot_erwt_ao_b0{n}"
        eich3.loc[eich3[spalte_n].isna(), spalte_n] = eich3.loc[
            eich3[spalte_n].isna(), spalte
        ]
    eich3.loc[eich3["ot_erwt_ao_b99_n"].isna(), "ot_erwt_ao_b99_n"] = eich3.loc[
        eich3["ot_erwt_ao_b99_n"].isna(), "ot_erwt_ao_b99"
    ]
    eich3.loc[eich3["ot_erwt_ao_n"].isna(), "ot_erwt_ao_n"] = eich3.loc[
        eich3["ot_erwt_ao_n"].isna(), "ot_erwt_ao"
    ]

    n_spalten = [f"ot_erwt_ao_b0{n}_n" for n in BRANCHEN] + ["ot_erwt_ao_b99_n"]

    # eich4: finale Spalten übernehmen (SAS-Original benennt hier zusätzlich
    # in _fin um, inhaltlich identisch zu den _n-Werten aus eich3)
    eich4 = eich3
    for spalte in n_spalten:
        eich4[spalte.replace("_n", "_fin")] = eich4[spalte]
    fin_spalten = [f"ot_erwt_ao_b0{n}_fin" for n in BRANCHEN] + ["ot_erwt_ao_b99_fin"]
    eich4["ot_erwt_ao_fin"] = sas_sum(eich4, fin_spalten)

    eich7 = eich4
    eich7["summe"] = sas_sum(eich7, fin_spalten)
    summe_null2 = eich7["summe"] == 0
    eich7.loc[summe_null2, ["ot_erwt_ao_fin"] + fin_spalten] = np.nan

    # Werte runden und finalisieren
    final = eich7[["ags11"] + fin_spalten + ["ot_erwt_ao_fin"]].copy()
    final = final.rename(
        columns={f"ot_erwt_ao_b0{n}_fin": f"ot_erwt_ao_b0{n}" for n in BRANCHEN}
    )
    final = final.rename(
        columns={"ot_erwt_ao_b99_fin": "ot_erwt_ao_b99", "ot_erwt_ao_fin": "ot_erwt_ao"}
    )
    for spalte in b_spalten:
        final[spalte] = sas_round(final[spalte])
    final["ot_erwt_ao"] = sas_round(final["ot_erwt_ao"])

    # Entstanden Rundungsdifferenzen? Auf BR99 drauf rechnen
    final["delta"] = final["ot_erwt_ao"] - sas_sum(final, b_spalten)
    delta_vorhanden = ~final["delta"].isin([0]) & final["delta"].notna()
    final.loc[delta_vorhanden, "ot_erwt_ao_b99"] += final.loc[delta_vorhanden, "delta"]

    # Bei negativen Werten in BR99 wird die größte Branche (B01-B07) zum
    # Ausgleich herangezogen
    final2 = final.drop(columns=["delta"])
    negativ = (final2["ot_erwt_ao_b99"] < 0) & final2["ot_erwt_ao_b99"].notna()
    branchen_spalten = [f"ot_erwt_ao_b0{n}" for n in BRANCHEN]
    if negativ.any():
        werte = final2.loc[negativ, branchen_spalten].to_numpy()
        groesste_spalte_idx = np.argmax(werte, axis=1)
        for i, spalte in enumerate(branchen_spalten):
            treffer = negativ.copy()
            treffer[negativ] = groesste_spalte_idx == i
            final2.loc[treffer, spalte] += final2.loc[treffer, "ot_erwt_ao_b99"]
        final2.loc[negativ, "ot_erwt_ao_b99"] = 0

    final3 = final2
    logger.info(
        "Erwerbstätige AO verteilt: %d Zeilen, Summe=%.0f",
        len(final3),
        final3["ot_erwt_ao"].sum(),
    )

    # Validierung gegen SAS-Referenz (vor dem Push):
    # validate(
    #     df_py=final3,
    #     ref_query="SELECT ags11, ot_erwt_ao FROM sas_schema.z_ags11_erwt_ao_b",
    #     engine=engine,
    #     pk="ags11",
    #     cols=["ot_erwt_ao"],
    #     tolerance=0,
    # )

    # final3.to_sql(
    #     name="z_ags11_erwt_ao_b",
    #     con=engine,
    #     schema="SCHEMA",
    #     if_exists="replace",
    #     index=False,
    # )
    # logger.info("Gespeichert: %d Zeilen", len(final3))

    engine.dispose()
    engine_roh.dispose()


if __name__ == "__main__":
    main()
