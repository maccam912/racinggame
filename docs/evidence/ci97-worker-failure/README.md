# Exported Linux worker coverage failure

Build 97, commit `93e6410`, GitHub Actions run `39352039713`, native server job
`118401549096`. The actual exported Linux x86-64 worker completes two three-lap
races through eight independent 50±20 ms / 1% datagram-loss proxies. All 16
finishes and complete client result rows agree; worst moving clear correction
p95 is 0.040763 m. No engine error or DNF is reported.

The gate correctly fails: client 6 has only **460** moving clear-road samples in
race 1, below the unchanged minimum 500. Client 4 has only 502. Their contact
populations are 2,559 and 2,525, respectively. The driver harness is being adjusted
to hold ordinary brake-only input for index × 30 input ticks after GO (0–3.5 s),
then use the same snapshot-informed paced driver. Cars are not relocated and the
finish grace, physics, correction definitions, 500 minimum and .25 m p95 cap are
unchanged. Changes to this harness now require the full ten-race soak in CI.

These are original failed reports and logs, preserved without rewriting their
measurements. The new fixture's results are separate evidence. No Build 97
release was published.
