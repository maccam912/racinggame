#!/usr/bin/env python3
"""Real baked-road AI acceptance, isolated per track to bound wall-clock time."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from bootstrap import ROOT


def run(seeds=20, jobs=3):
    folder = ROOT/'reports'/('ai-acceptance-'+time.strftime('%Y%m%d-%H%M%S'))
    folder.mkdir(parents=True)
    tracks = json.loads((ROOT/'game/content/tracks.json').read_text())['tracks']
    cases = [(track['id'], False) for track in tracks]+[('palm_bay', True)]

    def case(track, solo):
        name = track+('-solo' if solo else '')
        report = folder/(name+'.json')
        command = [sys.executable, 'tools/godot.py', '--headless', '--fixed-fps', '60',
                   '--script', 'tests/bot_tracks.gd', '--', '--track='+track,
                   '--seeds='+str(4 if solo else seeds), '--report='+str(report)]
        if solo:
            command.append('--solo')
        started = time.monotonic()
        with (folder/(name+'.log')).open('w') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=1800)
        if result.returncode or not report.exists():
            raise RuntimeError(name+' failed; inspect '+str(folder/(name+'.log')))
        value = json.loads(report.read_text())
        assert value['passed'] and len(value['results'])==3*(4 if solo else seeds)
        assert all(len(row['times'])==(1 if solo else 8) and not row['dnfs'] for row in value['results'])
        print(f'PASS {name}: {len(value["results"])} races in {time.monotonic()-started:.1f}s', flush=True)
        return name, value

    values = {}
    with ThreadPoolExecutor(max_workers=jobs) as executor:
        for future in as_completed([executor.submit(case, *entry) for entry in cases]):
            name, value = future.result()
            values[name] = value
    solo = values['palm_bay-solo']['results']
    ordering = []
    for car in range(4):
        times = [next(row['times'][0] for row in solo if row['reference_car']==car and row['difficulty']==difficulty) for difficulty in range(3)]
        assert times[2]<times[1]<times[0], f'Difficulty order failed for car {car}: {times}'
        ordering.append({'car':car, 'easy':times[0], 'medium':times[1], 'hard':times[2]})
    rows = [row for name, value in values.items() if not name.endswith('-solo') for row in value['results']]
    summary = {'passed':True, 'content_hash':values['palm_bay']['content_hash'],
               'tracks':len(tracks), 'difficulties':3, 'seeds_per_case':seeds,
               'field_races':len(rows), 'finished_cars':sum(len(row['times']) for row in rows),
               'recoveries':sum(row['recoveries'] for row in rows), 'single_car_ordering':ordering,
               'boundaries':['Seven bots plus an autopiloted reference car; not a human difficulty/feel test',
                             'Bots have no random reaction or line variation; seeds rotate four legal reference-car choices',
                             'Single-car ordering uses a fixture-only flattened Palm Bay route at y=4, with bank/jump offsets zero and car contact disabled; shipped geometry is unchanged']}
    (folder/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2),flush=True)
    return summary


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--seeds', type=int, choices=range(1,21), default=20)
    parser.add_argument('--jobs', type=int, choices=range(1,9), default=min(3,os.cpu_count() or 1))
    args = parser.parse_args()
    run(args.seeds,args.jobs)
