import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT=Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name=='posix','POSIX container wrapper')
class ContainerHostTests(unittest.TestCase):
    def test_restart_keeps_wrapper_alive_and_shutdown_waits_for_child(self):
        with tempfile.TemporaryDirectory(prefix='pacific-host-') as temporary:
            folder=Path(temporary)
            fake=folder/'operator'
            fake.write_text('#!'+sys.executable+'\n'+'''
import os,signal,time
from pathlib import Path
folder=Path(os.environ['PR_HOST_TEST_ROOT'])
stop_at=None
signals=0
def stop(*_):
 global stop_at,signals
 signals+=1
 stop_at=time.monotonic()+1.2 if signals==1 else time.monotonic()
signal.signal(signal.SIGTERM,stop)
(folder/('ready-'+str(os.getpid()))).write_text('ready')
while stop_at is None or time.monotonic()<stop_at:time.sleep(.02)
''')
            fake.chmod(0o700)
            pid_file=folder/'child.pid'
            environment={**os.environ,'PR_DIRECTORY_BINARY':str(fake),'PR_HOST_PID_FILE':str(pid_file),'PR_HOST_TEST_ROOT':str(folder)}
            output=(folder/'wrapper.log').open('w')
            wrapper=subprocess.Popen(['sh',str(ROOT/'services/directory/deploy/container/host.sh'),'serve'],env=environment,stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
            def ready(previous=None):
                deadline=time.monotonic()+6
                while time.monotonic()<deadline:
                    if pid_file.exists():
                        value=pid_file.read_text().strip()
                        if value.isdigit() and value!=previous and (folder/('ready-'+value)).exists():return value
                    self.assertIsNone(wrapper.poll(),'wrapper exited unexpectedly')
                    time.sleep(.02)
                self.fail('owned child did not become ready')
            try:
                first=ready()
                os.kill(int(first),signal.SIGKILL)
                second=ready(first)
                self.assertNotEqual(first,second)
                wrapper.send_signal(signal.SIGTERM)
                time.sleep(.2)
                self.assertIsNone(wrapper.poll(),'wrapper returned before the child completed its drain')
                self.assertEqual(wrapper.wait(timeout=5),0)
                output.flush()
                self.assertIn('directory_restarting',(folder/'wrapper.log').read_text())
                self.assertFalse(pid_file.exists())
            finally:
                # The separate process group contains only this test's wrapper
                # and fake children; no external or recovered host PID is used.
                try:os.killpg(wrapper.pid,signal.SIGTERM)
                except ProcessLookupError:pass
                try:wrapper.wait(timeout=4)
                except subprocess.TimeoutExpired:
                    os.killpg(wrapper.pid,signal.SIGKILL);wrapper.wait()
                output.close()
