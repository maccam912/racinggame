#!/usr/bin/env python3
"""Real CLI backup/restart/auth drill with entirely temporary local identities."""
import base64
import hashlib
import hmac
import json
import os
from pathlib import Path
import secrets
import signal
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
from bootstrap import ROOT


def main():
    folder = ROOT/'reports'/('directory-backup-'+uuid.uuid4().hex[:10])
    folder.mkdir(parents=True, mode=0o700)
    summary = {'passed':False, 'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
               'boundary':'Compiled operator CLI; explicit loopback HTTP fixture with temporary keys, guests and databases. No public region or operated backup schedule.'}
    checks = {}
    process = None
    handles = []
    try:
        with tempfile.TemporaryDirectory(prefix='pacific-backup-') as temporary:
            root = Path(temporary)
            binary, keys, database = root/'pacific-directory', root/'keys', root/'live.sqlite'
            subprocess.run(['go','-C',str(ROOT/'services/directory'),'build','-o',str(binary),'./cmd/pacific-directory'],check=True,capture_output=True)
            def command(*args, ok=True):
                result = subprocess.run([str(binary),*map(str,args)],capture_output=True,text=True,timeout=30)
                assert (result.returncode == 0) == ok, 'Unexpected operator command status'
                return json.loads(result.stdout) if ok and result.stdout.strip() else None
            command('keygen','--keys',keys)
            def port():
                with socket.socket() as probe:
                    probe.bind(('127.0.0.1',0))
                    return probe.getsockname()[1]
            public, private = port(), port()
            assert public != private
            url = f'http://127.0.0.1:{public}'
            def start(path, stage):
                nonlocal process
                handle = (folder/(stage+'.log')).open('w');handles.append(handle)
                process = subprocess.Popen([str(binary),'serve','--db',str(path),'--keys',str(keys),'--logs',str(root/(stage+'-logs')),
                    '--listen',f'127.0.0.1:{public}','--private-listen',f'127.0.0.1:{private}',
                    '--public-url',url,'--allow-insecure-loopback','--worker',sys.executable,
                    '--protocol','5','--content-hash','a'*64],stdout=handle,stderr=subprocess.STDOUT)
                deadline = time.monotonic()+10
                while True:
                    assert process.poll() is None and time.monotonic() < deadline, 'Drill service did not start'
                    try:
                        with urllib.request.urlopen(url+'/readyz',timeout=1) as response:
                            assert response.status == 200
                        break
                    except (urllib.error.URLError,ConnectionError):time.sleep(.05)
            def stop():
                nonlocal process
                if process is not None:
                    process.send_signal(signal.SIGINT)
                    assert process.wait(timeout=10) == 0, 'Drill service did not stop cleanly'
                    process = None
            def post(path, body, expected=200):
                request = urllib.request.Request(url+path,json.dumps(body).encode(),{'Content-Type':'application/json'})
                try:response = urllib.request.urlopen(request,timeout=5)
                except urllib.error.HTTPError as error:response = error
                with response:
                    assert response.status == expected, 'Unexpected drill HTTP status'
                    return json.load(response)
            encode = lambda data:base64.urlsafe_b64encode(data).decode().rstrip('=')
            guest, banned = str(uuid.uuid4()), str(uuid.uuid4())
            secret, banned_secret = secrets.token_bytes(32), secrets.token_bytes(32)
            name = 'Backup Driver'
            start(database,'before')
            session = post('/v1/guests',{'guest_id':guest,'secret':encode(secret),'display_name':name},201)
            post('/v1/guests',{'guest_id':banned,'secret':encode(banned_secret),'display_name':'Banned Driver'},201)
            command('ban','--db',database,'--guest',banned)
            old_nonce = post('/v1/auth/challenge',{'guest_id':guest})['nonce']
            backup = root/'snapshot'
            result = command('backup','--db',database,'--keys',keys,'--backup',backup)
            checks['live_cli_backup'] = result['backup']['schema'] == 3 and result['backup']['bytes'] >= 4096
            summary['snapshot'] = result['backup']
            before = (backup/'directory.sqlite').read_bytes()
            command('backup','--db',database,'--keys',keys,'--backup',backup,ok=False)
            checks['existing_backup_refused'] = (backup/'directory.sqlite').read_bytes() == before
            restored = root/'restored.sqlite'
            command('restore','--backup',backup,'--keys',keys,'--out',restored)
            command('restore','--backup',backup,'--keys',keys,'--out',restored,ok=False)
            checks['backup_unchanged'] = (backup/'directory.sqlite').read_bytes() == before
            with sqlite3.connect('file:'+str(restored)+'?mode=ro',uri=True) as db:
                checks['two_guests_preserved'] = db.execute('SELECT count(*) FROM guests').fetchone()[0] == 2
                checks['no_ephemeral_leases_or_replay_state'] = all(db.execute('SELECT count(*) FROM '+table).fetchone()[0] == 0 for table in ['workers','rooms','reservations','worker_commands','nonces','sessions'])
                checks['ban_preserved'] = db.execute('SELECT banned FROM guests WHERE id=?',(banned,)).fetchone()[0] == 1
            stop()
            start(restored,'after')
            old_proof = encode(hmac.digest(secret,('pacific-rush-auth-v1\n'+guest+'\n'+old_nonce+'\n'+name).encode(),'sha256'))
            replay = post('/v1/auth/session',{'guest_id':guest,'nonce':old_nonce,'proof':old_proof,'display_name':name},401)
            checks['old_nonce_refused'] = replay['error']['code'] == 'invalid_auth'
            nonce = post('/v1/auth/challenge',{'guest_id':guest})['nonce']
            proof = encode(hmac.digest(secret,('pacific-rush-auth-v1\n'+guest+'\n'+nonce+'\n'+name).encode(),'sha256'))
            recovered = post('/v1/auth/session',{'guest_id':guest,'nonce':nonce,'proof':proof,'display_name':name})
            checks['original_guest_reauth'] = recovered['guest_id'] == guest and recovered['session_token'] != session['session_token']
            rejection = post('/v1/guests',{'guest_id':banned,'secret':encode(banned_secret),'display_name':'Banned Driver'},409)
            checks['banned_guest_refused'] = rejection['error']['code'] == 'invalid_guest'
            checks['file_mode'] = os.stat(restored).st_mode & 0o777 == 0o600
            stop()
            checks['no_keys_in_backup'] = sorted(path.name for path in backup.iterdir()) == ['directory.sqlite','manifest.json']
            summary['passed'] = all(checks.values())
            assert summary['passed'], 'Backup drill acceptance failed'
        summary['temporary_data_removed'] = not Path(temporary).exists()
    finally:
        if process is not None and process.poll() is None:
            process.send_signal(signal.SIGINT)
            try:process.wait(timeout=10)
            except subprocess.TimeoutExpired:process.kill();process.wait()
        for handle in handles:handle.close()
        summary['checks'] = checks
        (folder/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        print(json.dumps({'passed':summary['passed'],'summary':str(folder/'summary.json')}),flush=True)


if __name__ == '__main__':
    main()
