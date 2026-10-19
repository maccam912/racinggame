#!/usr/bin/env python3
"""Author original launcher/desktop icons and verify committed source/containers."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
from bootstrap import ROOT


def digest(path):
    with path.open('rb') as file:return hashlib.file_digest(file,'sha256').hexdigest()


def check(folder,manifest):
    assert digest(ROOT/manifest['source'])==manifest['source_sha256'],'Icon generator changed; regenerate assets'
    for row in manifest['files']:
        path=ROOT/row['path']
        assert path.is_file() and digest(path)==row['sha256'],'Icon checksum differs: '+str(path)
        if row['kind'] in ['png','macos_iconset']:
            header=path.read_bytes()[:24]
            assert header[:8]==b'\x89PNG\r\n\x1a\n'
            assert struct.unpack('>II',header[16:24])==(row['width'],row['height'])
    data=(folder/'app.ico').read_bytes()
    assert struct.unpack_from('<HHH',data)==(0,1,7)
    sizes=[]
    for index in range(7):
        width,height,_,_,planes,bits,length,offset=struct.unpack_from('<BBBBHHII',data,6+index*16)
        width,height=width or 256,height or 256
        assert width==height and planes==1 and bits==32 and offset+length<=len(data)
        assert data[offset:offset+8]==b'\x89PNG\r\n\x1a\n'
        assert struct.unpack('>II',data[offset+16:offset+24])==(width,height)
        sizes.append(width)
    assert sizes==[16,24,32,48,64,128,256]
    data=(folder/'app.icns').read_bytes()
    assert data[:4]==b'icns' and struct.unpack('>I',data[4:8])[0]==len(data)
    kinds=[];offset=8
    while offset<len(data):
        kind,length=struct.unpack_from('>4sI',data,offset)
        assert length>=8 and offset+length<=len(data)
        kinds.append(kind.decode('ascii'));offset+=length
    assert offset==len(data) and all(kind in kinds for kind in ['ic07','ic08','ic09','ic10','ic11','ic12','ic13','ic14'])
    subprocess.run([sys.executable,str(ROOT/'tools/godot.py'),'--headless','--script','tests/app_icon_tests.gd'],cwd=ROOT,check=True)
    print('APP_ICON_SOURCE_HASH_PNG_WINDOWS_7_SIZES_MACOS_RETINA_CONTAINERS_PASS')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--generate',action='store_true',help='macOS authoring, using the pinned SVG rasterizer and system iconutil')
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    folder=ROOT/'assets/exported/branding'
    if args.generate:
        if sys.platform!='darwin':raise RuntimeError('macOS iconutil is required for reproducible source iconset packaging')
        subprocess.run([sys.executable,str(ROOT/'tools/godot.py'),'--headless','--script','assets/source/generate_app_icons.gd'],cwd=ROOT,check=True)
        subprocess.run(['/usr/bin/iconutil','--convert','icns','--output',str(folder/'app.icns'),str(folder/'app.iconset')],check=True)
        manifest=json.loads((folder/'catalog.json').read_text())
        manifest['files'].append({'path':'assets/exported/branding/app.icns','kind':'macos_icon','sha256':digest(folder/'app.icns')})
        (folder/'catalog.json').write_text(json.dumps(manifest,indent=2)+'\n')
    check(folder,json.loads((folder/'catalog.json').read_text()))


if __name__=='__main__':main()
