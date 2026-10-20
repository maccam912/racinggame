# Original paint and pavement materials

Asset identity:
`714139d39e533999be25d7d324a84e3981f229958fb9da7e3ddab2103f1d8b1e`.
Gameplay identity remains
`4eaef43b6dd7efb40414a23b8f84f4f2902417f8e3a9d0d85bbeced354b3e69a`.

Original code-native shaders add car paint dither/flakes, broad illustrated
coating/glass highlights and chrome response; the same surface function serves
ordinary, fade and ghost passes. Dry paving adds aggregate, weathering and
route-aligned tire paths. Fine paint/aggregate detail fades with derivatives.
No external texture or shader sample is an input.

The render-only UV fixture checks every road vertex/normal against the previous
front-face mesh and verifies complete lap/lateral coordinates. Shared collision
inputs, original surface classifications and compatibility identity are unchanged.
Native Compatibility evidence includes 24 posed course views, all four cars,
ghost rendering, remote brake lamps and nine actually submitted shader paths
across six worlds. Loading, failed readback/Retry, Cancel and real ENet Loaded
ordering pass locally. These are source-renderer results, not a new APK, other
GPU, human driving, frame-budget or minimum-hardware claim.

`failures/` keeps the first shader-signature failure: the shared surface helper
was updated before its ghost caller. The ghost call is corrected and its native
follow-up passes. A first coarse road-grain preview was toned down before the
final 24 images and their hash-bearing manifest were captured.

The strict Linux release graphics gate remains a separate open investigation.
Build 101 passed the first sixteen commands and all exports, then repeated the
shader-fixture failure. Extra loader-state traces and a focused Linux diagnostic
workflow investigate it without publishing or weakening the release gate.
