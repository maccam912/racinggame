"""Export smaller runtime posters while preserving full-resolution originals."""
import hashlib
import json
from pathlib import Path
import struct
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'assets/source/roadside-posters/generation.json'
OUT = ROOT/'assets/exported/posters'


def main():
    provenance = json.loads(SOURCE.read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    for row in provenance['images']:
        source = ROOT/row['source']
        raw = source.read_bytes()
        assert raw[:8] == b'\x89PNG\r\n\x1a\n'
        width, height = struct.unpack('>II', raw[16:24])
        assert (width, height) == (1536, 1024)
        path = OUT/source.name
        with Image.open(source) as image:
            image.convert('RGB').resize((768,512),Image.Resampling.LANCZOS).save(path,optimize=True)
        rows.append({'id':row['id'], 'title':row['title'], 'source':row['source'],
                     'path':path.relative_to(ROOT).as_posix(), 'pixels':[768,512],
                     'source_pixels':[width,height],'source_sha256':hashlib.sha256(raw).hexdigest(),
                     'sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'size_m':[12,8]})
    value = {'schema_version':1, 'license':'MIT', 'source':SOURCE.relative_to(ROOT).as_posix(),
             'generator':'assets/source/describe_roadside_posters.py', 'assets':rows}
    (OUT/'catalog.json').write_text(json.dumps(value, indent=2)+'\n')
    print('RESIZED_RUNTIME_POSTERS_ORIGINALS_PRESERVED count='+str(len(rows)))


if __name__ == '__main__':
    main()
