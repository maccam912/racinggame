#!/usr/bin/env python3
"""Separate cosmetic identity and source/budget checks, independent of gameplay."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file,'sha256').hexdigest()


def compute():
    files = [p for folder in ['assets/exported','assets/fonts'] for p in (ROOT/folder).rglob('*')
             if p.is_file() and p.suffix not in ['.import','.uid'] and not p.name.startswith('.')]
    files.append(ROOT/'assets/manifest.json')
    context = hashlib.sha256()
    hashes = {}
    for path in sorted(files):
        name = path.relative_to(ROOT).as_posix()
        context.update(name.encode())
        context.update(path.read_bytes())
        hashes[name] = digest(path)
    return {'schema_version':1,'asset_hash':context.hexdigest(),'files':hashes}


def validate():
    value = json.loads((ROOT/'assets/exported/cars/inventory.json').read_text())
    assert value['license']=='MIT' and value['blender']=='5.1.2'
    assert (ROOT/value['source']).is_file() and (ROOT/value['editable_source']).is_file()
    atlas = ROOT/value['atlas']['path']
    data = atlas.read_bytes()
    assert data[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack_from('>II',data,16)==(1024,1024)
    assert digest(atlas)==value['atlas']['sha256']
    assert {car['id'] for car in value['cars']}=={'comet','needle','switch','sunset'}
    for car in value['cars']:
        path = ROOT/car['path']
        data = path.read_bytes()
        assert digest(path)==car['sha256']
        magic,version,length = struct.unpack_from('<III',data)
        assert magic==0x46546C67 and version==2 and length==len(data)
        chunk_length,chunk_type = struct.unpack_from('<II',data,12)
        assert chunk_type==0x4E4F534A
        gltf = json.loads(data[20:20+chunk_length])
        def meshes(node):
            result = [gltf['meshes'][node['mesh']]] if 'mesh' in node else []
            for child in node.get('children',[]): result += meshes(gltf['nodes'][child])
            return result
        for level in range(3):
            node = next(node for node in gltf['nodes'] if node.get('name','').startswith('LOD'+str(level)))
            parts = meshes(node)
            triangles = 0
            for mesh in parts:
                assert len(mesh['primitives'])==1
                primitive = mesh['primitives'][0]
                assert primitive.get('mode',4)==4
                assert 'COLOR_0' in primitive['attributes'] and 'TEXCOORD_0' in primitive['attributes']
                triangles += gltf['accessors'][primitive['indices']]['count']//3
            expected = car['lods'][level]
            assert len(parts)==5 and triangles==expected['triangles'] and triangles<=[12000,4000,1200][level]
        settings = (path.with_suffix('.glb.import')).read_text()
        assert 'meshes/generate_lods=false' in settings and 'gltf/embedded_image_handling=0' in settings
    print('Validated four original cars, twelve explicit LODs, shared 1024 atlas and editable source')


if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    validate()
    value = json.dumps(compute(),indent=2)+'\n'
    path = ROOT/'assets/checksums.json'
    if args.check:
        assert path.read_text()==value,'Cosmetic hash stale: run python3 tools/asset_hash.py'
    else:
        path.write_text(value)
    print(compute()['asset_hash'])
