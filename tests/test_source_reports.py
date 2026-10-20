"""Real subprocess failures, partial checkpoints and owned timeout cleanup."""
import contextlib
import io
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import check as source_gate


class SourceReports(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def test_failed_process_keeps_full_merged_original_bytes(self):
        command = [sys.executable,'-c',"import sys; sys.stdout.buffer.write(b'BEGIN'+b'x'*9000+b'\\xffTAIL'); sys.stdout.flush(); sys.stderr.write('STDERR_RETAINED\\n'); sys.exit(7)"]
        path = self.root/'output.log'
        row = source_gate.run_check(command,path)
        self.assertFalse(row['passed'])
        self.assertEqual(row['exit_code'],7)
        self.assertIn(b'BEGIN',path.read_bytes())
        self.assertIn(b'\xffTAIL',path.read_bytes())
        self.assertIn(b'STDERR_RETAINED',path.read_bytes())
        self.assertLessEqual(len(row['output']),4000)
        self.assertIn('\ufffdTAIL',row['output'])

    def test_launch_failure_is_saved(self):
        row = source_gate.run_check([str(self.root/'missing-executable')],self.root/'launch.log')
        self.assertFalse(row['passed'])
        self.assertIsNone(row['exit_code'])
        self.assertIn('FileNotFoundError',row['failure'])
        self.assertIn('FileNotFoundError',(self.root/'launch.log').read_text())

    @unittest.skipIf(os.name=='nt','Linux/macOS source gate process-group boundary')
    def test_timeout_kills_an_owned_descendant_that_ignores_term(self):
        pid_file = self.root/'descendant.pid'
        child = "import os,signal,sys,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); open(sys.argv[1],'w').write(str(os.getpid())); print('DESCENDANT_READY',flush=True); time.sleep(30)"
        parent = "import subprocess,sys,time; subprocess.Popen([sys.executable,'-u','-c',sys.argv[1],sys.argv[2]]); print('PARENT_READY',flush=True); time.sleep(30)"
        row = source_gate.run_check([sys.executable,'-u','-c',parent,child,str(pid_file)],self.root/'timeout.log',timeout=2)
        self.assertTrue(row['timed_out'])
        self.assertFalse(row['passed'])
        self.assertEqual(row['termination_scope'],'owned_process_group')
        self.assertIn('DESCENDANT_READY',(self.root/'timeout.log').read_text())
        pid = int(pid_file.read_text())
        def cleanup():
            try: os.kill(pid,signal.SIGKILL)
            except ProcessLookupError: pass
        self.addCleanup(cleanup)
        # A dead descendant may briefly remain as an init-owned zombie. It must
        # never remain a live sleeping process after the runner returns.
        until = time.monotonic()+1
        while True:
            status = subprocess.run(['ps','-p',str(pid),'-o','stat='],capture_output=True,text=True).stdout.strip()
            if not status or status.startswith('Z'): break
            self.assertLess(time.monotonic(),until,'Owned descendant survived timeout cleanup')
            time.sleep(.02)
        self.assertIn('Timed out after 2 seconds',row['output'])

    def test_interrupt_keeps_row_and_stops_its_process(self):
        real_popen = subprocess.Popen
        children = []
        def launch(*args,**kwargs):
            process = real_popen(*args,**kwargs)
            children.append(process)
            real_wait = process.wait
            called = False
            def wait(timeout=None):
                nonlocal called
                if not called:
                    called = True
                    raise KeyboardInterrupt()
                return real_wait(timeout=timeout)
            process.wait = wait
            return process
        with patch.object(source_gate.subprocess,'Popen',side_effect=launch):
            row = source_gate.run_check([sys.executable,'-c','import time; time.sleep(30)'],self.root/'interrupted.log')
        self.assertTrue(row['interrupted'])
        self.assertFalse(row['passed'])
        self.assertIsNotNone(children[0].poll())
        self.assertIn('Interrupted',row['output'])

    def test_partial_report_is_not_green_and_repeat_keeps_old_failure(self):
        partial = "import json,sys; v=json.load(open(sys.argv[1])); assert v['status']=='running' and not v['passed'] and len(v['results'])==1; print('PARTIAL_REPORT_OBSERVED'); sys.exit(9)"
        commands = [[sys.executable,'-c',"print('FIRST_FINISHED')"],
                    [sys.executable,'-c',partial,str(self.root/'checks.json')]]
        with contextlib.redirect_stdout(io.StringIO()):
            first = source_gate.run_checks(commands,self.root)
        self.assertFalse(first['passed'])
        self.assertEqual(first['status'],'complete')
        self.assertIn('PARTIAL_REPORT_OBSERVED',first['results'][1]['output'])
        folder = Path(first['folder'])
        original = {path.name:path.read_bytes() for path in folder.iterdir()}
        with contextlib.redirect_stdout(io.StringIO()):
            second = source_gate.run_checks(commands[:1],self.root)
        self.assertTrue(second['passed'])
        self.assertNotEqual(first['folder'],second['folder'])
        self.assertTrue(json.loads((self.root/'checks.json').read_text())['passed'])
        self.assertEqual(original,{path.name:path.read_bytes() for path in folder.iterdir()})


if __name__=='__main__': unittest.main()
