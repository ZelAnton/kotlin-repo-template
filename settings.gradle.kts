// The Gradle project / artifact name. `scripts/init.ps1` stamps the real name in.
rootProject.name = "__ProjectName__"

// Type-safe dependency catalog. gradle/libs.versions.toml is picked up
// automatically as the `libs` catalog — no extra wiring needed here.
dependencyResolutionManagement {
    repositories {
        mavenCentral()
    }
}
