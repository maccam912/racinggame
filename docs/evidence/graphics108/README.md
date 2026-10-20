# Long-course construction deadline and retained graphics evidence

Build 107's strict Linux render job passes all preceding steps, then the GPU-preparation fixture times out while Quarry is still constructing at stage 81 of 90 after 60 seconds. No warmer exists yet; graphics_error=false. Its original job log, prior fixture and pending parent status are retained. This is a construction-fixture failure; publication stays blocked regardless of other jobs.

The fixture now allows max(60 seconds, (authored construction steps + 4 frame allowance) × 1 second). Skyline has 70 units / 74 seconds; Quarry 90 / 94. Every case records actual construction duration, unit count, cap and allowance. The GPU/readback stage keeps its independent 15-second deadline, two drawn frames, real readback, Retry/Cancel/background and real ENet Loaded ordering. Production loading and all gameplay/performance limits remain unchanged. The manual diagnostic job allows 20 minutes for the complete eight-course plus error/ENet matrix; individual stage bounds still apply.

The deliberately slow native probe is retained under ../city108: Citrus at 3 fps takes 16.984 seconds within its 60-second bound; Quarry at 1 fps takes 90.985 seconds within 94 seconds, exceeding the old fixed bound. Both then complete genuine GPU preparation. The final fixture with incremental reporting passes all eight native worlds and readback/error/readiness cases.

Reports now clear stale success at startup, record a unique run ID, exact fixture SHA-256 and content/asset identities, preserve each completed course immediately and write failure-stage state on timeout. Only full completion sets passed=true. The final native report is complete; Linux confirmation and full release publication remain separate pending gates.


Build 107 subsequently finishes with only the render job failed. Its separate full ten-race staged soak passes all 80 matching finishes, minimum 2,038 clear samples, worst clear p95 0.0364678 m and zero measured post-warm-up worker RSS growth. Complete raw soak evidence is retained under ci107-soak-pass. The parent run is failed and publishes no release; this does not substitute for the corrected graphics/release run.

The focused Linux diagnostic (`39379722228`) passes on `958478a`; complete raw metadata, log and GPU images are under `linux-diagnostic/`. Skyline construction is 10,654 ms within 74,000 ms; Quarry 35,045 ms within 94,000 ms, with actual two-frame/readback completion. Build 108's separate required full render job (`118487779380`) and complete 40-job parent workflow pass. All 18 packages are published; complete release and ten-race proof is under `../release108/`.
