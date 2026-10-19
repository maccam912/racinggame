#!/usr/bin/env python3
"""Eight real ENet clients: Unicode rosters, car choices, loading, results and rematch."""
import argparse
import json
from pathlib import Path
import subprocess
import time
from bootstrap import ROOT, engine


def run(port, lobby_reconnect=False):
    folder = ROOT/'reports'/f'lobby-eight-{port}'
    folder.mkdir(parents=True, exist_ok=True)
    command = [str(engine()), '--path', str(ROOT), '--headless']
    processes, handles = [], []
    try:
        log = (folder/'server.log').open('w'); handles.append(log)
        server = subprocess.Popen([*command, '--', '--server', f'--port={port}'], stdout=log, stderr=subprocess.STDOUT)
        processes.append(server)
        deadline = time.monotonic()+10
        while 'PACIFIC_RUSH_SERVER_READY' not in (folder/'server.log').read_text():
            if server.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError('Worker startup failed: '+(folder/'server.log').read_text()[-3000:])
            time.sleep(.05)
        clients = []
        for index in range(8):
            log = (folder/f'client-{index}.log').open('w'); handles.append(log)
            faults = ['--lobby-reconnect'] if lobby_reconnect and index == 0 else []
            client = subprocess.Popen([*command, '--script', 'tests/lobby_network_client.gd', '--', f'--port={port}', f'--index={index}', f'--report={folder/f"client-{index}.json"}', *faults], stdout=log, stderr=subprocess.STDOUT)
            processes.append(client); clients.append(client)
        deadline = time.monotonic()+360
        while any(client.poll() is None for client in clients):
            if time.monotonic() > deadline:
                raise RuntimeError('Eight-client rematch timed out')
            time.sleep(.1)
        reports = [json.loads((folder/f'client-{index}.json').read_text()) for index in range(8)]
        results = reports[0]['results']
        passed = all(client.returncode == 0 for client in clients)
        passed &= len(results) == 2 and all(report['results'] == results and report['loaded_tracks'] == [0,1] for report in reports)
        passed &= all(len(race['rows']) == 8 and sorted(set(row['car'] for row in race['rows'])) == [0,1,2,3] and all(row['dnf'] == '' for row in race['rows']) for race in results)
        for name in ['server.log',*[f'client-{index}.log' for index in range(8)]]:
            text = (folder/name).read_text()
            passed &= not any(marker in text for marker in ('SCRIPT ERROR:', 'ERROR:', 'Leaked instance'))
        summary = {'passed':bool(passed), 'humans':8, 'tracks':[0,1], 'races':results, 'lobby_reconnect':lobby_reconnect,
                   'names':'three family graphemes plus two letters, 77 UTF-8 bytes each',
                   'protocol':json.loads((ROOT/'game/content/rules.json').read_text())['protocol_version'],
                   'content_hash':json.loads((ROOT/'game/content/compatibility.json').read_text())['content_hash'],
                   'clients':reports}
        (folder/'summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n')
        print(json.dumps({'passed':bool(passed), 'report':str(folder/'summary.json')},indent=2))
        return 0 if passed else 1
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
        for handle in handles: handle.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--port',type=int,default=27050)
    parser.add_argument('--lobby-reconnect', action='store_true')
    args = parser.parse_args()
    raise SystemExit(run(args.port, args.lobby_reconnect))
