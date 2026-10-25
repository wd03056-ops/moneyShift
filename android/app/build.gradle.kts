plugins {
    id("com.android.application")
    // Flutter 내장/위임 Kotlin — 앱 모듈에서 kotlin-android 수동 적용하지 않음
    // (settings.gradle.kts 의 org.jetbrains.kotlin.android apply false 로 버전만 제공)
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase (android/app/google-services.json 필요 — flutterfire configure)
    id("com.google.gms.google-services")
}

// Gradle Kotlin DSL 에서 `java` 는 Project.java 확장이라 `java.util.Properties` 가
// Unresolved reference 'util' 로 깨진다. Properties 대신 텍스트로 키를 읽는다.
fun readKakaoNativeAppKey(): String {
    val fromEnv = System.getenv("KAKAO_NATIVE_APP_KEY")?.trim().orEmpty()
    if (fromEnv.isNotEmpty()) return fromEnv

    val file = rootProject.file("kakao.properties")
    if (file.exists()) {
        for (raw in file.readLines()) {
            val line = raw.trim()
            if (line.isEmpty() || line.startsWith("#")) continue
            if (line.startsWith("kakao.native.app.key=")) {
                val value = line.substringAfter("=").trim()
                if (value.isNotEmpty()) return value
            }
        }
    }

    return "f180fab248825101fa969428a27827e8"
}

val kakaoNativeAppKey: String = readKakaoNativeAppKey()

android {
    namespace = "com.money.money_shift"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 등 Java 8+ API 용
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.money.money_shift"
        // Firebase Auth / Messaging · AdMob 권장 하한
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 카카오 로그인 Redirect URI: kakao{NATIVE_APP_KEY}://oauth
        manifestPlaceholders["kakaoNativeAppKey"] = kakaoNativeAppKey
    }

    // AGP 9: resourceConfigurations 대신 localeFilters
    androidResources {
        localeFilters += listOf("ko", "en")
    }

    buildTypes {
        release {
            // Play 업로드 전: key.properties + signingConfigs.release 로 교체 필수
            // (현재는 로컬 검증용 debug 키 — 스토어 제출 금지)
            signingConfig = signingConfigs.getByName("debug")

            // Play 권장: R8 난독화 + 미사용 리소스 제거
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
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
    // Firebase BoM (플러그인이 transitive 로 가져오지만 버전 정렬용)
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))
    // flutter_local_notifications AAR metadata 요구사항
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
