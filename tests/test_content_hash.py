import sys
from pathlib import Path
import unittest
from unittest.mock import patch
import tempfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import content_hash

class GameplayHashTests(unittest.TestCase):
    def test_physics_adapters_participate_in_compatibility(self):
        source = content_hash.compute()
        required = ['game/world/world_query.gd','game/world/route_collision.gd','game/content/track_definition.gd','game/content/car_definition.gd']
        for relative in required: self.assertIn(relative,source['files'])
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for relative in source['files']:
                path = root/relative
                path.parent.mkdir(parents=True,exist_ok=True)
                path.write_bytes((content_hash.ROOT/relative).read_bytes())
            with patch.object(content_hash,'ROOT',root):
                self.assertEqual(content_hash.compute(),source)
                for relative in required:
                    path = root/relative
                    original = path.read_bytes()
                    path.write_bytes(original+b'\n# Fixture-only contract change\n')
                    self.assertNotEqual(content_hash.compute()['content_hash'],source['content_hash'])
                    path.write_bytes(original)
