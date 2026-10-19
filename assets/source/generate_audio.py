"""Original Pacific Rush music, engines, effects and synthetic arcade prompts.

Authoring only: Python 3.14.7, NumPy 2.5.2, ffmpeg 9.0.1 and oggenc 1.4.3.
No recordings, downloaded songs, voice models or third-party sample banks.
Formant-resonator background: Klatt 1980, doi:10.1121/1.383940.
All arrangements, timbres, phoneme trajectories and source code here are original.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/exported/audio'
WORK=ROOT/'build/audio-authoring'
RATE=44100
TAU=math.tau
SONGS=[
    ('palm_bay','Boardwalk Morning',132,55,'major','surf',[0,0,5,5,3,3,4,4,0,0,2,2,3,4,4,4], [9,7,5,4,5,9,11,9,7,5,4,2,4,5,7,5]),
    ('citrus_pass','Orange Afternoon',138,50,'major','breakbeat',[0,3,0,4,5,3,0,4,0,3,2,5,3,4,0,4],[4,7,9,7,5,4,2,4,7,9,12,11,9,7,5,2]),
    ('marina_lights','Tidal Arcade',130,57,'minor','synth',[0,0,5,5,2,2,6,6,0,3,5,6,2,5,6,6],[0,4,7,11,9,7,4,2,4,7,9,12,11,7,5,2]),
    ('redwood_run','Canopy Light',128,52,'minor','surf',[0,0,3,3,5,5,6,6,0,0,2,2,3,5,6,6],[7,4,2,0,2,4,7,9,7,5,4,2,4,5,7,4]),
    ('sunstone_canyon','Mesa Motion',142,48,'minor','breakbeat',[0,0,6,6,5,5,3,6,0,0,2,2,5,3,6,6],[0,2,4,7,6,4,2,0,4,7,9,7,6,4,2,4]),
    ('pacific_summit','Golden Descent',136,57,'major','synth',[0,4,5,3,0,4,3,4,0,2,5,3,0,3,4,4],[7,9,11,14,12,11,9,7,5,7,9,11,12,11,9,7]),
    ('menu','Coastline Invitation',128,55,'major','menu',[0,0,5,5,3,3,4,4,0,2,5,3,0,3,4,4],[4,7,9,7,5,4,2,4,7,9,7,5,4,2,0,2])]
MANIFEST=[]


def midi(note): return 440*2**((note-69)/12)
def times(seconds): return np.arange(max(1,round(seconds*RATE)),dtype=np.float64)/RATE


def envelope(t,duration,attack=.006,release=.08,decay=1):
    return np.minimum(1,t/max(attack,1/RATE))*np.minimum(1,np.maximum(0,duration-t)/max(release,1/RATE))*np.exp(-decay*t/max(duration,.01))


def instrument(note,duration,kind):
    t=times(duration); frequency=midi(note)
    phase=TAU*frequency*t
    if kind=='guitar':
        signal=sum(np.sin(phase*h+.025*h*np.sin(TAU*5.4*t))/h**1.25*np.exp(-t*h*1.6) for h in range(1,15))
        signal=np.tanh(signal*1.5)*(1+.07*np.sin(TAU*7*t))
        env=envelope(t,duration,.002,.09,1.3)
    elif kind=='bass':
        signal=np.sin(phase)+.22*np.sin(2*phase)+.09*np.sin(3*phase)
        env=envelope(t,duration,.004,.04,1.2)
    elif kind=='bell':
        signal=np.sin(phase+1.8*np.sin(2*phase)*np.exp(-t*7))+.16*np.sin(3*phase)
        env=envelope(t,duration,.003,.10,2.5)
    else:
        signal=sum(np.sin(phase*h+.04*np.sin(TAU*.7*t))/h**1.7 for h in range(1,8))
        env=envelope(t,duration,.016,.10,.7)
    return (signal*env).astype(np.float32)


def drum(kind,rng):
    duration={'kick':.32,'snare':.23,'hat':.065,'open_hat':.19,'tom':.25}[kind]
    t=times(duration); noise=rng.normal(0,1,t.size)
    if kind=='kick':
        phase=TAU*(45*t+55*(1-np.exp(-t*28))/28)
        signal=np.sin(phase)*np.exp(-t*16)+.08*noise*np.exp(-t*160)
    elif kind=='snare':
        high=noise-np.roll(noise,1)
        signal=.32*high*np.exp(-t*23)+.28*np.sin(TAU*185*t)*np.exp(-t*30)
    elif kind=='tom': signal=np.sin(TAU*(92*t+40*(1-np.exp(-t*20))/20))*np.exp(-t*17)
    else:
        high=noise-np.roll(noise,1)
        signal=high*.13*np.exp(-t*(55 if kind=='hat' else 22))
    return (signal*envelope(t,duration,.001,.015,0)).astype(np.float32)


def add(buffer,signal,start,level=1,pan=0):
    offset=round(start*RATE)%len(buffer)
    left=math.sqrt((1-pan)/2)*level;right=math.sqrt((1+pan)/2)*level
    count=len(signal);first=min(count,len(buffer)-offset)
    buffer[offset:offset+first,0]+=signal[:first]*left
    buffer[offset:offset+first,1]+=signal[:first]*right
    if first<count:
        buffer[:count-first,0]+=signal[first:]*left
        buffer[:count-first,1]+=signal[first:]*right


def master_periodic(buffer,beat):
    # Circular delays preserve the last bar's tails across the loop boundary.
    dry=buffer.copy()
    for delay,gain in [(.137,.11),(.223,.075),(.347,.045)]:
        samples=round((delay+beat*.15)*RATE)
        buffer[:,0]+=np.roll(dry[:,1],samples)*gain
        buffer[:,1]+=np.roll(dry[:,0],samples+127)*gain
    buffer-=buffer.mean(axis=0)
    buffer=np.tanh(buffer*.95)
    buffer*=.70/max(.001,float(np.abs(buffer).max()))
    return buffer.astype(np.float32)


def compose(song):
    identifier,title,bpm,root,mode,style,progression,melody=song
    bars=48 if identifier=='menu' else 80
    beat=60/bpm;duration=bars*4*beat
    output=np.zeros((round(duration*RATE),2),dtype=np.float32)
    rng=np.random.default_rng(52700+sum(map(ord,identifier)))
    scale=[0,2,4,5,7,9,11] if mode=='major' else [0,2,3,5,7,8,10]
    def degree(value):return root+scale[value%7]+12*(value//7)
    drums={kind:drum(kind,rng) for kind in ['kick','snare','hat','open_hat','tom']}
    for bar in range(bars):
        chord=progression[bar%16]
        section=(bar//16)%5
        sparse=style=='menu' or (section==2 and bar%16<8)
        for step in [0,1.5,2,3.5] if style=='breakbeat' else [0,2]:
            add(output,drums['kick'],(bar*4+step)*beat,.42 if not sparse else .29)
        for step in [1,3]: add(output,drums['snare'],(bar*4+step)*beat,.34 if not sparse else .17,.10)
        for step in range(8 if sparse else 16):
            grid=.5 if sparse else .25
            accent=.8 if step%2==0 else .48
            add(output,drums['open_hat' if step==(7 if sparse else 15) and bar%4==3 else 'hat'],(bar*4+step*grid)*beat,.32*accent,-.25 if step%2 else .25)
        if bar%8==7 and not sparse:
            for step in [3.25,3.5,3.75]:add(output,drums['tom'],(bar*4+step)*beat,.23,-.3+step*.15)
        for step in [0,.75,1.5,2,2.75,3.5]:
            bass_note=degree(chord)-12+(7 if step==2.75 and bar%2 else 0)
            add(output,instrument(bass_note,beat*.58,'bass'),(bar*4+step)*beat,.28)
        for step in [.5,1.5,2.5,3.5]:
            for voice,d in enumerate([0,2,4,6]):
                note=degree(chord+d)
                add(output,instrument(note,beat*(.72 if style=='surf' else 1.2),'guitar' if style=='surf' else 'pad'),(bar*4+step)*beat+voice*.008,.105,-.42 if voice%2 else .42)
        if not sparse or bar%2==0:
            for step in range(4):
                pitch=root+12+melody[(bar*2+step+section*3)%len(melody)]
                if section==3 and bar%4==3: pitch+=12
                length=beat*(.62 if step%2 else .88)
                add(output,instrument(pitch,length,'guitar' if style=='surf' else 'bell'),(bar*4+step+.12*(step%2))*beat,.16 if style!='menu' else .11,.12)
    return master_periodic(output,beat),{'title':title,'bpm':bpm,'beats':bars*4,'bars':bars,'duration_seconds':len(output)/RATE,'style':style,'key_root_midi':root,'mode':mode,'loop':True}


def wav(path,signal):
    if signal.ndim==1: signal=signal[:,None]
    data=np.clip(signal,-.999,.999)
    with wave.open(str(path),'wb') as file:
        file.setnchannels(signal.shape[1]);file.setsampwidth(2);file.setframerate(RATE)
        file.writeframes((data*32767).astype('<i2').tobytes())


def analysis(path):
    result=subprocess.run(['ffmpeg','-hide_banner','-nostats','-i',str(path),'-af','loudnorm=I=-18:TP=-3:LRA=8:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
    return json.JSONDecoder().raw_decode(result.stderr[result.stderr.rfind('{'):])[0]


def export(identifier,signal,category,details=None,target=-18,peak=-3):
    path=OUT/(identifier+'.ogg');source=WORK/(identifier+'.wav')
    wav(source,signal)
    measured=analysis(source)
    # R128 has no integrated measurement below its 400 ms gate. Those short
    # transients use their measured oversampled true peak instead.
    integrated=float(measured['input_i'])
    gain=min(target-integrated,peak-float(measured['input_tp'])) if math.isfinite(integrated) else peak-float(measured['input_tp'])
    wav(source,signal*10**(gain/20))
    subprocess.run(['oggenc','--quiet','--serial',str(52700+sum(map(ord,identifier))),'-q','5' if category=='music' else '4','-o',str(path),str(source)],check=True)
    final=analysis(path)
    probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=sample_rate,channels','-of','json',str(path)],text=True))
    final_integrated=float(final['input_i'])
    row={'id':identifier,'category':category,'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'sample_rate':int(probe['streams'][0]['sample_rate']),'channels':probe['streams'][0]['channels'],'duration_seconds':float(probe['format']['duration']),'integrated_lufs':final_integrated if math.isfinite(final_integrated) else None,'true_peak_dbfs':float(final['input_tp']),'loop':False}
    if details: row.update(details)
    MANIFEST.append(row)
    settings=path.with_suffix('.ogg.import')
    if settings.exists():
        values={'loop':str(row['loop']).lower(),'bpm':str(row.get('bpm',0)),'beat_count':str(row.get('beats',0)),'bar_beats':'4'}
        settings.write_text('\n'.join(line.split('=')[0]+'='+values[line.split('=')[0]] if line.split('=')[0] in values else line for line in settings.read_text().splitlines())+'\n')
    source.unlink()
    print('AUDIO_EXPORTED',identifier,row['duration_seconds'],row['integrated_lufs'],row['true_peak_dbfs'],flush=True)


def engine(profile,state):
    base={'comet':64,'needle':72,'switch':60,'sunset':48}[profile]
    t=times(2)
    harmonics={'idle':7,'low':10,'high':16,'coast':6}[state]
    channels=[]
    for width,rate in [(.025,8),(.035,10)]:
        phase=TAU*base*t+width*np.sin(TAU*rate*t)
        signal=sum(np.sin(phase*h)/(h**(1.35 if state!='high' else 1.05)) for h in range(1,harmonics+1))
        signal+=.09*np.sin(TAU*base/2*t)*(1+.3*np.sin(TAU*12*t))
        channels.append(np.tanh(signal*(1.3 if state=='high' else .9)))
    # Periodic phase modulation gives slight width and a shared zero crossing
    # at the encode boundary, avoiding the Vorbis startup-window click.
    stereo=np.column_stack(channels)
    stereo-=stereo.mean(axis=0)
    return (stereo*.50/max(.001,float(np.abs(stereo).max()))).astype(np.float32)


def effect(identifier):
    duration={'asphalt_squeal':2,'sand_rumble':2,'grass_rumble':2,'wall_light':.20,'wall_heavy':.28,'bump':.18,'landing':.30,'recovery':.55,'countdown':.14,'go':.40,'lap':.55,'finish':.80,'ui_move':.06,'ui_confirm':.10,'ui_back':.12,'ui_error':.16,'results':.80}[identifier]
    t=times(duration);rng=np.random.default_rng(1421+sum(map(ord,identifier)));noise=rng.normal(0,1,len(t))
    if identifier=='asphalt_squeal': signal=np.sin(TAU*(1170*t+8*np.sin(TAU*4*t)))+.3*np.sin(TAU*1690*t)+.1*noise
    elif identifier in ['sand_rumble','grass_rumble']:
        spectrum=np.fft.rfft(noise);frequencies=np.fft.rfftfreq(len(t),1/RATE)
        spectrum*=np.exp(-(frequencies/(420 if identifier=='sand_rumble' else 250))**2)
        signal=np.fft.irfft(spectrum,n=len(t))*4+np.sin(TAU*58*t)*.25
    elif identifier.startswith('wall'): signal=(noise-np.roll(noise,1))*.30*np.exp(-t*15)+np.sin(TAU*170*t)*.18*np.exp(-t*24)
    elif identifier in ['bump','landing']: signal=np.sin(TAU*(68*t+14*(1-np.exp(-t*20))/20))*np.exp(-t*20)+noise*.15*np.exp(-t*45)
    elif identifier=='recovery': signal=noise*.16*np.sin(np.pi*t/duration)**2+np.sin(TAU*(330*t+550*t*t))*.3
    else:
        frequencies={'countdown':[660],'go':[880,1100,1320],'lap':[660,880,1100],'finish':[660,880,1100,1320],'ui_move':[780],'ui_confirm':[880,1174],'ui_back':[660,494],'ui_error':[220,207],'results':[523,659,784,1046]}[identifier]
        signal=sum(np.sin(TAU*f*t)*np.exp(-t*7) for f in frequencies)/len(frequencies)
    if identifier not in ['asphalt_squeal','sand_rumble','grass_rumble']:signal*=envelope(t,duration,.002,.025,0)
    signal-=np.mean(signal)
    return (signal*.6/max(.001,float(np.abs(signal).max()))).astype(np.float32),duration==2


# Approximate vowel trajectories are authored for this small, deliberately synthetic voice.
FORMANTS={'ee':(310,2250,3000),'ih':(420,1900,2650),'eh':(570,1750,2500),'ae':(720,1650,2500),'ah':(700,1150,2500),'aw':(570,850,2450),'oh':(480,900,2400),'oo':(350,800,2200),'er':(480,1350,1650),'l':(360,1100,2500),'w':(310,650,2200),'n':(250,1500,2600),'m':(220,1050,2400),'ng':(300,1800,2700)}
PROMPTS={
 'three':('Three',[('th',.11),('er',.075),('ee',.32)]),
 'two':('Two',[('t',.035),('oo',.34)]),
 'one':('One',[('w',.08),('ah',.22),('n',.11)]),
 'go':('Go',[('g',.045),('oh',.26),('oo',.09)]),
 'final_lap':('Final lap',[('f',.09),('ah',.13),('ee',.12),('n',.07),('ah',.075),('l',.07),('_',.07),('l',.07),('ae',.24),('p',.045)]),
 'wrong_way':('Wrong way',[('er',.09),('aw',.24),('ng',.12),('_',.075),('w',.08),('eh',.18),('ee',.11)]),
 'new_best_time':('New best time',[('n',.08),('ee',.065),('oo',.22),('_',.065),('b',.035),('eh',.18),('s',.09),('t',.035),('_',.07),('t',.04),('ah',.13),('ee',.13),('m',.10)]),
 'finish':('Finish',[('f',.10),('ih',.14),('n',.08),('ih',.12),('sh',.14)])}


def prompt(identifier):
    text,phonemes=PROMPTS[identifier]
    chunks=[];rng=np.random.default_rng(892+sum(map(ord,identifier)))
    for i,(phoneme,duration) in enumerate(phonemes):
        t=times(duration)
        if phoneme=='_': signal=np.zeros(len(t))
        elif phoneme in FORMANTS:
            f0=151-24*(i/max(1,len(phonemes)-1))
            phase=TAU*(f0*t+.8*np.sin(TAU*4.2*t)/TAU)
            signal=np.zeros(len(t))
            for h in range(1,40):
                frequency=f0*h
                gain=sum(weight/(1+((frequency-formant)/bandwidth)**2) for formant,bandwidth,weight in zip(FORMANTS[phoneme],[75,105,150],[1,.65,.35]))
                signal+=np.sin(phase*h)*gain/h**.55
            signal*=.8 if phoneme in ['n','m','ng','l','w','er'] else 1
        else:
            noise=rng.normal(0,1,len(t));freq=np.fft.rfftfreq(len(t),1/RATE)
            center={'th':3200,'f':3900,'s':6500,'sh':2900,'t':4300,'g':1700,'p':900,'b':850}[phoneme]
            signal=np.fft.irfft(np.fft.rfft(noise)*np.exp(-((freq-center)/(1500 if phoneme not in ['p','b'] else 600))**2),n=len(t))
            if phoneme in ['t','g','p','b']: signal*=np.exp(-t*95)
            signal*=.23
        signal*=envelope(t,duration,.012,.018,.1)
        chunks.append(signal)
    signal=np.concatenate([np.zeros(round(.025*RATE)),*chunks,np.zeros(round(.08*RATE))])
    signal-=signal.mean()
    return (signal*.65/max(.001,float(np.abs(signal).max()))).astype(np.float32),text


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--only',choices=['music','engines','effects','voice']);args=parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    if not args.only or args.only=='music':
        for song in SONGS:
            samples,details=compose(song);export('music_'+song[0],samples,'music',details,-18,-3)
    if not args.only or args.only=='engines':
        for profile in ['comet','needle','switch','sunset']:
            for state in ['idle','low','high','coast']:
                export('engine_'+profile+'_'+state,engine(profile,state),'engine',{'profile':profile,'state':state,'loop':True},-19,-7)
    if not args.only or args.only=='effects':
        for identifier in ['asphalt_squeal','sand_rumble','grass_rumble','wall_light','wall_heavy','bump','landing','recovery','countdown','go','lap','finish','ui_move','ui_confirm','ui_back','ui_error','results']:
            samples,loop=effect(identifier);export('effect_'+identifier,samples,'effect',{'loop':loop},-20 if identifier.startswith('ui_') else -18,-6)
    if not args.only or args.only=='voice':
        for identifier in PROMPTS:
            samples,text=prompt(identifier);export('voice_'+identifier,samples,'voice',{'text':text,'synthesis':'Original fixed formant/noise trajectories, no speaker recording or voice model'},-18,-5)
    existing=[]
    path=OUT/'catalog.json'
    if args.only and path.exists():
        old=json.loads(path.read_text())['assets']
        ids={row['id'] for row in MANIFEST};existing=[row for row in old if row['id'] not in ids]
    value={'schema_version':1,'creator':'Pacific Rush contributors','license':'MIT','source':'assets/source/generate_audio.py','sample_rate':RATE,'numpy':np.__version__,'ffmpeg':subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0],'assets':sorted(existing+MANIFEST,key=lambda row:row['id'])}
    path.write_text(json.dumps(value,indent=2)+'\n')
    print('PACIFIC_ORIGINAL_AUDIO_EXPORTED',len(value['assets']),flush=True)


if __name__=='__main__': main()
