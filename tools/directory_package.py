#!/usr/bin/env python3
"""Bundle the pinned Linux x86-64 operator service with the server export."""
import base64
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
from bootstrap import ROOT


def digest(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file,'sha256').hexdigest()


def build(folder, game_build):
    lock = json.loads((ROOT/'tools/toolchain.lock').read_text())
    environment = {**os.environ,'GOTOOLCHAIN':'local','CGO_ENABLED':'0','GOOS':'linux','GOARCH':'amd64'}
    version = subprocess.check_output(['go','env','GOVERSION'],env=environment,text=True).strip()
    if version != 'go'+lock['go']:
        raise RuntimeError('Directory packaging requires the exact pinned Go '+lock['go'])
    source = hashlib.sha256()
    for path in sorted([*(ROOT/'services/directory').rglob('*.go'),ROOT/'services/directory/go.mod',ROOT/'services/directory/go.sum']):
        source.update(path.relative_to(ROOT).as_posix().encode())
        source.update(path.read_bytes())
    identity = {key:game_build[key] for key in ['version','build_number','commit','working_tree_dirty','protocol_version','content_hash','distribution']}
    identity.update(source_sha256=source.hexdigest(),target_platform='linux-amd64',go_version=version,service_schema=4)
    encoded = base64.urlsafe_b64encode(json.dumps(identity,sort_keys=True,separators=(',',':')).encode()).decode().rstrip('=')
    folder.mkdir(parents=True,exist_ok=True)
    binary = folder/'pacific-directory'
    pending = folder/'pacific-directory.pending'
    try:
        subprocess.run(['go','-C',str(ROOT/'services/directory'),'build','-mod=readonly','-trimpath','-buildvcs=false',
                        '-ldflags','-s -w -buildid= -X main.buildIdentityB64='+encoded,
                        '-o',str(pending),'./cmd/pacific-directory'],env=environment,check=True)
        # A cross-build is always ELF64 / little-endian / x86-64, never a host binary.
        with pending.open('rb') as executable:
            header = executable.read(20)
        if header[:6] != b'\x7fELF\x02\x01' or header[18:20] != b'\x3e\x00':
            raise RuntimeError('Directory package is not Linux x86-64 ELF')
        pending.chmod(0o755)
        pending.replace(binary)
    finally:
        pending.unlink(missing_ok=True)
    (folder/'directory-build.json').write_text(json.dumps(identity,indent=2)+'\n')
    shutil.copytree(ROOT/'services/directory/licenses',folder/'licenses/directory',dirs_exist_ok=True)
    runbooks = ['DIRECTORY_BACKUPS.md','SUPERVISOR_LIFECYCLE.md','SERVER_PERFORMANCE.md','WORKER_RETIREMENT.md','CONTAINER_HOSTING.md','DATA_DELETION_REQUESTS.md']
    readme = (ROOT/'docs/SERVER_PACKAGE.md').read_text()
    for name in runbooks:
        readme = readme.replace(']('+name+')','](operator/'+name+')')
    (folder/'README_SERVER.md').write_text(readme)
    documentation = folder/'operator'
    documentation.mkdir(exist_ok=True)
    for name in runbooks:
        shutil.copy(ROOT/'docs'/name,documentation/name)
        # Numeric historical evidence linked from an operated runbook travels
        # with that runbook; extracted packages cannot resolve repository paths.
        for reference in re.findall(r'\]\((evidence/[^)]+)\)',(ROOT/'docs'/name).read_text()):
            source = (ROOT/'docs'/reference).resolve()
            if not source.is_relative_to((ROOT/'docs/evidence').resolve()) or not source.is_file():
                raise RuntimeError('Runbook evidence is missing or outside docs/evidence')
            destination = documentation/reference
            destination.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy(source,destination)
    directory_readme = (ROOT/'services/directory/README.md').read_text().replace('../../docs/SERVER_PACKAGE.md','../README_SERVER.md').replace('../../docs/','')
    (documentation/'DIRECTORY.md').write_text(directory_readme)
    shutil.copytree(ROOT/'services/directory/deploy',documentation/'deploy',dirs_exist_ok=True)
    return {**identity,'path':binary.name,'sha256':digest(binary),'cgo_enabled':False,
            'go_sum_sha256':digest(ROOT/'services/directory/go.sum')}


def verify(folder, game_build):
    """Execute the shipped CLI on its actual Linux host and compare both identities."""
    expected = game_build['directory_service']
    binary = folder/'pacific-directory'
    assert digest(binary) == expected['sha256'], 'Packaged directory checksum differs'
    result = subprocess.run([str(binary),'version'],capture_output=True,text=True,timeout=15,check=True)
    identity = json.loads(result.stdout)
    sidecar = json.loads((folder/'directory-build.json').read_text())
    assert identity == sidecar, 'Directory embedded/sidecar identity differs'
    for key in ['version','build_number','commit','working_tree_dirty','protocol_version','content_hash','distribution']:
        assert identity[key] == game_build[key], 'Directory/game identity differs: '+key
    for key,value in identity.items():
        assert expected[key] == value, 'Directory manifest identity differs: '+key
    assert identity['go_version'] == 'go'+json.loads((ROOT/'tools/toolchain.lock').read_text())['go']
    assert identity['service_schema'] == 4 and identity['target_platform'] == 'linux-amd64'
    return identity
