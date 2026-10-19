#!/usr/bin/env python3
"""Reproduce pre-art controller videos with an explicit developer input overlay."""
import hashlib
import json
import platform
from pathlib import Path
import shutil
import subprocess
import sys
from bootstrap import ROOT


def main():
    if not shutil.which('ffmpeg'):
        raise RuntimeError('Install ffmpeg to encode the local reference captures')
    reports = ROOT/'reports'
    reports.mkdir(exist_ok=True)
    (reports/'.gdignore').touch()
    movie = reports/'graybox-reference.avi'
    with (reports/'graybox-reference.log').open('w') as log:
        subprocess.run([sys.executable,'tools/godot.py','--fixed-fps','60','--resolution','1280x720',
                        '--write-movie',str(movie),'--script','tests/graybox_reference_capture.gd'],
                       cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
    value = json.loads((reports/'graybox-reference.json').read_text())
    for case in value['cases']:
        output = ROOT/'docs/evidence'/('m1-'+case['id']+'.mp4')
        temporary = output.with_suffix('.tmp.mp4')
        try:
            subprocess.run(['ffmpeg','-nostdin','-y','-loglevel','error','-ss',str(case['start_frame']/60),
                            '-i',str(movie),'-t',str(case['frames']/60),'-an','-c:v','libx264',
                            '-preset','medium','-crf','23','-pix_fmt','yuv420p','-movflags','+faststart',
                            str(temporary)],check=True,timeout=120)
            temporary.replace(output)
        finally:
            temporary.unlink(missing_ok=True)
        case.update(video=output.name,sha256=hashlib.file_digest(output.open('rb'),'sha256').hexdigest(),video_bytes=output.stat().st_size)
    value.update(source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                 working_tree_dirty=bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip()),
                 renderer=('macOS' if platform.system()=='Darwin' else platform.system())+' Godot 4.6.3 Compatibility',
                 camera={'mode':'Near Chase','reduce_motion':True,'base_vertical_fov':65},
                 capture_script_sha256=hashlib.sha256((ROOT/'tests/graybox_reference_capture.gd').read_bytes()).hexdigest(),
                 video_encoding='1280x720, 60 fps, H.264 CRF 23, silent graybox, offline-rendered',
                 encoder=subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0])
    (ROOT/'docs/evidence/m1-driving-references.json').write_text(json.dumps(value,indent=2)+'\n')
    movie.unlink()
    print('Captured nine shared-controller references; '+str(sum(row['video_bytes'] for row in value['cases']))+' encoded bytes')


if __name__ == '__main__':
    main()
