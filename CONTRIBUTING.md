# Contributing to __ProjectName__

Thanks for your interest in improving **__ProjectName__**.

## Prerequisites

- A **JDK 25** toolchain (the build both compiles on and targets JVM 25). You do
  not need it on `PATH` — the Gradle **foojay resolver** downloads a matching JDK
  automatically when one isn't installed.
- Nothing else: the repository ships a **Gradle wrapper** (`./gradlew`,
  `gradlew.bat` on Windows) that provisions the pinned Gradle version. Always use
  the wrapper, never a system `gradle`.

## Build and test

```sh
./gradlew build
./gradlew test
```

`./gradlew build` compiles, tests, and lints. The build treats **warnings as
errors** (`allWarningsAsErrors = true`) and runs ktlint as part of `check`, so a
clean local build is required before opening a pull request. Run a single test
with:

```sh
./gradlew test --tests "__PackageName__.GreeterTest"
```

## Conventions

- **Formatting** is governed by [`.editorconfig`](.editorconfig) and ktlint —
  4-space indentation (spaces, not tabs), LF line endings, UTF-8, final newline
  (`kotlin.code.style=official`). Run `./gradlew ktlintCheck` to verify and
  `./gradlew ktlintFormat` to auto-fix. Do not reformat code you are not changing.
- **`explicitApi()` is on (strict)** — every public declaration must spell out
  its visibility modifier and return type. Keep the public surface small; mark
  internals `internal` or `private`.
- **Dependencies and build plugins** use the Gradle version catalog — declare
  their versions in [`gradle/libs.versions.toml`](gradle/libs.versions.toml) and
  reference them as `libs.<alias>` / `libs.plugins.<alias>`; never hard-code a
  version inline in `build.gradle.kts`. Foojay is the intentional exception:
  its sole version is on the settings-plugin declaration in
  `settings.gradle.kts`, since settings plugins cannot use project catalog
  aliases. Do not add a catalog duplicate; verify changes with
  `scripts/check-foojay-single-source.ps1` or `scripts/check-foojay-single-source.sh`.
- See [`AGENTS.md`](AGENTS.md) for the full, authoritative set of conventions
  (exception-handling style, comments, architecture).

## Changelog

Every user-visible change ships its [`CHANGELOG.md`](CHANGELOG.md) entry in the
same change set, under `## [Unreleased]`. Write the bullet for a consumer of the
library, not the implementer. Pure internal refactors are exempt.

## Pull requests

- Keep changes focused; unrelated cleanups belong in their own PR.
- Ensure CI (build/test on Linux, Windows, macOS) and CodeQL pass.
- Fill in the pull-request checklist.
