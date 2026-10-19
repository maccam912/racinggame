#!/usr/bin/env python3
"""Pinned project cache; never installs a system service or trusts a local CA."""
import hashlib
import json
import platform
from pathlib import Path
import tarfile
import urllib.request
from bootstrap import ROOT


def caddy():
    lock=json.loads((ROOT/'tools/toolchain.lock').read_text())['caddy']
    machine={'aarch64':'arm64','arm64':'arm64','x86_64':'amd64','AMD64':'amd64'}.get(platform.machine(),platform.machine())
    asset=lock['assets'][f'{platform.system().lower()}-{machine}']
    folder=Path.home()/'.cache/pacific-rush/caddy'/lock['version']/f'{platform.system().lower()}-{machine}'
    folder.mkdir(parents=True,exist_ok=True)
    binary=folder/'caddy';archive=folder/asset['file']
    if not archive.exists() or hashlib.sha512(archive.read_bytes()).hexdigest()!=asset['sha512']:
        temporary=archive.with_suffix('.download')
        urllib.request.urlretrieve(lock['release']+asset['file'],temporary)
        assert hashlib.sha512(temporary.read_bytes()).hexdigest()==asset['sha512'],'Caddy checksum mismatch'
        temporary.replace(archive)
    if not binary.exists():
        with tarfile.open(archive) as bundle:
            for name in ['caddy','LICENSE']:
                bundle.extract(name,folder,filter='data')
        binary.chmod(0o755)
    return binary


if __name__=='__main__':print(caddy())
