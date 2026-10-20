# Retained Build115 ten-race clear-coverage failure

[Workflow](https://github.com/maccam912/racinggame/actions/runs/39410650205), clean `1df1e2cb1d159611c460aa644c030ed62ccfd42c`. No release is published (release API 404); the publisher correctly skips. All other required jobs, including the corrected two-lap long-course scenario, pass.

The ten impaired three-lap Palm/Citrus races have **80 matching normal finishes**, every late checkpoint, worst clear p95 **0.0479960 m**, all wire/engine/source checks and **0.981889%** post-warm-up peak RSS growth. The strict failure remains: Palm race 7 yields only **442 / 460 clear samples** for drivers 0 / 6, with **2,694 / 2,708 contact samples**. The unchanged requirement is 500 clear samples per client per race; contact observations cannot substitute. No cleanup issues, **1,912.901 s**. Raw reports, exact fixture sources and logs remain untouched.

The follow-up addresses the actual test-driver platooning through snapshot-based ordinary brake inputs to create physical following gaps. Production handling/AI/contact classification, coverage and correction/wire/finish/memory limits remain unchanged. The new following-gap population must receive its own complete real-UDP acceptance; this original run is not reclassified.
