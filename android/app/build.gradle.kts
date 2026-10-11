import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystoreProperties = keystorePropertiesFile.exists()

if (hasKeystoreProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "jp.seichiquest.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Local debug builds may run without release-only signing secrets.
        // Release configuration is validated separately below.
        manifestPlaceholders["googleMapsApiKey"] =
            keystoreProperties.getProperty("googleMapsApiKey") ?: ""
        applicationId = "jp.seichiquest.app"
        minSdk = flutter.minSdkVersion
        // Google Play: 2026-08-31以降の新規アプリ/更新はAPI 36以上が必須。
        // Flutter SDK既定値の変化に左右されないよう、リリース要件を明示する。
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Debug / ProfileはGoogle公式テスト用AdMob App ID
        manifestPlaceholders["adMobAppId"] =
            "ca-app-pub-3940256099942544~3347511713"
    }

    if (hasKeystoreProperties) {
        signingConfigs {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Releaseは聖地クエスト本番用AdMob App ID
            manifestPlaceholders["adMobAppId"] =
                "ca-app-pub-1391846841313915~6472071786"

            // Releaseはupload keystoreで署名。設定がない場合はリリースタスクを失敗させる。
            if (hasKeystoreProperties) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// Do not block debug/profile builds when local release-signing secrets are absent.
// Never allow a release artifact to be produced without the required signing settings.
if (!hasKeystoreProperties) {
    tasks.configureEach {
        if (name == "assembleRelease" || name == "bundleRelease") {
            doFirst {
                throw GradleException(
                    "android/key.properties is required to build a signed release."
                )
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // Override the old WorkManager pulled in by Google Mobile Ads.
    implementation("androidx.work:work-runtime:2.11.2")
}
