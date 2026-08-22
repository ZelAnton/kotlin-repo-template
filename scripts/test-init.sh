#!/usr/bin/env bash
# Reproducible initializer checks. Run from any shell with bash and pwsh:
#   bash ./scripts/test-init.sh

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
test_root="$(mktemp -d "$repo_root/../kotlin-init-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

die() {
  echo "error: $*" >&2
  exit 1
}

pwsh_command="$(command -v pwsh || command -v pwsh.exe || true)"
[ -n "$pwsh_command" ] || die "pwsh is required to check scripts/init.ps1"

to_native_path() {
  if command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$1"
  elif command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s' "$1"
  fi
}

placeholder="__Package""Name__"
project_placeholder="__Project""Name__"
package_name="com.example.nested"

copy_template() {
  local destination="$1"
  mkdir -p "$destination"
  cp -a "$repo_root"/. "$destination"/
  rm -rf "$destination/.git"
}

assert_settings_activated() {
  local case_dir="$1"

  [ -f "$case_dir/.claude/settings.json" ] || die "clean initializer did not activate settings.json"
  [ ! -e "$case_dir/.claude/settings.json.template" ] || die "clean initializer left settings.json.template"
  grep -Fq '"permissions"' "$case_dir/.claude/settings.json" || die "activated settings file has unexpected contents"
}

assert_success_tree() {
  local case_dir="$1"
  local main_source="$case_dir/src/main/kotlin/$placeholder"
  local test_source="$case_dir/src/test/kotlin/$placeholder"
  local main_target="$case_dir/src/main/kotlin/com/example/nested"
  local test_target="$case_dir/src/test/kotlin/com/example/nested"

  [ ! -d "$main_source" ] || die "PowerShell/POSIX success case left the main source directory"
  [ ! -d "$test_source" ] || die "PowerShell/POSIX success case left the test source directory"
  [ -f "$main_target/Greeter.kt" ] || die "root main file was not transferred"
  [ -f "$main_target/nested/deep/MainNested.kt" ] || die "nested main file was not transferred"
  [ -f "$test_target/GreeterTest.kt" ] || die "root test file was not transferred"
  [ -f "$test_target/nested/deep/TestNested.kt" ] || die "nested test file was not transferred"
  grep -Fq "package $package_name.nested.deep" "$main_target/nested/deep/MainNested.kt" || die "nested main package was not replaced"
  grep -Fq "package $package_name.nested.deep" "$test_target/nested/deep/TestNested.kt" || die "nested test package was not replaced"
  assert_settings_activated "$case_dir"
}

run_success_case() {
  local shell_name="$1"
  local case_dir="$test_root/success-$shell_name"
  local expected_settings="$test_root/expected-settings-$shell_name.json"
  copy_template "$case_dir"
  cp "$case_dir/.claude/settings.json.template" "$expected_settings"
  mkdir -p "$case_dir/src/main/kotlin/$placeholder/nested/deep"
  mkdir -p "$case_dir/src/test/kotlin/$placeholder/nested/deep"
  printf 'package %s.nested.deep\n\nclass MainNested\n' "$placeholder" > "$case_dir/src/main/kotlin/$placeholder/nested/deep/MainNested.kt"
  printf 'package %s.nested.deep\n\nclass TestNested\n' "$placeholder" > "$case_dir/src/test/kotlin/$placeholder/nested/deep/TestNested.kt"

  if [ "$shell_name" = bash ]; then
    bash "$case_dir/scripts/init.sh" --project-name nested-check --package-name "$package_name" --keep-script
  else
    "$pwsh_command" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$(to_native_path "$case_dir/scripts/init.ps1")" -ProjectName nested-check -PackageName "$package_name" -KeepScript
  fi
  assert_success_tree "$case_dir"
  cmp -s "$expected_settings" "$case_dir/.claude/settings.json" || die "$shell_name clean activation changed settings contents"
}

assert_failure_tree() {
  local case_dir="$1"
  local main_source="$case_dir/src/main/kotlin/$placeholder"
  local destination="$case_dir/src/main/kotlin/com/example/nested"

  [ -d "$main_source/nested/$placeholder" ] || die "nested-placeholder fixture was not created"
  [ ! -e "$destination" ] || die "failed initializer created a destination tree"
  [ -f "$case_dir/TEMPLATE.md" ] || die "failed initializer removed TEMPLATE.md"
  [ -f "$case_dir/scripts/init.sh" ] || die "failed initializer removed init.sh"
  [ -f "$case_dir/scripts/init.ps1" ] || die "failed initializer removed init.ps1"
  grep -Fq "$project_placeholder" "$case_dir/README.md" || die "failed initializer partially replaced file contents"
}

run_failure_case() {
  local shell_name="$1"
  local case_dir="$test_root/failure-$shell_name"
  copy_template "$case_dir"
  mkdir -p "$case_dir/src/main/kotlin/$placeholder/nested/$placeholder"
  printf 'package %s.nested\n' "$placeholder" > "$case_dir/src/main/kotlin/$placeholder/nested/$placeholder/NestedPlaceholder.kt"

  if [ "$shell_name" = bash ]; then
    if bash "$case_dir/scripts/init.sh" --project-name nested-check --package-name "$package_name" --keep-script; then
      die "POSIX initializer accepted a nested package placeholder directory"
    fi
  else
    if "$pwsh_command" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$(to_native_path "$case_dir/scripts/init.ps1")" -ProjectName nested-check -PackageName "$package_name" -KeepScript; then
      die "PowerShell initializer accepted a nested package placeholder directory"
    fi
  fi
  assert_failure_tree "$case_dir"
}

assert_conflict_tree() {
  local case_dir="$1"
  local main_source="$case_dir/src/main/kotlin/$placeholder"
  local destination_file="$case_dir/src/main/kotlin/com/example/nested/Greeter.kt"

  [ -d "$main_source" ] || die "destination-conflict case removed the source package"
  [ -f "$destination_file" ] || die "destination-conflict case removed the existing destination file"
  grep -Fxq 'keep this destination file' "$destination_file" || die "existing destination file was overwritten"
  [ -f "$case_dir/TEMPLATE.md" ] || die "destination-conflict case removed TEMPLATE.md"
  [ -f "$case_dir/scripts/init.sh" ] || die "destination-conflict case removed init.sh"
  [ -f "$case_dir/scripts/init.ps1" ] || die "destination-conflict case removed init.ps1"
  grep -Fq "$project_placeholder" "$case_dir/README.md" || die "destination-conflict case partially replaced file contents"
}

run_conflict_case() {
  local shell_name="$1"
  local case_dir="$test_root/conflict-$shell_name"
  local output
  copy_template "$case_dir"
  mkdir -p "$case_dir/src/main/kotlin/$placeholder"
  mkdir -p "$case_dir/src/main/kotlin/com/example/nested"
  printf 'keep this destination file\n' > "$case_dir/src/main/kotlin/com/example/nested/Greeter.kt"

  if [ "$shell_name" = bash ]; then
    if output="$(bash "$case_dir/scripts/init.sh" --project-name nested-check --package-name "$package_name" --keep-script 2>&1)"; then
      die "POSIX initializer overwrote or accepted an existing destination file"
    fi
  else
    if output="$("$pwsh_command" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$(to_native_path "$case_dir/scripts/init.ps1")" -ProjectName nested-check -PackageName "$package_name" -KeepScript 2>&1)"; then
      die "PowerShell initializer overwrote or accepted an existing destination file"
    fi
  fi
  printf '%s\n' "$output" | grep -Fqi 'destination' || die "$shell_name conflict error did not identify the destination"
  assert_conflict_tree "$case_dir"
}

assert_settings_conflict_tree() {
  local case_dir="$1"
  local settings_file="$case_dir/.claude/settings.json"
  local settings_template="$case_dir/.claude/settings.json.template"
  local main_source="$case_dir/src/main/kotlin/$placeholder"
  local package_destination="$case_dir/src/main/kotlin/com/example/nested"

  [ -f "$settings_file" ] || die "settings-conflict case removed the existing user file"
  grep -Fxq 'keep this user settings file' "$settings_file" || die "existing user settings file was overwritten"
  [ -f "$settings_template" ] || die "settings-conflict case consumed settings.json.template"
  [ -d "$main_source" ] || die "settings-conflict case moved the source package before failing"
  [ ! -e "$package_destination" ] || die "settings-conflict case created a package destination before failing"
  [ -f "$case_dir/TEMPLATE.md" ] || die "settings-conflict case removed TEMPLATE.md"
  [ -f "$case_dir/scripts/init.sh" ] || die "settings-conflict case removed init.sh"
  [ -f "$case_dir/scripts/init.ps1" ] || die "settings-conflict case removed init.ps1"
  grep -Fq "$project_placeholder" "$case_dir/README.md" || die "settings-conflict case partially replaced file contents"
}

run_settings_conflict_case() {
  local shell_name="$1"
  local case_dir="$test_root/settings-conflict-$shell_name"
  local expected_template="$test_root/expected-settings-template-$shell_name.json"
  local output
  copy_template "$case_dir"
  cp "$case_dir/.claude/settings.json.template" "$expected_template"
  printf 'keep this user settings file\n' > "$case_dir/.claude/settings.json"

  if [ "$shell_name" = bash ]; then
    if output="$(bash "$case_dir/scripts/init.sh" --project-name nested-check --package-name "$package_name" --keep-script 2>&1)"; then
      die "POSIX initializer overwrote or accepted an existing settings file"
    fi
  else
    if output="$("$pwsh_command" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$(to_native_path "$case_dir/scripts/init.ps1")" -ProjectName nested-check -PackageName "$package_name" -KeepScript 2>&1)"; then
      die "PowerShell initializer overwrote or accepted an existing settings file"
    fi
  fi
  printf '%s\n' "$output" | grep -Fqi 'settings' || die "$shell_name settings conflict error did not identify settings"
  assert_settings_conflict_tree "$case_dir"
  cmp -s "$expected_template" "$case_dir/.claude/settings.json.template" || die "$shell_name settings conflict changed the template"
}

run_success_case bash
run_success_case powershell
run_failure_case bash
run_failure_case powershell
run_conflict_case bash
run_conflict_case powershell
run_settings_conflict_case bash
run_settings_conflict_case powershell
echo "Initializer checks passed for POSIX and PowerShell (clean transfer, nested validation, and settings/package conflict protection)."
