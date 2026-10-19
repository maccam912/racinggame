#!/usr/bin/env python3
"""Versioned gameplay manifest, identical in editor, client exports and stripped server."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def compute():
    files = sorted([*ROOT.glob('game/content/baked/*.json'), *ROOT.glob('game/core/*.gd'),
                    ROOT/'game/content/cars.json', ROOT/'game/content/tracks.json',
                    ROOT/'game/content/rules.json', ROOT/'game/world/route_geometry.gd',
                    ROOT/'game/net/net_codec.gd', ROOT/'game/net/input_buffer.gd'])
    context = hashlib.sha256()
    hashes = {}
    for path in files:
        name = path.relative_to(ROOT).as_posix()
        context.update(name.encode())
        context.update(path.read_bytes())
        hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    return {'schema_version':1, 'content_hash':context.hexdigest(), 'files':hashes}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    path = ROOT/'game/content/compatibility.json'
    value = json.dumps(compute(), indent=2)+'\n'
    if args.check:
        assert path.read_text() == value, 'Gameplay hash stale: run python3 tools/content_hash.py'
    else:
        path.write_text(value)
    print(compute()['content_hash'])
