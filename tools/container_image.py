#!/usr/bin/env python3
"""Prepare/build an OCI runtime only from a checksum-verified server release ZIP."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import stat
import subprocess
import zipfile
from bootstrap import ROOT


def digest(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file,'sha256').hexdigest()


def prepare(archive, context):
    expected = archive.with_suffix('.sha256').read_text().strip().split()
    assert len(expected)==2 and expected[1]==archive.name and expected[0]==digest(archive), 'Server archive checksum differs'
    context.mkdir(parents=True)
    bundle = context/'bundle'
    bundle.mkdir()
    with zipfile.ZipFile(archive) as source:
        for item in source.infolist():
            relative = Path(item.filename)
            assert not relative.is_absolute() and '..' not in relative.parts and not stat.S_ISLNK(item.external_attr>>16), 'Unsafe release archive member'
            assert not item.filename.endswith(('.key','.sqlite','.keystore','.p12')), 'Operator secrets/data must not enter image layers'
        source.extractall(bundle)
    for name in ['pacific-directory','pacific-rush-server.x86_64']:
        (bundle/name).chmod(0o755)
    data = json.loads((bundle/'build.json').read_text())
    assert data['target_platform']=='server'
    assert digest(bundle/'pacific-directory')==data['directory_service']['sha256']
    identity = json.loads((bundle/'directory-build.json').read_text())
    for key in ['commit','build_number','version','working_tree_dirty','protocol_version','content_hash','distribution']:
        assert identity[key]==data[key], 'Service/game build identities differ'
    source = bundle/'operator/deploy/container'
    lock = json.loads((ROOT/'tools/toolchain.lock').read_text())
    assert (source/'Dockerfile').read_text().splitlines()[0]=='FROM '+lock['server_container']['base'], 'Container base differs from toolchain pin'
    assert lock['caddy_digest'] in (source/'compose.yaml').read_text(), 'Caddy image differs from toolchain pin'
    shutil.copy(source/'Dockerfile',context/'Dockerfile')
    shutil.copy(source/'host.sh',context/'host.sh')
    (context/'host.sh').chmod(0o755)
    (context/'.dockerignore').write_text('*\n!bundle/\n!bundle/**\n!Dockerfile\n!host.sh\n')
    manifest={'prepared':True,'built':False,'archive':archive.name,'archive_sha256':expected[0],
              'base':lock['server_container']['base'],'platform':'linux/amd64','game_build':data,
              'boundary':'Context contains the verified server bundle and its checked-in runtime files, never operator keys/databases.'}
    (context/'context.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('archive',type=Path)
    parser.add_argument('--context',type=Path,required=True,help='New output folder, never overwritten')
    parser.add_argument('--tag',help='Local image tag; required for a real Docker build')
    parser.add_argument('--prepare-only',action='store_true')
    args=parser.parse_args()
    if not args.prepare_only and not args.tag:parser.error('--tag is required without --prepare-only')
    manifest=prepare(args.archive.resolve(),args.context.resolve())
    if not args.prepare_only:
        try:
            subprocess.run(['docker','info','--format','{{.ServerVersion}}'],check=True,capture_output=True,text=True)
        except (OSError,subprocess.CalledProcessError) as error:
            raise RuntimeError('No available Docker engine; prepared context retained at '+str(args.context)) from error
        data=manifest['game_build']
        subprocess.run(['docker','build','--platform','linux/amd64','--tag',args.tag,
                        '--label','org.opencontainers.image.source=https://github.com/maccam912/racinggame',
                        '--label','org.opencontainers.image.version='+data['version'],
                        '--label','org.opencontainers.image.revision='+data['commit'],
                        '--label','org.opencontainers.image.licenses=MIT',str(args.context.resolve())],check=True)
        inspect=json.loads(subprocess.check_output(['docker','image','inspect',args.tag],text=True))[0]
        manifest.update(built=True,image_id=inspect['Id'],architecture=inspect['Architecture'],os=inspect['Os'],tag=args.tag)
        assert inspect['Architecture']=='amd64' and inspect['Os']=='linux'
        (args.context/'context.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'prepared':True,'built':manifest['built'],'context':str(args.context),'image_id':manifest.get('image_id')}),flush=True)


if __name__=='__main__':main()
