"""
BESCHAEFTIGTE 07_Schueler_Azubis PAGS2025
Migriert aus: 07_Schueler_Azubis.sas

Schüler und Azubis

Benötigte Input Variablen:
- Einwohner nach Altersklasse
- Schüler auf Kreisebene vom Amt
- Auszubildende auf Kreisebene vom Amt

Vorgehen:
Die Anzahl der Schüler auf Kreisebene wird über die Einwohnerzahl (6 bis
unter 18 Jährige) auf die Siedlungsblöcke verteilt und anschließend auf
Ortsteil aggregiert.

Die Anzahl der Auszubildenden auf Kreisebene wird über die Einwohnerzahl
(15 bis unter 30 Jährige) auf die Siedlungsblöcke verteilt und
anschließend auf Ortsteil aggregiert.

Nicht übersetzt: der komplette PRÜFUNG-Block (test, test2, test3, test4,
proc sgplot, proc corr) sowie die chk_kr_sum/chk_kr1-Zwischenchecks, das
"mark"-Flag und der "ant"-Anteilswert - reine Diagnose des SAS-Entwicklers
ohne Einfluss auf die Zieltabellen.
"""

from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import text  # noqa: F401

from igi_base import get_engine, get_logger, load_environment, validate
from igi_base.sas import sas_round, sas_sum


def main() -> None:
    load_environment(Path(__file__).parent / ".env")
    logger = get_logger(__name__)

    engine = get_engine(env_var="PROD_DB")
    engine_roh = get_engine(env_var="PROCESSING_DB")

    # Match Altersstruktur und Daten auf Kreis

    # Amtliche Daten auf Kreisebene ziehen
    kr_schueler = pd.read_sql_table(
        table_name="kr_schueler_2023", con=engine_roh, schema="roh_genesis"
    )

    # Einwohner ziehen
    sb_ew = pd.read_sql_table(
        table_name="mv_ags20",
        con=engine,
        schema="variablen2025",
        columns=[
            "ags20",
            "sb_ew_anz",
            "sb_ew_06u10_anz",
            "sb_ew_10u15_anz",
            "sb_ew_15u18_anz",
            "sb_ew_18u30_anz",
        ],
    )
    sb_ew["ags5"] = sb_ew["ags20"].str[:5]

    # Match Daten
    a1a = sb_ew.merge(kr_schueler, on="ags5", how="left")
    a1a = a1a[a1a["sb_ew_anz"].notna()]

    # Schüler ausrechnen
    a1 = a1a
    a1["sb_ew_06u18_anz"] = sas_sum(
        a1, ["sb_ew_06u10_anz", "sb_ew_10u15_anz", "sb_ew_15u18_anz"]
    )

    # Aufsummieren auf Kreis
    a2a = a1
    a2a["ags5_ew_06u18_anz"] = a2a.groupby("ags5")["sb_ew_06u18_anz"].transform("sum")

    # Verteilen
    a2b = a2a
    ags5_ew_06u18_sicher = a2b["ags5_ew_06u18_anz"].replace(0, np.nan)
    a2b["sb_schueler"] = (
        a2b["sb_ew_06u18_anz"] / ags5_ew_06u18_sicher * a2b["kr_schueler"]
    )
    a2b.loc[a2b["ags5_ew_06u18_anz"] == 0, "sb_schueler"] = 0
    a2b["ags11"] = a2b["ags20"].str[:11]

    # Zahlen anpassen, wenn zu hoch
    a2 = a2b
    kappungsgrenze = sas_round(a2["sb_ew_06u18_anz"] + a2["sb_ew_06u18_anz"] * 0.1)
    zu_hoch = a2["sb_schueler"] > kappungsgrenze
    a2.loc[zu_hoch, "sb_schueler"] = kappungsgrenze[zu_hoch]

    a3 = a2
    a3["sb_schueler"] = sas_round(a3["sb_schueler"])
    logger.info(
        "Schüler verteilt: %d Zeilen, Summe=%.0f", len(a3), a3["sb_schueler"].sum()
    )

    # Abspeichern
    # Auf SB
    sb_schueler = a3[["ags20", "sb_schueler"]]  # noqa: F841 (für auskommentierten to_sql-Write unten)

    # Auf OT
    ot_schueler = (
        a3.groupby("ags11", as_index=False)["sb_schueler"]
        .sum()
        .rename(columns={"sb_schueler": "ot_schueler"})
    )

    # ----- AZUBIS -----

    # Amtliche Daten aus Datenbank ziehen
    kr_input = pd.read_sql_table(
        table_name="kr_ausbildung_2023", con=engine_roh, schema="roh_genesis"
    )

    # Daten einlesen
    a1_azubi = sb_ew.merge(kr_input, on="ags5", how="left")
    a1_azubi = a1_azubi[a1_azubi["sb_ew_anz"].notna()]

    # EW 15-30 berechnen
    a1b = a1_azubi
    a1b["sb_ew_15u30_anz"] = sas_sum(a1b, ["sb_ew_15u18_anz", "sb_ew_18u30_anz"])
    a1b = a1b[a1b["sb_ew_anz"].notna()]

    # Aufsummieren auf Kreis
    a2b_azubi = a1b[["ags5", "ags20", "sb_ew_15u30_anz", "kr_azubi"]].copy()
    a2b_azubi["ags5_ew_15u30_anz"] = a2b_azubi.groupby("ags5")[
        "sb_ew_15u30_anz"
    ].transform("sum")

    # Verteilen
    a2_azubi = a2b_azubi
    ags5_ew_15u30_sicher = a2_azubi["ags5_ew_15u30_anz"].replace(0, np.nan)
    a2_azubi["sb_azubi"] = (
        a2_azubi["sb_ew_15u30_anz"] / ags5_ew_15u30_sicher * a2_azubi["kr_azubi"]
    )
    a2_azubi.loc[a2_azubi["ags5_ew_15u30_anz"] == 0, "sb_azubi"] = 0
    a2_azubi["ags11"] = a2_azubi["ags20"].str[:11]

    a3_azubi = a2_azubi[
        [
            "ags5",
            "ags11",
            "ags20",
            "sb_ew_15u30_anz",
            "ags5_ew_15u30_anz",
            "sb_azubi",
            "kr_azubi",
        ]
    ].copy()
    a3_azubi["ags5_azubi"] = (
        sas_round(a3_azubi["sb_azubi"]).groupby(a3_azubi["ags5"]).transform("sum")
    )
    a3_azubi["delta"] = a3_azubi["kr_azubi"] - a3_azubi["ags5_azubi"]

    # ANPASSUNGEN
    a3b = a3_azubi
    ags5_azubi_sicher = a3b["ags5_azubi"].replace(0, np.nan)
    a3b["sb_azubi_2"] = sas_round(a3b["sb_azubi"] / ags5_azubi_sicher * a3b["delta"])
    a3b.loc[a3b["ags5_azubi"] == 0, "sb_azubi_2"] = 0
    a3b["sb_azubi_neu"] = sas_round(sas_sum(a3b, ["sb_azubi", "sb_azubi_2"]))
    logger.info(
        "Azubis verteilt: %d Zeilen, Summe=%.0f", len(a3b), a3b["sb_azubi_neu"].sum()
    )

    # Abspeichern
    # Auf SB
    sb_azubi = a3b[["ags20", "sb_azubi_neu"]].rename(  # noqa: F841 (für auskommentierten to_sql-Write unten)
        columns={"sb_azubi_neu": "sb_azubi"}
    )

    # Auf OT
    ot_azubi = (  # noqa: F841 (für auskommentierten to_sql-Write unten)
        a3b.groupby("ags11", as_index=False)["sb_azubi_neu"]
        .sum()
        .rename(columns={"sb_azubi_neu": "ot_azubi"})
    )

    # Validierung gegen SAS-Referenz (vor dem Push):
    validate(
        df_py=ot_schueler,
        ref_path=Path(__file__).parent / "sas/datensatz/ot_schueler.sas7bdat",
        pk="ags11",
        cols=["ot_schueler"],
        tolerance=0,
    )

    # sb_schueler.to_sql(
    #     name="sb_schueler", con=engine, schema="SCHEMA", if_exists="replace", index=False
    # )
    # ot_schueler.to_sql(
    #     name="ot_schueler", con=engine, schema="SCHEMA", if_exists="replace", index=False
    # )
    # sb_azubi.to_sql(
    #     name="sb_azubi", con=engine, schema="SCHEMA", if_exists="replace", index=False
    # )
    # ot_azubi.to_sql(
    #     name="ot_azubi", con=engine, schema="SCHEMA", if_exists="replace", index=False
    # )
    # logger.info(
    #     "Gespeichert: SB_SCHUELER=%d, OT_SCHUELER=%d, SB_AZUBI=%d, OT_AZUBI=%d",
    #     len(sb_schueler),
    #     len(ot_schueler),
    #     len(sb_azubi),
    #     len(ot_azubi),
    # )

    engine.dispose()
    engine_roh.dispose()


if __name__ == "__main__":
    main()
