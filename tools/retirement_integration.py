#!/usr/bin/env python3
"""Real ENet shutdown after an explicitly synthetic eight-driver result."""
import argparse
import json
from pathlib import Path
import subprocess
import time
import uuid
from bootstrap import ROOT, engine
from udp_proxy import UDPProxy

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--port',type=int,default=27640)
    args=parser.parse_args()
    folder=ROOT/'reports'/('worker-retirement-'+uuid.uuid4().hex[:10]);folder.mkdir(parents=True)
    command=[str(engine()),'--headless','--path',str(ROOT)]
    processes,handles=[],[]
    proxy=UDPProxy(args.port,args.port+10,75,30,.03)
    summary={'passed':False,'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
             'boundary':'Synthetic eight-driver finish exercises active-race retirement and real fragmented reliable ENet delivery. No profile, score, timing or genuine race finish acceptance.'}
    try:
        proxy.start()
        handle=(folder/'worker.log').open('w');handles.append(handle)
        server=subprocess.Popen([*command,'--script','tests/retirement_worker.gd','--','--auto-start','--no-bot-fill',f'--port={args.port+10}'],stdout=handle,stderr=subprocess.STDOUT)
        processes.append(server)
        deadline=time.monotonic()+10
        while 'PACIFIC_RUSH_SERVER_READY' not in (folder/'worker.log').read_text():
            assert server.poll() is None and time.monotonic()<deadline,'Worker startup'
            time.sleep(.05)
        for index in range(8):
            handle=(folder/f'client-{index}.log').open('w');handles.append(handle)
            name='👨‍👩‍👧‍👦'*3+'a'+chr(97+index)
            processes.append(subprocess.Popen([*command,'--script','tests/network_bot_client.gd','--',f'--port={args.port}',f'--name={name}','--seconds=20','--retirement-commands',f'--report={folder/f"client-{index}.json"}'],stdout=handle,stderr=subprocess.STDOUT))
        deadline=time.monotonic()+35
        while any(child.poll() is None for child in processes):
            assert time.monotonic()<deadline,'Worker did not retire in bounded time'
            time.sleep(.1)
        reports=[json.loads((folder/f'client-{i}.json').read_text()) for i in range(8)]
        log=(folder/'worker.log').read_text()
        summary.update(clients=reports,worker_exit=server.returncode,wire=dict(proxy.stats),retired_during_active_race='RETIREMENT_REQUESTED_DURING_RACE' in log,advanced_before_finish='RETIREMENT_SYNTHETIC_RESULTS' in log)
        payload_bytes=next((int(line.split()[-1]) for line in log.splitlines() if line.startswith('RETIREMENT_RESULTS_BYTES ')),0)
        summary.update(late_admission_rejected='RETIREMENT_LATE_ADMISSION_REJECTED' in log, races_started=log.count('PACIFIC_RUSH_RACE_STARTED'),result_payload_bytes=payload_bytes)
        summary['passed']=all(child.returncode==0 for child in processes) and summary['retired_during_active_race'] and summary['advanced_before_finish'] and summary['late_admission_rejected'] and summary['races_started']==1 and payload_bytes>1200 and len(reports[0]['results'])==8 and all(report['results']==reports[0]['results'] for report in reports)
        assert summary['passed'],'Retirement failed to deliver the final authoritative rows'
    except Exception as error:
        summary['failure']=f'{type(error).__name__}: {error}'
        raise
    finally:
        for child in reversed(processes):
            if child.poll() is None:
                child.terminate()
                try:child.wait(timeout=5)
                except subprocess.TimeoutExpired:child.kill();child.wait()
        proxy.stop()
        for handle in handles:handle.close()
        (folder/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        print(json.dumps({'passed':summary['passed'],'report':str(folder/'summary.json')}),flush=True)

if __name__=='__main__':main()
