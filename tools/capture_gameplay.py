#!/usr/bin/env python3
"""Six ordinary races from an exported desktop game or owned rooted Android emulator."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import time
import uuid
from bootstrap import ROOT

PACKAGE = 'dev.pacificrush.game'


def verify(path, track, mobile, tick):
    image = path.read_bytes()
    assert image[:8] == b'\x89PNG\r\n\x1a\n'
    size = struct.unpack('>II', image[16:24])
    value = json.loads(path.with_suffix('.png.json').read_text())
    assert value['track'] == track and value['phase'] == 4
    assert value['race_ticks'] >= tick and value['speed_mps'] > 5
    assert value['mode'] == 'quick' and value['opponents'] == 7
    assert value['autodrive'] and not value['synthetic_pose'] and value['hud']
    assert value['touch'] == mobile and value['camera'] == 'near'
    assert value['settings']['preset'] == 'medium'
    assert size == (value['width'], value['height'])
    assert size == ((2400, 1080) if mobile else (1920, 1080))
    assert value['png_sha256'] == hashlib.sha256(image).hexdigest()
    assert value['build']['target_platform'] in (['android'] if mobile else ['macos', 'windows', 'linux'])
    return value


def main():
    parser = argparse.ArgumentParser()
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument('--desktop-binary', type=Path)
    target.add_argument('--android-serial', help='Owned rooted emulator only; never roots a device')
    parser.add_argument('--adb', type=Path, default=Path.home()/'Library/Android/sdk/platform-tools/adb')
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--race-tick', type=int, default=1200)
    parser.add_argument('--track', action='append', help='Default: all six, in catalog order')
    args = parser.parse_args()
    args.out = args.out.resolve()
    args.out.mkdir(parents=True, exist_ok=True)
    catalog = [row['id'] for row in json.loads((ROOT/'game/content/tracks.json').read_text())['tracks']]
    tracks = args.track or catalog
    assert set(tracks) <= set(catalog) and 0 < args.race_tick <= 18000
    mobile = bool(args.android_serial)
    run = uuid.uuid4().hex[:10]
    summary = {'passed': False, 'boundary': 'Unretouched native export gameplay, diagnostic ordinary AI inputs; no physical-device, human driving, other OS render or storefront approval claim.', 'captures': []}
    def adb(*command, **options):
        return subprocess.run([str(args.adb), '-s', args.android_serial, *command], check=True, **options)
    if mobile:
        assert args.android_serial.startswith('emulator-'), 'Only an explicitly named owned emulator is supported'
        assert adb('shell', 'id', '-u', capture_output=True, text=True).stdout.strip() == '0', 'Emulator must already be rooted'
        summary['device'] = adb('shell', 'getprop', 'ro.product.model', capture_output=True, text=True).stdout.strip()
        summary['android_release'] = adb('shell', 'getprop', 'ro.build.version.release', capture_output=True, text=True).stdout.strip()
        summary['serial'] = args.android_serial
    else:
        args.desktop_binary = args.desktop_binary.resolve()
        summary['binary_sha256'] = hashlib.sha256(args.desktop_binary.read_bytes()).hexdigest()
    try:
        for track in tracks:
            profile = 'qa_capture_' + run + '_' + track
            output = args.out/(track+'.png')
            assert not output.exists(), 'Refuse to replace a previous capture'
            screenshot = 'user://diagnostic_profiles/'+profile+'/capture.png' if mobile else str(output)
            options = ['--profile='+profile, '--capture='+screenshot, '--capture-track='+track,
                       '--capture-race-tick='+str(args.race_tick), '--autodrive']
            archive = None
            if mobile:
                folder = '/data/user/0/'+PACKAGE+'/files/diagnostic_profiles/'+profile
                archive = '/data/local/tmp/pacific-rush-captures-'+run+'-'+track
                assert adb('shell', 'sh', '-c', 'test ! -e '+folder, capture_output=True).returncode == 0
                adb('shell', 'am', 'force-stop', PACKAGE, capture_output=True)
                adb('shell', 'am', 'start', '-n', PACKAGE+'/com.godot.game.GodotApp',
                    '--esa', 'command_line_params', ','.join(['--', *options]), capture_output=True)
                deadline = time.monotonic()+240
                while time.monotonic()<deadline:
                    exists = subprocess.run([str(args.adb), '-s', args.android_serial, 'shell', 'test', '-f', folder+'/capture.png.json'], capture_output=True)
                    if exists.returncode == 0:
                        for suffix in ['', '.json']:
                            output.with_name(output.name+suffix).write_bytes(adb('exec-out', 'cat', folder+'/capture.png'+suffix, capture_output=True).stdout)
                        break
                    time.sleep(1)
                else:
                    raise TimeoutError('Actual Android gameplay capture timed out: '+track)
                adb('shell', 'am', 'force-stop', PACKAGE, capture_output=True)
                adb('shell', 'mv', folder, archive, capture_output=True)
            else:
                with output.with_suffix('.log').open('w') as log:
                    subprocess.run([str(args.desktop_binary), '--resolution', '1920x1080', '--', *options],
                                   cwd=args.desktop_binary.parent, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=240)
            value = verify(output, track, mobile, args.race_tick)
            value['png'] = output.name
            if archive: value['owned_profile_archive'] = archive
            summary['captures'].append(value)
            print(json.dumps({'captured': track, 'pixels': [value['width'],value['height']], 'tick': value['race_ticks']}), flush=True)
        assert len(summary['captures']) == len(tracks)
        summary['passed'] = True
    finally:
        if mobile: adb('shell', 'am', 'force-stop', PACKAGE, capture_output=True)
        (args.out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')


if __name__ == '__main__':
    main()
