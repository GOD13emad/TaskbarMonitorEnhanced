# Reproducible build

Build.ps1 is the authoritative local and CI build path for the unreleased v1.7.0 candidate, retaining the protected sensor architecture and an optional external official PawnIO driver.

It performs the following gates:

dependencies.lock.json is the single source of truth for upstream dependency versions, URLs and SHA-256 values.

1. Verifies pinned LibreHardwareMonitor 0.9.6 and PawnIO 2.2.0 dependency provenance from upstream URLs. The official PawnIO binary is retained in the builder cache for historical compatibility only; it is not bundled or silently installed by v1.7 OSS Setup.
2. Verifies the pinned SHA-256 of both dependency artifacts before extraction or use.
3. Builds the main application, isolated sensor broker, and supervisor as x64 .NET Framework 4.8 binaries.
   Release projects explicitly enable deterministic/CI compilation and omit absolute PDB path metadata from production PE files.
4. Builds the setup executable from those exact outputs.
5. Runs setup /verify and requires exactly 25 OSS embedded resources; PawnIOBundled must be false for the SignPath-eligible release.
6. Runs the legacy, feature-contract and workspace model-regression suites using actual child-process exit codes.
7. Writes artifacts/BUILD_MANIFEST.json with dependency provenance and output SHA-256 values.

Pinned dependencies:

- LibreHardwareMonitor 0.9.6
  SHA-256: 086D9F1B5A99E643EDC2CFAAAC16051685B551E4C5AC0B32A57C58C0E529C001
- PawnIO 2.2.0
  SHA-256: 1F519A22E47187F70A1379A48CA604981C4FCF694F4E65B734AAA74A9FBA3032

global.json pins .NET SDK 10.0.400 with latest-patch roll-forward.

For an offline rebuild after a successful dependency fetch:

    ./build/Build.ps1 -NoDownload

The dependency cache and all outputs are ignored by Git. The build definitions, icon, hashes and build script are tracked.

Deterministic verification:

    ./build/Verify-Determinism.ps1

This creates a separate clean Git clone, reuses only the verified dependency cache, rebuilds all release binaries and requires every output SHA-256 to match the primary build.
