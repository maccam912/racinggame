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
from contextlib import contextmanager, nullcontext
from export_environment import temporary_configuration
from native_build import ensure_export
from content_hash import compute
from asset_hash import compute as cosmetic_manifest
from bootstrap import ROOT, LOCK, engine, templates

TARGETS = {'linux':('Linux','pacific-rush.x86_64'), 'windows':('Windows','pacific-rush.exe'),
           'macos':('macOS','pacific-rush.zip'), 'android':('Android','pacific-rush.apk'),
           'android_aab':('Android AAB','pacific-rush.aab'),
           'server':('Server','pacific-rush-server.x86_64')}


def checked(args):
    subprocess.run([sys.executable, str(ROOT/'tools/godot.py'), *args], cwd=ROOT, check=True)


def metadata(target, number):
    return {'version':f'0.0.{number}-dev', 'build_number':number,
            'working_tree_dirty':bool(subprocess.check_output(['git','status','--porcelain','--untracked-files=normal'],cwd=ROOT,text=True).strip()),
            'commit':subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip(),
            'engine_version':LOCK['version'], 'engine_checksum':LOCK['assets'][sys.platform]['sha256'],
            'export_templates_checksum':LOCK['assets']['templates']['sha256'],
            'protocol_version':json.loads((ROOT/'game/content/rules.json').read_text())['protocol_version'],'save_schema':1,'content_hash':compute()['content_hash'],'asset_hash':cosmetic_manifest()['asset_hash'],'target_platform':target,
            'distribution':'development', 'public_signing':'not configured'}


@contextmanager
def stamped(data, number):
    import re
    project = ROOT/'project.godot'
    presets = ROOT/'export_presets.cfg'
    original_project, original_presets = project.read_text(), presets.read_text()
    build_info = ROOT/'game/build.json'
    original_info = build_info.read_bytes() if build_info.exists() else None
    (ROOT/'game/build.json').write_text(json.dumps(data, indent=2)+'\n')
    project.write_text(re.sub(r'config/version="[^"]+"', f'config/version="0.0.{number}-dev"', original_project))
    text = re.sub(r'version/code=\d+', f'version/code={number}', original_presets)
    text = re.sub(r'version/name="[^"]+"', f'version/name="0.0.{number}-dev"', text)
    text = re.sub(r'application/short_version="[^"]+"', f'application/short_version="0.0.{number}"', text)
    text = re.sub(r'application/version="[^"]+"', f'application/version="{number}"', text)
    presets.write_text(text)
    try:
        yield
    finally:
        project.write_text(original_project)
        presets.write_text(original_presets)
        if original_info is None:
            build_info.unlink(missing_ok=True)
        else:
            build_info.write_bytes(original_info)


def android_configuration():
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
    local_key = Path.home()/'.local/share/pacific-rush/development.keystore'
    fallback_key = Path.home()/'.android/debug.keystore'
    keystore = Path(os.environ.get('PACIFIC_DEBUG_KEYSTORE', str(local_key if local_key.exists() else fallback_key))).expanduser()
    if not keystore.exists():
        keystore = local_key
        keystore.parent.mkdir(parents=True,exist_ok=True)
        subprocess.run([str(Path(jdk)/'bin/keytool'),'-genkeypair','-keystore',str(keystore),'-storepass','android','-keypass','android','-alias','androiddebugkey','-dname','CN=Pacific Rush Development','-keyalg','RSA','-keysize','2048','-validity','10000'],check=True,capture_output=True)
        keystore.chmod(0o600)
    values = {'export/android/android_sdk_path':sdk, 'export/android/java_sdk_path':jdk}
    values.update({'export/android/debug_keystore':str(keystore), 'export/android/debug_keystore_user':'androiddebugkey', 'export/android/debug_keystore_pass':'android'})
    environment = {'GODOT_ANDROID_KEYSTORE_RELEASE_PATH':str(keystore), 'GODOT_ANDROID_KEYSTORE_RELEASE_USER':'androiddebugkey', 'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD':'android'}
    return settings, values, environment


def build(target, number):
    if number < 1:
        raise ValueError('Build number must be positive')
    adapter = ensure_export(target)
    templates()
    folder = ROOT/'build'/target
    folder.mkdir(parents=True, exist_ok=True)
    (ROOT/'build/.gdignore').touch()
    preset, name = TARGETS[target]
    data = metadata(target, number)
    data["native_adapter"] = adapter
    configuration = temporary_configuration(*android_configuration()) if target.startswith('android') else nullcontext()
    with configuration, stamped(data, number):
        checked(['--headless','--editor','--import','--quit'])
        install = ['--install-android-build-template'] if target.startswith('android') else []
        checked(['--headless', *install, '--export-release',preset,str(folder/name)])
    (folder/'build.json').write_text(json.dumps(data, indent=2)+'\n')
    shutil.copy(ROOT/'LICENSE', folder/'LICENSE')
    shutil.copytree(ROOT/'assets/licenses',folder/'licenses',dirs_exist_ok=True)
    output = ROOT/'build/download'
    output.mkdir(exist_ok=True)
    stem = f'pacific-rush-{number:05d}-{target}'
    if target.startswith('android'):
        artifact = output/(stem+Path(name).suffix)
        shutil.copy(folder/name, artifact)
    else:
        artifact = output/(stem+'.zip')
        if target == 'macos':
            with zipfile.ZipFile(folder/name) as source, zipfile.ZipFile(artifact, 'w', zipfile.ZIP_DEFLATED) as dest:
                for item in source.infolist():
                    dest.writestr(item, source.read(item))
                dest.writestr('build.json', json.dumps(data, indent=2))
                dest.write(ROOT/'LICENSE','LICENSE')
                for path in (ROOT/'assets/licenses').rglob('*'):
                    if path.is_file():
                        dest.write(path,'licenses/'+path.relative_to(ROOT/'assets/licenses').as_posix())
        else:
            with zipfile.ZipFile(artifact, 'w', zipfile.ZIP_DEFLATED) as archive:
                for path in sorted(folder.rglob('*')):
                    if path.is_file():
                        archive.write(path, path.relative_to(folder).as_posix())
    (output/(stem+'-build.json')).write_text(json.dumps(data, indent=2)+'\n')
    (output/(stem+'.sha256')).write_text(hashlib.file_digest(artifact.open('rb'),'sha256').hexdigest()+'  '+artifact.name+'\n')
    print(artifact)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('target', choices=TARGETS)
    parser.add_argument('--number', type=int, default=1)
    args = parser.parse_args()
    build(args.target,args.number)
