#!/usr/bin/env python3
"""Clean install/reinstall only in a newly created, initially empty test AVD.

Never use a player's emulator: preflight requires no existing game, a named
installation-fixture AVD and a per-invocation stamp before any uninstall.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = 'dev.pacificrush.game'
APP_DIR = '/data/user/0/'+PACKAGE


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('apk', type=Path)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--expected-avd', required=True)
    parser.add_argument('--adb', type=Path, default=Path.home()/'Library/Android/sdk/platform-tools/adb')
    args = parser.parse_args()
    assert args.serial.startswith('emulator-') and args.expected_avd.startswith('pacific_rush_install_')
    folder = ROOT/'reports'/('android-install-'+uuid.uuid4().hex[:10])
    folder.mkdir(parents=True)
    apk = args.apk.resolve()
    scope = 'test:'+str(uuid.uuid4())
    stamp = uuid.uuid4().hex
    report = {'passed':False,'serial':args.serial,'avd':args.expected_avd,
              'apk_sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),
              'scope':scope,'steps':{},
              'boundary':'New disposable emulator, actual release APK, offline first-run renders, native save and non-exportable test-key probes, owned uninstall/reinstall. No player data, real online guest registration, physical hardware or storefront acceptance. Startup observations include host polling and are not minimum-hardware first-frame benchmarks.'}
    metadata = apk.with_name(apk.stem+'-build.json')
    if metadata.exists(): report['build'] = json.loads(metadata.read_text())

    def adb(*command, check=True):
        return subprocess.run([str(args.adb),'-s',args.serial,*command],capture_output=True,text=True,check=check).stdout.strip()

    def present():
        return adb('shell','pm path '+PACKAGE,check=False).startswith('package:')

    def launch(label, parameters, marker):
        adb('shell','am force-stop '+PACKAGE)
        adb('logcat','-c') # This new fixture AVD has no unrelated game sessions.
        began = time.monotonic()
        adb('shell','am','start','-W','-n',PACKAGE+'/com.godot.game.GodotApp',
            '--esa','command_line_params',','.join(['--',*parameters]))
        deadline = time.monotonic()+45
        ready_at = None
        while time.monotonic()<deadline:
            text = adb('logcat','-d','-v','raw','-s','godot')
            if 'PACIFIC_RUSH_CLIENT_READY' in text and ready_at is None: ready_at = time.monotonic()-began
            if any(value in text for value in ['SCRIPT ERROR:','ERROR:','PROBE_FAIL','instances leaked']):
                (folder/(label+'.log')).write_text(text)
                raise AssertionError('Actual APK probe failed: '+label)
            if marker in text:
                (folder/(label+'.log')).write_text(text)
                report['steps'][label] = {'passed':True,'observed_seconds':time.monotonic()-began,'client_ready_seconds':ready_at}
                return text
            time.sleep(.2)
        (folder/(label+'.log')).write_text(adb('logcat','-d','-v','raw','-s','godot'))
        raise TimeoutError('Actual APK probe timed out: '+label)

    def protected(label, action):
        launch(label,['--protected-store-probe','--probe-scope='+scope,'--probe-action='+action],'PROTECTED_STORE_PROBE_PASS')

    def saved(label, action):
        launch(label,['--save-files-probe','--probe-scope='+scope,'--probe-action='+action],'SAVE_FILES_PROBE_PASS')

    def screenshot(label):
        profile = 'install_'+uuid.uuid4().hex[:16]
        remote = APP_DIR+'/files/diagnostic_profiles/'+profile+'/screen.png'
        launch(label,['--profile='+profile,'--capture=user://diagnostic_profiles/'+profile+'/screen.png','--capture-frame=150'],'PACIFIC_RUSH_CLIENT_READY')
        deadline = time.monotonic()+30
        while time.monotonic()<deadline:
            result = subprocess.run([str(args.adb),'-s',args.serial,'shell','test','-f',remote],capture_output=True)
            if result.returncode==0: break
            time.sleep(.2)
        else: raise TimeoutError('First-run native frame was not saved')
        time.sleep(1) # Ordinary stopped-audio quit, then inspect its shutdown.
        text = adb('logcat','-d','-v','raw','-s','godot')
        (folder/(label+'.log')).write_text(text)
        assert not any(value in text for value in ['SCRIPT ERROR:','ERROR:','instances leaked'])
        image = subprocess.check_output([str(args.adb),'-s',args.serial,'exec-out','cat',remote])
        assert image[:8]==b'\x89PNG\r\n\x1a\n'
        (folder/(label+'.png')).write_bytes(image)
        report['steps'][label]['png_sha256'] = hashlib.sha256(image).hexdigest()

    try:
        assert adb('shell','getprop ro.kernel.qemu')=='1' and adb('shell','id -u')=='0'
        assert adb('emu','avd','name').splitlines()[0]==args.expected_avd, 'Wrong AVD; stop before any mutation'
        assert not present(), 'Fixture requires an initially empty game installation; preserve existing data and stop'
        report['initially_absent'] = True
        report['model'] = adb('shell','getprop ro.product.model')
        report['android_release'] = adb('shell','getprop ro.build.version.release')
        # Network settings belong only to this newly created installation AVD.
        adb('shell','svc wifi disable')
        adb('shell','svc data disable')
        report['first_install_output'] = adb('install',str(apk))
        services = launch('offline_route',['--mobile-services-probe'],'PACIFIC_MOBILE_SERVICES_READY')
        route = json.loads(re.search(r'PACIFIC_MOBILE_SERVICES_READY (\{[^\n]+\})',services)[1])
        assert route['route_kind']=='none' and not route['route_available'], 'Offline launch requires no default network'
        report['offline_route'] = route
        screenshot('first_install_preferences')
        protected('key_initially_absent','absent')
        protected('key_write','write')
        protected('key_cold_read','read')
        saved('save_write','write')
        saved('save_cold_read','read')
        local_stamp = folder/'ownership-stamp.json'
        local_stamp.write_text(json.dumps({'fixture':stamp,'apk_sha256':report['apk_sha256']})+'\n')
        adb('push',str(local_stamp),APP_DIR+'/files/install-fixture-stamp.json')
        assert json.loads(adb('shell','cat '+APP_DIR+'/files/install-fixture-stamp.json'))['fixture']==stamp
        assert adb('emu','avd','name').splitlines()[0]==args.expected_avd
        installed = adb('shell','pm path '+PACKAGE).removeprefix('package:')
        assert adb('shell','sha256sum '+installed).split()[0]==report['apk_sha256']
        adb('shell','am force-stop '+PACKAGE)
        report['uninstall_output'] = adb('uninstall',PACKAGE)
        assert not present()
        removed = subprocess.run([str(args.adb),'-s',args.serial,'shell','test','!','-e',APP_DIR],capture_output=True)
        assert removed.returncode==0, 'The owned app-data directory must be removed by uninstall'
        report['owned_app_data_removed'] = True
        report['reinstall_output'] = adb('install',str(apk))
        protected('old_key_absent_after_reinstall','absent')
        saved('old_save_absent_after_reinstall','read_deleted')
        screenshot('reinstalled_preferences')
        report['passed'] = True
    except BaseException as error:
        report['failure'] = type(error).__name__+': '+str(error)
        raise
    finally:
        adb('shell','am force-stop '+PACKAGE,check=False)
        (folder/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({'passed':report['passed'],'report':str(folder/'summary.json'),'failure':report.get('failure')}),flush=True)


if __name__=='__main__':
    main()
