plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.ktlint)
    // Publishing to Maven Central via the Sonatype Central Portal. This plugin
    // applies `maven-publish` + `signing` for you, builds the sources/javadoc
    // jars, and talks the Central Portal upload protocol (plain `maven-publish`
    // cannot). Remove it (and the `mavenPublishing` block below) for an app or
    // internal-only library.
    alias(libs.plugins.maven.publish)
}

group = "__Group__"
// Version comes from `-Pversion=<x.y.z>` (the release workflow passes it) and
// falls back to 0.1.0 for local builds. Assigning project.version explicitly
// keeps `publishToMavenLocal` and the Central Portal coordinates in sync.
version = providers.gradleProperty("version").getOrElse("0.1.0")
description = "__Description__"

kotlin {
    // Compile and run on JDK 25. Gradle provisions the toolchain, so the build
    // does not depend on whatever JDK happens to be on PATH.
    //
    // Note: Kotlin currently emits JVM 24 bytecode as its max target, so under a
    // JDK 25 toolchain the first compile prints an informational
    // "falling back to Kotlin JVM_24 JVM target" warning. It is not an error and
    // disappears once Kotlin ships a JVM 25 target.
    jvmToolchain(25)

    // Explicit API mode (strict): every public declaration must spell out its
    // visibility and return type. Recommended for libraries; drop to `warning`
    // or remove for an application.
    explicitApi()

    compilerOptions {
        // Warnings are build failures — the Kotlin analogue of the .NET
        // templates' TreatWarningsAsErrors.
        allWarningsAsErrors = true
    }
}

dependencies {
    // kotlin("test") routes to the JUnit Platform (Jupiter) backend because
    // junit-jupiter is on the test classpath and `useJUnitPlatform()` is set.
    testImplementation(kotlin("test"))
    testImplementation(platform(libs.junit.bom))
    testImplementation(libs.junit.jupiter)
    testRuntimeOnly(libs.junit.platform.launcher)
}

tasks.test {
    useJUnitPlatform()
}

// ---------------------------------------------------------------------------
// Publishing — Maven Central via the Sonatype Central Portal.
//
// Applies when the project ships a library. For an app or internal-only library,
// delete this block and the `com.vanniktech.maven.publish` plugin alias above.
//
// Credentials are read from Gradle properties / environment variables (the
// release workflow provides them as ORG_GRADLE_PROJECT_* — see
// .github/workflows/release.yml and TEMPLATE.md "Publishing to Maven Central"):
//   mavenCentralUsername / mavenCentralPassword  - Central Portal user token
//   signingInMemoryKey / signingInMemoryKeyPassword - GPG key + passphrase
//
// `./gradlew build` and `publishToMavenLocal` do NOT require any of these; only
// the `publish*ToMavenCentral` tasks do.
// ---------------------------------------------------------------------------
mavenPublishing {
    // The plugin auto-detects the Kotlin/JVM project and produces the main jar
    // plus the sources and (empty) javadoc jars that Maven Central requires. To
    // ship real API docs, apply the Dokka plugin and call
    // `configure(KotlinJvm(javadocJar = JavadocJar.Dokka("dokkaHtml")))`.

    // Upload to the Central Portal. `automaticRelease = false` uploads a staging
    // deployment you release from the Portal UI; set it to true to auto-release
    // once validation passes.
    publishToMavenCentral(automaticRelease = false)

    // Central requires signed artifacts, but signing must NOT break key-free
    // builds: `publishToMavenLocal` (and any publish task) would otherwise fail
    // with "no configured signatory". Sign only when a key is provided — the
    // release workflow sets ORG_GRADLE_PROJECT_signingInMemoryKey, which Gradle
    // exposes as the `signingInMemoryKey` project property.
    if (providers.gradleProperty("signingInMemoryKey").isPresent) {
        signAllPublications()
    }

    coordinates(group.toString(), rootProject.name, version.toString())

    pom {
        name = rootProject.name
        description = project.description
        url = "https://github.com/__GitHubOwner__/__ProjectName__"

        licenses {
            license {
                name = "MIT License"
                url = "https://opensource.org/licenses/MIT"
            }
        }
        developers {
            developer {
                name = "__Author__"
            }
        }
        scm {
            url = "https://github.com/__GitHubOwner__/__ProjectName__"
            connection = "scm:git:https://github.com/__GitHubOwner__/__ProjectName__.git"
            developerConnection = "scm:git:ssh://git@github.com/__GitHubOwner__/__ProjectName__.git"
        }
    }
}
