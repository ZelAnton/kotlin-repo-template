# Kotlin repository template

A starting point for Kotlin (JVM) libraries built with Gradle (Kotlin DSL): a
version catalog, a strict `.editorconfig` + ktlint, `explicitApi()` and
warnings-as-errors, JUnit 6, cross-platform CI, an optional Maven Central release
pipeline, and conventions for agents in [CLAUDE.md](CLAUDE.md) /
[AGENTS.md](AGENTS.md).

> **AI agents:** before initializing a repo from this template, read
> [docs/AGENT-INIT-GUIDE.md](docs/AGENT-INIT-GUIDE.md). It captures the mistakes
> past initialization sessions made and is a living document you are expected to
> extend when new mistakes happen.

## Using this template

1. Create a new repository from this one (GitHub: **Use this template**), or copy
   the files into a fresh repo.
2. Run the init script once to stamp your project name in:

   ```pwsh
   pwsh ./scripts/init.ps1 -ProjectName acme-widgets -PackageName com.acme.widgets -Author "Jane Doe" -GitHubOwner acme -Description "Widget toolkit"
   ```

   On a POSIX shell (Linux/macOS, or git-bash) run the equivalent instead:

   ```bash
   bash ./scripts/init.sh --project-name acme-widgets --package-name com.acme.widgets --author "Jane Doe" --github-owner acme --description "Widget toolkit"
   ```

   `-ProjectName` is required; the rest are optional and fall back to sensible
   defaults (`git config user.name`, `your-org`, `io.github.<owner>` group, a
   package derived from group + project, a TODO description, the current year).
   The script:
   - replaces the placeholder tokens in every file's contents (values in `.kts`
     and `.toml` are escaped so quotes/backslashes can't break the script);
   - moves the token-named Kotlin package
     (`src/{main,test}/kotlin/__PackageName__`) into the real dotted-package
     directory tree — the Kotlin-specific step, since a source file must sit in a
     directory matching its `package` declaration;
   - activates `.claude/settings.json` from its shipped `.template` form;
   - deletes `TEMPLATE.md`, `docs/AGENT-INIT-GUIDE.md`, and (unless
     `-KeepScript`) both initializers.
3. Verify:

   ```sh
   ./gradlew build
   ```

4. Replace the placeholder `greet` function in `src/main/kotlin/...` with your
   real API and update the sample test.

## Make agent instructions local in the new repo (init step)

> **Scope.** This applies to the repository you **create from** this template,
> not to the template repo itself. In the template, `CLAUDE.md`, `AGENTS.md`, and
> `.claude/` stay **tracked and pushed** — they are the shared source the template
> distributes. The step below runs **once, in the downstream repo, after init.**

**Agent instruction:** when you initialize a new project from this template,
treat `CLAUDE.md`, `AGENTS.md`, `.claude/` — and any other agent-instruction
files you add later (e.g. `.cursorrules`, `.github/copilot-instructions.md`) — as
**local-only agent instructions**. After running `init`, untrack them so they
stay on disk for your tooling but never reach that repo's remote on a
commit/push. `init` does **not** change tracking; this is a **by-hand step**, so
do it before the first push.

A `.gitignore` entry alone won't do it: these files are **already tracked** (the
template ships them, and GitHub's *Use this template* commits them), and git
ignores `.gitignore` rules for paths it already tracks. You must both (1) stop
tracking a file and (2) add a **local-only** ignore — `.git/info/exclude`, which
lives in your clone and is **never pushed** (unlike `.gitignore`, which is itself
committed) — so it doesn't reappear as untracked and get re-added by accident.
The trade-off: `.git/info/exclude` is per-clone, so a fresh clone re-tracks these
files and you re-apply the steps. A colocated `jj` honours `.git/info/exclude`
too, but `jj file untrack` only accepts a path that is *already* ignored — so the
exclude (step 1) must come first.

### `CLAUDE.md` and `AGENTS.md`

These untrack cleanly with a local-only ignore:

```sh
# 1) Local-only ignore (not pushed).
printf '/CLAUDE.md\n/AGENTS.md\n' >> .git/info/exclude
# PowerShell: Add-Content .git/info/exclude '/CLAUDE.md', '/AGENTS.md'

# 2) Stop tracking the committed copies (kept on disk), then commit the removal.
git rm --cached CLAUDE.md AGENTS.md           # jj: jj file untrack CLAUDE.md AGENTS.md
git commit -m "Keep agent instructions local"
```

### `.claude/`

`.claude/` is a special case where a local-only exclude is **not enough**. The
committed `.gitignore` already ignores everything under `.claude/` *except*
`settings.json` and `settings.json.template`, which it **deliberately
force-ships** (`!.claude/settings.json`). A committed `.gitignore` negation
outranks `.git/info/exclude`, so adding `/.claude/` to the exclude does nothing
for those two files — they stay tracked, and after a bare `git rm --cached` they
re-surface as untracked (and `jj file untrack` refuses them outright, since they
aren't ignored).

To take `.claude/` fully local, **delete** the `!.claude/settings.json` and
`!.claude/settings.json.template` lines from `.gitignore` (a committed edit;
`.claude/*` then ignores the whole directory) and untrack the settings:

```sh
git rm -r --cached .claude                    # jj: jj file untrack .claude
git commit -m "Stop sharing .claude settings"
```

Or simply leave `settings.json` shared — the template's default intent.

**Do this before the first push.** Untracking stops these files going *forward*,
which is what matters day to day — but a repo created via GitHub's *Use this
template* already carries the template's copies in its **initial commit on the
remote**, so untracking drops them from the tip only; they survive in history.
For a repo that never contained them, copy the template into a fresh `git init`
and untrack before the first commit.

(In the **template repo**, skip all of this — its `CLAUDE.md` / `AGENTS.md` /
`.claude/` are meant to stay tracked and shared.)

## Placeholder tokens

| Token | Meaning |
|---|---|
| `__ProjectName__` | Gradle project / artifact name (`rootProject.name`), repo name |
| `__PackageName__` | Kotlin package (dotted) + the source directory path |
| `__Group__` | Maven group id (e.g. `com.acme`) |
| `__Author__` | author (LICENSE, POM developer) |
| `__AuthorEmail__` | author email (release-commit identity in `release.yml`) |
| `__GitHubOwner__` | GitHub owner/org in repository URLs |
| `__Description__` | project description |
| `__Year__` | copyright year |

## What differs from the C# / F# templates (Kotlin-specific)

- **Build system is Gradle (Kotlin DSL), not MSBuild.** `build.gradle.kts` +
  `settings.gradle.kts` replace the `.csproj`/`.slnx`; a **Gradle wrapper**
  (`./gradlew`) pins the Gradle version the way `global.json` pins the .NET SDK.
- **Version catalog instead of Central Package Management.**
  `gradle/libs.versions.toml` is the single source of dependency/plugin versions;
  build scripts use `libs.*` aliases.
- **Spaces, not tabs.** Kotlin official style (and ktlint) use 4-space indent, so
  this template indents with spaces — the same exception the F# template makes.
- **Source layout follows the JVM convention:** `src/main/kotlin/<package>` and
  `src/test/kotlin/<package>`, and the directory path must match the `package`
  declaration. The init script moves the token package directory accordingly.
- **ktlint, not `dotnet format`.** Formatting/linting is enforced by the
  `org.jlleitschuh.gradle.ktlint` plugin and checked in CI.
- **JUnit 6 (Jupiter)** is the test framework, wired via a BOM and
  `useJUnitPlatform()`.
- **CodeQL is enabled.** GitHub CodeQL supports Kotlin via its `java-kotlin`
  analysis; `codeql.yml` is included (delete it if unwanted). CI otherwise relies
  on warnings-as-errors + ktlint + Dependabot.
- **Builds on and targets JDK 25.** The Gradle toolchain (`jvmToolchain(25)`)
  uses Kotlin 2.3+ for the latest compiler and emits JVM 25 bytecode, so the
  published artifact needs a JDK 25+ runtime — lower `jvmToolchain(...)` to an LTS
  (17/21) for wider reach. The JDK 25 toolchain is downloaded automatically via
  the **foojay resolver** (`settings.gradle.kts`) when it isn't installed locally.
- **Coverage via Kover** (`org.jetbrains.kotlinx.kover`) — opt-in (see below):
  uncomment `alias(libs.plugins.kover)` in `build.gradle.kts`, then
  `./gradlew koverHtmlReport`.
- **Dependency graph submission.** `.github/workflows/dependency-submission.yml`
  feeds the resolved Gradle graph to GitHub so Dependabot alerts cover transitive
  dependencies too.

## Publishing to Maven Central

The release workflow publishes through the Sonatype **Central Portal**. Add these
repository secrets:

| Secret | Purpose |
|---|---|
| `MAVEN_CENTRAL_USERNAME` | Central Portal user token name |
| `MAVEN_CENTRAL_PASSWORD` | Central Portal user token password |
| `SIGNING_KEY` | ASCII-armored GPG private key (the artifacts must be signed) |
| `SIGNING_PASSWORD` | passphrase for that key |

The `group` in `build.gradle.kts` must be a namespace you have verified on the
Central Portal (e.g. `io.github.<owner>` is verifiable via your GitHub account).

### How the release workflow is ordered (and why a re-run is safe)

`release.yml` is built around one principle: **the upload to Maven Central is the
single irreversible step (the pivot)**, and it runs *before* any tag or GitHub
Release. The order is:

1. **Preflight secrets** — fails immediately if a publish secret is missing, before
   anything is built or uploaded.
2. **Build + test**, then **validate the publication with no upload** (a signed
   `publishToMavenLocal`) so packaging / POM / signing errors surface cheaply.
3. **Publish to Maven Central** — the pivot. Retried for transient failures; a
   version already published upstream is treated as success.
4. **Tag + push** (idempotent) and **GitHub Release** (upserts).

Because nothing reaches the registry, a tag, or a Release before the pivot, **any
pre-pivot failure leaves no trace** — just re-run. And because the version is an
explicit `workflow_dispatch` input (never auto-bumped from a manifest), **re-running
the whole workflow after a partial failure is also safe**: it can't skip or orphan a
version number. The lone manual case: if only the *GitHub Release* step fails for
good, the artifact is already published and the tag already pushed, so you can just
publish the Release by hand from the tag instead of re-running.

If you switch the publish task to `publishAndReleaseToMavenCentral` (auto-release),
verify that the "already published" detection in the publish step matches the
Central Portal's actual duplicate-version wording — it must recognise a genuine
re-run but must not match unrelated "already exists" noise.

## Optional pieces — remove what you don't need

- **Maven Central publishing** — if this is an app or internal library, delete
  `.github/workflows/release.yml`, the `com.vanniktech.maven.publish` plugin
  alias (in `build.gradle.kts` and `gradle/libs.versions.toml`), and the
  `mavenPublishing { }` block in `build.gradle.kts`. Keep CI.
- **CodeQL** — delete `.github/workflows/codeql.yml` if you don't want it.

## Opt-in tooling (wired but not enabled)

These are pre-declared in `gradle/libs.versions.toml` so enabling them is a
one-liner; left off by default to keep the out-of-the-box `./gradlew build` fast
and green.

- **Kover** — Kotlin code coverage (`koverHtmlReport` / `koverVerify`). Enable by
  uncommenting `alias(libs.plugins.kover)` in `build.gradle.kts`. Off by default
  because Kover's plugin classpath can clash with the Kotlin Gradle Plugin's
  embedded compiler on a bleeding-edge Kotlin; enable once a Kover release that
  matches your Kotlin version is available.
- **Binary Compatibility Validator** — the natural companion to `explicitApi()`:
  it records the public ABI in `api/*.api` and fails the build on an unintended
  change. Enable by uncommenting the
  `alias(libs.plugins.binary.compatibility.validator)` line in `build.gradle.kts`,
  then run `./gradlew apiDump` once and commit the generated `api/` directory.
  (It's off by default because `apiCheck` fails until that baseline exists, and a
  tokenized baseline can't be committed cleanly before `init`.)
- **detekt** — static analysis for code smells and complexity (ktlint only covers
  formatting). Add `detekt = "<latest>"` + a plugin alias to the catalog and apply
  `io.gitlab.arturbosch.detekt`. The current stable detekt targets an older Kotlin;
  confirm a build that supports Kotlin 2.3 before enabling.
- **Dokka** — real API docs in the published `-javadoc` jar (the default is an
  empty javadoc jar). Apply `org.jetbrains.dokka` and switch the publishing
  `configure(...)` call to `JavadocJar.Dokka("dokkaHtml")` as noted in
  `build.gradle.kts`.

## Post-setup checklist

- [ ] Maven Central secrets added (only if publishing).
- [ ] `LICENSE` author/year and license choice reviewed.
- [ ] `build.gradle.kts` POM metadata (description, URLs, developer) filled in.
- [ ] `group` is a namespace you can verify on the Central Portal.
- [ ] `CLAUDE.md` "Architecture" section written for your project.
- [ ] Agent-instruction files (`CLAUDE.md`, `AGENTS.md`, `.claude/`) made local —
      untracked + ignored so they don't reach the remote (before the first push).
      See "Make agent instructions local in the new repo".
- [ ] Branch protection for `main` configured — require pull requests (plus CI / CodeQL
      checks). The agent docs (`CLAUDE.md` / `AGENTS.md`) now assume a
      feature-branch + PR flow into `main`. Note the release workflow pushes a
      *release commit* **and** tag straight to `main` (the CHANGELOG promotion),
      so under branch protection that push is rejected unless the release actor
      can bypass it — configure the GitHub App bypass (repo variable
      `RELEASE_APP_ID` + secret `RELEASE_APP_PRIVATE_KEY`) as documented in
      `release.yml`. While `main` is unprotected it falls back to `GITHUB_TOKEN`
      and works without the App.
