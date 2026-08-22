#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_root/.github/workflows/release.yml"
matcher="$repo_root/scripts/check-central-portal-duplicate.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$workflow" ]] || fail "release workflow is missing"
[[ -f "$matcher" ]] || fail "duplicate matcher is missing"

printf '%s\n' "Upload failed: Component with package url: 'pkg:maven/com.example/demo@1.2.3?type=jar' already exists" |
  bash "$matcher" - com.example demo 1.2.3 || fail "exact Central Portal duplicate was not accepted"

if printf '%s\n' "Upload failed: Component with package url: 'pkg:maven/com.example/other@1.2.3' already exists" |
  bash "$matcher" - com.example demo 1.2.3; then
  fail "duplicate from another artifact was accepted"
fi

if printf '%s\n' "Upload failed: Component metadata already exists in the staging deployment" |
  bash "$matcher" - com.example demo 1.2.3; then
  fail "unrelated already-exists text was accepted"
fi

publish_line=$(grep -nF 'name: Publish to Maven Central (irreversible pivot)' "$workflow" | cut -d: -f1)
availability_line=$(grep -nF 'name: Verify Maven Central artifact is available (before VCS/GitHub release)' "$workflow" | cut -d: -f1)
push_line=$(grep -nF 'name: Push the release commit + tag (atomic)' "$workflow" | cut -d: -f1)
release_line=$(grep -nF 'name: Create or update the GitHub Release (idempotent)' "$workflow" | cut -d: -f1)
(( publish_line < availability_line )) || fail "availability is not after publication"
(( availability_line < push_line )) || fail "VCS push is not after availability"
(( push_line < release_line )) || fail "GitHub Release is not after VCS push"

grep -qF 'gh release view "$LATEST_TAG"' "$workflow" || fail "rerun release lookup is missing"
grep -qF 'Resuming the exact tagged version' "$workflow" || fail "same-version resume path is missing"
grep -qF 'bash scripts/check-central-portal-duplicate.sh' "$workflow" || fail "exact Central duplicate matcher is not used"
grep -qF 'DeploymentValidation.PUBLISHED' "$repo_root/build.gradle.kts" || fail "Central publication validation is missing"

echo "Release workflow checks passed: exact duplicate coordinate, same-version resume, and publication ordering."
