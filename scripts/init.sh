#!/usr/bin/env bash
#
# Initializes this template into a concrete Kotlin (Gradle) project (POSIX
# counterpart of init.ps1 — use whichever matches your shell; both do the same).
#
# Replaces the placeholder tokens (__ProjectName__, __PackageName__, __Group__,
# __Author__, __GitHubOwner__, __Description__, __Year__) in file contents, moves
# the token-named Kotlin source package into the real dotted-package directory
# tree, then removes the template-only files (TEMPLATE.md, docs/AGENT-INIT-GUIDE.md)
# and — unless --keep-script — both initializers (init.sh and init.ps1).
#
# Usage:
#   bash ./scripts/init.sh --project-name acme-widgets --package-name com.acme.widgets \
#       [--group com.acme] [--author "Jane Doe"] [--github-owner acme] \
#       [--description "Widget toolkit"] [--year 2026] [--keep-script]
#
# --project-name is required; the rest fall back to sensible defaults so the
# result always builds. Edit LICENSE / build.gradle.kts afterwards to refine them.

set -euo pipefail

project_name=""
package_name=""
group=""
author=""
github_owner=""
description=""
year=""
keep_script=0

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --project-name)  project_name="${2:-}"; shift 2 ;;
    --package-name)  package_name="${2:-}"; shift 2 ;;
    --group)         group="${2:-}"; shift 2 ;;
    --author)        author="${2:-}"; shift 2 ;;
    --github-owner)  github_owner="${2:-}"; shift 2 ;;
    --description)   description="${2:-}"; shift 2 ;;
    --year)          year="${2:-}"; shift 2 ;;
    --keep-script)   keep_script=1; shift ;;
    -h|--help)       sed -n '2,21p' "$0"; exit 0 ;;
    *)               die "unknown argument: $1" ;;
  esac
done

[ -n "$project_name" ] || die "--project-name is required (e.g. --project-name acme-widgets)."

# Gradle artifact names: letters, digits, '-' and '_'; start with a letter.
case "$project_name" in
  [A-Za-z]*) : ;;
  *) die "invalid --project-name '$project_name'. Start with a letter." ;;
esac
case "$project_name" in
  *[!A-Za-z0-9_-]*) die "invalid --project-name '$project_name'. Use letters, digits, '-' or '_'." ;;
esac

# Sanitize a string into a single legal lowercase package segment.
pkg_segment() {
  local seg
  seg="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
  [ -n "$seg" ] || seg="app"
  case "$seg" in [0-9]*) seg="_$seg" ;; esac
  printf '%s' "$seg"
}

# Defaults (mirror init.ps1).
if [ -z "$author" ]; then
  author="$(git config user.name 2>/dev/null || true)"
  [ -n "$author" ] || author="Your Name"
fi
[ -n "$github_owner" ] || github_owner="your-org"
[ -n "$description" ]  || description="TODO: project description"
[ -n "$year" ]         || year="$(date +%Y)"
[ -n "$group" ]        || group="io.github.$(pkg_segment "$github_owner")"
[ -n "$package_name" ] || package_name="$group.$(pkg_segment "$project_name")"

# A package is dot-separated identifiers: [a-z_][a-z0-9_]* per segment.
IFS='.' read -ra _segs <<< "$package_name"
for seg in "${_segs[@]}"; do
  case "$seg" in
    [a-z_]*) ;;
    *) die "invalid --package-name '$package_name'. Each segment must start with a lowercase letter or underscore (e.g. com.acme.widgets)." ;;
  esac
  case "$seg" in
    *[!a-z0-9_]*) die "invalid --package-name '$package_name'. Use lowercase letters, digits and underscores (e.g. com.acme.widgets)." ;;
  esac
done

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
self="$script_dir/$(basename "$0")"
sibling_ps1="$script_dir/init.ps1"

# Values written into Kotlin-script / TOML files sit inside double-quoted strings
# — escape backslash then quote so a literal " or \ can't break the script.
esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
project_e="$(esc "$project_name")"
group_e="$(esc "$group")"
author_e="$(esc "$author")"
owner_e="$(esc "$github_owner")"
desc_e="$(esc "$description")"
year_e="$(esc "$year")"

echo "==> Initializing template as '$project_name' (package $package_name)"

# 1) Replace tokens in file contents. Both initializers are skipped: they carry
#    the literal token strings as search keys, so substituting inside them would
#    corrupt the sibling script.
changed=0
while IFS= read -r -d '' file; do
  case "$file" in
    "$self"|"$sibling_ps1") continue ;;
  esac
  # Skip binary files (notably gradle/wrapper/gradle-wrapper.jar). They carry no
  # tokens, and reading them through a shell command substitution strips NUL
  # bytes ("ignored null byte in input"), which would corrupt the file on rewrite.
  case "$file" in
    *.jar|*.png|*.jpg|*.gif|*.ico|*.zip) continue ;;
  esac
  case "$file" in
    *.kts|*.toml) p=$project_e; g=$group_e; a=$author_e; o=$owner_e; d=$desc_e; y=$year_e ;;
    *)            p=$project_name; g=$group; a=$author; o=$github_owner; d=$description; y=$year ;;
  esac
  # Preserve trailing newlines: append a sentinel before capture, strip it after.
  content="$(cat "$file"; printf x)"; content="${content%x}"
  orig="$content"
  content="${content//__ProjectName__/$p}"
  content="${content//__PackageName__/$package_name}"
  content="${content//__Group__/$g}"
  content="${content//__Author__/$a}"
  content="${content//__GitHubOwner__/$o}"
  content="${content//__Description__/$d}"
  content="${content//__Year__/$y}"
  if [ "$content" != "$orig" ]; then
    printf '%s' "$content" > "$file"
    changed=$((changed + 1))
  fi
done < <(find "$repo_root" -type d \( -name .git -o -name .jj -o -name build -o -name .gradle -o -name .idea \) -prune -o -type f -print0)
echo "    Updated contents in $changed file(s)."

# 2) Move the token-named Kotlin package directory into the real dotted-package
#    tree (e.g. src/main/kotlin/__PackageName__ -> src/main/kotlin/com/acme/widgets).
#    A JVM source file must live in a directory matching its `package` declaration.
pkg_rel_path="$(printf '%s' "$package_name" | tr '.' '/')"
if [ -d "$repo_root/src" ]; then
  while IFS= read -r -d '' dir; do
    parent="$(dirname "$dir")"
    dest="$parent/$pkg_rel_path"
    mkdir -p "$dest"
    find "$dir" -maxdepth 1 -type f -exec mv {} "$dest/" \;
    rm -rf "$dir"
    echo "    Moved ${parent#"$repo_root"/}/__PackageName__ -> ${parent#"$repo_root"/}/$pkg_rel_path"
  done < <(find "$repo_root/src" -type d -name '__PackageName__' -print0)
fi

# 3) Activate Claude Code shared settings if shipped as a .template.
if [ -f "$repo_root/.claude/settings.json.template" ]; then
  mv -f "$repo_root/.claude/settings.json.template" "$repo_root/.claude/settings.json"
  echo "    Activated .claude/settings.json"
fi

# 4) Remove template-only files (the agent guide is template meta — pitfalls are
#    logged back to the *template's* copy, so the downstream repo drops it).
rm -f "$repo_root/TEMPLATE.md" "$repo_root/docs/AGENT-INIT-GUIDE.md"
rmdir "$repo_root/docs" 2>/dev/null || true

# Strip the template-only ktlint exemption from .editorconfig. It disables the
# package-name rule for the placeholder package directory, which no longer exists
# after the move in step 2, so the rule now applies to the real package. cat -s
# collapses the blank line left behind by the range delete.
if [ -f "$repo_root/.editorconfig" ]; then
  tmp="$(mktemp)"
  sed '/# >>> template-only:ktlint-placeholder/,/# <<< template-only:ktlint-placeholder/d' \
    "$repo_root/.editorconfig" | cat -s > "$tmp"
  mv "$tmp" "$repo_root/.editorconfig"
  echo "    Removed template-only ktlint exemption from .editorconfig"
fi

echo ""
echo "Done. Next steps:"
echo "  1. ./gradlew build"
echo "  2. ./gradlew ktlintFormat   # auto-fix style, then re-run build"
echo "  3. Review LICENSE (author/year) and build.gradle.kts POM metadata."
echo "  4. Replace src/main/kotlin/.../Greeter.kt with your real API and"
echo "     update the sample test."
echo "  5. Fill the Architecture section of CLAUDE.md, then commit."

# 5) Remove both initializers unless asked to keep them.
if [ "$keep_script" -ne 1 ]; then
  rm -f "$sibling_ps1"
  rm -f "$self"
fi
