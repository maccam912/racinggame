# Build 92 driving footage

[Palm Bay pace and first climb/drop](palm-bay-speed.mp4) and
[Summit approach, flight and descent](summit-flight.mp4) are native exported-game
recordings with the normal HUD, seven Medium opponents and ordinary diagnostic
AI inputs. The local export embeds clean commit `f6084cf`, content identity
`4eaef43b…` and cosmetic identity `b61a53bf…`; complete metadata is in the end-frame
sidecars and [manifest](manifest.json). The later painted signs have their own
source-render checkpoint.

Godot Movie Maker runs at fixed 60 Hz / 60 fps. The clips preserve simulation
pace; they measure neither live device performance nor human driving preference.
Only the time range and H.264/AAC encoding changed. No scenery, HUD, camera or
vehicle was composited into the footage.

Reproduce from the matching exported executable using a fresh diagnostic profile:

```sh
'Pacific Rush.app/Contents/MacOS/Pacific Rush' --resolution 1280x720 --disable-vsync --write-movie /absolute/path/palm_bay.avi --fixed-fps 60 -- --profile=movie_palm_unique --capture=/absolute/path/palm_bay.png --capture-track=palm_bay --capture-race-tick=1800 --autodrive
ffmpeg -ss 7.5 -i palm_bay.avi -t 28.25 -c:v libx264 -preset medium -crf 23 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart palm-bay-speed.mp4
```

For Summit use `--capture-track=pacific_summit`, a fresh profile/output path,
`--capture-race-tick=3400`, then trim from 46 seconds for 14 seconds. The fixed
loading/countdown frame count can vary, so inspect the HUD clock in any new
recording before selecting its range. Original movie hashes, exact encoded
frame counts and end snapshots are preserved with these clips.
