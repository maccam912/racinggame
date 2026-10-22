#!/usr/bin/env python3
"""Thirty individually drawn routes for the forty-course roster.

See docs/COURSE_ROSTER_40.md. This authors canonical JSON; bake_tracks.py remains
the only route baker. Existing ten routes and their asset bytes are retained.
"""
import copy
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
# ID, theme, surface, width, relief, explicit polygon. Each polygon is authored
# for its named setting; no random, rotated or scaled clones of other circuits.
ROUTES=[
 ('glacier_ridge','polar','asphalt',16,95,[(0,300),(0,-1050),(900,-1350),(1400,-700),(950,-350),(1400,250),(800,650)]),
 ('aurora_harbor','polar','asphalt',18,12,[(0,400),(0,-1100),(550,-1100),(550,-650),(1150,-650),(1150,-1100),(1700,-1100),(1700,450),(1100,450),(1100,0),(550,0),(550,450)]),
 ('alpine_meadow','polar','dirt',18,55,[(0,300),(0,-600),(500,-1000),(1050,-600),(1600,-1000),(2050,-350),(1500,100),(1650,650),(850,950),(400,500)]),
 ('frostbite_fjord','polar','asphalt',16,80,[(0,200),(0,-1300),(1700,-1300),(1700,700),(1150,700),(1150,-650),(550,-650),(550,700),(0,700)]),
 ('tundra_pipeline','polar','dirt',20,30,[(0,400),(0,-1100),(1300,-1100),(1850,-650),(1850,0),(1350,0),(1350,600),(600,600)]),
 ('rainforest_ruins','tropical','dirt',16,70,[(0,450),(0,-1000),(650,-1000),(650,-500),(1250,-500),(1250,0),(1850,0),(1850,800),(950,1100),(350,950)]),
 ('monsoon_delta','tropical','asphalt',18,25,[(0,400),(0,-1000),(500,-1250),(1050,-750),(650,-300),(1200,150),(1750,-300),(2100,300),(1550,900),(650,850)]),
 ('coral_causeway','tropical','asphalt',16,35,[(0,200),(0,-900),(650,-1450),(1200,-1000),(1700,-1100),(2100,-400),(1550,0),(1200,600),(550,700)]),
 ('mangrove_maze','tropical','dirt',14,15,[(0,400),(0,-1000),(550,-1000),(550,-450),(1100,-450),(1100,-1000),(1650,-1000),(1650,500),(1100,500),(1100,100),(550,100),(550,650)]),
 ('cloudforest_climb','tropical','dirt',16,110,[(0,350),(0,-1000),(600,-1350),(1250,-1050),(1700,-1450),(2250,-950),(2050,-250),(1400,100),(1750,650),(1000,1050),(400,800)]),
 ('sakura_ring','east_asia','asphalt',18,30,[(0,250),(0,-1050),(550,-1400),(1300,-1050),(1700,-350),(1150,50),(1450,550),(800,1000),(300,700)]),
 ('bamboo_gorge','east_asia','dirt',16,65,[(0,450),(0,-1050),(550,-1350),(1050,-850),(650,-300),(1200,200),(1750,-300),(2100,400),(1400,1050),(450,850)]),
 ('lantern_market','east_asia','asphalt',16,8,[(0,400),(0,-1200),(600,-1200),(600,-650),(1200,-650),(1200,-100),(1800,-100),(1800,500),(650,500),(650,1050),(0,1050)]),
 ('terrace_touge','east_asia','asphalt',16,100,[(0,400),(0,-1150),(700,-1550),(1450,-1150),(1900,-500),(1300,-50),(1900,500),(1450,1100),(750,1100),(350,750)]),
 ('temple_coast','east_asia','asphalt',18,45,[(0,350),(0,-1000),(550,-1450),(1350,-1150),(1850,-500),(1650,250),(1100,650),(650,200),(1100,-300),(650,-650),(350,-350),(350,400)]),
 ('saltflat_velocity','desert','asphalt',20,8,[(0,450),(0,-1900),(800,-1900),(1600,-1200),(1450,-400),(1950,200),(1350,750),(500,750)]),
 ('dune_serpent','desert','dirt',18,75,[(0,400),(0,-1100),(600,-1450),(1050,-950),(650,-450),(1200,100),(1650,-350),(2100,200),(1800,900),(950,1150),(350,850)]),
 ('oasis_citadel','desert','asphalt',20,35,[(0,450),(0,-1050),(650,-1400),(1450,-1100),(1850,-450),(1300,-150),(1300,450),(1900,450),(1450,1150),(450,1000)]),
 ('copper_mesa','desert','dirt',16,90,[(0,450),(0,-1200),(700,-1650),(1450,-1200),(1900,-600),(1400,-200),(1900,400),(1500,1050),(850,650),(350,1050)]),
 ('storm_chase','desert','asphalt',20,25,[(0,450),(0,-1400),(1600,-1400),(2050,-800),(1550,-250),(2050,350),(1500,1100),(500,1100)]),
 ('steelworks_sprint','industry','asphalt',18,20,[(0,500),(0,-1200),(1700,-1200),(1700,-650),(700,-650),(700,-100),(1300,-100),(1300,500),(1900,500),(1500,1100),(500,1100)]),
 ('container_corkscrew','industry','asphalt',16,40,[(0,450),(0,-1200),(600,-1200),(600,-650),(1200,-650),(1200,-1200),(1800,-1200),(1800,700),(1200,700),(1200,150),(600,150),(600,700)]),
 ('neon_underpass','industry','asphalt',16,18,[(0,450),(0,-1100),(700,-1500),(1550,-1100),(1550,-500),(950,-500),(950,50),(1900,550),(1350,1150),(650,750)]),
 ('windfarm_run','industry','dirt',18,85,[(0,400),(0,-1200),(800,-1550),(1600,-1050),(1950,-350),(1300,100),(1750,700),(950,1200),(350,800)]),
 ('festival_speedway','industry','asphalt',20,15,[(0,400),(0,-1100),(650,-1600),(1600,-1200),(1900,-450),(1550,100),(1000,-200),(650,250),(1100,750),(600,1250),(0,950)]),
 ('lunar_freight','space','asphalt',18,60,[(0,450),(0,-1100),(700,-1500),(1450,-1100),(1900,-500),(1350,-100),(1350,450),(2000,450),(1500,1100),(450,1000)]),
 ('orbital_gardens','space','asphalt',18,50,[(0,800),(0,-1000),(650,-1550),(1500,-1350),(2100,-650),(1900,150),(1350,750),(750,750),(750,200),(350,200),(350,800)]),
 ('crystal_chasm','space','dirt',16,95,[(0,500),(0,-1150),(550,-1500),(1050,-1050),(650,-500),(1200,50),(1750,-500),(2250,100),(1900,1000),(950,1300),(350,1000)]),
 ('mars_badlands','space','dirt',18,85,[(0,400),(0,-1200),(650,-1600),(1250,-1150),(1850,-1450),(2250,-750),(1700,-150),(2200,450),(1550,1200),(650,1000)]),
 ('reactor_rift','space','asphalt',16,70,[(0,500),(0,-1350),(1700,-1350),(2150,-650),(1600,-250),(2000,350),(1450,1000),(950,550),(450,1100)]),
]

PALETTES={
 'polar':('C9DFE8','A8CFE6','E4EFF1','F4F6FF','ice_spires','spruce_snow','polar'),
 'tropical':('4D8975','56B7D1','B6E8D7','FFF0C0','jungle_temple','kapok','tropical'),
 'east_asia':('759878','739BC9','EFD6CB','FFE1BA','pagoda','sakura','east-asia'),
 'desert':('D2A370','618BC2','EBC9A1','FFE4B5','citadel','oasis_palm','desert'),
 'industry':('727C86','50638A','BDC5D7','E9D5B5','furnace','steel_pylon','industry'),
 'space':('6D5B81','171C3A','967BB4','99E4EF','lunar_base','crystal_cluster','space'),
}
LANDMARKS={
 'glacier_ridge':['ice_spires','ice_spires','gondola','research_base','ice_spires'],
 'aurora_harbor':['cargo_ship','cargo_crane','radar_station','polar_huts','research_base'],
 'alpine_meadow':['chalet','alpine_fir','wind_turbine','barn_silos','gondola'],
 'frostbite_fjord':['ice_spires','polar_huts','gondola','ice_spires','research_base'],
 'tundra_pipeline':['pump_station','pump_station','radar_station','research_base','pump_station'],
 'rainforest_ruins':['jungle_temple','stone_face','kapok','stone_face','jungle_temple'],
 'monsoon_delta':['stilt_village','cargo_ship','mangrove','pump_station','radar_station'],
 'coral_causeway':['coral_arch','island_resort','coral_arch','island_resort','coral_arch'],
 'mangrove_maze':['mangrove','stilt_village','kapok','stilt_village','stone_face'],
 'cloudforest_climb':['tree_fern','stone_face','stilt_village','jungle_temple','stone_face'],
 'sakura_ring':['sakura','torii','pagoda','lantern_market','waterwheel_house'],
 'bamboo_gorge':['bamboo','torii','waterwheel_house','waterwheel_house','sea_shrine'],
 'lantern_market':['torii','lantern_market','pagoda','lantern_market','sea_shrine'],
 'terrace_touge':['tea_terrace','sea_shrine','torii','pagoda','waterwheel_house'],
 'temple_coast':['sea_shrine','torii','cargo_ship','sakura','torii'],
 'saltflat_velocity':['salt_spires','salt_spires','pump_station','radar_station','salt_spires'],
 'dune_serpent':['dune_spires','citadel','citadel','dune_spires','oasis_palm'],
 'oasis_citadel':['citadel','oasis_palm','citadel','waterwheel_house','citadel'],
 'copper_mesa':['dune_spires','mine_headframe','mine_headframe','gondola','dune_spires'],
 'storm_chase':['barn_silos','barn_silos','wind_turbine','radar_station','barn_silos'],
 'steelworks_sprint':['furnace','cooling_towers','cargo_crane','steel_pylon','furnace'],
 'container_corkscrew':['containers','cargo_crane','cargo_ship','radar_station','dry_dock'],
 'neon_underpass':['neon_gate','steel_pylon','lantern_market','ventilation_station','neon_gate'],
 'windfarm_run':['wind_turbine','steel_pylon','radar_station','barn_silos','steel_pylon'],
 'festival_speedway':['grandstand','festival_stage','ferris_wheel','festival_stage','grandstand'],
 'lunar_freight':['lunar_base','space_dish','rocket','mars_hoodoo','lunar_base'],
 'orbital_gardens':['greenhouse','reactor_rings','solar_array','greenhouse','reactor_rings'],
 'crystal_chasm':['crystal_cluster','reactor_rings','lunar_base','crystal_cluster','crystal_cluster'],
 'mars_badlands':['mars_hoodoo','lunar_base','greenhouse','space_dish','mars_hoodoo'],
 'reactor_rift':['reactor_rings','solar_array','reactor_rings','lunar_base','crystal_cluster'],
}
TREES={'glacier_ridge':'ice_spires','aurora_harbor':'spruce_snow','alpine_meadow':'alpine_fir',
 'frostbite_fjord':'spruce_snow','tundra_pipeline':'spruce_snow','rainforest_ruins':'kapok',
 'monsoon_delta':'mangrove','coral_causeway':'oasis_palm','mangrove_maze':'mangrove',
 'cloudforest_climb':'tree_fern','sakura_ring':'sakura','bamboo_gorge':'bamboo',
 'lantern_market':'sakura','terrace_touge':'bamboo','temple_coast':'sakura',
 'saltflat_velocity':'salt_spires','dune_serpent':'dune_spires','oasis_citadel':'oasis_palm',
 'copper_mesa':'dune_spires','storm_chase':'alpine_fir','steelworks_sprint':'steel_pylon',
 'container_corkscrew':'containers','neon_underpass':'neon_gate','windfarm_run':'alpine_fir',
 'festival_speedway':'festival_stage','lunar_freight':'lunar_base','orbital_gardens':'greenhouse',
 'crystal_chasm':'crystal_cluster','mars_badlands':'mars_hoodoo','reactor_rift':'crystal_cluster'}

# Flowing routes are sparse spline controls, not rounded polygon vertices. Long
# arcs, changing radii and linked esses deliberately occupy most of these laps.
# The collinear first/last controls preserve a flat, readable standing grid.
FLOW={
 'glacier_ridge':[(0,0),(0,-180),(0,-360),(80,-620),(290,-870),(570,-1020),(850,-960),(1020,-770),(960,-550),(740,-400),(820,-180),(1070,10),(1140,250),(980,480),(690,550),(450,410),(230,350),(45,180),(0,65)],
 'alpine_meadow':[(0,0),(0,-140),(0,-300),(100,-510),(320,-620),(540,-520),(620,-280),(820,-220),(1000,-390),(1240,-370),(1380,-130),(1260,100),(1020,160),(980,380),(780,570),(520,540),(390,340),(160,300),(0,150),(0,55)],
 'rainforest_ruins':[(0,0),(0,-160),(0,-330),(130,-550),(360,-610),(550,-470),(490,-260),(700,-110),(900,-260),(1140,-200),(1230,30),(1080,230),(820,370),(640,590),(390,640),(150,440),(20,210),(0,60)],
 'monsoon_delta':[(0,0),(0,-200),(0,-440),(140,-720),(410,-850),(690,-700),(790,-410),(610,-150),(740,100),(1040,170),(1260,20),(1500,170),(1530,470),(1260,720),(940,660),(700,450),(410,490),(130,340),(0,160),(0,60)],
 'coral_causeway':[(0,0),(0,-200),(0,-450),(170,-730),(480,-900),(780,-800),(980,-530),(1280,-490),(1540,-660),(1820,-560),(1960,-290),(1840,-40),(1540,100),(1310,310),(1120,600),(820,730),(530,600),(360,350),(140,300),(0,150),(0,55)],
 'cloudforest_climb':[(0,0),(0,-200),(0,-450),(160,-730),(460,-870),(750,-710),(790,-440),(600,-230),(760,0),(1080,0),(1320,-170),(1560,0),(1610,300),(1390,540),(1070,560),(830,790),(520,830),(260,620),(70,350),(0,140),(0,55)],
 'sakura_ring':[(0,0),(0,-140),(0,-320),(100,-540),(350,-660),(620,-570),(770,-350),(690,-140),(480,-50),(450,140),(650,230),(850,170),(1000,350),(900,570),(650,680),(390,560),(260,350),(65,230),(0,90),(0,45)],
 'bamboo_gorge':[(0,0),(0,-160),(0,-340),(120,-580),(360,-700),(580,-560),(530,-340),(740,-190),(940,-350),(1160,-230),(1190,30),(980,190),(800,410),(540,500),(320,370),(130,300),(0,150),(0,55)],
 'terrace_touge':[(0,0),(0,-170),(0,-370),(130,-650),(420,-820),(720,-740),(840,-510),(680,-280),(860,-80),(1160,-150),(1340,70),(1250,340),(960,430),(790,650),(520,730),(270,530),(70,310),(0,130),(0,50)],
 'temple_coast':[(0,0),(0,-180),(0,-380),(120,-660),(390,-810),(700,-770),(980,-570),(1110,-270),(1060,60),(850,330),(540,450),(330,340),(340,130),(580,30),(650,-180),(480,-350),(260,-270),(180,-40),(140,170),(20,180),(0,60)],
 'dune_serpent':[(0,0),(0,-170),(0,-360),(150,-610),(400,-710),(630,-570),(590,-320),(800,-150),(1040,-300),(1290,-140),(1340,140),(1130,390),(830,520),(570,430),(370,260),(140,270),(0,140),(0,55)],
 'windfarm_run':[(0,0),(0,-240),(0,-530),(180,-860),(510,-1080),(870,-990),(1130,-730),(1080,-400),(810,-180),(920,100),(1240,260),(1320,580),(1070,860),(730,900),(480,680),(300,400),(80,270),(0,120),(0,55)],
 'festival_speedway':[(0,0),(0,-180),(0,-400),(100,-650),(350,-820),(680,-840),(960,-670),(1100,-400),(1030,-140),(800,-30),(590,-100),(460,70),(560,250),(810,300),(940,500),(770,710),(460,760),(200,580),(25,300),(0,130),(0,55)],
 'orbital_gardens':[(0,0),(0,-220),(0,-470),(160,-790),(490,-980),(870,-960),(1220,-730),(1390,-390),(1350,-20),(1120,300),(950,550),(1100,800),(950,1050),(650,1100),(400,950),(200,700),(30,400),(0,180),(0,60)],
 'crystal_chasm':[(0,0),(0,-170),(0,-360),(130,-620),(390,-770),(650,-620),(600,-350),(850,-200),(1100,-390),(1380,-230),(1470,70),(1280,370),(980,500),(730,740),(420,780),(150,530),(20,260),(0,60)],
 'mars_badlands':[(0,0),(0,-220),(0,-480),(180,-800),(510,-970),(820,-800),(1030,-550),(1310,-720),(1600,-580),(1710,-280),(1520,-20),(1250,110),(1410,380),(1240,680),(920,830),(620,640),(330,620),(90,350),(0,140),(0,55)],
}

# Individual dimensions and corner cuts create genuinely different pacing even
# on the angular street/utility courses. Cuts are in final metres, not scaled.
PROFILES={
 'glacier_ridge':(1.10,160),'aurora_harbor':(.62,68),'alpine_meadow':(.72,120),
 'frostbite_fjord':(.72,105),'tundra_pipeline':(1.05,195),'rainforest_ruins':(.86,120),
 'monsoon_delta':(.90,155),'coral_causeway':(1.22,210),'mangrove_maze':(.72,[110]*11+[187]),
 'cloudforest_climb':(1.15,160),'sakura_ring':(.75,110),'bamboo_gorge':(.82,100),
 'lantern_market':(.53,62),'terrace_touge':(1.00,140),'temple_coast':(1.10,130),
 'saltflat_velocity':(1.35,[270,95,170,230,120,210,300,200]),
 'dune_serpent':(.95,150),'oasis_citadel':(.76,[115]*7+[207]+[115]*2),'copper_mesa':(.90,95),
 'storm_chase':(1.10,[250,140,210,180,100,170,220,260]),
 'steelworks_sprint':(.68,[105]*8+[230]+[105]*2),
 'container_corkscrew':(.68,140),'neon_underpass':(.64,110),'windfarm_run':(1.12,180),
 'festival_speedway':(.80,130),'lunar_freight':(.82,[95]*7+[280]+[95]*2),
 'orbital_gardens':(1.10,180),'crystal_chasm':(.90,110),'mars_badlands':(1.17,160),
 'reactor_rift':(.88,[220,100,180,140,85,130,160,100,130]),
}

PLANTINGS={
 'glacier_ridge':['ice_spires','spruce_snow','snow_pine'],
 'aurora_harbor':['spruce_snow','snow_pine','ice_spires'],
 'alpine_meadow':['alpine_fir','autumn_maple','coastal_cypress'],
 'frostbite_fjord':['spruce_snow','ice_spires','snow_pine'],
 'tundra_pipeline':['shrub','snow_pine','spruce_snow'],
 'rainforest_ruins':['kapok','tree_fern','mangrove'],
 'monsoon_delta':['mangrove','kapok','coconut_palm'],
 'coral_causeway':['oasis_palm','fan_palm','coconut_palm'],
 'mangrove_maze':['mangrove','tree_fern','kapok'],
 'cloudforest_climb':['tree_fern','kapok','coastal_cypress'],
 'sakura_ring':['sakura','bamboo','autumn_maple'],
 'bamboo_gorge':['bamboo','coastal_cypress','tree_fern'],
 'lantern_market':['sakura','bamboo','coastal_cypress'],
 'terrace_touge':['bamboo','coastal_cypress','sakura'],
 'temple_coast':['sakura','fan_palm','coastal_cypress'],
 'saltflat_velocity':['salt_spires','shrub','hoodoo_cluster'],
 'dune_serpent':['dune_spires','flowering_cactus','shrub'],
 'oasis_citadel':['oasis_palm','fan_palm','flowering_cactus'],
 'copper_mesa':['hoodoo_cluster','dune_spires','flowering_cactus'],
 'storm_chase':['shrub','autumn_maple','coastal_cypress'],
 'steelworks_sprint':['steel_pylon','containers','pump_station'],
 'container_corkscrew':['containers','steel_pylon','dry_dock'],
 'neon_underpass':['neon_gate','ventilation_station','steel_pylon'],
 'windfarm_run':['shrub','alpine_fir','coastal_cypress'],
 'festival_speedway':['fan_palm','festival_stage','grandstand'],
 'lunar_freight':['lunar_base','mars_hoodoo','space_dish'],
 'orbital_gardens':['greenhouse','crystal_cluster','solar_array'],
 'crystal_chasm':['crystal_cluster','mars_hoodoo','ice_spires'],
 'mars_badlands':['mars_hoodoo','dune_spires','lunar_base'],
 'reactor_rift':['crystal_cluster','solar_array','steel_pylon'],
}
DISTRICTS={'aurora_harbor':'harbor','lantern_market':'market','steelworks_sprint':'works',
 'container_corkscrew':'port','neon_underpass':'city','festival_speedway':'festival',
 'oasis_citadel':'citadel','lunar_freight':'base','orbital_gardens':'habitat','reactor_rift':'reactor'}


def street_controls(vertices, cuts, height):
    """Circular fillets with tangents, including compact city blocks."""
    cuts=[max(85,c) for c in cuts] if isinstance(cuts,list) else [max(85,cuts)]*len(vertices)
    points=[]
    for i,corner in enumerate(vertices):
        before,after=vertices[i-1],vertices[(i+1)%len(vertices)]
        incoming=[before[j]-corner[j] for j in range(2)]
        outgoing=[after[j]-corner[j] for j in range(2)]
        a,b=math.hypot(*incoming),math.hypot(*outgoing)
        incoming=[v/a for v in incoming];outgoing=[v/b for v in outgoing]
        cut=cuts[i]
        dot=sum(x*y for x,y in zip(incoming,outgoing))
        if dot<-.999:
            continue  # A redundant collinear polygon vertex is not a corner.
        entry=[corner[j]+incoming[j]*cut for j in range(2)]
        exit=[corner[j]+outgoing[j]*cut for j in range(2)]
        center=[corner[j]+(incoming[j]+outgoing[j])*cut/(1+dot) for j in range(2)]
        radius=math.dist(center,entry)
        lo=math.atan2(entry[1]-center[1],entry[0]-center[0])
        hi=math.atan2(exit[1]-center[1],exit[0]-center[0])
        turn=(hi-lo+math.pi)%(2*math.pi)-math.pi
        steps=max(2,math.ceil(abs(turn)/.9))
        # One tangent point on each side keeps long straight sections straight.
        run=min(60,(a-cut-cuts[i-1])*.28,(b-cut-cuts[(i+1)%len(vertices)])*.28)
        assert run>0, (i,corner,cuts)
        arc=[[center[0]+math.cos(lo+turn*k/steps)*radius,
              center[1]+math.sin(lo+turn*k/steps)*radius] for k in range(steps+1)]
        for x,z in [[entry[j]+incoming[j]*run for j in range(2)],*arc,
                    [exit[j]+outgoing[j]*run for j in range(2)]]:
            points.append([round(x,4),round(height(x,z),4),round(z,4)])
    assert len(points)<=64
    return points


def main():
    path=ROOT/'game/content/tracks.json'
    catalog=json.loads(path.read_text());catalog['tracks']=catalog['tracks'][:10]
    art_path=ROOT/'assets/source/course_specs.json'
    art=json.loads(art_path.read_text());art['courses']=art['courses'][:10]
    text_path=ROOT/'game/ui/text/en.json';text=json.loads(text_path.read_text())
    briefs={line.split('`')[1]:line.split('|')[3].strip() for line in (ROOT/'docs/COURSE_ROSTER_40.md').read_text().splitlines() if line.startswith('| ') and '` / ' in line}
    for index,(identifier,theme,surface,width,relief,polygon) in enumerate(ROUTES):
        name=identifier.replace('_',' ').title()
        scale,cuts=PROFILES[identifier]
        polygon=[(x*scale,z*scale) for x,z in FLOW.get(identifier,polygon)]
        max_x=max(x for x,z in polygon)
        # The initial x=0 straight remains level, keeping an honest legal grid.
        def height(x,z):
            return 12+min(relief,max_x*.052)*math.sin(math.pi*max(0,min(1,x/max_x)))**2
        controls=([[round(x,4),round(height(x,z),4),round(z,4)] for x,z in polygon]
                  if identifier in FLOW else street_controls(polygon,cuts,height))
        if identifier in FLOW:
            distances=[0.0]
            for a,b in zip(polygon,polygon[1:]+polygon[:1]):
                distances.append(distances[-1]+math.dist(a,b))
            waves=2 if identifier in ['cloudforest_climb','terrace_touge','mars_badlands'] else 1
            for point,distance in zip(controls,distances):
                u=max(0,min(1,(distance-350)/(distances[-1]-700)))
                point[1]=round(12+relief*math.sin(math.pi*u*waves)**2,4)
        track={'id':identifier,'name':name,'display_name_key':'track.'+identifier,
            'ordered_control_points':controls,'width':width,'shoulder':3,'surface':'sand' if theme in ['desert','space'] else 'grass',
            'difficulty':'Hard' if width==14 or relief>=80 else 'Easy' if width==20 and relief<=30 else 'Medium',
            'width_intervals':[],'bank_intervals':[],'ramp_markers':[],
            'environment_id':identifier,'baked_route_id':'res://game/content/baked/'+identifier+'.json',
            'collision_id':identifier,'thumbnail_id':identifier,'minimap_id':identifier,
            'landmark_specs':[],'surface_intervals':[],'road_surface':surface,'spline':'centripetal'}
        if identifier in ['dune_serpent','mars_badlands']:
            track['ramp_markers']=[.30] if identifier=='dune_serpent' else [.28,.64]
            track['width_intervals']=[[u-.015,u+.025,24] for u in track['ramp_markers']]
        catalog['tracks'].append(track)
        ground,sky,horizon,sun,_,_,atlas=PALETTES[theme]
        night=identifier in ['aurora_harbor','lantern_market','neon_underpass','festival_speedway']
        if identifier=='alpine_meadow': ground='789C66'
        if identifier=='tundra_pipeline': ground='A49475'
        if identifier=='saltflat_velocity': ground='E5E5D9'
        if identifier=='storm_chase': sky='536477';horizon='ABB49C'
        if identifier=='mars_badlands': ground='B46149'
        if identifier=='lunar_freight': ground='8C8B96'
        if identifier=='reactor_rift': ground='363E48';horizon='75AB88'
        spec={'id':identifier,'ground':ground,'sky_top':'252449' if night else sky,
            'horizon':'635B8A' if night else horizon,'sun':sun,'sun_energy':.25 if night else .6,
            'ambient':.52 if night else .42,'sun_rotation':[-42,-35+index*7%90,0],
            'water':identifier in ['aurora_harbor','frostbite_fjord','monsoon_delta','coral_causeway','mangrove_maze','temple_coast','container_corkscrew'],
            'coast_interval':[.08,.86] if identifier in ['aurora_harbor','frostbite_fjord','monsoon_delta','coral_causeway','mangrove_maze','temple_coast','container_corkscrew'] else [],'vegetation':TREES[identifier],
            'landmarks':[{'id':asset,'u':u,'lateral':side*(72 if asset in ['wind_turbine','gondola','reactor_rings'] else 52)} for asset,u,side in zip(LANDMARKS[identifier],[.13,.31,.49,.67,.85],[-1,1,-1,1,-1])],
            'expansion40':True,'theme':theme,'emission':.4 if night else 0,
            'soil':{'polar':'998B71','tropical':'8A6848','east_asia':'9C795A','desert':'B58456','industry':'8F897A','space':'AF6452' if identifier=='mars_badlands' else '7A5D85'}[theme],
            'terrain_margin_m':360,'space':theme=='space',
            'plantings':PLANTINGS[identifier],'district':DISTRICTS.get(identifier,''),
            'sky_seed':index*.73,'sky_style':{'polar':0,'tropical':1,'east_asia':2,'desert':3,'industry':4,'space':5}[theme],
            'accent':['57CDE0','F6CF72','F29EB5','EFAD6B','43E2DD','B0F67C'][index//5],
            'music_family':['pacific_summit','redwood_run','marina_lights','sunstone_canyon','citrus_pass','marina_lights'][index//5]}
        art['courses'].append(spec)
        text['track.'+identifier]=name
        text['route.description.'+identifier]=briefs.get(identifier,name+' — '+surface+' circuit.')
    path.write_text(json.dumps(catalog,indent=2)+'\n')
    art_path.write_text(json.dumps(art,indent=2)+'\n')
    text_path.write_text(json.dumps(text,indent=2,ensure_ascii=False)+'\n')
    print('FORTY_AUTHORED_COURSES',len(catalog['tracks']))


if __name__=='__main__': main()
