import os

from igi_base.env import Environment, detect_environment, load_environment


def test_detect_environment_is_local_by_default(monkeypatch):
    monkeypatch.delenv("AIRFLOW_HOME", raising=False)
    assert detect_environment() == Environment.LOCAL


def test_detect_environment_is_airflow_if_airflow_home_set(monkeypatch):
    monkeypatch.setenv("AIRFLOW_HOME", "/some/path")
    assert detect_environment() == Environment.AIRFLOW


def test_load_environment_returns_detected_environment(monkeypatch):
    monkeypatch.delenv("AIRFLOW_HOME", raising=False)
    assert load_environment() == Environment.LOCAL


def test_load_environment_loads_explicit_dotenv_path(monkeypatch, tmp_path):
    monkeypatch.delenv("AIRFLOW_HOME", raising=False)
    monkeypatch.delenv("SOME_FACHBEREICH_VAR", raising=False)
    dotenv_file = tmp_path / ".env"
    dotenv_file.write_text("SOME_FACHBEREICH_VAR=hello\n")

    assert load_environment(dotenv_file) == Environment.LOCAL
    assert os.environ["SOME_FACHBEREICH_VAR"] == "hello"


def test_load_environment_skips_dotenv_in_airflow(monkeypatch, tmp_path):
    monkeypatch.setenv("AIRFLOW_HOME", "/some/path")
    monkeypatch.delenv("SOME_OTHER_VAR", raising=False)
    dotenv_file = tmp_path / ".env"
    dotenv_file.write_text("SOME_OTHER_VAR=hello\n")

    assert load_environment(dotenv_file) == Environment.AIRFLOW
    assert "SOME_OTHER_VAR" not in os.environ
