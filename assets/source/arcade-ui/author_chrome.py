"""Original scalable Pacific Rush arcade chrome. Run from any directory."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'assets/exported/arcade_ui'
OUT.mkdir(exist_ok=True)


def frame(kind, top, middle, bottom, edge, height=72):
    h = height
    outline = f'M12 1H245L255 11V{h-13}L243 {h-1}H1V13Z'
    inner = f'M15 7H241L249 15V{h-16}L240 {h-7}H7V16Z'
    checks = ''.join(f'<path d="M{x} {y}h4v4h-4Z" fill="{color}"/>'
                     for x in (9,13) for y in range(18,h-17,4)
                     for color in [('#f9f4dc' if (x//4+y//4)%2 else '#101139')])
    if kind=='panel':
        checks = ''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="{h}" viewBox="0 0 256 {h}">
<defs>
 <linearGradient id="metal" x1="0" y1="0" x2="0" y2="1"><stop stop-color="{top}"/><stop offset=".36" stop-color="{middle}"/><stop offset=".40" stop-color="{bottom}"/><stop offset="1" stop-color="{middle}"/></linearGradient>
 <linearGradient id="shine" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#fff" stop-opacity=".6"/><stop offset="1" stop-color="#dffaff" stop-opacity=".03"/></linearGradient>
</defs>
<path d="{outline}" fill="{edge}" stroke="#090923" stroke-width="2"/>
<path d="M14 3H244L252 12M4 {h-4}H241L252 {h-15}" fill="none" stroke="#fff5c9" stroke-width="2"/>
<path d="{inner}" fill="url(#metal)" stroke="#0c0739" stroke-width="2"/>
<path d="M16 9H239L247 17V{round(h*.35)}H8V18Z" fill="url(#shine)"/>
<path d="M20 11H236M21 {h-11}H237" fill="none" stroke="#b4dcff" stroke-opacity=".7"/>
{checks}
<path d="M243 22V{h-23}" fill="none" stroke="#ed2eab" stroke-width="3"/>
</svg>'''


assets = {
    'button':frame('button','#577eff','#2537a0','#120f63','#ef9c20'),
    'hover':frame('hover','#bf53ef','#5b167a','#341566','#ffdd30'),
    'pressed':frame('pressed','#253598','#323c9e','#100b47','#f735a2'),
    'disabled':frame('disabled','#30384c','#252c43','#171e32','#717d98'),
    'panel':frame('panel','#3c3b89','#201e57','#130e3b','#6d78ab',128),
    'focus':'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="72" viewBox="0 0 256 72"><path d="M10 2H246L254 10V62L246 70H10L2 62V10Z" fill="none" stroke="#ffe864" stroke-width="4"/><path d="M15 7H241M15 65H241" fill="none" stroke="#fff8ce" stroke-width="1"/></svg>''',
}
checks = ''.join(f'<path d="M{x} {y}h48v48h-48Z"/>' for x in range(0,1280,48)
                 for y in range(0,720,48) if (x//48+y//48)%2==0)
dots = ''.join(f'<circle cx="{x}" cy="{y}" r="2"/>' for x in range(12,1280,18)
               for y in range(12,720,18))
assets['backdrop'] = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720" viewBox="0 0 1280 720">
<defs><linearGradient id="sky" x2=".8" y2="1"><stop stop-color="#0c0e44"/><stop offset=".5" stop-color="#29216b"/><stop offset="1" stop-color="#0a194d"/></linearGradient><linearGradient id="slash"><stop stop-color="#f831a3"/><stop offset=".5" stop-color="#6942e9"/><stop offset="1" stop-color="#27c9f7"/></linearGradient></defs>
<path fill="url(#sky)" d="M0 0H1280V720H0Z"/>
<g fill="#3a69be" opacity=".12" transform="translate(220,-100) rotate(17)">{checks}</g>
<g fill="#e450f5" opacity=".10">{dots}</g>
<path d="M0 450L1280 40V104L0 514ZM0 533L1280 123V137L0 547Z" fill="url(#slash)" opacity=".48"/>
<path d="M0 716L800 0H861L58 720ZM1020 720L1280 486V532L1070 720Z" fill="#2071dd" opacity=".26"/>
<path d="M0 0H1280V7H0ZM0 711H1280V720H0Z" fill="#ec9e21"/>
<path d="M0 9H1280M0 708H1280" stroke="#f63c9b" stroke-width="3"/>
<path d="M1100 30L1090 75L1130 65L1075 150L1091 92L1050 111Z" fill="#ffca3e" opacity=".45"/>
</svg>'''

rows = []
for name, svg in assets.items():
    path = OUT/(name+'.svg')
    path.write_text(svg+'\n')
    rows.append({'id':name,'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(OUT/'catalog.json').write_text(json.dumps({'license':'MIT','source':'assets/source/arcade-ui/author_chrome.py','assets':rows},indent=2)+'\n')
print('Authored seven original scalable chrome/backdrop assets')
