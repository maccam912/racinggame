"""Owned emulator UI reference through the game's existing capture entry point."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
ADB = str(Path.home()/'Library/Android/sdk/platform-tools/adb')
OUT = ROOT/'reports'/('android-ui101-'+uuid.uuid4().hex[:10])
OUT.mkdir()
build = json.loads((ROOT/'build/download/pacific-rush-00101-android-build.json').read_text())
assert not build['working_tree_dirty'] and build['commit']=='8545b3c09f74d68d3213ff89fdf4d405792d7cbd'
summary = {'passed':False,'build':build,'captures':[],
           'boundary':'Actual installed clean-source release-mode APK main menus on Android 15 ARM64 emulators, captured by existing in-game GPU readback. Synthetic owned profiles; no source UI overrides, physical input, thermal or minimum-hardware claim.'}

def adb(serial, *args, check=True):
    return subprocess.run([ADB,'-s',serial,*args],capture_output=True,check=check)

try:
    for serial, name in [('emulator-5580','phone'),('emulator-5582','tablet')]:
        assert adb(serial,'shell','getprop','ro.kernel.qemu').stdout.strip()==b'1'
        for scale in [100,150]:
            profile = 'm6_ui101_'+uuid.uuid4().hex[:12]
            remote = '/data/user/0/dev.pacificrush.game/files/diagnostic_profiles/'+profile
            dest = OUT/(name+'-'+str(scale));dest.mkdir()
            now = datetime.now(timezone.utc).isoformat()
            payload = {'display_name':'Coast Driver','selected_car':0,'selected_paint':0,
                       'first_run_complete':True,'school_steps':[False]*5,'races_completed':0,
                       'distance_m':0.0,'trophies':[],'ledger':{},'guest_reference':'',
                       'last_mode':'quick','last_menu':'quick','cellular_notice_accepted':False}
            for component, value in [('profile',payload),('settings',{'desktop':{},'mobile':{'ui_scale':scale,'reduce_motion':True}})]:
                (dest/(component+'.json')).write_text(json.dumps({'schema_version':1,'saved_at_utc':now,'payload':value})+'\n')
            adb(serial,'shell','am','force-stop','dev.pacificrush.game')
            adb(serial,'shell','mkdir','-m','700',remote)
            for component in ['profile','settings']:
                adb(serial,'push',str(dest/(component+'.json')),remote+'/'+component+'.json')
            uid = adb(serial,'shell','stat','-c','%u','/data/user/0/dev.pacificrush.game').stdout.decode().strip()
            assert uid.isdigit()
            adb(serial,'shell','chown','-R',uid+':'+uid,remote)
            adb(serial,'shell','logcat','-c')
            arguments = '--,--profile='+profile+',--capture=user://diagnostic_profiles/'+profile+'/main.png,--capture-frame=150'
            adb(serial,'shell','am','start','-n','dev.pacificrush.game/com.godot.game.GodotApp','--esa','command_line_params',arguments)
            deadline = time.monotonic()+65
            while time.monotonic()<deadline:
                if adb(serial,'shell','test','-f',remote+'/main.png',check=False).returncode==0:
                    break
                time.sleep(.5)
            else:
                raise TimeoutError('Actual APK main-menu readback timed out: '+serial)
            adb(serial,'pull',remote+'/main.png',str(dest/'main.png'))
            log = adb(serial,'shell','logcat','-d','-v','raw','-s','godot').stdout
            (dest/'android.log').write_bytes(log)
            assert b'PACIFIC_RUSH_CAPTURE_SAVED' in log and b'SCRIPT ERROR' not in log
            adb(serial,'shell','am','force-stop','dev.pacificrush.game')
            adb(serial,'pull',remote,str(dest/'profile-after'))
            state = json.loads((dest/'profile-after/profile.json').read_text())['payload']
            assert state['races_completed']==0 and state['distance_m']==0
            archived = '/data/user/0/dev.pacificrush.game/files/qa_archive_'+profile
            adb(serial,'shell','mv',remote,archived)
            row = {'serial':serial,'layout':name,'ui_scale':scale,'profile':profile,'archived_profile':archived,
                   'path':str((dest/'main.png').relative_to(OUT)),
                   'sha256':hashlib.sha256((dest/'main.png').read_bytes()).hexdigest(),'zero_race_stats':True}
            summary['captures'].append(row)
            print(json.dumps(row),flush=True)
    summary['passed']=True
finally:
    (OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(str(OUT),flush=True)
