Pacific Rush development checkpoint: six smooth beginner roads alongside 34
technical courses, with Smooth/Technical filters and road-style labels. Palm Bay,
Citrus Pass, Tundra Pipeline, Saltflat Velocity, Storm Chase and Festival Speedway
have no added road wiggles; Citrus retains its jumps. Eight cars, including Pulse
and Meteor with three two-second boosts, remain available. Hosts can privately
assign Gentle or Strong steering help to individual players. Local Quick Race
and Cup also offer steering help in Accessibility settings. Quick Race's Relaxed
setup chooses a smooth road, one lap, three Easy rivals, no car collisions,
Strong help, corner braking, turn arrows and auto acceleration; review the setup before pressing Start. Far Chase and Retro
remain the defaults. Content/protocol/save versions are 20/9/1; older progress
remains archived with incompatible continuation disabled.
Assisted races allow up to two minutes after the first finish; standard races
retain 30 seconds and the overall ten-minute limit remains. Garage cards include
clickable pictures of all eight actual car models. Quick Race remembers its
setup across restarts; Trial keeps those preferences intact.
This is an incomplete implementation of DESIGN.md.

Desktop packages, Android ARM64 APK/AAB, and Linux dedicated worker are published together with build metadata and SHA-256 checksums. macOS is ad-hoc signed; publisher signing and notarization are pending. Android release-mode packages use a stable development certificate, not a store publisher certificate.

See docs/STATUS.md for implemented milestones and outstanding acceptance gates. Automated exports do not establish physical Android usability, cross-play, performance, public hosting, or launch readiness.

The Linux server ZIP also includes the matching `pacific-directory` operator, build identity, service dependency licenses, Caddy examples and backup/drain runbooks. Public regions remain unconfigured.

The matching Linux OCI runtime is built and published with the platform packages. Its immutable registry reference is appended below by the publisher; region hosting remains operator-configured. Extended tests, including eight-player crash/recovery, graceful stop and the ten-race soak, run separately through the manual **Extra tests and soak** workflow. A published development build does not imply that workflow has passed.
