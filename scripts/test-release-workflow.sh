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
grep -qF 'sort -V -r' "$workflow" || fail "stable tags are not version-sorted"
grep -qF 'bash scripts/check-central-portal-duplicate.sh' "$workflow" || fail "exact Central duplicate matcher is not used"
grep -qF 'DeploymentValidation.PUBLISHED' "$repo_root/build.gradle.kts" || fail "Central publication validation is missing"
grep -qF 'NOTES_FILE: ${{ steps.notes.outputs.path }}' "$workflow" || fail "promoted release notes are not persisted"
grep -qF 'pathlib.Path(os.environ["NOTES_FILE"])' "$workflow" || fail "promotion does not read the assembled notes"
grep -qF 'steps.version.outputs.resume != '\''true'\'' && steps.changelog.outputs.has_manual == '\''false'\''' "$workflow" || fail "resume incorrectly runs git-cliff"
grep -qF 'RELEASE_AUTHOR_NAME_B64: "__AuthorBase64__"' "$workflow" || fail "release author is not carried as encoded data"
grep -qF 'RELEASE_AUTHOR_EMAIL_B64: "__AuthorEmailBase64__"' "$workflow" || fail "release author email is not carried as encoded data"
grep -qF 'base64.b64decode(encoded, validate=True).decode("utf-8")' "$workflow" || fail "release identity decoding is not strict"
grep -qF 'subprocess.run(["git", "config", "user.name", author_name], check=True)' "$workflow" || fail "release author is not passed to git as argv data"
grep -qF 'subprocess.run(["git", "config", "user.email", author_email], check=True)' "$workflow" || fail "release author email is not passed to git as argv data"
! grep -qF 'git config user.name "__Author__"' "$workflow" || fail "release workflow still interpolates raw author shell source"
! grep -qF 'git config user.email "__AuthorEmail__"' "$workflow" || fail "release workflow still interpolates raw author email shell source"

# Execute the workflow's real version-detection block against prerelease,
# stable, resume, and first-release tag sets. This keeps the test aligned with
# the shell that runs in Actions instead of reimplementing its version logic.
temp_dir=$(mktemp -d)
cleanup() {
  rm -rf "$temp_dir"
}
trap cleanup EXIT

# Execute the workflow's real identity-decoding block with shell metacharacters.
# The exact values must reach git config as argv data without executing any part.
identity_script="$temp_dir/configure-release-identity.py"
awk '
  /^      - name: Commit and tag the release \(local only\)$/ { in_step=1; next }
  in_step && /python3 <<'"'"'PY'"'"'/ { capture=1; next }
  capture && /^[[:space:]]*PY$/ { exit }
  capture { sub(/^          /, ""); print }
' "$workflow" > "$identity_script"

identity_case="$temp_dir/identity"
mkdir -p "$identity_case"
git -C "$identity_case" init -q
dangerous_author='O"Reilly $(touch injected-author) `touch injected-backtick` \ path'
dangerous_email='release+"quoted"\path@example.invalid'
author_b64=$(printf '%s' "$dangerous_author" | base64 | tr -d '\r\n')
email_b64=$(printf '%s' "$dangerous_email" | base64 | tr -d '\r\n')
(
  cd "$identity_case"
  RELEASE_AUTHOR_NAME_B64="$author_b64" RELEASE_AUTHOR_EMAIL_B64="$email_b64" \
    python3 "$identity_script"
) || fail "release identity decoding block failed"
[[ "$(git -C "$identity_case" config --get user.name)" == "$dangerous_author" ]] || fail "release author changed while crossing the workflow boundary"
[[ "$(git -C "$identity_case" config --get user.email)" == "$dangerous_email" ]] || fail "release author email changed while crossing the workflow boundary"
[[ ! -e "$identity_case/injected-author" && ! -e "$identity_case/injected-backtick" ]] || fail "release identity metadata executed shell content"

version_script="$temp_dir/determine-version.sh"
awk '
  /^      - name: Determine next version$/ { in_step=1; next }
  in_step && /^      - name:/ { exit }
  in_step && /^        run: \|$/ { in_run=1; next }
  in_run && /^          / { sub(/^          /, ""); print; next }
  in_run { exit }
' "$workflow" > "$version_script"
sed -i 's/\${{ inputs.bump }}/${INPUT_BUMP}/g' "$version_script"

run_determine_version_case() {
  local case_name=$1
  local tags=$2
  local expected_current=$3
  local expected_version=$4
  local expected_resume=$5
  local release_exists=$6
  local case_dir="$temp_dir/version-$case_name"
  local output_file="$case_dir/github-output"

  mkdir -p "$case_dir/bin"
  git -C "$case_dir" init -q
  git -C "$case_dir" -c user.name=test -c user.email=test@example.invalid commit --allow-empty -qm initial
  printf '%s\n' 'val version = providers.gradleProperty("version").getOrElse("0.1.0")' > "$case_dir/build.gradle.kts"
  git -C "$case_dir" add build.gradle.kts
  git -C "$case_dir" -c user.name=test -c user.email=test@example.invalid commit -qm build
  for tag in $tags; do
    git -C "$case_dir" tag "$tag"
  done

  cat > "$case_dir/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "${1-}" == release && "${2-}" == view && "${GH_RELEASE_EXISTS:-false}" == true ]]; then
  exit 0
fi
exit 1
EOF
  chmod +x "$case_dir/bin/gh"
  : > "$output_file"
  (
    cd "$case_dir"
    PATH="$case_dir/bin:$PATH" GH_RELEASE_EXISTS="$release_exists" INPUT_BUMP=patch \
      GITHUB_OUTPUT="$output_file" bash "$version_script"
  ) || fail "$case_name version detection failed"

  grep -qF "current=$expected_current" "$output_file" || fail "$case_name selected the wrong current version"
  grep -qF "version=$expected_version" "$output_file" || fail "$case_name computed the wrong next version"
  grep -qF "tag=v$expected_version" "$output_file" || fail "$case_name computed the wrong tag"
  grep -qF "resume=$expected_resume" "$output_file" || fail "$case_name selected the wrong resume mode"
}

run_determine_version_case prerelease-and-stable \
  'v9.9.9-rc.1 v8.8.8+build v1.2.3-rc v1.2.3' 1.2.3 1.2.4 false true
run_determine_version_case resume-after-prerelease \
  'v4.0.0-beta v4.0.0' 4.0.0 4.0.0 true false
run_determine_version_case first-release '' 0.0.0 0.1.0 false false

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
