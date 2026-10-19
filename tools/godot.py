#!/usr/bin/env python3
"""Run the pinned engine; stream diagnostics and stop on script/import failures."""
import subprocess
import sys
from bootstrap import ROOT, engine

if __name__ == '__main__':
    command = [str(engine()), '--path', str(ROOT), *sys.argv[1:]]
    failed = False
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        for line in process.stdout:
            print(line, end='', flush=True)
            if any(marker in line for marker in ('SCRIPT ERROR:', 'Parse Error:', 'ERROR:', 'TEST FAIL')):
                failed = True
                process.terminate()
        code = process.wait(timeout=5)
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
    raise SystemExit(code or int(failed))
