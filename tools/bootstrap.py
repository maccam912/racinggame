#!/usr/bin/env python3
"""Install checksum-verified, project-pinned Godot without replacing system Godot."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / "tools/toolchain.lock").read_text())['godot']
CACHE = Path.home() / ".cache/pacific-rush/toolchain" / LOCK['version']


def download(key):
    asset = LOCK['assets'][key]
    path = CACHE / asset['file']
    CACHE.mkdir(parents=True, exist_ok=True)
    if not path.exists() or hashlib.file_digest(path.open('rb'), 'sha256').hexdigest() != asset['sha256']:
        print(f"Downloading {asset['file']}", file=sys.stderr, flush=True)
        temporary = path.with_suffix('.part')
        with urllib.request.urlopen(LOCK['release'] + asset['file'], timeout=120) as src, temporary.open('wb') as dst:
            while chunk := src.read(1024 * 1024):
                dst.write(chunk)
        if hashlib.file_digest(temporary.open('rb'), 'sha256').hexdigest() != asset['sha256']:
            temporary.unlink()
            raise RuntimeError(f"Checksum mismatch: {asset['file']}")
        temporary.replace(path)
    return path


def engine():
    if override := os.environ.get('PACIFIC_GODOT'):
        return Path(override)
    folder = CACHE / sys.platform
    binary = folder / ('Godot.app/Contents/MacOS/Godot' if sys.platform == 'darwin' else
                       'Godot_v4.6.3-stable_win64.exe' if sys.platform == 'win32' else
                       'Godot_v4.6.3-stable_linux.x86_64')
    if not binary.exists():
        with zipfile.ZipFile(download(sys.platform)) as archive:
            archive.extractall(folder)
        for path in folder.rglob('*'):
            if path.is_file() and (path == binary or '/MacOS/' in str(path)):
                path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return binary


def templates():
    if sys.platform == 'darwin':
        base = Path.home() / 'Library/Application Support/Godot'
    elif sys.platform == 'win32':
        base = Path(os.environ['APPDATA']) / 'Godot'
    else:
        base = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'godot'
    destination = base / 'export_templates/4.6.3.stable'
    marker = destination / '.pacific-checksum'
    if marker.exists() and marker.read_text() == LOCK['assets']['templates']['sha256']:
        return
    with zipfile.ZipFile(download('templates')) as archive:
        for item in archive.infolist():
            relative = Path(item.filename).relative_to('templates')
            if not relative.parts or item.is_dir():
                continue
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(item))
            if not target.suffix:
                target.chmod(0o755)
    marker.write_text(LOCK['assets']['templates']['sha256'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--templates', action='store_true')
    args = parser.parse_args()
    binary = engine()
    if args.templates:
        templates()
    print(binary)
