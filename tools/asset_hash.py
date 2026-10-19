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
    validate_scenery()


def validate_scenery():
    library = json.loads((ROOT/'assets/exported/scenery/library.json').read_text())
    assert library['license']=='MIT' and library['blender']=='5.1.2'
    assert (ROOT/library['source']).is_file() and (ROOT/library['editable_source']).is_file()
    assets=library['assets']
    assert len(assets)==47 and len({row['id'] for row in assets})==47
    assert [sum(row['category']==category for row in assets) for category in ['landmark','foliage','prop','building','landscape']]==[30,5,7,3,2]
    for row in assets:
        path=ROOT/row['path']; data=path.read_bytes()
        assert digest(path)==row['sha256'],row['id']
        size,kind=struct.unpack_from('<II',data,12)
        assert kind==0x4E4F534A
        gltf=json.loads(data[20:20+size])
        counts={}
        for node in gltf['nodes']:
            if 'mesh' not in node: continue
            level=next(level for level in range(3) if f'LOD{level}' in node['name'])
            primitives=gltf['meshes'][node['mesh']]['primitives']
            assert len(primitives)==1
            primitive=primitives[0]
            assert 'TEXCOORD_0' in primitive['attributes']
            # Identity mesh transforms are required by the shared MultiMesh batches.
            assert node.get('translation',[0,0,0])==[0,0,0],node['name']
            counts[level]=gltf['accessors'][primitive['indices']]['count']//3
        assert [counts[i] for i in range(3)]==row['triangles'],row['id']
        cap={'landmark':20000,'foliage':1200,'prop':500,'building':3000,'landscape':500}[row['category']]
        assert counts[0]<=cap
        if row['category']=='landmark': assert counts[1]<=counts[0]/2
        if row['category']=='foliage': assert counts[1]<=200 and counts[2]<=8
        assert all(value>0 for value in counts.values())
        settings=path.with_suffix('.glb.import').read_text()
        assert 'gltf/embedded_image_handling=0' in settings and 'meshes/generate_lods=false' in settings
    for name,size in [('scenery_atlas',1024),('props_atlas',512),('foliage_atlas',512)]:
        path=ROOT/f'assets/exported/textures/{name}.png'
        assert struct.unpack_from('>II',path.read_bytes(),16)==(size,size)
        assert 'mipmaps/generate=true' in path.with_suffix('.png.import').read_text()
    courses=json.loads((ROOT/'assets/exported/scenery/courses.json').read_text())
    assert courses==json.loads((ROOT/'assets/source/course_specs.json').read_text())
    terrain=json.loads((ROOT/'assets/exported/scenery/terrain.json').read_text())
    assert len(courses['courses'])==len(terrain['courses'])==6
    by_id={row['id']:row for row in assets}
    for row in courses['courses']:
        assert len(row['landmarks'])==5
        assert all(by_id[landmark['id']]['category']=='landmark' and 0<=landmark['u']<1 for landmark in row['landmarks'])
        postcard=ROOT/f'assets/exported/thumbnails/{row["id"]}.png'
        assert struct.unpack_from('>II',postcard.read_bytes(),16)==(512,288),'Course postcard must be a shipped 512x288 scene render'
    for row in terrain['courses']:
        assert digest(ROOT/row['path'])==row['sha256']
        bake=json.loads((ROOT/f'game/content/baked/{row["id"]}.json').read_text())
        assert row['route_hash']==bake['content_hash'],'Cosmetic terrain must follow the current canonical bake'
    print('Validated 30 landmarks, five vegetation models, seven props, six cosmetic terrains and shared atlases')


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
