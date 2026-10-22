"""Bake cosmetic terrain chunks around unchanged canonical road samples (Blender)."""
import argparse
import sys
import hashlib
import json
import math
from pathlib import Path
import bpy
from mathutils.kdtree import KDTree

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/exported/scenery'
sys.path.insert(0,str(Path(__file__).resolve().parent))
from terrain_profiles import relief as distant_relief, PROFILES


def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)))
    return t*t*(3-2*t)


def main():
    courses=json.loads((ROOT/'assets/source/course_specs.json').read_text())
    arguments = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument('--tracks', help='Regenerate only these comma-separated courses, preserving the other terrain bytes')
    args = parser.parse_args(arguments)
    selected = set(args.tracks.split(',')) if args.tracks else {spec['id'] for spec in courses['courses']}
    assert selected and selected <= {spec['id'] for spec in courses['courses']}
    previous = json.loads((OUT/'terrain.json').read_text()) if (OUT/'terrain.json').exists() else {'courses':[]}
    retained = {row['id']:row for row in previous['courses']}
    reports=[]
    for spec in courses['courses']:
        if spec['id'] not in selected:
            assert spec['id'] in retained, 'An unselected course needs an existing terrain bake'
            reports.append(retained[spec['id']])
            continue
        bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
        bake=json.loads((ROOT/f'game/content/baked/{spec["id"]}.json').read_text())
        rows=bake['samples']
        tree=KDTree(len(rows))
        for i,row in enumerate(rows): tree.insert((row[0],row[2],0),i)
        tree.balance()
        margin=float(spec.get("terrain_margin_m",320))
        low_x=math.floor((min(r[0] for r in rows)-margin)/160)*160
        high_x=math.ceil((max(r[0] for r in rows)+margin)/160)*160
        low_z=math.floor((min(r[2] for r in rows)-margin)/160)*160
        high_z=math.ceil((max(r[2] for r in rows)+margin)/160)*160
        sea_level=float(spec.get('sea_level',min(row[1] for row in rows)-3.5))
        root=bpy.data.objects.new(spec['id']+'_Terrain',None)
        bpy.context.collection.objects.link(root)
        chunks=[]
        for x0 in range(low_x,high_x,160):
            for z0 in range(low_z,high_z,160):
                vertices,faces,shades=[],[],[]
                for iz in range(6):
                    for ix in range(6):
                        x,z=x0+ix*32,z0+iz*32
                        _,index,distance=tree.find((x,z,0))
                        row=rows[index]
                        signed=(x-row[0])*-row[5]+(z-row[2])*row[3]
                        wave=math.sin(x*.009+z*.006)*.55+math.cos(z*.013-x*.003)*.45
                        height=row[1]-2.8+smooth(62,180,distance)*(8+wave*(21 if spec['id']=='sunstone_canyon' else 12))
                        if spec.get('terrain_mode')=='flat': height=float(spec['terrain_height'])+wave*.6
                        if spec['id'] in PROFILES: height += distant_relief(spec['id'],x,z,distance)
                        coast=spec['coast_interval']
                        if coast and coast[0]<=row[7]<=coast[1] and signed>24:
                            weight=smooth(24,60,signed)
                            height=height*(1-weight)+(sea_level-1.5)*weight
                        vertices.append((x,-z,height))
                        shade=.91+.06*math.sin(x*.035+z*.021)+.03*math.cos(z*.04)
                        shades.append((shade,shade,shade,1))
                for iz in range(5):
                    for ix in range(5):
                        a=iz*6+ix
                        faces.extend([(a,a+6,a+7),(a,a+7,a+1)])
                mesh=bpy.data.meshes.new('GroundChunk')
                mesh.from_pydata(vertices,[],faces); mesh.update()
                colors=mesh.color_attributes.new(name='PacificTerrain',type='FLOAT_COLOR',domain='CORNER')
                for loop in mesh.loops: colors.data[loop.index].color=shades[loop.vertex_index]
                obj=bpy.data.objects.new('Ground_%d_%d'%(x0,z0),mesh)
                bpy.context.collection.objects.link(obj); obj.parent=root; chunks.append(obj)
        bpy.ops.object.select_all(action='SELECT')
        path=OUT/(spec['id']+'_terrain.glb')
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_materials='NONE',export_vertex_color='NAME',export_vertex_color_name='PacificTerrain',export_all_vertex_colors=False)
        report={'id':spec['id'],'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'chunks':len(chunks),'triangles':len(chunks)*50,'chunk_width_m':160,'grid_step_m':32,'sea_level':sea_level,'route_hash':bake['content_hash'],'bounds_xz_m':[low_x,low_z,high_x,high_z]}
        if spec['id'] in PROFILES:
            report.update(relief_profile=PROFILES[spec['id']][0],protected_road_band_m=240,protected_vertex_band_m=286,relief_source='assets/source/terrain_profiles.py',relief_source_sha256=hashlib.sha256((ROOT/'assets/source/terrain_profiles.py').read_bytes()).hexdigest())
        reports.append(report)
    (OUT/'terrain.json').write_text(json.dumps({'schema_version':1,'source':'assets/source/generate_terrain.py','license':'MIT','courses':reports},indent=2)+'\n')
    (OUT/'courses.json').write_text(json.dumps(courses,indent=2)+'\n')
    print('PACIFIC_COSMETIC_TERRAIN_EXPORTED',len(reports))


if __name__=='__main__': main()
