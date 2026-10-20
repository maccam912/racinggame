#!/usr/bin/env python3
"""Live graphical scene-cycle and memory measurement on the current desktop."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import shutil
import subprocess
import time
import uuid
from bootstrap import ROOT, engine
from content_hash import compute as gameplay_manifest
from asset_hash import compute as cosmetic_manifest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--seconds', type=int, default=900)
    args = parser.parse_args()
    assert platform.system() in ['Darwin','Linux'] and 1<=args.seconds<=3600
    folder = ROOT/'reports'/('render-soak-'+uuid.uuid4().hex[:10])
    folder.mkdir(parents=True)
    profile = 'render_soak_'+uuid.uuid4().hex[:12]
    manifest, cosmetics = gameplay_manifest(), cosmetic_manifest()
    assert manifest==json.loads((ROOT/'game/content/compatibility.json').read_text())
    assert cosmetics==json.loads((ROOT/'assets/checksums.json').read_text())
    script = ROOT/'tests/render_soak_evidence.gd'
    report = {'passed':False,'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              'working_tree_dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True)),
              'platform':platform.platform(),'requested_seconds':args.seconds,'profile':profile,
              'content_hash':manifest['content_hash'],'asset_hash':cosmetics['asset_hash'],
              'fixture_sha256':hashlib.sha256(script.read_bytes()).hexdigest(),
              'boundary':'Live native source rendering at 1920x1080 Medium/60 cap, eight-course repeated eight-car races. RSS includes renderer/audio/scene resources. This host can have other applications/emulators active; no minimum-device, physical thermal or standalone worst-track budget claim.'}
    process = None
    observations = []
    began = time.monotonic()
    try:
        with (folder/'native.log').open('w') as log:
            command = [str(engine()),'--path',str(ROOT),'--resolution','1920x1080',
                       '--script',str(script),'--','--autodrive','--profile='+profile,
                       '--capture-frame=1000000000','--capture='+str(folder/'unused.png'),
                       '--seconds='+str(args.seconds),'--report='+str(folder/'native.json')]
            process = subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
            while process.poll() is None:
                elapsed = time.monotonic()-began
                if elapsed>args.seconds+240: raise TimeoutError('Live renderer did not finish its current race before the deadline')
                result = subprocess.run(['ps','-o','rss=','-p',str(process.pid)],capture_output=True,text=True)
                if result.returncode==0 and result.stdout.strip().isdigit():
                    rss = int(result.stdout.strip())*1024
                    observations.append({'elapsed_seconds':elapsed,'rss_bytes':rss})
                    assert rss<=4*1024**3, 'Owned fixture exceeded the 4 GiB runaway guard'
                text = (folder/'native.log').read_text()
                assert not any(marker in text for marker in ['SCRIPT ERROR:','ERROR:','instances leaked']), 'Renderer error; inspect preserved native log'
                time.sleep(1)
            assert process.returncode==0, 'Native renderer exited unsuccessfully'
        native = json.loads((folder/'native.json').read_text())
        assert native['passed'] and native['final'] and native['elapsed_seconds']>=args.seconds
        report['native'] = native
        memory = {'peak_rss_bytes':max(row['rss_bytes'] for row in observations),'growth_measured':False}
        if args.seconds>=900:
            baseline = next(row for row in observations if row['elapsed_seconds']>=300)
            end = next(row for row in observations if row['elapsed_seconds']>=900)
            warm = max(row['rss_bytes'] for row in observations if row['elapsed_seconds']<=baseline['elapsed_seconds'])
            peak = max(row['rss_bytes'] for row in observations if baseline['elapsed_seconds']<=row['elapsed_seconds']<=end['elapsed_seconds'])
            memory.update(growth_measured=True,baseline=baseline,end=end,warmup_peak_rss_bytes=warm,
                          post_warmup_peak_rss_bytes=peak,peak_growth_fraction=peak/warm-1,
                          retained_growth_fraction=end['rss_bytes']/baseline['rss_bytes']-1,
                          scope='All scene/loading transition peaks retained, 5–15 minute repeated-course high-water comparison. Separate from a continuous worst-track hardware test.')
        metrics = native['racing_frame_times']
        checks = {'normal_complete_races':bool(native['races']),
                  'racing_frames_recorded':metrics['samples']>0,
                  'desktop_rss_under_2GB':memory['peak_rss_bytes']<=2_000_000_000,
                  'source_unchanged':gameplay_manifest()==manifest and cosmetic_manifest()==cosmetics,
                  'engine_log':not any(marker in (folder/'native.log').read_text() for marker in ['SCRIPT ERROR:','ERROR:','instances leaked'])}
        if args.seconds>=900:
            checks['rss_growth_at_most_5percent'] = memory['peak_growth_fraction']<=.05
            checks['all_catalog_courses'] = {row['track'] for row in native['races']}=={row['id'] for row in json.loads((ROOT/'game/content/tracks.json').read_text())['tracks']}
        # Report timing independently: host contention does not become a passing
        # minimum-device claim or get hidden by the lifetime/memory verdict.
        report.update(memory=memory,checks=checks,passed=all(checks.values()),
                      host_frame_budget={'p95_at_most_20ms':metrics['p95_ms']<=20,'p99_at_most_33ms':metrics['p99_ms']<=33})
        assert report['passed'], 'Scene lifetime/memory checks failed; inspect report'
    except BaseException as error:
        report['passed'] = False
        report['failure'] = type(error).__name__+': '+str(error)
        raise
    finally:
        if process and process.poll() is None:
            process.terminate()
            try: process.wait(timeout=5)
            except subprocess.TimeoutExpired: process.kill(); process.wait()
        user_base = (Path.home()/'Library/Application Support/Godot/app_userdata/Pacific Rush') if platform.system()=='Darwin' else Path.home()/'.local/share/godot/app_userdata/Pacific Rush'
        owned_profile = user_base/'diagnostic_profiles'/profile
        # Retain only this invocation's newly named saves for inspection; never
        # remove or alter another profile, including older QA evidence.
        try:
            if owned_profile.exists():
                shutil.move(str(owned_profile),str(folder/'owned-profile'))
                report['owned_profile_archived'] = True
        except OSError as error:
            report['passed'] = False
            report['cleanup_error'] = type(error).__name__+': '+str(error)
            report.setdefault('failure','Could not archive the invocation-owned QA profile')
        report['elapsed_seconds'] = time.monotonic()-began
        report['observations'] = observations
        (folder/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({'passed':report['passed'],'report':str(folder/'summary.json'),'failure':report.get('failure')}),flush=True)
    assert report['passed'], report.get('failure','Live fixture incomplete')


if __name__=='__main__':
    main()
