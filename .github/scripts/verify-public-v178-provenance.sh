#!/usr/bin/env bash
# Read-only, historical public release attestation check on a GitHub-hosted runner.
# Never executes the installer, signs files, creates tags, publishes, or uploads.
set -euo pipefail
umask 077

[[ -n "$GH_TOKEN" ]] || { echo 'GITHUB_TOKEN_REQUIRED' >&2; exit 1; }
[[ "$GITHUB_REPOSITORY" == "GOD13emad/TaskbarMonitorEnhanced" ]] || {
  echo "WRONG_REPOSITORY" >&2
  exit 1
}
[[ "$GITHUB_EVENT_NAME" == workflow_dispatch ]] || {
  echo "READ_ONLY_MANUAL_EVENT_REQUIRED" >&2
  exit 1
}
[[ "$GITHUB_REF" == refs/heads/* ]] || {
  echo "READ_ONLY_BRANCH_REF_REQUIRED" >&2
  exit 1
}

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

gh_release='https://github.com/cli/cli/releases/download/v2.102.0/gh_2.102.0_linux_amd64.tar.gz'
gh_sha='bb766f710eef8ede859c18578c72c327597cd4c8a85b06001b1f3843c6019386'
installer_url='https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/download/v1.7.8/TaskbarMonitorEnhanced_Setup_1.7.8.exe'
installer_sha='4db3c03ac7ab70b3d3123a365c156e71370f0338991b399b99169a4b5b5f8b75'
source_sha='9960a06dba606d1c93b8ca2b84e0e3e25ca4f68d'
signer='GOD13emad/TaskbarMonitorEnhanced/.github/workflows/ci.yml'

curl --proto '=https' --tlsv1.2 -fsSL --retry 2 --connect-timeout 15 --max-time 120 "$gh_release" -o "$work/gh.tar.gz"
printf '%s  %s\n' "$gh_sha" "$work/gh.tar.gz" | sha256sum --check --strict --status
tar -xzf "$work/gh.tar.gz" -C "$work"
gh_binary="$work/gh_2.102.0_linux_amd64/bin/gh"
[[ -f "$gh_binary" ]] || { echo 'VERIFIED_GH_BINARY_MISSING' >&2; exit 1; }
"$gh_binary" --version | head -n 1 | grep -F 'gh version 2.102.0 '
echo "PATCHED_GH_ARCHIVE_SHA256_PASS"

installer="$work/TaskbarMonitorEnhanced_Setup_1.7.8.exe"
curl --proto '=https' --tlsv1.2 -fsSL --retry 2 --connect-timeout 15 --max-time 120 "$installer_url" -o "$installer"
printf '%s  %s\n' "$installer_sha" "$installer" | sha256sum --check --strict --status
[[ "$(stat -c '%s' "$installer")" == 8565760 ]] || {
  echo 'PUBLIC_RELEASE_INSTALLER_SIZE_MISMATCH' >&2
  exit 1
}
echo "PUBLIC_V178_INSTALLER_SHA256_PASS"

"$gh_binary" attestation verify "$installer" \
  --repo 'GOD13emad/TaskbarMonitorEnhanced' \
  --signer-workflow "$signer" \
  --source-ref refs/heads/main \
  --source-digest "$source_sha" \
  --deny-self-hosted-runners \
  --predicate-type 'https://slsa.dev/provenance/v1'
echo "PUBLIC_V178_EXACT_SLSA_PROVENANCE_VERIFIED"

# A broken trust-root or API connection must never be misclassified as a
# successful tamper test. Only the exact changed-subject 404 is accepted.
tampered="$work/TaskbarMonitorEnhanced_Setup_1.7.8.tampered.exe"
cp -- "$installer" "$tampered"
printf '\x7f' >> "$tampered"
tampered_sha="$(sha256sum "$tampered" | awk '{print $1}')"
[[ "$tampered_sha" != "$installer_sha" ]] || { echo 'TAMPER_DIGEST_NOT_CHANGED' >&2; exit 1; }
if "$gh_binary" attestation verify "$tampered" \
    --repo 'GOD13emad/TaskbarMonitorEnhanced' \
    --signer-workflow "$signer" \
    --source-ref refs/heads/main \
    --source-digest "$source_sha" \
    --deny-self-hosted-runners \
    --predicate-type 'https://slsa.dev/provenance/v1' \
    > "$work/tamper.log" 2>&1; then
  echo 'CRITICAL_TAMPERED_SUBJECT_ACCEPTED' >&2
  exit 1
fi
if ! grep -Fq 'HTTP 404: Not Found' "$work/tamper.log" ||
   ! grep -Fq "/attestations/sha256:$tampered_sha" "$work/tamper.log"; then
  echo 'INCONCLUSIVE_TAMPER_REJECTION' >&2
  tail -n 10 "$work/tamper.log" >&2
  exit 1
fi
echo "PUBLIC_V178_TAMPERED_INSTALLER_REJECTED"

# Valid bytes with an explicitly wrong source commit must also be rejected.
wrong_source_sha='0000000000000000000000000000000000000000'
[[ "$wrong_source_sha" != "$source_sha" ]] || exit 1
if "$gh_binary" attestation verify "$installer" \
    --repo 'GOD13emad/TaskbarMonitorEnhanced' \
    --signer-workflow "$signer" \
    --source-ref refs/heads/main \
    --source-digest "$wrong_source_sha" \
    --deny-self-hosted-runners \
    --predicate-type 'https://slsa.dev/provenance/v1' \
    > "$work/wrong-source.log" 2>&1; then
  echo 'CRITICAL_WRONG_SOURCE_SHA_ACCEPTED' >&2
  exit 1
fi
if ! grep -Fq "expected SourceRepositoryDigest to be $wrong_source_sha, got $source_sha" "$work/wrong-source.log"; then
  echo 'INCONCLUSIVE_SOURCE_DIGEST_REJECTION' >&2
  tail -n 10 "$work/wrong-source.log" >&2
  exit 1
fi
echo "PUBLIC_V178_WRONG_SOURCE_COMMIT_REJECTED"
echo "PUBLIC_V178_NEGATIVE_GATES_PASS"

# Validate the actual reusable Windows PowerShell client logic on GitHub-hosted
# PowerShell 7; Linux runner skips only Windows Authenticode OS-specific probing.
command -v pwsh >/dev/null || { echo 'PWSH_RUNTIME_MISSING' >&2; exit 1; }
client='.github/scripts/Verify-Public-V178.ps1'
[[ -f "$client" ]] || { echo 'PUBLIC_V178_CLIENT_SCRIPT_MISSING' >&2; exit 1; }
pwsh -NoLogo -NoProfile -File "$client" -InstallerPath "$installer" -GhPath "$gh_binary"
echo "PUBLIC_V178_POWERSHELL_CLIENT_REAL_FILE_PASS"

printf 'INVALID' > "$work/client-size-invalid.exe"
if pwsh -NoLogo -NoProfile -File "$client" \
  -InstallerPath "$work/client-size-invalid.exe" -GhPath "$gh_binary" \
  > "$work/client-size.log" 2>&1; then
  echo 'CRITICAL_CLIENT_ACCEPTED_WRONG_SIZE' >&2
  exit 1
fi
grep -Fq 'PUBLIC_V178_INVALID_SIZE' "$work/client-size.log" || {
  echo 'INCONCLUSIVE_CLIENT_SIZE_REJECTION' >&2
  tail -n 8 "$work/client-size.log" >&2
  exit 1
}

truncate -s 8565760 "$work/client-digest-invalid.exe"
if pwsh -NoLogo -NoProfile -File "$client" \
  -InstallerPath "$work/client-digest-invalid.exe" -GhPath "$gh_binary" \
  > "$work/client-digest.log" 2>&1; then
  echo 'CRITICAL_CLIENT_ACCEPTED_WRONG_DIGEST' >&2
  exit 1
fi
grep -Fq 'PUBLIC_V178_DIGEST_MISMATCH' "$work/client-digest.log" || {
  echo 'INCONCLUSIVE_CLIENT_DIGEST_REJECTION' >&2
  tail -n 8 "$work/client-digest.log" >&2
  exit 1
}
echo "PUBLIC_V178_POWERSHELL_CLIENT_NEGATIVE_GATES_PASS"
echo "PUBLIC_V178_POWERSHELL_CLIENT_TESTS_PASS"
