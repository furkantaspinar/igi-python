"""Fertig konfigurierter Logger für Migrationsskripte."""

import logging
import os
import sys


def get_logger(name: str) -> logging.Logger:
    """Loggt auf stdout. Level per LOG_LEVEL-Env-Variable steuerbar (Default INFO)."""
    logger = logging.getLogger(name)

    if logger.handlers:
        return logger  # schon konfiguriert, z.B. bei mehrfachem Import

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(
        logging.Formatter(
            fmt="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
        )
    )

    level = os.getenv("LOG_LEVEL", "INFO").upper()
    logger.setLevel(level)
    logger.addHandler(handler)
    logger.propagate = False

    return logger
