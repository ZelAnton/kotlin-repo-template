#!/usr/bin/env bash
#
# Verifies the template's single-source Foojay settings-plugin contract.
# This is a static check: it does not resolve the plugin or require a JDK.
#
# Usage: bash ./scripts/check-foojay-single-source.sh

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
settings_file="$root_dir/settings.gradle.kts"
catalog_file="$root_dir/gradle/libs.versions.toml"

for file in "$settings_file" "$catalog_file"; do
  if [ ! -f "$file" ]; then
    echo "Required file not found: $file" >&2
    exit 1
  fi
done

plugin_pattern='^[[:space:]]*id\("org\.gradle\.toolchains\.foojay-resolver-convention"\)[[:space:]]+version[[:space:]]+"[^"]+"[[:space:]]*$'
matches="$(grep -E "$plugin_pattern" "$settings_file" || true)"
match_count="$(printf '%s\n' "$matches" | awk 'NF { count++ } END { print count + 0 }')"
if [ "$match_count" -ne 1 ]; then
  echo "Expected exactly one Foojay settings-plugin declaration; found $match_count." >&2
  exit 1
fi

version="$(printf '%s\n' "$matches" | sed -E 's/.*version[[:space:]]+"([^"]+)".*/\1/')"
if [ -z "$version" ]; then
  echo "The Foojay settings-plugin declaration has an empty version." >&2
  exit 1
fi

catalog_duplicates="$(grep -E -i '^[[:space:]]*[A-Za-z0-9_-]*foojay[A-Za-z0-9_-]*[[:space:]]*=' "$catalog_file" || true)"
if [ -n "$catalog_duplicates" ]; then
  echo "The version catalog contains a Foojay assignment; keep Foojay settings-owned." >&2
  exit 1
fi

candidate_version='99.99.99-contract-test'
temporary_settings="$(mktemp)"
trap 'rm -f "$temporary_settings"' EXIT
sed -E "s|^([[:space:]]*id\(\"org\.gradle\.toolchains\.foojay-resolver-convention\"\)[[:space:]]+version[[:space:]]+\")[^\"]+(\"[[:space:]]*)$|\1${candidate_version}\2|" \
  "$settings_file" > "$temporary_settings"
mutated_version="$(sed -n -E 's/^[[:space:]]*id\("org\.gradle\.toolchains\.foojay-resolver-convention"\)[[:space:]]+version[[:space:]]+"([^"]+)"[[:space:]]*$/\1/p' "$temporary_settings")"
if [ "$mutated_version" != "$candidate_version" ]; then
  echo "Changing the settings-owned version did not change the applied Foojay declaration." >&2
  exit 1
fi

echo "Foojay single-source contract OK: settings.gradle.kts owns version $version; catalog has no Foojay alias."
