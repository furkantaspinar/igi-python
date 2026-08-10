"""SQLAlchemy-Engine für die DB-Verbindung - lokal via .env, in Airflow via Connection."""

from __future__ import annotations

import os
from typing import TYPE_CHECKING

from igi_base.env import Environment, detect_environment

if TYPE_CHECKING:
    from sqlalchemy.engine import Engine


def get_engine(conn_id: str | None = None, *, env_var: str | None = None) -> Engine:
    """
    Lokal: env_var angeben, z.B. get_engine(env_var="PROD_DB") -> liest die
    Connection-URL aus der gleichnamigen Variable in der .env.

    In Airflow: conn_id angeben -> nutzt die dort in Airflow hinterlegte Connection.
    """
    environment = detect_environment()

    if environment == Environment.AIRFLOW:
        if conn_id is None:
            raise ValueError("conn_id is required in Airflow environment")
        from airflow.providers.postgres.hooks.postgres import PostgresHook

        return PostgresHook(postgres_conn_id=conn_id).get_sqlalchemy_engine()

    if env_var is None:
        raise ValueError("env_var is required in local environment")
    from sqlalchemy import create_engine

    return create_engine(os.environ[env_var])
