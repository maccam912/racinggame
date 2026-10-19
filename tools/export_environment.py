"""Scoped Godot Android preferences; preserve unrelated editor changes."""
from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import stat
import tempfile

HEADER = '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'


def resource_range(text):
    header = re.search(r'^\[resource\]\r?\n?', text, re.M)
    if header is None:
        raise ValueError('Godot editor settings have no resource section')
    following = re.search(r'^\[', text[header.end():], re.M)
    return header.end(), header.end() + following.start() if following else len(text)


def property_pattern(key):
    return re.compile(r'^' + re.escape(key) + r'=[^\r\n]*(?:\r?\n|$)', re.M)


def replace_properties(text, keys, lines):
    start, end = resource_range(text)
    body = text[start:end]
    for key in keys:
        body = property_pattern(key).sub('', body)
    if body and not body.endswith('\n'):
        body += '\n'
    return text[:start] + body + ''.join(lines) + text[end:]


def atomic_write(path, text, mode):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.pacific-rush-export-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as output:
            output.write(text.encode('utf-8'))
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


@contextmanager
def temporary_configuration(path, values, environment):
    """Restore only the keys we touch, even after a failed exporter process.

    Godot may write other preferences while importing. Do not restore an entire
    old file over those changes. Credentials are held in memory, never logged.
    """
    path = Path(path)
    existed = path.exists()
    original = path.read_bytes().decode('utf-8') if existed else HEADER
    mode = stat.S_IMODE(path.stat().st_mode) if existed else 0o600
    start, end = resource_range(original)
    previous = [match.group(0) for key in values for match in property_pattern(key).finditer(original[start:end])]
    saved_environment = {key: os.environ.get(key) for key in environment}
    lines = [key + '=' + json.dumps(str(value), ensure_ascii=False) + '\n' for key, value in values.items()]
    atomic_write(path, replace_properties(original, values, lines), mode)
    try:
        os.environ.update(environment)
        yield
    finally:
        for key, value in saved_environment.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        current = path.read_bytes().decode('utf-8') if path.exists() else HEADER
        restored = replace_properties(current, values, previous)
        # If this task alone created the file, leave no empty configuration.
        if not existed and restored.strip() == HEADER.strip():
            path.unlink(missing_ok=True)
        else:
            atomic_write(path, restored, mode)
