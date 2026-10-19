#!/usr/bin/env python3
"""Run the pinned engine and fail on GDScript/import errors even if Godot exits 0."""
import subprocess
import sys
from bootstrap import ROOT, engine

if __name__ == '__main__':
    command = [str(engine()), '--path', str(ROOT), *sys.argv[1:]]
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print(result.stdout, end='')
    failed = any(marker in result.stdout for marker in ('SCRIPT ERROR:', 'Parse Error:', 'ERROR:', 'TEST FAIL'))
    raise SystemExit(result.returncode or int(failed))
