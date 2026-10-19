import copy
import json
import math
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from validate_content import ROOT, validate


class SchemaTests(unittest.TestCase):
    def setUp(self):
        self.schema = json.loads((ROOT/'schemas/cars.schema.json').read_text())
        self.value = json.loads((ROOT/'game/content/cars.json').read_text())

    def test_valid_content(self):
        validate(self.value,self.schema)

    def test_invalid_shared_parameters(self):
        mutations = [('top_speed',math.nan),('grip',-1),('acceleration','fast'),('turn_factor',3),('default_paint',8)]
        for key,value in mutations:
            changed = copy.deepcopy(self.value)
            changed['cars'][0][key] = value
            with self.assertRaises(ValueError,msg=key):
                validate(changed,self.schema)

    def test_surface_intervals_reject_invalid_schema(self):
        schema = json.loads((ROOT/'schemas/tracks.schema.json').read_text())
        value = json.loads((ROOT/'game/content/tracks.json').read_text())
        for bad in [{'start':-.1,'end':.9,'surface':'sand'}, {'start':.7,'end':1.1,'surface':'sand'}, {'start':.7,'end':.9,'surface':'ice'}, {'start':.7,'surface':'sand'}, {'start':.7,'end':.9,'surface':'sand','hidden_grip':2}]:
            changed = copy.deepcopy(value)
            changed['tracks'][5]['surface_intervals'] = [bad]
            with self.assertRaises(ValueError): validate(changed,schema)

    def test_missing_and_unknown_fields(self):
        del self.value['cars'][0]['grip']
        with self.assertRaises(ValueError):
            validate(self.value,self.schema)
        self.setUp()
        self.value['cars'][0]['hidden_boost'] = 5
        with self.assertRaises(ValueError):
            validate(self.value,self.schema)


if __name__ == '__main__':
    unittest.main()
