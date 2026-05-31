# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> This is the Kotlin sibling of `cSharp-repo-template` / `fSharp-repo-template` /
> `rust-repo-template`, scaffolded by mirroring those and adapting for Kotlin +
> Gradle. It is a **token template**: `__ProjectName__`, `__PackageName__`,
> `__Group__`, `__Author__`, `__GitHubOwner__`, `__Description__`, and `__Year__`
> are stamped in by `scripts/init.ps1` (or the POSIX `scripts/init.sh`). Read
> [TEMPLATE.md](TEMPLATE.md) and [AGENTS.md](AGENTS.md) for the full layout and
> the enforced conventions; the Kotlin-specific deviations are summarised in
> TEMPLATE.md.

## Commands

```bash
# Build everything (compile + test + ktlint) — warnings are errors.
./gradlew build

# Run only the tests.
./gradlew test

# Run a single test class or method.
./gradlew test --tests "__PackageName__.GreeterTest"
./gradlew test --tests "*GreeterTest.greet*"

# Lint / auto-format Kotlin (ktlint is the style authority; CI fails on lint errors).
./gradlew ktlintCheck
./gradlew ktlintFormat

# Publish to the local Maven repository for manual consumption.
./gradlew publishToMavenLocal
```

The repository ships a **Gradle wrapper** (`./gradlew` / `gradlew.bat`); always
use it rather than a system `gradle` so the build runs against the pinned Gradle
version. The first invocation downloads the distribution.

## Architecture

> **Fill this in for `__ProjectName__`.** Describe the public surface, the main
> types/packages, and any non-obvious design decisions so an agent can navigate
> the code without re-deriving the structure each time.

The library package is `__PackageName__`; source lives under
`src/main/kotlin/<package path>` and tests under `src/test/kotlin/<package path>`.
Keep the public API surface small and intentional, prefer immutable types and
top-level / `object` functions, keep implementation details `internal`, and
prefer simple, direct code over new abstractions.

### Explicit API mode

`build.gradle.kts` enables `explicitApi()` (strict). Every public declaration
**must** spell out its visibility modifier and its return type — an inferred
return type or an implicit `public` on an exposed declaration is a compile error.
This keeps the published API surface deliberate. Drop it to `explicitApi =
ExplicitApiMode.Warning` or remove it entirely if this becomes an application
rather than a library.

### Warnings are errors

`allWarningsAsErrors = true` in the Kotlin compiler options — the analogue of the
.NET templates' `TreatWarningsAsErrors`. A new compiler warning fails the build;
fix it rather than suppressing it, and reserve `@Suppress` for cases with a
written justification.

### JDK 25 toolchain note

The build targets a JDK 25 toolchain (`jvmToolchain(25)`). Kotlin's maximum
bytecode target is currently JVM 24, so the compiler emits an informational
"falling back to Kotlin JVM_24 JVM target" message on JDK 25. This is expected,
not an error, and goes away when Kotlin ships a JVM 25 target. Do not "fix" it by
lowering the toolchain.

### Exception-handling style

- **No one-line `try` / `catch` / `finally`.** Each keyword owns its own braced
  block on its own lines.
- **Every empty `catch` carries a comment** explaining which exception is
  expected and why swallowing it is correct here. A bare empty block is not
  acceptable.

## Dependencies and versions

All dependency and plugin **versions** live in `gradle/libs.versions.toml` (the
Gradle *version catalog* — the Kotlin analogue of .NET Central Package
Management). Build scripts reference them as `libs.<alias>` /
`libs.plugins.<alias>` and never hard-code a version inline. It is **not** a
fixed allow-list — add the production and test dependencies the project actually
needs, each as a catalog entry.

The JUnit 5 (Jupiter) test stack is wired through the catalog's `junit-bom`, so
individual `junit-*` artifacts are declared without their own versions.
`kotlin("test")` is mapped onto the JUnit Platform via `useJUnitPlatform()`.

## Changelog

`CHANGELOG.md` is the single source of truth for release notes. **Every
user-visible change ships its changelog entry in the same change set**, under
`## [Unreleased]` (`### Added/Changed/Fixed/Removed/Deprecated`). Write it for a
consumer of the library, one bullet per distinct user-visible effect. Never edit
the versioned sections — the release workflow manages those.

If `[Unreleased]` is empty at release time, [git-cliff](https://git-cliff.org/)
(`cliff.toml`) auto-fills it from commit subjects, bucketed by first word
(`Add`/`Feat`→Added, `Fix`/`Bug`→Fixed, `Remove`/`Delete`/`Drop`→Removed,
`Doc`/`Chore`/`Test`→skipped, else→Changed). Manual entries always win — write
commit subjects accordingly.

## Release packaging

> Applies when the repository ships a library. If `__ProjectName__` is an app or
> internal-only, delete `.github/workflows/release.yml`, the
> `com.vanniktech.maven.publish` plugin alias, and the `mavenPublishing { }`
> block in `build.gradle.kts`.

The release workflow builds the jar + sources + javadoc jars, signs them with the
configured GPG key, and publishes to Maven Central via the Central Portal (using
the `com.vanniktech.maven.publish` plugin — plain `maven-publish` cannot reach the
Central Portal). See TEMPLATE.md "Publishing to Maven Central" for the required
secrets (`MAVEN_CENTRAL_USERNAME`, `MAVEN_CENTRAL_PASSWORD`, `SIGNING_KEY`,
`SIGNING_PASSWORD`).

## Version control workflow

The repo is colocated git + [jujutsu (`jj`)](https://jj-vcs.github.io/jj/); use
`jj`, not raw git.

- **Describe early:** `jj describe -m "..."` when starting work. Fold small
  follow-ups into the current change; re-`describe` if scope shifts.
- **Orthogonal work:** ask before splitting — `jj new -m "..."` (descendant) or
  `jj new @- -m "..."` (parallel sibling).
- **Sync only on the user's explicit `pull`/`push`/`sync`:** `jj git fetch`;
  rebase if upstream advanced (`jj rebase -r @- -d main@origin`);
  `jj bookmark set main -r <rev>`; `jj git push`. **Never push without an
  explicit signal.**
- **Undo via jj's safety net:** `jj undo`, `jj abandon <rev>`, `jj restore`,
  `jj op log` + `jj op restore <op-id>`.
- **No new bookmarks unless asked.** Work lands on `main` (the publish target).
