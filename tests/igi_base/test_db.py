import pytest
from sqlalchemy import Engine

from igi_base.db import get_engine


def test_get_engine_returns_engine_for_env_var(monkeypatch):
    monkeypatch.delenv("AIRFLOW_HOME", raising=False)
    monkeypatch.setenv("TEST_DB", "sqlite:///:memory:")

    engine = get_engine(env_var="TEST_DB")

    assert isinstance(engine, Engine)


def test_get_engine_requires_env_var_locally(monkeypatch):
    monkeypatch.delenv("AIRFLOW_HOME", raising=False)

    with pytest.raises(ValueError):
        get_engine()


def test_get_engine_requires_conn_id_in_airflow(monkeypatch):
    monkeypatch.setenv("AIRFLOW_HOME", "/some/path")

    with pytest.raises(ValueError):
        get_engine()
