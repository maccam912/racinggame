# Initial city-108 scene-lifetime run — memory gate failed

Clean source `958478afcb986e6b38597108958644be08ea44cd`, content 8 and asset `f84503f5`. All 12 ordinary eight-car races completed. Peak RSS 815,464,448 bytes; 5–15 minute peak growth **9.343%**, exceeding the unchanged 5% gate. The full summary remains `passed: false`. Racing frame p95/p99 were 18.357/18.878 ms.

The first eight-course cycle lasts about 638 seconds. The five-minute warm-up sees only the first four completed courses; the later highest peak is near the first Skyline load at 425 seconds. End RSS falls below the instantaneous baseline. These observations do not prove a leak or excuse the failed gate. A separately reported heavy-course repeat exercises Skyline and Quarry before minute five; its result must be evaluated independently.

This is this Mac's live source renderer, Dummy audio, Medium/60 cap at 1920×1080, with other processes/emulators present. No minimum-hardware or physical thermal acceptance is claimed.
