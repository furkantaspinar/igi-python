"""
Platzhalter für eine echte Ergebnisprüfung nach dem Lauf der
Beschaeftigten-Migrationsskripte (05, 06, 10) - würde normalerweise das
Ergebnis in der Datenbank prüfen (z.B. Zeilenzahlen, Wertebereiche,
Plausibilität ggü. Vorjahr). Hier nur zur Veranschaulichung für's Team, wie
so ein Prüfschritt am Ende einer TaskGroup eingehängt wird.

Steuerbar über die Env-Var PRUEFUNG_ERGEBNIS:
- "erfolgreich" (Default) -> main() läuft durch
- "fehler" -> main() wirft einen Fehler

Lokal: in der .env dieses Ordners setzen. In Airflow: main_dag.py liest dafür
die Airflow-Variable "beschaeftigte_pruefung_ergebnis" (Admin -> Variables im
UI, ohne Redeploy änderbar) und setzt sie vor dem Aufruf als Env-Var.
"""

import os
from pathlib import Path

from igi_base import get_logger, load_environment


def main() -> None:
    load_environment(Path(__file__).parent / ".env")
    logger = get_logger(__name__)

    ergebnis = os.getenv("PRUEFUNG_ERGEBNIS", "erfolgreich")

    if ergebnis == "fehler":
        raise ValueError(
            "Dummy-Prüfung: simulierter Fehler (PRUEFUNG_ERGEBNIS='fehler')"
        )

    logger.info("Dummy-Prüfung erfolgreich (Ergebnis=%r)", ergebnis)


if __name__ == "__main__":
    main()
