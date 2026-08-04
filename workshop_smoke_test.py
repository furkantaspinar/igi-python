"""
Workshop Smoke Test

Führe dieses Skript aus um zu prüfen ob deine Umgebung korrekt eingerichtet ist:
- Datenbankverbindung funktioniert
- igi_base ist installiert
- .env wird gelesen

Nutzt die .env des Fachbereichs "beschaeftigte" als Beispiel (jeder
Fachbereich unter migration/ hat seine eigene .env, siehe README).

Ausführen:
    uv run python workshop_smoke_test.py
"""

from pathlib import Path

import pandas as pd

from igi_base import get_engine, get_logger, load_environment

PAGS_AKT = 2025
BESCHAEFTIGTE_ENV = Path(__file__).parent / "migration" / "beschaeftigte" / ".env"


def main() -> None:
    load_environment(BESCHAEFTIGTE_ENV)
    logger = get_logger(__name__)

    logger.info("Verbinde mit Datenbank...")
    engine = get_engine(env_var="PROD_DB")

    logger.info("Lade Daten...")
    df = pd.read_sql_table(
        table_name="ags8",
        con=engine,
        schema=f"variablen{PAGS_AKT}",
        columns=["ags8", "gemeindename"],
    )

    logger.info("Geladen: %d Zeilen", len(df))
    logger.info("Erste Zeilen:\n%s", df.head())

    engine.dispose()
    logger.info("Fertig. Umgebung ist korrekt eingerichtet.")


if __name__ == "__main__":
    main()
