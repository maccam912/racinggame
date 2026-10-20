#!/usr/bin/env python3
"""Exercise real OS stores; isolate Linux D-Bus and hosted macOS test keychains."""
import argparse
from contextlib import contextmanager
import os
from pathlib import Path
import secrets
import shlex
import subprocess
import sys
import tempfile
import uuid
from bootstrap import ROOT


def engine_commands():
    scope = 'test:'+str(uuid.uuid4())
    return [['--headless','--editor','--import','--quit'],['--headless','--script','tests/native_memory_tests.gd'],['--headless','--script','tests/native_store_tests.gd']] + [
        ['--headless','--','--protected-store-probe','--probe-scope='+scope,'--probe-action='+action]
        for action in ['absent','write','read','replace','read_replaced','erase','absent']]


def engine_tests():
    for args in engine_commands():
        subprocess.run([sys.executable,str(ROOT/'tools/godot.py'),*args],cwd=ROOT,check=True)


def security(*args):
    result = subprocess.run(['security',*args],capture_output=True,text=True)
    if result.returncode:
        # The command can contain the temporary CI-only password. Do not emit it.
        raise RuntimeError('Temporary CI keychain operation failed')
    return result.stdout


@contextmanager
def hosted_keychain():
    if os.environ.get('GITHUB_ACTIONS')!='true':
        raise RuntimeError('Keychain isolation is restricted to an ephemeral hosted CI job')
    previous_default = shlex.split(security('default-keychain','-d','user'))
    previous_search = shlex.split(security('list-keychains','-d','user'))
    with tempfile.TemporaryDirectory(prefix='pacific-keychain-') as folder:
        path = str(Path(folder)/'test.keychain-db')
        password = secrets.token_hex(24)
        created = False
        try:
            security('create-keychain','-p',password,path)
            created = True
            security('set-keychain-settings','-lut','600',path)
            security('unlock-keychain','-p',password,path)
            security('list-keychains','-d','user','-s',path,*previous_search)
            security('default-keychain','-d','user','-s',path)
            yield
        finally:
            if previous_default:
                security('default-keychain','-d','user','-s',previous_default[0])
            security('list-keychains','-d','user','-s',*previous_search)
            if created:
                security('delete-keychain',path)


def linux_child():
    with tempfile.TemporaryDirectory(prefix='pacific-secret-service-') as folder:
        environment = dict(os.environ,XDG_DATA_HOME=folder+'/data',XDG_RUNTIME_DIR=folder+'/runtime')
        Path(environment['XDG_RUNTIME_DIR']).mkdir(mode=0o700)
        control = Path(folder)/'control'
        control.mkdir(mode=0o700)
        daemon = subprocess.Popen(['gnome-keyring-daemon','--foreground','--unlock','--components=secrets',
                                   '--control-directory='+str(control)],env=environment,stdin=subprocess.PIPE,
                                  stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            daemon.stdin.write(secrets.token_hex(24).encode())
            daemon.stdin.close()
            subprocess.run(['gdbus','wait','--session','--timeout=10','org.freedesktop.secrets'],env=environment,check=True)
            for args in engine_commands():
                subprocess.run([sys.executable,str(ROOT/'tools/godot.py'),*args],cwd=ROOT,env=environment,check=True)
        finally:
            daemon.terminate()
            try:
                daemon.wait(timeout=5)
            except subprocess.TimeoutExpired:
                daemon.kill()
                daemon.wait()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--isolated',action='store_true')
    parser.add_argument('--linux-child',action='store_true')
    args = parser.parse_args()
    if args.linux_child:
        linux_child()
    elif args.isolated and sys.platform=='linux':
        subprocess.run(['dbus-run-session','--',sys.executable,str(Path(__file__).resolve()),'--linux-child'],cwd=ROOT,check=True)
    elif args.isolated and sys.platform=='darwin':
        with hosted_keychain():
            engine_tests()
    else:
        engine_tests()


if __name__=='__main__':
    main()
