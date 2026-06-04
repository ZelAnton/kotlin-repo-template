# __ProjectName__

[![CI](https://github.com/__GitHubOwner__/__ProjectName__/actions/workflows/ci.yml/badge.svg)](https://github.com/__GitHubOwner__/__ProjectName__/actions/workflows/ci.yml)
[![Maven Central](https://img.shields.io/maven-central/v/__Group__/__ProjectName__)](https://central.sonatype.com/artifact/__Group__/__ProjectName__)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Kotlin](https://img.shields.io/badge/Kotlin-2.4-blueviolet?logo=kotlin)](https://kotlinlang.org)

__Description__

## Requirements

- **JDK 25 or later** to *use* this library: the build targets JVM 25 bytecode.
  Lower `jvmToolchain(...)` in `build.gradle.kts` to support older JREs.
- Building from source: nothing but the repo — the Gradle wrapper provisions
  Gradle **9.5.1**, and the **JDK 25** toolchain is downloaded automatically (via
  the foojay resolver) if it isn't already installed. Kotlin **2.4**.

## Installation

Available on Maven Central.

```kotlin
dependencies {
    implementation("__Group__:__ProjectName__:<version>")
}
```

## Usage

```kotlin
import __PackageName__.greet

greet("World") // "Hello, World!"
```

TODO: replace the placeholder API above and document the real public surface.

## Building from source

```sh
./gradlew build          # compile, test, lint
./gradlew ktlintFormat   # auto-fix formatting
./gradlew koverHtmlReport # coverage (enable Kover first — opt-in, see below) → build/reports/kover/html/index.html
```

Kover is **opt-in**: uncomment `alias(libs.plugins.kover)` in `build.gradle.kts`
before `koverHtmlReport` exists as a task (see "Opt-in tooling" in TEMPLATE.md).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the version history.

## License

This project is licensed under the [MIT License](LICENSE).
