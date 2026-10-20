"""Guard the requested driving differences, using actual canonical geometry."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class TrackVarietyTests(unittest.TestCase):
    def test_street_rally_and_mountain_have_different_demands(self):
        tracks = {t['id']:t for t in json.loads((ROOT/'game/content/tracks.json').read_text())['tracks']}
        bakes = {id:json.loads((ROOT/t['baked_route_id'].removeprefix('res://')).read_text()) for id,t in tracks.items()}
        city = bakes['marina_lights']['samples']
        forest = bakes['redwood_run']['samples']
        summit = bakes['pacific_summit']['samples']
        self.assertGreater(sum(abs(r[6])<.001 for r in city)/len(city), .6, 'street course needs long straight boulevards')
        self.assertGreater(sum(abs(r[6])>.01 for r in city)/len(city), .08, 'street course needs actual braking corners')
        self.assertLess(max(r[1] for r in city)-min(r[1] for r in city), 1, 'city driving must differ from the hill courses')
        self.assertLess(sum(abs(r[6])<.001 for r in forest)/len(forest), .25, 'forest rally needs continuous steering')
        self.assertTrue(any(r[6]>.01 for r in forest) and any(r[6]<-.01 for r in forest), 'rally needs linked bends in both directions')
        self.assertGreater(max(r[1] for r in summit)-min(r[1] for r in summit), 145)
        self.assertEqual(len(tracks['pacific_summit']['ramp_markers']),3)
        self.assertEqual(len(tracks['sunstone_canyon']['ramp_markers']),3)
        self.assertGreaterEqual(sum(t['road_surface']=='dirt' for t in tracks.values()),3)
        art = json.loads((ROOT/'assets/source/course_specs.json').read_text())['courses']
        self.assertTrue(next(t for t in art if t['id']=='caldera_crosscut')['space'])


if __name__ == '__main__':
    unittest.main()
