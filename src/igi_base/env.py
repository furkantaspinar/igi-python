"""Erkennt ob das Skript lokal oder in Airflow läuft."""

import os
from enum import Enum
from pathlib import Path

from dotenv import find_dotenv, load_dotenv


class Environment(str, Enum):
    LOCAL = "local"
    AIRFLOW = "airflow"


def detect_environment() -> Environment:
    """Airflow setzt AIRFLOW_HOME - wenn das gesetzt ist, laufen wir in Airflow."""
    if os.getenv("AIRFLOW_HOME"):
        return Environment.AIRFLOW
    return Environment.LOCAL


def load_environment(dotenv_path: str | Path | None = None) -> Environment:
    """Lädt die .env-Datei, aber nur lokal. In Airflow kommen die Variablen von dort.

    dotenv_path: expliziter Pfad zur .env, z.B. Path(__file__).parent / ".env"
    im aufrufenden Migrationsskript. Damit hat jeder Fachbereich seine eigene
    .env, unabhängig vom CWD des Prozesses. Ohne Angabe: alte Suche aufwärts
    ab CWD (find_dotenv) als Fallback für Root-Skripte.
    """
    environment = detect_environment()
    if environment == Environment.AIRFLOW:
        return environment

    if dotenv_path is not None:
        load_dotenv(dotenv_path)
    else:
        load_dotenv(find_dotenv(usecwd=True))
    return environment
