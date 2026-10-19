Pacific Rush development checkpoint. This is an incomplete implementation of DESIGN.md.

Desktop packages, Android ARM64 APK/AAB, and Linux dedicated worker are published together with build metadata and SHA-256 checksums. macOS is ad-hoc signed; publisher signing and notarization are pending. Android release-mode packages use a stable development certificate, not a store publisher certificate.

See docs/STATUS.md for implemented milestones and outstanding acceptance gates. Automated exports do not establish physical Android usability, cross-play, performance, public hosting, or launch readiness.

The Linux server ZIP also includes the matching `pacific-directory` operator, build identity, service dependency licenses, Caddy examples and backup/drain runbooks. Public regions remain unconfigured.

The matching Linux OCI runtime is published only after its actual eight-player crash/recovery and graceful-stop gate passes. Its immutable registry reference is appended below by the publisher; region hosting remains operator-configured.
