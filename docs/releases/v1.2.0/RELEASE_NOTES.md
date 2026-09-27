# Taskbar Monitor Enhanced v1.2.0 — Modern Settings & Premium Themes

v1.2.0 is a feature release candidate built on the accepted v1.1.3 startup-resilience baseline and the unchanged accepted 1.1.2+r21 protected sensor layer.

## Fixed

- Hardware hover details are now suppressed while the Settings window is open.
- The Settings-open guard resets hover state and hides any visible hardware flyout, preventing the previously observed stuck hover-detail window.
- A dedicated `--hoverguardproof` regression verifies both mouse-move and watchdog suppression paths.

## Modern Settings

- Replaces the classic tab-strip presentation with a modern left-navigation settings shell.
- Adds clear page titles and descriptions, dark surfaces, consistent spacing, flat controls, and persistent Save & Apply / Cancel actions.
- Adds a live theme palette preview on the Display page.
- Keeps the established WinForms/runtime architecture rather than introducing a new UI framework dependency.
- Adds `--settingsproof <dir>` to render all eight Settings pages for deterministic visual review.

## Premium theme library

The built-in theme library is doubled from 14 to 28 themes.

New themes:
- Aurora Borealis
- Solarized Luxe
- Arctic Frost
- Sakura Night
- Matrix Grid
- Desert Sand
- Royal Amethyst
- Ocean Depth
- Copper Industrial
- Nordic Light
- Ember Forge
- Synthwave Sunset
- Quantum Violet
- Monochrome Paper

The new themes use distinct renderer families (aurora, luxe, zen, synth, matrix, paper, and industrial) rather than simple palette-only copies.

## Preserved architecture

- The exact accepted protected sensor layer remains `1.1.2+r21`.
- CPU/GPU/storage isolation, watchdog supervision, suspend/resume behavior, startup resilience, taskbar integration, update-integrity checks, SBOM generation and provenance controls remain in scope for regression.
- Public v1.1.3 remains immutable and is not retagged or overwritten.

## Candidate qualification gates

v1.2.0 is not a public accepted release until the exact candidate passes: build with zero warnings/errors, Setup /verify, built-in self-test, hover-guard proof, 28-theme live proof, 592/500 px compact proof, 8-page Settings proof, deterministic clean-clone verification, SBOM/provenance checks, installed runtime regression, and exact release-commit GitHub CI.

## Code signing

No publicly trusted Authenticode signature is claimed unless a trusted provider has actually issued and applied one. SignPath Foundation acceptance remains an external gate until independently confirmed.
