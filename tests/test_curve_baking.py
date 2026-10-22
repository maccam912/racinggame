"""Continuity at authored curve joins is a geometry requirement, not a visual guess."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from bake_tracks import bspline

class CurveBakingTests(unittest.TestCase):
    def test_position_tangent_and_curvature_match_at_uneven_joins(self):
        points=[(-70,8,40),(0,12,0),(10,28,-310),(280,82,-410),(340,20,-120)]
        before=points[:4];after=points[1:]
        self.assertEqual(bspline(*before,1),bspline(*after,0))
        # Quadratic tangent and linear second derivative of the cubic basis.
        def tangent(p,t):
            weights=(-3*(1-t)**2,9*t*t-12*t,-9*t*t+6*t+3,3*t*t)
            return tuple(sum(w*v[i] for w,v in zip(weights,p))/6 for i in range(3))
        def second(p,t):
            weights=(6*(1-t),18*t-12,-18*t+6,6*t)
            return tuple(sum(w*v[i] for w,v in zip(weights,p))/6 for i in range(3))
        self.assertEqual(tangent(before,1),tangent(after,0))
        self.assertEqual(second(before,1),second(after,0))
        self.assertGreater(sum(v*v for v in tangent(before,1)),1)

    def test_four_grid_controls_remain_a_true_straight(self):
        points=[(0,12,200),(0,12,100),(0,12,0),(0,12,-100)]
        for step in range(101):
            x,y,z=bspline(*points,step/100)
            self.assertEqual(x,0)
            self.assertAlmostEqual(y,12)
            self.assertAlmostEqual(z,100-step)

if __name__=='__main__': unittest.main()
