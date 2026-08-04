"""
CASA_OPNV_IDX PAGS2025
Bearbeiter: ErS
Datum: 08.05.2025

Berechnet den ÖPNV-Index (0–100) je Adresspunkt (ags27) anhand der
Fußwegdistanz zu Bus-, U-Bahn/Tram- und Bahnhaltestellen.
Ausgabe: sas_dbupdate.z_ags27_ers_0508_opnv_idx
"""

from pathlib import Path

import pandas as pd
from sqlalchemy import text  # noqa: F401

from igi_base import get_engine, get_logger, load_environment, validate
from igi_base.sas import sas_round, sas_sum  # noqa: F401

pags_akt = 2025
schema_var = f"variablen{pags_akt}"


def main() -> None:
    load_environment(Path(__file__).parent / ".env")
    logger = get_logger(__name__)

    engine = get_engine(env_var="PROD_DB")

    # --- Stammdaten einlesen ---

    gem1 = pd.read_sql_table(
        table_name="ags8",
        con=engine,
        schema=schema_var,
        columns=["ags8", "gemeindename"],
    )

    gem2 = pd.read_sql_table(
        table_name="ags8_gem_lage",
        con=engine,
        schema=schema_var,
        columns=["ags8", "gem_bbsr_typ"],
    )

    bbsr = gem1.merge(gem2, on="ags8", how="left")

    # --- ÖPNV-Distanzen einlesen, auf 10.000 m deckeln ---

    lage = pd.read_sql_table(
        table_name="ags27_casa_opnv",
        con=engine,
        schema=schema_var,
        columns=["ags27", "casa_dist_bhf", "casa_dist_bush", "casa_dist_ustrab"],
    )

    lage["casa_dist_bhf"] = lage["casa_dist_bhf"].clip(upper=10000)
    lage["casa_dist_bush"] = lage["casa_dist_bush"].clip(upper=10000)
    lage["casa_dist_ustrab"] = lage["casa_dist_ustrab"].clip(upper=10000)

    dist_cols = ["casa_dist_bhf", "casa_dist_bush", "casa_dist_ustrab"]

    lage_check = pd.DataFrame(
        {
            "n": lage[dist_cols].notna().sum(),
            "nmiss": lage[dist_cols].isna().sum(),
            "max": lage[dist_cols].max(),
        }
    )
    logger.info("Prüfung lage:\n%s", lage_check)

    # --- AGS27-Schlüsseltabelle einlesen ---

    ags27 = pd.read_sql_table(
        table_name="ags27",
        con=engine,
        schema=schema_var,
        columns=["ags27", "ags20", "ags8", "ags5"],
    )

    # --- Distanzen und BBSR-Typ an AGS27 anspielen ---

    preopnv_00 = ags27.merge(
        lage[["ags27", "casa_dist_bhf", "casa_dist_bush", "casa_dist_ustrab"]],
        on="ags27",
        how="left",
    )
    # PAGS25: 23.503.292 Zeilen

    tst = preopnv_00[preopnv_00[dist_cols].notna().all(axis=1)]
    logger.info("tst erstellt: %s Zeilen", len(tst))

    preopnv_02 = preopnv_00.merge(
        bbsr[["ags8", "gemeindename", "gem_bbsr_typ"]].rename(
            columns={"gemeindename": "gem_name", "gem_bbsr_typ": "bbsr_typ"}
        ),
        on="ags8",
        how="left",
    )

    # --- Erreichbarkeitsflags setzen ---
    # Städtisch (10/20): engere Schwellen; ländlich/unbekannt (30/40/50/-99): 1.000 m

    opnv_01 = preopnv_02.copy()
    opnv_01["bbsr_typ"] = opnv_01["bbsr_typ"].fillna(-99).astype(int)
    opnv_01["bush_zuweit"] = 0
    opnv_01["ustrab_zuweit"] = 0
    opnv_01["bhf_zuweit"] = 0

    mask_10_20 = opnv_01["bbsr_typ"].isin([10, 20])
    opnv_01.loc[mask_10_20 & (opnv_01["casa_dist_bush"] < 200), "bush_zuweit"] = 1
    opnv_01.loc[mask_10_20 & (opnv_01["casa_dist_ustrab"] < 500), "ustrab_zuweit"] = 1
    opnv_01.loc[mask_10_20 & (opnv_01["casa_dist_bhf"] < 1000), "bhf_zuweit"] = 1

    mask_other = opnv_01["bbsr_typ"].isin([30, 40, 50, -99])
    opnv_01.loc[mask_other & (opnv_01["casa_dist_bush"] < 1000), "bush_zuweit"] = 1
    opnv_01.loc[mask_other & (opnv_01["casa_dist_ustrab"] < 1000), "ustrab_zuweit"] = 1
    opnv_01.loc[mask_other & (opnv_01["casa_dist_bhf"] < 1000), "bhf_zuweit"] = 1

    opnv_01["vorh_opnv_code"] = (
        opnv_01["bush_zuweit"].astype(str)
        + opnv_01["ustrab_zuweit"].astype(str)
        + opnv_01["bhf_zuweit"].astype(str)
    )
    opnv_01["sum_opnv"] = (
        opnv_01["bush_zuweit"] + opnv_01["ustrab_zuweit"] + opnv_01["bhf_zuweit"]
    )

    logger.info("opnv_01 erstellt: %s Zeilen", len(opnv_01))

    dist_check_by_bbsr = opnv_01.groupby("bbsr_typ")[dist_cols].describe().round(2)
    logger.info("Distanzprüfung nach BBSR_TYP:\n%s", dist_check_by_bbsr)

    opnv_01 = opnv_01.sort_values(by=["sum_opnv", "bbsr_typ"])

    # --- Distanzen normieren: je BBSR-Typ auf 0–100.000 skalieren und invertieren ---
    # Formel: 100.000 - ((dist - min) * 100.000) / (max - min)
    # → kurze Distanz = hoher Wert; Rundung auf 5 Dezimalstellen (seit PAGS20)

    opnv_04 = opnv_01.copy()
    for col in dist_cols:
        opnv_04[f"max_{col}"] = opnv_04.groupby("bbsr_typ")[col].transform("max")
        opnv_04[f"min_{col}"] = opnv_04.groupby("bbsr_typ")[col].transform("min")
    logger.info("opnv_04 erstellt: %s Zeilen", len(opnv_04))

    opnv_05 = opnv_04.copy()
    for col in dist_cols:
        opnv_05[f"nor_{col}"] = sas_round(
            100000
            - ((opnv_05[col] - opnv_05[f"min_{col}"]) * 100000)
            / (opnv_05[f"max_{col}"] - opnv_05[f"min_{col}"]),
            ndigits=5,
        )
    opnv_05 = opnv_05.drop(
        columns=[f"max_{col}" for col in dist_cols]
        + [f"min_{col}" for col in dist_cols]
    )
    logger.info("opnv_05 erstellt: %s Zeilen", len(opnv_05))

    # --- Bewertungsindizes berechnen ---
    # bew_idx:   gewichteter Mittelwert über erreichbare Typen (sum_opnv > 0),
    #            sonst einfacher Mittelwert aller drei
    # bew_idx_3: immer einfacher Mittelwert aller drei (Basis für Folgeschritte)

    opnv_06 = opnv_05.copy()
    simple_avg = (
        opnv_06["nor_casa_dist_bush"]
        + opnv_06["nor_casa_dist_ustrab"]
        + opnv_06["nor_casa_dist_bhf"]
    ) / 3
    weighted_avg = (
        opnv_06["bush_zuweit"] * opnv_06["nor_casa_dist_bush"]
        + opnv_06["ustrab_zuweit"] * opnv_06["nor_casa_dist_ustrab"]
        + opnv_06["bhf_zuweit"] * opnv_06["nor_casa_dist_bhf"]
    ) / opnv_06["sum_opnv"]

    opnv_06["bew_idx"] = sas_round(simple_avg)
    opnv_06.loc[opnv_06["sum_opnv"] > 0, "bew_idx"] = sas_round(
        weighted_avg[opnv_06["sum_opnv"] > 0]
    )
    opnv_06["bew_idx_3"] = sas_round(simple_avg)
    logger.info("opnv_06 erstellt: %s Zeilen", len(opnv_06))

    opnv_06s = opnv_06.sort_values(by="sum_opnv")

    # --- bew_idx_3 je sum_opnv-Gruppe auf 0–100.000 normieren ---

    opnv_07 = opnv_06s.copy()
    opnv_07["max_bew_idx_3"] = opnv_07.groupby("sum_opnv")["bew_idx_3"].transform("max")
    opnv_07["min_bew_idx_3"] = opnv_07.groupby("sum_opnv")["bew_idx_3"].transform("min")
    logger.info("opnv_07 erstellt: %s Zeilen", len(opnv_07))

    opnv_08 = opnv_07.copy()
    opnv_08["nor_bew_idx_3"] = (
        (opnv_08["bew_idx_3"] - opnv_08["min_bew_idx_3"]) * 100000
    ) / (opnv_08["max_bew_idx_3"] - opnv_08["min_bew_idx_3"])
    opnv_08 = opnv_08.drop(columns=["max_bew_idx_3", "min_bew_idx_3"])
    logger.info("opnv_08 erstellt: %s Zeilen", len(opnv_08))

    # --- Weichzeichner: Bonus je erreichbarem ÖPNV-Typ addieren ---
    # Mildert harte Sprünge an den Gruppengrenzen ab (25.000 je sum_opnv-Stufe)

    opnv_09a = opnv_08.copy()
    opnv_09a["akt_nor_bew_idx_3"] = opnv_09a["nor_bew_idx_3"] + (
        25000 * opnv_09a["sum_opnv"]
    )
    logger.info("opnv_09a erstellt: %s Zeilen", len(opnv_09a))

    # Globales Min/Max für finale Skalierung
    opnv_09b = opnv_09a.copy()
    opnv_09b["max_bew_akt"] = opnv_09b["akt_nor_bew_idx_3"].max()
    opnv_09b["min_bew_akt"] = opnv_09b["akt_nor_bew_idx_3"].min()
    logger.info("opnv_09b erstellt: %s Zeilen", len(opnv_09b))

    # --- Finale Skalierung auf 0–100 (casa_opnv_idx) ---

    opnv_11 = opnv_09b.copy()
    opnv_11["new_bew_idx_3"] = (
        (opnv_11["akt_nor_bew_idx_3"] - opnv_11["min_bew_akt"]) * 100000
    ) / (opnv_11["max_bew_akt"] - opnv_11["min_bew_akt"])
    opnv_11["casa_opnv_idx"] = sas_round(opnv_11["new_bew_idx_3"] / 1000)
    opnv_11["casa_opnv_idx"] = opnv_11["casa_opnv_idx"].fillna(-99).astype(int)

    logger.info("opnv_11 erstellt: %s Zeilen", len(opnv_11))
    logger.info(
        "Verteilung casa_opnv_idx:\n%s",
        opnv_11["casa_opnv_idx"].value_counts(dropna=False).sort_index(),
    )

    # --- Klassenbildung relativ innerhalb des Kreises (ags5) ---
    # 5 Klassen anhand kreisinterner Perzentile (P10/P30/P70/P90)

    opnv_11s = opnv_11.sort_values(by="ags5")
    perzentile = (
        opnv_11s.groupby("ags5")["casa_opnv_idx"]
        .quantile([0.10, 0.30, 0.70, 0.90])
        .unstack()
    )
    perzentile.columns = ["p_10", "p_30", "p_70", "p_90"]
    perzentile = perzentile.reset_index()

    opnv_12 = opnv_11s.merge(perzentile, on="ags5", how="left")

    opnv_13 = opnv_12.copy()
    opnv_13["casa_opnv_idx_kl"] = -99
    idx = opnv_13["casa_opnv_idx"]
    opnv_13.loc[(idx >= 0) & (idx < opnv_13["p_10"]), "casa_opnv_idx_kl"] = 1
    opnv_13.loc[
        (idx >= opnv_13["p_10"]) & (idx < opnv_13["p_30"]), "casa_opnv_idx_kl"
    ] = 2
    opnv_13.loc[
        (idx >= opnv_13["p_30"]) & (idx < opnv_13["p_70"]), "casa_opnv_idx_kl"
    ] = 3
    opnv_13.loc[
        (idx >= opnv_13["p_70"]) & (idx < opnv_13["p_90"]), "casa_opnv_idx_kl"
    ] = 4
    opnv_13.loc[idx >= opnv_13["p_90"], "casa_opnv_idx_kl"] = 5

    opnv_13 = opnv_13[["ags27", "casa_opnv_idx", "casa_opnv_idx_kl"]]
    logger.info("opnv_13 erstellt: %s Zeilen", len(opnv_13))

    validate(
        df_py=opnv_13,
        ref_query=(
            "SELECT ags27, casa_opnv_idx, casa_opnv_idx_kl "
            f"FROM {schema_var}.ags27_casa_opnv"
        ),
        engine=engine,
        pk="ags27",
        cols=["casa_opnv_idx", "casa_opnv_idx_kl"],
        tolerance=0,
    )

    # --- Ergebnis speichern ---

    """
    opnv_13.to_sql(
        name="z_ags27_ers_0508_opnv_idx",
        con=engine,
        schema="sas_dbupdate",
        if_exists="replace",
        index=False,
        chunksize=100_000,
    )
    with engine.begin() as conn:
        conn.execute(
            text(
                "ALTER TABLE sas_dbupdate.z_ags27_ers_0508_opnv_idx "
                "ADD PRIMARY KEY (ags27)"
            )
        )

    logger.info("opnv_13 gespeichert.")
    engine.dispose()
    """

    # --- Dry Run: Ergebnis prüfen und als CSV speichern, aber NICHT in die Datenbank schreiben ---

    logger.info("DRY RUN: opnv_13 wird nicht in die Datenbank geschrieben.")

    opnv_13=opnv_13.sort_values("ags27")

    logger.info("opnv_13 erstellt: %s Zeilen", len(opnv_13))
    logger.info("opnv_13 Vorschau:\n%s", opnv_13.head(20))

    logger.info(
        "Verteilung casa_opnv_idx:\n%s",
        opnv_13["casa_opnv_idx"].value_counts(dropna=False).sort_index(),
    )

    logger.info(
        "Verteilung casa_opnv_idx_kl:\n%s",
        opnv_13["casa_opnv_idx_kl"].value_counts(dropna=False).sort_index(),
    )

    logger.info(
        "Kennzahlen casa_opnv_idx:\n%s",
        opnv_13["casa_opnv_idx"].agg(["min", "max", "mean", "median"]),
    )

    # Nur Sample speichern, damit die Datei nicht riesig wird
    output_path="opnv_13_python_sample.csv"

    opnv_13.head(100_000).to_csv(
        output_path,
        index=False,
        sep=";",
    )
    logger.info("CSV-Sample gespeichert: %s", output_path)
    engine.dispose()


if __name__ == "__main__":
    main()
