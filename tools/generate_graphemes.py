#!/usr/bin/env python3
"""Reproduce Unicode 16 extended-grapheme tables and official boundary cases."""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request
from bootstrap import ROOT

BASE = 'https://www.unicode.org/Public/16.0.0/ucd/'
FILES = {
    'auxiliary/GraphemeBreakProperty.txt': 'c29360bd6f7132811d701d29069541e827eb44bfc4c8fbde8c370d6982689dc1',
    'emoji/emoji-data.txt': 'f1365a5173eee18e1f98b240cdc492e84a25f1ce7e0c9d1094eb29c41a22696a',
    'DerivedCoreProperties.txt': '39d35161f2954497f69e08bdb9e701493f476a3d30222de20028feda36c1dabd',
    'auxiliary/GraphemeBreakTest.txt': 'ee2b9354d270ac061b29f09662cafea06341d77e704b8cc6bd72aaeeda363cb5',
}
GCB = ['Other', 'CR', 'LF', 'Control', 'Extend', 'ZWJ', 'Regional_Indicator', 'Prepend', 'SpacingMark', 'L', 'V', 'T', 'LV', 'LVT']
INCB = ['None', 'Consonant', 'Linker', 'Extend']


def source(part):
    path = ROOT/'build/unicode16'/Path(part).name
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        data = urllib.request.urlopen(BASE+part, timeout=30).read()
        assert hashlib.sha256(data).hexdigest() == FILES[part], part
        path.write_bytes(data)
    data = path.read_bytes()
    assert hashlib.sha256(data).hexdigest() == FILES[part], part
    return data.decode('utf-8')


def properties(text, choose):
    rows = []
    for line in text.splitlines():
        body = line.split('#', 1)[0].strip()
        if not body:
            continue
        fields = [value.strip() for value in body.split(';')]
        value = choose(fields)
        if value is None:
            continue
        limits = fields[0].split('..')
        rows.append([int(limits[0], 16), int(limits[-1], 16), value])
    merged = []
    for low, high, value in sorted(rows):
        assert 0 <= low <= high <= 0x10ffff
        if merged:
            assert low > merged[-1][1]
        if merged and low == merged[-1][1]+1 and value == merged[-1][2]:
            merged[-1][1] = high
        else:
            merged.append([low, high, value])
    return merged


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    sources = {part: source(part) for part in FILES}
    provenance = {'unicode_version': '16.0.0', 'source_sha256': {BASE+part: value for part, value in FILES.items()}, 'license': 'assets/licenses/Unicode-LICENSE.txt'}
    table = {**provenance,
             'gcb': properties(sources['auxiliary/GraphemeBreakProperty.txt'], lambda f: GCB.index(f[1]) if f[1] not in ['LV', 'LVT'] else None),
             'pictographic': properties(sources['emoji/emoji-data.txt'], lambda f: 1 if f[1] == 'Extended_Pictographic' else None),
             'incb': properties(sources['DerivedCoreProperties.txt'], lambda f: INCB.index(f[2]) if f[1] == 'InCB' else None)}
    cases = []
    for line in sources['auxiliary/GraphemeBreakTest.txt'].splitlines():
        body = line.split('#', 1)[0].strip()
        if not body:
            continue
        points, breaks = [], []
        for token in body.split():
            if token == '÷':
                breaks.append(len(points))
            elif token != '×':
                points.append(int(token, 16))
        assert breaks[0] == 0 and breaks[-1] == len(points)
        cases.append({'points': points, 'breaks': breaks})
    for relative, data in [('game/content/unicode_graphemes.json', table), ('tests/fixtures/grapheme_break_16.json', {**provenance, 'cases': cases})]:
        path = ROOT/relative
        encoded = json.dumps(data, separators=(',', ':'))+'\n'
        if args.check:
            assert path.read_text() == encoded, 'Stale generated Unicode data: '+relative
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(encoded)
    print(json.dumps({'unicode': '16.0.0', 'official_cases': len(cases), 'gcb_ranges': len(table['gcb']), 'incb_ranges': len(table['incb'])}))


if __name__ == '__main__':
    main()
