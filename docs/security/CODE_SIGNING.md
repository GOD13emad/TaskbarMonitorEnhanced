# Code Signing — Taskbar Monitor Enhanced

## Current signing identity

The repository includes only the PUBLIC certificate for the local DEVELOPMENT Authenticode identity.

- Subject: CN=Taskbar Monitor Enhanced Development Code Signing
- Thumbprint: 4673165CCB579F868EFE5F52FCDA761780F49989
- Algorithm: RSA / SHA-256
- EKU: Code Signing (1.3.6.1.5.5.7.3.3)
- Private key: Windows CurrentUser\My certificate store on the signing workstation only
- Private-key export: not performed
- Public trust: NOT publicly trusted; this is a self-signed development certificate
- Public certificate: docs/security/TaskbarMonitorEnhanced_Development_CodeSigning.cer

The development certificate proves the Authenticode signing pipeline and signer identity on the controlled workstation. It does NOT make Windows SmartScreen or arbitrary external Windows installations trust the publisher.

## Security rules

1. Never commit or publish PFX, P12, PVK, private key, recovery secret, or certificate password.
2. Never install the development self-signed certificate into Trusted Root Certification Authorities merely to make a test appear publicly trusted.
3. The immutable v1.1.2 release must not be modified or re-uploaded. Authenticode signing changes executable bytes and SHA-256 hashes.
4. A publicly trusted signed release must use a CA-issued Code Signing certificate or an approved managed signing service.
5. Production signing should use RFC3161 timestamping.

## Signing tool

`build/signing/Sign-Authenticode.ps1` signs one or more files using a certificate thumbprint from CurrentUser\My. It uses SHA-256 for the Authenticode digest and supports an optional RFC3161 timestamp URL.

Example:

`pwsh -File build/signing/Sign-Authenticode.ps1 -Thumbprint <CA_CERT_THUMBPRINT> -TimestampUrl <RFC3161_URL> -Path <file>`

## Verification tool

`build/signing/Verify-Authenticode.ps1` verifies that the file is signed, that the Authenticode hash is intact, and—when provided—that the signer thumbprint matches the expected identity.

For this self-signed development identity only, use `-AllowUntrustedDevelopment`. This permits the expected untrusted-chain status but does not convert the certificate into a publicly trusted publisher.

## Production release order

For the next signed release:

1. Build deterministic Main, Broker, and Supervisor binaries.
2. Authenticode-sign those binaries using the CA-issued production identity and an RFC3161 timestamp.
3. Verify signer thumbprint, trust, timestamp, and signed SHA-256 for every binary.
4. Package the already-signed binaries into the installer.
5. Sign the installer last and timestamp it.
6. Verify installed signed binary hashes.
7. Generate final SHA256SUMS and SPDX SBOM from the signed payload.
8. Run the required deterministic/equivalence/runtime regressions.
9. Run GitHub provenance/SBOM attestation.
10. Publish a NEW release version. Never move or rewrite v1.1.2.

## Public-trust upgrade gate

Development signing is ready. Publicly trusted Publisher identity remains blocked on obtaining a CA-issued Code Signing certificate or an approved managed signing identity. When that identity is available, replace the signing identity source/thumbprint and retain all verification gates.
