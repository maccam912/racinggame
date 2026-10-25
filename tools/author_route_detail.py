#!/usr/bin/env python3
"""Author deterministic three-scale detail, then retain explicit editable profiles.

This is an authoring operation, not a runtime randomizer. Canonical baking still
owns final resampling, radius/grade/separation checks, gates and AI speed lines.
"""
import argparse
import copy
import hashlib
import json
import math
import random
from pathlib import Path
from bake_tracks import bake

ROOT=Path(__file__).resolve().parents[1]


def smooth(t):
    t=max(0,min(1,t))
    return t*t*t*(10+t*(-15+6*t))


def fade(s,a,b,width):
    return smooth((s-a)/width)*smooth((b-s)/width)


def layer(n,spacing,amplitude,seed):
    rng=random.Random(seed)
    count=max(4,round(n*2/spacing))
    nodes=[rng.uniform(-amplitude,amplitude) for _ in range(count)]
    out=[]
    for i in range(n):
        u=i*count/n;j=int(u);t=u-j
        weights=((1-t)**3,3*t**3-6*t*t+4,-3*t**3+3*t*t+3*t+1,t**3)
        out.append(sum(w*nodes[(j+k-1)%count] for k,w in enumerate(weights))/6)
    return out


def curvature(points):
    n=len(points);tangents=[]
    for i in range(n):
        a,b=points[i-1],points[(i+1)%n]
        dx,dz=b[0]-a[0],b[2]-a[2];length=math.hypot(dx,dz)
        tangents.append((dx/length,dz/length))
    result=[]
    for i in range(n):
        a,b=tangents[i-1],tangents[(i+1)%n]
        ang=math.atan2(a[0]*b[1]-a[1]*b[0],a[0]*b[0]+a[1]*b[1])
        span=math.dist(points[i],points[i-1])+math.dist(points[i],points[(i+1)%n])
        result.append(ang/span)
    return result


def envelope(track,base,city):
    rows=base['samples'];n=len(rows);length=base['length']
    corner_distance=[0.0 if abs(r[6])>.009 else length for r in rows]
    for _ in range(2):
        for j in range(2*n):
            i=j%n;corner_distance[i]=min(corner_distance[i],corner_distance[i-1]+2)
        for j in range(2*n-1,-1,-1):
            i=j%n;corner_distance[i]=min(corner_distance[i],corner_distance[(i+1)%n]+2)
    result=[]
    for i,row in enumerate(rows):
        s=i*2
        env=fade(s,170,length-80,140)
        if city:
            env*=1-fade(s,0,min(950,length*.16),100)
            env*=1-fade(s,length*.65,length*.79,100)
            env*=smooth((corner_distance[i]-20)/100)
        for lo,hi,_ in track['bank_intervals']:
            env*=1-fade(row[7],max(0,lo-.08),min(1,hi+.08),.03)
        for marker in track['ramp_markers']:
            delta=((row[7]-marker+.5)%1-.5)*length
            env*=smooth((-delta-100)/100) if delta<0 else smooth((delta-180)/120)
        if track['id']=='saltflat_velocity':
            env*=smooth((s-2300)/180)
        if track['id']=='skyline_splice':
            delta=min(row[7],1-row[7],abs(row[7]-.5))*length
            env*=smooth((delta-130)/100)
        result.append(env)
    return result


def author(track,city,seed):
    base=bake(track);rows=base['samples'];n=len(rows)
    env=envelope(track,base,city)
    medium=layer(n,96,42,seed);fine=layer(n,48,24,seed+1)
    offsets=[(a+b)*e for a,b,e in zip(medium,fine,env)]
    def moved(profile):
        return [[r[0]-r[5]*d,r[1],r[2]+r[3]*d] for r,d in zip(rows,profile)]
    target=min(30,base['validation']['min_radius']-.1)
    factor=1.0
    for _ in range(100):
        if 1/max(abs(x) for x in curvature(moved([v*factor for v in offsets])))>=target:break
        factor*=.965
    offsets=[v*factor for v in offsets]
    broad=[v*e for v,e in zip(layer(n,205,100,seed+2),env)]
    for _ in range(500):
        k=curvature(moved([a+b for a,b in zip(offsets,broad)]))
        peak=max(range(n),key=lambda i:abs(k[i]))
        if 1/abs(k[peak])>=target:break
        for i in range(n):
            distance=min(abs(i-peak),n-abs(i-peak))*2
            if distance<480:broad[i]*=1-.14*math.exp(-.5*(distance/150)**2)
    return base,[a+b for a,b in zip(offsets,broad)]


def profile(base,offsets):
    # Eight-metre authoring handles preserve the approved small features;
    # the baker interpolates them and independently resamples the final road.
    count=math.ceil(base['length']/8)
    count+=count%2
    def sample(u):
        s=(u*base['length']-base['start_sample']*2)%base['length']
        at=s/2;index=int(at);alpha=at-index
        return offsets[index%len(offsets)]*(1-alpha)+offsets[(index+1)%len(offsets)]*alpha
    return [round(sample(i/count),5) for i in range(count)]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tracks',help='Explicitly regenerate only these profiles; otherwise author missing profiles only')
    args=parser.parse_args()
    selected=set(args.tracks.split(',')) if args.tracks else set()
    source=ROOT/'assets/source/technical_courses15.json'
    catalog=json.loads((ROOT/'game/content/tracks.json').read_text())
    designs=json.loads(source.read_text())
    old={t['id']:t for t in catalog['tracks']}
    for row in designs['courses']:
        if row.get('authored_detail',{}).get('style')=='smooth':continue
        if row['id'] not in selected and row.get('detail_offsets'):continue
        track=copy.deepcopy(old[row['id']])
        for key in ['ordered_control_points','spline','ramp_markers','width_intervals','bank_intervals']:
            track[key]=row[key]
        track.pop('detail_offsets',None)
        base,offsets=author(track,row['city'],row['noise_seed'])
        if row.get('approved_offsets'):
            assert len(row['approved_offsets'])==len(base['samples'])
            offsets=row.pop('approved_offsets')
        values=profile(base,offsets)
        if track['id']=='skyline_splice':
            half=len(values)//2
            values=values[:half]+[-v for v in values[:half]]
        factor=1.0
        for attempt in range(120):
            track['detail_offsets']=[round(v*factor,5) for v in values]
            try:
                result=bake(track)
                break
            except AssertionError as error:
                if attempt==119:raise
                factor*=.95
        row['detail_offsets']=track['detail_offsets']
        row['authored_detail']={'octaves':[[48,24],[96,42],[205,100]],'bake_tuning':round(factor,6),'max_lateral_m':max(abs(v) for v in track['detail_offsets']),'length_m':result['length'],'min_radius_m':result['validation']['min_radius']}
        print(track['id'],round(result['length']),result['validation'],'detail',round(row['authored_detail']['max_lateral_m'],1),flush=True)
    source.write_text(json.dumps(designs,indent=2)+'\n')


if __name__=='__main__':main()
