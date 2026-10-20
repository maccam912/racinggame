# Separate construction and GPU deadlines

The focused GitHub-hosted Linux diagnostic reproduced the failure with complete
loader-state traces. Palm Bay constructed, waited under the foreground guard,
then submitted two real frames and read back 103 draw calls successfully. Citrus
then reached only construction stage 39 of 48 before the fixture's shared
15-second deadline expired. The guard was valid and false, `done=false`,
`graphics_error=false`, and no shader warmer existed yet. This identifies slow
world construction on llvmpipe; the earlier missed-phase explanation was not
confirmed by the trace. The complete failed job log is preserved here.

The fixture now permits at most 60 seconds for construction to reach graphics
preparation, and retains 15 seconds for the subsequent GPU/readiness stage.
It still requires held-background behavior, real submitted variants, at least
two drawn frames, a 256-pixel readback, Retry/Cancel and real ENet Loaded ordering.
Timeout returns a Boolean to an assertion in the calling fixture, preventing
follow-on access to a nonexistent warmer after the original failure.

Production loading code, frame counts, readback checks, authority behavior and
performance acceptance limits are unchanged. This is a correctness fixture with
a software-renderer construction allowance, not a new loading-speed target.
Native follow-up and corrected Linux diagnostics are separate evidence files.

The explicit slow-construction probe sets the engine cap to 3 **after** settings
for Citrus only, restores the original cap before GPU readiness, and asserts
that construction exceeds the old 15-second limit. Its report records the actual
cap and elapsed construction time. An earlier `--max-fps 3` launch-only run was
reset to 60 by client settings; its historical filename is not slow-render proof.
