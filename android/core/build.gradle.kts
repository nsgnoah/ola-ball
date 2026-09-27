// Pure Kotlin: the rules, models, match state and stores, with no Android imports. The same
// boundary the iOS app keeps (`Models/`, `Engine/` are plain Swift), so both ports can be tested
// on the JVM and the MatchState JSON stays the cross-platform contract.
plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
}

kotlin {
    jvmToolchain(17)
}

sourceSets {
    test {
        // content/assets/decks.json and content/golden/*.json are written by the iOS test
        // OlaBallTests/CrossPlatformExportTests.swift; the tests here replay them.
        resources.srcDirs("../../content/assets", "../../content/golden")
    }
}

dependencies {
    api(libs.kotlinx.serialization.json)
    api(libs.kotlinx.coroutines.core)
    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
}

tasks.withType<Test> {
    testLogging {
        events("failed", "skipped")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
        showStandardStreams = false
    }
}
