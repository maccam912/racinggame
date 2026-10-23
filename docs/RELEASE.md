Pacific Rush development checkpoint: eight cars and forty revised courses with
three scales of local road detail, more angular city plans, and additional large
and medium scenery. Trailblazer adds a grippy rally wagon; Corsair adds a fast GT.
Pulse and Meteor each have three two-second boosts per race, with no refill:
Shift, gamepad X/Square, or the touch Boost button. Remaining charges survive
save/resume and network snapshots. Far Chase and Retro remain the defaults.
See docs/COURSE_ROSTER_40.md for the course roster. Content is 16, protocol 8,
save schema 1; older saves remain archived with incompatible continuation disabled.
This is an incomplete implementation of DESIGN.md.

Desktop packages, Android ARM64 APK/AAB, and Linux dedicated worker are published together with build metadata and SHA-256 checksums. macOS is ad-hoc signed; publisher signing and notarization are pending. Android release-mode packages use a stable development certificate, not a store publisher certificate.

See docs/STATUS.md for implemented milestones and outstanding acceptance gates. Automated exports do not establish physical Android usability, cross-play, performance, public hosting, or launch readiness.

The Linux server ZIP also includes the matching `pacific-directory` operator, build identity, service dependency licenses, Caddy examples and backup/drain runbooks. Public regions remain unconfigured.

The matching Linux OCI runtime is built and published with the platform packages. Its immutable registry reference is appended below by the publisher; region hosting remains operator-configured. Extended tests, including eight-player crash/recovery, graceful stop and the ten-race soak, run separately through the manual **Extra tests and soak** workflow. A published development build does not imply that workflow has passed.
