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
grep -qF 'NOTES_FILE: ${{ steps.notes.outputs.path }}' "$workflow" || fail "promoted release notes are not persisted"
grep -qF 'pathlib.Path(os.environ["NOTES_FILE"])' "$workflow" || fail "promotion does not read the assembled notes"
grep -qF 'steps.version.outputs.resume != '\''true'\'' && steps.changelog.outputs.has_manual == '\''false'\''' "$workflow" || fail "resume incorrectly runs git-cliff"

# Execute the workflow's real promotion block against both kinds of assembled
# notes, then run the same version-section extraction used by a resume. This
# catches regressions where manual notes or git-cliff fallback notes disappear
# from the tagged changelog, or where resume falls back to skipped-step output.
temp_dir=$(mktemp -d)
cleanup() {
  rm -rf "$temp_dir"
}
trap cleanup EXIT

promotion_script="$temp_dir/promote.py"
awk '
  /python3 <<'"'"'PY'"'"'/ { capture=1; next }
  capture && /^[[:space:]]*PY$/ { exit }
  capture { sub(/^          /, ""); print }
' "$workflow" > "$promotion_script"

run_resume_case() {
  local case_name=$1
  local version=$2
  local previous=$3
  local notes=$4
  local case_dir="$temp_dir/$case_name"
  mkdir -p "$case_dir"
  cat > "$case_dir/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

### Added
- original placeholder

[Unreleased]: https://github.com/__GitHubOwner__/__ProjectName__/commits/main
EOF
  printf '%s\n' "$notes" > "$case_dir/release-notes.md"
  (
    cd "$case_dir"
    VERSION="$version" TAG="v$version" PREV_TAG="v$previous" \
      NOTES_FILE="$case_dir/release-notes.md" python3 "$promotion_script"
  ) || fail "$case_name promotion failed"

  grep -qF "## [$version] - " "$case_dir/CHANGELOG.md" || fail "$case_name version entry is missing"
  grep -qF -- "$notes" "$case_dir/CHANGELOG.md" || fail "$case_name notes were not persisted"

  resumed_notes=$(awk -v version="$version" '
    index($0, "## [" version "]") == 1 { f=1; next }
    /^## \[/ { if (f) exit }
    /^\[[^]]+\]:[[:space:]]/ { if (f) exit }
    f
  ' "$case_dir/CHANGELOG.md")
  printf '%s\n' "$resumed_notes" | grep -qF -- "$notes" || fail "$case_name resume cannot recover its notes"
}

run_resume_case manual 1.2.3 1.2.2 $'### Added\n\n- manually curated release note'
run_resume_case fallback 1.2.4 1.2.3 $'### Changed\n\n- generated fallback release note'

echo "Release workflow checks passed: exact duplicate coordinate, same-version resume with manual/fallback notes, and publication ordering."
