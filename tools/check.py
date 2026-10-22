#!/usr/bin/env python3
"""One command for source contracts and real-engine driving/race/network fixtures."""
import json
from datetime import datetime, timezone
import os
import platform
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import uuid
from bootstrap import ROOT, engine

SUITES = ['source_script_tests', 'iroh_room_tests', 'content_tests', 'expansion40_tests', 'road_partition_tests', 'driving_tests', 'steering_drift_tests', 'race_assistance_tests', 'world_tests', 'progress_touch_tests', 'trial_medal_acceptance', 'course_camera_acceptance', 'soak_driver_tests',
          'slice_smoke', 'network_contract_tests', 'client_prediction_tests', 'race_contact_tests', 'jump_track_tests', 'summit_landing_tests', 'billboard_tests', 'roadside_poster_tests',
          'save_cup_tests', 'ghost_medal_tests', 'app_data_tests', 'name_tests', 'menu_flow_tests', 'mode_tests', 'lobby_tests', 'compact_control_tests', 'input_ownership_tests', 'display_tests', 'ghost_transaction_tests', 'binding_tests', 'binding_ui_tests', 'menu_repeat_tests', 'result_receipt_tests', 'touch_layout_tests', 'touch_editor_tests', 'choice_picker_tests', 'guest_identity_tests', 'guest_service_tests', 'directory_client_tests', 'region_book_tests', 'online_menu_tests', 'identity_reset_ui_tests', 'keyboard_layout_tests', 'menu_scroll_tests', 'retry_flow_tests', 'world_presentation_tests', 'loading_flow_tests', 'audio_mix_tests', 'recovery_assist_tests', 'diagnostics_export_tests', 'network_quality_tests', 'accessibility_settings_tests', 'bot_contract_tests', 'car_asset_tests', 'scenery_contract_tests', 'surface_version_tests', 'content_transition_tests', 'content5_transition_tests', 'content6_transition_tests', 'content7_transition_tests', 'content8_transition_tests', 'content9_transition_tests', 'content10_transition_tests', 'content11_transition_tests', 'bot_vertical_tests', 'snapshot_course_tests', 'course_variety_tests', 'arcade_track_tests', 'course_spectacle_tests', 'event_layout_tests', 'terrain_grounding_tests', 'landscape_sightline_tests', 'hill_presentation_tests', 'route_landmark_tests', 'durable_save_tests', 'race_archive_tests', 'checkpoint_ui_tests', 'results_visibility_tests']


def stop_owned_check(process):
    """Stop the session created by this invocation, never a name-matched process."""
    if os.name == 'nt':
        # Source CI runs on Linux. On Windows this preserves the former direct
        # child cleanup scope; native platform harnesses own their own children.
        if process.poll() is None:
            process.terminate()
            try: process.wait(timeout=2)
            except subprocess.TimeoutExpired: process.kill(); process.wait()
        return 'owned_direct_child'
    deadline = time.monotonic()+2
    try: os.killpg(process.pid,signal.SIGTERM)
    except ProcessLookupError: pass
    try: process.wait(timeout=2)
    except subprocess.TimeoutExpired: pass
    while time.monotonic()<deadline:
        try: os.killpg(process.pid,0)
        except ProcessLookupError: break
        time.sleep(.02)
    try: os.killpg(process.pid,signal.SIGKILL)
    except ProcessLookupError: pass
    process.wait()
    return 'owned_process_group'


def run_check(command, log_path, *, timeout=120, cwd=ROOT):
    """Retain complete merged output, including startup failures and timeouts."""
    started = time.monotonic()
    row = {'suite':' '.join(command[1:]),'command':command,'passed':False,
           'started_utc':datetime.now(timezone.utc).isoformat(),
           'timed_out':False,'interrupted':False,'exit_code':None,'log':str(log_path)}
    process = None
    with Path(log_path).open('w',encoding='utf-8') as handle:
        try:
            process = subprocess.Popen(command,cwd=cwd,stdout=handle,stderr=subprocess.STDOUT,start_new_session=os.name!='nt')
            row['exit_code'] = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            row['timed_out'] = True
            row['termination_scope'] = stop_owned_check(process)
            row['exit_code'] = process.returncode
            handle.write(f'\n[source gate] Timed out after {timeout} seconds\n')
        except KeyboardInterrupt:
            row['interrupted'] = True
            if process is not None: row['termination_scope'] = stop_owned_check(process)
            row['exit_code'] = process.returncode if process is not None else None
            handle.write('\n[source gate] Interrupted; owned process stopped\n')
        except OSError as error:
            row['failure'] = type(error).__name__+': '+str(error)
            handle.write('\n[source gate] '+row['failure']+'\n')
        finally:
            if process is not None and process.poll() is None:
                row['termination_scope'] = stop_owned_check(process)
    row['seconds'] = round(time.monotonic()-started,3)
    row['output'] = Path(log_path).read_text(errors='replace')[-4000:]
    row['passed'] = row['exit_code']==0 and not row['timed_out'] and not row['interrupted'] and 'failure' not in row
    return row


def atomic_report(path, report):
    with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',dir=path.parent,prefix='.'+path.name+'-',suffix='.tmp',delete=False) as handle:
        temporary = Path(handle.name)
        json.dump(report,handle,indent=2)
        handle.write('\n')
    try: temporary.replace(path)
    finally: temporary.unlink(missing_ok=True)


def run_checks(commands, reports, *, timeout=120):
    reports = Path(reports)
    reports.mkdir(exist_ok=True,parents=True)
    folder = reports/('checks-'+uuid.uuid4().hex[:10])
    folder.mkdir()
    report = {'platform':platform.system()+'-'+platform.machine(),'engine':'4.6.3-stable',
              'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              'working_tree_dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True)),
              'folder':str(folder),'command_count':len(commands),'passed':False,'status':'running','results':[]}
    def checkpoint():
        report['passed'] = report['status']=='complete' and len(report['results'])==len(commands) and all(row['passed'] for row in report['results'])
        atomic_report(folder/'summary.json',report)
        atomic_report(reports/'checks.json',report)
    checkpoint()
    try:
        for index,command in enumerate(commands):
            row = run_check(command,folder/f'{index+1:03d}.log',timeout=timeout)
            report['results'].append(row)
            print(('PASS ' if row['passed'] else 'FAIL ')+row['suite'],flush=True)
            output = row['output'][-1000:]
            print(output,end='' if output.endswith('\n') else '\n',flush=True)
            checkpoint()
            if row['interrupted']:
                report['status'] = 'interrupted'
                break
        else: report['status'] = 'complete'
    except KeyboardInterrupt:
        report['status'] = 'interrupted'
    except BaseException as error:
        report['status'] = 'failed'
        report['failure'] = type(error).__name__+': '+str(error)
        raise
    finally:
        checkpoint()
    return report


def main():
    reports = ROOT/'reports'
    reports.mkdir(exist_ok=True)
    (reports/'.gdignore').touch()
    commands = [[sys.executable,'tools/validate_content.py'], [sys.executable,'tools/bake_tracks.py','--check'],
                [sys.executable,'tools/generate_graphemes.py','--check'],
                [sys.executable,'tools/content_hash.py','--check'], [sys.executable,'tools/asset_hash.py','--check'],
                [sys.executable,'tools/app_icons.py','--check'],
                [sys.executable,'-m','unittest','discover','-s','tests','-p','test_*.py'],
                [sys.executable,'tools/godot.py','--headless','--editor','--import','--quit']]
    for suite in SUITES+['race_audio_tests','feedback_event_tests','race_feedback_tests','recovery_presentation_tests','interface_icon_tests','race_hud_tests','menu_style_tests','school_presentation_tests']:
        source=(ROOT/f'tests/{suite}.gd').read_text()
        # UI/race scenes now own real audio transports. Let the mixer thread
        # process stop/fade commands before shutdown; deterministic simulation
        # fixtures still run with accelerated fixed frames.
        realtime=any(marker in source for marker in ['client_app.gd','RaceDrive.new()'])
        command=[sys.executable,'tools/godot.py','--headless','--max-fps' if realtime else '--fixed-fps','60','--script',f'tests/{suite}.gd','--','--profile=ci_tests']
        if suite in ['trial_medal_acceptance','course_camera_acceptance']:
            # Each course keeps the existing per-command deadline as the
            # roster grows. Every car/camera is still exercised on every route.
            for track in json.loads((ROOT/'game/content/tracks.json').read_text())['tracks']:
                commands.append(command+['--track='+track['id'],'--report=res://reports/'+suite+'-'+track['id']+'.json'])
        else: commands.append(command)
    commands.append([sys.executable,'tools/godot.py','--headless','--max-fps','60','--script','tests/leave_delivery_tests.gd'])
    commands.append([sys.executable,'tools/godot.py','--headless','--max-fps','60','--script','tests/lobby_reconnect_tests.gd'])
    commands.append([sys.executable,'tools/godot.py','--headless','--max-fps','60','--script','tests/online_lifecycle_tests.gd','--','--profile=ci_tests'])
    commands.append([sys.executable,'tools/godot.py','--headless','--max-fps','60','--script','tests/mobile_runtime_tests.gd','--','--profile=ci_tests'])
    commands.append([sys.executable,'tools/godot.py','--headless','--max-fps','60','--script','tests/mobile_services_tests.gd','--','--profile=ci_tests'])
    commands.append([sys.executable,'tools/godot.py','--headless','--max-fps','60','--script','tests/direct_connect_tests.gd','--','--profile=ci_tests'])
    commands.append([sys.executable,'tools/godot.py','--headless','--script','tests/shader_warmup_tests.gd'])
    commands.append([sys.executable,'tools/godot.py','--headless','--max-fps','60','--script','tests/packet_fault_tests.gd'])
    commands.append([sys.executable,'tools/godot.py','--headless','--script','tests/grapheme_tests.gd'])
    commands.append([sys.executable,'tools/godot.py','--headless','--script','tests/worker_performance_tests.gd'])
    commands.append([sys.executable,'tools/godot.py','--headless','--script','tests/font_tests.gd'])
    commands.append([sys.executable,'tools/godot.py','--headless','--script','tests/font_input_tests.gd'])
    commands.append([sys.executable,'tools/godot.py','--headless','--script','tests/retirement_tests.gd'])
    commands.append([sys.executable,'tools/godot.py','--headless','--max-fps','60','--script','tests/worker_directory_tests.gd'])
    commands.append([sys.executable,'tools/retirement_integration.py'])
    commands.append([sys.executable,'tools/godot.py','--headless','--script','tests/audio_dsp_evidence.gd'])
    report = run_checks(commands,reports)
    raise SystemExit(0 if report['passed'] else 130 if report['status']=='interrupted' else 1)


if __name__ == '__main__':
    main()
