#!/usr/bin/env python3
"""Pinned Caddy -> real Go TLS auth, proxy/rate and private-route boundaries."""
import base64
import hashlib
import hmac
import json
import os
import signal
import ssl
import subprocess
import time
import urllib.error
import urllib.request
import uuid
from bootstrap import ROOT, engine
from caddy_bootstrap import caddy


def run():
    folder=ROOT/'reports'/f'caddy-{uuid.uuid4()}'
    folder.mkdir(mode=0o700,parents=True)
    keys=folder/'keys';binary=ROOT/'build/pacific-directory'
    binary.parent.mkdir(parents=True,exist_ok=True)
    subprocess.run(['go','-C','services/directory','build','-o',str(binary),'./cmd/pacific-directory'],cwd=ROOT,check=True)
    subprocess.run([str(binary),'keygen','--keys',str(keys)],check=True)
    versions={'protocol':json.loads((ROOT/'game/content/rules.json').read_text())['protocol_version'],'content_hash':json.loads((ROOT/'game/content/compatibility.json').read_text())['content_hash']}
    processes,handles=[],[];url='https://localhost:29443'
    secret=base64.urlsafe_b64encode(os.urandom(32)).decode().rstrip('=')
    def request(method,path,body=None,expected=200,headers=None,base=url,context=None):
        req=urllib.request.Request(base+path,method=method,data=json.dumps(body).encode() if body is not None else None,headers={'Content-Type':'application/json',**(headers or {})})
        try:
            with urllib.request.urlopen(req,context=context,timeout=10) as response:status,data=response.status,response.read()
        except urllib.error.HTTPError as error:status,data=error.code,error.read()
        assert status==expected,f'{method} {path} got {status}, expected {expected}'
        return json.loads(data) if data and data.startswith(b'{') else None
    try:
        output=(folder/'directory.log').open('w');handles.append(output)
        directory=subprocess.Popen([str(binary),'serve','--db',str(folder/'directory.sqlite'),'--keys',str(keys),'--logs',str(folder/'logs'),'--listen','127.0.0.1:29080','--private-listen','127.0.0.1:29081','--public-url',url,'--worker',str(engine()),'--protocol',str(versions['protocol']),'--content-hash',versions['content_hash'],'--ip-api-limit','12'],stdout=output,stderr=subprocess.STDOUT);processes.append(directory)
        deadline=time.monotonic()+10
        while 'PACIFIC_DIRECTORY_READY' not in (folder/'directory.log').read_text():
            if directory.poll() is not None or time.monotonic()>deadline:raise RuntimeError('Directory startup failed')
            time.sleep(.05)
        output=(folder/'caddy.log').open('w');handles.append(output)
        env={**os.environ,'XDG_DATA_HOME':str(folder/'data'),'XDG_CONFIG_HOME':str(folder/'config'),'PR_PUBLIC_ADDRESS':url,'PR_BIND_ADDRESS':'127.0.0.1','PR_DIRECTORY_UPSTREAM':'127.0.0.1:29080','PR_CADDY_TLS':'tls-test.caddy'}
        proxy=subprocess.Popen([str(caddy()),'run','--config',str(ROOT/'services/directory/deploy/Caddyfile'),'--adapter','caddyfile'],env=env,stdout=output,stderr=subprocess.STDOUT);processes.append(proxy)
        root=folder/'data/caddy/pki/authorities/local/root.crt';deadline=time.monotonic()+15
        while not root.exists():
            if proxy.poll() is not None or time.monotonic()>deadline:raise RuntimeError('Isolated Caddy TLS startup failed; inspect caddy.log')
            time.sleep(.05)
        context=ssl.create_default_context(cafile=str(root))
        while True:
            try:request('GET','/healthz',context=context);break
            except (urllib.error.URLError,ConnectionError):
                if time.monotonic()>deadline:raise
                time.sleep(.05)
        request('GET','/healthz',base='http://127.0.0.1:29080',expected=400)
        request('POST','/workers/'+str(uuid.uuid4())+'/heartbeat',{},expected=404,context=context)
        request('POST','/workers/'+str(uuid.uuid4())+'/heartbeat',{'state':'Lobby','ready':True,'guests':[],'name':'Test Room','rules':{'track':0,'laps':1,'bot_fill':False,'difficulty':1,'contact':True},'private':False,'acknowledged':[]},expected=401,base='http://127.0.0.1:29081')
        guest=str(uuid.uuid4());session=request('POST','/v1/guests',{'guest_id':guest,'secret':secret,'display_name':'Cafe\u0301 Driver'},201,context=context)
        challenge=request('POST','/v1/auth/challenge',{'guest_id':guest},context=context)
        message=f'pacific-rush-auth-v1\n{guest}\n{challenge["nonce"]}\nCafé Driver'.encode()
        proof=base64.urlsafe_b64encode(hmac.new(base64.urlsafe_b64decode(secret+'='),message,hashlib.sha256).digest()).decode().rstrip('=')
        auth={'guest_id':guest,'nonce':challenge['nonce'],'proof':proof,'display_name':'Café Driver'}
        authenticated=request('POST','/v1/auth/session',auth,context=context);assert authenticated['guest_id']==guest and authenticated['display_name']=='Café Driver'
        request('POST','/v1/auth/session',auth,401,context=context)
        # Caddy replaces untrusted forwarding fields. Changing a forged source
        # address must not create a fresh API quota for each request.
        limited=False
        for index in range(20):
            try:request('GET','/v1/regions',headers={'X-Forwarded-For':f'198.51.100.{index+1}','X-Forwarded-Proto':'http'},context=context)
            except AssertionError as error:
                if 'got 429' not in str(error):raise
                limited=True;break
        assert limited,'Spoofed forwarding headers bypassed IP quota'
        for path in [folder/'caddy.log',folder/'directory.log',*(folder/'logs').glob('*.jsonl')]:
            text=path.read_text();assert secret not in text and session['session_token'] not in text and authenticated['session_token'] not in text,'Credential entered operational logs'
        summary={'passed':True,'caddy':'2.11.7','transport':'loopback TLS, isolated test CA, no system trust modification','checks':['HTTPS registration/auth and NFC HMAC','nonce replay','direct HTTP denied','private worker route absent publicly','private credential required','forwarded-IP spoof cannot evade quota','credentials absent from logs']}
        (folder/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps({'passed':True,'report':str(folder/'summary.json')}),flush=True)
    finally:
        for process in reversed(processes):
            if process.poll() is None:
                process.send_signal(signal.SIGINT)
                try:process.wait(timeout=10)
                except subprocess.TimeoutExpired:process.kill();process.wait()
        for handle in handles:handle.close()
        for key in keys.glob('*'):key.unlink()
        # Remove the isolated local CA's private material too.
        for key in (folder/'data').rglob('*.key'):key.unlink()


if __name__=='__main__':run()
