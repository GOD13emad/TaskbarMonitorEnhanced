# R21 Acceptance Status — Taskbar Monitor Enhanced v1.1.2

Status: GITHUB ATTESTED / IMMUTABLE PUBLICATION READY
Updated: 2026-09-26T17:38:19.1485489+03:30

## Release authority

- Immutable release/tag target: aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0
- Behavior/build authority: 5916db0ef7fe19fea8cc13ebde73d01021d7c3d6
- Branch: release/v1.1.2-final
- Public Stable/Latest remains v1.1.1 until v1.1.2 is actually created and post-verified.

## Accepted gates

- Final identity equivalence: PASS 7/7.
- Deterministic local build and SPDX SBOM generation: PASS.
- Exact installed v1.1.2 identity/hashes/config preservation: PASS.
- Proportional final runtime regression R2: PASS.
- GitHub Actions run 36244774522: PASS.
- GitHub binary provenance attestation: PASS.
- GitHub Setup SBOM attestation: PASS.
- GitHub evidence artifact binary hashes: PASS 4/4 exact.
- SPDX semantic equivalence: PASS. Raw document hashes differ only in documentNamespace/git-head and creationInfo.created; normalized hash is BFBB7FB00FF3C8DD9ED26DBD17C0E3CAED5B4F666BE5373E7C329549AEEB7BAA.

## Exact final output hashes

- Main: DFF69CFC96C0A0567DD32C04EBD45414CFF045172A76A84EE1060814921DFE9E
- Broker: 182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833
- Supervisor: 38553CCE30D5D3F1A22AC6765C4A0F5D4D204970A3DAD7BA9467A326235FC196
- Setup: 25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB
- Local SPDX SBOM: B324745F6041FA8E8C8FA888977B40B41100B787C6A8E087ED80EB23AC148578
- GitHub-run SPDX SBOM raw: 1C3D36B725BAC33A61BE9D886C4C6AA6E78ECAE58D5815DDA13E4F68229B1B9B
- Semantic-normalized SPDX hash: BFBB7FB00FF3C8DD9ED26DBD17C0E3CAED5B4F666BE5373E7C329549AEEB7BAA

## CI failure prevention

Run 36244394685 failed before build because checkout depth was 1 while the workflow used HEAD^. The pinned checkout action now uses the minimum sufficient fetch-depth 2. Fresh run 36244774522 passed every required step. The failed run was not blindly rerun.

## Open gates

1. Create immutable tag/release v1.1.2 at exact attested commit aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0.
2. Upload exact accepted release assets.
3. Verify tag target, non-draft/non-prerelease, Latest/Stable state and release asset hashes.
4. Final Project Brain / Knowledge closeout.

## Evidence

- docs/acceptance/R22_GITHUB_ATTESTATION_ACCEPTANCE.json
- docs/acceptance/R22_FINAL_RUNTIME_ACCEPTANCE.json
- docs/acceptance/R22_FINAL_BUILD_ACCEPTANCE.json
- docs/acceptance/R22_FINAL_IDENTITY_EQUIVALENCE.json
- r21_evidence/R22_SBOM_SEMANTIC_EQUIVALENCE.json