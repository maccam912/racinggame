"""Import human-authored CC0 rock/metal recordings; no procedural composition.

Original downloads and license-page snapshots are retained in source/music.
Only gain normalization, a short circular seam and Vorbis encoding are applied.
Run with --download once; normal rebuilds use the retained source recordings.
"""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess
import urllib.request
import numpy as np
from generate_audio import export, MANIFEST, OUT, RATE, ROOT, WORK

SOURCE = ROOT/'assets/source/music'
RAGNAR = 'https://opengameart.org/content/rock-music-pack'
FILES = 'https://opengameart.org/sites/default/files/'
RECORDINGS = [
    ('palm_bay', 'Downtown Destruction', 'Ragnar Random', RAGNAR, '07_-_downtown_destruction.ogg'),
    ('citrus_pass', 'Hammer of the Berserker', 'Ragnar Random', RAGNAR, '03_-_hammer_of_the_berserker.ogg'),
    ('marina_lights', 'Artificial Devil', 'Ragnar Random', RAGNAR, '04_-_artificial_devil.ogg'),
    ('redwood_run', 'Once More [Metal]', 'nene', 'https://opengameart.org/content/once-more-metal', 'once_more_metal.wav'),
    ('sunstone_canyon', 'Plutonian Thrash', 'Ragnar Random', RAGNAR, '05_-_plutonian_thrash.ogg'),
    ('pacific_summit', 'Fight for Better Future [Rock/Metal]', 'nene', 'https://opengameart.org/content/fight-for-better-future-rockmetal', 'fight_for_better_future.wav'),
    ('menu', 'Cheap Speed Think Fast', 'Ragnar Random', RAGNAR, '29_-_cheap_speed_think_fast.ogg'),
]


def fetch(row):
    identifier, title, creator, page, filename = row
    url = FILES+filename
    target = SOURCE/filename
    if not target.exists():
        with urllib.request.urlopen(url, timeout=60) as response:
            target.write_bytes(response.read())
    snapshot = SOURCE/(page.rsplit('/',1)[-1]+'.html')
    if not snapshot.exists():
        with urllib.request.urlopen(page, timeout=60) as response:
            snapshot.write_bytes(response.read())
    assert 'publicdomain/zero/1.0' in snapshot.read_text(), 'Source must explicitly link CC0'
    return {'id':'music_'+identifier,'title':title,'creator':creator,'license':'CC0-1.0',
            'license_url':'https://creativecommons.org/publicdomain/zero/1.0/',
            'source_url':page,'download_url':url,'source_path':target.relative_to(ROOT).as_posix(),
            'source_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
            'license_evidence':snapshot.relative_to(ROOT).as_posix()}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--download',action='store_true')
    args=parser.parse_args()
    SOURCE.mkdir(parents=True,exist_ok=True)
    OUT.mkdir(parents=True,exist_ok=True)
    WORK.mkdir(parents=True,exist_ok=True)
    manifest=SOURCE/'cc0-sources.json'
    if args.download:
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            rows=list(pool.map(fetch,RECORDINGS))
        manifest.write_text(json.dumps({'schema_version':1,'recordings':rows},indent=2)+'\n')
    rows=json.loads(manifest.read_text())['recordings']
    for row in rows:
        source=ROOT/row['source_path']
        assert hashlib.sha256(source.read_bytes()).hexdigest()==row['source_sha256']
        raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(source),'-ar',str(RATE),'-ac','2','-f','f32le','-'])
        signal=np.frombuffer(raw,dtype='<f4').reshape(-1,2).copy()
        # Overlap the original end with its original opening. No pitch, tempo
        # or arrangement change, and no silent gap when the game loops it.
        seam=round(.025*RATE)
        blend=np.linspace(0,1,seam,dtype=np.float32)[:,None]
        signal[-seam:]=signal[-seam:]*(1-blend)+signal[:seam]*blend
        signal=signal[seam:]
        details={**row,'loop':True,'bpm':0,'beats':0,'bars':0,'style':'recorded_rock_metal',
                 'processing':'25 ms circular seam, R128 gain normalization and Vorbis encoding; original tempo and arrangement'}
        export(row['id'],signal,'music',details,-18,-3)
    catalog=OUT/'catalog.json'
    value=json.loads(catalog.read_text())
    value['license']='MIT AND CC0-1.0'
    value['music_source']='assets/source/import_cc0_music.py'
    ids={row['id'] for row in MANIFEST}
    value['assets']=sorted([row for row in value['assets'] if row['id'] not in ids]+MANIFEST,key=lambda row:row['id'])
    catalog.write_text(json.dumps(value,indent=2)+'\n')
    print('RECORDED_CC0_ROCK_METAL_IMPORTED',len(rows))


if __name__=='__main__': main()
