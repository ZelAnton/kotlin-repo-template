# AGENTS.md

Conventions and guardrails for AI coding agents working in this repository. This
is the canonical, detailed reference; [CLAUDE.md](CLAUDE.md) is a shorter pointer
to it.

> **Template note:** this file ships with placeholder tokens (`__ProjectName__`,
> `__PackageName__`, `__Group__`, `__Author__`, `__GitHubOwner__`,
> `__Description__`, `__Year__`) that `scripts/init.ps1` stamps in. After
> initialization, fill the **Project** section below.

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
| Publish locally | `./gradlew publishToMavenLocal` |

The build is **warnings-as-errors** (`allWarningsAsErrors = true`) and runs
ktlint as part of `check`/`build`. A new warning or lint violation fails the
build; fix it rather than suppressing it.

## Toolchain

- **Kotlin 2.3+**, **Gradle 9.5** (wrapper), **JDK 25** via the Gradle toolchain
  (`jvmToolchain(25)`). The toolchain means the build does not depend on the JDK
  on `PATH` — Gradle provisions a matching one.
- Kotlin currently maxes out at the **JVM 24** bytecode target, so on JDK 25 the
  compiler prints "falling back to Kotlin JVM_24 JVM target". This is expected;
  do not lower the toolchain to silence it.

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
- JUnit 5 is aligned through `junit-bom`; declare `junit-*` artifacts without
  their own versions. `kotlin("test")` runs on the JUnit Platform via
  `useJUnitPlatform()`.
- Keep the Kotlin and ktlint-plugin versions compatible; when bumping Kotlin,
  check the ktlint-gradle plugin supports it.

## Tests

- Place tests under `src/test/kotlin/<package path>` mirroring the main package.
- Write them as JUnit 5 test classes with `@Test` methods. Backtick-quoted method
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
Delete it if you don't want CodeQL. Keep Dependabot
(`.github/dependabot.yml`) for dependency and Action updates either way.

## Version control workflow

Colocated git + [jujutsu (`jj`)](https://jj-vcs.github.io/jj/). Drive everything
through `jj` (git writes can desync the jj working copy; if unavoidable, follow
with `jj git import`).

- **Describe early:** `jj describe -m "..."` at the start of work; fold small
  follow-ups into the current change; re-`describe` on scope shift.
- **Orthogonal work:** ask before splitting — `jj new -m "..."` (descendant) or
  `jj new @- -m "..."` (parallel sibling).
- **Sync only on the user's explicit `pull`/`push`/`sync`:** `jj git fetch`;
  rebase if upstream advanced (`jj rebase -r @- -d main@origin`);
  `jj bookmark set main -r <rev>`; `jj git push`. **Never push without an
  explicit signal.**
- **Undo:** `jj undo`, `jj abandon <rev>`, `jj restore`, `jj op log` +
  `jj op restore <op-id>`.
- **No new bookmarks unless asked.** Work lands on `main`.
