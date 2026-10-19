#!/usr/bin/env python3
"""One command for source contracts and real-engine driving/race/network fixtures."""
import json
import platform
from pathlib import Path
import subprocess
import sys
import time
from bootstrap import ROOT, engine

SUITES = ['content_tests', 'driving_tests', 'world_tests', 'progress_touch_tests',
          'slice_smoke', 'network_contract_tests', 'race_contact_tests', 'jump_track_tests',
          'save_cup_tests', 'ghost_medal_tests', 'app_data_tests', 'name_tests', 'menu_flow_tests', 'mode_tests', 'lobby_tests', 'compact_control_tests', 'input_ownership_tests', 'display_tests', 'ghost_transaction_tests', 'binding_tests', 'binding_ui_tests', 'menu_repeat_tests', 'result_receipt_tests', 'touch_layout_tests', 'touch_editor_tests', 'choice_picker_tests', 'guest_identity_tests', 'guest_service_tests', 'directory_client_tests', 'region_book_tests', 'online_menu_tests', 'identity_reset_ui_tests', 'keyboard_layout_tests', 'menu_scroll_tests', 'retry_flow_tests', 'world_presentation_tests', 'loading_flow_tests']


def main():
    reports = ROOT/'reports'
    reports.mkdir(exist_ok=True)
    (reports/'.gdignore').touch()
    commands = [[sys.executable,'tools/validate_content.py'], [sys.executable,'tools/bake_tracks.py','--check'],
                [sys.executable,'tools/content_hash.py','--check'],
                [sys.executable,'-m','unittest','discover','-s','tests','-p','test_*.py'],
                [sys.executable,'tools/godot.py','--headless','--editor','--import','--quit']]
    commands += [[sys.executable,'tools/godot.py','--headless','--fixed-fps','60','--script',f'tests/{suite}.gd', '--', '--profile=ci_tests'] for suite in SUITES]
    commands.append([sys.executable,'tools/godot.py','--headless','--max-fps','60','--script','tests/leave_delivery_tests.gd'])
    results = []
    for command in commands:
        started = time.monotonic()
        try:
            result = subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=120)
            output = result.stdout+result.stderr
            passed = result.returncode == 0
        except subprocess.TimeoutExpired:
            output,passed = 'Timed out after 120 seconds',False
        label = ' '.join(command[1:])
        print(('PASS ' if passed else 'FAIL ')+label,flush=True)
        print(output[-1000:],end='' if output.endswith('\n') else '\n',flush=True)
        results.append({'suite':label,'passed':passed,'seconds':round(time.monotonic()-started,3),'output':output[-4000:]})
    report = {'platform':platform.system()+'-'+platform.machine(), 'engine':'4.6.3-stable',
              'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              'passed':all(r['passed'] for r in results),'results':results}
    (reports/'checks.json').write_text(json.dumps(report,indent=2)+'\n')
    raise SystemExit(0 if report['passed'] else 1)


if __name__ == '__main__':
    main()
