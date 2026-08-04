"""
Validierungsfunktion für SAS-nach-Python-Migrationen.

Prüft ob ein Python-Ergebnis (DataFrame im Speicher) mit einer
SAS-Referenz übereinstimmt – vor dem Push. Die Referenz kann entweder
aus der Datenbank (ref_query + engine) oder direkt aus einer
SAS7BDAT-Datei (ref_path) geladen werden.

Verwendung in Migrationsskripten:

    from igi_base import validate

    # Variante 1: Referenz aus der Datenbank
    validate(
        df_py=opnv_13,
        ref_query="SELECT ags27, casa_opnv_idx FROM variablen2025.ags27_casa_opnv",
        engine=engine,
        pk="ags27",
        cols=["casa_opnv_idx"],
        tolerance=0,
        sample_n=1000,
    )

    # Variante 2: Referenz aus einer SAS7BDAT-Datei
    validate(
        df_py=ot_be_ao,
        ref_path="beschaeftigte/sas/datensatz/ot_be_ao.sas7bdat",
        pk="ags11",
        cols=["ot_be_ao"],
        tolerance=0,
    )
"""

from pathlib import Path

import pandas as pd
from sqlalchemy.engine import Engine

from igi_base.log import get_logger

logger = get_logger(__name__)

MAX_EXAMPLES = 20  # max. Anzahl Beispiel-Diffs pro Fehlermeldung im Log


def validate(
    df_py: pd.DataFrame,
    *,
    pk: str,
    cols: list[str],
    ref_query: str | None = None,
    engine: Engine | None = None,
    ref_path: str | Path | None = None,
    tolerance: float = 0,
    sample_n: int = 1000,
) -> None:
    """
    Vergleicht df_py mit einer SAS-Referenz - entweder aus der Datenbank
    (ref_query + engine) oder aus einer SAS7BDAT-Datei (ref_path).

    Stufe 1 – Struktur:   Zeilenzahl, PK-Vollständigkeit
    Stufe 2 – Verteilung: deskriptive Stats und value_counts je Spalte
    Stufe 3 – Stichprobe: exakter Vergleich auf sample_n zufälligen PKs

    Wirft bei Abweichungen eine ValidationError-Exception → kein Push.

    Parameters
    ----------
    df_py     : Python-Ergebnis (im Speicher)
    pk        : Primary-Key-Spalte für den Join
    cols      : Spalten die verglichen werden sollen
    ref_query : SQL-Query die den SAS-Referenzoutput aufbaut (Alternative 1, zusammen mit engine)
    engine    : DB-Verbindung (Alternative 1, zusammen mit ref_query)
    ref_path  : Pfad zu einer .sas7bdat-Datei mit der SAS-Referenz (Alternative 2)
    tolerance : Erlaubte Abweichung pro Wert (0 = exakt)
    sample_n  : Anzahl zufälliger PKs für den Stichprobenvergleich

    Hinweis: Genau eine der beiden Alternativen muss angegeben werden.
    """
    using_query = ref_query is not None or engine is not None
    using_path = ref_path is not None

    if using_query and using_path:
        raise ValueError(
            "Gib entweder (ref_query und engine) oder ref_path an, nicht beides."
        )
    if not using_query and not using_path:
        raise ValueError(
            "Gib entweder (ref_query und engine) oder ref_path als Referenz an."
        )
    if using_query and (ref_query is None or engine is None):
        raise ValueError("Für ref_query wird auch engine benötigt (und umgekehrt).")

    df_ref = _load_reference(ref_query, engine, ref_path)

    errors: list[str] = []
    errors += _check_structure(df_py, df_ref, pk)
    errors += _check_distribution(df_py, df_ref, cols, tolerance)
    errors += _check_sample(df_py, df_ref, pk, cols, tolerance, sample_n)

    if errors:
        message = "\n".join(errors)
        logger.error("Validierung fehlgeschlagen:\n%s", message)
        raise ValidationError(message)

    logger.info(
        "Validierung erfolgreich: Python-Ergebnis stimmt mit SAS-Referenz überein."
    )


def _load_reference(
    ref_query: str | None,
    engine: Engine | None,
    ref_path: str | Path | None,
) -> pd.DataFrame:
    """Lädt die SAS-Referenz aus der DB (ref_query/engine) oder aus einer .sas7bdat-Datei (ref_path)."""
    if ref_path is not None:
        # encoding="utf-8": ohne das kommen Text-Spalten als bytes statt
        # str zurück (SAS7BDAT-Eigenheit von pd.read_sas).
        df_ref = pd.read_sas(ref_path, encoding="utf-8")
        # Spaltennamen-Schreibweise ist zwischen SAS-Dateien inkonsistent
        # (z.B. "ot_Schueler" statt "ot_schueler") - hier vereinheitlichen,
        # damit pk/cols beim Aufruf immer lowercase sein können.
        df_ref.columns = df_ref.columns.str.lower()
        return df_ref

    return pd.read_sql(ref_query, engine)


def _check_structure(df_py: pd.DataFrame, df_ref: pd.DataFrame, pk: str) -> list[str]:
    """Stufe 1: Zeilenzahl und PK-Vollständigkeit."""
    errors = []

    if len(df_py) != len(df_ref):
        errors.append(f"Zeilenzahl weicht ab: Python={len(df_py)}, SAS={len(df_ref)}")

    pks_py = set(df_py[pk])
    pks_ref = set(df_ref[pk])

    missing = pks_ref - pks_py
    extra = pks_py - pks_ref

    if missing:
        beispiele = list(missing)[:MAX_EXAMPLES]
        errors.append(f"{len(missing)} PKs fehlen in Python (Beispiele: {beispiele})")

    if extra:
        beispiele = list(extra)[:MAX_EXAMPLES]
        errors.append(
            f"{len(extra)} zusätzliche PKs in Python (Beispiele: {beispiele})"
        )

    return errors


def _check_distribution(
    df_py: pd.DataFrame, df_ref: pd.DataFrame, cols: list[str], tolerance: float
) -> list[str]:
    """Stufe 2: deskriptive Stats (numerisch) und value_counts (wenige eindeutige Werte)."""
    errors = []

    for col in cols:
        if pd.api.types.is_numeric_dtype(df_py[col]):
            stats_py = df_py[col].agg(["min", "max", "mean", "median", "count"])
            stats_ref = df_ref[col].agg(["min", "max", "mean", "median", "count"])

            for stat in ["min", "max", "mean", "median", "count"]:
                diff = abs(stats_py[stat] - stats_ref[stat])
                if diff > tolerance:
                    errors.append(
                        f"Spalte '{col}': {stat} weicht ab "
                        f"(Python={stats_py[stat]}, SAS={stats_ref[stat]}, diff={diff})"
                    )

        if (
            df_py[col].nunique() <= 50
        ):  # value_counts nur bei wenigen eindeutigen Werten sinnvoll
            counts_py = df_py[col].value_counts()
            counts_ref = df_ref[col].value_counts()

            for value in set(counts_py.index) | set(counts_ref.index):
                n_py = counts_py.get(value, 0)
                n_ref = counts_ref.get(value, 0)
                if abs(n_py - n_ref) > tolerance:
                    errors.append(
                        f"Spalte '{col}', Wert '{value}': Anzahl weicht ab "
                        f"(Python={n_py}, SAS={n_ref})"
                    )

    return errors


def _check_sample(
    df_py: pd.DataFrame,
    df_ref: pd.DataFrame,
    pk: str,
    cols: list[str],
    tolerance: float,
    sample_n: int,
) -> list[str]:
    """Stufe 3: exakter Vergleich auf sample_n zufälligen, gemeinsamen PKs."""
    common_pks = list(set(df_py[pk]) & set(df_ref[pk]))
    n = min(sample_n, len(common_pks))

    if n == 0:
        return ["Keine gemeinsamen PKs für Stichprobenvergleich vorhanden."]

    sample_pks = pd.Series(common_pks).sample(n=n, random_state=42)

    merged = df_py[df_py[pk].isin(sample_pks)].merge(
        df_ref[df_ref[pk].isin(sample_pks)], on=pk, suffixes=("_py", "_ref")
    )

    errors = []

    for col in cols:
        col_py, col_ref = f"{col}_py", f"{col}_ref"

        if pd.api.types.is_numeric_dtype(merged[col_py]):
            diff = (merged[col_py] - merged[col_ref]).abs()
            mismatch = merged[diff > tolerance]
        else:
            mismatch = merged[merged[col_py] != merged[col_ref]]

        if not mismatch.empty:
            beispiele = (
                mismatch[[pk, col_py, col_ref]].head(MAX_EXAMPLES).to_dict("records")
            )
            errors.append(
                f"Spalte '{col}': {len(mismatch)} von {n} Stichproben weichen ab "
                f"(Beispiele: {beispiele})"
            )

    return errors


class ValidationError(Exception):
    """Wird geworfen wenn der Vergleich Python vs. SAS fehlschlägt."""
