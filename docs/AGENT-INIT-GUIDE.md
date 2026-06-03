# Agent init guide — Kotlin repository template

Read this **before** initializing a repo from this template. It is a living
document: when an initialization session hits a mistake the guide didn't cover,
add it to the failure log at the bottom (in the *template's* copy — this file is
deleted from downstream repos by the init script).

## TL;DR

1. **Read the layout, don't assume it.** This is a Gradle (Kotlin DSL) library,
   not Maven, not Android. There is one root module.
2. **Check the toolchain first.** Run `scripts/check-env.ps1` (or
   `scripts/check-env.sh`). If it reports a missing or too-old JDK, STOP and offer
   the user the install commands it prints — don't run init against an environment
   that can't launch Gradle.
3. **Run the init script — don't hand-edit tokens.** `scripts/init.ps1`
   (PowerShell) or `scripts/init.sh` (POSIX) does the substitution *and* the
   package-directory move. Doing it by hand misses the directory move and breaks
   the build.
4. **Verify with `./gradlew build`** (the wrapper, not a system `gradle`).
5. **Use the wrapper.** First run downloads the Gradle distribution; let it.
6. **Make agent instructions local.** After init, untrack `CLAUDE.md`,
   `AGENTS.md`, and `.claude/` in the new repo so they don't push to its remote
   (see "Make agent instructions local in the new repo" below).

## What the template actually is

- A single-module Kotlin/JVM **library** crate-equivalent.
- Build: `build.gradle.kts` + `settings.gradle.kts`, versions in
  `gradle/libs.versions.toml` (version catalog).
- Toolchain: Kotlin 2.3, Gradle 9.5 (wrapper), JDK 25 via `jvmToolchain(25)`.
- Style: spaces (4), ktlint, `explicitApi()` strict, warnings-as-errors.
- Tests: JUnit 6 via a BOM + `useJUnitPlatform()`, `kotlin("test")`.
- Placeholder tokens substituted by the init script: `__ProjectName__`,
  `__PackageName__`, `__Group__`, `__Author__`, `__AuthorEmail__` (release-commit
  identity in `release.yml`), `__GitHubOwner__`, `__Description__`, `__Year__`.

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

## JVM target: keep Kotlin at 2.3+

The build runs a JDK 25 toolchain and targets JVM 25 bytecode. **Kotlin 2.3** is
the first release that emits a JVM 25 target; on Kotlin 2.2 the compiler silently
falls back to JVM 24 under a JDK 25 toolchain — you'd ship 24 bytecode without an
error. The catalog pins Kotlin 2.3+ for exactly this reason, so don't drop below
it.

Don't lower `jvmToolchain(25)` to chase a target mismatch either: the toolchain
only controls which JDK runs the build, and 25 is what's installed. If you
deliberately want older bytecode from a recent toolchain, set the Kotlin
`jvmTarget` **and** the Java `sourceCompatibility`/`targetCompatibility` together
(Gradle fails the build if they disagree).

## The happy path (standard single-module init)

First check the environment — if `check-env` flags a missing/too-old JDK, stop and
offer the user the install commands it prints before continuing:

```pwsh
pwsh ./scripts/check-env.ps1
pwsh ./scripts/init.ps1 -ProjectName acme-widgets -PackageName com.acme.widgets -Author "Jane Doe" -AuthorEmail jane@acme.com -GitHubOwner acme -Description "Widget toolkit"
./gradlew build
```

```bash
bash ./scripts/check-env.sh
bash ./scripts/init.sh --project-name acme-widgets --package-name com.acme.widgets --author "Jane Doe" --author-email jane@acme.com --github-owner acme --description "Widget toolkit"
./gradlew build
```

Then replace `greet` with the real API, update the test, fill the Architecture
section of CLAUDE.md, and commit.

## Make agent instructions local in the new repo

In the repo you create from this template, `CLAUDE.md` / `AGENTS.md` / `.claude/`
— and any other agent-instruction files you add later (e.g. `.cursorrules`,
`.github/copilot-instructions.md`) — are **your local agent instructions**.
Untrack them after init so they stay on disk but never reach that repo's remote.
(This is about the **downstream** repo; the template repo itself keeps these
tracked and shared.) `init` does **not** change tracking — this is a **by-hand
step.** A `.gitignore` rule won't untrack already-committed files — add a
local-only ignore (not pushed, honoured by `jj` too) and drop them from the
index:

```sh
printf '/CLAUDE.md\n/AGENTS.md\n' >> .git/info/exclude
git rm --cached CLAUDE.md AGENTS.md          # jj: jj file untrack CLAUDE.md AGENTS.md
git commit -m "Keep agent instructions local"
```

`.claude/` needs an extra step: the committed `.gitignore` force-ships
`settings.json` / `settings.json.template`, and that negation outranks
`.git/info/exclude`, so a local exclude can't hide them. See TEMPLATE.md "Make
agent instructions local in the new repo" → "`.claude/`" for the `.gitignore`
edit that takes the whole directory local.

Do this **before the first push** (a repo made via *Use this template* still
keeps these files in its initial commit's history). `init` deletes this guide and
TEMPLATE.md, so the surviving copy of this recipe downstream is the
"Agent instructions are local-only in this (generated) repo" section in
`AGENTS.md` — that is the one to consult after init or on the by-hand path.

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
