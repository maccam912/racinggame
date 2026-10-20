#!/usr/bin/env python3
"""Render the actual baked routes and elevation profiles as a reviewable SVG."""
import json
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1100" viewBox="0 0 1600 1100">',
             '<rect width="1600" height="1100" fill="#101525"/>',
             '<g font-family="sans-serif" fill="#f6eedb">',
             '<text x="30" y="38" font-size="25" font-weight="bold">PACIFIC RUSH — TEN DIFFERENT DRIVES</text>',
             '<text x="30" y="65" font-size="14" fill="#bac9dd">Actual baked centerlines • each card scaled to fit • yellow dots are launch ramps • elevation strip below each route</text>']
    tracks = json.loads((ROOT/'game/content/tracks.json').read_text())['tracks']
    metrics = []
    for i, track in enumerate(tracks):
        bake = json.loads((ROOT/track['baked_route_id'].removeprefix('res://')).read_text())
        rows = bake['samples']
        x, y = 20+(i%5)*316, 90+(i//5)*500
        parts.append(f'<rect x="{x}" y="{y}" width="302" height="480" rx="12" fill="#1a2338"/>')
        parts.append(f'<text x="{x+16}" y="{y+30}" font-size="19" font-weight="bold">{escape(track["name"])}</text>')
        color = '#e8a45c' if track['road_surface']=='dirt' else '#70dbe5' if track['id']=='caldera_crosscut' else '#b4c8f3'
        low_x, high_x = min(r[0] for r in rows), max(r[0] for r in rows)
        low_z, high_z = min(r[2] for r in rows), max(r[2] for r in rows)
        scale = 254/max(high_x-low_x,high_z-low_z)
        def xy(row):
            return (x+151+(row[0]-(high_x+low_x)/2)*scale,
                    y+205+(row[2]-(high_z+low_z)/2)*scale)
        points = [xy(row) for row in rows[::4]]
        d = 'M'+' L'.join(f'{a:.2f},{b:.2f}' for a,b in points)+' Z'
        parts.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="4" stroke-linejoin="round"/>')
        a,b = xy(rows[0])
        parts.append(f'<circle cx="{a:.2f}" cy="{b:.2f}" r="5" fill="#fff5e5"/>')
        for marker in track['ramp_markers']:
            row = min(rows,key=lambda r:abs(r[7]-marker))
            a,b = xy(row)
            parts.append(f'<circle cx="{a:.2f}" cy="{b:.2f}" r="5" fill="#ffd052" stroke="#101525" stroke-width="1.5"/>')
        low, high = min(r[1] for r in rows), max(r[1] for r in rows)
        profile = ' '.join(f'{x+22+dist/bake["length"]*258:.2f},{y+407-(r[1]-low)/max(1,high-low)*50:.2f}' for dist,r in zip(bake['distances'][::8],rows[::8]))
        parts.append(f'<polyline points="{profile}" fill="none" stroke="{color}" stroke-width="2"/>')
        label = f'{bake["length"]/1000:.2f} km · {track["road_surface"].title()} · {high-low:.0f} m rise/fall'
        parts.append(f'<text x="{x+16}" y="{y+440}" font-size="14">{label}</text>')
        parts.append(f'<text x="{x+16}" y="{y+463}" font-size="13" fill="#bac9dd">{len(track["ramp_markers"])} launches · min radius {bake["validation"]["min_radius"]:.0f} m</text>')
        metrics.append({'track':track['id'],'length_m':bake['length'],'surface':track['road_surface'],
                        'elevation_range_m':round(high-low,3),'launches':len(track['ramp_markers']),
                        'straight_fraction':round(sum(abs(r[6])<.001 for r in rows)/len(rows),3),**bake['validation']})
    parts.append('</g></svg>')
    folder = ROOT/'docs/evidence/arcade-tracks'
    folder.mkdir(parents=True,exist_ok=True)
    (folder/'layouts.svg').write_text('\n'.join(parts)+'\n')
    (folder/'geometry.json').write_text(json.dumps(metrics,indent=2)+'\n')
    print(folder/'layouts.svg')


if __name__ == '__main__':
    main()
