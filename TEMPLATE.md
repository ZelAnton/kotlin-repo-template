# Kotlin repository template

A starting point for Kotlin (JVM) libraries built with Gradle (Kotlin DSL): a
version catalog, a strict `.editorconfig` + ktlint, `explicitApi()` and
warnings-as-errors, JUnit 5, cross-platform CI, an optional Maven Central release
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

## Placeholder tokens

| Token | Meaning |
|---|---|
| `__ProjectName__` | Gradle project / artifact name (`rootProject.name`), repo name |
| `__PackageName__` | Kotlin package (dotted) + the source directory path |
| `__Group__` | Maven group id (e.g. `com.acme`) |
| `__Author__` | author (LICENSE, POM developer) |
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
- **JUnit 5 (Jupiter)** is the test framework, wired via a BOM and
  `useJUnitPlatform()`.
- **No CodeQL by default.** GitHub CodeQL supports Kotlin via its `java-kotlin`
  analysis; a ready-to-enable `codeql.yml` is included but you may delete it.
  CI otherwise relies on warnings-as-errors + ktlint + Dependabot.
- **Targets JDK 25** through the Gradle toolchain (`jvmToolchain(25)`); requires
  Kotlin 2.3+, which is the first release with JDK 25 support.

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

## Optional pieces — remove what you don't need

- **Maven Central publishing** — if this is an app or internal library, delete
  `.github/workflows/release.yml`, the `com.vanniktech.maven.publish` plugin
  alias (in `build.gradle.kts` and `gradle/libs.versions.toml`), and the
  `mavenPublishing { }` block in `build.gradle.kts`. Keep CI.
- **CodeQL** — delete `.github/workflows/codeql.yml` if you don't want it.

## Post-setup checklist

- [ ] Maven Central secrets added (only if publishing).
- [ ] `LICENSE` author/year and license choice reviewed.
- [ ] `build.gradle.kts` POM metadata (description, URLs, developer) filled in.
- [ ] `group` is a namespace you can verify on the Central Portal.
- [ ] `CLAUDE.md` "Architecture" section written for your project.
- [ ] Branch protection / required checks configured for `main` (CI).
