#!/usr/bin/env python3
"""Execute the exported native client/server, preserving clear headless evidence."""
import argparse
import json
import os
from pathlib import Path
import platform
import plistlib
import stat
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main(target, artifact):
    folder = ROOT/'build/native-smoke'/target
    folder.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(artifact) as archive:
        archive.extractall(folder)
        for item in archive.infolist():
            permissions = item.external_attr >> 16
            path = folder/item.filename
            if path.is_file() and permissions:
                path.chmod(permissions)
    if target == 'macos':
        app = next(folder.glob('*.app'))
        info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
        binary = app/'Contents/MacOS'/info['CFBundleExecutable']
    elif target == 'windows':
        binary = folder/'pacific-rush.exe'
    else:
        binary = folder/('pacific-rush-server.x86_64' if target == 'server' else 'pacific-rush.x86_64')
    if platform.system() != 'Windows':
        binary.chmod(binary.stat().st_mode|stat.S_IXUSR)
    command = [str(binary),'--headless','--quit-after','30']
    if target != 'server':
        command += ['--','--drive']
    probe = subprocess.run([str(binary),'--headless','--','--platform-probe'],cwd=folder,capture_output=True,text=True,timeout=30)
    probe_output = probe.stdout+probe.stderr
    result = subprocess.run(command,cwd=folder,capture_output=True,text=True,timeout=30)
    output = result.stdout+result.stderr
    expected = 'PACIFIC_RUSH_SERVER_READY' if target == 'server' else 'PACIFIC_RUSH_DRIVING_READY'
    passed = probe.returncode==0 and 'PACIFIC_PLATFORM_READY' in probe_output and 'ERROR:' not in probe_output and result.returncode == 0 and expected in output and 'ERROR:' not in output and 'SCRIPT ERROR:' not in output
    report = {'target':target,'host':platform.system()+'-'+platform.machine(),'kind':'exported binary headless startup; graphical/device performance not measured', 'passed':passed,'platform_probe':probe_output,'output':output}
    reports = ROOT/'reports'
    reports.mkdir(exist_ok=True)
    (reports/f'native-{target}-{platform.machine()}.json').write_text(json.dumps(report,indent=2)+'\n')
    print(probe_output+output)
    raise SystemExit(0 if passed else 1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('target',choices=['linux','windows','macos','server'])
    parser.add_argument('artifact',type=Path)
    args = parser.parse_args()
    main(args.target,args.artifact)
