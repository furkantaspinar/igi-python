"""SAS-kompatible Varianten von round() und sum() - Python rundet anders als SAS."""

import math

import numpy as np
import pandas as pd


def sas_round(value, ndigits: int = 0):
    """Rundet wie SAS: half away from zero inklusive Float-Toleranz."""
    if isinstance(value, pd.Series):
        return value.apply(lambda x: sas_round(x, ndigits=ndigits))

    if pd.isna(value):
        return np.nan

    multiplier = 10**ndigits
    x = float(value) * multiplier

    # >>> ÄNDERUNG:
    # Float-Werte wie 12.499999999999998 auf die mathematisch
    # gemeinte Halbstelle 12.5 korrigieren.
    if x >= 0:
        nearest_half = math.floor(x * 2 + 0.5) / 2
    else:
        nearest_half = math.ceil(x * 2 - 0.5) / 2

    tolerance = 1e-12 * max(1.0, abs(x))

    if math.isclose(
        x,
        nearest_half,
        rel_tol=0.0,
        abs_tol=tolerance,
    ):
        x = nearest_half

    # SAS: exakt halbe Werte von null weg runden
    if x >= 0:
        rounded = math.floor(x + 0.5)
    else:
        rounded = math.ceil(x - 0.5)

    result = rounded / multiplier

    return int(result) if ndigits == 0 else result


def sas_sum(df: pd.DataFrame, columns: list) -> pd.Series:
    """Summe über die Spalten pro Zeile. Wie SAS: NaN wird ignoriert, außer wenn alle fehlen."""
    numeric_df = df[columns].apply(pd.to_numeric, errors="raise")
    row_sum = numeric_df.sum(axis=1, skipna=True)
    all_missing = numeric_df.isna().all(axis=1)
    return row_sum.mask(all_missing, np.nan)
