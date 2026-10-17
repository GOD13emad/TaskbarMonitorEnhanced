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
