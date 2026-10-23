"""Profiles are part of road geometry, not a visual displacement of the mesh."""
import math
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from bake_tracks import detailed_curve


class RouteDetailTests(unittest.TestCase):
    def test_zero_detail_retains_base_surface_and_nonzero_detail_changes_length(self):
        points=[(math.sin(i*math.tau/400)*200,12,math.cos(i*math.tau/400)*200) for i in range(401)]
        distances=[0.0]
        for a,b in zip(points,points[1:]):distances.append(distances[-1]+math.dist(a,b))
        zero,zero_s=detailed_curve(points,distances,[0]*40)
        outward,outward_s=detailed_curve(points,distances,[10]*40)
        self.assertLess(abs(zero_s[-1]-distances[-1]),.1)
        self.assertGreater(abs(outward_s[-1]-zero_s[-1]),60)
        self.assertEqual(outward[0],outward[-1])
        for point in outward:
            self.assertEqual(point[1],12)
            self.assertAlmostEqual(math.hypot(point[0],point[2]),210,delta=.01)


if __name__=='__main__':unittest.main()
