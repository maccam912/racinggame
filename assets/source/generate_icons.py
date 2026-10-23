"""Original editable SVG icons; canonical course outlines come from shipped bakes."""
from pathlib import Path
import hashlib
import json
from html import escape

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/exported/icons'
GLYPHS={
 'action_boost':'<path d="M13 2L5 14h6l-1 8 9-13h-6z"/>',
 'action_accelerate':'<path d="M7 20V9a5 5 0 0 1 10 0v11zM10 8h4M10 11h4M10 14h4M10 17h4"/>',
 'action_brake':'<path d="M5 20V10a3 3 0 0 1 3-3h8a3 3 0 0 1 3 3v10zM8 11h8M8 14h8M8 17h8"/>',
 'action_steer_left':'<circle cx="12" cy="12" r="9"/><path d="M4 12h16M12 12v8M9 7l-3 3 3 3"/>',
 'action_steer_right':'<circle cx="12" cy="12" r="9"/><path d="M4 12h16M12 12v8M15 7l3 3-3 3"/>',
 'action_handbrake':'<path d="M5 20l6-5 3-10 4 1-3 12-7 3M4 6c3 0 3 4 0 4s-3 4 0 4M21 7v7"/>',
 'action_recover':'<path d="M6 7a8 8 0 1 1-2 8M6 3v6H2"/>',
 'action_camera':'<path d="M3 7h5l2-3h4l2 3h5v13H3z"/><circle cx="12" cy="13" r="4"/>',
 'action_look_back':'<path d="M8 5l-5 5 5 5M3 10h11a6 6 0 0 1 6 6v4M9 17h5"/>',
 'action_pause':'<path d="M8 4v16M16 4v16" stroke-width="4"/>',
 'action_ui_up':'<path d="M5 15l7-7 7 7"/>',
 'action_ui_down':'<path d="M5 9l7 7 7-7"/>',
 'action_ui_left':'<path d="M15 5l-7 7 7 7"/>',
 'action_ui_right':'<path d="M9 5l7 7-7 7"/>',
 'action_ui_accept':'<path d="M4 12l5 5L20 6"/>',
 'action_ui_cancel':'<path d="M10 5l-7 7 7 7M3 12h18"/>',
 'tab_display':'<rect x="3" y="3" width="18" height="13" rx="1"/><path d="M12 16v5M7 21h10"/>',
 'tab_graphics':'<circle cx="12" cy="12" r="4"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M5 19l2-2M17 7l2-2"/>',
 'tab_audio':'<path d="M3 9h4l6-5v16l-6-5H3zM16 8a6 6 0 0 1 0 8M19 5a10 10 0 0 1 0 14"/>',
 'tab_controls':'<path d="M7 7h10c3 0 5 11 3 12-2 1-4-3-5-3H9c-1 0-3 4-5 3C2 18 4 7 7 7zM8 10v5M5.5 12.5h5M16 11h.1M19 14h.1"/>',
 'tab_touch':'<path d="M9 20l-5-6c-1-2 1-3 2-2l2 2V5c0-3 4-3 4 0v6l4-1 4 3-2 7z"/>',
 'tab_accessibility':'<circle cx="12" cy="4" r="2"/><path d="M3 8l9 2 9-2M12 10v5M12 15l-5 7M12 15l5 7"/>',
 'tab_gameplay':'<path d="M5 22V3c6-4 8 5 14 1v10c-6 4-8-5-14-1"/>',
 'tab_data':'<path d="M3 6h7l2 3h9v12H3zM3 6V3h8l2 3h8v3"/>',
 'menu_online':'<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12h18M5 7h14M5 17h14"/>',
 'menu_quick':'<path d="M4 21V3h16v12H4M4 7h16M4 11h16M8 3v12M12 3v12M16 3v12"/>',
 'menu_trial':'<circle cx="12" cy="13" r="8"/><path d="M9 2h6M12 5V2M12 13l4-4M19 5l2 2"/>',
 'menu_cup':'<path d="M7 3h10v7a5 5 0 0 1-10 0zM7 5H3v4c0 3 3 4 5 4M17 5h4v4c0 3-3 4-5 4M12 15v6M7 21h10"/>',
 'menu_school':'<path d="M2 8l10-5 10 5-10 5zM6 10v7c4 4 8 4 12 0v-7M22 8v10"/>',
 'menu_garage':'<path d="M3 21V8l9-6 9 6v13M7 21V10h10v11M7 14h10M7 18h10"/>',
 'menu_settings':'<path d="M3 6h18M3 12h18M3 18h18"/><circle cx="8" cy="6" r="2" fill="#172c40"/><circle cx="16" cy="12" r="2" fill="#172c40"/><circle cx="10" cy="18" r="2" fill="#172c40"/>',
 'menu_credits':'<circle cx="12" cy="12" r="9"/><path d="M12 10v7M12 6v.2"/>',
 'menu_quit':'<path d="M12 2v10M6 5a9 9 0 1 0 12 0"/>',
 'connection_good':'<path d="M4 20v-5M12 20V9M20 20V3" stroke-width="4"/>',
 'connection_caution':'<path d="M4 20v-5M12 20V9" stroke-width="4"/><path d="M18 20V3h4v17z"/>',
 'connection_poor':'<path d="M4 20v-5" stroke-width="4"/><path d="M10 20V9h4v11zM18 20V3h4v17z"/>'}
CARS={
 'comet':'M2 15l2-5 5-3h7l4 5 2 2v4H2z',
 'needle':'M2 16l2-3 8-5h6l4 8v2H2z',
 'switch':'M3 17V9l2-3h11l4 6 1 5z',
 'sunset':'M2 17v-5l4-1 3-4h7l4 5h2v5z',
 'trailblazer':'M2 17V9l2-4h12l4 6h2v6zM5 3h10',
 'corsair':'M1 17v-4l7-5h8l5 5h2v4zM3 9h4',
 'pulse':'M3 17V8l3-3h9l5 7 2 2v3zM15 3l-2 5h4l-2 5',
 'meteor':'M1 17l3-4 9-6h6l3 9v1zM9 4l-2 5h4l-2 5'}

def write(identifier,body,category,details=None):
    title=identifier.replace('_',' ').title()
    text=f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24"><title>{escape(title)}</title><g fill="none" stroke="#F8F4E8" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">{body}</g></svg>\n'
    path=OUT/(identifier+'.svg');path.write_text(text)
    row={'id':identifier,'category':category,'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    if details:row.update(details)
    return row

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    rows=[write(identifier,body,identifier.split('_')[0]) for identifier,body in GLYPHS.items()]
    for identifier,body in CARS.items():
        rows.append(write('car_'+identifier,f'<path d="{body}"/><circle cx="6" cy="17" r="2.5" fill="#172c40"/><circle cx="18" cy="17" r="2.5" fill="#172c40"/>','car'))
    for path in sorted((ROOT/'game/content/baked').glob('*.json')):
        value=json.loads(path.read_text());points=[(r[0],r[2]) for r in value['samples']]
        x0=min(x for x,z in points);z0=min(z for x,z in points);dx=max(x for x,z in points)-x0;dz=max(z for x,z in points)-z0;scale=19/max(dx,dz)
        def xy(p):return f'{(p[0]-x0-dx/2)*scale+12:.3f},{(p[1]-z0-dz/2)*scale+12:.3f}'
        step=max(1,len(points)//96)
        body='<path d="M'+' L'.join(xy(p) for p in points[::step])+' Z"/>'
        x,z=xy(points[0]).split(',');body+=f'<circle cx="{x}" cy="{z}" r="1.4" fill="#F3CD48" stroke="#172c40" stroke-width=".6"/>'
        rows.append(write('track_'+path.stem,body,'track',{'route_hash':value['content_hash']}))
    for rank,color in [('gold','#F3CD48'),('silver','#C5D4D9'),('bronze','#CB8B54')]:
        body=f'<path d="M7 2h4l1 6-4 4-4-8zM13 2h4l3 2-4 8-4-4z" fill="{color}" stroke="#172c40"/><circle cx="12" cy="15" r="7" fill="{color}" stroke="#172c40"/><path d="M12 10l1.5 3 3.5.5-2.5 2.4.6 3.4-3.1-1.6-3.1 1.6.6-3.4L7 13.5l3.5-.5z" stroke="#172c40" stroke-width="1"/>'
        rows.append(write('medal_'+rank,body,'medal'))
        body=f'<g fill="{color}" stroke="#172c40">{GLYPHS["menu_cup"]}</g>'
        rows.append(write('trophy_'+rank,body,'trophy'))
    rows.append(write('medal_none','<circle cx="12" cy="13" r="8" stroke-dasharray="2 3"/><path d="M8 3V1M16 3V1"/>','medal'))
    paints=json.loads((ROOT/'game/content/cars.json').read_text())['paints']
    for index,color in enumerate(paints):
        rows.append(write('paint_'+str(index),f'<rect x="3" y="3" width="18" height="18" rx="2" fill="#{color}"/>','paint',{'color':color}))
    catalog={'schema_version':1,'creator':'Pacific Rush contributors','license':'MIT','source':'assets/source/generate_icons.py','viewbox':[0,0,24,24],'assets':sorted(rows,key=lambda r:r['id'])}
    (OUT/'catalog.json').write_text(json.dumps(catalog,indent=2)+'\n')
    for path in OUT.glob('*.svg.import'):
        path.write_text(path.read_text().replace('mipmaps/generate=false','mipmaps/generate=true'))
    print('ORIGINAL_SVG_ICONS',len(rows))

if __name__=='__main__':main()
