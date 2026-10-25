"""Bind reviewed terrain to road geometry independently of the vehicle roster."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ('length','columns','samples','distances','start_sample','gates')


def geometry_hash(bake):
    value = {key:bake[key] for key in FIELDS}
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def binding():
    return json.loads((ROOT/'assets/source/terrain_routes19.json').read_text())


def route_matches(row, bake):
    if row['route_hash'] == bake['content_hash']:
        return True
    base = binding()['tracks'].get(bake['track_id'],{})
    return row['route_hash'] == base.get('route_hash') and geometry_hash(bake) == base.get('geometry_sha256')
