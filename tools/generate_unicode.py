#!/usr/bin/env python3
"""Reproduce the vendored NFC subset with the pinned Python Unicode database."""
import json
from pathlib import Path
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
assert unicodedata.unidata_version == '16.0.0', 'Use the pinned Python 3.14.7 Unicode database'
decomposition,combining,composition = {},{},{}
for point in range(0x110000):
    character = chr(point)
    if value := unicodedata.combining(character):
        combining[str(point)] = value
    value = unicodedata.decomposition(character)
    if value and not value.startswith('<'):
        parts = [int(x,16) for x in value.split()]
        decomposition[str(point)] = parts
        if len(parts) == 2 and unicodedata.normalize('NFC',''.join(map(chr,parts))) == character:
            composition[f'{parts[0]}:{parts[1]}'] = point
value = {'unicode_version':unicodedata.unidata_version,'decomposition':decomposition,'combining':combining,'composition':composition}
(ROOT/'game/content/unicode_nfc.json').write_text(json.dumps(value,separators=(',',':'))+'\n')
