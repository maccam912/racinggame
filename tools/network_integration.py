#!/usr/bin/env python3
"""Two real ENet clients + dedicated authority, optional symmetric faults."""
import argparse
import json
from pathlib import Path
import subprocess
import time
from bootstrap import ROOT, engine
from udp_proxy import UDPProxy


def run(seconds=70, latency=0, jitter=0, loss=0, reconnect=False, port=27021, contacts=False, away_seconds=5, trace=False, reverse_start=False):
    folder = ROOT/'reports'/f'network-udp-{latency}-{jitter}-{loss}-{port}'
    folder.mkdir(parents=True, exist_ok=True)
    command = [str(engine()), '--headless', '--path', str(ROOT)]
    proxy = UDPProxy(port,port+100,latency,jitter,loss) if latency or jitter or loss else None
    worker_port = port+100 if proxy else port
    processes, files = [], []
    try:
        if proxy:
            proxy.start()
        log = (folder/'server.log').open('w')
        files.append(log)
        server = subprocess.Popen([*command, '--', '--server', '--auto-start', '--no-bot-fill', '--laps=1', f'--port={worker_port}', *(['--laps=3', '--contact-fixture'] if contacts else [])], stdout=log, stderr=subprocess.STDOUT)
        processes.append(server)
        deadline = time.monotonic()+15
        while 'PACIFIC_RUSH_SERVER_READY' not in (folder/'server.log').read_text():
            if server.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError('Worker failed to start: '+(folder/'server.log').read_text()[-2000:])
            time.sleep(.1)
        for index in ([1,0] if reverse_start else [0,1]):
            log = (folder/f'client{index}.log').open('w')
            files.append(log)
            args = [*command, '--script', 'tests/network_bot_client.gd', '--', f'--port={port}', f'--name=Driver{index}', f'--report={folder / f"client{index}.json"}', f'--seconds={seconds}']
            if reconnect and index == 0:
                args += ['--reconnect-at=15', f'--away-seconds={away_seconds}']
            if trace:
                args += ['--trace-network']
            if contacts:
                args += ['--contact-exercises']
            processes.append(subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT))
            if reverse_start and index == 1:
                until = time.monotonic()+5
                while 'waiting for racers' not in (folder/'client1.log').read_text() and time.monotonic() < until:
                    time.sleep(.05)
        deadline = time.monotonic()+seconds+20
        while any(p.poll() is None for p in processes[1:]):
            if server.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError('Network integration timeout/worker exit')
            time.sleep(.2)
        for index, process in enumerate(processes[1:]):
            assert process.returncode == 0, f'Client {index} failed: {(folder / f"client{index}.log").read_text()[-2000:]}'
        values = [json.loads((folder/f'client{i}.json').read_text()) for i in range(2)]
        assert {v['slot'] for v in values} == {0, 1}, 'Stable unique slots'
        for index, value in enumerate(values):
            expired = reconnect and away_seconds > 20 and index == 0
            assert value['snapshots'] >= (150 if expired else 1000 if seconds >= 65 else 20), 'Insufficient snapshot samples'
            assert value['max_speed'] > 15, 'Inputs did not drive the car'
            if seconds >= 65 and not expired:
                assert value['contact_corrections' if contacts else 'clear_corrections']['count'] >= 1000, 'Insufficient moving correction samples for scenario'
                assert value['clear_corrections']['p95'] <= (.5 if latency >= 75 else .25), 'Clear-road correction target failed'
                assert value['contact_corrections']['p95'] <= 1.5, 'Contact correction target failed'
        if reconnect:
            if away_seconds <= 20:
                assert values[0]['reconnect_done'] and values[0]['connected'] and values[0]['initial_slot'] == values[0]['slot'], 'Reconnect must retain the original slot'
            else:
                assert values[0]['reconnect_done'] and not values[0]['connected'] and not values[0]['results'] and 'Reconnect expired' in values[0].get('permanent_error',''), 'Expired identity must not regain control or receive a fabricated result'
                assert len(values[1]['results']) == 2 and any(row['name'] == 'Driver0' and row['dnf'] == 'Reconnect expired' for row in values[1]['results']), 'Authority must preserve the expired human as DNF without duplicate seats'
        if seconds >= 90 and not contacts and not (reconnect and away_seconds > 20):
            assert all(v['results'] for v in values), 'Race did not finish on authority and both clients'
        if all(v['results'] for v in values):
            assert values[0]['results'] == values[1]['results'], 'Authoritative standings diverged'
        contact_events = (folder/'server.log').read_text().count('PACIFIC_RUSH_CONTACT_EVENT')
        if contacts:
            assert contact_events >= 20, f'Only {contact_events} distinct contact episodes; need 20'
        report = {'passed':True, 'protocol':json.loads((ROOT/'game/content/rules.json').read_text())['protocol_version'], 'content_hash':json.loads((ROOT/'game/content/compatibility.json').read_text())['content_hash'], 'away_seconds':away_seconds if reconnect else 0, 'seconds':seconds, 'one_way_latency_ms':latency, 'jitter_ms':jitter, 'loss':loss, 'transport':'UDP proxy including ENet handshake/ACK/reliable packets' if proxy else 'loopback ENet', 'wire_metrics':dict(proxy.stats) if proxy else {}, 'contact_events':contact_events, 'clients':values}
        (folder/'summary.json').write_text(json.dumps(report, indent=2)+'\n')
        console_report = {**report, 'clients':[{k:v for k,v in value.items() if k != 'reconciliation_trace'} for value in values]}
        print(json.dumps(console_report, indent=2), flush=True)
        return report
    finally:
        for process in reversed(processes):
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        for file in files:
            file.close()
        if proxy:
            proxy.stop()
        for path in folder.glob('*.log'):
            text = path.read_text()
            if 'SCRIPT ERROR:' in text or 'ERROR:' in text:
                raise RuntimeError(f'Errors in {path.name}: {text[-3000:]}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--seconds', type=float, default=70)
    parser.add_argument('--latency', type=int, default=0)
    parser.add_argument('--jitter', type=int, default=0)
    parser.add_argument('--loss', type=float, default=0)
    parser.add_argument('--reconnect', action='store_true')
    parser.add_argument('--port', type=int, default=27021)
    parser.add_argument('--contacts', action='store_true')
    parser.add_argument('--away-seconds', type=float, default=5)
    parser.add_argument('--trace', action='store_true')
    parser.add_argument('--reverse-start', action='store_true')
    run(**vars(parser.parse_args()))
