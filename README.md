# igi-python

Monorepo für SAS→Python-Migrationen bei IGI: die gemeinsame Bibliothek `igi_base` und alle Migrationsskripte, organisiert nach Fachbereich.

## Struktur

```
igi-python/
├── src/igi_base/         # gemeinsame Hilfsfunktionen (get_engine, get_logger,
│                          #   load_environment, validate, sas_round, sas_sum, ...)
├── migration/
│   ├── _template/         # Vorlage für eine neue Migration
│   ├── beschaeftigte/      # ein Ordner pro Fachbereich, mit eigener .env
│   └── opnv/
├── dags/main_dag.py       # zentrales Airflow-DAG für alle Fachbereiche
└── tests/igi_base/         # Tests für igi_base
```

Es gibt **ein** Python-Projekt für das gesamte Repo (eine `pyproject.toml`, eine `.venv`, eine Tool-Konfiguration). Migrationsskripte sind kein eigenes Package, sondern liegen als Ordner pro Fachbereich unter `migration/`. Jeder Fachbereich hat aber seine **eigene `.env`**, weil unterschiedliche Fachbereiche unterschiedliche Datenbankzugänge brauchen können.

## Was ist in `igi_base` enthalten

- `get_engine` — SQLAlchemy-Engine, lokal via `.env`, in Airflow via `PostgresHook`
- `load_environment` — lädt eine `.env`; ohne Argument die nächstgelegene aufwärts vom CWD, mit `Path(__file__).parent / ".env"` gezielt die `.env` des aufrufenden Skripts (so funktioniert die Fachbereichs-`.env`)
- `get_logger` — konfigurierter Logger
- `sas_round` / `sas_sum` — SAS-kompatibles Runden/Summieren
- `validate` — vergleicht ein Python-Ergebnis mit der SAS-Referenz (aus DB-Query oder `.sas7bdat`-Datei), vor dem Push

## Setup

`uv` ersetzt `pip` + `venv`:
```bash
# Linux/Ubuntu
curl -LsSf https://astral.sh/uv/install.sh | sh
# Windows
winget install astral-sh.uv
```

Danach im Repo-Root:
```bash
uv sync
```

Für jeden Fachbereich, mit dem du arbeitest, `.env.example` kopieren und befüllen:
```bash
cp migration/beschaeftigte/.env.example migration/beschaeftigte/.env
# Werte anpassen
```

FYI: Die verfügbaren Datenbankverbindungen sind intern unter `\lda\fachliteratur\python_skripte\db_connections\psql_connections.json` aufgelistet. Den passenden `sqlalchemy_connstring` dort nachschlagen und in die jeweilige `.env` eintragen.

> **Wichtig:** Credentials niemals direkt im Code einlesen — immer über `.env` und `get_engine(env_var="...")`.

## Setup prüfen

```bash
uv run python workshop_smoke_test.py
```

Verbindet sich mit der Datenbank, lädt eine kleine Tabelle und gibt die ersten Zeilen aus. Endet der Log-Output mit `Fertig. Umgebung ist korrekt eingerichtet.` — ist alles bereit.

## Neue Migration anlegen

1. Fachbereich existiert schon: `migration/_template/skript.py` in den bestehenden Fachbereichsordner kopieren und umbenennen.
2. Neuer Fachbereich: den gesamten `migration/_template/`-Ordner nach `migration/<fachbereich>/` kopieren, `.env.example` zu `.env` kopieren und befüllen.
3. Platzhalter ersetzen (Schema, Tabellen, Spalten, Env-Var, ...), Transformationen implementieren.
4. Code prüfen und formatieren:
   ```bash
   uv run ruff check .
   uv run ruff format .
   ```
5. Skript ausführen:
   ```bash
   uv run python migration/<fachbereich>/mein_script.py
   ```

## Tests

```bash
uv run pytest
```

## Airflow

`dags/main_dag.py` bindet die migrierten Skripte pro Fachbereich als eigene `TaskGroup` ein (siehe Docstring dort für die Team-Konvention beim Hinzufügen weiterer Skripte).

## SAS→Python Cheatsheet

Siehe [`CHEATSHEET.md`](CHEATSHEET.md) für gängige SAS→Python-Übersetzungsmuster.
