"""Catalog untouched generated atlas pixels through alpha-bounded UV regions."""
import hashlib
import json
from pathlib import Path
import shutil
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'assets/source/expansion40'
OUT=ROOT/'assets/exported/billboards/expansion40'
PACKS={
 'polar': [('ice_spires',38),('polar_huts',17),('chalet',18),('research_base',31),('spruce_snow',24),('expansion_alpine_fir',23),('gondola',38),('pump_station',22)],
 'tropical':[('jungle_temple',38),('kapok',30),('stilt_village',24),('coral_arch',32),('tree_fern',19),('mangrove',20),('stone_face',28),('island_resort',25)],
 'east-asia':[('sakura',21),('bamboo',27),('pagoda',39),('torii',28),('lantern_market',19),('tea_terrace',30),('sea_shrine',28),('waterwheel_house',22)],
 'desert':[('dune_spires',40),('citadel',37),('oasis_palm',27),('mine_headframe',34),('salt_spires',31),('barn_silos',28),('wind_turbine',52),('radar_station',35)],
 'industry':[('furnace',43),('cooling_towers',40),('cargo_crane',47),('containers',22),('neon_gate',27),('steel_pylon',45),('grandstand',25),('festival_stage',27),('ferris_wheel',50),('cargo_ship',32),('dry_dock',32),('ventilation_station',30)],
 'space':[('lunar_base',30),('space_dish',42),('rocket',55),('mars_hoodoo',45),('greenhouse',31),('reactor_rings',48),('solar_array',43),('crystal_cluster',42)]}


def subject_bounds(mask):
    """Choose the main connected silhouette, ignoring adjacent-cell fragments.

    This only chooses a UV rectangle. It does not edit or export image pixels.
    Scanline flood fill needs no image-processing dependency beyond NumPy.
    """
    remaining=mask.copy();height,width=remaining.shape
    biggest=0;bounds=None
    for y in range(height):
        while remaining[y].any():
            stack=[(int(np.flatnonzero(remaining[y])[0]),y)]
            area=0;lo_x=width;lo_y=height;hi_x=hi_y=-1
            while stack:
                x,at_y=stack.pop()
                if not remaining[at_y,x]:continue
                left=right=x
                while left>0 and remaining[at_y,left-1]:left-=1
                while right+1<width and remaining[at_y,right+1]:right+=1
                remaining[at_y,left:right+1]=False
                area+=right-left+1
                lo_x=min(lo_x,left);hi_x=max(hi_x,right)
                lo_y=min(lo_y,at_y);hi_y=max(hi_y,at_y)
                for neighbor in [at_y-1,at_y+1]:
                    if neighbor<0 or neighbor>=height:continue
                    run=remaining[neighbor,left:right+1]
                    starts=np.flatnonzero(run & ~np.r_[False,run[:-1]])
                    stack.extend((left+int(start),neighbor) for start in starts)
            if area>biggest:biggest=area;bounds=(lo_x,lo_y,hi_x-lo_x+1,hi_y-lo_y+1)
    assert biggest>1000 and bounds is not None
    return bounds


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    provenance=json.loads((SOURCE/'generation.json').read_text())
    original=next(row for row in provenance['images'] if row['id']=='polar')
    provenance['images']=[]
    rows=[]
    for pack,items in PACKS.items():
        source=SOURCE/(pack+'-v1.png')
        target=OUT/source.name
        shutil.copyfile(source,target)
        image=Image.open(source).convert('RGBA')
        pixels=np.asarray(image);mask=pixels[:,:,3]>=128
        height,width=mask.shape
        assert (pixels[:,:,3]==0).sum()>width*height*.15, 'Real generated transparency required'
        row_count=3 if pack=='industry' else 2
        # The generated cell spacing is approximate. Locate clear gutters near
        # the requested row boundaries without modifying a single source pixel.
        vertical=[0]
        for row in range(1,row_count):
            lo=round(height*(row/row_count-.085));hi=round(height*(row/row_count+.085))
            counts=mask[lo:hi].sum(axis=1)
            best=np.flatnonzero(counts==counts.min())
            vertical.append(lo+int(best[len(best)//2]))
        vertical.append(height)
        for index,(identifier,world_height) in enumerate(items):
            row,column=divmod(index,4)
            y0,y1=vertical[row:row+2]
            horizontal=[0]
            for divider in range(1,4):
                lo=round(width*(divider/4-.055));hi=round(width*(divider/4+.055))
                counts=mask[y0:y1,lo:hi].sum(axis=0)
                best=np.flatnonzero(counts==counts.min())
                horizontal.append(lo+int(best[len(best)//2]))
            horizontal.append(width)
            x0,x1=horizontal[column:column+2]
            cell=mask[y0:y1,x0:x1]
            local_x,local_y,w,h=subject_bounds(cell)
            x,y=x0+local_x,y0+local_y
            rows.append({'id':identifier,'path':target.relative_to(ROOT).as_posix(),
                'source':source.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                'pixels':[width,height],'uv_bounds_pixels':[x,y,w,h],
                'size_m':[round(world_height*w/h,4),1,world_height],
                'alpha_scissor':.5,'pack':pack,'solid_pixels':int(cell.sum()),'transparent_pixels':int((pixels[y0:y1,x0:x1,3]==0).sum())})
        prompt=original['prompt'] if pack=='polar' else (SOURCE/(pack+'-prompt.txt')).read_text().strip()
        provenance['images'].append({'id':pack,'source':source.relative_to(ROOT).as_posix(),
            'export':target.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'pixels':[width,height],'transparent_background':True,'prompt':prompt})
    # A separate clean cherry silhouette replaces the atlas cell whose leaves
    # touched the neighboring bamboo. Source PNG pixels remain untouched.
    source=SOURCE/'sakura-v1.png';target=OUT/source.name
    shutil.copyfile(source,target)
    image=Image.open(source).convert('RGBA');pixels=np.asarray(image)
    mask=pixels[:,:,3]>=128;ys,xs=np.nonzero(mask)
    x,y=int(xs.min()),int(ys.min());w,h=int(xs.max()-xs.min()+1),int(ys.max()-ys.min()+1)
    row=next(row for row in rows if row['id']=='sakura')
    row.update(path=target.relative_to(ROOT).as_posix(),source=source.relative_to(ROOT).as_posix(),
        sha256=hashlib.sha256(source.read_bytes()).hexdigest(),pixels=list(image.size),
        uv_bounds_pixels=[x,y,w,h],size_m=[round(21*w/h,4),1,21],solid_pixels=int(mask.sum()),
        transparent_pixels=int((pixels[:,:,3]==0).sum()))
    provenance['images'].append({'id':'sakura','source':row['source'],'export':row['path'],
        'sha256':row['sha256'],'pixels':row['pixels'],'transparent_background':True,
        'prompt':(SOURCE/'sakura-prompt.txt').read_text().strip()})
    (SOURCE/'generation.json').write_text(json.dumps(provenance,indent=2)+'\n')
    (OUT/'catalog.json').write_text(json.dumps({'schema_version':1,'source':'assets/source/describe_expansion40.py','assets':rows},indent=2)+'\n')
    print('EXPANSION40_UNMODIFIED_ALPHA_ATLASES',len(PACKS),'SPRITES',len(rows))


if __name__=='__main__': main()
