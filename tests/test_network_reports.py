"""Failure evidence and ownership checks without launching a real worker."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import network_integration as fixture


class Process:
    def __init__(self, code=None):
        self.returncode=code
        self.terminated=False

    def poll(self): return self.returncode
    def terminate(self): self.terminated=True; self.returncode=-15
    def kill(self): self.returncode=-9
    def wait(self,timeout=None): return self.returncode


class NetworkReports(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name)
        content=self.root/'game/content';content.mkdir(parents=True)
        self.manifest={'schema_version':1,'content_hash':'a'*64,'files':{}}
        (content/'compatibility.json').write_text(json.dumps(self.manifest))
        (content/'rules.json').write_text(json.dumps({'protocol_version':5}))
        for name,value in [('ROOT',self.root),('engine',lambda:Path('/unused-engine')),('gameplay_manifest',lambda:self.manifest)]:
            patcher=patch.object(fixture,name,value);patcher.start();self.addCleanup(patcher.stop)

    def summaries(self): return sorted((self.root/'reports').glob('*/summary.json'))

    def test_startup_failures_keep_independent_immutable_reports(self):
        with patch.object(fixture.subprocess,'Popen',return_value=Process(17)):
            with self.assertRaisesRegex(RuntimeError,'Worker failed to start'): fixture.run(seconds=1)
            first=self.summaries()[0];original=first.read_bytes()
            with self.assertRaisesRegex(RuntimeError,'Worker failed to start'): fixture.run(seconds=1)
        self.assertEqual(len(self.summaries()),2)
        self.assertEqual(first.read_bytes(),original)
        result=json.loads(original)
        self.assertFalse(result['passed'])
        self.assertEqual(result['content_hash'],'a'*64)
        self.assertIn('Worker failed to start',result['failure'])
        self.assertEqual(result['clients'],[])

    def test_stale_gameplay_identity_is_reported_before_launch(self):
        (self.root/'game/content/compatibility.json').write_text(json.dumps({'content_hash':'b'*64}))
        with patch.object(fixture.subprocess,'Popen') as launch:
            with self.assertRaisesRegex(AssertionError,'manifest must be current'): fixture.run(seconds=1)
        launch.assert_not_called()
        result=json.loads(self.summaries()[0].read_text())
        self.assertFalse(result['passed'])
        self.assertIn('manifest must be current',result['failure'])

    def test_timeout_stops_only_spawned_processes_and_records_failure(self):
        processes=[]
        def launch(command,stdout,stderr):
            if '--script' not in command:
                stdout.write('PACIFIC_RUSH_SERVER_READY\n');stdout.flush()
            process=Process();processes.append(process);return process
        with patch.object(fixture.subprocess,'Popen',side_effect=launch), patch.object(fixture.time,'monotonic',side_effect=[0,0,0,99,99]):
            with self.assertRaisesRegex(RuntimeError,'Network integration timeout'): fixture.run(seconds=1)
        self.assertEqual(len(processes),3)
        self.assertTrue(all(process.terminated for process in processes))
        result=json.loads(self.summaries()[0].read_text())
        self.assertFalse(result['passed'])
        self.assertIn('timeout',result['failure'])
        self.assertEqual(result['cleanup_errors'],[])

    def test_partial_client_json_is_preserved_without_hiding_original_error(self):
        def launch(command,stdout,stderr):
            if '--script' not in command:
                stdout.write('PACIFIC_RUSH_SERVER_READY\n');stdout.flush()
            else:
                report=Path(next(arg.split('=',1)[1] for arg in command if arg.startswith('--report=')))
                report.write_text('{')
            return Process(0)
        with patch.object(fixture.subprocess,'Popen',side_effect=launch):
            with self.assertRaises(json.JSONDecodeError): fixture.run(seconds=1)
        result=json.loads(self.summaries()[0].read_text())
        self.assertFalse(result['passed'])
        self.assertIn('JSONDecodeError',result['failure'])
        self.assertEqual(len(result['client_report_errors']),2)
        for path in self.summaries()[0].parent.glob('client*.json'): self.assertEqual(path.read_text(),'{')


if __name__=='__main__': unittest.main()
