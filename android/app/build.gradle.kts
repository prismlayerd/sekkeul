import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 릴리스 서명 키 — android/key.properties(절대 커밋 금지)에서 로드. 없으면 debug 서명으로 폴백.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.sekkeul.app"

    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.sekkeul.app"

        minSdk = flutter.minSdkVersion
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
        }

        // 성능을 재는 빌드. AOT로 컴파일돼 릴리스와 같은 속도로 돌지만,
        // 패키지가 달라 스토어에서 받은 앱 옆에 나란히 깔린다.
        //
        // 디버그(JIT)는 원래 프레임이 밀려서 "버벅인다"의 원인이 앱인지
        // 빌드 방식인지 가릴 수가 없다. 그걸 가르려고 둔다.
        // **release는 건드리지 않는다** — 스토어에 올리는 AAB에 영향이 가면 안 된다.
        getByName("profile") {
            applicationIdSuffix = ".profile"
        }

        release {
            // key.properties가 있으면 실서명, 없으면 debug로 폴백(빌드는 항상 성공).
            if (!keystorePropertiesFile.exists()) {
                logger.warn("⚠️  [세끌] android/key.properties가 없어 release 빌드가 debug 키로 서명됩니다 — 스토어 제출용 APK/AAB가 아닙니다.")
            }
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}