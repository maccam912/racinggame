#!/usr/bin/env python3
"""Two-lap Expert fields and authority catch-up around an autopiloted human."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import subprocess
import sys
import time
from bootstrap import ROOT
from content_hash import compute


def run(seeds=1, jobs=3):
    folder = ROOT / 'reports' / ('expert-' + time.strftime('%Y%m%d-%H%M%S'))
    folder.mkdir(parents=True)
    tracks = json.loads((ROOT / 'game/content/tracks.json').read_text())['tracks']
    manifest = (ROOT / 'game/content/compatibility.json').read_bytes()
    assert json.loads(manifest) == compute(), 'Regenerate the gameplay manifest before acceptance'
    cases = [(row['id'], human) for row in tracks for human in (False, True)]

    def case(track, human):
        name = track + ('-human' if human else '-field')
        report = folder / (name + '.json')
        command = [sys.executable, 'tools/godot.py', '--headless', '--fixed-fps', '60',
                   '--script', 'tests/bot_tracks.gd', '--', '--track=' + track,
                   '--difficulty=3', '--laps=2', '--seeds=' + str(seeds), '--report=' + str(report)]
        if human:
            command.append('--human')
        with (folder / (name + '.log')).open('w') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600)
        assert result.returncode == 0 and report.exists(), name + ': inspect ' + str(folder)
        value = json.loads(report.read_text())
        assert value['passed'] and len(value['results']) == seeds
        assert all(len(row['times']) == 8 and not row['dnfs'] for row in value['results'])
        print('PASS ' + name, flush=True)
        return [dict(row, human=human, laps=2) for row in value['results']]

    rows = []
    with ThreadPoolExecutor(max_workers=jobs) as executor:
        for future in as_completed([executor.submit(case, *entry) for entry in cases]):
            rows.extend(future.result())
    assert json.loads(manifest) == compute() and manifest == (ROOT / 'game/content/compatibility.json').read_bytes(), 'Gameplay changed during acceptance'
    summary = {'passed': True, 'tracks': len(tracks), 'field_races': len(rows),
               'finished_cars': sum(len(row['times']) for row in rows),
               'recoveries': sum(row['recoveries'] for row in rows),
               'drift_ticks': sum(row['drift_ticks'] for row in rows),
               'content_hash': json.loads(manifest)['content_hash'],
               'boundary': 'Real baked collision, two laps, contact on; all-bot and autopiloted-human fields. Human driving feel and physical-device performance require playtesting.',
               'results': rows}
    (folder / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps({key: value for key, value in summary.items() if key != 'results'}, indent=2))
    print(folder)
    return summary


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--seeds', type=int, choices=range(1, 9), default=1)
    parser.add_argument('--jobs', type=int, choices=range(1, 9), default=3)
    args = parser.parse_args()
    run(args.seeds, args.jobs)
