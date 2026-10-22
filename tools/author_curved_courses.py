#!/usr/bin/env python3
"""Apply the authored content-14 curve revision, then run bake_tracks.py.

Run after the base expansion/classic authoring tools if regenerating the roster.
Only the 28 named courses change; other routes retain their exact definitions.
"""
import argparse
import json
import math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def controls(row):
    plan, stations = row['plan'], row['elevation_stations']
    assert stations[0][0]==0 and stations[-1][0]==1
    assert all(a[0]<b[0] for a,b in zip(stations,stations[1:]))
    distances = [0.0]
    for a,b in zip(plan,plan[1:]+plan[:1]): distances.append(distances[-1]+math.dist(a,b))
    result=[]
    for (x,z),s in zip(plan,distances):
        u=s/distances[-1]
        for (a,low),(b,high) in zip(stations,stations[1:]):
            if a<=u<=b:
                t=(u-a)/(b-a); t=t*t*(3-2*t)
                result.append([x,round(low+(high-low)*t,4),z])
                break
    return result


def apply(catalog):
    source = json.loads((ROOT/'assets/source/curved_courses14.json').read_text())
    by_id = {row['id']: row for row in source['courses']}
    assert len(by_id) == 28
    for track in catalog['tracks']:
        if track['id'] not in by_id: continue
        row = by_id[track['id']]
        track['ordered_control_points'] = controls(row)
        track['spline'] = row['spline']
    return catalog

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    path = ROOT/'game/content/tracks.json'
    expected = json.dumps(apply(json.loads(path.read_text())),indent=2)+'\n'
    if args.check: assert path.read_text()==expected,'Run tools/author_curved_courses.py'
    else: path.write_text(expected)
    print('TWENTY_EIGHT_AUTHORED_CURVATURE_CONTINUOUS_COURSES')

if __name__=='__main__': main()
