#!/usr/bin/env python3
"""Run the pinned engine; stream diagnostics and stop on script/import failures."""
import subprocess
import sys
from bootstrap import ROOT, engine

if __name__ == '__main__':
    arguments = sys.argv[1:]
    if (ROOT/'native/pacific_platform.gdextension').exists() and all(flag in arguments for flag in ['--editor','--import','--quit']):
        # Godot #111048: first GDExtension discovery queues documentation work
        # after immediate import shutdown has destroyed its DocTools instance.
        # Let the editor run its deferred work before orderly shutdown.
        arguments = [arg for arg in arguments if arg not in ['--import','--quit']]
        arguments += ['--quit-after','180','--max-fps','60']
    command = [str(engine()), '--path', str(ROOT), *arguments]
    failed = False
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        for line in process.stdout:
            print(line, end='', flush=True)
            if any(marker in line for marker in ('SCRIPT ERROR:', 'Parse Error:', 'ERROR:', 'TEST FAIL', 'Unicode parsing error')):
                failed = True
                process.terminate()
        code = process.wait(timeout=5)
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
    raise SystemExit(code or int(failed))
