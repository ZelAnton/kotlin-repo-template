#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 <log> <group> <artifact> <version>" >&2
  exit 2
fi

log_file=$1
group=$2
artifact=$3
version=$4
expected_purl="pkg:maven/${group}/${artifact}@${version}"
input="$log_file"
if [[ "$input" == "-" ]]; then
  input=/dev/stdin
fi

# Keep the match coordinate-exact. Central may append a PURL qualifier such as
# ?type=jar, but a different version/artifact must never authorize a retry skip.
awk -v expected="$expected_purl" '
  {
    lower = tolower($0)
    position = index($0, expected)
    if (position == 0 || index(lower, "component with package url") == 0 ||
        index(lower, "already exists") == 0) {
      next
    }
    following = substr($0, position + length(expected), 1)
    if (following == "" || following == "?" || following == "\047" ||
        following == "\042" || following ~ /[[:space:]]/) {
      found = 1
      exit
    }
  }
  END {
    exit(found ? 0 : 1)
  }
' "$input"
