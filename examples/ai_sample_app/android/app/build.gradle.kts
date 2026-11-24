plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// True for a `patrol test` build (ENG-41597).
val patrolEnabled = project.findProperty("patrol-enabled") == "true"

configurations.all {
    resolutionStrategy {
        // Force AndroidX instead of support library
        force("androidx.core:core:1.17.0")
    }
    // Exclude old support library
    exclude(group = "com.android.support", module = "support-compat")
    exclude(group = "com.android.support", module = "support-v4")
}

android {
    namespace = "com.cometchat.sampleapp.flutter.android"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.cometchat.sampleapp.flutter.android"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        // Patrol builds (`patrol test` passes -Ppatrol-enabled=true) run the
        // offline E2E suite on PatrolJUnitRunner under Android Test
        // Orchestrator, one app process per test. App data is kept between
        // tests (no clearPackageData), so a relaunch case can read what the
        // test before it left. Every other build keeps the plain runner.
        testInstrumentationRunner =
            if (patrolEnabled) "pl.leancode.patrol.PatrolJUnitRunner"
            else "androidx.test.runner.AndroidJUnitRunner"
        if (patrolEnabled) {
            // MainActivityTest is the integration_test (FlutterTestRunner)
            // host; under Patrol it would wait forever for results that
            // never come. Patrol runs only PatrolMainActivityTest.
            testInstrumentationRunnerArguments["notClass"] =
                "com.cometchat.sampleapp.flutter.android.MainActivityTest"
        }
    }

    if (patrolEnabled) {
        testOptions {
            execution = "ANDROIDX_TEST_ORCHESTRATOR"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        // Flutter creates a 'profile' build type. cometchat_calls_sdk pulls in
        // React Native deps that only publish 'debug'/'release' variants.
        // configureEach runs during evaluation so matchingFallbacks isn't locked yet.
        configureEach {
            if (name == "profile") {
                matchingFallbacks += listOf("release")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    androidTestImplementation("androidx.test:runner:1.2.0")
    androidTestImplementation("androidx.test:rules:1.2.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.2.0")
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}

flutter {
    source = "../.."
}
