"""Original Pacific Rush scenery. Run with Blender 5.1.2 and --python-exit-code 1.

X is right, Y is depth/forward, Z is up. All geometry, palette atlases and
silhouette cards are authored here; no downloaded models or texture sources.
"""
from array import array
import hashlib
import json
import math
import struct
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/exported/scenery'
TEXTURES = ROOT/'assets/exported/textures'
COLORS = {'cream':'F3E4C4','terracotta':'B96344','dark':'172C40','wood':'865435',
          'leaf':'5E9654','glass':'3C7089','orange':'ED9B3B','sandstone':'D58C53',
          'stone':'A9B7A8','sea':'31BFC1','windows':'E8D8B7','lit_windows':'436E8A',
          'yellow':'F3CD48','coral':'F16B50','white':'F8F4E8','trim':'8CA2AA'}
PALETTE = list(COLORS)
MATERIALS = {}
IMAGES = {}
PARTS = []
CATEGORY = 'landmark'
CURRENT = ''
MODEL_LEVEL = 0


def rgb(value): return tuple(int(value[i:i+2],16)/255 for i in (0,2,4))
def linear(value): return value/12.92 if value<=.04045 else ((value+.055)/1.055)**2.4
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def atlas(name,size):
    image = bpy.data.images.new(name,width=size,height=size,alpha=True)
    image.colorspace_settings.name = 'sRGB'
    pixels = array('f')
    for y in range(size):
        for x in range(size):
            role = PALETTE[(y*4//size)*4+x*4//size]
            color = COLORS[role]
            u,v = x%(size//4)/(size//4),y%(size//4)/(size//4)
            if role in ['windows','lit_windows']:
                if .13 < (u*4)%1 < .79 and .18 < (v*3)%1 < .77:
                    color = '32556A' if role=='windows' else 'F3CD82'
            pixels.extend((*[linear(c) for c in rgb(color)],1))
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(TEXTURES/(name+'.png'))
    image.file_format = 'PNG'
    image.save()
    IMAGES[name] = image


def foliage_atlas():
    image = bpy.data.images.new('foliage_atlas',width=512,height=512,alpha=True)
    image.colorspace_settings.name = 'sRGB'
    pixels = array('f')
    for y in range(512):
        for x in range(512):
            species = (y//256)*4+x//128
            u,v = (x%128)/127*2-1,(y%256)/255
            wood = False
            leaf = False
            fruit = False
            if species==0:
                wood = abs(u+.07*math.sin(v*2))<.045 and v<.79
                leaf = abs(v-(.83-.18*abs(u)))<.055 and abs(u)<.96
                leaf |= abs(u)<.36 and .75<v<.99 and abs(u)<(1-v)*1.9+.03
            elif species==1:
                wood = abs(u)<.065 and v<.6
                leaf = (u/.92)**2+((v-.64)/.33)**2<1
                fruit = leaf and (int((u+1)*19)%9==2 and int(v*45)%13<3)
            elif species==2:
                wood = abs(u)<.045 and v<.9
                leaf = .16<v<.99 and abs(u)<(1-v)*.96*(.87+.13*math.cos(v*45))
            elif species==3:
                leaf = (u/.94)**2+((v-.35)/.32)**2<1
            elif species==4:
                leaf = any(abs(u-(stem*.18)*(1-v))<.025 and .02<v<.55+abs(stem)*.045 for stem in range(-4,5))
            else:
                leaf = True
            color = '865435' if wood else 'ED9B3B' if fruit else '5E9654'
            if species==5: color = '865435'
            elif species==6: color = '5E9654' if u<0 else '2F6650'
            elif species==7: color = 'ED9B3B'
            pixels.extend((*[linear(c) for c in rgb(color)],1 if wood or leaf else 0))
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(TEXTURES/'foliage_atlas.png')
    image.file_format = 'PNG'
    image.save()
    IMAGES['foliage_atlas'] = image


def prepare_materials():
    for name in ['scenery_atlas','props_atlas','foliage_atlas']:
        mat = bpy.data.materials.new('Pacific_'+name)
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Roughness'].default_value = .9
        texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
        texture.image = IMAGES[name]
        mat.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color'])
        if name=='foliage_atlas':
            mat.node_tree.links.new(texture.outputs['Alpha'],shader.inputs['Alpha'])
        MATERIALS[name] = mat


def mesh(name,vertices,faces,role='cream'):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices,[],faces)
    data.update()
    bm = bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(data); bm.free()
    obj = bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    obj['role'] = role
    PARTS.append(obj)
    return obj


def apply_transform(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)


def box(at,size,role='cream',rotation=None):
    if MODEL_LEVEL>0 and CATEGORY in ['landmark','building','landscape'] and min(size)<.45 and sum(value>=1 for value in size)<2: return None
    bpy.ops.mesh.primitive_cube_add(size=1,location=at)
    obj = bpy.context.object
    obj.name = CURRENT+'_'+role
    obj.dimensions = size
    if rotation: obj.rotation_euler = rotation
    apply_transform(obj)
    obj['role'] = role; PARTS.append(obj)
    return obj


def cylinder(at,radius,height,role='cream',segments=12,top=None,rotation=None):
    if MODEL_LEVEL>0 and CATEGORY in ['landmark','building','landscape']: segments=max(4,segments//(2 if MODEL_LEVEL==1 else 3))
    bpy.ops.mesh.primitive_cone_add(vertices=segments,radius1=radius,radius2=radius if top is None else top,depth=height,location=at)
    obj = bpy.context.object
    obj.name = CURRENT+'_'+role
    if rotation:
        obj.rotation_euler = rotation
        apply_transform(obj)
    obj['role'] = role; PARTS.append(obj)
    return obj


def bar(a,b,radius,role='cream',segments=8):
    if MODEL_LEVEL>0 and radius<.24: return None
    a,b = Vector(a),Vector(b)
    obj = cylinder((a+b)/2,radius,(b-a).length,role,segments)
    obj.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    apply_transform(obj)
    return obj


def roof(width,depth,height,base,role='terracotta'):
    return mesh(CURRENT+'_Roof',[(-width/2,-depth/2,base),(width/2,-depth/2,base),
        (-width/2,depth/2,base),(width/2,depth/2,base),(0,-depth/2,base+height),(0,depth/2,base+height)],
        [(0,4,1),(2,3,5),(0,2,5,4),(1,4,5,3),(0,1,3,2)],role)


def sign(text,at=(0,-3,4),size=1.6,role='dark'):
    if MODEL_LEVEL>0: return
    curve = bpy.data.curves.new(CURRENT+'_Text','FONT')
    curve.body = text; curve.align_x = 'CENTER'; curve.size = size
    curve.extrude = .012; curve.resolution_u = 2
    curve.font = bpy.data.fonts.load(str(ROOT/'assets/fonts/BarlowCondensed-Bold.ttf'),check_existing=True)
    obj = bpy.data.objects.new(CURRENT+'_Text',curve)
    bpy.context.collection.objects.link(obj)
    obj.location = at; obj.rotation_euler = (math.pi/2,0,0)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.ops.object.convert(target='MESH'); apply_transform(obj)
    obj['role'] = role; PARTS.append(obj)


def hut(width=10,depth=7,height=4,role='cream',name=''):
    box((0,0,height/2),(width,depth,height),role)
    roof(width+1,depth+1,1.8,height)
    box((0,-depth/2-.06,height*.55),(width*.8,.1,height*.45),'windows')
    if name: sign(name,(0,-depth/2-.15,height+.3),min(2,width/max(3,len(name))*1.4))


def ring(center,radius,minor,role='cream',segments=48):
    if MODEL_LEVEL>0: segments=max(12,segments//(2 if MODEL_LEVEL==1 else 3))
    cross=6 if MODEL_LEVEL==0 else 4 if MODEL_LEVEL==1 else 3
    vertices,faces = [],[]
    for i in range(segments):
        a=i*math.tau/segments
        for j in range(cross):
            b=j*math.tau/cross
            vertices.append((center[0]+(radius+minor*math.cos(b))*math.cos(a),center[1]+minor*math.sin(b),center[2]+(radius+minor*math.cos(b))*math.sin(a)))
    for i in range(segments):
        for j in range(cross): faces.append((i*cross+j,i*cross+(j+1)%cross,((i+1)%segments)*cross+(j+1)%cross,((i+1)%segments)*cross+j))
    return mesh(CURRENT+'_Ring',vertices,faces,role)


def model(identifier):
    if identifier=='surf_shop':
        hut(13,8,4,'sea','SURF')
        for i in range(5):
            obj=cylinder((-4+i*2,-4.8,2),.38,3.8,['coral','yellow','sea'][i%3],10)
            obj.rotation_euler.y = .1*(i-2)
    elif identifier=='lighthouse':
        cylinder((0,0,11),4.5,22,'cream',20,top=2.7)
        for z in [7,15]: cylinder((0,0,z),4.1 if z==7 else 3.4,2.0,'coral',20)
        cylinder((0,0,23),4,1,'dark',20)
        cylinder((0,0,25),2.6,3,'glass',16)
        cylinder((0,0,27.4),3.5,1.8,'terracotta',16,top=0)
        for a in range(0,360,45): bar((math.cos(math.radians(a))*3.7,math.sin(math.radians(a))*3.7,23),(math.cos(math.radians(a))*3.7,math.sin(math.radians(a))*3.7,25),.08,'white')
    elif identifier=='pier':
        box((67.5,0,-.7),(105,11,1.4),'wood')
        for x in range(18,121,10):
            for side in [-1,1]:
                cylinder((x,side*4,-5),.42,9,'wood',8)
                box((x,side*5,1),( .2,.2,2),'cream')
        for side in [-1,1]: box((67.5,side*5,1.8),(105,.2,.2),'cream')
        for x in [109,118]: box((x,0,1.8),(1,3,2.3),'sea')
    elif identifier=='beach_hotel':
        box((0,0,11),(28,15,22),'windows')
        for z in range(3,23,4): box((0,-8,z),(30,1.3,.3),'cream')
        box((0,0,22.5),(31,18,1),'coral'); sign('BAY HOTEL',(0,-8.1,23.2),2.7)
        for x in [-18,18]: cylinder((x,0,3),1,6,'sea',10)
    elif identifier=='sun_sign':
        cylinder((0,0,4),.35,8,'cream',8)
        cylinder((0,0,10),3.8,.45,'yellow',24,rotation=(math.pi/2,0,0))
        for i in range(12):
            a=i*math.tau/12
            bar((math.cos(a)*4.3,0,10+math.sin(a)*4.3),(math.cos(a)*5.3,0,10+math.sin(a)*5.3),.24,'yellow')
        sign('SUN',(0,-.27,9),2.3)
    elif identifier=='fruit_stand':
        hut(11,7,3,'cream','FRESH CITRUS')
        box((0,-4.4,1),(10,1.4,1.8),'wood')
        for i in range(12): cylinder((-4.5+i*.8,-4.4,2.1),.32,.45,'orange',8)
        for x in [-5,5]: cylinder((x,-4.2,2),.12,4,'white',8)
    elif identifier=='water_tower':
        for x in [-3.5,3.5]:
            for y in [-3.5,3.5]: bar((x,y,0),(x*.65,y*.65,17),.35,'white')
        cylinder((0,0,18),4.8,7,'white',20)
        cylinder((0,0,22),5.2,1.4,'cream',20,top=0)
        for z in [4,9,14]:
            for y in [-3.4,3.4]: bar((-3.4,y,z),(3.4,y,z+4),.13,'trim')
    elif identifier=='packing_shed':
        hut(28,16,6,'windows','CITRUS CO-OP')
        for x in [-10,-3,4]: box((x,-8.2,2),(4,.25,4),'wood')
        for i in range(8): box((-10+i*3,-10.5,.7),(2,2,1.4),'orange')
    elif identifier=='orange_arch':
        for x in [-15,15]:
            cylinder((x,0,4),.6,8,'cream',12)
            cylinder((x,0,10),2.0,4,'orange',16,top=1.4)
        ring((0,0,8),15,.75,'orange',48)
        # Remove the lower semicircle; the opening is unobstructed below eight meters.
        obj=PARTS[-1]
        bm=bmesh.new(); bm.from_mesh(obj.data)
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<8-.001],context='VERTS')
        bm.to_mesh(obj.data); bm.free()
        box((0,0,12.8),(20,1,2),'leaf'); sign('CITRUS PASS',(0,-.6,12.2),2.2,'white')
    elif identifier=='windmill':
        cylinder((0,0,7),3.2,14,'cream',12,top=1.8)
        cylinder((0,0,15),3,3,'terracotta',12,top=0)
        for i in range(4):
            a=i*math.pi/2+.4
            bar((0,-3,12),(math.cos(a)*8,-3,12+math.sin(a)*8),.2,'wood')
            obj=box((math.cos(a)*5,-3,12+math.sin(a)*5),(6,.22,1.2),'cream')
            obj.rotation_euler.y=-a
    elif identifier=='arcade':
        hut(24,12,7,'lit_windows','MARINA PLAY')
        for x in [-12,12]: box((x,-6.3,4),(.25,.25,8),'sea')
        for z in [2,6.8]: box((0,-6.3,z),(24,.25,.25),'coral')
        for x in [-8,-4,0,4,8]: box((x,-6.3,1.7),(2,.4,3.4),'glass')
    elif identifier=='marina_wheel':
        ring((0,0,25),22.5,.45,'cream',64)
        ring((0,.8,25),22.5,.32,'sea',64)
        for side in [-1,1]: bar((side*12,2,0),(0,0,25),.8,'coral')
        for i in range(16):
            a=i*math.tau/16; x,z=math.cos(a)*22.5,25+math.sin(a)*22.5
            bar((0,0,25),(x,0,z),.1,'cream')
            box((x,0,z-1.4),(2.4,2.3,2.4),'coral' if i%2 else 'sea')
    elif identifier in ['underpass','tunnel_portal']:
        clearance = 7 if identifier=='underpass' else 8
        for x in [-15,15]: box((x,0,clearance/2),(2,5,clearance),'stone' if clearance==7 else 'sandstone')
        box((0,0,clearance+.8),(32,5,1.6),'stone' if clearance==7 else 'sandstone')
        for x in range(-13,14,4): box((x,-2.55,clearance+.8),(2,.12,.3),'yellow')
        if identifier=='tunnel_portal': sign('SUNSTONE',(0,-2.6,clearance+1.9),2.3,'cream')
    elif identifier=='sailboats':
        for i in range(3):
            x=i*12-12
            cylinder((x,0,.8),3,1.6,'cream',12,top=2)
            bar((x,0,1),(x,0,16-i*2),.12,'wood')
            mesh('Sail',[(x,.1,2),(x,.1,15-i*2),(x+6,.1,3)],[(0,1,2)],'white')
            box((x,0,.5),(3,10,1),'sea' if i%2 else 'coral')
    elif identifier=='seafood_diner':
        hut(17,10,4,'sea','DOCKSIDE DINER')
        for x in [-7,0,7]:
            cylinder((x,-7.5,1.4),1.7,.25,'cream',12)
            cylinder((x,-7.5,2.8),2.3,.7,'coral',12,top=0)
    elif identifier=='ranger_kiosk':
        hut(8,6,3.4,'wood','RANGER')
        box((7,0,2),(3,.5,4),'leaf'); box((7,-.3,2.6),(2.3,.08,1.5),'cream')
    elif identifier=='giant_tree':
        cylinder((0,0,24),3.5,48,'wood',18,top=1.4)
        for z,r in [(29,13),(38,10),(46,7)]: cylinder((0,0,z),r,18,'leaf',14,top=0)
        for a in range(0,360,45): bar((0,0,7),(math.cos(math.radians(a))*5,math.sin(math.radians(a))*5,0),.7,'wood')
    elif identifier in ['timber_bridge','viaduct']:
        length=54 if identifier=='timber_bridge' else 126
        role='wood' if identifier=='timber_bridge' else 'stone'
        box((0,0,-.8),(22,length,1.1),role)
        for y in range(-int(length)//2+4,int(length)//2,12 if MODEL_LEVEL==0 else 26 if MODEL_LEVEL==1 else 42):
            for x in [-8,8]: box((x,y,-8),(1.8,2,15),role)
            box((0,y,-2),(22,1.5,2),role)
        if identifier=='timber_bridge':
            for x in [-12,12]:
                box((x,0,1.4),(.5,length,.3),'wood')
                for y in range(-24,25,6): bar((x,y,0),(x,y,2),.13,'wood')
    elif identifier=='visitor_center':
        hut(26,16,5,'wood','REDWOOD CENTER')
        box((0,-8.1,2.5),(20,.2,3),'windows')
        cylinder((18,0,2.5),2.3,5,'wood',12,rotation=(0,math.pi/2,0))
    elif identifier=='tree_display':
        box((0,0,.4),(11,5,.8),'stone')
        cylinder((0,0,4),3.5,1.2,'wood',32,rotation=(math.pi/2,0,0))
        for r in [1,1.7,2.4,3.1]: ring((0,-.62,4),r,.035,'cream',48)
        sign('YEARS IN THE RINGS',(0,-1,8.2),1.1)
    elif identifier=='dinosaur':
        if MODEL_LEVEL==0: cylinder((0,0,1),5,2,'sandstone',12)
        else: box((0,0,.7),(9,5,1.4),'sandstone')
        box((0,0,5),(8,3,3),'leaf')
        for x in [-2.5,2.5]:
            for y in [-1,1]: bar((x,y,4),(x,y*1.5,1.5),.65,'leaf')
        bar((3,0,5),(7,0,11),1.0,'leaf'); box((7.5,0,11.5),(3,1.8,1.8),'leaf')
        bar((-3,0,5),(-10,0,3),.7,'leaf'); box((8.4,-.94,12),(.25,.08,.25),'dark')
    elif identifier=='twin_mesas':
        for x,r,h in [(-32,28,53),(34,22,67)]:
            cylinder((x,0,h/2),r*1.4,h,'sandstone',9,top=r)
            for z in [h*.22,h*.55,h*.83]: cylinder((x,0,z),r*(1.4-.4*z/h)+.4,1.5,'terracotta',9)
            cylinder((x,0,h),r,2,'cream',9,top=r*.94)
    elif identifier=='rail_trestle':
        box((0,0,15),(95,4,1),'wood')
        for x in range(-42,43,12):
            for y in [-1.5,1.5]:
                bar((x-4,y,0),(x,y,15),.35,'wood'); bar((x+4,y,0),(x,y,15),.35,'wood')
        for y in [-1,1]: box((0,y,15.8),(95,.18,.22),'trim')
    elif identifier=='motel_sign':
        for x in [-2.8,2.8]: cylinder((x,0,5),.25,10,'cream',8)
        box((0,0,11),(9,1,6),'sea'); sign('MOTEL',(0,-.6,10),2.2,'yellow')
        box((0,0,7),(9,1,1),'coral'); sign('SUNSTONE',(0,-.65,6.7),1.3,'white')
    elif identifier=='observatory':
        cylinder((0,0,4),10,8,'cream',24)
        cylinder((0,0,9.5),10,3,'glass',24,top=8)
        cylinder((0,0,12.4),8,3,'cream',24,top=3)
        bar((0,-1,11),(0,-10,16),1.0,'dark',12)
        box((0,-10,16),(2.5,2,2.5),'trim')
    elif identifier=='overlook':
        box((0,0,-.5),(28,20,1),'stone')
        for x in [-14,14]:
            box((x,0,1),(.3,20,.3),'cream')
            for y in range(-9,10,3): bar((x,y,0),(x,y,1.2),.1,'cream')
        for x in [-8,0,8]:
            cylinder((x,2,1),.18,2,'trim',8)
            cylinder((x,1.7,2),.35,1.4,'sea',10,rotation=(math.pi/2,0,0))
    elif identifier=='mountain_lodge':
        hut(30,19,8,'windows','SUMMIT LODGE')
        for x in [-12,12]: box((x,-11,4),(.8,.8,8),'wood')
        for x in [-10,-5,0,5,10]: box((x,-10,4),(3,.3,5),'glass')
    elif identifier=='balloons':
        for i in range(5):
            x=(i-2)*14; z=22+(i%3)*9
            cylinder((x,0,z),4.4,8,['coral','yellow','sea'][i%3],16,top=2.7)
            cylinder((x,0,z-5),1.8,2,'cream',12,top=3.5)
            box((x,0,z-8),(2,2,1.5),'wood')
            for a in [-1,1]: bar((x+a,0,z-7),(x+a*2,0,z-5),.06,'dark')
    elif identifier=='coastal_home':
        hut(14,9,4.5,'windows')
        if MODEL_LEVEL==0:
            box((0,-5.3,3.7),(15,2,.3),'sea')
            for x in [-6,6]: cylinder((x,-5.3,1.8),.15,3.6,'cream',8)
        box((0,0,-1.2),(15,10,2.4),'stone')
    elif identifier=='marina_shops':
        for x,h,role in [(-6,7,'sea'),(6,9,'coral')]:
            box((x,0,h/2),(11,10,h),'lit_windows')
            if MODEL_LEVEL==0:
                box((x,0,h+.2),(12,11,.4),role)
                box((x,-5.6,3.5),(11,1.5,.5),role)
        box((0,0,-1.2),(24,11,2.4),'stone')
    elif identifier=='marina_hotel':
        box((0,0,9),(18,12,18),'lit_windows')
        box((0,1,21),(12,10,6),'lit_windows')
        for z in [3,9,15,24]: box((0,-6.2,z),(20,.4,.35),'sea')
        for x in [-9,9]: box((x,-6.2,9),(.3,.4,18),'coral')
        box((0,0,-1.2),(20,14,2.4),'stone')
    elif identifier=='sandstone_rock':
        cylinder((0,0,11),18,22,'sandstone',7,top=10)
        cylinder((0,0,13),14.5,2,'terracotta',7,top=14)
        cylinder((3,0,22),10,2,'cream',7,top=8)
    elif identifier=='summit_peak':
        cylinder((0,0,27.5),48,55,'stone',9,top=0)
        cylinder((7,5,14),30,28,'sandstone',7,top=0)
    else:
        raise ValueError(identifier)


def tree(identifier):
    if identifier=='palm':
        cylinder((0,0,4.5),.42,9,'wood',8,top=.18)
        for i in range(8):
            a=i*math.tau/8
            vertices=[]
            for j in range(5):
                t=j/4; r=t*5
                for side in [-1,1]:
                    vertices.append((math.cos(a)*r-math.sin(a)*side*.65*math.sin(t*math.pi),math.sin(a)*r+math.cos(a)*side*.65*math.sin(t*math.pi),9+.7*math.sin(t*math.pi)-2*t*t))
            mesh('PalmFrond',vertices,[(j*2,j*2+1,j*2+3,j*2+2) for j in range(4)],'leaf')
    elif identifier=='orchard':
        cylinder((0,0,1.8),.22,3.6,'wood',8,top=.12)
        for x,y,z,r in [(0,0,4.2,2.4),(-1.4,0,3.6,1.5),(1.4,0,3.8,1.6)]: cylinder((x,y,z),r,3.4,'leaf',9,top=r*.4)
        for i in range(8):
            a=i*math.tau/8
            cylinder((math.cos(a)*2.0,math.sin(a)*2.0,3.4),.18,.35,'orange',6)
    elif identifier=='redwood':
        cylinder((0,0,12.5),1.0,25,'wood',10,top=.32)
        for z,r,h in [(14,5.7,11),(21,4.1,11),(27,2.9,10)]: cylinder((0,0,z),r,h,'leaf',10,top=0)
    elif identifier=='shrub':
        for x,y in [(-.7,0),(.7,.2),(0,-.5)]: cylinder((x,y,.65),1.1,1.3,'leaf',8,top=.5)
    elif identifier=='grass':
        for i in range(7):
            a=i*math.tau/7
            mesh('Grass',[(0,0,0),(math.cos(a)*.75,math.sin(a)*.75,1.1),(.16*math.sin(a),-.16*math.cos(a),0)],[(0,1,2)],'leaf')


def prop(identifier):
    if identifier=='chevron':
        for x in [-1.5,1.5]: cylinder((x,0,1.4),.1,2.8,'trim',8)
        box((0,0,2.5),(4.3,.18,2.1),'yellow')
        for x in [-1.05,1.05]:
            mesh('Chevron',[(x-.65,-.101,3.3),(x+.25,-.101,2.5),(x-.65,-.101,1.7),(x-.2,-.101,1.7),(x+.7,-.101,2.5),(x-.2,-.101,3.3)],[(0,1,5),(5,1,4),(1,2,3),(1,3,4)],'dark')
    elif identifier=='warning':
        cylinder((0,0,1.5),.1,3,'trim',8)
        mesh('Warning',[(-1.3,0,2),(1.3,0,2),(0,0,4.2)],[(0,1,2)],'yellow')
        box((0,-.03,2.9),(.17,.05,.7),'dark')
    elif identifier=='streetlight':
        cylinder((0,0,5),.15,10,'trim',10)
        bar((0,0,10),(2,0,10),.1,'trim')
        box((2,0,9.9),(1.4,.6,.2),'white')
    elif identifier=='bench':
        box((0,0,.55),(2.2,.7,.15),'wood'); box((0,.35,1),(2.2,.15,.8),'wood')
        for x in [-.8,.8]: box((x,0,.25),(.12,.6,.5),'trim')
    elif identifier=='umbrella':
        cylinder((0,0,1.6),.08,3.2,'wood',8)
        cylinder((0,0,3),2.6,.9,'coral',12,top=0)
    elif identifier=='cone':
        box((0,0,.07),(.6,.6,.14),'dark'); cylinder((0,0,.5),.25,.9,'orange',8,top=.035)
    elif identifier=='crate': box((0,0,.6),(1.2,1.2,1.2),'wood')
    else: raise ValueError(identifier)


def assign_uv(obj,atlas_name):
    role=obj.get('role','cream')
    layer=obj.data.uv_layers.active or obj.data.uv_layers.new(name='PacificScenery')
    for other in list(obj.data.uv_layers):
        if other!=layer: obj.data.uv_layers.remove(other)
    layer.name='PacificScenery'
    if atlas_name=='foliage_atlas':
        tile=5 if role=='wood' else 7 if role=='orange' else 6
        point=((tile%4+.25)/4,(tile//4+.5)/2)
        for loop in layer.data: loop.uv=point
    else:
        tile=PALETTE.index(role); tx,ty=tile%4,tile//4
        bounds=[(min(v.co[i] for v in obj.data.vertices),max(v.co[i] for v in obj.data.vertices)) for i in range(3)]
        for poly in obj.data.polygons:
            axes=[i for i in range(3) if i!=max(range(3),key=lambda i:abs(poly.normal[i]))]
            for loop in poly.loop_indices:
                co=obj.data.vertices[obj.data.loops[loop].vertex_index].co
                u,v=[(co[i]-bounds[i][0])/max(.001,bounds[i][1]-bounds[i][0]) for i in axes]
                layer.data[loop].uv=((tx+.04+.92*u)/4,(ty+.04+.92*v)/4)
    obj.data.materials.clear(); obj.data.materials.append(MATERIALS[atlas_name])


def triangles(obj):
    obj.data.calc_loop_triangles(); return len(obj.data.loop_triangles)


def join(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    obj=bpy.context.object; obj.name=name
    return obj


def silhouette(identifier,height,width):
    tile=['palm','orchard','redwood','shrub','grass'].index(identifier)
    vertices=[(-width/2,0,0),(width/2,0,0),(width/2,0,height),(-width/2,0,height),
              (0,-width/2,0),(0,width/2,0),(0,width/2,height),(0,-width/2,height)]
    obj=mesh(identifier+'_Impostor',vertices,[(0,1,2,3),(4,5,6,7)],'leaf')
    uv=obj.data.uv_layers.new(name='PacificScenery')
    for poly in obj.data.polygons:
        for n,loop in enumerate(poly.loop_indices):
            uv.data[loop].uv=((tile%4+[0,1,1,0][n])/4,(tile//4+[0,0,1,1][n])/2)
    obj.data.materials.append(MATERIALS['foliage_atlas'])
    return obj


def export(identifier,category,index):
    global PARTS,CURRENT,CATEGORY,MODEL_LEVEL
    PARTS=[]; CURRENT=identifier; CATEGORY=category
    MODEL_LEVEL=0
    bpy.ops.object.select_all(action='DESELECT')
    root=bpy.data.objects.new(identifier,None); bpy.context.collection.objects.link(root)
    atlas_name='foliage_atlas' if category=='foliage' else 'props_atlas' if category=='prop' else 'scenery_atlas'
    (tree if category=='foliage' else prop if category=='prop' else model)(identifier)
    for obj in PARTS: assign_uv(obj,atlas_name)
    body=join(PARTS,identifier+'_LOD0_Mesh'); body.parent=root
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bounds=[Vector(v) for v in body.bound_box]
    size=[max(v[i] for v in bounds)-min(v[i] for v in bounds) for i in range(3)]
    lods=[body]; counts=[triangles(body)]
    assert counts[0] <= {'foliage':1200,'prop':500,'building':3000,'landscape':500,'landmark':20000}[category],(identifier,counts[0])
    for level in [1,2]:
        if category in ['landmark','building','landscape']:
            PARTS=[]; MODEL_LEVEL=level
            model(identifier)
            for piece in PARTS: assign_uv(piece,atlas_name)
            obj=join(PARTS,identifier+'_LOD'+str(level)+'_Mesh')
        elif category=='foliage' and level==2:
            obj=silhouette(identifier,size[2],max(size[0],size[1]))
        elif category=='foliage' and level==1:
            if identifier=='orchard':
                PARTS=[]
                cylinder((0,0,1.8),.22,3.6,'wood',6,top=.12)
                for x,y,z,r in [(0,0,4.2,2.4),(-1.4,0,3.6,1.5),(1.4,0,3.8,1.6)]: cylinder((x,y,z),r,3.4,'leaf',6,top=r*.4)
                for piece in PARTS: assign_uv(piece,atlas_name)
                obj=join(PARTS,identifier+'_LOD1_Mesh')
            else:
                obj=body.copy(); obj.data=body.data.copy(); bpy.context.collection.objects.link(obj)
            assert triangles(obj)<=200
        else:
            obj=body.copy(); obj.data=body.data.copy(); bpy.context.collection.objects.link(obj)
            modifier=obj.modifiers.new('Explicit silhouette LOD','DECIMATE')
            target=min(counts[0]*(.48 if level==1 else .13),180 if category=='foliage' else 100000)
            modifier.ratio=max(.01,target/counts[0])
            bpy.context.view_layer.objects.active=obj
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.name=identifier+'_LOD'+str(level)+'_Mesh'; obj.parent=root
        bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        lods.append(obj); counts.append(triangles(obj))
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for obj in lods: obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    path=OUT/(identifier+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_image_format='AUTO',export_extras=True)
    payload=path.read_bytes()
    gltf=json.loads(payload[20:20+struct.unpack_from('<I',payload,12)[0]])
    exported={}
    for node in gltf['nodes']:
        if 'mesh' not in node: continue
        level=next(level for level in range(3) if f'LOD{level}' in node['name'])
        exported[level]=sum(gltf['accessors'][primitive['indices']]['count']//3 for primitive in gltf['meshes'][node['mesh']]['primitives'])
    root.location=(index%8*150,index//8*160,0)
    for obj in lods[1:]: obj.hide_set(True); obj.hide_render=True
    return {'id':identifier,'category':category,'path':path.relative_to(ROOT).as_posix(),'sha256':digest(path),
            'atlas':'assets/exported/textures/'+atlas_name+'.png','triangles':[exported[level] for level in range(3)],'authoring_triangles':counts,
            'lod_distances':[0,70,180] if category=='foliage' else [0,80,100] if category=='prop' else [0,80,180] if category=='building' else [0,100,250],
            'size_m':[round(v,4) for v in size]}


def main():
    OUT.mkdir(parents=True,exist_ok=True); TEXTURES.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    atlas('scenery_atlas',1024); atlas('props_atlas',512); foliage_atlas(); prepare_materials()
    landmarks=['surf_shop','lighthouse','pier','beach_hotel','sun_sign','fruit_stand','water_tower','packing_shed','orange_arch','windmill','arcade','marina_wheel','underpass','sailboats','seafood_diner','ranger_kiosk','giant_tree','timber_bridge','visitor_center','tree_display','dinosaur','twin_mesas','rail_trestle','tunnel_portal','motel_sign','observatory','overlook','mountain_lodge','viaduct','balloons']
    assets=[]
    for identifier in landmarks: assets.append(export(identifier,'landmark',len(assets)))
    for identifier in ['palm','orchard','redwood','shrub','grass']: assets.append(export(identifier,'foliage',len(assets)))
    for identifier in ['chevron','warning','streetlight','bench','umbrella','cone','crate']: assets.append(export(identifier,'prop',len(assets)))
    for identifier in ['coastal_home','marina_shops','marina_hotel']: assets.append(export(identifier,'building',len(assets)))
    for identifier in ['sandstone_rock','summit_peak']: assets.append(export(identifier,'landscape',len(assets)))
    for name,image in IMAGES.items():
        image.pack(); image.filepath_raw='//../exported/textures/'+name+'.png'
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/source/pacific_scenery.blend'))
    value={'schema_version':1,'creator':'Pacific Rush contributors','license':'MIT','source':'assets/source/generate_scenery.py','editable_source':'assets/source/pacific_scenery.blend','source_url':None,'blender':bpy.app.version_string,'assets':assets}
    (OUT/'library.json').write_text(json.dumps(value,indent=2)+'\n')
    print('PACIFIC_ORIGINAL_SCENERY_EXPORTED',len(assets),sum(a['triangles'][0] for a in assets))


if __name__=='__main__': main()
