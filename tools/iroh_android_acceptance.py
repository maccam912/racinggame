#!/usr/bin/env python3
"""Installed release APK plus seven native clients through the shared Iroh service."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import uuid
from bootstrap import ROOT, engine


def run(args):
    assert args.serial.startswith('emulator-'), 'Select an owned emulator explicitly'
    adb = [str(args.adb),'-s',args.serial]
    def device(*values):
        return subprocess.check_output([*adb,*values],stderr=subprocess.STDOUT)
    assert device('shell','id','-u').strip()==b'0' and device('shell','getprop','ro.kernel.qemu').strip()==b'1'
    wifi_before = device('shell','settings','get','global','wifi_on').decode().strip()
    apk = args.apk.resolve()
    folder = ROOT/'reports'/('iroh-android-'+uuid.uuid4().hex[:10]); folder.mkdir(parents=True)
    profile = 'iroh_'+uuid.uuid4().hex[:12]
    profile_path = '/data/user/0/dev.pacificrush.game/files/diagnostic_profiles/'+profile
    command = [str(engine()),'--path',str(ROOT),'--headless','--max-fps','60']
    children, handles = [], []
    report = {'passed':False,'serial':args.serial,'profile':profile,'apk_sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),
              'wifi_before':wifi_before,'temporary_wifi_enabled':args.enable_wifi,
              'boundary':'Installed release APK on an owned emulator, live shared rendezvous, native Iroh, seven desktop clients and two races. No physical hardware or cellular transition claim.'}
    def start(values,name):
        handle = (folder/name).open('w'); handles.append(handle)
        child = subprocess.Popen([*command,*values],stdout=handle,stderr=subprocess.STDOUT)
        children.append(child); return child
    def wait_for(condition,seconds):
        deadline = time.monotonic()+seconds
        while time.monotonic()<deadline:
            if condition(): return
            if any(p.poll() not in [None,0] for p in children): raise RuntimeError('Native Iroh fixture failed')
            time.sleep(.2)
        raise TimeoutError('Iroh Android fixture condition timed out')
    try:
        if args.enable_wifi:
            device('shell','svc','wifi','enable')
            wait_for(lambda:b'Wifi is connected' in device('shell','cmd','wifi','status'),30)
        probe = subprocess.run([*adb,'shell','ping','-c','1','-W','2','1.1.1.1'],capture_output=True)
        assert b'Network is unreachable' not in probe.stdout+probe.stderr, 'Emulator has no network route'
        # Installation is a separate byte-preserving update gate; require these
        # exact APK bytes instead of silently replacing any installed package.
        source = device('shell','pm','path','dev.pacificrush.game').decode().strip().removeprefix('package:')
        assert device('shell','sha256sum',source).decode().split()[0]==report['apk_sha256']
        device('shell','am','force-stop','dev.pacificrush.game')
        handle = (folder/'android.log').open('w'); handles.append(handle)
        log = subprocess.Popen([*adb,'logcat','-T','1','-v','raw','-s','godot'],stdout=handle,stderr=subprocess.STDOUT)
        children.append(log)
        host_path = folder/'host.json'
        host = start(['--script','tests/iroh_host.gd','--','--network-evidence',f'--report={host_path}'],'host.log')
        wait_for(host_path.exists,60)
        hosting = json.loads(host_path.read_text()); report['hosting'] = hosting
        clients = []
        for index in range(7):
            clients.append(start(['--script','tests/lobby_network_client.gd','--',f'--index={index}',
                f'--iroh-code={hosting["code"]}',f'--report={folder/f"client-{index}.json"}',
                '--latency-ms=50','--jitter-ms=20','--loss=0.01','--seconds=420'],f'client-{index}.log'))
        device('shell','am','start','-W','-n','dev.pacificrush.game/com.godot.game.GodotApp','--esa','command_line_params',
               '--,--profile='+profile+',--join-code='+hosting['code']+',--autodrive,--network-evidence')
        pid = ''
        captured = set()
        def complete():
            nonlocal pid
            text = (folder/'android.log').read_text(errors='replace')
            assert not any(marker in text for marker in ['SCRIPT ERROR:','ERROR:','Reconnect expired'])
            observed = device('shell','pidof','dev.pacificrush.game').decode().strip()
            if observed:
                if not pid: pid = observed
                assert observed==pid, 'Android process restarted'
            drives = text.count('PACIFIC_RUSH_DRIVING_READY')
            count = len(re.findall(r'PACIFIC_RUSH_CLIENT_RESULTS_DIGEST (\d+) (\d+) ([a-f0-9]{64})',text))
            if drives and ('grid',drives) not in captured:
                (folder/f'android-grid-{drives}.png').write_bytes(device('exec-out','screencap','-p')); captured.add(('grid',drives))
            if count and ('results',count) not in captured:
                (folder/f'android-results-{count}.png').write_bytes(device('exec-out','screencap','-p')); captured.add(('results',count))
            return count==2 and all(p.poll() is not None for p in clients)
        wait_for(complete,440)
        values = [json.loads((folder/f'client-{index}.json').read_text()) for index in range(7)]
        races = values[0]['results']
        assert all(value['results']==races and value['loaded_tracks']==[0,1] for value in values)
        assert len(races)==2 and all(len(race['rows'])==8 and all(not row['bot'] and row['dnf']=='' for row in race['rows']) for race in races)
        text = (folder/'android.log').read_text()
        hashes = re.findall(r'PACIFIC_RUSH_CLIENT_RESULTS_DIGEST (\d+) (\d+) ([a-f0-9]{64})',text)
        assert [digest for _,_,digest in hashes]==values[0]['result_hashes'] and all(count=='8' for _,count,_ in hashes)
        assert text.count('PACIFIC_RUSH_GRAPHICS_PREPARED')==2
        time.sleep(.8)
        saved = json.loads(device('shell','cat',profile_path+'/profile.json'))
        assert saved['payload']['races_completed']==2
        (folder/'android-profile.json').write_text(json.dumps(saved,indent=2)+'\n')
        host_path.with_suffix('.json.stop').touch(); host.wait(timeout=20)
        report.update(passed=True,native_clients=7,android_clients=1,finishes=16,results=races,
                      identical_result_digests=True,same_android_pid=pid,graphics_loads=2,result_commits=2,clients=values)
    except BaseException as error:
        report['failure'] = type(error).__name__+': '+str(error)
    finally:
        for child in children:
            if child.poll() is None:
                child.terminate()
                try: child.wait(timeout=5)
                except subprocess.TimeoutExpired: child.kill(); child.wait()
        device('shell','am','force-stop','dev.pacificrush.game')
        if args.enable_wifi and wifi_before=='0': device('shell','svc','wifi','disable')
        # Keep the new diagnostic profile and its exact scope recorded for
        # review; unrelated files and profiles are never deleted.
        for handle in handles: handle.close()
        (folder/'summary.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
        print(json.dumps({'passed':report['passed'],'report':str(folder/'summary.json'),'failure':report.get('failure')}))
    return 0 if report['passed'] else 1


if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('apk',type=Path)
    parser.add_argument('--serial',required=True)
    parser.add_argument('--enable-wifi',action='store_true',help='Temporarily enable test-emulator Wi-Fi and restore its original state')
    parser.add_argument('--adb',type=Path,default=Path.home()/'Library/Android/sdk/platform-tools/adb')
    raise SystemExit(run(parser.parse_args()))
