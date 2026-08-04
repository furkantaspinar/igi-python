# Vorlage für Python-Datentransformationsskripte.
# 1. Neuer Fachbereich: kopiere den GESAMTEN _template-Ordner nach
#    migration/<dein-fachbereich>/ und benenne diese Datei nach deinem Skript.
#    Bestehender Fachbereich: kopiere nur diese Datei in den bestehenden
#    Fachbereichsordner und benenne sie um.
# 2. Falls neuer Fachbereich: .env.example zu .env kopieren und Werte eintragen.
# 3. Ersetze die Platzhalter (conn_id, Schema, Tabellen, Spalten).
# 4. Implementiere deine Transformationen.

from pathlib import Path

import pandas as pd
from sqlalchemy import text  # noqa: F401

from igi_base import get_engine, get_logger, load_environment, validate  # noqa: F401
from igi_base.sas import sas_round, sas_sum  # noqa: F401


def main() -> None:
    load_environment(Path(__file__).parent / ".env")
    logger = get_logger(__name__)

    # get_engine("i360prod-sos_scheduler_user", env_var="PROD_DB") # lokal + Airflow
    # get_engine(env_var="PROD_DB") # nur lokal
    engine = get_engine(env_var="PROD_DB")

    # Daten einlesen
    df = pd.read_sql_table(
        table_name="TABELLE",
        con=engine,
        schema="SCHEMA",
        columns=["SPALTE1", "SPALTE2"],
    )
    # Für Custom-SQL (WHERE, JOIN etc.):
    # from sqlalchemy import text
    # df = pd.read_sql(text("SELECT * FROM schema.tabelle WHERE ..."), con=engine)

    logger.info("Geladen: %d Zeilen", len(df))

    # Transformationen
    # Hier die Fachlichkeit implementieren z.B.:
    # df["col"] = sas_round(df["col"], ndigits=2)
    # df["total"] = sas_sum(df, ["a", "b", "c"])

    # Validierung gegen SAS-Referenz (vor dem Push)
    # Variante 1: Referenz aus der Datenbank
    # validate(
    #     df_py=df,
    #     ref_query="SELECT SPALTE1, SPALTE2 FROM sas_schema.sas_referenztabelle",
    #     engine=engine,
    #     pk="SPALTE1",
    #     cols=["SPALTE2"],
    #     tolerance=0,
    # )
    # Variante 2: Referenz aus einer SAS7BDAT-Datei (SAS-Original schreibt
    # in ein libname-File statt in die DB)
    # validate(
    #     df_py=df,
    #     ref_path=Path(__file__).parent / "sas/datensatz/sas_referenztabelle.sas7bdat",
    #     pk="SPALTE1",
    #     cols=["SPALTE2"],
    #     tolerance=0,
    # )

    # Ergebnis pushen
    df.to_sql(
        name="TABELLE",
        con=engine,
        schema="SCHEMA",
        if_exists="replace",
        index=False,
    )
    logger.info("Gespeichert: %d Zeilen", len(df))

    engine.dispose()


if __name__ == "__main__":
    main()
