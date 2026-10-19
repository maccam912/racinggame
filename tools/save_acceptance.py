#!/usr/bin/env python3
"""Real native process locks, abrupt process death and durable component fixtures."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from bootstrap import ROOT, engine


def run():
    # A native-adapter job starts from a clean checkout with no class/import cache.
    subprocess.run([sys.executable,'tools/godot.py','--headless','--editor','--import','--quit'],cwd=ROOT,check=True)
    report = {'passed':False, 'platform':sys.platform, 'cases':[], 'boundary':'Native barriers and process termination; not an actual power-cut or physical Android storage test. Windows uses file flush/write-through moves; no portable directory-fsync guarantee is claimed.'}
    folder = ROOT/'reports'/'save-acceptance'
    folder.mkdir(parents=True,exist_ok=True)
    command = [str(engine()),'--headless','--path',str(ROOT),'--script','tests/save_lock_probe.gd','--']
    with tempfile.TemporaryDirectory(prefix='pacific-save-') as temporary:
        profile = str(Path(temporary)/'profile café')
        processes = []
        files = []
        def invoke(operation, stage='', wait=True):
            name = operation+('-'+stage if stage else '')
            output = folder/(name+'.log')
            log = output.open('w'); files.append(log)
            process = subprocess.Popen([*command,'--folder='+profile,'--operation='+operation,'--stage='+stage],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
            processes.append(process)
            if wait:
                code = process.wait(timeout=30)
                text = output.read_text()
                assert code==0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text,(name,text)
                report['cases'].append(name)
            else:
                deadline = time.monotonic()+15
                marker = 'NATIVE_PROFILE_LOCK_HELD' if operation=='hold' else 'NATIVE_INTERRUPTED_WRITE_READY'
                while marker not in output.read_text():
                    if process.poll() is not None or time.monotonic()>deadline: raise RuntimeError(name+' failed: '+output.read_text())
                    time.sleep(.05)
            return process
        try:
            holder = invoke('hold',wait=False)
            invoke('busy')
            holder.kill(); holder.wait(timeout=5)
            invoke('after_kill')
            for stage in ['sync_file','sync_directory','after_tmp','after_backup','before_replace']:
                interrupted = invoke('interrupted',stage,wait=False)
                interrupted.kill(); interrupted.wait(timeout=5)
                invoke('verify_interrupted',stage)
            for stage in ['after_delete_marker','after_delete_primary']:
                interrupted = invoke('interrupted_delete',stage,wait=False)
                interrupted.kill(); interrupted.wait(timeout=5)
                invoke('verify_deleted',stage)
        finally:
            for process in processes:
                if process.poll() is None:
                    process.kill(); process.wait(timeout=5)
            for file in files: file.close()
    subprocess.run([sys.executable,'tools/godot.py','--headless','--fixed-fps','60','--script','tests/durable_save_tests.gd'],cwd=ROOT,check=True)
    report['passed'] = True
    (folder/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2),flush=True)
    return report

if __name__=='__main__': run()
