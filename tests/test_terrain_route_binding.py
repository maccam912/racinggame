import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from terrain_route_binding import route_matches


class TerrainRouteBindingTests(unittest.TestCase):
    def test_vehicle_roster_changes_do_not_require_different_terrain(self):
        root = Path(__file__).resolve().parents[1]
        bake = json.loads((root/'game/content/baked/palm_bay.json').read_text())
        row = next(r for r in json.loads((root/'assets/exported/scenery/terrain.json').read_text())['courses'] if r['id']=='palm_bay')
        changed = copy.deepcopy(bake)
        changed['content_hash'] = '0'*64
        changed['ai_speeds'] = {}
        self.assertTrue(route_matches(row,changed))
        changed['samples'][0][0] += .01
        self.assertFalse(route_matches(row,changed))


if __name__ == '__main__':
    unittest.main()
