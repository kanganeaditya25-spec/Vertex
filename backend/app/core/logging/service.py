from __future__ import annotations

import json
import logging as std_logging
from collections.abc import Mapping
from typing import Any

from app.core.configuration.settings import core_settings

_SENSITIVE_KEYS = {
    'authorization',
    'cookie',
    'password',
    'secret',
    'token',
    'api_key',
    'access_token',
    'refresh_token',
}


def _bounded(value: Any, max_chars: int) -> Any:
    if isinstance(value, Mapping):
        return {str(key): _bounded(item, max_chars) for key, item in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [_bounded(item, max_chars) for item in value]
    if isinstance(value, str) and len(value) > max_chars:
        return f'{value[:max_chars]}…'
    return value


def redact_fields(fields: Mapping[str, Any] | None) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in (fields or {}).items():
        normalized = str(key).casefold().replace('-', '_')
        result[str(key)] = '[REDACTED]' if normalized in _SENSITIVE_KEYS else _bounded(value, core_settings.max_log_value_chars)
    return result


class CoreLogger:
    def __init__(self, name: str = 'focusflow.core') -> None:
        self._logger = std_logging.getLogger(name)

    def _write(self, level: int, message: str, fields: Mapping[str, Any] | None = None) -> None:
        payload = {'message': message, **redact_fields(fields)}
        self._logger.log(level, json.dumps(payload, ensure_ascii=False, default=str))

    def debug(self, message: str, **fields: Any) -> None:
        self._write(std_logging.DEBUG, message, fields)

    def info(self, message: str, **fields: Any) -> None:
        self._write(std_logging.INFO, message, fields)

    def warning(self, message: str, **fields: Any) -> None:
        self._write(std_logging.WARNING, message, fields)

    def error(self, message: str, **fields: Any) -> None:
        self._write(std_logging.ERROR, message, fields)

    def exception(self, message: str, **fields: Any) -> None:
        self._write(std_logging.ERROR, message, fields)


def configure_logging() -> None:
    level = getattr(std_logging, core_settings.log_level.upper(), std_logging.INFO)
    std_logging.basicConfig(level=level, format='%(message)s')
    std_logging.getLogger('focusflow.core').setLevel(level)


logger = CoreLogger()
