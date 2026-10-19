#!/usr/bin/env python3
"""Actual OCI init, eight-player race, directory crash/recovery and graceful stop.

All containers/volumes, keys and guests are unique to this invocation. No source
project is passed to the image's worker. No synthetic finishes or profiles.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import secrets
import signal
import socket
import sqlite3
import subprocess
import time
import urllib.error
import urllib.request
import uuid
from bootstrap import ROOT, engine


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--image',required=True)
    parser.add_argument('--context',type=Path,required=True)
    args=parser.parse_args()
    context=json.loads((args.context/'context.json').read_text())
    assert context['built'] and context['tag']==args.image
    identifier=uuid.uuid4().hex[:12]
    name='pacific-qa-'+identifier
    volumes=[name+'-data',name+'-logs']
    folder=ROOT/'reports'/('container-'+identifier)
    folder.mkdir(parents=True,mode=0o700)
    processes,handles=[],[]
    created_volumes=[]
    container_created=False
    stopper=None
    report={'passed':False,'image':context,'boundary':'Linux OCI image under a two-CPU cgroup quota / 1 GiB total memory, actual eight-human two-lap race. CI hardware, not a dedicated cloud-host or physical-device performance claim.'}

    def docker(*arguments,timeout=30):
        result=subprocess.run(['docker',*map(str,arguments)],capture_output=True,text=True,check=True,timeout=timeout)
        return result.stdout

    def wait_for(predicate,seconds,message):
        deadline=time.monotonic()+seconds
        while time.monotonic()<deadline:
            try:
                value=predicate()
                if value:return value
            except (OSError,ValueError,KeyError,sqlite3.Error,urllib.error.URLError,subprocess.CalledProcessError):pass
            if any(p.poll() not in [None,0] for p in processes):raise RuntimeError('Owned game client failed; inspect logs')
            time.sleep(.2)
        raise TimeoutError(message)

    def free_port(kind):
        with socket.socket(socket.AF_INET,kind) as probe:
            probe.bind(('127.0.0.1',0))
            return probe.getsockname()[1]
    public,private,udp=free_port(socket.SOCK_STREAM),free_port(socket.SOCK_STREAM),free_port(socket.SOCK_DGRAM)
    assert len({public,private,udp})==3
    url=f'http://127.0.0.1:{public}'

    def api(method,path,body=None,token='',expected=200):
        headers={'Content-Type':'application/json','X-Forwarded-Proto':'https'}
        if token:headers['Authorization']='Bearer '+token
        request=urllib.request.Request(url+path,data=json.dumps(body).encode() if body is not None else None,headers=headers,method=method)
        try:response=urllib.request.urlopen(request,timeout=15)
        except urllib.error.HTTPError as error:response=error
        with response:
            assert response.status==expected,'Unexpected container HTTP status'
            return json.load(response)

    def directory_pid():
        value=docker('exec',name,'cat','/tmp/pacific-directory.pid').strip()
        assert value.isdigit() and int(value)>1
        return value

    def worker_pid():
        # Host PIDs are compared only, never signaled. Select the actual worker
        # executable, excluding the wrapper/service's --worker argument.
        output=docker('top',name,'-eo','pid,args')
        values=[]
        for line in output.splitlines()[1:]:
            fields=line.strip().split(None,1)
            if len(fields)==2 and fields[1].startswith('/opt/pacific-rush/pacific-rush-server.x86_64 '):values.append(fields[0])
        assert len(values)==1,'Exactly one exported worker expected'
        return values[0]

    def snapshot(label):
        destination='/var/lib/pacific-rush/qa-'+label
        docker('exec',name,'/opt/pacific-rush/pacific-directory','backup','--db','/var/lib/pacific-rush/directory.sqlite','--keys','/var/lib/pacific-rush/keys','--backup',destination)
        local=folder/(label+'.sqlite')
        docker('cp',name+':'+destination+'/directory.sqlite',local)
        try:
            with sqlite3.connect('file:'+str(local)+'?mode=ro',uri=True) as db:
                rows=db.execute('SELECT id,heartbeat,drain_deadline,guests,performance FROM workers').fetchall()
                return [{'worker':row[0],'heartbeat':row[1],'drain_deadline':row[2],'guests':json.loads(row[3]),'performance':json.loads(row[4])} for row in rows]
        finally:local.unlink(missing_ok=True)

    try:
        inspect=json.loads(docker('image','inspect',args.image))[0]
        assert inspect['Id']==context['image_id'] and inspect['Config']['User']=='10001:10001'
        version=json.loads(docker('run','--rm',args.image,'version'))
        for key in ['version','commit','build_number','protocol_version','content_hash']:
            assert version[key]==context['game_build'][key]
        report['operator_identity']=version
        probe=docker('run','--rm','--entrypoint','/opt/pacific-rush/pacific-rush-server.x86_64',args.image,'--headless','--','--platform-probe')
        assert 'PACIFIC_PLATFORM_READY' in probe and 'ERROR:' not in probe
        report['native_probe']=probe
        for volume in volumes:
            docker('volume','create','--label','pacific.qa='+identifier,volume)
            created_volumes.append(volume)
        mounts=['--mount','type=volume,src='+volumes[0]+',dst=/var/lib/pacific-rush',
                '--mount','type=volume,src='+volumes[1]+',dst=/var/log/pacific-rush']
        docker('run','--rm',*mounts,args.image,'keygen','--keys','/var/lib/pacific-rush/keys')
        build=context['game_build']
        docker('run','--detach','--name',name,'--label','pacific.qa='+identifier,'--network','host',
               '--cpus','2','--memory','1g','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges:true',
               '--tmpfs','/tmp:rw,noexec,nosuid,size=64m,mode=1777',*mounts,
               '--env',f'PR_HEALTH_LISTEN=127.0.0.1:{public}',args.image,'serve',
               '--db=/var/lib/pacific-rush/directory.sqlite','--keys=/var/lib/pacific-rush/keys','--logs=/var/log/pacific-rush/pool-a',
               f'--listen=127.0.0.1:{public}',f'--private-listen=127.0.0.1:{private}','--public-url=https://container.invalid',
               '--worker-host=127.0.0.1','--worker=/opt/pacific-rush/pacific-rush-server.x86_64',f'--first-port={udp}',
               '--workers=1','--host-workers=1','--protocol='+str(build['protocol_version']),'--content-hash='+build['content_hash'])
        container_created=True
        wait_for(lambda:api('GET','/readyz')['status']=='ready',15,'Container did not become ready')
        docker('exec',name,'/opt/pacific-rush/pacific-directory','probe','--listen',f'127.0.0.1:{public}')
        identity_before=directory_pid()
        guests=[]
        for index in range(8):
            guest=str(uuid.uuid4())
            secret=base64.urlsafe_b64encode(secrets.token_bytes(32)).decode().rstrip('=')
            guests.append(api('POST','/v1/guests',{'guest_id':guest,'secret':secret,'display_name':'👨‍👩‍👧‍👦'*3+'a'+chr(97+index)},expected=201))
        versions={'protocol':build['protocol_version'],'content_hash':build['content_hash']}
        rules={'track':0,'laps':2,'bot_fill':False,'difficulty':1,'contact':True}
        created=api('POST','/v1/rooms',{'name':'Container QA','private':False,'region':'test','rules':rules,**versions},guests[0]['session_token'],201)
        tickets=[created['ticket']]
        for guest in guests[1:]:tickets.append(api('POST','/v1/rooms/'+created['room_id']+'/join',versions,guest['session_token'])['ticket'])
        for index,ticket in enumerate(tickets):
            handle=(folder/f'client-{index}.log').open('w');handles.append(handle)
            process=subprocess.Popen([str(engine()),'--headless','--path',str(ROOT),'--max-fps','60','--script','tests/lobby_network_client.gd','--',
                '--index='+str(index),'--port='+str(udp),'--races=1','--laps=2','--seconds=300','--report='+str(folder/f'client-{index}.json')],
                cwd=ROOT,env={**os.environ,'PR_TEST_TICKET':ticket},stdout=handle,stderr=subprocess.STDOUT)
            processes.append(process)
        wait_for(lambda:all('LOBBY_CLIENT_RACE_STARTED' in (folder/f'client-{i}.log').read_text() for i in range(8)),30,'Eight clients never reached Grid')
        time.sleep(7) # Ordinary three-second Grid has ended; no synthetic result.
        worker_before=worker_pid()
        before=snapshot('before')
        assert len(before)==1 and before[0]['worker']==created['worker_id']
        assert set(before[0]['guests'])=={g['guest_id'] for g in guests}
        report['before']=before
        # Kill only the verified directory child inside this uniquely owned image.
        role=docker('exec',name,'cat','/proc/'+identity_before+'/comm').strip()
        assert role.startswith('pacific-direct')
        docker('exec',name,'kill','-KILL',identity_before)
        wait_for(lambda:directory_pid()!=identity_before,12,'Init did not restart the crashed directory child')
        wait_for(lambda:api('GET','/readyz')['status']=='ready',12,'Replacement directory not ready')
        attempt=0
        def recovered_report():
            nonlocal attempt
            label='after-'+str(attempt);attempt+=1
            value=snapshot(label)
            return value if len(value)==1 and value[0]['heartbeat']>before[0]['heartbeat'] else False
        after=wait_for(recovered_report,18,'Recovered worker never authenticated a fresh heartbeat')
        assert after[0]['worker']==created['worker_id'] and after[0]['drain_deadline']>0
        assert set(after[0]['guests'])=={g['guest_id'] for g in guests}
        assert worker_pid()==worker_before,'Image restarted the actual race worker'
        report['after']=after
        # The new Go allocator has no owned child. It must still supervise the
        # recovered worker until its genuine race completes during planned stop.
        handle=(folder/'stop.log').open('w');handles.append(handle)
        stopper=subprocess.Popen(['docker','stop','--time','660',name],stdout=handle,stderr=subprocess.STDOUT)
        time.sleep(2)
        assert stopper.poll() is None,'Container exited while its recovered race was still active'
        wait_for(lambda:all(p.poll() is not None for p in processes),310,'Eight actual racers did not finish')
        clients=[json.loads((folder/f'client-{i}.json').read_text()) for i in range(8)]
        races=clients[0]['results']
        assert len(races)==1 and len(races[0]['rows'])==8
        assert all(p.returncode==0 for p in processes) and all(c['results']==races and c['large_racing_events']==0 for c in clients)
        assert {r['id'] for r in races[0]['rows']}=={g['guest_id'] for g in guests}
        assert all(not r['bot'] and not r['dnf'] for r in races[0]['rows'])
        assert {int(r['car']) for r in races[0]['rows']}=={0,1,2,3}
        assert stopper.wait(timeout=30)==0
        state=json.loads(docker('inspect',name))[0]['State']
        assert not state['Running'] and state['ExitCode']==0 and not state['OOMKilled']
        report.update(passed=True,finishes=8,same_worker_process=True,same_eight_identities=True,identical_results=True,
                      graceful_stop_waited_for_recovered_race=True,no_synthetic_finish=True,container_exit=state['ExitCode'],
                      clients=clients,engine_version=docker('version','--format','{{.Server.Version}}').strip())
    except Exception as error:
        report['failure']=type(error).__name__+': '+str(error)
        raise
    finally:
        cleanup=[]
        for process in processes:
            if process.poll() is None:process.terminate()
        for process in processes:
            try:process.wait(timeout=5)
            except subprocess.TimeoutExpired:process.kill();process.wait()
        if container_created:
            try:(folder/'container.log').write_text(docker('logs',name))
            except Exception:cleanup.append('container log unavailable')
            try:docker('rm','--force',name,timeout=30)
            except Exception:cleanup.append('owned container removal failed')
        if stopper and stopper.poll() is None:
            try:stopper.wait(timeout=10)
            except subprocess.TimeoutExpired:stopper.terminate();stopper.wait()
        for handle in handles:handle.close()
        for volume in created_volumes:
            try:docker('volume','rm',volume)
            except Exception:cleanup.append('owned temporary volume removal failed')
        report['cleanup_issues']=cleanup
        if cleanup:report['passed']=False
        (folder/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({'passed':report['passed'],'summary':str(folder/'summary.json')}),flush=True)
    if not report['passed']:raise SystemExit(1)


if __name__=='__main__':main()
