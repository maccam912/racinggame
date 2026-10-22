#!/usr/bin/env python3
"""Thirty individually drawn course polygons for the forty-course roster.

See docs/COURSE_ROSTER_40.md. This authors canonical JSON; bake_tracks.py remains
the only route baker. Existing ten routes and their asset bytes are retained.
"""
import copy
import json
import math
from pathlib import Path
from author_arcade_tracks import rounded

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


def main():
    path=ROOT/'game/content/tracks.json'
    catalog=json.loads(path.read_text());catalog['tracks']=catalog['tracks'][:10]
    art_path=ROOT/'assets/source/course_specs.json'
    art=json.loads(art_path.read_text());art['courses']=art['courses'][:10]
    text_path=ROOT/'game/ui/text/en.json';text=json.loads(text_path.read_text())
    briefs={line.split('`')[1]:line.split('|')[3].strip() for line in (ROOT/'docs/COURSE_ROSTER_40.md').read_text().splitlines() if line.startswith('| ') and '` / ' in line}
    for index,(identifier,theme,surface,width,relief,polygon) in enumerate(ROUTES):
        name=identifier.replace('_',' ').title()
        if identifier=='steelworks_sprint': polygon=[(x*.94,z*.94) for x,z in polygon]
        if identifier=='frostbite_fjord': polygon=[(x*.89,z*.89) for x,z in polygon]
        max_x=max(x for x,z in polygon)
        # The initial x=0 straight remains level, keeping an honest legal grid.
        def height(x,z):
            return 12+relief*math.sin(math.pi*max(0,min(1,x/max_x)))**2
        cuts={
            'mangrove_maze':[110]*11+[170],
            'oasis_citadel':240,
            'steelworks_sprint':[110]*8+[300]+[110]*2,
            'container_corkscrew':160,
            'lunar_freight':[110]*7+[340]+[110]*2,
        }.get(identifier,110)
        controls=rounded(polygon,cuts,height)
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
