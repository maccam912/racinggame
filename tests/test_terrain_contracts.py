import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('terrain_contracts', ROOT/'tools/terrain_contracts.py')
TERRAIN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TERRAIN)


class TerrainContracts(unittest.TestCase):
    def glb(self, folder, positions=None, transform=False, indices=None):
        positions = positions or [(0, 0, 0), (32, 0, 0), (32, 1, 32)]
        # Deliberately interleave position/normal with a leading four-byte pad.
        binary = b'PAD!'+b''.join(struct.pack('<6f', *p, 0, 1, 0) for p in positions)
        indices = [0, 1, 2] if indices is None else indices
        index_offset = len(binary)
        binary += struct.pack('<'+'H'*len(indices), *indices)
        doc = {'nodes': [{'mesh': 0}], 'meshes': [{'primitives': [{'attributes': {'POSITION': 0, 'NORMAL': 1}, 'indices': 2}]}],
               'accessors': [{'bufferView': 0, 'componentType': 5126, 'type': 'VEC3', 'count': len(positions)},
                             {'bufferView': 0, 'byteOffset': 12, 'componentType': 5126, 'type': 'VEC3', 'count': len(positions)},
                             {'bufferView': 1, 'componentType': 5123, 'type': 'SCALAR', 'count': len(indices)}], 'bufferViews': [{'buffer': 0, 'byteOffset': 4, 'byteLength': index_offset-4, 'byteStride': 24}, {'buffer': 0, 'byteOffset': index_offset, 'byteLength': len(binary)-index_offset}]}
        if transform:
            doc['nodes'][0]['translation'] = [0, 1, 0]
        source = json.dumps(doc).encode()
        source += b' '*(-len(source) % 4)
        binary += b'\0'*(-len(binary) % 4)
        chunks = struct.pack('<II', len(source), 0x4E4F534A)+source+struct.pack('<II', len(binary), 0x004E4942)+binary
        path = Path(folder)/'test.glb'
        path.write_bytes(struct.pack('<III', 0x46546C67, 2, 12+len(chunks))+chunks)
        return path

    def test_real_buffer_offsets_and_stride(self):
        with tempfile.TemporaryDirectory() as folder:
            grid, meshes, triangles = TERRAIN.glb_grid(self.glb(folder))
            self.assertEqual(grid, {(0, 0): 0, (32, 0): 0, (32, 32): 1})
            self.assertEqual((meshes, triangles), (1, 1))

    def test_corrupt_geometry_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            for positions in [[(0, 0, 0), (32, float('nan'), 0), (32, 1, 32)],
                              [(0, 0, 0), (0, 1, 0), (32, 1, 32)],
                              [(0, 0, 0), (31, 0, 0), (32, 1, 32)]]:
                with self.subTest(positions=positions), self.assertRaises(AssertionError):
                    TERRAIN.glb_grid(self.glb(folder, positions))
            with self.assertRaises(AssertionError):
                TERRAIN.glb_grid(self.glb(folder, transform=True))
            with self.assertRaises(AssertionError):
                TERRAIN.glb_grid(self.glb(folder, indices=[0, 1, 9]))
            with self.assertRaises(AssertionError):
                TERRAIN.glb_grid(self.glb(folder, positions=[(0, 0, 0), (64, 0, 0), (32, 1, 32)]))
            with self.assertRaises(AssertionError):
                TERRAIN.glb_grid(self.glb(folder, positions=[(0, 0, 0), (32, 0, 0), (0, 1, 32)]))
            with self.assertRaises(AssertionError):
                TERRAIN.glb_grid(self.glb(folder, indices=[0, 1, 2, 0, 1, 2]))

    def test_road_band_across_negative_cells_and_exact_boundary(self):
        band = TERRAIN.RoadBand([[0, 0, 0], [-1050, 10, -600]])
        self.assertTrue(band.contains(240, 0))
        self.assertFalse(band.contains(241, 0))
        self.assertTrue(band.contains(-1200, -600))
        self.assertFalse(band.contains(800, 800))

    def test_protected_hash_and_sparse_water_runs(self):
        grid = {(0, 0): 1.0, (32, 0): 2.0, (64, 0): 3.0}
        protected = [(0, 0), (32, 0)]
        before = TERRAIN.digest_grid(grid, protected)
        grid[64, 0] = 12
        self.assertEqual(before, TERRAIN.digest_grid(grid, protected))
        grid[32, 0] += .001
        self.assertNotEqual(before, TERRAIN.digest_grid(grid, protected))
        self.assertEqual(TERRAIN.runs([0, 1, 4, 5, 6, 9]), [[0, 2], [4, 7], [9, 10]])
        self.assertEqual(TERRAIN.runs([]), [])


if __name__ == '__main__':
    unittest.main()
