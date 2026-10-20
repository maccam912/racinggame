#!/usr/bin/env python3
"""Build the locked Iroh GDExtension for desktop and Android ARM64."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'native/iroh'
HOST = {'darwin':'macos','linux':'linux','win32':'windows'}[sys.platform]
TARGETS = {'macos':['aarch64-apple-darwin','x86_64-apple-darwin'],
           'linux':['x86_64-unknown-linux-gnu'],'windows':['x86_64-pc-windows-msvc'],
           'android':['aarch64-linux-android']}
NAMES = {'macos':'libpacific_iroh.macos.universal.dylib','linux':'libpacific_iroh.linux.x86_64.so',
         'windows':'pacific_iroh.windows.x86_64.dll','android':'libpacific_iroh.android.arm64.so'}
CACHE = Path.home()/'.cache/pacific-rush/iroh-target'


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def source_hash():
    context = hashlib.sha256()
    paths = sorted([*SOURCE.rglob('*.rs'),SOURCE/'Cargo.toml',SOURCE/'Cargo.lock',
                    ROOT/'native/pacific_iroh.gdextension.in',ROOT/'tools/iroh_build.py'])
    for path in paths:
        context.update(path.relative_to(ROOT).as_posix().encode())
        context.update(path.read_bytes())
    return context.hexdigest()


def binary_path(platform):
    return ROOT/'native/bin'/NAMES[platform]


def manifest_path(platform):
    return ROOT/'native/bin'/f'manifest-iroh-{platform}.json'


def ready(platform):
    try:
        manifest = json.loads(manifest_path(platform).read_text())
        return manifest['source_hash']==source_hash() and manifest['sha256']==digest(binary_path(platform))
    except (OSError,ValueError,KeyError):
        return False


def configure():
    if binary_path(HOST).exists():
        shutil.copyfile(ROOT/'native/pacific_iroh.gdextension.in',ROOT/'native/pacific_iroh.gdextension')


def build(platform):
    if platform not in [HOST,'android']:
        raise RuntimeError('Build the Iroh '+platform+' library on its native runner')
    if not shutil.which('cargo'):
        raise RuntimeError('Install Rust 1.98.1 with rustup to build Iroh')
    environment = dict(os.environ)
    if platform=='macos': environment['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
    if platform=='android':
        lock = json.loads((ROOT/'tools/toolchain.lock').read_text())['android']
        sdk = Path(os.environ.get('ANDROID_HOME',str(Path.home()/'Library/Android/sdk')))
        ndk = sdk/'ndk'/lock['ndk']/'toolchains/llvm/prebuilt'
        host_tag = {'darwin':'darwin-x86_64','linux':'linux-x86_64','win32':'windows-x86_64'}[sys.platform]
        tool = ndk/host_tag/'bin'
        suffix = '.cmd' if sys.platform=='win32' else ''
        linker = tool/f'aarch64-linux-android{lock["min_sdk"]}-clang{suffix}'
        if not linker.exists(): raise RuntimeError('Android NDK linker missing: '+str(linker))
        environment.update(CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER=str(linker),
                           CC_aarch64_linux_android=str(linker),AR_aarch64_linux_android=str(tool/'llvm-ar'))
    outputs = []
    for target in TARGETS[platform]:
        subprocess.run(['rustup','target','add',target],check=True)
        subprocess.run(['cargo','build','--locked','--release','--manifest-path',str(SOURCE/'Cargo.toml'),
                        '--target',target,'--target-dir',str(CACHE),'-j','4'],env=environment,cwd=ROOT,check=True)
        filename = 'pacific_iroh.dll' if platform=='windows' else 'libpacific_iroh.'+('dylib' if platform=='macos' else 'so')
        outputs.append(CACHE/target/'release'/filename)
    output = binary_path(platform)
    output.parent.mkdir(parents=True,exist_ok=True)
    temporary = output.with_suffix(output.suffix+'.pending')
    if platform=='macos': subprocess.run(['lipo','-create',*[str(p) for p in outputs],'-output',str(temporary)],check=True)
    else: shutil.copyfile(outputs[0],temporary)
    temporary.replace(output)
    manifest_path(platform).write_text(json.dumps({'platform':platform,'targets':TARGETS[platform],
        'source_hash':source_hash(),'sha256':digest(output),'iroh':'1.2.0','gdext':'0.5.5',
        'upstream':'153979fc02f86b10802358ae38fb74204fbf179a'},indent=2)+'\n')
    configure()
    return output


def ensure_export(target):
    platform = {'server':'linux','android_aab':'android'}.get(target,target)
    for required in dict.fromkeys([HOST,platform]):
        if not ready(required): build(required)
    configure()
    return json.loads(manifest_path(platform).read_text())


if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('platform',choices=['host',*TARGETS],default='host',nargs='?')
    args = parser.parse_args()
    print(build(HOST if args.platform=='host' else args.platform))
