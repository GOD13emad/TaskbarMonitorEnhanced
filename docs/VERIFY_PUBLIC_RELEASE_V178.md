# Independently verify Taskbar Monitor Enhanced v1.7.8

**Scope:** [Official v1.7.8 release](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.7.8), Windows installer TaskbarMonitorEnhanced_Setup_1.7.8.exe.

This checks the exact released file bytes and their SLSA/Sigstore source-signing provenance. It does **not** give the program Windows Authenticode publisher trust. Windows reports this historical release as **NotSigned**. It does not establish SmartScreen / Smart App Control reputation.

## Immutable identifiers

| Property | Required value |
| --- | --- |
| Size | 8565760 bytes |
| SHA-256 | 4db3c03ac7ab70b3d3123a365c156e71370f0338991b399b99169a4b5b5f8b75 |
| Repository | GOD13emad/TaskbarMonitorEnhanced |
| Trusted workflow | GOD13emad/TaskbarMonitorEnhanced/.github/workflows/ci.yml |
| Actual workflow source ref | refs/heads/main |
| Exact source commit and release tag target | 9960a06dba606d1c93b8ca2b84e0e3e25ca4f68d |
| Public release tag | v1.7.8 |
| Predicate | https://slsa.dev/provenance/v1 |
| Runner policy | GitHub-hosted only; no self-hosted runner |

The producer ran on **main**, which contained the release-tag commit; do not replace the recorded source ref with a tag ref.

## Verify locally on Windows

1. Download the EXE from the linked official release, but **do not run it**.
2. Check its size, SHA-256 and separate Authenticode status using Windows PowerShell:

~~~powershell
(Get-Item -LiteralPath 'C:\path\TaskbarMonitorEnhanced_Setup_1.7.8.exe').Length
(Get-FileHash -LiteralPath 'C:\path\TaskbarMonitorEnhanced_Setup_1.7.8.exe' -Algorithm SHA256).Hash
Get-AuthenticodeSignature -LiteralPath 'C:\path\TaskbarMonitorEnhanced_Setup_1.7.8.exe' | Select-Object Status
~~~

Expect the exact size and SHA-256 above and Authenticode **NotSigned**. A different digest is an immediate STOP, even if the EXE has the expected name.

3. Obtain GitHub CLI **2.102.0 or newer** because of the patched signer-workflow identity issue [GHSA-wjmr-j3rp-mh2g](https://github.com/advisories/GHSA-wjmr-j3rp-mh2g). You may use a portable executable; no administrator or systemwide upgrade is required. The official [gh v2.102.0 Windows amd64 ZIP](https://github.com/cli/cli/releases/tag/v2.102.0) has SHA-256 ae64e556ecc240b200f7eba60d550e4bb60d78e860e69dd88c449405b86067f4. Independently check that archive digest before extraction.

4. Review this PR's read-only script. From the checked-out branch root, with the original installer file already present, run:

~~~powershell
pwsh -NoProfile -File .github/scripts/Verify-Public-V178.ps1 -InstallerPath 'C:\path\TaskbarMonitorEnhanced_Setup_1.7.8.exe' -GhPath 'C:\path\verified-portable-gh\bin\gh.exe'
~~~

The script checks file size, SHA, version, and exact GitHub attestation signer workflow, main source ref, source commit, SLSA predicate, and hosted runner. Only exit code zero plus PUBLIC_V178_EXACT_SLSA_PROVENANCE_VERIFIED constitutes an overall provenance PASS.

The corresponding direct verification call, after checking your exact file and gh client, is:

~~~powershell
& 'C:\path\verified-portable-gh\bin\gh.exe' attestation verify 'C:\path\TaskbarMonitorEnhanced_Setup_1.7.8.exe' --repo GOD13emad/TaskbarMonitorEnhanced --signer-workflow GOD13emad/TaskbarMonitorEnhanced/.github/workflows/ci.yml --source-ref refs/heads/main --source-digest 9960a06dba606d1c93b8ca2b84e0e3e25ca4f68d --deny-self-hosted-runners --predicate-type 'https://slsa.dev/provenance/v1'
~~~

The verification needs the GitHub API and Sigstore public trust material. If blocked, the result is **UNVERIFIED**, not PASS and not proof of tampering.

## Evidence and trust limits

- [Hosted positive proof](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/39052353269)
- [Hosted positive plus strict negative controls](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/39052453007)

In the second run, the original installer passed, an appended-byte tampered copy failed exact digest lookup, and the unchanged original with a deliberately incorrect source commit failed exact source-digest policy. No installer was executed.

A successful hosted proof is for the **exact documented SHA-256 only**; compare your local downloaded file separately. SLSA provenance does **not** replace legally issued Windows Authenticode and does not establish that the binary is safe, harmless, or approved by an issuer. Never disable Windows security controls to run unsigned software. Every future version needs its own independent digest, source and verification.
