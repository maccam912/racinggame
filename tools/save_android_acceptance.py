#!/usr/bin/env python3
"""Cold exported-package saves and cross-process flock on an owned ARM64 emulator."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('artifact',type=Path)
    parser.add_argument('--serial',required=True)
    args = parser.parse_args()
    if not args.serial.startswith('emulator-'): parser.error('Use an explicitly selected owned emulator')
    sdk = Path(os.environ.get('ANDROID_SDK_ROOT',Path.home()/'Library/Android/sdk'))
    base = [str(sdk/'platform-tools/adb'),'-s',args.serial]
    def adb(*command): return subprocess.check_output([*base,*command],text=True)
    if adb('shell','id','-u').strip()!='0': raise RuntimeError('This fixture requires a rooted owned emulator')
    scope = 'test:'+str(uuid.uuid4())
    profile = '/data/user/0/dev.pacificrush.game/files/diagnostic_profiles/save_files_probe/'+scope[5:]
    report = {'passed':False,'device':'Explicitly selected Android ARM64 emulator','serial':args.serial,'scope':scope,'steps':{},'apk_sha256':hashlib.file_digest(args.artifact.open('rb'),'sha256').hexdigest(),'boundary':'Real exported native file/directory flushes, cold Android processes and external POSIX lock contention; not physical hardware, power-cut or thermal acceptance.'}
    host = 'darwin-x86_64' if sys.platform=='darwin' else 'linux-x86_64'
    clang = sdk/'ndk/28.1.13356709/toolchains/llvm/prebuilt'/host/'bin/aarch64-linux-android29-clang'
    binary = ROOT/'build/instrumentation/android-save-lock'
    binary.parent.mkdir(parents=True,exist_ok=True)
    subprocess.run([str(clang),str(ROOT/'tests/native_lock_probe.c'),'-O2','-o',str(binary)],check=True)
    remote = '/data/local/tmp/pacific-save-lock-'+scope[5:]
    adb('install','-r',str(args.artifact.resolve()))
    adb('push',str(binary),remote); adb('shell','chmod','700',remote)
    def probe(action,held=False):
        adb('shell','am','force-stop','dev.pacificrush.game'); adb('logcat','-c')
        adb('shell','am','start','-W','-n','dev.pacificrush.game/com.godot.game.GodotApp','--esa','command_line_params','--,--save-files-probe,--probe-scope='+scope+',--probe-action='+action)
        deadline = time.monotonic()+25
        while time.monotonic()<deadline:
            output = adb('logcat','-d','-s','godot')
            if 'SAVE_FILES_PROBE_FAIL' in output or 'SCRIPT ERROR' in output or 'ERROR:' in output: raise RuntimeError(action+' failed: '+output)
            if ('SAVE_FILES_PROBE_HELD' if held else 'SAVE_FILES_PROBE_PASS') in output:
                report['steps'][action] = True
                return
            time.sleep(.2)
        raise TimeoutError('Android save probe timed out: '+action)
    try:
        for action in ['write','read','replace','fail','read_replaced']: probe(action)
        probe('hold',held=True)
        report['steps']['external_lock_busy'] = 'NATIVE_EXTERNAL_LOCK_BUSY' in adb('shell',remote,profile+'/.pacific-save.lock')
        adb('shell','am','force-stop','dev.pacificrush.game')
        report['steps']['external_lock_released_after_kill'] = 'NATIVE_EXTERNAL_LOCK_FREE' in adb('shell',remote,profile+'/.pacific-save.lock')
        probe('read_replaced')
        probe('delete_interrupted'); probe('read_deleted')
    finally:
        try: probe('cleanup')
        finally:
            adb('shell','am','force-stop','dev.pacificrush.game')
            adb('shell','rm',remote)
    report['passed'] = all(report['steps'].values()) and len(report['steps'])==11
    (ROOT/'reports/android-save-acceptance.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    raise SystemExit(0 if report['passed'] else 1)

if __name__=='__main__': main()
