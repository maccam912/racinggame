#!/usr/bin/env python3
"""Start a local authoritative worker plus two native clients; Ctrl+C closes all."""
import subprocess
from bootstrap import ROOT, engine

processes = []
try:
    command = [str(engine()), '--path', str(ROOT)]
    processes.append(subprocess.Popen([*command, '--headless', '--', '--server']))
    for _ in range(2):
        processes.append(subprocess.Popen([*command, '--', '--connect=127.0.0.1:27020']))
    for process in processes[1:]:
        process.wait()
except KeyboardInterrupt:
    pass
finally:
    for process in processes:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
