#!/usr/bin/env python3
"""Real supervisor drain, crash recovery and overlapping pools on owned data.

The fixture forces synthetic finishes after real service retirement; it does
not validate race times or save any profile. Ephemeral keys/tickets stay local.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import secrets
import shlex
import signal
import socket
import sqlite3
import subprocess
import time
import urllib.error
import urllib.request
import uuid
from bootstrap import ROOT, engine


def wait_for(predicate, seconds, message):
    deadline=time.monotonic()+seconds
    while time.monotonic()<deadline:
        try:
            value=predicate()
            if value:return value
        except (OSError,ValueError,KeyError,sqlite3.Error):pass
        time.sleep(.05)
    raise RuntimeError(message)


def scenario(mode,binary,base_port):
    folder=ROOT/'reports'/('directory-lifecycle-'+mode+'-'+uuid.uuid4().hex[:10])
    folder.mkdir(parents=True,mode=0o700)
    keys=folder/'keys';database=folder/'directory.sqlite';reports=folder/'workers';reports.mkdir()
    subprocess.run([str(binary),'keygen','--keys',str(keys)],check=True,capture_output=True)
    wrapper=folder/'worker.sh';finish_gate=folder/'allow-synthetic-finish'
    wrapper.write_text('#!/bin/sh\nexport PR_LIFECYCLE_REPORT='+shlex.quote(str(reports))+'\nexport PR_LIFECYCLE_FINISH_GATE='+shlex.quote(str(finish_gate))+'\nexec '+shlex.quote(str(engine()))+' --script tests/managed_lifecycle_worker.gd "$@"\n')
    wrapper.chmod(0o700)
    protocol=json.loads((ROOT/'game/content/rules.json').read_text())['protocol_version']
    content=json.loads((ROOT/'game/content/compatibility.json').read_text())['content_hash']
    versions={'protocol':protocol,'content_hash':content}
    rules={'track':0,'laps':1,'bot_fill':False,'difficulty':1,'contact':True}
    url=f'http://127.0.0.1:{base_port}'
    processes,services,handles=[],[],[]
    summary={'passed':False,'scenario':mode,'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
             'boundary':'Owned local Go processes, SQLite and actual ticket-required Godot workers/ENet clients. Forced synthetic finish only; no profile, genuine timing, hosting or physical-device claim.'}

    def api(method,path,body=None,token='',expected=200):
        request=urllib.request.Request(url+path,data=json.dumps(body).encode() if body is not None else None,method=method,
            headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token} if token else {})})
        try:
            with urllib.request.urlopen(request,timeout=15) as response:status,payload=response.status,response.read()
        except urllib.error.HTTPError as error:status,payload=error.code,error.read()
        assert status==expected,f'{method} {path.split("?")[0]} status {status}, expected {expected}'
        return json.loads(payload) if payload else None

    def rows():
        with sqlite3.connect(f'file:{database}?mode=ro',uri=True) as db:
            return db.execute('SELECT id,port,drain_deadline,ready,owner_private FROM workers').fetchall()

    def worker_report(worker):
        return json.loads((reports/(worker+'.json')).read_text())

    def report_flag(worker,flag):
        value=worker_report(worker)
        return value if value.get(flag) else False

    def start_service(label,private_port,pool_port):
        handle=(folder/(label+'.log')).open('w');handles.append(handle)
        child=subprocess.Popen([str(binary),'serve','--db',str(database),'--keys',str(keys),'--logs',str(folder/'logs'),
            '--listen',f'127.0.0.1:{base_port}','--private-listen',f'127.0.0.1:{private_port}','--allow-insecure-loopback',
            '--worker',str(wrapper),'--worker-project',str(ROOT),'--first-port',str(pool_port),'--workers','2','--host-workers','2',
            '--protocol',str(protocol),'--content-hash',content],stdout=handle,stderr=subprocess.STDOUT)
        processes.append(child);services.append(child)
        wait_for(lambda:'PACIFIC_DIRECTORY_READY' in (folder/(label+'.log')).read_text() or child.poll() is not None,10,'Supervisor startup')
        assert child.poll() is None,'Supervisor failed to start'
        return child

    def guest(index):
        secret=base64.urlsafe_b64encode(secrets.token_bytes(32)).decode().rstrip('=')
        return api('POST','/v1/guests',{'guest_id':str(uuid.uuid4()),'secret':secret,'display_name':f'LifecycleDriver{index}'},expected=201)

    def create(identity):
        return api('POST','/v1/rooms',{'name':'LifecycleRoom','private':False,'region':'test','rules':rules,**versions},identity['session_token'],201)

    try:
        old=start_service('old',base_port+1,base_port+20)
        guests=[guest(0),guest(1)]
        created=create(guests[0]);worker=created['worker_id']
        admission=api('POST',f'/v1/rooms/{created["room_id"]}/join',versions,guests[1]['session_token'])
        if mode=='idle':
            subprocess.run([str(binary),'drain','--db',str(database),'--worker',worker],check=True,capture_output=True)
            wait_for(lambda:not rows(),12,'Idle drain did not release worker metadata/port')
            summary.update(idle_worker_reclaimed=True)
        else:
            clients=[]
            for index,ticket in enumerate([created['ticket'],admission['ticket']]):
                handle=(folder/f'client-{index}.log').open('w');handles.append(handle)
                client=subprocess.Popen([str(engine()),'--headless','--path',str(ROOT),'--script','tests/managed_lifecycle_client.gd','--',
                    f'--port={created["port"]}',f'--name=LifecycleDriver{index}','--seconds=28',f'--report={folder/f"client-{index}.json"}'],
                    env={**os.environ,'PR_TEST_TICKET':ticket},stdout=handle,stderr=subprocess.STDOUT)
                clients.append(client);processes.append(client)
            first=wait_for(lambda:report_flag(worker,'race_active'),18,'Race did not become active')
            # Preserve the observed race binding, then change only supervisor state.
            summary['race_before']=first
            if mode in ['crash','recovered-stop']:
                old.kill();old.wait(timeout=5)
                replacement=start_service('replacement',base_port+1,base_port+20)
            else:
                old.send_signal(signal.SIGTERM)
                wait_for(lambda:'directory_draining' in ''.join(path.read_text() for path in (folder/'logs').glob('*.jsonl')),5,'First signal did not enter drain')
                if mode=='rollout':
                    def public_free():
                        with socket.socket() as probe:
                            probe.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
                            probe.bind(('127.0.0.1',base_port))
                        return True
                    wait_for(public_free,6,'Old public listener did not close')
                    replacement=start_service('replacement',base_port+2,base_port+30)
                    new_room=create(guests[0])
                    assert new_room['port']>=base_port+30 and new_room['worker_id']!=worker
                    assert len(rows())==2,'Old/new pools did not overlap'
                    api('POST','/v1/rooms',{'name':'CapacityProbe','private':False,'region':'test','rules':rules,**versions},guests[1]['session_token'],503)
                    subprocess.run([str(binary),'drain','--db',str(database),'--worker',new_room['worker_id']],check=True,capture_output=True)
                    summary.update(overlapping_pools=True,shared_host_cap_rejected=True,old_bearer_accepted_by_new_supervisor=True)
            wait_for(lambda:report_flag(worker,'retiring'),10,'Worker never received private retirement')
            if mode=='recovered-stop':
                replacement.send_signal(signal.SIGTERM)
                wait_for(lambda:'directory_draining' in ''.join(path.read_text() for path in (folder/'logs').glob('*.jsonl')),5,'Replacement did not enter drain')
                time.sleep(1.5)
                assert replacement.poll() is None,'Replacement exited while a recovered active worker still needed private supervision'
                summary['replacement_kept_private_supervision']=True
            finish_gate.write_text('synthetic fixture only\n')
            final=wait_for(lambda:report_flag(worker,'results_sent'),18,'Surviving worker did not finish/deliver after private drain')
            assert final['race_uuid']==first['race_uuid'] and final['guest_ids']==first['guest_ids'] and final['advanced_after_retire']
            summary['race_after']=final
            for client in clients:client.wait(timeout=35)
            data=[json.loads((folder/f'client-{index}.json').read_text()) for index in range(2)]
            assert all(client.returncode==0 for client in clients) and len(data[0]['results'])==2 and data[0]['results']==data[1]['results']
            assert {row['id'] for row in data[0]['results']}=={identity['guest_id'] for identity in guests}
            summary.update(identical_synthetic_results=True,same_race_and_guest_ids=True,clients=data)
            wait_for(lambda:not rows(),12,'Retired old worker left a permanent pool reservation')
            if mode=='rollout':
                old.wait(timeout=8);assert old.returncode==0
                summary['old_supervisor_exited_after_drain']=True
            if mode=='graceful':
                old.wait(timeout=5);assert old.returncode==0
                summary['graceful_supervisor_exit']=True
            elif mode=='recovered-stop':
                replacement.wait(timeout=5);assert replacement.returncode==0
                summary['replacement_exited_after_recovered_worker']=True
            else:
                # The old bearer still authenticates a fresh allocation after recovery.
                probe=create(guests[0])
                subprocess.run([str(binary),'drain','--db',str(database),'--worker',probe['worker_id']],check=True,capture_output=True)
                wait_for(lambda:not rows(),12,'Post-recovery idle allocation did not drain')
                summary['old_bearer_still_allocates']=True
        summary['passed']=True
    except Exception as error:
        summary['failure']=f'{type(error).__name__}: {error}'
        raise
    finally:
        cleanup_issues=[]
        finish_gate.write_text('synthetic fixture cleanup only\n')
        # End only this fixture's clients first; keep private supervision alive
        # while surviving workers receive drain and release their bound ports.
        for child in reversed(processes):
            if child not in services and child.poll() is None:
                child.terminate()
                try:child.wait(timeout=5)
                except subprocess.TimeoutExpired:child.kill();child.wait()
        try:
            if rows():
                if not any(child.poll() is None for child in services):start_service('cleanup',base_port+1,base_port+20)
                subprocess.run([str(binary),'drain','--db',str(database),'--all'],check=True,capture_output=True)
                wait_for(lambda:not rows(),35,'Owned fixture workers did not finish cleanup')
        except Exception as error:cleanup_issues.append(f'{type(error).__name__}: {error}')
        for child in reversed(services):
            if child.poll() is None:
                child.send_signal(signal.SIGINT)
                try:child.wait(timeout=12)
                except subprocess.TimeoutExpired:
                    child.send_signal(signal.SIGINT)
                    try:child.wait(timeout=10)
                    except subprocess.TimeoutExpired:child.kill();child.wait()
        for handle in handles:handle.close()
        summary['remaining_worker_rows']=len(rows())
        summary['cleanup_issues']=cleanup_issues
        if cleanup_issues or summary['remaining_worker_rows']:summary['passed']=False
        if not summary['remaining_worker_rows']:
            for key in keys.glob('*'):key.unlink()
        (folder/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        print(json.dumps({'passed':summary['passed'],'scenario':mode,'report':str(folder/'summary.json'),'failure':summary.get('failure')}),flush=True)
    return summary


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--mode',choices=['idle','graceful','crash','rollout','recovered-stop','all'],default='all')
    parser.add_argument('--port',type=int,default=28640)
    args=parser.parse_args()
    binary=ROOT/'build/pacific-directory'
    subprocess.run(['go','-C','services/directory','build','-o',str(binary),'./cmd/pacific-directory'],cwd=ROOT,check=True)
    for index,mode in enumerate(['idle','graceful','crash','rollout','recovered-stop'] if args.mode=='all' else [args.mode]):scenario(mode,binary,args.port+index*60)


if __name__=='__main__':main()
