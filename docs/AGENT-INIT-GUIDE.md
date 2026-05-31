# Agent init guide — Kotlin repository template

Read this **before** initializing a repo from this template. It is a living
document: when an initialization session hits a mistake the guide didn't cover,
add it to the failure log at the bottom (in the *template's* copy — this file is
deleted from downstream repos by the init script).

## TL;DR

1. **Read the layout, don't assume it.** This is a Gradle (Kotlin DSL) library,
   not Maven, not Android. There is one root module.
2. **Run the init script — don't hand-edit tokens.** `scripts/init.ps1`
   (PowerShell) or `scripts/init.sh` (POSIX) does the substitution *and* the
   package-directory move. Doing it by hand misses the directory move and breaks
   the build.
3. **Verify with `./gradlew build`** (the wrapper, not a system `gradle`).
4. **Use the wrapper.** First run downloads the Gradle distribution; let it.

## What the template actually is

- A single-module Kotlin/JVM **library** crate-equivalent.
- Build: `build.gradle.kts` + `settings.gradle.kts`, versions in
  `gradle/libs.versions.toml` (version catalog).
- Toolchain: Kotlin 2.3, Gradle 9.5 (wrapper), JDK 25 via `jvmToolchain(25)`.
- Style: spaces (4), ktlint, `explicitApi()` strict, warnings-as-errors.
- Tests: JUnit 5 via a BOM + `useJUnitPlatform()`, `kotlin("test")`.

## The package-directory trap (Kotlin-specific)

A JVM source file's directory path **must** match its `package` declaration. The
template ships sources under `src/main/kotlin/__PackageName__/` and
`src/test/kotlin/__PackageName__/` with `package __PackageName__` inside. The init
script does two things that must both happen:

1. replaces the `__PackageName__` token in file contents with the dotted package
   (e.g. `com.acme.widgets`);
2. **moves** `…/kotlin/__PackageName__/` to `…/kotlin/com/acme/widgets/`.

If you substitute tokens by hand and forget the move, the file declares
`package com.acme.widgets` while living in a directory named `__PackageName__` —
Kotlin compiles it (it warns, not errors, on mismatched dirs for non-`main`), but
it's wrong and confuses tooling. Always use the script.

## The JDK-25 fallback warning is not an error

On a JDK 25 toolchain the Kotlin compiler prints:

```
'compileJava' task (current target is 25) and 'compileKotlin' task ... jvmTarget (24) ...
warning: ... falling back to Kotlin JVM_24 JVM target
```

This is expected — Kotlin's max bytecode target is JVM 24 at the time of writing.
Do **not** lower `jvmToolchain` to 24 to silence it; the toolchain controls which
JDK runs the build, and 25 is what's installed. The warning disappears when
Kotlin ships a JVM 25 target.

## The happy path (standard single-module init)

```pwsh
pwsh ./scripts/init.ps1 -ProjectName acme-widgets -PackageName com.acme.widgets -Author "Jane Doe" -GitHubOwner acme -Description "Widget toolkit"
./gradlew build
```

```bash
bash ./scripts/init.sh --project-name acme-widgets --package-name com.acme.widgets --author "Jane Doe" --github-owner acme --description "Widget toolkit"
./gradlew build
```

Then replace `greet` with the real API, update the test, fill the Architecture
section of CLAUDE.md, and commit.

## Tooling discipline

- **Don't run many slow Gradle invocations in parallel.** A wrapper build is
  minutes on first run (distribution + dependency download). Run one, wait for it,
  read the result. Queuing several and then interrupting cascades into confusing
  failures.
- **Use the wrapper**, not a system `gradle`, so the version matches.
- On Windows, paths like `C:\Program Files\...` contain spaces — make sure any
  tool you shell out to is invoked so the space is handled (this bit an old
  ktlint-gradle release; 14.x is fine).

## Updating this guide

When you trip over something not covered here, append a dated entry to the
failure log below **in the template repo** so the next initialization avoids it.

## Failure log

- *(none yet — add entries as `YYYY-MM-DD — symptom — root cause — fix`)*
