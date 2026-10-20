from pathlib import Path
import subprocess,json,time
ROOT=Path(__file__).resolve().parent
ADB=[str(Path.home()/'Library/Android/sdk/platform-tools/adb'),'-s','emulator-5580']
def shell_events(rows):
    script='set -e\n'+'\n'.join('sendevent /dev/input/event1 %d %d %d'%tuple(row) for row in rows)+'\n'
    subprocess.run([*ADB,'shell','sh','-s'],input=script,text=True,check=True)
def down(points):
    rows=[]
    for slot,(x,y) in enumerate(points):
        raw_x=round((1080-y)*32767/1080)
        raw_y=round(x*32767/2400)
        rows += [[3,47,slot],[3,57,1160+slot],[3,53,raw_x],[3,54,raw_y],[3,58,512]]
    rows += [[1,330,1],[0,0,0]]
    shell_events(rows)
    return rows
def up(count):
    rows=[]
    for slot in range(count):rows += [[3,47,slot],[3,57,-1],[3,58,0]]
    rows += [[1,330,0],[0,0,0]]
    shell_events(rows)
    return rows
def shot(name):
    (ROOT/name).write_bytes(subprocess.check_output([*ADB,'exec-out','screencap','-p']))
if __name__=='__main__':
    rows=down([(700,560)])
    try:
        time.sleep(.2)
        shot('kernel-single-held.png')
        (ROOT/'kernel-single-held-input.txt').write_bytes(subprocess.check_output([*ADB,'shell','dumpsys','input']))
    finally:released=up(1)
    time.sleep(.5)
    shot('after-kernel-quick.png')
    (ROOT/'kernel-single-events.json').write_text(json.dumps({'screen_points':[[700,560]],'down':rows,'up':released},indent=2)+'\n')

def release_slots(slots, remaining):
    rows=[]
    for slot in slots:rows += [[3,47,slot],[3,57,-1],[3,58,0]]
    rows += [[1,330,1 if remaining else 0],[0,0,0]]
    shell_events(rows)
    return rows
