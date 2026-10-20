#!/usr/bin/env python3
"""Live shared rendezvous, eight native Iroh clients, race/rematch and reconnect."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
import uuid
from bootstrap import ROOT, engine


def snapshot_sources(folder=None):
    paths = sorted([*ROOT.glob('game/net/*.gd'),*ROOT.glob('game/server/*.gd'),*ROOT.glob('native/iroh/src/*.rs'),
                    ROOT/'native/iroh/Cargo.toml',ROOT/'native/iroh/Cargo.lock',ROOT/'tests/iroh_host.gd',
                    ROOT/'tests/lobby_network_client.gd',ROOT/'tools/iroh_integration.py',
                    ROOT/'game/content/compatibility.json',ROOT/'game/content/rules.json'])
    hashes = {}
    for path in paths:
        name = path.relative_to(ROOT).as_posix()
        data = path.read_bytes()
        hashes[name] = hashlib.sha256(data).hexdigest()
        if folder is not None:
            output = folder/'fixture_source'/name
            output.parent.mkdir(parents=True,exist_ok=True)
            output.write_bytes(data)
    return hashes


def run(reconnect=False):
    folder = ROOT/'reports'/('iroh-'+uuid.uuid4().hex[:10])
    folder.mkdir(parents=True)
    (ROOT/'reports/.gdignore').touch()
    command = [str(engine()),'--path',str(ROOT),'--headless','--max-fps','60']
    processes, handles = [], []
    summary = {'passed':False,'service':'https://iroh-rendezvous.maccam912.workers.dev',
               'transport':'native Iroh QUIC; 50±20 ms/1% client application-packet impairment',
               'reconnect':reconnect,'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
               'working_tree_dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip())}
    summary['source_hashes'] = snapshot_sources(folder)
    def start(arguments,name):
        handle = (folder/name).open('w'); handles.append(handle)
        child = subprocess.Popen([*command,*arguments],cwd=ROOT,stdout=handle,stderr=subprocess.STDOUT)
        processes.append(child)
        return child
    try:
        host_report = folder/'host.json'
        host = start(['--script','tests/iroh_host.gd','--',f'--report={host_report}'],'host.log')
        deadline = time.monotonic()+60
        while not host_report.exists():
            if host.poll() is not None or time.monotonic()>deadline:
                raise RuntimeError('Iroh host did not become ready: '+(folder/'host.log').read_text()[-3000:])
            time.sleep(.1)
        hosting = json.loads(host_report.read_text())
        summary['hosting'] = hosting
        clients = []
        for index in range(8):
            extra = ['--reconnect'] if reconnect and index==7 else []
            clients.append(start(['--script','tests/lobby_network_client.gd','--',f'--index={index}',
                f'--iroh-code={hosting["code"]}',f'--report={folder/f"client-{index}.json"}',
                '--latency-ms=50','--jitter-ms=20','--loss=0.01',*extra],f'client-{index}.log'))
        deadline = time.monotonic()+370
        while any(client.poll() is None for client in clients):
            if time.monotonic()>deadline: raise RuntimeError('Iroh race/rematch timed out')
            for index,client in enumerate(clients):
                log = (folder/f'client-{index}.log').read_text()
                if 'SCRIPT ERROR:' in log or 'ERROR:' in log: raise RuntimeError('Iroh client error: '+log[-3000:])
            time.sleep(.25)
        reports = [json.loads((folder/f'client-{index}.json').read_text()) for index in range(8)]
        results = reports[0]['results']
        passed = all(client.returncode==0 for client in clients)
        passed &= len(results)==2 and all(report['results']==results and report['loaded_tracks']==[0,1] for report in reports)
        passed &= all(len(race['rows'])==8 and all(row['dnf']=='' and not row['bot'] for row in race['rows']) for race in results)
        metrics = [metric for report in reports for metric in report['race_metrics']]
        passed &= len(metrics)==16 and all(row['clear']['count']>=100 and row['clear']['p95']<=.25 for row in metrics)
        passed &= not reconnect or reports[7]['resume_count']>=1
        passed &= snapshot_sources()==summary['source_hashes']
        host_report.with_suffix('.json.stop').touch()
        host.wait(timeout=20)
        for path in folder.glob('*.log'):
            passed &= not any(marker in path.read_text() for marker in ['SCRIPT ERROR:','ERROR:','Leaked instance'])
        summary.update(passed=bool(passed),clients=reports,results=results,
                       minimum_clear_samples=min((r['clear']['count'] for r in metrics),default=0),
                       worst_clear_p95=max((r['clear']['p95'] for r in metrics),default=0))
    except BaseException as error:
        summary['failure'] = type(error).__name__+': '+str(error)
    finally:
        for child in processes:
            if child.poll() is None:
                child.terminate()
                try: child.wait(timeout=5)
                except subprocess.TimeoutExpired: child.kill(); child.wait()
        for handle in handles: handle.close()
        (folder/'summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n')
        print(json.dumps({'passed':summary['passed'],'report':str(folder/'summary.json'),
                          'failure':summary.get('failure')},indent=2))
    return 0 if summary['passed'] else 1


if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--reconnect',action='store_true')
    raise SystemExit(run(parser.parse_args().reconnect))
