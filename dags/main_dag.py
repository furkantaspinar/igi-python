"""
Beispiel-DAG für migrierte SAS->Python-Skripte, aktuell für den
Themenbereich "beschaeftigte" (nur ein Teil der zu migrierenden Skripte
dieses Repos, kein zentrales DAG für alle Migrationen).

Prinzip: Jeder Themenbereich bekommt eine eigene TaskGroup (klappbar im
Airflow-UI), aber alle Tasks leben im selben DAG-Graphen - Abhängigkeiten
sind daher auch ÜBER Gruppengrenzen hinweg möglich (eine Task in TaskGroup B
kann von einer Task in TaskGroup A abhängen). Das ist in Airflow kein
Sonderfall: TaskGroups sind rein visuell/organisatorisch, keine
Isolationsgrenze für `>>`.

Konvention für's Team, wenn ein weiteres Skript migriert ist:
1. Eigene TaskGroup für den Themenbereich anlegen (falls noch nicht
   vorhanden) oder eine neue Task in eine bestehende Gruppe einfügen.
2. Task-Objekt in einer Variable halten (nicht nur lokal in der `with
   TaskGroup(...)`-Closure) - so bleibt es außerhalb der Gruppe referenzierbar,
   falls eine andere Gruppe später davon abhängen muss.
3. Abhängigkeit(en) am Ende des Blocks mit `>>` eintragen, siehe Beispiel
   unten (05/06 -> 10 innerhalb von "beschaeftigte").

Dateinamen mit Ziffern-Präfix (z.B. "05_SvB_AO.py") sind keine
gültigen Python-Modulnamen und lassen sich nicht per `import` laden -
deshalb der importlib.util-Umweg in _load_main().

Jeder Fachbereich hat eine eigene .env in seinem Ordner
(migration/<bereich>/.env) - load_environment() in den Skripten lädt sie
automatisch relativ zum Skript-Pfad (Path(__file__).parent / ".env"),
nicht relativ zum CWD des DAG-Prozesses. Das funktioniert unverändert auch
beim Laden über _load_main() unten, weil __file__ im geladenen Modul auf
den echten Pfad unter migration/ zeigt. In der Airflow-Umgebung selbst wird
die .env ohnehin ignoriert (AIRFLOW_HOME gesetzt -> Connections/Variablen
statt .env), das betrifft also nur lokale Testläufe außerhalb Airflows.

Migrationsschritte, die reines SQL sind (kein pandas nötig, z.B.
CREATE INDEX/CREATE MATERIALIZED VIEW), bekommen keinen Python-Wrapper -
dafür SQLExecuteQueryOperator direkt mit der .sql-Datei als sql-Parameter
(siehe beschaeftigte_for_studenten unten). Die Verbindung läuft dabei über
eine Airflow Connection (conn_id), nicht über .env/get_engine wie bei den
PythonOperator-Tasks.
"""

import importlib.util
import os
import sys
from datetime import UTC, datetime
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent

# igi_base liegt unter src/ und wird auf dem Airflow-Server nicht installiert
# (kein pip install/uv sync nötig) - der Deploy kopiert nur Dateien, deshalb
# hier src/ direkt auf den Python-Pfad legen, damit `from igi_base import ...`
# in den Migrationsskripten funktioniert.
sys.path.insert(0, str(REPO_ROOT / "src"))

#from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.providers.standard.operators.python import PythonOperator
from airflow.sdk import DAG, TaskGroup, Variable

MIGRATION_ROOT = REPO_ROOT / "migration"

# E-Mail-Benachrichtigung bei fehlgeschlagenen Tasks. Setzt voraus, dass auf
# dem Airflow-Server ein SMTP-Server konfiguriert ist (airflow.cfg [smtp]
# bzw. AIRFLOW__SMTP__* Env-Vars) - das ist nicht Teil dieses Repos.
# TODO: Platzhalter-Adresse durch die echte(n) Team-Adresse(n) ersetzen.
default_args = {
    "email": ["futa@netlight.com"],
    "email_on_failure": True,
    "email_on_retry": False,
}


def _load_main(relative_script_path: str):
    """Lädt die main()-Funktion aus einem Skript mit Ziffern-Präfix im Dateinamen."""
    module_path = MIGRATION_ROOT / relative_script_path
    spec = importlib.util.spec_from_file_location(module_path.stem, module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.main


def _pruefe_beschaeftigte_dummy() -> None:
    """Wrapper um 99_Pruefung_Dummy.main(): liest die Airflow-Variable
    "beschaeftigte_pruefung_ergebnis" (Admin -> Variables im UI, ohne
    Redeploy änderbar) und reicht sie als Env-Var PRUEFUNG_ERGEBNIS an das
    Skript weiter, damit dieses airflow-frei bleibt (wie die übrigen
    Migrationsskripte, siehe Docstring dort):
    - "erfolgreich" (Default, falls Variable nicht gesetzt) -> Task grün
    - "fehler" -> Task schlägt fehl (löst z.B. email_on_failure aus)
    """
    os.environ["PRUEFUNG_ERGEBNIS"] = Variable.get(
        "beschaeftigte_pruefung_ergebnis", default="erfolgreich"
    )
    _load_main("beschaeftigte/99_Pruefung_Dummy.py")()


with (
    DAG(
        dag_id="beschaeftigte",
        description="Beispiel DAG für migrierten SAS->Python-Beschaeftigten-Skripte",
        schedule=None,  # manuell/on-demand - kein Cron nötig während der Migration
        start_date=datetime(2025, 1, 1, tzinfo=UTC),
        catchup=False,
        tags=["sas-migration"],
        default_args=default_args,
    ) as dag,
    TaskGroup(group_id="beschaeftigte") as beschaeftigte_group,
):
    # --- Themenbereich: Beschaeftigte ---
    # Migrierte Skripte: 05_SvB_AO, 06_Selbständige_Mithfam, 10_ERWTPERS_AO,
    # 99_Pruefung_Dummy (Platzhalter-Prüfung, siehe unten). 10 braucht (über
    # die DB-Tabelle variablen2025.ags11_ot_soz) die Outputs von 05 UND 06.
    beschaeftigte_05_svb_ao = PythonOperator(
        task_id="05_svb_ao",
        python_callable=_load_main("beschaeftigte/05_SvB_AO.py"),
    )
    beschaeftigte_06_selbstaendige_mithfam = PythonOperator(
        task_id="06_selbstaendige_mithfam",
        python_callable=_load_main("beschaeftigte/06_Selbstaendige_Mithfam.py"),
    )
    beschaeftigte_10_erwtpers_ao = PythonOperator(
        task_id="10_erwtpers_ao",
        python_callable=_load_main("beschaeftigte/10_ERWTPERS_AO.py"),
    )
    # 99_Pruefung_Dummy: Platzhalter für ein echtes Prüfskript, das das
    # Ergebnis der Gruppe in der DB validiert (Zeilenzahlen, Wertebereiche
    # etc.). Kein eigener .env-Bedarf wie bei den anderen, aber sonst gleich
    # behandelt wie ein migriertes Skript - siehe _pruefe_beschaeftigte_dummy().
    beschaeftigte_99_pruefung_dummy = PythonOperator(
        task_id="99_pruefung_dummy",
        python_callable=_pruefe_beschaeftigte_dummy,
    )

    [
        beschaeftigte_05_svb_ao,
        beschaeftigte_06_selbstaendige_mithfam,
    ] >> beschaeftigte_10_erwtpers_ao
    beschaeftigte_10_erwtpers_ao >> beschaeftigte_99_pruefung_dummy

    # for_Studenten.sql ist reines SQL (CREATE INDEX/CREATE MATERIALIZED
    # VIEW) ohne pandas-Transformation - dafür SQLExecuteQueryOperator
    # statt PythonOperator/_load_main(). conn_id verweist auf eine in
    # Airflow hinterlegte Connection (Admin -> Connections), nicht auf
    # eine .env-Variable wie bei den PythonOperator-Tasks oben - Name
    # wie im get_engine()-Kommentar in der _template-Vorlage.
    # beschaeftigte_for_studenten = SQLExecuteQueryOperator(
    #     task_id="for_studenten",
    #     conn_id="i360prod-sos_scheduler_user",
    #     sql=str(MIGRATION_ROOT / "beschaeftigte" / "sas" / "for_Studenten.sql"),
    # )

    # Weitere Themenbereiche (z.B. opnv) werden als eigene TaskGroup ergänzt,
    # sobald deren Skripte migriert sind - siehe Docstring oben für die
    # Konvention. Abhängigkeiten über Gruppengrenzen hinweg sind möglich,
    # z.B.: opnv_01_casa_opnv_idx >> beschaeftigte_05_svb_ao
