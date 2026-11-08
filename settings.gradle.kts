rootProject.name = "Budget"

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

include(":shared")

// Xcode builds only the iOS framework of the shared core (see project.yml):
// no Android SDK needed there
if (providers.gradleProperty("budget.iosOnly").orNull != "true") {
    include(":androidApp")
}
