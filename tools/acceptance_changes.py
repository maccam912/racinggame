#!/usr/bin/env python3
"""Compare acceptance inputs with the last gated development tag, including failed pushes."""
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
AI_INPUTS = ['game/content/compatibility.json','tests/bot_tracks.gd','tools/bot_acceptance.py']
SOAK_INPUTS = ['game/content/compatibility.json','game/net','game/server','native/iroh','native/pacific_iroh.gdextension.in','tools/iroh_build.py','tests/soak_network_client.gd',
               'tests/lobby_network_client.gd','tools/soak_acceptance.py','tools/toolchain.lock','tools/acceptance_changes.py']


def detect(root=ROOT, remote='origin'):
    def git(*args):
        return subprocess.check_output(['git',*args],cwd=root,text=True).strip()
    tags = []
    for line in git('ls-remote','--tags','--refs',remote).splitlines():
        ref = line.split()[-1]
        match = re.fullmatch(r'refs/tags/v0\.0\.([0-9]+)-dev',ref)
        if match: tags.append((int(match.group(1)),ref))
    result = {'baseline_tag':None,'baseline_commit':None,'gameplay_changed':True,'soak_changed':True}
    if not tags: return result
    ref = max(tags)[1]
    subprocess.run(['git','fetch','--no-tags','--depth=1',remote,ref],cwd=root,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    baseline = git('rev-parse','FETCH_HEAD^{commit}')
    result.update(baseline_tag=ref.removeprefix('refs/tags/'),baseline_commit=baseline)
    for key,paths in [('gameplay_changed',AI_INPUTS),('soak_changed',SOAK_INPUTS)]:
        status = subprocess.run(['git','diff','--quiet',baseline,'HEAD','--',*paths],cwd=root).returncode
        if status not in (0,1): raise RuntimeError('Cannot compare acceptance inputs')
        result[key] = status==1
    return result


if __name__=='__main__':
    result = detect()
    print(json.dumps(result))
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'],'a') as output:
            output.write('changed='+str(result['gameplay_changed']).lower()+'\n')
            output.write('soak_changed='+str(result['soak_changed']).lower()+'\n')
