#!/usr/bin/env python3
"""Inspect actual terrain GLBs and preserve the version-13 road-side foundation."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FOUNDATION = ROOT/'assets/source/terrain_foundations13.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def glb_grid(path):
    data = path.read_bytes()
    assert struct.unpack_from('<III', data) == (0x46546C67, 2, len(data)), path
    chunks = {}
    at = 12
    while at < len(data):
        size, kind = struct.unpack_from('<II', data, at)
        chunks[kind] = data[at+8:at+8+size]
        at += 8+size
    doc = json.loads(chunks[0x4E4F534A])
    binary = chunks[0x004E4942]
    assert all(not any(k in node for k in ['matrix', 'rotation', 'translation', 'scale']) for node in doc['nodes']), 'Terrain uses world-space vertices without node transforms'
    assert sorted(node['mesh'] for node in doc['nodes'] if 'mesh' in node) == list(range(len(doc['meshes'])))

    def vec3(index):
        accessor = doc['accessors'][index]
        assert accessor['componentType'] == 5126 and accessor['type'] == 'VEC3' and 'sparse' not in accessor
        view = doc['bufferViews'][accessor['bufferView']]
        assert view.get('buffer', 0) == 0
        offset = view.get('byteOffset', 0)+accessor.get('byteOffset', 0)
        stride = view.get('byteStride', 12)
        return [struct.unpack_from('<3f', binary, offset+i*stride) for i in range(accessor['count'])]

    grid = {}
    triangles = 0
    triangle_keys = set()
    for mesh in doc['meshes']:
        assert len(mesh['primitives']) == 1
        primitive = mesh['primitives'][0]
        assert primitive.get('mode', 4) == 4
        for normal in vec3(primitive['attributes']['NORMAL']):
            assert all(math.isfinite(v) for v in normal) and abs(sum(v*v for v in normal)-1) < .002
        positions = vec3(primitive['attributes']['POSITION'])
        for x, y, z in positions:
            assert all(math.isfinite(v) for v in [x, y, z])
            key = round(x), round(z)
            assert abs(x-key[0]) < .0001 and abs(z-key[1]) < .0001 and key[0] % 32 == key[1] % 32 == 0
            assert key not in grid or grid[key] == y, 'Chunk borders must agree exactly'
            grid[key] = y
        accessor = doc['accessors'][primitive['indices']]
        assert accessor['count'] % 3 == 0 and accessor['type'] == 'SCALAR'
        view = doc['bufferViews'][accessor['bufferView']]
        code, size = {5121: ('B', 1), 5123: ('H', 2), 5125: ('I', 4)}[accessor['componentType']]
        offset = view.get('byteOffset', 0)+accessor.get('byteOffset', 0)
        indices = [struct.unpack_from('<'+code, binary, offset+i*view.get('byteStride', size))[0] for i in range(accessor['count'])]
        assert all(i < len(positions) for i in indices)
        for first in range(0, len(indices), 3):
            a, b, c = [positions[i] for i in indices[first:first+3]]
            assert max(p[0] for p in [a,b,c])-min(p[0] for p in [a,b,c]) <= 32
            assert max(p[2] for p in [a,b,c])-min(p[2] for p in [a,b,c]) <= 32
            assert abs((b[0]-a[0])*(c[2]-a[2])-(b[2]-a[2])*(c[0]-a[0])) == 1024, 'Every face remains one half of a 32 m grid cell'
            points = tuple(sorted((round(p[0]), round(p[2])) for p in [a,b,c]))
            low = min(p[0] for p in points), min(p[1] for p in points)
            high = max(p[0] for p in points), max(p[1] for p in points)
            assert low in points and high in points, 'The authored low-left/high-right diagonal is preserved'
            assert points not in triangle_keys, 'Grid faces cannot be duplicated to hide a missing face'
            triangle_keys.add(points)
        triangles += len(indices)//3
    return grid, len(doc['meshes']), triangles


class RoadBand:
    def __init__(self, rows, radius=240):
        self.radius = radius
        self.cells = {}
        for row in rows:
            key = math.floor(row[0]/64), math.floor(row[2]/64)
            self.cells.setdefault(key, []).append((row[0], row[2]))

    def contains(self, x, z):
        radius = self.radius
        for ix in range(math.floor((x-radius)/64), math.floor((x+radius)/64)+1):
            for iz in range(math.floor((z-radius)/64), math.floor((z+radius)/64)+1):
                for px, pz in self.cells.get((ix, iz), []):
                    if (x-px)**2+(z-pz)**2 <= radius*radius:
                        return True
        return False


def digest_grid(grid, keys):
    digest = hashlib.sha256()
    for x, z in keys:
        digest.update(struct.pack('<iif', x, z, grid[x, z]))
    return digest.hexdigest()


def f32(value):
    return struct.unpack('<f', struct.pack('<f', value))[0]


def runs(indices):
    result = []
    for index in indices:
        if result and result[-1][1] == index:
            result[-1][1] += 1
        else:
            result.append([index, index+1])
    return result


def max_step(grid):
    return max(abs(y-grid[near]) for (x, z), y in grid.items() for near in [(x-32, z), (x, z-32)] if near in grid)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--freeze', action='store_true', help='Create the first immutable foundation from the current exports; refuses to overwrite')
    parser.add_argument('--grid-snapshot', type=Path, help='With --freeze, save pre-change grids for a one-off actual before/after audit')
    parser.add_argument('--before', type=Path, help='Compare actual exports against an earlier --grid-snapshot')
    parser.add_argument('--report', type=Path, default=ROOT/'reports/terrain-contracts.json')
    args = parser.parse_args()
    catalog = json.loads((ROOT/'game/content/tracks.json').read_text())['tracks']
    info = json.loads((ROOT/'assets/exported/scenery/terrain.json').read_text())['courses']
    metadata = {r['id']: r for r in info}
    manifest = json.loads((ROOT/'game/content/compatibility.json').read_text())
    if args.freeze:
        assert not FOUNDATION.exists(), 'A frozen foundation may not be replaced implicitly'
        frozen = {'schema_version': 1, 'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), 'content_hash': manifest['content_hash'], 'protected_band_m': 240, 'protected_vertex_band_m': 286, 'tracks': []}
    else:
        frozen = json.loads(FOUNDATION.read_text())
        assert frozen['schema_version'] == 1 and frozen['content_hash'] == manifest['content_hash']
        assert frozen['protected_band_m'] == 240 and frozen['protected_vertex_band_m'] == 286
    baselines = {r['id']: r for r in frozen['tracks']}
    before = json.loads(args.before.read_text())['grids'] if args.before else None
    snapshots = {}
    results = []
    for index, definition in enumerate(catalog):
        ident = definition['id']
        row = metadata[ident]
        grid, chunks, triangles = glb_grid(ROOT/row['path'])
        keys = sorted(grid)
        bounds = row.get('bounds_xz_m', [min(p[0] for p in keys), min(p[1] for p in keys), max(p[0] for p in keys), max(p[1] for p in keys)])
        expected = [(x, z) for x in range(bounds[0], bounds[2]+1, 32) for z in range(bounds[1], bounds[3]+1, 32)]
        assert keys == expected and chunks == row['chunks'] and triangles == row['triangles'] == chunks*50
        bake = json.loads((ROOT/f'game/content/baked/{ident}.json').read_text())
        protected = []
        # Instantiate the index once per course rather than per vertex.
        if index >= 10:
            band = RoadBand(bake['samples'])
            protected = [p for p in keys if band.contains(*p)]
        guard = RoadBand(bake['samples'], 286)
        surface_guard = [] if index < 10 else [p for p in keys if guard.contains(*p)]
        guard_hash = digest_grid(grid, surface_guard)
        protected_hash = digest_grid(grid, protected)
        all_hash = digest_grid(grid, keys)
        sea_y = f32(row['sea_level']-1.5)
        sea_runs = runs(i for i, p in enumerate(keys) if grid[p] == sea_y)
        if args.freeze:
            frozen['tracks'].append({'id': ident, 'classic': index < 10, 'old_export_sha256': sha(ROOT/row['path']), 'old_grid_sha256': all_hash, 'route_hash': bake['content_hash'], 'metadata': row, 'bounds_xz_m': bounds, 'grid_vertices': len(grid), 'protected_vertices': len(protected), 'protected_grid_sha256': protected_hash, 'surface_guard_vertices': len(surface_guard), 'surface_guard_grid_sha256': guard_hash, 'sea_y': sea_y, 'sea_runs': sea_runs})
            snapshots[ident] = [[x, z, grid[x, z]] for x, z in keys]
            continue
        base = baselines[ident]
        assert bake['content_hash'] == base['route_hash'] == row['route_hash']
        assert len(grid) == base['grid_vertices'] and chunks == base['metadata']['chunks'] and triangles == base['metadata']['triangles']
        assert bounds == base['bounds_xz_m'] and row['sea_level'] == base['metadata']['sea_level']
        if base['classic']:
            assert row == base['metadata'] and sha(ROOT/row['path']) == base['old_export_sha256'], 'The established ten exports and records remain byte-identical'
        else:
            assert protected_hash == base['protected_grid_sha256'] and len(protected) == base['protected_vertices'], 'Terrain within 240 m of every road sample is frozen'
            assert all_hash != base['old_grid_sha256'], 'Every addition receives an actual landform change'
            assert row['protected_road_band_m'] == 240 and row['protected_vertex_band_m'] == 286
            assert guard_hash == base['surface_guard_grid_sha256'] and len(surface_guard) == base['surface_guard_vertices'], 'The 46 m vertex guard also freezes every triangle intersecting the 240 m road band'
            assert row['relief_source_sha256'] == sha(ROOT/'assets/source/terrain_profiles.py')
        water = 0
        for first, end in base['sea_runs']:
            for i in range(first, end):
                assert grid[keys[i]] == base['sea_y'], 'Existing flat sea vertices stay at their exact water level'
                water += 1
        result = {'track': ident, 'classic': base['classic'], 'grid_vertices': len(grid), 'protected_vertices': len(protected), 'protected_grid_sha256': protected_hash, 'surface_guard_vertices': len(surface_guard), 'surface_guard_grid_sha256': guard_hash, 'triangles': triangles, 'chunks': chunks, 'fixed_sea_vertices': water, 'grid_sha256': all_hash, 'max_grid_step_m': max_step(grid)}
        if before:
            old = {(x, z): y for x, z, y in before[ident]}
            assert old.keys() == grid.keys()
            delta = [grid[p]-old[p] for p in keys]
            result.update(changed_vertices=sum(abs(d) > .0001 for d in delta), minimum_delta_m=min(delta), maximum_delta_m=max(delta), old_max_grid_step_m=max_step(old))
            assert all(grid[p] == old[p] for p in surface_guard)
        results.append(result)
    if args.freeze:
        FOUNDATION.write_text(json.dumps(frozen, indent=2)+'\n')
        if args.grid_snapshot:
            assert not args.grid_snapshot.exists()
            args.grid_snapshot.write_text(json.dumps({'grids': snapshots}, separators=(',', ':'))+'\n')
        print('FROZEN_ACTUAL_FORTY_TERRAIN_EXPORTS_CLASSIC_BYTES_PROTECTED_ROAD_BAND_AND_SEA_LEVELS')
    else:
        assert len(results) == 40
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps({'passed': True, 'content_hash': manifest['content_hash'], 'foundation_sha256': sha(FOUNDATION), 'cases': results, 'boundary': 'Actual GLB float32 vertices/normals, complete rectangular grids, mesh/triangle budgets, exact original-ten file bytes/metadata, exact protected 240 m road surface with a 46 m triangle vertex guard and pre-existing flat sea vertices. Cosmetic geometry only; native appearance is separate.'}, indent=2)+'\n')
        print('ACTUAL_FORTY_TERRAIN_EXPORTS_CLASSIC_BYTES_240M_ROAD_BAND_WATER_AND_BUDGET_PASS')


if __name__ == '__main__':
    main()
