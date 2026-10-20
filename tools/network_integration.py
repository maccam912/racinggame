#!/usr/bin/env python3
"""Two real ENet clients + dedicated authority, optional symmetric faults."""
import argparse
import json
from pathlib import Path
import subprocess
import time
import uuid
from bootstrap import ROOT, engine
from content_hash import compute as gameplay_manifest
from udp_proxy import UDPProxy


def run(seconds=160, latency=0, jitter=0, loss=0, reconnect=False, port=27021, contacts=False, away_seconds=5, trace=False, reverse_start=False, client_hitch=False, laps=2):
    folder = ROOT/'reports'/f'network-udp-{latency}-{jitter}-{loss}-{port}-{uuid.uuid4().hex[:10]}'
    folder.mkdir(parents=True)
    command = [str(engine()), '--headless', '--path', str(ROOT)]
    proxy = UDPProxy(port,port+100,latency,jitter,loss) if latency or jitter or loss else None
    worker_port = port+100 if proxy else port
    processes, files = [], []
    began = time.monotonic()
    manifest = gameplay_manifest()
    report = {'passed':False, 'content_hash':manifest['content_hash'],
              'laps':3 if contacts else laps, 'seconds':seconds,
              'one_way_latency_ms':latency, 'jitter_ms':jitter, 'loss':loss,
              'contacts':contacts, 'away_seconds':away_seconds if reconnect else 0,
              'client_hitch_seconds':1.5 if client_hitch else 0,
              'protocol':json.loads((ROOT/'game/content/rules.json').read_text())['protocol_version'],
              'transport':'UDP proxy including ENet handshake/ACK/reliable packets' if proxy else 'loopback ENet',
              'clients':[]}
    try:
        assert manifest==json.loads((ROOT/'game/content/compatibility.json').read_text()), 'Gameplay manifest must be current before launch'
        if proxy:
            proxy.start()
        log = (folder/'server.log').open('w')
        files.append(log)
        server = subprocess.Popen([*command, '--', '--server', '--auto-start', '--no-bot-fill', f'--laps={3 if contacts else laps}', f'--port={worker_port}', *(['--contact-fixture'] if contacts else [])], stdout=log, stderr=subprocess.STDOUT)
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
            if client_hitch and index == 1:
                args += ['--hitch-at=10','--hitch-seconds=1.5']
            processes.append(subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT))
            if reverse_start and index == 1:
                until = time.monotonic()+5
                while 'waiting for racers' not in (folder/'client1.log').read_text() and time.monotonic() < until:
                    time.sleep(.05)
        deadline = time.monotonic()+seconds+20
        while any(p.poll() is None for p in processes[1:]):
            worker_exit = server.poll()
            if worker_exit is not None and (worker_exit != 0 or 'PACIFIC_RUSH_AUTHORITATIVE_RESULTS' not in (folder/'server.log').read_text()):
                raise RuntimeError('Worker exited before authoritative results')
            if time.monotonic() > deadline:
                raise RuntimeError('Network integration timeout')
            time.sleep(.2)
        for index, process in enumerate(processes[1:]):
            assert process.returncode == 0, f'Client {index} failed: {(folder / f"client{index}.log").read_text()[-2000:]}'
        values = [json.loads((folder/f'client{i}.json').read_text()) for i in range(2)]
        assert {v['slot'] for v in values} == {0, 1}, 'Stable unique slots'
        for index, value in enumerate(values):
            assert value["large_racing_events"] == 0, "Large roster message arrived during racing"
            expired = reconnect and away_seconds > 20 and index == 0
            assert value['snapshots'] >= (150 if expired else 1000 if seconds >= 65 else 20), 'Insufficient snapshot samples'
            assert value['max_speed'] > 15, 'Inputs did not drive the car'
            # Expiry/contact fixtures may freeze or script the sole rival before
            # any braking. Both lamp states are required in ordinary full races.
            if seconds >= 65 and not contacts and not (reconnect and away_seconds > 20):
                assert value['remote_brake_on'] > 0 and value['remote_brake_off'] > 0, 'Remote authoritative brake lights never switched in the race'
            if seconds >= 65 and not expired:
                assert value['contact_corrections' if contacts else 'clear_corrections']['count'] >= 1000, 'Insufficient moving correction samples for scenario'
                assert value['clear_corrections']['p95'] <= (.5 if latency >= 75 else .25), 'Clear-road correction target failed'
                assert value['contact_corrections']['p95'] <= 1.5, 'Contact correction target failed'
        if reconnect:
            if away_seconds <= 20:
                assert values[0]['resume_count'] >= 1, 'Reconnect did not use compact resume'
                assert values[0]['reconnect_done'] and values[0]['connected'] and values[0]['initial_slot'] == values[0]['slot'], 'Reconnect must retain the original slot'
            else:
                assert values[0]['reconnect_done'] and not values[0]['connected'] and not values[0]['results'] and 'Reconnect expired' in values[0].get('permanent_error',''), 'Expired identity must not regain control or receive a fabricated result'
                assert len(values[1]['results']) == 2 and any(row['name'] == 'Driver0' and row['dnf'] == 'Reconnect expired' for row in values[1]['results']), 'Authority must preserve the expired human as DNF without duplicate seats'
        if client_hitch:
            assert values[1]['hitch_done'] and values[1]['clock_rebase_count'] >= 1, 'Deliberate client stall did not exercise clock rebase'
            assert all(value['clock_rebase_count'] <= 4 for value in values), 'Excessive clock rebases would hide unstable ordinary prediction'
            assert values[1]['acknowledged_sequence'] > 1000, 'Rebased input did not resume server acknowledgement'
            assert values[1]['results'] and all(row['dnf'] == '' for row in values[1]['results']), 'A recoverable client stall must not cause Input inactive DNF'
        if seconds >= 90 and not contacts and not (reconnect and away_seconds > 20):
            assert all(v['results'] for v in values), 'Race did not finish on authority and both clients'
        if all(v['results'] for v in values):
            assert values[0]['results'] == values[1]['results'], 'Authoritative standings diverged'
        contact_events = (folder/'server.log').read_text().count('PACIFIC_RUSH_CONTACT_EVENT')
        if contacts:
            assert contact_events >= 20, f'Only {contact_events} distinct contact episodes; need 20'
        assert gameplay_manifest()==manifest and json.loads((ROOT/'game/content/compatibility.json').read_text())==manifest, 'Gameplay sources or manifest changed during the fixture'
        report.update(passed=True,wire_metrics=dict(proxy.stats) if proxy else {},contact_events=contact_events,clients=values)
    except Exception as error:
        report['failure'] = f'{type(error).__name__}: {error}'
        raise
    finally:
        cleanup_errors = []
        for process in reversed(processes):
            try:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
            except OSError as error:
                cleanup_errors.append(str(error))
        for file in files:
            file.close()
        if proxy:
            try:
                proxy.stop()
            except Exception as error:
                cleanup_errors.append(str(error))
        engine_errors = []
        for path in folder.glob('*.log'):
            text = path.read_text()
            if 'SCRIPT ERROR:' in text or 'ERROR:' in text:
                engine_errors.append(path.name)
        if not report['clients']:
            report['client_report_errors'] = []
            for path in sorted(folder.glob('client*.json')):
                try:
                    report['clients'].append(json.loads(path.read_text()))
                except (OSError,ValueError) as error:
                    report['client_report_errors'].append({'file':path.name,'error':str(error)})
        try:
            unchanged = gameplay_manifest()==manifest and json.loads((ROOT/'game/content/compatibility.json').read_text())==manifest
        except Exception as error:
            unchanged = False
            report['source_manifest_error'] = str(error)
        report.update(elapsed_seconds=time.monotonic()-began,engine_error_logs=engine_errors,
                      cleanup_errors=cleanup_errors,source_manifest_unchanged=unchanged)
        report.setdefault('wire_metrics',dict(proxy.stats) if proxy else {})
        report.setdefault('contact_events',(folder/'server.log').read_text().count('PACIFIC_RUSH_CONTACT_EVENT') if (folder/'server.log').exists() else 0)
        if engine_errors or cleanup_errors or not unchanged:
            report['passed'] = False
            report.setdefault('failure','Engine/cleanup errors or changed gameplay sources; inspect '+str(folder))
        if not report['passed']:
            report.setdefault('failure','Interrupted before a complete fixture result')
        (folder/'summary.json').write_text(json.dumps(report, indent=2)+'\n')
        if engine_errors or cleanup_errors:
            raise RuntimeError('Engine/cleanup errors; inspect '+str(folder))
    assert report['passed'], report.get('failure','Incomplete network fixture')
    console_report = {**report, 'clients':[{k:v for k,v in value.items() if k != 'reconciliation_trace'} for value in report['clients']]}
    print(json.dumps(console_report, indent=2), flush=True)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--seconds', type=float, default=160)
    parser.add_argument('--latency', type=int, default=0)
    parser.add_argument('--jitter', type=int, default=0)
    parser.add_argument('--loss', type=float, default=0)
    parser.add_argument('--laps', type=int, choices=[1,2,3], default=2)
    parser.add_argument('--reconnect', action='store_true')
    parser.add_argument('--port', type=int, default=27021)
    parser.add_argument('--contacts', action='store_true')
    parser.add_argument('--away-seconds', type=float, default=5)
    parser.add_argument('--trace', action='store_true')
    parser.add_argument('--reverse-start', action='store_true')
    parser.add_argument('--client-hitch', action='store_true')
    run(**vars(parser.parse_args()))
