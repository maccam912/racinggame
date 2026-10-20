# /// script
# dependencies = ["fonttools==4.67.0"]
# ///
"""Build the original Pacific Rush display face. Run with uv run author_font.py.

Hand-authored seven-row letterforms are traced into continuous outlines,
chamfered, and sheared forward. No third-party font outlines are inputs.
Body text deliberately uses a separate, more legible family.
"""
import hashlib
import json
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

ROOT = Path(__file__).resolve().parents[3]
PATTERNS = {
    'A': '.###./##.##/##.##/#####/##.##/##.##/##.##',
    'B': '####./##.##/##.##/####./##.##/##.##/####.',
    'C': '.####/##.../##.../##.../##.../##.../.####',
    'D': '####./##.##/##.##/##.##/##.##/##.##/####.',
    'E': '#####/##.../##.../####./##.../##.../#####',
    'F': '#####/##.../##.../####./##.../##.../##...',
    'G': '.####/##.../##.../##.##/##.##/##.##/.####',
    'H': '##.##/##.##/##.##/#####/##.##/##.##/##.##',
    'I': '###/.#./.#./.#./.#./.#./###',
    'J': '..###/...##/...##/...##/##.##/##.##/.###.',
    'K': '##.##/##.##/####./###../####./##.##/##.##',
    'L': '##.../##.../##.../##.../##.../##.../#####',
    'M': '##...##/###.###/#######/##.#.##/##...##/##...##/##...##',
    'N': '##..##/###.##/######/######/##.###/##..##/##..##',
    'O': '.###./##.##/##.##/##.##/##.##/##.##/.###.',
    'P': '####./##.##/##.##/####./##.../##.../##...',
    'Q': '.###../##.##./##.##./##.##./##.##./##.##./.#####',
    'R': '####./##.##/##.##/####./####./##.##/##.##',
    'S': '.####/##.../##.../.###./...##/...##/####.',
    'T': '#####/.###./..#../..#../..#../..#../..#..',
    'U': '##.##/##.##/##.##/##.##/##.##/##.##/.###.',
    'V': '##.##/##.##/##.##/##.##/##.##/.###./..#..',
    'W': '##...##/##...##/##...##/##.#.##/#######/###.###/##...##',
    'X': '##.##/##.##/.###./..#../.###./##.##/##.##',
    'Y': '##.##/##.##/.###./..#../..#../..#../..#..',
    'Z': '#####/...##/..##./.###./.##../##.../#####',
    '0': '.###./##.##/##.##/##.##/##.##/##.##/.###.',
    '1': '.##./###./.##./.##./.##./.##./####',
    '2': '####./...##/...##/.###./##.../##.../#####',
    '3': '####./...##/...##/.###./...##/...##/####.',
    '4': '##.##/##.##/##.##/#####/...##/...##/...##',
    '5': '#####/##.../##.../####./...##/...##/####.',
    '6': '.####/##.../##.../####./##.##/##.##/.###.',
    '7': '#####/...##/...##/..##./..##./.##../.##..',
    '8': '.###./##.##/##.##/.###./##.##/##.##/.###.',
    '9': '.###./##.##/##.##/.####/...##/...##/####.',
    '.': '.. /.. /.. /.. /.. /## /## ',
    ',': '.. /.. /.. /.. /.. /.# /#. ',
    ':': '.. /## /## /.. /## /## /.. ',
    ';': '.. /## /## /.. /## /.# /#. ',
    '!': '##/##/##/##/##/../##',
    '?': '####./...##/...##/..##./..##./...../..##.',
    '-': '...../...../...../#####/...../...../.....',
    '+': '...../..#../..#../#####/..#../..#../.....',
    '/': '....#/...##/...#./..#../.#.../##.../#....',
    '\\': '#..../##.../.#.../..#../...#./...##/....#',
    '(': '..##/.##./##../##../##../.##./..##',
    ')': '##../.##./..##/..##/..##/.##./##..',
    '[': '###/##./##./##./##./##./###',
    ']': '###/.##/.##/.##/.##/.##/###',
    '=': '...../...../#####/...../#####/...../.....',
    '_': '...../...../...../...../...../...../#####',
    "'": '##/##/#./../../../../..',
    '"': '#.#/#.#/................../.../.../.../...',
    '%': '##..#/##.##/...#./..#../.#.../##.##/#..##',
    '#': '.#.#./#####/.#.#./.#.#./#####/.#.#./.....',
    '&': '.###./##.##/##.../.###./##.##/##.##/.####',
    '*': '...../#.#.#/.###./#####/.###./#.#.#/.....',
    '<': '...##/..##./.##../##.../.##../..##./...##',
    '>': '##.../.##../..##./...##/..##./.##../##...',
    '|': '#/#/#/#/#/#/#',
    '@': '.####/##..##/##.###/##.#.#/##.###/##..../.#####',
    '$': '..#../.####/##.#./.###./.#.##/####./..#..',
    '^': '..#../.###./##.##/...../...../...../.....',
    '`': '##/.#/../../../../../..',
    '{': '..##/.##./.##./##.../.##./.##./..##',
    '}': '##.../.##../.##../..##./.##../.##../##...',
    '~': '....../....../.##..#/##.##./#..##./....../......',
}
# Punctuation widths are explicit; trailing spaces never create ink.
PATTERNS['.'] = '../.. /.. /.. /.. /##/##'.replace(' ', '')
PATTERNS['"'] = '#.#/#.#/.../.../.../.../...'


def outlines(pattern):
    """Cancel shared cell edges, trace every boundary, then clip its corners."""
    rows = pattern.split('/')
    edges = set()
    for y, row in enumerate(rows):
        for x, pixel in enumerate(row):
            if pixel != '#':
                continue
            points = [(x, 7-y), (x+1, 7-y), (x+1, 6-y), (x, 6-y)]
            for a, b in zip(points, points[1:] + points[:1]):
                if (b, a) in edges:
                    edges.remove((b, a))
                else:
                    edges.add((a, b))
    contours = []
    while edges:
        edge = min(edges)
        start = edge[0]
        contour = [start]
        while True:
            edges.remove(edge)
            point = edge[1]
            if point == start:
                break
            contour.append(point)
            candidates = [e for e in edges if e[0] == point]
            assert candidates, (pattern, point)
            # Keep diagonal-touching islands separate: follow the right turn.
            dx, dy = point[0]-edge[0][0], point[1]-edge[0][1]
            edge = min(candidates, key=lambda e: (
                -(dx*(e[1][1]-point[1])-dy*(e[1][0]-point[0])), e))
        corners = []
        for i, point in enumerate(contour):
            before, after = contour[i-1], contour[(i+1) % len(contour)]
            if (point[0]-before[0], point[1]-before[1]) == (after[0]-point[0], after[1]-point[1]):
                continue
            corners.append(point)
        clipped = []
        for i, p in enumerate(corners):
            for q in (corners[i-1], corners[(i+1) % len(corners)]):
                distance = abs(q[0]-p[0])+abs(q[1]-p[1])
                x = p[0]+(q[0]-p[0])*.17/distance
                y = p[1]+(q[1]-p[1])*.17/distance
                clipped.append((round(22+x*82+y*17), round(y*100)))
        contours.append(clipped)
    return contours, max(map(len, rows))*82+158


glyphs, metrics, cmap = {}, {}, {}
for char, pattern in PATTERNS.items():
    name = 'uni%04X' % ord(char)
    contours, advance = outlines(pattern)
    pen = TTGlyphPen(None)
    for contour in contours:
        pen.moveTo(contour[0])
        for p in contour[1:]:
            pen.lineTo(p)
        pen.closePath()
    glyphs[name] = pen.glyph()
    metrics[name] = (advance, 22)
    cmap[ord(char)] = name
    if char.isupper():
        cmap[ord(char.lower())] = name
pen = TTGlyphPen(None)
glyphs['space'] = pen.glyph()
metrics['space'] = (270, 0)
cmap[32] = 'space'
glyphs['.notdef'] = glyphs['uni003F']
metrics['.notdef'] = metrics['uni003F']
for digit in '0123456789':
    name = 'uni%04X' % ord(digit)
    metrics[name] = (568, metrics[name][1])
font = FontBuilder(1000, isTTF=True)
font.setupGlyphOrder(['.notdef', 'space'] + [n for n in glyphs if n not in ('.notdef', 'space')])
font.setupCharacterMap(cmap)
font.setupGlyf(glyphs)
font.setupHorizontalMetrics(metrics)
font.setupHorizontalHeader(ascent=790, descent=-150, lineGap=60)
font.setupNameTable({
    'familyName': 'Pacific Rush Display', 'styleName': 'Arcade Italic',
    'uniqueFontIdentifier': 'PacificRushDisplay-1.000',
    'fullName': 'Pacific Rush Display Arcade Italic',
    'psName': 'PacificRushDisplay-ArcadeItalic', 'version': 'Version 1.000',
    'copyright': 'Copyright 2026 Pacific Rush contributors. MIT License.',
    'licenseDescription': 'Original letterforms. MIT License; see repository LICENSE.',
})
font.setupOS2(sTypoAscender=790, sTypoDescender=-150, sTypoLineGap=60,
              usWinAscent=790, usWinDescent=150, sxHeight=700, sCapHeight=700,
              usWeightClass=800, usWidthClass=4, fsSelection=0x21)
font.setupPost(italicAngle=-14)
font.setupMaxp()
font.font.recalcTimestamp = False
font.font['head'].created = font.font['head'].modified = 3875212800
font.font['head'].macStyle = 3
path = ROOT/'assets/fonts/PacificRushDisplay.ttf'
font.save(path)
metadata = {'family': 'Pacific Rush Display', 'license': 'MIT',
            'source': 'assets/source/arcade-ui/author_font.py',
            'generator': 'fonttools 4.67.0', 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'codepoints': sorted(cmap), 'uppercase_forms_for_lowercase': True,
            'boundary': 'Original ASCII display alphabet, numbers and punctuation; body and unsupported scripts use bundled fallback fonts.'}
(Path(__file__).parent/'display-font.json').write_text(json.dumps(metadata, indent=2)+'\n')
print('Authored original Pacific Rush Display: %s glyphs, %s codepoints' % (len(glyphs), len(cmap)))
