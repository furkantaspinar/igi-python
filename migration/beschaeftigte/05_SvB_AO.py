"""
BESCHAEFTIGTE 05_SvB_AO PAGS2025
Migriert aus: 05_SvB_AO.sas

Sozialversicherungspflichtige Beschäftigte, insgesamt (am Arbeitsort)

Benötigte Input Variablen:
- Beschäftigtenanzahl von Bedirect
- Sozialvers.pflichtig Beschäftigte am Arbeitsort auf Gemeinde- und
  Kreisebene vom Amt

Vorgehen:
Die Anzahl der SvB am Arbeitsort vom Amt auf Gemeinde-und Kreisebene wird
über die Anzahl der Beschäftigten auf die Ortsteile verteilt.

Änderungen von PAGS25:
- in den letzten zwei Jahren wurden Vorjahreswerte übertragen, jetzt wird
  neu berechnet
- hierzu Orientierung am Skript vom PAGS22
- Hintergrund: neue Firmendaten (von Bedirect), die wieder absolute
  Mitarbeiterzahlen ausgeben

Hinweis: der SAS-Block zwischen AO2 und AO3 (Gemeindewerte an Kreiswerte
eichen, GEM_BE_AO_GES_neu/delta_neu) wird unten nicht verwendet und ist
daher hier nicht übersetzt, ebenso die reinen Prüfblöcke (proc freq/means,
test-Tabellen).
"""

from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import text  # noqa: F401

from igi_base import get_engine, get_logger, load_environment, validate  # noqa: F401
from igi_base.sas import sas_round, sas_sum


def main() -> None:
    load_environment(Path(__file__).parent / ".env")
    logger = get_logger(__name__)

    engine = get_engine(env_var="PROD_DB")
    engine_roh = get_engine(env_var="PROCESSING_DB")

    # Kreisdaten einlesen - Ab PAGS25 in Datenbank
    amt_kr = pd.read_sql_table(
        table_name="kr_besch_ao_2023",
        con=engine_roh,
        schema="roh_genesis",
    ).rename(columns={"kr_be_ao": "kr_be_ao_ges"})

    # Gemeindedaten einlesen - Ab PAGS25 in Datenbank
    ags8 = pd.read_sql_table(
        table_name="ags8",
        con=engine,
        schema="variablen2025",
        columns=["ags8", "gemeindename"],
    )
    gem_bev = pd.read_sql_table(
        table_name="gem_bev_2023",
        con=engine_roh,
        schema="roh_genesis",
        columns=["ags8", "gem_ew_anz"],
    )
    gem_besch_ao = pd.read_sql_table(
        table_name="gem_besch_ao_2023",
        con=engine_roh,
        schema="roh_genesis",
        columns=["ags8", "gem_be_ao"],
    ).rename(columns={"gem_be_ao": "gem_be_ao_ges"})

    amt_gem = ags8.merge(gem_bev, on="ags8", how="left").merge(
        gem_besch_ao, on="ags8", how="left"
    )

    # if GEM_be_ao_ges = . and gem_ew_anz not in (0,.) then miss=1;
    # 2025: 10978, davon haben 1.375 keine Beschäftigte, obwohl Einwohner
    amt_gem["miss"] = (
        amt_gem["gem_be_ao_ges"].isna()
        & amt_gem["gem_ew_anz"].notna()
        & (amt_gem["gem_ew_anz"] != 0)
    ).astype(int)

    # Beschäftigte von Gemeinde auf Kreis aggregieren (amtliche Daten)
    amt_gem["ags5"] = amt_gem["ags8"].str[:5]
    amt_gem_ags5 = amt_gem.groupby(
        "ags5",
        as_index=False,
        dropna=False,
    ).agg(
        gem_be_ao_ags5=(
            "gem_be_ao_ges",
            lambda values: values.sum(min_count=1),
        ),
        gem_be_ao_miss=("miss", "sum"),
        anz_gem=("ags8", "size"),
    )

    # ----- FIRMEN -----
    # Firmendaten einlesen
    firmen = pd.read_sql_table(
        table_name="bedirect_vie_20250409",
        con=engine,
        schema="bedirect",
        columns=["ags27", "ags11", "ags8", "ags5", "mitarbeiter_real"],
    )

    # Firmendaten aggregieren auf OT-Ebene
    for column in ["ags27", "ags11", "ags8", "ags5"]:
        firmen[column] = firmen[column].astype("string").str.strip()

    firmen = firmen[
        firmen["ags11"].notna()
        & firmen["ags11"].ne("")
        ].copy()

    firmen = (
        firmen.groupby(
            ["ags5", "ags8", "ags11"],
            as_index=False,
            dropna=False,
        )
        .agg(
            beschaeftigte=(
                "mitarbeiter_real",
                lambda values: values.sum(min_count=1),
            )
        )
    )

    # Firmendaten aggregieren auf Gemeinde-Ebene
    firmen["beschaeftigte_ags8"] = (
        firmen.groupby(
            "ags8",
            dropna=False,
        )["beschaeftigte"]
        .transform(lambda values: values.sum(min_count=1))
    )

    # Firmendaten aggregieren auf Kreis-Ebene
    firmen["beschaeftigte_ags5"] = (
        firmen.groupby(
            "ags5",
            dropna=False,
        )["beschaeftigte"]
        .transform(lambda values: values.sum(min_count=1))
    )

    # ----- POIs -----
    # POIs einlesen
    poi = pd.read_sql_table(table_name="ags27_casa_poi", con=engine, schema="variablen2025")
    poi_spalten = [spalte for spalte in poi.columns if spalte.startswith("casa_poi_")]
    poi["sumpoi"] = sas_sum(poi, poi_spalten).fillna(0)
    poi["ags11"] = poi["ags27"].str[:11]
    poi["ags8"] = poi["ags27"].str[:8]
    poi["ags5"] = poi["ags27"].str[:5]

    # POIs auf OT aggregieren
    poi_ags11 = (
        poi.groupby(
            "ags11",
            as_index=False,
            dropna=False,
        )
        .agg(
            ot_poi=("sumpoi", lambda values: values.sum(min_count=1)),
        )
    )

    # POIs auf Gemeinde aggregieren
    poi_ags8 = (
        poi.groupby(
            "ags8",
            as_index=False,
            dropna=False,
        )
        .agg(
            gem_poi=("sumpoi", lambda values: values.sum(min_count=1)),
        )
    )

    # POIs auf Kreis aggregieren
    poi_ags5 = (
        poi.groupby(
            "ags5",
            as_index=False,
            dropna=False,
        )
        .agg(
            kr_poi=("sumpoi", lambda values: values.sum(min_count=1)),
        )
    )

    ######

    # ----- MERGEN -----
    # Daten zusammenspielen
    ao1 = (
        firmen.merge(
            amt_gem[["ags8", "gemeindename", "gem_ew_anz", "gem_be_ao_ges"]],
            on="ags8",
            how="left",
        )
        .merge(amt_gem_ags5, on="ags5", how="left")
        .merge(amt_kr, on="ags5", how="left")
        .merge(poi_ags11, on="ags11", how="left")
        .merge(poi_ags8, on="ags8", how="left")
        .merge(poi_ags5, on="ags5", how="left")
    )

    # Differenz Beschäftigte Gemeinde und Kreis berechnen
    ao2 = ao1
    ao2["gem_be_ao_delta"] = ao2["kr_be_ao_ges"] - ao2["gem_be_ao_ags5"]

    # Beschäftigte verteilen, wo Gemeindewerte nicht Missing sind
    # ao3 = ao2.copy()
    # beschaeftigte_ags8 = ao3["beschaeftigte_ags8"].replace(0, np.nan)
    # gem_poi = ao3["gem_poi"].replace(0, np.nan)
    #
    # ao3["ot_besch_ao"] = sas_round(
    #     ((ao3["beschaeftigte"] / beschaeftigte_ags8) + (ao3["ot_poi"] / gem_poi))
    #     * ao3["gem_be_ao_ges"]
    #     / 2
    # )
    # kein_poi = ao3["ot_poi"].isna()
    # ao3.loc[kein_poi, "ot_besch_ao"] = sas_round(
    #     ao3.loc[kein_poi, "beschaeftigte"]
    #     / beschaeftigte_ags8[kein_poi]
    #     * ao3.loc[kein_poi, "gem_be_ao_ges"]
    # )
    # ao3.loc[ao3["gem_be_ao_ges"] == 0, "ot_besch_ao"] = 0
    # ao3 = ao3[ao3["ot_besch_ao"].notna()]

    #####

    # Beschäftigte verteilen, wenn Gemeindewerte vorhanden sind
    ao3 = ao2.copy()

    with np.errstate(divide="ignore", invalid="ignore"):
        standard_verteilung = (
                                      (
                                              ao3["beschaeftigte"]
                                              / ao3["beschaeftigte_ags8"]
                                      )
                                      + (
                                              ao3["ot_poi"]
                                              / ao3["gem_poi"]
                                      )
                              ) * ao3["gem_be_ao_ges"] / 2

    standard_verteilung = standard_verteilung.replace(
        [np.inf, -np.inf],
        np.nan,
    )

    ao3["ot_besch_ao"] = sas_round(
        standard_verteilung
    )

    # Fehlende POI-Informationen werden in den aktuellen Daten teilweise
    # als 0 statt als Missing dargestellt. In beiden Fällen wird nur anhand
    # der Bedirect-Beschäftigten verteilt.
    kein_poi_anteil = (
            ao3["ot_poi"].isna()
            | ao3["ot_poi"].eq(0)
            | ao3["gem_poi"].isna()
            | ao3["gem_poi"].eq(0)
    )

    with np.errstate(divide="ignore", invalid="ignore"):
        beschaeftigten_verteilung = (
                ao3["beschaeftigte"]
                / ao3["beschaeftigte_ags8"]
                * ao3["gem_be_ao_ges"]
        )

    beschaeftigten_verteilung = beschaeftigten_verteilung.replace(
        [np.inf, -np.inf],
        np.nan,
    )

    ao3.loc[
        kein_poi_anteil,
        "ot_besch_ao",
    ] = sas_round(
        beschaeftigten_verteilung.loc[kein_poi_anteil]
    )

    # SAS:
    # if GEM_be_ao_ges = 0 then OT_BESCH_AO = 0;
    ao3.loc[
        ao3["gem_be_ao_ges"].eq(0),
        "ot_besch_ao",
    ] = 0

    # SAS:
    # if OT_BESCH_AO = . then delete;
    ao3 = ao3.loc[
        ao3["ot_besch_ao"].notna()
    ].copy()

    # Zahlen verteilen, wo Gemeindewerte Missing sind
    ao4 = ao2[ao2["gem_be_ao_ges"].isna()].copy()

    # Mitarbeiter auf Kreis aggregieren
    ao5 = ao4.copy()

    ao5["beschaeftigte_ags5"] = (
        ao5.groupby(
            "ags5",
            dropna=False,
        )["beschaeftigte"]
        .transform(lambda values: values.sum(min_count=1))
    )

    ao5["kr_poi"] = (
        ao5.groupby(
            "ags5",
            dropna=False,
        )["ot_poi"]
        .transform(lambda values: values.sum(min_count=1))
    )

    # Differenz zwischen Gemeinden und Kreis verteilen
    ao6 = ao5
    beschaeftigte_ags5 = ao6["beschaeftigte_ags5"].replace(0, np.nan)
    kr_poi = ao6["kr_poi"].replace(0, np.nan)

    #ao6["ot_besch_ao"] = sas_round(
    #    ((ao6["beschaeftigte"] / beschaeftigte_ags5) + (ao6["ot_poi"] / kr_poi))
    #    * ao6["gem_be_ao_delta"]
    #    / 2
    #)

    with np.errstate(divide="ignore", invalid="ignore"):
        kreisverteilung = (
                                  (
                                          ao6["beschaeftigte"]
                                          / beschaeftigte_ags5
                                  )
                                  + (
                                          ao6["ot_poi"]
                                          / kr_poi
                                  )
                          ) * ao6["gem_be_ao_delta"] / 2

    kreisverteilung = kreisverteilung.replace(
        [np.inf, -np.inf],
        np.nan,
    )

    ao6["ot_besch_ao"] = sas_round(
        kreisverteilung
    )

    #kein_poi6 = ao6["ot_poi"].isna()
    kein_poi6 = (
            ao6["ot_poi"].isna()
            | ao6["ot_poi"].eq(0)
            | ao6["kr_poi"].isna()
            | ao6["kr_poi"].eq(0)
    )

    #ao6.loc[kein_poi6, "ot_besch_ao"] = sas_round(
    #    ao6.loc[kein_poi6, "beschaeftigte"]
    #    / beschaeftigte_ags5[kein_poi6]
    #    * ao6.loc[kein_poi6, "gem_be_ao_delta"]
    #)

    with np.errstate(divide="ignore", invalid="ignore"):
        kreisverteilung_nur_beschaeftigte = (
                ao6["beschaeftigte"]
                / beschaeftigte_ags5
                * ao6["gem_be_ao_delta"]
        )

    kreisverteilung_nur_beschaeftigte = (
        kreisverteilung_nur_beschaeftigte.replace(
            [np.inf, -np.inf],
            np.nan,
        )
    )

    ao6.loc[
        kein_poi6,
        "ot_besch_ao",
    ] = sas_round(
        kreisverteilung_nur_beschaeftigte.loc[
            kein_poi6
        ]
    )


    ao6.loc[ao6["gem_be_ao_delta"] == 0, "ot_besch_ao"] = 0
    ao6 = ao6[ao6["ot_besch_ao"].notna()]


    # Tabellen zusammenfügen
    ao7 = pd.concat([ao3, ao6], ignore_index=True)

    #ao8 = ao7.groupby("ags11", as_index=False).agg(
    #    ags5=("ags5", "first"),
    #    ags8=("ags8", "first"),
    #    kr_be_ao_ges=("kr_be_ao_ges", "first"),
    #    gem_be_ao_ges=("gem_be_ao_ges", "first"),
    #    beschaeftigte_ot=("beschaeftigte", "sum"),
    #    ot_besch_ao=("ot_besch_ao", "sum"),
    #    anz=("ags11", "count"),
    #)

    #####

    # >>> ÄNDERUNG: dropna=False, SAS-Summen und count(*) nachbilden
    ao8 = ao7.groupby(
        "ags11",
        as_index=False,
        dropna=False,
    ).agg(
        ags5=("ags5", "first"),
        ags8=("ags8", "first"),
        gemeindename=("gemeindename", "first"),
        kr_be_ao_ges=("kr_be_ao_ges", "first"),
        gem_be_ao_ges=("gem_be_ao_ges", "first"),
        beschaeftigte_ot=(
            "beschaeftigte",
            lambda values: values.sum(min_count=1),
        ),
        ot_besch_ao=(
            "ot_besch_ao",
            lambda values: values.sum(min_count=1),
        ),
        anz=("ags11", "size"),
    )

    # Eichen an Werten auf Kreis
    # (Württ-Sonderregel ist im SAS-Original bereits auskommentiert und
    # daher hier nicht übersetzt)
    ao12 = ao8
    ao12["ot_besch_ags5"] = (
        ao12.groupby(
            "ags5",
            dropna=False,
        )["ot_besch_ao"]
        .transform(lambda values: values.sum(min_count=1))
    )
    ot_besch_ags5 = ao12["ot_besch_ags5"].replace(0, np.nan)
    with np.errstate(divide="ignore", invalid="ignore"):
        kreis_eichung = (
                ao12["ot_besch_ao"]
                * ao12["kr_be_ao_ges"]
                / ot_besch_ags5
        )

    kreis_eichung = kreis_eichung.replace(
        [np.inf, -np.inf],
        np.nan,
    )

    ao12["ot_besch_ao_neu"] = sas_round(
        kreis_eichung
    )
    ao12.loc[ao12["ot_besch_ao"] == 0, "ot_besch_ao_neu"] = 0
    logger.info("SvB AO verteilt: %d Zeilen, Summe=%.0f", len(ao12), ao12["ot_besch_ao_neu"].sum())

    # Abspeichern
    ot_be_ao = ao12[["ags11", "ot_besch_ao_neu"]].rename(
        columns={"ot_besch_ao_neu": "ot_be_ao"}
    )

    # Validierung gegen SAS-Referenz (vor dem Push):
    validate(
        df_py=ot_be_ao,
        ref_path=Path(__file__).parent / "sas/datensatz/ot_be_ao.sas7bdat",
        pk="ags11",
        cols=["ot_be_ao"],
        tolerance=0,
    )

    # ot_be_ao.to_sql(
    #     name="ot_be_ao",
    #     con=engine,
    #     schema="SCHEMA",
    #     if_exists="replace",
    #     index=False,
    # )
    logger.info("Gespeichert: %d Zeilen", len(ot_be_ao))

    engine.dispose()
    engine_roh.dispose()


if __name__ == "__main__":
    main()
