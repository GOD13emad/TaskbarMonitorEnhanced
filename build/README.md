# R21 reproducible build

Build-R21.ps1 is the authoritative local and CI build path for the 1.1.2-rc10 R21 candidate.

It performs the following gates:

dependencies.lock.json is the single source of truth for upstream dependency versions, URLs and SHA-256 values.

1. Downloads LibreHardwareMonitor 0.9.6 and PawnIO 2.2.0 only from their official GitHub release URLs.
2. Verifies the pinned SHA-256 of both dependency artifacts before extraction or use.
3. Builds the main application, isolated sensor broker, and supervisor as x64 .NET Framework 4.8 binaries.
   Release projects explicitly enable deterministic/CI compilation and omit absolute PDB path metadata from production PE files.
4. Builds the setup executable from those exact outputs.
5. Runs setup /verify and requires 19 embedded resources.
6. Runs the application self-test.
7. Writes artifacts/R21_BUILD_MANIFEST.json with dependency provenance and output SHA-256 values.

Pinned dependencies:

- LibreHardwareMonitor 0.9.6
  SHA-256: 086D9F1B5A99E643EDC2CFAAAC16051685B551E4C5AC0B32A57C58C0E529C001
- PawnIO 2.2.0
  SHA-256: 1F519A22E47187F70A1379A48CA604981C4FCF694F4E65B734AAA74A9FBA3032

global.json pins .NET SDK 10.0.400 with latest-patch roll-forward.

For an offline rebuild after a successful dependency fetch:

    ./build/Build-R21.ps1 -NoDownload

The dependency cache and all outputs are ignored by Git. The build definitions, icon, hashes and build script are tracked.

Deterministic verification:

    ./build/Verify-Determinism.ps1

This creates a separate clean Git clone, reuses only the verified dependency cache, rebuilds all release binaries and requires every output SHA-256 to match the primary build.
