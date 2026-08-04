import logging

from igi_base.log import get_logger


def test_get_logger_uses_log_level_env_var(monkeypatch):
    monkeypatch.setenv("LOG_LEVEL", "DEBUG")
    logger = get_logger("test_debug_level")
    assert logger.level == logging.DEBUG


def test_get_logger_does_not_add_duplicate_handlers():
    logger_first_call = get_logger("same_logger")
    logger_second_call = get_logger("same_logger")
    assert len(logger_second_call.handlers) == len(logger_first_call.handlers) == 1
