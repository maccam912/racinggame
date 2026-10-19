#!/usr/bin/env python3
"""Two complete eight-human races: installed Android APK + seven native clients.

Requires an owned rooted Android emulator, a matching built APK and pinned
Godot. Uses diagnostic autodrive, normal lobby timers and actual authority rows.
Keeps unrelated profiles and archives only the unique QA profile it creates.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import socket
import subprocess
import time
import uuid
from bootstrap import ROOT, engine


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--serial', required=True)
    parser.add_argument('--number', required=True, type=int)
    parser.add_argument('--adb', default=str(Path.home()/'Library/Android/sdk/platform-tools/adb'))
    args = parser.parse_args()
    adb = [args.adb, '-s', args.serial]

    def device(*arguments):
        return subprocess.check_output([*adb, *arguments], stderr=subprocess.STDOUT)

    if not args.serial.startswith('emulator-') or device('shell', 'getprop', 'ro.kernel.qemu').strip() != b'1':
        raise RuntimeError('This automated fixture requires an owned Android emulator')
    if device('shell', 'id', '-u').strip() != b'0':
        raise RuntimeError('The emulator must already be rooted for isolated QA-profile verification')
    apk = ROOT/f'build/download/pacific-rush-{args.number:05d}-android.apk'
    build = json.loads(apk.with_name(apk.stem+'-build.json').read_text())
    assert build['target_platform'] == 'android'
    assert build['content_hash'] == json.loads((ROOT/'game/content/compatibility.json').read_text())['content_hash']
    assert build['protocol_version'] == json.loads((ROOT/'game/content/rules.json').read_text())['protocol_version']
    folder = ROOT/'reports'/f'mixed-android-{args.number}-{uuid.uuid4().hex[:8]}'
    folder.mkdir(parents=True)
    profile = 'm5_mixed_'+uuid.uuid4().hex[:12]
    profile_path = '/data/user/0/dev.pacificrush.game/files/diagnostic_profiles/'+profile
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(('127.0.0.1', 0))
        port = probe.getsockname()[1]
    processes, handles = [], []
    report = {'passed': False, 'build': build,
              'apk_sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
              'serial': args.serial, 'model': device('shell', 'getprop', 'ro.product.model').decode().strip(),
              'android_release': device('shell', 'getprop', 'ro.build.version.release').decode().strip(),
              'profile': profile, 'transport': 'Local real ENet; Android emulator host gateway and native loopback',
              'boundary': 'Installed release APK with diagnostic autodrive and seven native shared-controller clients. Normal lobby/results timers, original graphics/HUD and actual authority. Automated emulator cross-play; not physical touch, cellular, thermal, human feel or ten-race impaired-network acceptance.'}
    android_log = ''

    def game_log():
        return device('shell', 'logcat', '-d', '-v', 'raw', '-s', 'godot').decode()

    def wait_for(predicate, seconds):
        deadline = time.monotonic()+seconds
        while time.monotonic() < deadline:
            if predicate():
                return
            if any(p.poll() not in [None, 0] for p in processes):
                raise RuntimeError('An owned native fixture exited unsuccessfully; inspect logs')
            time.sleep(.2)
        raise TimeoutError('Mixed-platform fixture condition timed out')

    def launch(arguments, name):
        handle = (folder/name).open('w')
        handles.append(handle)
        process = subprocess.Popen([str(engine()), '--headless', '--path', str(ROOT), '--max-fps', '60', *arguments], stdout=handle, stderr=subprocess.STDOUT)
        processes.append(process)
        return process

    try:
        device('install', '-r', str(apk))
        device('shell', 'am', 'force-stop', 'dev.pacificrush.game')
        device('shell', 'logcat', '-c')
        launch(['--script', 'tests/mobile_worker_evidence.gd', '--', '--port='+str(port), '--network-evidence', '--authority-report='+str(folder/'authority.json')], 'server.log')
        wait_for(lambda: 'PACIFIC_RUSH_SERVER_READY' in (folder/'server.log').read_text(), 10)
        # Establish a native host before the mobile client joins. The existing
        # eight-member fixture requests Palm Bay/Citrus rules and marks itself
        # ready; Android exercises the normal automatic lobby/results timers.
        launch(['--script', 'tests/lobby_network_client.gd', '--', '--index=0', '--port='+str(port), '--report='+str(folder/'client0.json')], 'client0.log')
        wait_for(lambda: 'waiting for racers' in (folder/'client0.log').read_text(), 8)
        for index in range(1, 7):
            launch(['--script', 'tests/lobby_network_client.gd', '--', '--index='+str(index), '--port='+str(port), '--report='+str(folder/f'client{index}.json')], f'client{index}.log')
        device('shell', 'am', 'start', '-n', 'dev.pacificrush.game/com.godot.game.GodotApp', '--esa', 'command_line_params', '--,--profile='+profile+',--connect=10.0.2.2:'+str(port)+',--autodrive,--network-evidence')
        deadline = time.monotonic()+350
        previous = (-1, -1)
        captured = set()
        while time.monotonic() < deadline:
            android_log = game_log()
            assert all(marker not in android_log for marker in ['SCRIPT ERROR', 'ERROR:', 'Unicode parsing error'])
            if 'Reconnect expired' in android_log:
                raise RuntimeError('Android reservation expired before the mixed run completed')
            drives = android_log.count('PACIFIC_RUSH_DRIVING_READY')
            result_text = re.findall(r'PACIFIC_RUSH_CLIENT_RESULTS_DIGEST (\d+) (\d+) ([0-9a-f]{64})', android_log)
            state = (drives, len(result_text))
            if state != previous:
                print(json.dumps({'android_drives': drives, 'android_results': len(result_text), 'report': str(folder)}), flush=True)
                previous = state
            if drives and (drives, 'grid') not in captured:
                (folder/f'android-grid-{drives}.png').write_bytes(device('exec-out', 'screencap', '-p'))
                captured.add((drives, 'grid'))
            if result_text and (len(result_text), 'results') not in captured:
                (folder/f'android-results-{len(result_text)}.png').write_bytes(device('exec-out', 'screencap', '-p'))
                captured.add((len(result_text), 'results'))
            if len(result_text) == 2 and all((folder/f'client{i}.json').exists() for i in range(7)):
                break
            if any(p.poll() not in [None, 0] for p in processes):
                raise RuntimeError('An owned native fixture failed during cross-play; inspect logs')
            time.sleep(.5)
        else:
            raise TimeoutError('Two mixed-platform races did not complete before the deadline')
        wait_for(lambda: all(p.poll() == 0 for p in processes[1:]), 8)
        values = [json.loads((folder/f'client{i}.json').read_text()) for i in range(7)]
        races = values[0]['results']
        assert len(races) == 2 and all(value['results'] == races and value['loaded_tracks'] == [0, 1] and value['large_racing_events'] == 0 for value in values)
        hashes = values[0]['result_hashes']
        assert all(value['result_hashes'] == hashes for value in values)
        assert all(int(race_id) == index+1 and int(count) == 8 and digest == hashes[index] for index, (race_id, count, digest) in enumerate(result_text)), 'Android/native complete result digests differ'
        authority_rows = [json.loads(text) for text in re.findall(r'PACIFIC_RUSH_AUTHORITATIVE_RESULTS (\[.*\])', (folder/'server.log').read_text())]
        assert authority_rows == [race['rows'] for race in races], 'Authority/native rows differ'
        assert 'NETWORK_REJECTED_SCHEMA' not in android_log
        assert all(len(race['rows']) == 8 and all(not row['bot'] and row['dnf'] == '' for row in race['rows']) for race in races)
        assert {row['id'] for row in races[0]['rows']} == {row['id'] for row in races[1]['rows']}
        assert sorted({row['car'] for row in races[0]['rows']}) == [0, 1, 2, 3]
        assert android_log.count('PACIFIC_RUSH_GRAPHICS_PREPARED') == 2
        time.sleep(.8) # Result receipt commits after the diagnostic result line.
        saved = json.loads(device('shell', 'cat', profile_path+'/profile.json'))
        assert saved['payload']['races_completed'] == 2, 'Android result journal did not commit exactly two races'
        (folder/'android-profile.json').write_text(json.dumps(saved, indent=2)+'\n')
        report.update(passed=True, humans=8, native_clients=7, android_clients=1, tracks=[0, 1], races=races,
                      all_sixteen_finishes=True, identical_authority_android_native_rows=True,
                      same_eight_identities=True, android_graphics_prepared_twice=True,
                      android_races_committed=2, native_large_racing_events=0,
                      result_comparison='Full authority/native rows and matching canonical parsed-row SHA-256 on Android and every native client', result_hashes=hashes)
        for path in folder.glob('*.log'):
            assert all(marker not in path.read_text() for marker in ['SCRIPT ERROR', 'ERROR:', 'Unicode parsing error']), path.name
    except BaseException as error:
        report['failure'] = type(error).__name__+': '+str(error)
        raise
    finally:
        cleanup_issues = []
        try:
            (folder/'android-last.png').write_bytes(device('exec-out', 'screencap', '-p'))
        except (subprocess.CalledProcessError, OSError):
            cleanup_issues.append('final screenshot unavailable')
        try:
            (folder/'android.log').write_text(game_log())
        except (subprocess.CalledProcessError, UnicodeDecodeError, OSError):
            cleanup_issues.append('final decoded log unavailable')
        try:
            device('shell', 'am', 'force-stop', 'dev.pacificrush.game')
        except subprocess.CalledProcessError:
            cleanup_issues.append('force-stop unavailable')
        finally:
            for process in reversed(processes):
                if process.poll() is None:
                    process.terminate()
            for process in processes:
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            for handle in handles:
                handle.close()
        archive = '/data/local/tmp/pacific-rush-'+profile
        try:
            device('shell', 'mv', profile_path, archive)
            report['archived_profile'] = archive
        except subprocess.CalledProcessError:
            report['archived_profile'] = None
            cleanup_issues.append('QA profile archive unavailable')
        report['cleanup_issues'] = cleanup_issues
        (folder/'summary.json').write_text(json.dumps(report, indent=2)+'\n')
        print(json.dumps({'passed': report['passed'], 'report': str(folder/'summary.json')}), flush=True)


if __name__ == '__main__':
    main()
