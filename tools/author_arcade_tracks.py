#!/usr/bin/env python3
"""Author the six classic courses as distinct arcade routes; then run bake_tracks.py.

Coordinates, corner cuts and height profiles are intentional design inputs, not
random variations of a common circuit. The four expansion routes retain theirs.
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def rounded(vertices, cut, height):
    """Tangent straight / corner controls for an angular street or rally polygon."""
    points = []
    for i, corner in enumerate(vertices):
        before, after = vertices[i-1], vertices[(i+1) % len(vertices)]
        incoming = [before[j]-corner[j] for j in range(2)]
        outgoing = [after[j]-corner[j] for j in range(2)]
        incoming = [x/math.hypot(*incoming) for x in incoming]
        outgoing = [x/math.hypot(*outgoing) for x in outgoing]
        distance = cut[i] if isinstance(cut, list) else cut
        entry = [corner[j]+incoming[j]*distance for j in range(2)]
        exit = [corner[j]+outgoing[j]*distance for j in range(2)]
        middle = [(entry[j]+2*corner[j]+exit[j])/4 for j in range(2)]
        for x, z in [[corner[j]+incoming[j]*(distance+50) for j in range(2)], entry,
                     middle, exit, [corner[j]+outgoing[j]*(distance+50) for j in range(2)]]:
            points.append([round(x, 4), round(height(x, z), 4), round(z, 4)])
    return points


def main():
    path = ROOT/'game/content/tracks.json'
    catalog = json.loads(path.read_text())
    tracks = {t['id']:t for t in catalog['tracks']}
    # Broad seaside pentagon: open throttle, sweeping coastal corners.
    tracks['palm_bay']['ordered_control_points'] = rounded(
        [(0, 0), (0, -950), (700, -1200), (1200, -600), (850, 200)],
        [170, 180, 180, 190, 180], lambda x,z: 4+28*math.exp(-((x-1070)/330)**2-((z+550)/480)**2))
    # An orthogonal docklands block circuit: three long boulevards and a dogleg.
    tracks['marina_lights']['ordered_control_points'] = rounded(
        [(0, 200), (0, -1000), (1000, -1000), (1000, -500),
         (500, -500), (500, 0), (1000, 0), (1000, 400)],
        [110, 110, 110, 110, 110, 110, 110, 110], lambda x,z: 3)
    # Agricultural rally: alternating left/right cuts, mostly loose clay.
    tracks['citrus_pass']['ordered_control_points'] = rounded(
        [(0, 0), (0, -1050), (500, -1050), (500, -650), (950, -650),
         (950, -200), (1400, -200), (1400, 350), (650, 350)],
        125, lambda x,z: 8+42*math.sin(math.pi*max(0,min(1,x/1400)))**2)
    # Forest rally: a narrow serpentine outward leg and a sweeping return.
    tracks['redwood_run']['ordered_control_points'] = [
        [0,10,0],[0,10,-200],[0,10,-400],[70,20,-630],
        [280,48,-810],[500,74,-670],[360,66,-450],[590,44,-290],
        [820,22,-430],[1030,28,-650],[1240,60,-520],[1280,88,-260],
        [1080,102,-40],[1300,78,180],[1160,44,430],[860,22,530],
        [580,10,400],[300,10,350],[70,10,180],[0,10,65]]
    # Desert stadium: a long launch straight, a hard turn, then a rolling infield.
    tracks['sunstone_canyon']['ordered_control_points'] = [
        [0,12,0],[0,12,-200],[0,12,-450],[0,12,-700],
        [100,18,-950],[360,44,-1050],[620,58,-950],[660,38,-700],
        [460,18,-540],[420,20,-300],[650,50,-140],[900,80,-250],
        [1160,58,-100],[1200,26,180],[1000,12,430],[700,12,500],
        [420,12,400],[180,12,300],[20,12,180],[0,12,65]]
    # Mountain rollercoaster: repeated high ridges, long drops and three launches.
    tracks['pacific_summit']['ordered_control_points'] = [
        [0,20,0],[0,20,-250],[0,20,-500],[120,40,-800],
        [380,90,-1050],[700,140,-1100],[1020,168,-920],[1100,138,-620],
        [880,78,-350],[1000,38,-80],[1320,70,120],[1400,118,430],
        [1170,154,680],[820,120,650],[600,62,410],[350,22,500],
        [100,20,350],[0,20,120],[0,20,60]]
    for id in ['palm_bay','citrus_pass','marina_lights','redwood_run','sunstone_canyon','pacific_summit']:
        tracks[id]['bank_intervals'] = []
        tracks[id]['width_intervals'] = []
        tracks[id]['ramp_markers'] = []
        tracks[id]['road_surface'] = 'asphalt'
        tracks[id]['spline'] = 'centripetal'
    tracks['palm_bay']['width'] = 20
    tracks['citrus_pass'].update(road_surface='dirt', width=18, ramp_markers=[.24,.68])
    tracks['redwood_run'].update(road_surface='dirt', width=16, ramp_markers=[.32])
    tracks['sunstone_canyon'].update(road_surface='dirt', width=20, ramp_markers=[.12,.46,.74])
    tracks['pacific_summit'].update(width=18, ramp_markers=[.27,.50,.73], bank_intervals=[[.32,.40,7],[.76,.84,8]])
    tracks['pacific_summit']['width_intervals'] = [[m-.015,m+.025,24] for m in [.27,.50,.73]]
    for t in catalog['tracks']:
        t.setdefault('road_surface','asphalt')
    path.write_text(json.dumps(catalog, indent=2)+'\n')


if __name__ == '__main__':
    main()
