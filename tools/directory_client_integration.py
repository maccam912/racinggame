#!/usr/bin/env python3
"""Exercise the actual game client over isolated Caddy HTTPS and Go workers."""
import argparse
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
    parser=argparse.ArgumentParser()
    parser.add_argument("--menu",action="store_true")
    parser.add_argument("--visual",action="store_true")
    parser.add_argument("--hold",action="store_true",help="Keep the isolated service running for manual game checks")
    parser.add_argument("--android",action="store_true",help="Advertise the emulator host gateway to workers")
    args=parser.parse_args()
    if args.hold and args.menu:parser.error("--hold and --menu are separate modes")
    if args.android and not args.hold:parser.error("--android requires --hold")
    if args.visual and not args.menu:parser.error("--visual requires --menu")
    folder=ROOT/'reports'/('directory-client-'+str(uuid.uuid4()))
    folder.mkdir(parents=True,mode=0o700)
    binary=ROOT/'build/pacific-directory'
    binary.parent.mkdir(exist_ok=True)
    url='https://localhost:29543'
    for port,kind in [(29543,socket.SOCK_STREAM),(29880,socket.SOCK_STREAM),(29881,socket.SOCK_STREAM),*[(27230+i,socket.SOCK_DGRAM) for i in range(4)]]:
        with socket.socket(socket.AF_INET,kind) as probe:
            if kind==socket.SOCK_STREAM:probe.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
            probe.bind(('127.0.0.1',port))
    subprocess.run(['go','-C','services/directory','build','-o',str(binary),'./cmd/pacific-directory'],cwd=ROOT,check=True)
    subprocess.run([str(binary),'keygen','--keys',str(folder/'keys')],check=True)
    versions={'protocol':json.loads((ROOT/'game/content/rules.json').read_text())['protocol_version'],'content_hash':json.loads((ROOT/'game/content/compatibility.json').read_text())['content_hash']}
    processes,handles=[],[]
    summary={'passed':False,'transport':'HTTPS with scoped isolated CA; no system trust changes','identity_backend':'in-memory protected-store fixture; real OS persistence has separate native gates'}
    try:
        output=(folder/'directory.log').open('w');handles.append(output)
        service=subprocess.Popen([str(binary),'serve','--db',str(folder/'directory.sqlite'),'--keys',str(folder/'keys'),'--logs',str(folder/'logs'),'--listen','127.0.0.1:29880','--private-listen','127.0.0.1:29881','--public-url',url,'--worker',str(engine()),'--worker-project',str(ROOT),'--first-port','27230','--workers','4','--worker-host','10.0.2.2' if args.android else '127.0.0.1','--protocol',str(versions['protocol']),'--content-hash',versions['content_hash']],stdout=output,stderr=subprocess.STDOUT);processes.append(service)
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
        if args.hold:
            connection=folder/'connection.json'
            connection.write_text(json.dumps({'url':url,'ca':str(ca),'worker_host':'10.0.2.2' if args.android else '127.0.0.1'},indent=2)+'\n')
            print(json.dumps({'ready':True,'connection':str(connection)}),flush=True)
            summary.update(passed=True,kind='manual local HTTPS fixture; game behavior checked separately')
            try:
                while service.poll() is None and proxy.poll() is None:time.sleep(.2)
                raise RuntimeError('Manual directory fixture stopped unexpectedly')
            except KeyboardInterrupt:
                return
        output=(folder/'client.log').open('w');handles.append(output)
        display=[] if args.visual else ['--headless']
        visual_dir=folder/'visuals'
        if args.visual:visual_dir.mkdir()
        game=subprocess.Popen([str(engine()),*display,'--resolution','1280x720','--path',str(ROOT),'--script','tests/online_https_menu.gd' if args.menu else 'tests/directory_https_client.gd','--','--profile=menu_https_'+folder.name[-12:].replace('-','_'),'--directory-url='+url,'--directory-ca='+str(ca),'--logs='+str(folder/'logs'),*(['--visual-dir='+str(visual_dir)] if args.visual else [])],stdout=output,stderr=subprocess.STDOUT)
        processes.append(game)
        deadline=time.monotonic()+90
        while game.poll() is None:
            if 'ERROR:' in (folder/'client.log').read_text():raise RuntimeError('Game client reported an error; inspect client.log')
            if time.monotonic()>deadline:raise RuntimeError('Game client fixture timed out')
            time.sleep(.05)
        text=(folder/'client.log').read_text()
        assert game.returncode==0 and ('ONLINE_HTTPS_MENU_COMPLETE_PASS' if args.menu else 'DIRECTORY_HTTPS_CLIENT_AUTH_ALLOCATE_ENET_CODE_REAUTH_PASS') in text and 'ERROR:' not in text,'Game directory client fixture failed; inspect client.log'
        summary.update(passed=True,menu=args.menu,visual=args.visual,checks=['region and empty browser','HTTPS registration','cold protected payload reload and nonce/HMAC session','public allocation and browser reservation','real signed-ticket ENet admission','one 401 reauthentication retry retains guest UUID','private code visibility and generic failure','formatted code join','explicit leave','credentials absent from logs and profile'])
        if args.menu:
            summary['identity_backend']='game OS-protected adapter when available, otherwise explicit session-only identity'
            summary['actual_identity_backend']=next((line.split(' ',1)[1] for line in text.splitlines() if line.startswith('MENU_IDENTITY_BACKEND ')),'unknown')
            summary['checks']=['three verified region probes','create form rules and official lobby','ready/start through staged local world and collision-ready acknowledgement','public browser row admission','formatted private code join','code show/hide','Quick Join','same guest UUID across menu joins','Data reset erases protected identity']
    finally:
        for process in reversed(processes):
            if process.poll() is None:
                process.send_signal(signal.SIGINT)
                try:process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    if process is service:
                        # The first signal drains real races; this fixture has
                        # already stopped its clients and now forces only its
                        # own supervised pool through the explicit second signal.
                        process.send_signal(signal.SIGINT)
                        try:process.wait(timeout=10)
                        except subprocess.TimeoutExpired:process.kill();process.wait()
                    else:process.kill();process.wait()
        if args.menu:
            with (folder/'cleanup.log').open('w') as output:
                cleanup=subprocess.run([str(engine()),'--headless','--path',str(ROOT),'--script','tests/cleanup_guest_fixture.gd','--','--profile=menu_https_'+folder.name[-12:].replace('-','_')],stdout=output,stderr=subprocess.STDOUT,timeout=20)
            summary['profile_cleanup']=cleanup.returncode==0 and 'ERROR:' not in (folder/'cleanup.log').read_text()
            summary['passed']=summary['passed'] and summary['profile_cleanup']
        for handle in handles:handle.close()
        for key in (folder/'keys').glob('*'):key.unlink()
        for key in (folder/'data').rglob('*.key'):key.unlink()
        (folder/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        print(json.dumps({'passed':summary['passed'],'report':str(folder/'summary.json')}))
    if not summary['passed']:raise RuntimeError('Directory fixture or cleanup failed')


if __name__=='__main__':main()
