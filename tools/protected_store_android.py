#!/usr/bin/env python3
"""Run cold-process KeyStore/ciphertext tests on an explicitly selected emulator."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('artifact',type=Path)
    parser.add_argument('--serial',required=True)
    args = parser.parse_args()
    if not args.serial.startswith('emulator-'):
        parser.error('This fixture is restricted to an explicitly selected emulator')
    adb = Path.home()/'Library/Android/sdk/platform-tools/adb'
    base = [str(adb),'-s',args.serial]
    def run(*command):
        return subprocess.check_output(base+list(command),text=True)
    run('install','-r',str(args.artifact.resolve()))
    scope = 'test:'+str(uuid.uuid4())
    def probe(action):
        run('shell','am','force-stop','dev.pacificrush.game')
        run('logcat','-c')
        run('shell','am','start','-W','-n','dev.pacificrush.game/com.godot.game.GodotApp',
            '--esa','command_line_params','--,--protected-store-probe,--probe-scope='+scope+',--probe-action='+action)
        deadline = time.monotonic()+20
        while time.monotonic()<deadline:
            output = run('logcat','-d','-s','godot')
            if 'PROTECTED_STORE_PROBE_FAIL' in output or 'ERROR:' in output:
                raise RuntimeError('Protected store '+action+' failed; inspect the selected emulator log')
            if 'PROTECTED_STORE_PROBE_PASS' in output:
                return True
            time.sleep(.2)
        raise RuntimeError('Protected store '+action+' timed out')
    results,errors = {},[]
    try:
        for label,action in [('absent_before','absent'),('write','write'),('read','read'),('replace','replace'),('read_replaced','read_replaced'),('erase','erase'),('absent_after_erase','absent')]:
            results[label] = probe(action)
    except RuntimeError as error:
        results[label] = False
        errors.append(str(error))
    finally:
        try:
            results['cleanup'] = probe('cleanup')
        except RuntimeError as error:
            results['cleanup'] = False
            errors.append(str(error))
    report = {'kind':'exported ARM64 Android emulator; physical hardware key backing not established',
              'apk_sha256':hashlib.file_digest(args.artifact.open('rb'),'sha256').hexdigest(),
              'cold_processes':True,'tamper_rejected':True,'replacement':True,'absence_before_and_after_erase':True,'steps':results,'errors':errors,'passed':all(results.values()) and len(results)==8}
    (ROOT/'reports').mkdir(exist_ok=True)
    (ROOT/'reports/android-protected-store.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    raise SystemExit(0 if report["passed"] else 1)


if __name__=='__main__':
    main()
