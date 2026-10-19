#!/usr/bin/env python3
"""Real Go allocator, authenticated worker and eight ENet clients, two races.

Only ephemeral test identity secrets exist in this process's memory. Tickets
travel to child clients through environment, never command-line arguments/logs.
HTTP is an explicitly enabled loopback exception; TLS boundaries have separate
real TLS unit tests. No claim of a hosted region or physical-device validation.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import secrets
import signal
import subprocess
import time
import urllib.error
import urllib.request
import uuid
from bootstrap import ROOT, engine


def run(http_port=28180, worker_port=27060):
    folder = ROOT/'reports'/f'directory-eight-{worker_port}'
    folder.mkdir(parents=True, exist_ok=True)
    # A fresh key/DB folder for every run, including retries.
    runtime = folder/str(uuid.uuid4())
    runtime.mkdir(mode=0o700)
    binary = ROOT/'build/pacific-directory'
    binary.parent.mkdir(exist_ok=True)
    subprocess.run(['go','-C','services/directory','build','-o',str(binary),'./cmd/pacific-directory'],cwd=ROOT,check=True)
    subprocess.run([str(binary),'keygen','--keys',str(runtime/'keys')],check=True)
    processes,handles=[],[]
    url=f'http://127.0.0.1:{http_port}'
    def api(method,path,body=None,token='',expected=200):
        request=urllib.request.Request(url+path, data=json.dumps(body).encode() if body is not None else None,method=method,headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token} if token else {})})
        try:
            with urllib.request.urlopen(request,timeout=15) as response:
                status,payload=response.status,response.read()
        except urllib.error.HTTPError as error:
            status,payload=error.code,error.read()
        assert status==expected, f'{method} {path.split("?")[0]} got {status}, expected {expected}'
        return json.loads(payload) if payload else None
    compatibility=json.loads((ROOT/'game/content/compatibility.json').read_text())['content_hash']
    protocol=json.loads((ROOT/'game/content/rules.json').read_text())['protocol_version']
    versions={'protocol':protocol,'content_hash':compatibility}
    try:
        log=(folder/'directory.log').open('w');handles.append(log)
        service=subprocess.Popen([str(binary),'serve','--db',str(runtime/'directory.sqlite'),'--keys',str(runtime/'keys'),'--logs',str(runtime/'logs'),'--listen',f'127.0.0.1:{http_port}','--private-listen',f'127.0.0.1:{http_port+1}','--allow-insecure-loopback','--worker',str(engine()),'--worker-project',str(ROOT),'--first-port',str(worker_port),'--workers','2','--protocol',str(protocol),'--content-hash',compatibility],stdout=log,stderr=subprocess.STDOUT)
        processes.append(service)
        deadline=time.monotonic()+10
        while 'PACIFIC_DIRECTORY_READY' not in (folder/'directory.log').read_text():
            if service.poll() is not None or time.monotonic()>deadline:
                raise RuntimeError('Directory startup failed; inspect directory.log')
            time.sleep(.05)
        guests=[]
        for index in range(9):
            secret=base64.urlsafe_b64encode(secrets.token_bytes(32)).decode().rstrip('=')
            guests.append(api('POST','/v1/guests',{'guest_id':str(uuid.uuid4()),'secret':secret,'display_name':'👨‍👩‍👧‍👦'*3+'a'+chr(97+index)},expected=201))
        created=api('POST','/v1/rooms',{'name':'Test Coast','private':False,'region':'test','rules':{'track':0,'laps':1,'bot_fill':False,'difficulty':1,'contact':True},**versions},guests[0]['session_token'],201)
        admissions=[created]
        for guest in guests[1:8]:
            admissions.append(api('POST',f'/v1/rooms/{created["room_id"]}/join',versions,guest['session_token']))
        api('POST',f'/v1/rooms/{created["room_id"]}/join',versions,guests[8]['session_token'],409)
        visible=api('GET',f'/v1/rooms?protocol={protocol}&content_hash={compatibility}&show_in_race=true')['rooms']
        assert len(visible)==1 and visible[0]['humans']==8
        def probe(label,ticket=''):
            target=folder/f'probe-{label}.log'
            with target.open('w') as output:
                result=subprocess.run([str(engine()),'--headless','--path',str(ROOT),'--script','tests/admission_probe.gd','--',f'--port={worker_port}'],env={**os.environ,'PR_TEST_TICKET':ticket},stdout=output,stderr=subprocess.STDOUT,timeout=10)
            assert result.returncode==0 and 'rejected=true' in target.read_text(),f'Admission probe failed: {label}'
        probe('no-ticket')
        ticket=created['ticket'];probe('forged',ticket[:12]+('A' if ticket[12]!='A' else 'B')+ticket[13:])
        clients=[]
        for index,admission in enumerate(admissions):
            log=(folder/f'client-{index}.log').open('w');handles.append(log)
            env={**os.environ,'PR_TEST_TICKET':admission['ticket']}
            client=subprocess.Popen([str(engine()),'--headless','--path',str(ROOT),'--script','tests/lobby_network_client.gd','--',f'--port={worker_port}',f'--index={index}',f'--report={folder/f"client-{index}.json"}'],env=env,stdout=log,stderr=subprocess.STDOUT)
            clients.append(client);processes.append(client)
            if index==0:
                until=time.monotonic()+5
                while 'Official room — waiting for racers' not in (folder/'client-0.log').read_text():
                    if client.poll() is not None or time.monotonic()>until:raise RuntimeError('First official admission failed')
                    time.sleep(.05)
                probe('duplicate',admission['ticket'])
        deadline=time.monotonic()+360
        while any(client.poll() is None for client in clients):
            if service.poll() is not None:raise RuntimeError('Directory died during race')
            if time.monotonic()>deadline:raise RuntimeError('Directory-backed race timeout')
            time.sleep(.1)
        reports=[json.loads((folder/f'client-{index}.json').read_text()) for index in range(8)]
        races=reports[0]['results']
        assert all(client.returncode==0 for client in clients)
        assert len(races)==2 and all(report['results']==races and report['loaded_tracks']==[0,1] for report in reports)
        assert all(len(race['rows'])==8 and all(row['dnf']=='' for row in race['rows']) for race in races)
        assert {row['id'] for row in races[0]['rows']}=={guest['guest_id'] for guest in guests[:8]},'Official identities were replaced or duplicated'
        for index in range(8):
            text=(folder/f'client-{index}.log').read_text()
            assert 'Official room' in text and not any(marker in text for marker in ('SCRIPT ERROR:','ERROR:','Leaked instance'))
        summary={'passed':True,'transport':'explicit loopback HTTP + signed ticket + private worker consume + ENet','protocol':protocol,'content_hash':compatibility,'humans':8,'races':races,'capacity_rejection':409,'admission_probes':['no-ticket','forged','duplicate'],'runtime_keys':'ephemeral local test keys, never release keys'}
        (folder/'summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n')
        print(json.dumps({'passed':True,'report':str(folder/'summary.json')}),flush=True)
        return 0
    finally:
        # SIGINT invokes graceful service shutdown and kills/reaps its own pool.
        for process in reversed(processes):
            if process.poll() is None:
                process.send_signal(signal.SIGINT if process is processes[0] else signal.SIGTERM)
                try:process.wait(timeout=10)
                except subprocess.TimeoutExpired:process.kill();process.wait()
        for handle in handles:handle.close()
        # Retain the SQLite fixture for audit, but remove all ephemeral keys.
        for key in (runtime/'keys').glob('*'):key.unlink()


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--http-port',type=int,default=28180);parser.add_argument('--worker-port',type=int,default=27060);args=parser.parse_args()
    raise SystemExit(run(args.http_port,args.worker_port))
