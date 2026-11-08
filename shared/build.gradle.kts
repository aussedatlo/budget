import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.sqldelight)
    // Applied below, except for iOS-only builds (Xcode), which need no Android SDK
    alias(libs.plugins.android.library) apply false
}

/** `-Pbudget.iosOnly=true`: the iOS framework only, as Xcode builds it. */
val iosOnly = providers.gradleProperty("budget.iosOnly").orNull == "true"

kotlin {
    compilerOptions {
        freeCompilerArgs.add("-Xexpect-actual-classes")
    }

    // Fast host tests (and the database tests, on the desktop SQLite driver)
    jvm {
        compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
    }

    listOf(iosArm64(), iosSimulatorArm64(), iosX64()).forEach { target ->
        target.binaries.framework {
            baseName = "BudgetCore"
            isStatic = true
        }
    }

    sourceSets {
        all {
            languageSettings.optIn("kotlin.time.ExperimentalTime")
        }
        commonMain.dependencies {
            api(libs.datetime)
            api(libs.coroutines.core)
            implementation(libs.serialization.json)
        }
        commonTest.dependencies {
            implementation(kotlin("test"))
        }
        iosMain.dependencies {
            implementation(libs.sqldelight.native)
        }
        jvmMain.dependencies {
            implementation(libs.sqldelight.jvm)
        }
    }
}

if (!iosOnly) {
    apply(plugin = "com.android.library")

    kotlin {
        androidTarget {
            compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
        }
        sourceSets.getByName("androidMain").dependencies {
            implementation(libs.sqldelight.android)
        }
    }

    extensions.configure<com.android.build.gradle.LibraryExtension> {
        namespace = "com.example.budget.core"
        compileSdk = libs.versions.android.compileSdk.get().toInt()
        defaultConfig {
            minSdk = libs.versions.android.minSdk.get().toInt()
        }
        compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
    }
}

sqldelight {
    databases {
        create("BudgetDatabase") {
            packageName.set("com.example.budget.core.db")
        }
    }
}
