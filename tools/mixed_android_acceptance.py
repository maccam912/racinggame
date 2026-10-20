#!/usr/bin/env python3
"""Repeated eight-human races: installed Android APK + seven native clients.

Requires an owned rooted Android emulator, a matching built APK and pinned
Godot. Uses diagnostic autodrive, normal lobby timers and actual authority rows.
Keeps unrelated profiles and archives only the unique QA profile it creates.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import socket
import subprocess
import time
import uuid
from bootstrap import ROOT, engine
from content_hash import compute as gameplay_manifest
from udp_proxy import UDPProxy


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--serial', required=True)
    parser.add_argument('--number', required=True, type=int)
    parser.add_argument('--ui-scale', type=int, choices=[100,125,150], default=100)
    parser.add_argument('--races', type=int, choices=range(2,11), default=2)
    parser.add_argument('--laps', type=int, choices=[1,2,3], default=1)
    parser.add_argument('--seconds', type=int, default=350)
    parser.add_argument('--impaired', action='store_true', help='Eight independent UDP proxies: 50±20 ms each direction and 1%% loss, including ENet ACKs')
    parser.add_argument('--adb', default=str(Path.home()/'Library/Android/sdk/platform-tools/adb'))
    parser.add_argument("--tracks", default="palm_bay,citrus_pass", help="Comma-separated catalog IDs; native host selects this sequence")
    args = parser.parse_args()
    catalog=[row["id"] for row in json.loads((ROOT/"game/content/tracks.json").read_text())["tracks"]]
    selected=args.tracks.split(",")
    assert selected and all(value in catalog for value in selected)
    track_indices=[catalog.index(value) for value in selected]
    expected_tracks=[track_indices[index%len(track_indices)] for index in range(args.races)]
    assert 120 <= args.seconds <= 2400
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
    manifest = gameplay_manifest()
    assert manifest == json.loads((ROOT/'game/content/compatibility.json').read_text())
    folder = ROOT/'reports'/f'mixed-android-{args.number}-{uuid.uuid4().hex[:8]}'
    folder.mkdir(parents=True)
    profile = 'm5_mixed_'+uuid.uuid4().hex[:12]
    profile_path = '/data/user/0/dev.pacificrush.game/files/diagnostic_profiles/'+profile
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(('127.0.0.1', 0))
        port = probe.getsockname()[1]
    processes, handles, proxies = [], [], []
    log_process = None
    began = time.monotonic()
    memory = []
    report = {'passed': False, 'build': build,
              'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              'working_tree_dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True)),
              'fixture_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'apk_sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
              'serial': args.serial, 'model': device('shell', 'getprop', 'ro.product.model').decode().strip(),
              'android_release': device('shell', 'getprop', 'ro.build.version.release').decode().strip(),
              'profile': profile, 'ui_scale': args.ui_scale, 'races_requested':args.races, 'laps':args.laps,
              'transport': 'Eight independent real UDP proxies; Android emulator host gateway and native loopback',
              'one_way_latency_ms':50 if args.impaired else 0, 'one_way_jitter_ms':20 if args.impaired else 0,
              'independent_datagram_loss':.01 if args.impaired else 0,
              'boundary': 'Installed release APK with diagnostic autodrive and seven native shared-controller clients. Normal lobby/results timers, original graphics/HUD and actual authority. Native-client corrections are separate from Android result agreement. Android process RSS excludes separate GPU/emulator allocations. No physical touch, cellular, thermal, minimum-hardware or human handling claim.'}
    android_log = ''

    def game_log():
        return (folder/'android.log').read_text(errors='replace') if (folder/'android.log').exists() else ''

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
        if args.ui_scale != 100:
            # Seed only this brand-new owned QA profile while the app is stopped.
            # Partial mobile settings merge with normal shipped defaults.
            settings = {'schema_version':1,'saved_at_utc':datetime.now(timezone.utc).isoformat(),
                        'payload':{'desktop':{},'mobile':{'ui_scale':args.ui_scale}}}
            seed = folder/'seed-settings.json'
            seed.write_text(json.dumps(settings)+'\n')
            device('shell','mkdir','-m','700',profile_path)
            device('push',str(seed),profile_path+'/settings.json')
            uid = device('shell','stat','-c','%u','/data/user/0/dev.pacificrush.game').decode().strip()
            assert uid.isdigit()
            device('shell','chown','-R',uid+':'+uid,profile_path)
            device('shell','chmod','600',profile_path+'/settings.json')
        device('shell', 'logcat', '-c')
        # Stream once so a long run cannot lose early results when Android's
        # bounded system log buffer rotates. This child belongs to this fixture.
        log_handle = (folder/'android.log').open('w')
        handles.append(log_handle)
        log_process = subprocess.Popen([*adb,'logcat','-v','raw','-s','godot'],stdout=log_handle,stderr=subprocess.STDOUT)
        launch(['--script', 'tests/mobile_worker_evidence.gd', '--', '--port='+str(port), '--network-evidence', '--authority-report='+str(folder/'authority.json')], 'server.log')
        wait_for(lambda: 'PACIFIC_RUSH_SERVER_READY' in (folder/'server.log').read_text(), 10)
        for index in range(8):
            proxy = UDPProxy(0,port,50 if args.impaired else 0,20 if args.impaired else 0,.01 if args.impaired else 0,seed=81721+101*index)
            proxies.append(proxy)
            proxy.start()
        ports = [proxy.front.getsockname()[1] for proxy in proxies]
        fixture = 'tests/soak_network_client.gd' if args.impaired else 'tests/lobby_network_client.gd'
        def native_arguments(index):
            return ['--script',fixture,'--','--index='+str(index),'--port='+str(ports[index]),
                    '--races='+str(args.races),'--laps='+str(args.laps),'--seconds='+str(args.seconds),'--tracks='+','.join(map(str,track_indices)),
                    '--report='+str(folder/f'client{index}.json')]
        # Establish a native host before the mobile client joins. The existing
        # eight-member fixture requests the selected course rules and marks itself
        # ready; Android exercises the normal automatic lobby/results timers.
        launch(native_arguments(0), 'client0.log')
        wait_for(lambda: 'waiting for racers' in (folder/'client0.log').read_text(), 8)
        for index in range(1, 7):
            launch(native_arguments(index), f'client{index}.log')
        device('shell', 'am', 'start', '-n', 'dev.pacificrush.game/com.godot.game.GodotApp', '--esa', 'command_line_params', '--,--profile='+profile+',--connect=10.0.2.2:'+str(ports[7])+',--autodrive,--network-evidence')
        # Activity launch may return before the package appears in pidof.
        # Once acquired, the normal loop still rejects any missing/replaced PID.
        startup_pid = []
        def process_started():
            observed = subprocess.run([*adb,'shell','pidof','dev.pacificrush.game'],capture_output=True,text=True)
            value = observed.stdout.strip()
            if observed.returncode==0 and value.isdigit():
                startup_pid.append(value)
                return True
            return False
        wait_for(process_started,15)
        report['android_startup_pid'] = startup_pid[0]
        deadline = time.monotonic()+args.seconds
        next_memory = 0
        android_pid = startup_pid[0]
        previous = (-1, -1)
        captured = set()
        while time.monotonic() < deadline:
            android_log = game_log()
            assert log_process.poll() is None, 'Owned Android log stream exited early'
            assert all(marker not in android_log for marker in ['SCRIPT ERROR', 'ERROR:', 'Unicode parsing error'])
            if 'Reconnect expired' in android_log:
                raise RuntimeError('Android reservation expired before the mixed run completed')
            drives = android_log.count('PACIFIC_RUSH_DRIVING_READY')
            result_text = re.findall(r'PACIFIC_RUSH_CLIENT_RESULTS_DIGEST (\d+) (\d+) ([0-9a-f]{64})', android_log)
            state = (drives, len(result_text))
            age = time.monotonic()-began
            if age >= next_memory:
                next_memory = age+5
                pid = device('shell','pidof','dev.pacificrush.game').decode().strip()
                assert pid.isdigit(), 'Exactly one live Android game process required'
                if android_pid is None: android_pid = pid
                assert pid==android_pid, 'Android process restarted during the run'
                status = device('shell','cat','/proc/'+pid+'/status').decode()
                rss = re.search(r'^VmRSS:\s+(\d+)\s+kB$',status,re.MULTILINE)
                assert rss, 'Android native RSS unavailable'
                memory.append({'elapsed':age,'rss_bytes':int(rss[1])*1024})
            if state != previous:
                print(json.dumps({'android_drives': drives, 'android_results': len(result_text), 'report': str(folder)}), flush=True)
                previous = state
            if drives and (drives, 'grid') not in captured:
                (folder/f'android-grid-{drives}.png').write_bytes(device('exec-out', 'screencap', '-p'))
                captured.add((drives, 'grid'))
            if result_text and (len(result_text), 'results') not in captured:
                (folder/f'android-results-{len(result_text)}.png').write_bytes(device('exec-out', 'screencap', '-p'))
                captured.add((len(result_text), 'results'))
            if len(result_text) == args.races and all((folder/f'client{i}.json').exists() for i in range(7)):
                break
            if any(p.poll() not in [None, 0] for p in processes):
                raise RuntimeError('An owned native fixture failed during cross-play; inspect logs')
            time.sleep(.5)
        else:
            raise TimeoutError('Requested mixed-platform races did not complete before the deadline')
        wait_for(lambda: all(p.poll() == 0 for p in processes[1:]), 8)
        values = [json.loads((folder/f'client{i}.json').read_text()) for i in range(7)]
        races = values[0]['results']
        assert len(races) == args.races and all(value['results'] == races and value['loaded_tracks'] == expected_tracks and value['large_racing_events'] == 0 for value in values)
        hashes = values[0]['result_hashes']
        assert all(value['result_hashes'] == hashes for value in values)
        assert all(int(race_id) == index+1 and int(count) == 8 and digest == hashes[index] for index, (race_id, count, digest) in enumerate(result_text)), 'Android/native complete result digests differ'
        authority_rows = [json.loads(text) for text in re.findall(r'PACIFIC_RUSH_AUTHORITATIVE_RESULTS (\[.*\])', (folder/'server.log').read_text())]
        assert authority_rows == [race['rows'] for race in races], 'Authority/native rows differ'
        assert 'NETWORK_REJECTED_SCHEMA' not in android_log
        assert all(len(race['rows']) == 8 and all(not row['bot'] and row['dnf'] == '' for row in race['rows']) for race in races)
        assert all({row['id'] for row in races[0]['rows']} == {row['id'] for row in race['rows']} for race in races)
        assert sorted({row['car'] for row in races[0]['rows']}) == [0, 1, 2, 3]
        assert android_log.count('PACIFIC_RUSH_GRAPHICS_PREPARED') == args.races
        time.sleep(.8) # Result receipt commits after the diagnostic result line.
        saved = json.loads(device('shell', 'cat', profile_path+'/profile.json'))
        assert saved['payload']['races_completed'] == args.races, 'Android result journal did not commit exactly the requested races'
        (folder/'android-profile.json').write_text(json.dumps(saved, indent=2)+'\n')
        assert gameplay_manifest()==manifest and manifest==json.loads((ROOT/'game/content/compatibility.json').read_text()), 'Gameplay sources changed during the run'
        report.update(passed=True, humans=8, native_clients=7, android_clients=1, tracks=expected_tracks, races=races,
                      all_requested_finishes=True, finishes=8*args.races, identical_authority_android_native_rows=True,
                      same_eight_identities=True, android_graphics_prepared_count=args.races,
                      android_races_committed=args.races, native_large_racing_events=0,
                      clients_reports=values,
                      result_comparison='Full authority/native rows and matching canonical parsed-row SHA-256 on Android and every native client', result_hashes=hashes)
        if args.impaired and args.laps==3:
            clear = [row['clear'] for value in values for row in value['race_metrics']]
            checks = {'native_clear_coverage_500_each':len(clear)==7*args.races and all(row['count']>=500 for row in clear),
                      'native_clear_p95_025m_each':bool(clear) and all(row['p95']<=.25 for row in clear)}
            report['correction_checks'] = checks
            assert all(checks.values()), 'Native correction coverage or bound failed'
        for path in folder.glob('*.log'):
            assert all(marker not in path.read_text() for marker in ['SCRIPT ERROR', 'ERROR:', 'Unicode parsing error']), path.name
    except BaseException as error:
        report['passed'] = False
        report['failure'] = type(error).__name__+': '+str(error)
        raise
    finally:
        cleanup_issues = []
        try:
            (folder/'android-last.png').write_bytes(device('exec-out', 'screencap', '-p'))
        except (subprocess.CalledProcessError, OSError):
            cleanup_issues.append('final screenshot unavailable')
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
            if log_process is not None:
                log_process.terminate()
                try: log_process.wait(timeout=5)
                except subprocess.TimeoutExpired: log_process.kill(); log_process.wait()
            report['wire_totals'] = [dict(proxy.stats) for proxy in proxies]
            for proxy in proxies:
                try: proxy.stop()
                except Exception as error: cleanup_issues.append('UDP proxy: '+str(error))
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
        report['elapsed_seconds'] = time.monotonic()-began
        report['android_memory'] = {'observations':memory,'measured_5_to_15_minutes':False,
                                   'peak_rss_bytes':max((row['rss_bytes'] for row in memory),default=0)}
        if memory and memory[-1]['elapsed']>=900:
            first = next(row for row in memory if row['elapsed']>=300)
            last = next(row for row in memory if row['elapsed']>=900)
            warmup = max(row['rss_bytes'] for row in memory if row['elapsed']<=first['elapsed'])
            peak = max(row['rss_bytes'] for row in memory if first['elapsed']<=row['elapsed']<=last['elapsed'])
            report['android_memory'].update(measured_5_to_15_minutes=True,warmup_peak_rss_bytes=warmup,
                repeated_cycle_peak_rss_bytes=peak,peak_growth_fraction=peak/warmup-1,
                boundary='Comparable Palm Bay/Citrus three-lap loading/racing cycles. Actual Android process VmRSS on this emulator; excludes GPU and emulator host memory, no minimum-device or thermal claim.')
        if args.races==10 and args.laps==3:
            stats = report['android_memory']
            report['emulator_memory_checks'] = {'measured_5_to_15_minutes':stats['measured_5_to_15_minutes'],
                'rss_peak_under_1GB':0<stats['peak_rss_bytes']<=1000000000,
                'cycle_peak_growth_at_most_5_percent':stats.get('peak_growth_fraction',float('inf'))<=.05}
            if not all(report['emulator_memory_checks'].values()): report['passed'] = False
        if cleanup_issues: report['passed'] = False
        (folder/'summary.json').write_text(json.dumps(report, indent=2)+'\n')
        print(json.dumps({'passed': report['passed'], 'report': str(folder/'summary.json')}), flush=True)
    raise SystemExit(0 if report['passed'] else 1)


if __name__ == '__main__':
    main()
