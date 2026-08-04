import numpy as np
import pandas as pd

from igi_base.sas import sas_round, sas_sum


def test_sas_round_rounds_half_away_from_zero():
    assert sas_round(2.5) == 3
    assert sas_round(-2.5) == -3


def test_sas_round_with_ndigits():
    assert sas_round(1.25, ndigits=1) == 1.3


def test_sas_round_on_series():
    result = sas_round(pd.Series([1.5, 2.5, np.nan]))
    assert result.tolist()[:2] == [2, 3]
    assert np.isnan(result.tolist()[2])


def test_sas_sum_adds_columns_row_wise():
    df = pd.DataFrame({"a": [1, 2], "b": [3, 4]})
    result = sas_sum(df, ["a", "b"])
    assert result.tolist() == [4, 6]


def test_sas_sum_ignores_nan_but_keeps_it_if_all_missing():
    df = pd.DataFrame({"a": [1, np.nan], "b": [np.nan, 2]})
    result = sas_sum(df, ["a", "b"])
    assert result.tolist() == [1, 2]

    df_all_missing = pd.DataFrame({"a": [np.nan], "b": [np.nan]})
    result_all_missing = sas_sum(df_all_missing, ["a", "b"])
    assert np.isnan(result_all_missing.iloc[0])
