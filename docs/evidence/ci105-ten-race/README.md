# Build 105 long-soak coverage failure

Commit `0aa032b`, content 7, workflow 39369832275. All other jobs pass; this job fails and publication is skipped. Build 105 is not released.

Ten real impaired eight-client races finish all 80 cars with identical authoritative results. Worst clear p95 is 0.0368153 m, memory peak 136,736,768 bytes and post-warm-up growth 2.6633%. Wire limits, late-course snapshots, bounded controls and engine logs pass. Clear-coverage fails for two cars in race 5 (Palm Bay): clients 2/6 record only 257/300 clear samples, with 2,851/2,829 contact-classified samples. Required minimum remains 500 per client/race. Low measured corrections cannot replace the missing clear population.

The original complete summary, all clients, logs, fixture hashes and failure trace are retained. This run used the prior index-ordered half-second launch holds, normal Medium shared-controller clients and four car types. The follow-up harness uses public baked target-speed estimates for fastest-first one-second brake-only holds, keeps the 500-sample requirement and normal finish grace, and explicitly verifies all eight shared release plans. Production collision/physics/population classification and numeric acceptance limits remain unchanged. That follow-up must pass separately.
