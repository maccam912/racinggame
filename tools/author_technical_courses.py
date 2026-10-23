#!/usr/bin/env python3
"""Apply the reviewed content-15 city plans and three-octave lateral profiles.

Run after older roster authors, then bake_tracks.py. The source keeps explicit
profiles so individual bends can be edited without depending on random state.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'assets/source/technical_courses15.json'
FIELDS = ['ordered_control_points','spline','detail_offsets','ramp_markers','width_intervals','bank_intervals']


def apply(catalog):
    source = json.loads(SOURCE.read_text())
    rows = {row['id']:row for row in source['courses']}
    assert len(rows)==len(catalog['tracks'])==40
    for track in catalog['tracks']:
        track.update({key:rows[track['id']][key] for key in FIELDS})
    return catalog


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    path = ROOT/'game/content/tracks.json'
    expected = json.dumps(apply(json.loads(path.read_text())),indent=2)+'\n'
    if args.check:
        assert path.read_text()==expected,'Run tools/author_technical_courses.py'
    else:
        path.write_text(expected)
    print('FORTY_AUTHORED_THREE_SCALE_ROUTES')


if __name__=='__main__':main()
