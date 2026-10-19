"""Original Pacific Rush models. Blender 5.1.2 --background --python this_file.

Authoring axes: X right, Y toward the nose, Z up. glTF converts to Godot -Z forward.
Body/Stripe materials are neutral atlas regions tinted by CarVisual at runtime.
"""
from array import array
import hashlib
import json
import math
from pathlib import Path
import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/exported/cars'
TEXTURES = ROOT/'assets/exported/textures'
PALETTE = {'Rubber':'222C39','Glass':'203C50','Rim':'E7DFC9','Headlamp':'FFF0BA',
           'Brake':'A32F39','Chrome':'8CA2AA','Grille':'343C49','Interior':'172C40'}
SPECS = {
    'comet': {'length':4.10,'width':1.88,'roof':1.24,'cab_rear':-.90,'cab_front':.90,'roof_rear':-.60,'roof_front':.43,'roof_width':1.40,'axle':1.25,'stripe':0.0,'paint':'F16B50',
              'profiles':[(-1,.76,.49),(-.9,.94,.62),(-.55,1,.69),(0,1,.70),(.55,.97,.65),(.9,.87,.53),(1,.66,.38)]},
    'needle': {'length':4.34,'width':1.96,'roof':1.00,'cab_rear':-.95,'cab_front':1.00,'roof_rear':-.63,'roof_front':.25,'roof_width':1.38,'axle':1.30,'stripe':-.27,'paint':'20BFC5',
               'profiles':[(-1,.88,.54),(-.88,1,.62),(-.50,1,.60),(0,.97,.57),(.5,.93,.49),(.88,.81,.34),(1,.68,.24)]},
    'switch': {'length':3.62,'width':1.78,'roof':1.40,'cab_rear':-1.40,'cab_front':.80,'roof_rear':-1.18,'roof_front':.35,'roof_width':1.46,'axle':1.10,'stripe':0.0,'paint':'F3CD48',
               'profiles':[(-1,.90,.58),(-.90,1,.65),(-.55,1,.66),(0,1,.65),(.55,.97,.61),(.90,.87,.52),(1,.78,.41)]},
    'sunset': {'length':4.58,'width':2.04,'roof':1.22,'cab_rear':-1.10,'cab_front':.78,'roof_rear':-.65,'roof_front':.24,'roof_width':1.51,'axle':1.36,'stripe':.38,'paint':'8465CC',
               'profiles':[(-1,.88,.51),(-.90,.98,.62),(-.55,1,.68),(0,1,.67),(.55,1,.62),(.90,.90,.53),(1,.80,.39)]}}
MATERIALS = {}
ATLAS = None


def linear(channel):
    return channel/12.92 if channel<=.04045 else ((channel+.055)/1.055)**2.4


def color(hex_value):
    return tuple(int(hex_value[i:i+2],16)/255 for i in (0,2,4))


def create_atlas():
    global ATLAS
    size = 1024
    image = bpy.data.images.new('PacificCarAtlas',width=size,height=size,alpha=True)
    image.colorspace_settings.name = 'sRGB'
    pixels = array('f')
    trim = list(PALETTE.values())
    for y in range(size):
        for x in range(size):
            if x<512 and y<512:
                shade = .97
                if x in range(24,28) or x in range(482,486) or y in range(74,78) or y in range(405,409): shade = .67
                if 32<x<478 and 414<y<422: shade = 1.0
                rgb = (shade,shade,shade)
            elif x>=512 and y<512:
                index = min(7,(y//128)*2+(x-512)//256)
                rgb = color(trim[index])
            else:
                rgb = color('F5EBD3')
            pixels.extend((linear(rgb[0]),linear(rgb[1]),linear(rgb[2]),1))
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(TEXTURES/'cars_atlas.png')
    image.file_format = 'PNG'
    image.save()
    ATLAS = image
    for name in ['Body','Stripe',*PALETTE]:
        material = bpy.data.materials.new('Pacific_'+name)
        material.use_nodes = True
        node = material.node_tree.nodes.get('Principled BSDF')
        node.inputs['Roughness'].default_value = .34 if name in ['Body','Stripe'] else .85 if name=='Rubber' else .42
        node.inputs['Metallic'].default_value = .3 if name in ['Body','Stripe','Rim','Chrome'] else 0
        texture = material.node_tree.nodes.new('ShaderNodeTexImage')
        texture.image = image
        texture.interpolation = 'Linear'
        material.node_tree.links.new(texture.outputs['Color'],node.inputs['Base Color'])
        MATERIALS[name] = material


def empty(name,parent=None,location=(0,0,0)):
    obj = bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = location
    return obj


def apply_modifier(obj,modifier):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def apply_transform(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)


def mesh(name,vertices,faces,parent,role='Body',smooth=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices,[],faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.data.materials.append(MATERIALS[role])
    obj['pacific_role'] = role
    for polygon in data.polygons: polygon.use_smooth = smooth
    return obj


def cube(name,at,dimensions,parent,role='Body',bevel=0,segments=1):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    apply_transform(obj)
    obj.parent = parent
    obj.data.materials.append(MATERIALS[role])
    obj['pacific_role'] = role
    if bevel:
        modifier = obj.modifiers.new('Broad edge highlights','BEVEL')
        modifier.width = bevel
        modifier.segments = segments
        apply_modifier(obj,modifier)
    return obj


def torus(name,at,major,minor,parent,role,segments=24,cross=8,axial=1.0):
    bpy.ops.mesh.primitive_torus_add(major_segments=segments,minor_segments=cross,
                                   major_radius=major,minor_radius=minor,location=at,
                                   rotation=(0,math.pi/2,0))
    obj = bpy.context.object
    obj.name = name
    obj.scale.z = axial
    apply_transform(obj)
    obj.parent = parent
    obj.data.materials.append(MATERIALS[role])
    obj['pacific_role'] = role
    for polygon in obj.data.polygons: polygon.use_smooth = True
    return obj


def cylinder(name,at,radius,depth,parent,role,segments=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments,radius=radius,depth=depth,
                                      location=at,rotation=(0,math.pi/2,0))
    obj = bpy.context.object
    obj.name = name
    apply_transform(obj)
    obj.parent = parent
    obj.data.materials.append(MATERIALS[role])
    obj['pacific_role'] = role
    return obj


def body_top(spec,y):
    value = y/(spec['length']/2)
    profiles = spec['profiles']
    for a,b in zip(profiles,profiles[1:]):
        if a[0]<=value<=b[0]:
            t = (value-a[0])/(b[0]-a[0])
            return a[2]*(1-t)+b[2]*t
    return profiles[0 if value<0 else -1][2]


def build_body(identifier,spec,level,parent):
    vertices,faces = [],[]
    for fraction,width_factor,height in spec['profiles']:
        y = fraction*spec['length']/2
        w = spec['width']/2*width_factor
        ring = [(-.84*w,.08),(-w,.18),(-w,.75*height),(-.88*w,height),
                (.88*w,height),(w,.75*height),(w,.18),(.84*w,.08)]
        vertices.extend((x,y,z) for x,z in ring)
    for index in range(len(spec['profiles'])-1):
        for side in range(8): faces.append((index*8+side,index*8+(side+1)%8,(index+1)*8+(side+1)%8,(index+1)*8+side))
    faces.extend([tuple(reversed(range(8))),tuple((len(spec['profiles'])-1)*8+i for i in range(8))])
    obj = mesh(identifier+'_Body',vertices,faces,parent,smooth=True)
    if level<2:
        for axle in [-spec['axle'],spec['axle']]:
            cutter = cylinder('Arch cutter',(0,axle,.03),.405,spec['width']+1,None,'Rubber',32 if level==0 else 16)
            modifier = obj.modifiers.new('Open wheel arch','BOOLEAN')
            modifier.operation = 'DIFFERENCE'
            modifier.solver = 'EXACT'
            modifier.object = cutter
            apply_modifier(obj,modifier)
            bpy.data.objects.remove(cutter,do_unlink=True)
        modifier = obj.modifiers.new('Soft sheet metal edges','BEVEL')
        modifier.width = .026 if level==0 else .018
        modifier.segments = 3 if level==0 else 1
        modifier.limit_method = 'ANGLE'
        apply_modifier(obj,modifier)
    return obj


def build_cabin(identifier,spec,level,parent):
    bottom = .62 if identifier!='needle' else .52
    width = spec['width']*.43
    roof_width = spec['roof_width']/2
    vertices = [(-width,spec['cab_rear'],bottom),(width,spec['cab_rear'],bottom),
                (-width,spec['cab_front'],bottom),(width,spec['cab_front'],bottom),
                (-roof_width,spec['roof_rear'],spec['roof']),(roof_width,spec['roof_rear'],spec['roof']),
                (-roof_width,spec['roof_front'],spec['roof']),(roof_width,spec['roof_front'],spec['roof'])]
    mesh(identifier+'_Windows',vertices,[(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5),(4,5,7,6)],parent,'Glass')
    cube(identifier+'_Roof',(0,(spec['roof_rear']+spec['roof_front'])/2,spec['roof']+.025),
         (spec['roof_width']+.055,spec['roof_front']-spec['roof_rear']+.05,.07),parent,'Body',.025 if level==0 else 0,2)
    if level<2:
        for side in [-1,1]:
            cube(identifier+'_B_pillar',(side*(width+roof_width)/2,-.16,(bottom+spec['roof'])/2),(.07,.085,spec['roof']-bottom),parent,'Body')
            cube(identifier+'_Mirror',(side*(spec['width']/2+.07),.55,.72),(.18,.20,.11),parent,'Body',.025 if level==0 else 0,2)


def stripe(identifier,spec,parent):
    if identifier=='switch':
        for side in [-1,1]: cube(identifier+'_SideStripe',(side*(spec['width']/2+.008),-.10,.40),(.018,1.85,.065),parent,'Stripe')
        return
    for start,end in [(-spec['length']/2+.10,spec['cab_rear']-.06),(spec['cab_front']+.06,spec['length']/2-.10)]:
        vertices,faces = [],[]
        for index in range(9):
            y = start+(end-start)*index/8
            for side in [-1,1]: vertices.append((spec['stripe']+side*.115,y,body_top(spec,y)+.016))
        for index in range(8): faces.append((index*2,index*2+1,index*2+3,index*2+2))
        mesh(identifier+'_Stripe',vertices,faces,parent,'Stripe')
    cube(identifier+'_RoofStripe',(spec['stripe'],(spec['roof_rear']+spec['roof_front'])/2,spec['roof']+.063),(.23,spec['roof_front']-spec['roof_rear'],.007),parent,'Stripe')


def wheel(identifier,spec,level,parent,side,front):
    axle = spec['axle'] if front else -spec['axle']
    label = ('F' if front else 'R')+('L' if side<0 else 'R')
    root = empty(identifier+'_Wheel_'+label,parent,(side*(spec['width']/2-.02),axle,.02))
    if level<2:
        torus(identifier+'_Tire_'+label,(0,0,0),.27,.07,root,'Rubber',28 if level==0 else 16,12 if level==0 else 6,1.65)
        cylinder(identifier+'_Rim_'+label,(0,0,0),.205,.245,root,'Rim',24 if level==0 else 12)
        cylinder(identifier+'_Hub_'+label,(side*.13,0,0),.07,.025,root,'Grille',12 if level==0 else 8)
        for index in range(6 if level==0 else 4):
            angle = index*math.tau/(6 if level==0 else 4)
            obj = cube(identifier+'_Spoke_'+label,(side*.132,math.cos(angle)*.115,math.sin(angle)*.115),(.012,.055,.15),root,'Chrome')
            obj.rotation_euler.x = math.pi/2-angle
        vertices,faces = [],[]
        segments,cross = (24,6) if level==0 else (12,4)
        for arc in range(segments+1):
            angle = math.pi*arc/segments
            for ring in range(cross):
                tube = math.tau*ring/cross
                radius = .40+.022*math.cos(tube)
                vertices.append((side*(spec['width']/2+.008)+.022*math.sin(tube),axle+radius*math.cos(angle),.03+radius*math.sin(angle)))
        for arc in range(segments):
            for ring in range(cross): faces.append((arc*cross+ring,arc*cross+(ring+1)%cross,(arc+1)*cross+(ring+1)%cross,(arc+1)*cross+ring))
        mesh(identifier+'_Arch_'+label,vertices,faces,parent,'Body',True)
    else:
        cylinder(identifier+'_Tire_'+label,(0,0,0),.34,.24,root,'Rubber',8)
        cylinder(identifier+'_Hub_'+label,(side*.125,0,0),.18,.014,root,'Rim',8)


def assign_uv(obj):
    role = obj.get('pacific_role','Body')
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='PacificAtlas')
    for other in list(obj.data.uv_layers):
        if other!=uv: obj.data.uv_layers.remove(other)
    uv.name = 'PacificAtlas'
    if role in ['Body','Stripe']:
        xs = [vertex.co.x for vertex in obj.data.vertices]
        ys = [vertex.co.y for vertex in obj.data.vertices]
        zs = [vertex.co.z for vertex in obj.data.vertices]
        minimum = (min(xs),min(ys),min(zs))
        extent = (max(xs)-min(xs),max(ys)-min(ys),max(zs)-min(zs))
        for polygon in obj.data.polygons:
            for loop in polygon.loop_indices:
                co = obj.data.vertices[obj.data.loops[loop].vertex_index].co
                if role=='Stripe': coordinate = (.75,.75)
                else:
                    u = (co.y-minimum[1])/max(.001,extent[1])
                    v = (co.z-minimum[2])/max(.001,extent[2]) if abs(polygon.normal.z)<.5 else (co.x-minimum[0])/max(.001,extent[0])
                    coordinate = (.035+u*.43,.035+v*.43)
                uv.data[loop].uv = coordinate
    else:
        index = list(PALETTE).index(role)
        coordinate = (.625+(index%2)*.25,.0625+(index//2)*.125)
        for loop in uv.data: loop.uv = coordinate
    # A single game shader reads these role masks, allowing five mesh draws per
    # visible car LOD: static body plus four independently animated wheels.
    mask = (1,0,0,1) if role=='Body' else (0,1,0,1) if role=='Stripe' else (0,0,1,1) if role=='Brake' else (0,0,0,{'Rubber':.1,'Glass':.2,'Headlamp':.3,'Rim':.4,'Chrome':.4}.get(role,1))
    attribute = obj.data.color_attributes.new(name='PacificRoles',type='FLOAT_COLOR',domain='CORNER')
    for entry in attribute.data: entry.color = mask
    obj.data.materials.clear()
    obj.data.materials.append(MATERIALS['Body'])
    for polygon in obj.data.polygons: polygon.material_index = 0


def join_meshes(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = name
    return result


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def descendants(obj):
    return [obj]+[child for direct in obj.children for child in descendants(direct)]


def build_car(identifier,spec,index):
    root = empty(identifier)
    root['creator'] = 'Pacific Rush procedural asset generator'
    root['license'] = 'MIT'
    report = {'id':identifier,'lods':[],'texture':'assets/exported/textures/cars_atlas.png',
              'authoring_size_m':{'length':spec['length'],'width':spec['width'],'roof':spec['roof']},
              'front_axis':'Blender +Y / exported Godot -Z','default_paint':spec['paint']}
    groups = []
    for level in range(3):
        group = empty('LOD'+str(level),root)
        group['pacific_lod'] = level
        group['distance_m'] = [0,35,90][level]
        name = identifier+'_L'+str(level)
        build_body(name,spec,level,group)
        build_cabin(identifier,spec,level,group)
        stripe(identifier,spec,group)
        for side in [-1,1]:
            for front in [True,False]: wheel(name,spec,level,group,side,front)
            cube(name+'_Headlamp',(side*spec['width']*.31,spec['length']/2+.014,.35),(.44,.03,.13),group,'Headlamp')
            cube(name+'_Brake',(side*spec['width']*.31,-spec['length']/2-.015,.37),(.46,.032,.14),group,'Brake')
        cube(name+'_FrontGrille',(0,spec['length']/2+.016,.23),(spec['width']*.42,.028,.09),group,'Grille')
        if level<2:
            for side in [-1,1]: cube(name+'_DoorHandle',(side*(spec['width']/2+.012),-.28,.57),(.02,.19,.035),group,'Chrome')
        meshes = [obj for obj in descendants(group) if obj.type=='MESH']
        count = sum(triangles(obj) for obj in meshes)
        limit = [12000,4000,1200][level]
        if count>limit:
            for obj in meshes:
                if triangles(obj)<24: continue
                modifier = obj.modifiers.new('LOD budget','DECIMATE')
                modifier.ratio = limit/count*.91
                apply_modifier(obj,modifier)
        count = sum(triangles(obj) for obj in meshes)
        assert count<=limit,(identifier,level,count,limit)
        for obj in meshes: assign_uv(obj)
        for wheel_root in [obj for obj in group.children if '_Wheel_' in obj.name]:
            join_meshes([obj for obj in wheel_root.children if obj.type=='MESH'],wheel_root.name+'_Spin')
        join_meshes([obj for obj in group.children if obj.type=='MESH'],name+'_Visual')
        report['lods'].append({'level':level,'triangles':count,'ceiling':limit,'distance_m':[0,35,90][level],'mesh_parts':5})
        groups.append(group)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in descendants(root): obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    output = OUT/(identifier+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,
                              export_yup=True,export_apply=False,export_extras=True,
                              export_materials='EXPORT',export_image_format='AUTO',
                              export_vertex_color='NAME',export_vertex_color_name='PacificRoles',export_all_vertex_colors=False)
    report['path'] = output.relative_to(ROOT).as_posix()
    report['sha256'] = hashlib.sha256(output.read_bytes()).hexdigest()
    root.location.x = index*6
    for group in groups[1:]:
        for obj in descendants(group):
            obj.hide_set(True)
            obj.hide_render = True
    return report


def main():
    assert bpy.app.version[:2]==(5,1), 'Use pinned Blender 5.1.x for regeneration'
    OUT.mkdir(parents=True,exist_ok=True)
    TEXTURES.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    create_atlas()
    reports = [build_car(identifier,spec,index) for index,(identifier,spec) in enumerate(SPECS.items())]
    bpy.ops.file.pack_all()
    ATLAS.filepath_raw = "//../exported/textures/cars_atlas.png"
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/source/pacific_cars.blend'),compress=True)
    value = {'schema_version':1,'creator':'Pacific Rush procedural asset generator','license':'MIT',
             'source':'assets/source/generate_cars.py','editable_source':'assets/source/pacific_cars.blend',
             'source_url':None,'attribution':'Retain the project MIT notice','blender':bpy.app.version_string,
             'atlas':{'path':'assets/exported/textures/cars_atlas.png','width':1024,'height':1024,
                      'sha256':hashlib.sha256((TEXTURES/'cars_atlas.png').read_bytes()).hexdigest()},'cars':reports}
    (OUT/'inventory.json').write_text(json.dumps(value,indent=2)+'\n')
    print('PACIFIC_ORIGINAL_CARS_EXPORTED '+json.dumps([{r['id']:[x['triangles'] for x in r['lods']]} for r in reports]))


if __name__=='__main__': main()
