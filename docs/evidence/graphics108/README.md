# Long-course construction deadline and retained graphics evidence

Build 107's strict Linux render job passes all preceding steps, then the GPU-preparation fixture times out while Quarry is still constructing at stage 81 of 90 after 60 seconds. No warmer exists yet; graphics_error=false. Its original job log, prior fixture and pending parent status are retained. This is a construction-fixture failure; publication stays blocked regardless of other jobs.

The fixture now allows max(60 seconds, (authored construction steps + 4 frame allowance) × 1 second). Skyline has 70 units / 74 seconds; Quarry 90 / 94. Every case records actual construction duration, unit count, cap and allowance. The GPU/readback stage keeps its independent 15-second deadline, two drawn frames, real readback, Retry/Cancel/background and real ENet Loaded ordering. Production loading and all gameplay/performance limits remain unchanged. The manual diagnostic job allows 20 minutes for the complete eight-course plus error/ENet matrix; individual stage bounds still apply.

The deliberately slow native probe is retained under ../city108: Citrus at 3 fps takes 16.984 seconds within its 60-second bound; Quarry at 1 fps takes 90.985 seconds within 94 seconds, exceeding the old fixed bound. Both then complete genuine GPU preparation. The final fixture with incremental reporting passes all eight native worlds and readback/error/readiness cases.

Reports now clear stale success at startup, record a unique run ID, exact fixture SHA-256 and content/asset identities, preserve each completed course immediately and write failure-stage state on timeout. Only full completion sets passed=true. The final native report is complete; Linux confirmation and full release publication remain separate pending gates.
