#!/usr/bin/env python3
"""Exercise the actual game client over isolated Caddy HTTPS and Go workers."""
import json
import os
from pathlib import Path
import signal
import socket
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from bootstrap import ROOT,engine
from caddy_bootstrap import caddy


def main():
    folder=ROOT/'reports'/('directory-client-'+str(uuid.uuid4()))
    folder.mkdir(parents=True,mode=0o700)
    binary=ROOT/'build/pacific-directory'
    binary.parent.mkdir(exist_ok=True)
    url='https://localhost:29543'
    for port,kind in [(29543,socket.SOCK_STREAM),(29880,socket.SOCK_STREAM),(29881,socket.SOCK_STREAM),*[(27230+i,socket.SOCK_DGRAM) for i in range(4)]]:
        with socket.socket(socket.AF_INET,kind) as probe:probe.bind(('127.0.0.1',port))
    subprocess.run(['go','-C','services/directory','build','-o',str(binary),'./cmd/pacific-directory'],cwd=ROOT,check=True)
    subprocess.run([str(binary),'keygen','--keys',str(folder/'keys')],check=True)
    versions={'protocol':json.loads((ROOT/'game/content/rules.json').read_text())['protocol_version'],'content_hash':json.loads((ROOT/'game/content/compatibility.json').read_text())['content_hash']}
    processes,handles=[],[]
    summary={'passed':False,'transport':'HTTPS with scoped isolated CA; no system trust changes','identity_backend':'in-memory protected-store fixture; real OS persistence has separate native gates'}
    try:
        output=(folder/'directory.log').open('w');handles.append(output)
        service=subprocess.Popen([str(binary),'serve','--db',str(folder/'directory.sqlite'),'--keys',str(folder/'keys'),'--logs',str(folder/'logs'),'--listen','127.0.0.1:29880','--private-listen','127.0.0.1:29881','--public-url',url,'--worker',str(engine()),'--worker-project',str(ROOT),'--first-port','27230','--workers','4','--protocol',str(versions['protocol']),'--content-hash',versions['content_hash']],stdout=output,stderr=subprocess.STDOUT);processes.append(service)
        deadline=time.monotonic()+10
        while 'PACIFIC_DIRECTORY_READY' not in (folder/'directory.log').read_text():
            if service.poll() is not None or time.monotonic()>deadline:raise RuntimeError('Directory fixture did not start')
            time.sleep(.05)
        output=(folder/'caddy.log').open('w');handles.append(output)
        environment={**os.environ,'XDG_DATA_HOME':str(folder/'data'),'XDG_CONFIG_HOME':str(folder/'config'),'PR_PUBLIC_ADDRESS':url,'PR_BIND_ADDRESS':'127.0.0.1','PR_DIRECTORY_UPSTREAM':'127.0.0.1:29880','PR_CADDY_TLS':'tls-test.caddy'}
        proxy=subprocess.Popen([str(caddy()),'run','--config',str(ROOT/'services/directory/deploy/Caddyfile'),'--adapter','caddyfile'],env=environment,stdout=output,stderr=subprocess.STDOUT);processes.append(proxy)
        ca=folder/'data/caddy/pki/authorities/local/root.crt';deadline=time.monotonic()+15
        while not ca.exists():
            if proxy.poll() is not None or time.monotonic()>deadline:raise RuntimeError('Isolated HTTPS fixture did not start')
            time.sleep(.05)
        context=ssl.create_default_context(cafile=str(ca))
        while True:
            try:
                with urllib.request.urlopen(url+'/readyz',context=context,timeout=2) as reply:
                    assert reply.status==200
                break
            except (urllib.error.URLError,ConnectionError):
                if time.monotonic()>deadline:raise
                time.sleep(.05)
        with (folder/'client.log').open('w') as output:
            result=subprocess.run([sys.executable,str(ROOT/'tools/godot.py'),'--headless','--script','tests/directory_https_client.gd','--','--directory-url='+url,'--directory-ca='+str(ca),'--logs='+str(folder/'logs')],stdout=output,stderr=subprocess.STDOUT,timeout=90)
        text=(folder/'client.log').read_text()
        assert result.returncode==0 and 'DIRECTORY_HTTPS_CLIENT_AUTH_ALLOCATE_ENET_CODE_REAUTH_PASS' in text and 'ERROR:' not in text,'Game directory client fixture failed; inspect client.log'
        summary.update(passed=True,checks=['region and empty browser','HTTPS registration','cold protected payload reload and nonce/HMAC session','public allocation and browser reservation','real signed-ticket ENet admission','one 401 reauthentication retry retains guest UUID','private code visibility and generic failure','formatted code join','explicit leave','credentials absent from logs and profile'])
    finally:
        for process in reversed(processes):
            if process.poll() is None:
                process.send_signal(signal.SIGINT)
                try:process.wait(timeout=10)
                except subprocess.TimeoutExpired:process.kill();process.wait()
        for handle in handles:handle.close()
        for key in (folder/'keys').glob('*'):key.unlink()
        for key in (folder/'data').rglob('*.key'):key.unlink()
        (folder/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        print(json.dumps({'passed':summary['passed'],'report':str(folder/'summary.json')}))


if __name__=='__main__':main()
