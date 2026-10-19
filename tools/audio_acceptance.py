#!/usr/bin/env python3
"""Measure actual game output true peak and decoded asset loop boundaries."""
import argparse
from array import array
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]

def measure(path):
    result=subprocess.run(['ffmpeg','-hide_banner','-nostats','-i',str(path),'-af','loudnorm=I=-18:TP=-1:LRA=8:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
    return json.JSONDecoder().raw_decode(result.stderr[result.stderr.rfind('{'):])[0]

def loops():
    rows=json.loads((ROOT/'assets/exported/audio/catalog.json').read_text())['assets']
    result=[]
    for row in rows:
        if not row['loop']: continue
        decoded=subprocess.check_output(['ffmpeg','-v','error','-i',str(ROOT/row['path']),'-f','f32le','-'])
        data=array('f');data.frombytes(decoded)
        channels=row['channels']
        # Compare the actual decoded wrap step with adjacent waveform steps at
        # both ends. This catches synthesis/encoding discontinuities, not melody.
        wrap=max(abs(data[ch]-data[-channels+ch]) for ch in range(channels))
        edges=list(data[:4096])+list(data[-4096:])
        steps=sorted(abs(edges[i]-edges[i-channels]) for i in range(channels,len(edges)))
        reference=steps[int(len(steps)*.99)]
        assert wrap<=max(.015,reference*3),(row['id'],wrap,reference)
        result.append({'id':row['id'],'decoded_wrap_step':wrap,'edge_step_p99':reference})
    return result

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--capture',action='store_true');parser.add_argument('--native-output',action='store_true');args=parser.parse_args()
    if args.capture:
        options=['--fixed-fps','60','--write-movie','res://reports/audio-game-native.avi'] if args.native_output else ['--headless','--max-fps','60']
        arguments=['--profile=audio_mix_evidence']+(['--movie','--capture=res://reports/audio-game-native.png'] if args.native_output else [])
        subprocess.run([sys.executable,'tools/godot.py',*options,'--script','tests/audio_game_mix_evidence.gd','--',*arguments],cwd=ROOT,check=True,timeout=150)
    report=json.loads((ROOT/'reports/audio-game-mix.json').read_text())
    report['measurement']=measure(ROOT/'reports/audio-game-mix.wav')
    report['true_peak_dbfs']=float(report['measurement']['input_tp'])
    report['asset_hash']=json.loads((ROOT/'assets/checksums.json').read_text())['asset_hash']
    report['decoded_loops']=loops()
    if args.native_output:
        output=ROOT/'reports/audio-game-native.avi'
        report['final_output_measurement']=measure(output)
        probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(output)],text=True))
        duration=float(probe['format']['duration'])
        result=subprocess.run(['ffmpeg','-hide_banner','-nostats','-ss',str(duration-.5),'-i',str(output),'-vn','-af','volumedetect','-f','null','-'],capture_output=True,text=True,check=True)
        # PCM movie output is taken after the Master fader/mute.
        assert 'max_volume: -91.0 dB' in result.stderr or 'max_volume: -inf dB' in result.stderr,result.stderr
        report['final_output_master_muted']=True
        report['final_output_true_peak_dbfs']=float(report['final_output_measurement']['input_tp'])
        assert report['final_output_true_peak_dbfs']<=-1
    report['passed']=report['true_peak_dbfs']<=-1 and report['all_channels_muted_peak']<.0001
    (ROOT/'reports/audio-game-acceptance.json').write_text(json.dumps(report,indent=2)+'\n')
    assert report['passed'],report
    print('ACTUAL_GAME_MIX_TRUE_PEAK_PASS',report['true_peak_dbfs'],'dBFS',report['frames'],'frames')

if __name__=='__main__': main()
