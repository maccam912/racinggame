#!/usr/bin/env python3
"""Build the small, pinned OS adapter without installing global Python packages."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import venv

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT/'tools/toolchain.lock').read_text())
CACHE = Path.home()/'.cache/pacific-rush/native'
HOST = {'darwin':'macos','win32':'windows','linux':'linux'}[sys.platform]
ARCH = {'macos':'universal','windows':'x86_64','linux':'x86_64','android':'arm64'}
SUFFIX = {'macos':'dylib','windows':'dll','linux':'so','android':'so'}


def digest(path):
    with Path(path).open('rb') as file:
        return hashlib.file_digest(file,'sha256').hexdigest()


def fetch(url,path,sha256):
    path = Path(path)
    path.parent.mkdir(parents=True,exist_ok=True)
    if path.exists() and digest(path)==sha256:
        return path
    temporary = path.with_suffix('.part')
    with urllib.request.urlopen(url,timeout=120) as source, temporary.open('wb') as target:
        shutil.copyfileobj(source,target)
    if digest(temporary)!=sha256:
        temporary.unlink()
        raise RuntimeError('Native dependency checksum mismatch: '+path.name)
    temporary.replace(path)
    return path


def dependencies():
    sdk = LOCK['godot_cpp']
    directory = CACHE/'godot-cpp-4.5'
    marker = directory/'.pacific-source-pin'
    if not marker.exists() or marker.read_text().strip()!=sdk['sha256']:
        archive = fetch(sdk['url'],CACHE/'godot-cpp-4.5.tar.gz',sdk['sha256'])
        with tempfile.TemporaryDirectory(dir=CACHE) as temporary:
            with tarfile.open(archive) as source:
                for entry in source.getmembers():
                    parts = Path(entry.name).parts
                    if len(parts)<2:
                        continue
                    entry.name = '/'.join(parts[1:])
                    source.extract(entry,temporary,filter='data')
            if directory.exists():
                shutil.rmtree(directory)
            shutil.move(temporary,directory)
        marker.write_text(sdk['sha256']+'\n')
    package = LOCK['scons']
    wheel = fetch(package['url'],CACHE/f"scons-{package['version']}-py3-none-any.whl",package['sha256'])
    environment = CACHE/f"venv-scons-{package['version']}"
    python = environment/('Scripts/python.exe' if os.name=='nt' else 'bin/python3')
    if not python.exists():
        venv.EnvBuilder(with_pip=True).create(environment)
    installed = subprocess.run([str(python),'-c','import SCons; print(SCons.__version__)'],capture_output=True,text=True)
    if installed.returncode or installed.stdout.strip()!=package['version']:
        subprocess.run([str(python),'-m','pip','install','--no-index','--no-deps',str(wheel)],check=True)
    return directory,python


def source_hash():
    context = hashlib.sha256()
    paths = [ROOT/'tools/native_build.py',ROOT/'native/SConstruct',ROOT/'native/build_profile.json',ROOT/'native/pacific_platform.gdextension.in']
    paths += sorted((ROOT/'native/src').glob('*.cpp'))+sorted((ROOT/'native/src').glob('*.hpp'))+sorted((ROOT/'native/src').glob('*.mm'))
    for path in paths:
        context.update(path.relative_to(ROOT).as_posix().encode())
        context.update(path.read_bytes())
    context.update(json.dumps({key:LOCK[key] for key in ['godot_cpp','scons','android']},sort_keys=True).encode())
    return context.hexdigest()


def binary_path(platform_name):
    return ROOT/'native/bin'/f'libpacific_platform.{platform_name}.template_release.{ARCH[platform_name]}.{SUFFIX[platform_name]}'


def manifest_path(platform_name):
    return ROOT/'native/bin'/f'manifest-{platform_name}.json'


def ready(platform_name):
    binary,manifest = binary_path(platform_name),manifest_path(platform_name)
    if not binary.exists() or not manifest.exists():
        return False
    try:
        data = json.loads(manifest.read_text())
        return data['source_hash']==source_hash() and data['sha256']==digest(binary)
    except (KeyError,ValueError,OSError):
        return False


def configure():
    shutil.copyfile(ROOT/'native/pacific_platform.gdextension.in',ROOT/'native/pacific_platform.gdextension')


def build(platform_name):
    if platform_name not in [HOST,'android']:
        raise RuntimeError('Build the '+platform_name+' adapter on its native CI runner')
    sdk,python = dependencies()
    command = [str(python),'-m','SCons','-C',str(ROOT/'native'),f'platform={platform_name}',
               'target=template_release',f'arch={ARCH[platform_name]}',
               'build_profile='+str(ROOT/'native/build_profile.json'),'-j'+str(min(8,os.cpu_count() or 2))]
    environment = dict(os.environ,PACIFIC_GODOT_CPP=str(sdk))
    if platform_name=='macos':
        command.append('macos_deployment_target=13.0')
    if platform_name=='android':
        android = Path(os.environ.get('ANDROID_HOME',str(Path.home()/'Library/Android/sdk')))
        environment['ANDROID_HOME'] = str(android)
        environment['ANDROID_NDK_ROOT'] = str(android/'ndk'/LOCK['android']['ndk'])
        command += ['ANDROID_HOME='+str(android),'ndk_version='+LOCK['android']['ndk']]
        command.append('android_api_level='+str(LOCK['android']['min_sdk']))
    subprocess.run(command,cwd=ROOT,env=environment,check=True)
    binary = binary_path(platform_name)
    if not binary.exists():
        raise RuntimeError('Native adapter output missing: '+binary.name)
    manifest_path(platform_name).write_text(json.dumps({'platform':platform_name,'architecture':ARCH[platform_name],
        'api_floor':'4.5','sdk_commit':LOCK['godot_cpp']['commit'],'scons':LOCK['scons']['version'],
        'source_hash':source_hash(),'sha256':digest(binary)},indent=2)+'\n')
    configure()
    return binary


def ensure_export(target):
    platform_name = {'server':'linux','android_aab':'android'}.get(target,target)
    for required in dict.fromkeys([HOST,platform_name]):
        if not ready(required):
            build(required)
    configure()
    return json.loads(manifest_path(platform_name).read_text())


if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('platform',choices=['host',*ARCH],default='host',nargs='?')
    args = parser.parse_args()
    print(build(HOST if args.platform=='host' else args.platform))
