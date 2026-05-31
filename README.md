# __ProjectName__

[![CI](https://github.com/__GitHubOwner__/__ProjectName__/actions/workflows/ci.yml/badge.svg)](https://github.com/__GitHubOwner__/__ProjectName__/actions/workflows/ci.yml)
[![Maven Central](https://img.shields.io/maven-central/v/__Group__/__ProjectName__)](https://central.sonatype.com/artifact/__Group__/__ProjectName__)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Kotlin](https://img.shields.io/badge/Kotlin-2.3-blueviolet?logo=kotlin)](https://kotlinlang.org)

__Description__

## Requirements

- JDK 17 or later to run; the build provisions and targets **JDK 25** via the
  Gradle toolchain. Kotlin **2.3**, Gradle **9.5** (via the wrapper).

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
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the version history.

## License

This project is licensed under the [MIT License](LICENSE).
