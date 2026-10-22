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
    validate_audio()
    validate_icons()
    validate_posters()
    validate_decorations()
    validate_arcade_sprites()
    validate_expansion40()


def validate_expansion40():
    provenance=json.loads((ROOT/'assets/source/expansion40/generation.json').read_text())
    catalog=json.loads((ROOT/'assets/exported/billboards/expansion40/catalog.json').read_text())
    assert provenance['tool']=='built-in image_gen' and len(provenance['images'])==7
    assert len(catalog['assets'])==52 and len({row['id'] for row in catalog['assets']})==52
    for row in provenance['images']:
        assert digest(ROOT/row['source'])==digest(ROOT/row['export'])==row['sha256']
        assert row['prompt'] and row['transparent_background']
        assert 'mipmaps/generate=true' in (ROOT/row['export']).with_suffix('.png.import').read_text()
    for row in catalog['assets']:
        assert digest(ROOT/row['path'])==row['sha256']
        x,y,w,h=row['uv_bounds_pixels'];width,height=row['pixels']
        assert x>=0 and y>=0 and w>0 and h>0 and x+w<=width and y+h<=height
        assert abs(row['size_m'][0]/row['size_m'][2]-w/h)<.0001
    print('Validated six untouched imagegen atlases and one standalone tree, 52 alpha-bounded sprites and original prompts')


def validate_arcade_sprites():
    provenance=json.loads((ROOT/'assets/source/billboards/arcade-generation.json').read_text())
    for row in provenance['images']:
        source=ROOT/row['source']; path=ROOT/row['export']
        assert digest(source)==digest(path)==row['sha256']
        assert struct.unpack_from('>II',path.read_bytes(),16)==tuple(row['pixels'])
        assert row['prompt'] and row['tool']=='built-in image_gen'
        assert 'mipmaps/generate=true' in path.with_suffix('.png.import').read_text()
    catalog=json.loads((ROOT/'assets/exported/billboards/catalog.json').read_text())
    for row in catalog['assets']:
        x,y,w,h=row['uv_bounds_pixels']
        assert x>=0 and y>=0 and w>0 and h>0
        assert x+w<=row['pixels'][0] and y+h<=row['pixels'][1]
        assert digest(ROOT/row['path'])==row['sha256']
    print('Validated arcade sprite and sky provenance, atlas regions, hashes and mipmaps')


def validate_decorations():
    provenance=json.loads((ROOT/'assets/source/decorations/generation.json').read_text())
    for row in provenance['images']:
        source=ROOT/row['source'];path=ROOT/row['export']
        assert digest(source)==digest(path)==row['sha256']
        assert struct.unpack_from('>II',path.read_bytes(),16)==tuple(row['pixels'])
        assert row['transparent_background'] and row['prompt'] and row['tool']=='built-in image_gen'
        assert 'mipmaps/generate=true' in path.with_suffix('.png.import').read_text()
    print('Validated original unmodified transparent waterfall artwork, provenance and mipmaps')


def validate_posters():
    catalog=json.loads((ROOT/'assets/exported/posters/catalog.json').read_text())
    provenance=json.loads((ROOT/catalog['source']).read_text())
    assert catalog['license']=='MIT' and len(catalog['assets'])==10
    assert {row['id'] for row in catalog['assets']}=={row['id'] for row in json.loads((ROOT/'game/content/tracks.json').read_text())['tracks'][:10]}
    for row in catalog['assets']:
        source=ROOT/row['source']; path=ROOT/row['path']
        assert digest(source)==digest(path)==row['sha256']
        assert struct.unpack_from('>II',path.read_bytes(),16)==tuple(row['pixels'])==(1536,1024)
        assert row['size_m']==[12,8]
        assert 'mipmaps/generate=true' in path.with_suffix('.png.import').read_text()
        original=next(item for item in provenance['images'] if item['id']==row['id'])
        assert original['source']==row['source'] and original['prompt'] and not original['transparent_background']
    print('Validated ten unmodified original painted course posters, provenance, hashes and mipmaps')


def validate_icons():
    import xml.etree.ElementTree as ET
    value=json.loads((ROOT/'assets/exported/icons/catalog.json').read_text())
    rows=value['assets']
    assert value['license']=='MIT' and (ROOT/value['source']).is_file()
    assert len(rows)==94 and len({r['id'] for r in rows})==94
    assert [sum(row['category']==kind for row in rows) for kind in ['action','tab','menu','connection','car','track','medal','trophy','paint']]==[15,8,9,3,4,40,4,3,8]
    actions=['steer_left','steer_right','accelerate','brake','handbrake','recover','camera','look_back','pause','ui_up','ui_down','ui_left','ui_right','ui_accept','ui_cancel']
    assert {row['id'] for row in rows if row['category']=='action'}=={'action_'+a for a in actions}
    for row in rows:
        path=ROOT/row['path'];data=path.read_bytes()
        assert digest(path)==row['sha256'],row['id']
        svg=ET.fromstring(data)
        assert svg.attrib['viewBox']=='0 0 24 24' and svg.attrib['width']==svg.attrib['height']=='64'
        assert 'http' not in data.decode().replace('http://www.w3.org/2000/svg',''),'Icons must contain no external references'
        assert 'mipmaps/generate=true' in path.with_suffix('.svg.import').read_text()
        if row['category']=='track':
            bake=json.loads((ROOT/f'game/content/baked/{row["id"].removeprefix("track_")}.json').read_text())
            assert row['route_hash']==bake['content_hash']
        if row['category']=='paint':
            paints=json.loads((ROOT/'game/content/cars.json').read_text())['paints']
            assert row['color']==paints[int(row['id'].removeprefix('paint_'))]
    print('Validated 94 original editable SVG interface icons, canonical course outlines, paint swatches and mipmaps')


def validate_audio():
    value=json.loads((ROOT/'assets/exported/audio/catalog.json').read_text())
    assert value['license']=='MIT AND CC0-1.0' and (ROOT/value['source']).is_file()
    rows=value['assets']
    assert len(rows)==48 and len({row['id'] for row in rows})==48
    assert [sum(row['category']==kind for row in rows) for kind in ['music','engine','effect','voice']]==[7,16,17,8]
    assert {row['text'] for row in rows if row['category']=='voice'}=={'Three','Two','One','Go','Final lap','Wrong way','New best time','Finish'}
    for row in rows:
        path=ROOT/row['path']
        assert digest(path)==row['sha256'] and path.read_bytes()[:4]==b'OggS',row['id']
        assert row['sample_rate']==44100 and row['channels'] in [1,2]
        assert row['true_peak_dbfs']<=-2.5,row['id']
        settings=path.with_suffix('.ogg.import').read_text()
        assert ('loop='+str(row['loop']).lower()) in settings,row['id']
        if row['category']=='music':
            assert row['loop'] and row['channels']==2 and row['license']=='CC0-1.0'
            assert row['bpm']==0 and row['beats']==0, 'Do not invent tempo metadata for recordings'
            assert 30<=row['duration_seconds']<=300
            assert digest(ROOT/row['source_path'])==row['source_sha256']
            assert 'publicdomain/zero/1.0' in (ROOT/row['license_evidence']).read_text()
            assert -19<=row['integrated_lufs']<=-17
        if row['category']=='engine': assert row['loop'] and row['duration_seconds']==2
    print('Validated 48 Vorbis streams, seven recorded CC0 rock/metal selections, four engine profiles and eight fixed prompts')


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
        assert not gltf.get('images') and not gltf.get('textures'),row['id']+' must use the runtime shared atlas instead of embedding duplicate images'
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
    assert {r['id'] for r in courses['courses']}=={r['id'] for r in terrain['courses']}=={r['id'] for r in json.loads((ROOT/'game/content/tracks.json').read_text())['tracks']}
    by_id={row['id']:row for row in assets}
    for row in courses['courses']:
        assert len(row['landmarks'])==5
        if not row.get('expansion40'):
            assert all(by_id[landmark['id']]['category']=='landmark' and 0<=landmark['u']<1 for landmark in row['landmarks'])
        else:
            sprites=json.loads((ROOT/'assets/exported/billboards/expansion40/catalog.json').read_text())['assets']
            sprite_ids={item['id'] for item in sprites}|{'alpine_fir'}
            assert all(landmark['id'] in sprite_ids and 0<=landmark['u']<1 for landmark in row['landmarks'])
        postcard=ROOT/f'assets/exported/thumbnails/{row["id"]}.png'
        assert struct.unpack_from('>II',postcard.read_bytes(),16)==(512,288),'Course postcard must be a shipped 512x288 scene render'
    for row in terrain['courses']:
        assert digest(ROOT/row['path'])==row['sha256']
        bake=json.loads((ROOT/f'game/content/baked/{row["id"]}.json').read_text())
        assert row['route_hash']==bake['content_hash'],'Cosmetic terrain must follow the current canonical bake'
    print('Validated 30 landmarks, five vegetation models, seven props, forty cosmetic terrains and shared atlases')


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
