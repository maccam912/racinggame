#!/usr/bin/env python3
"""Export reproducible development packages; no publisher credentials in source."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
from bootstrap import ROOT, LOCK, engine, templates

TARGETS = {'linux':('Linux','pacific-rush.x86_64'), 'windows':('Windows','pacific-rush.exe'),
           'macos':('macOS','pacific-rush.zip'), 'android':('Android','pacific-rush.apk'),
           'server':('Server','pacific-rush-server.x86_64')}


def checked(args):
    subprocess.run([sys.executable, str(ROOT/'tools/godot.py'), *args], cwd=ROOT, check=True)


def metadata(target, number):
    h = hashlib.sha256()
    for path in sorted((ROOT/'game/content').rglob('*.json')):
        h.update(path.relative_to(ROOT).as_posix().encode())
        h.update(path.read_bytes())
    return {'version':f'0.0.{number}-dev', 'build_number':number,
            'commit':subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip(),
            'engine_version':LOCK['version'], 'engine_checksum':LOCK['assets']['templates']['sha256'],
            'protocol_version':1,'save_schema':1,'content_hash':h.hexdigest(),'target_platform':target,
            'distribution':'development', 'public_signing':'not configured'}


def build(target, number):
    templates()
    folder = ROOT/'build'/target
    folder.mkdir(parents=True, exist_ok=True)
    preset, name = TARGETS[target]
    if target == 'android':
        sdk = os.environ.get('ANDROID_HOME', str(Path.home()/'Library/Android/sdk'))
        jdk = os.environ.get('JAVA_HOME', '/opt/homebrew/opt/openjdk@17')
        settings = ROOT/'build/export-home/editor_settings-4.6.tres'
        # Godot accepts editor settings through its standard per-user config path.
        if sys.platform == 'darwin':
            settings = Path.home()/'Library/Application Support/Godot/editor_settings-4.6.tres'
        elif sys.platform == 'win32':
            settings = Path(os.environ['APPDATA'])/'Godot/editor_settings-4.6.tres'
        else:
            settings = Path.home()/'.config/godot/editor_settings-4.6.tres'
        settings.parent.mkdir(parents=True, exist_ok=True)
        text = settings.read_text() if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
        import re
        for key, value in {'export/android/android_sdk_path':sdk, 'export/android/java_sdk_path':jdk}.items():
            text = re.sub(r'^'+re.escape(key)+r'=.*\n', '', text, flags=re.M)
            text += f'{key}="{value}"\n'
        settings.write_text(text)
    checked(['--headless','--editor','--import','--quit'])
    install = ['--install-android-build-template'] if target == 'android' else []
    checked(['--headless', *install, '--export-debug',preset,str(folder/name)])
    data = metadata(target, number)
    (folder/'build.json').write_text(json.dumps(data, indent=2)+'\n')
    shutil.copy(ROOT/'LICENSE', folder/'LICENSE')
    output = ROOT/'build/download'
    output.mkdir(exist_ok=True)
    stem = f'pacific-rush-{number:05d}-{target}'
    if target == 'android':
        artifact = output/(stem+'.apk')
        shutil.copy(folder/name, artifact)
    else:
        artifact = output/(stem+'.zip')
        if target == 'macos':
            with zipfile.ZipFile(folder/name) as source, zipfile.ZipFile(artifact, 'w', zipfile.ZIP_DEFLATED) as dest:
                for item in source.infolist():
                    dest.writestr(item, source.read(item))
                dest.writestr('build.json', json.dumps(data, indent=2))
                dest.write(ROOT/'LICENSE','LICENSE')
        else:
            with zipfile.ZipFile(artifact, 'w', zipfile.ZIP_DEFLATED) as archive:
                for path in sorted(folder.iterdir()):
                    archive.write(path, path.name)
    (output/(stem+'-build.json')).write_text(json.dumps(data, indent=2)+'\n')
    (output/(stem+'.sha256')).write_text(hashlib.file_digest(artifact.open('rb'),'sha256').hexdigest()+'  '+artifact.name+'\n')
    print(artifact)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('target', choices=TARGETS)
    parser.add_argument('--number', type=int, default=1)
    args = parser.parse_args()
    build(args.target,args.number)
