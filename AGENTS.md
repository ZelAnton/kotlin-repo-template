# AGENTS.md

Conventions and guardrails for AI coding agents working in this repository. This
is the canonical, detailed reference; [CLAUDE.md](CLAUDE.md) is a shorter pointer
to it.

> **Template note:** this file ships with placeholder tokens (`__ProjectName__`,
> `__PackageName__`, `__Group__`, `__Author__`, `__GitHubOwner__`,
> `__Description__`, `__Year__`) that `scripts/init.ps1` stamps in. After
> initialization, fill the **Project** section below.

## Agent instructions are local-only in this (generated) repo

`CLAUDE.md`, `AGENTS.md`, and `.claude/` — plus any other agent-instruction files
you add later (e.g. `.cursorrules`, `.github/copilot-instructions.md`) — are
guidance for whoever, human or agent, works in this checkout, not project source.
In a repo **generated from the template** they should be **untracked and
git-ignored** so they stay on disk for tooling but never reach the remote; each
developer keeps their own. (This is downstream only — the *template* repo keeps
them tracked and shared. If you are reading this in the template itself, leave
them tracked.)

`scripts/init.ps1` does **not** change tracking — this is a **by-hand step.** If
it has not been done yet in this repo, do it **before the first push**:

- `CLAUDE.md` / `AGENTS.md` — keep the rule local (never pushed, no filename trace
  in the remote) via `.git/info/exclude`, then drop them from the index:

  ```sh
  printf '/CLAUDE.md\n/AGENTS.md\n' >> .git/info/exclude
  git rm --cached CLAUDE.md AGENTS.md          # jj: jj file untrack CLAUDE.md AGENTS.md
  ```

- `.claude/` — the committed `.gitignore` force-ships `settings.json`
  (`!.claude/settings.json`), and that negation outranks `.git/info/exclude`, so a
  local exclude can't hide it. **Delete** the `!.claude/settings.json` /
  `!.claude/settings.json.template` lines from `.gitignore` (then `.claude/*`
  ignores the whole directory) and untrack it:

  ```sh
  git rm -r --cached .claude                   # jj: jj file untrack .claude
  ```

`jj file untrack` only accepts already-ignored paths, so add the ignore rule
first. Untracking stops these files going *forward* — a repo made via *Use this
template* still has them in its initial commit on the remote (they survive in
history); for a clean slate, copy into a fresh `git init` and untrack before the
first commit. To keep them shared instead, do nothing here.

## Project

> **Fill this in.** One paragraph on what `__ProjectName__` does, its public
> surface, and the main packages/types. Note any non-obvious design decisions so
> an agent can navigate without re-deriving the structure.

## Build, test, lint

Use the Gradle **wrapper** (`./gradlew`, `gradlew.bat` on Windows) — never a
system `gradle` — so the build always runs against the pinned version.

| Task | Command |
|---|---|
| Full build (compile + test + lint) | `./gradlew build` |
| Tests only | `./gradlew test` |
| One test | `./gradlew test --tests "__PackageName__.GreeterTest"` |
| Lint | `./gradlew ktlintCheck` |
| Auto-format | `./gradlew ktlintFormat` |
| Coverage report (Kover, opt-in¹) | `./gradlew koverHtmlReport` |
| Publish locally | `./gradlew publishToMavenLocal` |

¹ **Kover is opt-in** and off by default — the `koverHtmlReport` task only exists
after you uncomment `alias(libs.plugins.kover)` in `build.gradle.kts` (see
TEMPLATE.md "Opt-in tooling"). Running it before then fails with *"Task
'koverHtmlReport' not found"*.

The build is **warnings-as-errors** (`allWarningsAsErrors = true`) and runs
ktlint as part of `check`/`build`. A new warning or lint violation fails the
build; fix it rather than suppressing it.

## Toolchain

- **Kotlin 2.3+**, **Gradle 9.5** (wrapper), **JDK 25** toolchain
  (`jvmToolchain(25)`) — the build both compiles on and targets JVM 25, so the
  published artifact needs a JDK 25+ runtime. The toolchain means the build does
  not depend on the JDK on `PATH`: the **foojay resolver** (`settings.gradle.kts`)
  downloads a matching JDK when one isn't installed.
- To target an older runtime, lower `jvmToolchain(...)` to an LTS (17/21). If you
  want a recent toolchain but older bytecode, set the Kotlin `jvmTarget` **and**
  the Java source/target compatibility to the same version — Gradle fails the
  build if the Kotlin and Java JVM targets disagree.
- Opt-in tooling (declared in the catalog, off by default — see TEMPLATE.md):
  **Kover** coverage and the **Binary Compatibility Validator** that pairs with
  `explicitApi()` to guard the public ABI.

## Code style

- **4-space indentation, spaces not tabs**, LF line endings, UTF-8, final
  newline — enforced by `.editorconfig` and ktlint (`kotlin.code.style=official`).
- **`explicitApi()` is on (strict).** Every public declaration must state its
  visibility modifier and return type explicitly. Keep the public surface small;
  mark internals `internal` or `private`.
- Prefer immutable data (`val`, read-only collections), expression bodies where
  they read clearly, and top-level / `object` functions over needless classes.
- Reserve `@Suppress` for cases with a written justification on the annotation.

### Exception handling

- No one-line `try` / `catch` / `finally` — each keyword owns a braced block on
  its own lines.
- Every empty `catch` carries a comment naming the expected exception and why
  doing nothing is correct. Example:

  ```kotlin
  try {
      watcher.close()
  } catch (_: IOException) {
      // already closed during concurrent teardown; nothing to recover.
  }
  ```

## Dependencies and versions

- **All versions live in `gradle/libs.versions.toml`** (the version catalog).
  Reference them as `libs.<alias>` / `libs.plugins.<alias>`; never hard-code a
  version inline in `build.gradle.kts`.
- It is **not** a fixed allow-list — add what the project needs, each as a
  catalog entry. Give a non-obvious dependency a short comment on why it's there.
- JUnit 6 is aligned through `junit-bom`; declare `junit-*` artifacts without
  their own versions. `kotlin("test")` runs on the JUnit Platform via
  `useJUnitPlatform()`.
- Keep the Kotlin and ktlint-plugin versions compatible; when bumping Kotlin,
  check the ktlint-gradle plugin supports it.

## Tests

- Place tests under `src/test/kotlin/<package path>` mirroring the main package.
- Write them as JUnit 6 test classes with `@Test` methods. Backtick-quoted method
  names (`` `greet returns greeting with name` ``) are encouraged for readability.
- Run after a build (or let the test task build); assert behaviour, not
  implementation detail.

## Changelog

`CHANGELOG.md` is the single source of truth. Every user-visible change ships its
entry in the same change set, under `## [Unreleased]`
(`### Added/Changed/Fixed/Removed/Deprecated`), written for a consumer. Never edit
versioned sections — the release workflow owns those. Empty `[Unreleased]` is
auto-filled from commit subjects by git-cliff (`cliff.toml`); manual entries win.

## Security scanning

GitHub **CodeQL supports Kotlin** through its `java-kotlin` pack. A `codeql.yml`
workflow is included and ready to run; treat new alerts like build warnings.
CodeQL's Kotlin extractor lags new Kotlin releases, so a freshly bumped Kotlin
can be rejected with *"no source code seen during build"*. `codeql.yml` works
around this by raising `CODEQL_EXTRACTOR_KOTLIN_OVERRIDE_MAXIMUM_VERSION_LIMIT`
to the catalog's Kotlin version (safe across patch bumps); if a Kotlin *minor*
ever breaks extraction outright, delete the workflow until CodeQL adds support
or pin Kotlin to a supported release for CI. Delete it if you don't want CodeQL.
Keep Dependabot (`.github/dependabot.yml`)
for dependency and Action updates, and the dependency-submission workflow
(`.github/workflows/dependency-submission.yml`) so security alerts also cover
transitive dependencies.

## Version control workflow

Colocated git + [jujutsu (`jj`)](https://jj-vcs.github.io/jj/). Drive everything
through `jj` (git writes can desync the jj working copy; if unavoidable, follow
with `jj git import`).

**Evaluate each new prompt before editing** — classify the scope:

| Signal in prompt | Category | Action |
|---|---|---|
| Same topic, refinement, follow-up of in-progress work | **Continuation** | Just work. jj auto-folds edits into the current change. |
| Same change but goal has been refined or expanded | **Scope shift** | `jj describe -m "<refined summary>"`. **Don't** start a new change. |
| Orthogonal topic, different area, "теперь сделай X" | **New work** | If current change is finished → `jj new -m "<summary>"` (descendant). If still in progress → `jj new @- -m "..."` (parallel sibling). |

Reliable signals: word changes like "теперь" / "now" / "next" / "также сделай" / "and also" usually mean **new work** or **scope shift**. Imperative follow-ups inside the same scope ("исправь это", "fix this", "продолжи") mean **continuation**. When in doubt, ask the user.

- **Describe early:** `jj describe -m "..."` at the start of work; fold small
  follow-ups into the current change; re-`describe` on scope shift.
- **Orthogonal work:** ask before splitting — `jj new -m "..."` (descendant) or
  `jj new @- -m "..."` (parallel sibling).
- **Sync only on the user's explicit `pull`/`push`/`sync`:** `jj git fetch`
  (picks up merged PRs); rebase if upstream advanced
  (`jj rebase -r @- -d main@origin`); put the work on a **feature bookmark** —
  `jj bookmark create <topic> -r @` the first time (then
  `jj bookmark move <topic> --to @`), `jj git push --allow-new -b <topic>`; open
  a PR into `main` (`gh pr create --base main --head <topic> --fill`). `main`
  advances only via merged PRs. **Never push without an explicit signal.**
  *Fallback:* where `main` is unprotected, push it directly
  (`jj bookmark move main --to @`; `jj git push -b main`); once PRs are required
  this is rejected for everyone except an automated actor granted a bypass.
- **Undo:** `jj undo`, `jj abandon <rev>`, `jj restore`, `jj op log` +
  `jj op restore <op-id>`.
- **Feature bookmark per PR is the unit of work** (short kebab-case topic).
  Don't advance `main` locally to publish — it moves only via merged PRs and the
  release workflow's tag.
