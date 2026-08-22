#!/usr/bin/env bash
#
# Initializes this template into a concrete Kotlin (Gradle) project (POSIX
# counterpart of init.ps1 — use whichever matches your shell; both do the same).
#
# Replaces the placeholder tokens (__ProjectName__, __PackageName__, __Group__,
# __Author__, __AuthorEmail__, __GitHubOwner__, __Description__, __Year__) in file contents, moves
# the token-named Kotlin source package into the real dotted-package directory
# tree, then removes the template-only files (TEMPLATE.md, docs/AGENT-INIT-GUIDE.md)
# and — unless --keep-script — both initializers (init.sh and init.ps1).
#
# Usage:
#   bash ./scripts/init.sh --project-name acme-widgets --package-name com.acme.widgets \
#       [--group com.acme] [--author "Jane Doe"] [--author-email you@example.com] \
#       [--github-owner acme] [--description "Widget toolkit"] [--year 2026] [--keep-script]
#
# --project-name is required; the rest fall back to sensible defaults so the
# result always builds. Edit LICENSE / build.gradle.kts afterwards to refine them.

set -euo pipefail

project_name=""
package_name=""
group=""
author=""
author_email=""
github_owner=""
description=""
year=""
keep_script=0

die() { echo "error: $*" >&2; exit 1; }

destination_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

while [ $# -gt 0 ]; do
  case "$1" in
    --project-name)  project_name="${2:-}"; shift 2 ;;
    --package-name)  package_name="${2:-}"; shift 2 ;;
    --group)         group="${2:-}"; shift 2 ;;
    --author)        author="${2:-}"; shift 2 ;;
    --author-email)  author_email="${2:-}"; shift 2 ;;
    --github-owner)  github_owner="${2:-}"; shift 2 ;;
    --description)   description="${2:-}"; shift 2 ;;
    --year)          year="${2:-}"; shift 2 ;;
    --keep-script)   keep_script=1; shift ;;
    -h|--help)       sed -n '2,18p' "$0"; exit 0 ;;
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
if [ -z "$author_email" ]; then
  author_email="$(git config user.email 2>/dev/null || true)"
  [ -n "$author_email" ] || author_email="you@example.com"
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
author_email_e="$(esc "$author_email")"
owner_e="$(esc "$github_owner")"
desc_e="$(esc "$description")"
year_e="$(esc "$year")"

echo "==> Initializing template as '$project_name' (package $package_name)"

# 1) Validate the package roots before making any content changes. Only the two
#    expected source roots are supported; a nested placeholder is ambiguous and
#    must fail before the checkout is partially initialized.
pkg_rel_path="$(printf '%s' "$package_name" | tr '.' '/')"
src_root="$repo_root/src"
package_dirs=()
if [ -d "$src_root" ]; then
  token_dirs_file="$(mktemp)"
  if ! find "$src_root" -type d -name '__PackageName__' -print0 > "$token_dirs_file"; then
    rm -f "$token_dirs_file"
    die "unable to inspect Kotlin package directories"
  fi
  while IFS= read -r -d '' dir; do
    case "$dir" in
      "$src_root/main/kotlin/__PackageName__"|"$src_root/test/kotlin/__PackageName__")
        package_dirs+=("$dir") ;;
      *)
        rm -f "$token_dirs_file"
        die "unsupported nested or misplaced __PackageName__ directory '$dir'. The package placeholder must be the direct source root." ;;
    esac
  done < "$token_dirs_file"
  rm -f "$token_dirs_file"
  for dir in "${package_dirs[@]}"; do
    parent="$(dirname "$dir")"
    dest="$parent/$pkg_rel_path"
    if destination_exists "$dest"; then
      die "cannot move '$dir': destination '$dest' already exists"
    fi
  done
fi

# 2) Replace tokens in file contents. Both initializers are skipped: they carry
#    the literal token strings as search keys, so substituting inside them would
#    corrupt the sibling script.
changed=0
content_files="$(mktemp)"
if ! find "$repo_root" -type d \( -name .git -o -name .jj -o -name build -o -name .gradle -o -name .idea \) -prune -o -type f -print0 > "$content_files"; then
  rm -f "$content_files"
  die "unable to enumerate template files"
fi
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
    *.kts|*.toml) p=$project_e; g=$group_e; a=$author_e; ae=$author_email_e; o=$owner_e; d=$desc_e; y=$year_e ;;
    *)            p=$project_name; g=$group; a=$author; ae=$author_email; o=$github_owner; d=$description; y=$year ;;
  esac
  # Preserve trailing newlines: append a sentinel before capture, strip it after.
  if ! content="$(cat "$file" || exit 1; printf x)"; then
    rm -f "$content_files"
    die "unable to read '$file'"
  fi
  content="${content%x}"
  orig="$content"
  content="${content//__ProjectName__/$p}"
  content="${content//__PackageName__/$package_name}"
  content="${content//__Group__/$g}"
  content="${content//__Author__/$a}"
  content="${content//__AuthorEmail__/$ae}"
  content="${content//__GitHubOwner__/$o}"
  content="${content//__Description__/$d}"
  content="${content//__Year__/$y}"
  if [ "$content" != "$orig" ]; then
    printf '%s' "$content" > "$file"
    changed=$((changed + 1))
  fi
done < "$content_files"
rm -f "$content_files"
echo "    Updated contents in $changed file(s)."

# 3) Move the token-named Kotlin package directory into the real dotted-package
#    tree (e.g. src/main/kotlin/__PackageName__ -> src/main/kotlin/com/acme/widgets).
#    A JVM source file must live in a directory matching its `package` declaration.
for dir in "${package_dirs[@]}"; do
    parent="$(dirname "$dir")"
    dest="$parent/$pkg_rel_path"
    if destination_exists "$dest"; then
      die "refusing to overwrite existing destination '$dest' while moving package '$dir'"
    fi
    mkdir -p "$(dirname "$dest")"
    mv -i "$dir" "$dest" < /dev/null
    if [ -e "$dir" ] || [ -L "$dir" ]; then
      die "move reported success but source directory '$dir' still exists"
    fi
    if destination_exists "$dest/__PackageName__"; then
      die "package move placed the source below an existing destination '$dest'"
    fi
    echo "    Moved ${parent#"$repo_root"/}/__PackageName__ -> ${parent#"$repo_root"/}/$pkg_rel_path"
done

# 4) Activate Claude Code shared settings if shipped as a .template.
if [ -f "$repo_root/.claude/settings.json.template" ]; then
  mv -f "$repo_root/.claude/settings.json.template" "$repo_root/.claude/settings.json"
  echo "    Activated .claude/settings.json"
fi

# 5) Remove template-only files (the agent guide is template meta — pitfalls are
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

# 6) Remove both initializers unless asked to keep them.
if [ "$keep_script" -ne 1 ]; then
  rm -f "$sibling_ps1"
  rm -f "$self"
fi
