from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from mixed_android_acceptance import android_memory_summary


class AndroidMemoryReport(unittest.TestCase):
    def observations(self, peak=420000000, end=390000000):
        return [{'elapsed':t,'rss_bytes':value} for t,value in [(2,300000000),(300,400000000),(700,peak),(901,end)]]

    def test_actual_routes_laps_and_exact_five_percent_boundary(self):
        stats,checks=android_memory_summary(self.observations(),['spillway_sprint','caldera_crosscut'],1,True)
        self.assertTrue(all(checks.values()))
        self.assertEqual(stats['repeated_cycle_peak_rss_bytes'],420000000)
        self.assertIn('spillway_sprint, caldera_crosscut 1-lap',stats['boundary'])
        self.assertNotIn('Palm Bay',stats['boundary'])

    def test_peak_growth_cannot_be_hidden_by_a_lower_endpoint(self):
        stats,checks=android_memory_summary(self.observations(440000000),['redwood_run'],2,True)
        self.assertFalse(checks['cycle_peak_growth_at_most_5_percent'])
        self.assertLess(stats['observations'][-1]['rss_bytes'],stats['warmup_peak_rss_bytes'])

    def test_missing_window_and_unobserved_warmup_fail_required_acceptance(self):
        for samples in [[],self.observations()[:-1],self.observations()[2:]]:
            with self.subTest(samples=samples):
                stats,checks=android_memory_summary(samples,['palm_bay'],3,True)
                self.assertFalse(stats['measured_5_to_15_minutes'])
                self.assertFalse(all(checks.values()))

    def test_peak_cap_covers_samples_after_the_growth_window_and_stays_optional(self):
        samples=self.observations()+[{'elapsed':1100,'rss_bytes':1000000001}]
        stats,checks=android_memory_summary(samples,['citrus_pass'],3,True)
        self.assertTrue(checks['cycle_peak_growth_at_most_5_percent'])
        self.assertFalse(checks['rss_peak_under_1GB'])
        _,optional=android_memory_summary(samples,['citrus_pass'],3)
        self.assertIsNone(optional)


if __name__=='__main__':unittest.main()
