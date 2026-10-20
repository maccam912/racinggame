#!/usr/bin/env python3
"""Canonical Catmull–Rom/2 m bake and geometric acceptance checks (DESIGN §10)."""
import argparse
import bisect
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / 'game/content'


def add(a, b):
    return tuple(x+y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x-y for x, y in zip(a, b))


def mul(a, f):
    return tuple(x*f for x in a)


def length(a):
    return math.sqrt(sum(x*x for x in a))


def unit(a):
    return mul(a, 1/length(a))


def smooth(x):
    x = max(0, min(1, x))
    return x*x*(3-2*x)


def catmull(p0, p1, p2, p3, t):
    return tuple(.5*(2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t**3)
                 for a, b, c, d in zip(p0, p1, p2, p3))


def interpolate(points, distances, s):
    i = min(len(points)-2, bisect.bisect_right(distances, s)-1)
    alpha = (s-distances[i])/(distances[i+1]-distances[i])
    return add(points[i], mul(sub(points[i+1], points[i]), alpha))


def bake(track):
    controls = track['ordered_control_points']
    count = len(controls)
    assert 16 <= count <= 32, f"{track['id']}: expected 16 to 32 route points"
    points = [catmull(controls[(i-1)%count], controls[i], controls[(i+1)%count], controls[(i+2)%count], j/256)
              for i in range(count) for j in range(256)]
    points.append(points[0])
    distances = [0.0]
    for a, b in zip(points, points[1:]):
        distances.append(distances[-1]+length(sub(b, a)))
    total = distances[-1]
    samples = [interpolate(points, distances, s) for s in range(0, math.ceil(total), 2)]
    n = len(samples)
    tangents = [unit(sub(samples[(i+1)%n], samples[(i-1)%n])) for i in range(n)]
    curvature, grades = [], []
    for i in range(n):
        a, b = tangents[(i-1)%n], tangents[(i+1)%n]
        angle = math.atan2(a[0]*b[2]-a[2]*b[0], a[0]*b[0]+a[2]*b[2])
        span = length(sub(samples[i], samples[(i-1)%n]))+length(sub(samples[(i+1)%n], samples[i]))
        curvature.append(angle/span)
        grades.append(abs(tangents[i][1])/math.hypot(tangents[i][0], tangents[i][2]))
    minimum_radius = 1/max(abs(x) for x in curvature)
    assert minimum_radius >= 28, f"{track['id']}: radius {minimum_radius:.2f} < 28 m"
    assert max(grades) <= .24, f"{track['id']}: grade exceeds 24%"

    def distance_to_features(s):
        features = [u*total for u in track['ramp_markers']]
        features += [u*total for interval in track['bank_intervals'] for u in interval[:2]]
        for lo, hi, _ in track['bank_intervals']:
            if lo*total <= s <= hi*total:
                return 0
        return min((min(abs(s-x), total-abs(s-x)) for x in features), default=total)

    start = next((i for i in range(n) if distance_to_features(2*i) >= 100
                  and all(abs(curvature[(i+j)%n]) < .0025 and grades[(i+j)%n] < .03
                          for j in range(-23, 36))), None)
    assert start is not None, f"{track['id']}: no legal starting straight"
    # Broad-phase spatial hash; arc-neighbor sections are the same local road.
    cells = {}
    for i, p in enumerate(samples):
        cell = (math.floor(p[0]/40), math.floor(p[2]/40))
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for j in cells.get((cell[0]+dx, cell[1]+dz), []):
                    if min(i-j, n-(i-j))*2 < 80 or abs(p[1]-samples[j][1]) > 10:
                        continue
                    horizontal = math.hypot(p[0]-samples[j][0], p[2]-samples[j][2])
                    max_width = max([track['width']]+[w[2] for w in track['width_intervals']])
                    assert horizontal >= max_width+8, f"{track['id']}: sections {i}/{j} too close ({horizontal:.1f} m)"
        cells.setdefault(cell, []).append(i)

    raw = []
    for i, (p, tangent, curve) in enumerate(zip(samples, tangents, curvature)):
        s, u = i*2, i*2/total
        width = track['width']
        for lo, hi, value in track['width_intervals']:
            fade = min(smooth((s-lo*total)/30), smooth((hi*total-s)/30))
            width += (value-track['width'])*fade
        bank = 0
        for lo, hi, degrees in track['bank_intervals']:
            fade = min(smooth((s-lo*total)/20), smooth((hi*total-s)/20))
            bank += math.radians(degrees)*fade*max(-1, min(1, curve/.001))
        height = 0
        for marker in track['ramp_markers']:
            relative = s-marker*total
            if -12 <= relative < 0:
                height += 1.2*(relative+12)/12
            elif 0 <= relative < 50:
                height += 1.2*(1-smooth(relative/50))
        raw.append([*p, *tangent, curve, u, width, bank, height])
    rotated = raw[start:]+raw[:start]
    cumulative = [0.0]
    for i in range(1, n):
        cumulative.append(cumulative[-1]+length(sub(rotated[i][:3], rotated[i-1][:3])))
    gates = []
    for s in range(0, math.ceil(total), 100):
        i = min(n-1, bisect.bisect_left(cumulative, s))
        a, b = rotated[(i-1)%n], rotated[i]
        ds = cumulative[i]-cumulative[i-1] if i else 2
        alpha = 1-(cumulative[i]-s)/ds
        pos = add(a[:3], mul(sub(b[:3], a[:3]), alpha)) if i else b[:3]
        f = unit(b[3:6])
        gates.append({'s': s, 'position': list(pos), 'forward': list(f),
                      'recovery': list(add(pos, mul(f, -6)))})
    assert 1 <= len(gates) <= 128, f"{track['id']}: checkpoint count exceeds the signed-byte snapshot field"
    speeds = {}
    cars = json.loads((CONTENT/'cars.json').read_text())['cars']
    smooth_curve = [sum(rotated[(i+j)%n][6] for j in range(-2, 3))/5 for i in range(n)]
    for car in cars:
        line = [max(12, min(.96*car['top_speed'], math.sqrt(car['grip']*.82/max(abs(c), .0005)))) for c in smooth_curve]
        for _ in range(4):
            for i in range(n-1, -1, -1):
                segment = length(sub(rotated[(i+1)%n][:3], rotated[i][:3]))
                line[i] = min(line[i], math.sqrt(line[(i+1)%n]**2+24*segment))
        speeds[car['id']] = [round(x, 6) for x in line]
    result = {'schema_version':1, 'track_id':track['id'], 'length':round(total, 6), 'start_sample':start,
              'columns':['x','y','z','fx','fy','fz','curvature','original_u','width','bank','ramp_height'],
              'samples':[[round(x, 6) for x in row] for row in rotated],
              'distances':[round(x, 6) for x in cumulative], 'gates':gates, 'ai_speeds':speeds,
              'validation':{'min_radius':round(minimum_radius, 3), 'max_grade':round(max(grades), 6)}}
    result['content_hash'] = hashlib.sha256(json.dumps(result, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return result


def main(check=False):
    folder = CONTENT/'baked'
    folder.mkdir(exist_ok=True)
    for track in json.loads((CONTENT/'tracks.json').read_text())['tracks']:
        result = bake(track)
        path = folder/(track['id']+'.json')
        text = json.dumps(result, separators=(',', ':'))+'\n'
        if check:
            assert path.read_text() == text, f"Stale bake: {path}"
        else:
            path.write_text(text)
        print(f"{track['id']}: {result['length']:.1f} m, minimum radius {result['validation']['min_radius']:.1f} m, start {result['start_sample']}, {len(result['gates'])} gates")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    main(parser.parse_args().check)
