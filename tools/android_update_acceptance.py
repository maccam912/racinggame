#!/usr/bin/env python3
"""Verify an in-place update on one owned emulator without clearing game data."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = 'dev.pacificrush.game'
FILES = '/data/user/0/'+PACKAGE+'/files'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('apk', type=Path)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--adb', type=Path, default=Path.home()/'Library/Android/sdk/platform-tools/adb')
    parser.add_argument('--apksigner', type=Path, default=Path.home()/'Library/Android/sdk/build-tools/35.0.1/apksigner')
    args = parser.parse_args()
    assert args.serial.startswith('emulator-'), 'Explicit owned emulator required'
    apk = args.apk.resolve()
    folder = ROOT/'reports'/('android-update-'+uuid.uuid4().hex[:10])
    folder.mkdir(parents=True)
    report = {'passed':False, 'serial':args.serial,
              'boundary':'Actual in-place emulator APK update and byte preservation before any game launch. Separate from save migration, clean installation, uninstall/reinstall or physical-device acceptance.',
              'apk_sha256':hashlib.sha256(apk.read_bytes()).hexdigest()}

    def adb(*command):
        return subprocess.check_output([str(args.adb), '-s', args.serial, *command], stderr=subprocess.STDOUT, text=True)

    def shell(command):
        return adb('shell', command).strip()

    def package():
        text = shell('dumpsys package '+PACKAGE)
        code = re.search(r'\bversionCode=(\d+)\b', text)
        name = re.search(r'\bversionName=([^\s]+)', text)
        assert code and name, 'An existing installed game is required'
        return {'version_code':int(code[1]), 'version_name':name[1], 'uid':shell('stat -c %u /data/user/0/'+PACKAGE)}

    def manifest():
        output = shell('find '+shlex.quote(FILES)+' -type f -exec sha256sum {} \\;')
        result = {}
        for line in output.splitlines():
            digest, path = line.split(None, 1)
            assert re.fullmatch('[0-9a-f]{64}',digest)
            relative = str(PurePosixPath(path).relative_to(FILES))
            result[relative] = digest
        return dict(sorted(result.items()))

    def certificate(path):
        env = dict(os.environ, JAVA_HOME='/opt/homebrew/opt/openjdk@17')
        output = subprocess.check_output([str(args.apksigner), 'verify', '--print-certs', str(path)], env=env, stderr=subprocess.STDOUT, text=True)
        values = re.findall(r'Signer #\d+ certificate SHA-256 digest: ([0-9a-f]{64})', output)
        assert len(values)==1, 'Exactly one verified development signer expected'
        return values[0]

    try:
        assert shell('getprop ro.kernel.qemu')=='1' and shell('id -u')=='0', 'Already rooted owned emulator required'
        report['model'] = shell('getprop ro.product.model')
        report['android_release'] = shell('getprop ro.build.version.release')
        adb('shell', 'am force-stop '+PACKAGE)
        report['before'] = package()
        before = manifest()
        report['files_before'] = before
        source = shell('pm path '+PACKAGE)
        assert source.startswith('package:') and '\n' not in source
        source = source.removeprefix('package:')
        with tempfile.TemporaryDirectory(prefix='signer-', dir=folder) as temporary:
            old = Path(temporary)/'installed.apk'
            subprocess.run([str(args.adb), '-s', args.serial, 'pull', source, str(old)], capture_output=True, check=True)
            report['previous_apk_sha256'] = hashlib.sha256(old.read_bytes()).hexdigest()
            report['previous_signer_sha256'] = certificate(old)
        report['signer_sha256'] = certificate(apk)
        assert report['previous_signer_sha256']==report['signer_sha256'], 'Signer mismatch: preserve installed data and stop'
        report['installer_output'] = adb('install', '-r', str(apk)).strip()
        report['after'] = package()
        after = manifest()
        report['files_after'] = after
        source = shell('pm path '+PACKAGE).removeprefix('package:')
        installed_hash = shell('sha256sum '+shlex.quote(source)).split()[0]
        report['installed_apk_sha256'] = installed_hash
        checks = {'same_uid':report['before']['uid']==report['after']['uid'],
                  'version_increased':report['after']['version_code']>report['before']['version_code'],
                  'all_existing_file_bytes_preserved':before==after,
                  'tested_apk_installed':installed_hash==report['apk_sha256']}
        report.update(checks=checks, file_count=len(before), passed=all(checks.values()))
        assert report['passed'], 'In-place update check failed; inspect preserved report'
    except BaseException as error:
        report['passed'] = False
        report['failure'] = type(error).__name__+': '+str(error)
        raise
    finally:
        (folder/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({'passed':report['passed'],'report':str(folder/'summary.json'),'files':report.get('file_count'),'failure':report.get('failure')}),flush=True)


if __name__=='__main__':
    main()
