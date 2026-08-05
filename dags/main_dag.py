"""
Zentrales DAG für alle SAS->Python-Migrationen dieses Repos.

Ziel: EIN DAG für die gesamte Migration. Jeder Themenbereich bekommt eine eigene
TaskGroup (klappbar im Airflow-UI), aber alle Tasks leben im
selben DAG-Graphen - Abhängigkeiten sind daher auch ÜBER Gruppengrenzen
hinweg möglich (eine Task in TaskGroup B kann von einer Task in TaskGroup A
abhängen). Das ist in Airflow kein Sonderfall: TaskGroups sind rein
visuell/organisatorisch, keine Isolationsgrenze für `>>`.

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
import sys
from datetime import UTC, datetime
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent

# igi_base liegt unter src/ und wird auf dem Airflow-Server nicht installiert
# (kein pip install/uv sync nötig) - der Deploy kopiert nur Dateien, deshalb
# hier src/ direkt auf den Python-Pfad legen, damit `from igi_base import ...`
# in den Migrationsskripten funktioniert.
sys.path.insert(0, str(REPO_ROOT / "src"))

from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.providers.standard.operators.python import PythonOperator
from airflow.sdk import DAG, TaskGroup

MIGRATION_ROOT = REPO_ROOT / "migration"


def _load_main(relative_script_path: str):
    """Lädt die main()-Funktion aus einem Skript mit Ziffern-Präfix im Dateinamen."""
    module_path = MIGRATION_ROOT / relative_script_path
    spec = importlib.util.spec_from_file_location(module_path.stem, module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.main


with (
    DAG(
        dag_id="main",
        description="Zentrales DAG für alle migrierten SAS->Python-Skripte des Repos",
        schedule=None,  # manuell/on-demand - kein Cron nötig während der Migration
        start_date=datetime(2025, 1, 1, tzinfo=UTC),
        catchup=False,
        tags=["sas-migration"],
    ) as dag,
    TaskGroup(group_id="beschaeftigte") as beschaeftigte_group,
):
    # --- Themenbereich: Beschaeftigte ---
    # Migrierte Skripte: 05_SvB_AO, 06_Selbständige_Mithfam, 10_ERWTPERS_AO.
    # 10 braucht (über die DB-Tabelle variablen2025.ags11_ot_soz) die
    # Outputs von 05 UND 06.
    beschaeftigte_05_svb_ao = PythonOperator(
        task_id="05_svb_ao",
        python_callable=_load_main("beschaeftigte/05_SvB_AO.py"),
    )
    beschaeftigte_06_selbstaendige_mithfam = PythonOperator(
        task_id="06_selbstaendige_mithfam",
        python_callable=_load_main("beschaeftigte/06_Selbständige_Mithfam.py"),
    )
    beschaeftigte_10_erwtpers_ao = PythonOperator(
        task_id="10_erwtpers_ao",
        python_callable=_load_main("beschaeftigte/10_ERWTPERS_AO.py"),
    )

    [
        beschaeftigte_05_svb_ao,
        beschaeftigte_06_selbstaendige_mithfam,
    ] >> beschaeftigte_10_erwtpers_ao

    # for_Studenten.sql ist reines SQL (CREATE INDEX/CREATE MATERIALIZED
    # VIEW) ohne pandas-Transformation - dafür SQLExecuteQueryOperator
    # statt PythonOperator/_load_main(). conn_id verweist auf eine in
    # Airflow hinterlegte Connection (Admin -> Connections), nicht auf
    # eine .env-Variable wie bei den PythonOperator-Tasks oben - Name
    # wie im get_engine()-Kommentar in der _template-Vorlage.
    beschaeftigte_for_studenten = SQLExecuteQueryOperator(
        task_id="for_studenten",
        conn_id="i360prod-sos_scheduler_user",
        sql=str(MIGRATION_ROOT / "beschaeftigte" / "sas" / "for_Studenten.sql"),
    )

    # Weitere Themenbereiche (z.B. opnv) werden als eigene TaskGroup ergänzt,
    # sobald deren Skripte migriert sind - siehe Docstring oben für die
    # Konvention. Abhängigkeiten über Gruppengrenzen hinweg sind möglich,
    # z.B.: opnv_01_casa_opnv_idx >> beschaeftigte_05_svb_ao
