plugins {
    // Foojay toolchain resolver — lets Gradle download the JDK 25 toolchain
    // (declared via jvmToolchain(25) in build.gradle.kts) when it is not already
    // installed locally. Without it, a machine lacking JDK 25 fails the build
    // instead of provisioning it. This is a settings plugin, so this is the
    // authoritative version: Gradle does not expose catalog plugin aliases in
    // settings scripts.
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

// The Gradle project / artifact name. `scripts/init.ps1` stamps the real name in.
rootProject.name = "__ProjectName__"

// Type-safe dependency catalog. gradle/libs.versions.toml is picked up
// automatically as the `libs` catalog — no extra wiring needed here.
dependencyResolutionManagement {
    repositories {
        mavenCentral()
    }
}
