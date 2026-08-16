# Source layout

The public repository keeps the installer and sensor-layer sources directly browsable under `installer/` and `src/sensors/`.

The exact corresponding source for each stable release is distributed as an explicit release asset and identified by its published SHA-256. This release asset is the authoritative byte-exact source package used for release acceptance; GitHub's automatically generated `Source code (zip)` and `Source code (tar.gz)` snapshots are repository snapshots and are not the accepted corresponding-source artifact.

For 1.0.2:

- corresponding source asset: `TaskbarMonitorEnhanced_1.0.2_SOURCE.zip`
- SHA-256: `6BC2ED8DA18F5959E9B6780C55ACF204ADC4C41FC7100C1BFEF567E56DE7E571`
- accepted runtime source SHA-256 inside that package: `9FD6EC1C3FF0334EDFE7D66489B1B3C7A12EE165F439E1244DC487358BB687D2`
- accepted installed EXE SHA-256: `4566917DD4CCE686A1B24D2646BC1832EB4910282F6555241457C53E933E1F92`

See `RELEASE_NOTES_v1.0.2.md` and `docs/FINAL_ACCEPTANCE_v1.0.2.md` for the release and lifecycle acceptance record.

The repository preserves upstream attribution and GNU GPL v3.0 licensing. Third-party notices are documented separately.
