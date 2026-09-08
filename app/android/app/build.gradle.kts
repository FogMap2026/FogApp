import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ⚠️ 아래 코드는 plugins {} 뒤에 와야 한다. Kotlin DSL 은 plugins {} 앞에 다른 문장을
//    허용하지 않는다(import 와 buildscript {} 만 예외).
//
// 릴리스 서명 키(원스토어 출시, 7-6). 두 경로로 읽는다.
//
//   로컬  : app/android/key.properties (gitignored)
//   CI    : 환경 변수 KEYSTORE_PATH / KEYSTORE_PASSWORD / KEY_ALIAS / KEY_PASSWORD
//
// ⛔ 키스토어와 비밀번호는 저장소에 커밋하지 않는다. .env·서비스 계정 키와 같은 취급이다.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

fun signingValue(propKey: String, envKey: String): String? =
    keystoreProperties.getProperty(propKey) ?: System.getenv(envKey)

val releaseStoreFile = signingValue("storeFile", "KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "KEY_PASSWORD")
val hasReleaseSigning = !releaseStoreFile.isNullOrBlank() &&
    !releaseStorePassword.isNullOrBlank() &&
    !releaseKeyAlias.isNullOrBlank() &&
    !releaseKeyPassword.isNullOrBlank() &&
    file(releaseStoreFile).exists()

android {
    namespace = "com.fogapp.fogapp"
    // 일부 플러그인(androidx 최신 버전 의존)이 compileSdk 34+ 를 요구합니다.
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications(#135)가 요구합니다. 없으면 빌드가
        // `checkDebugAarMetadata`에서 "requires core library desugaring to be enabled"로 실패합니다.
        // minSdk 23에서도 최신 java.time API를 쓸 수 있게 해주는 설정입니다.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fogapp.fogapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_naver_map(위치/지도 SDK)이 minSdkVersion 23을 요구합니다.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                // 키스토어는 PKCS12 다 — JKS 는 keytool 이 "outdated, 향후 제거" 경고를 낸다.
                // AGP 가 확장자·매직 바이트로 알아서 인식하기도 하지만 버전마다 다를 수 있어
                // 명시한다. 틀리면 빌드가 죽는데, 원인 메시지가 불친절하다.
                storeType = "PKCS12"
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // 키가 없으면 디버그 키로 서명된다 — 설치는 되지만 스토어에는 올릴 수 없다.
                //
                // ⚠️ 조용히 넘어가면 "빌드는 됐는데 업로드가 거부되는" 상태를 뒤늦게 안다.
                //    설정 방법은 docs/ONESTORE_RELEASE.md 참고.
                logger.warn(
                    "⚠️ 릴리스 서명 키가 없어 디버그 키로 서명합니다 — 스토어 업로드 불가. " +
                        "app/android/key.properties 또는 KEYSTORE_* 환경 변수를 설정하세요."
                )
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // 위 isCoreLibraryDesugaringEnabled 와 짝입니다 — 둘 중 하나만 있으면 빌드가 실패합니다.
    // flutter_local_notifications 22.x 가 2.1.4 이상을 요구합니다.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
