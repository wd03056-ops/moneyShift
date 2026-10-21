# 카카오 로그인 설정 가이드

Money Shift 카카오 로그인(`kakao_flutter_sdk_user` v2) 연동 절차입니다.

## 1. 카카오디벨로퍼스 앱 등록

1. [Kakao Developers](https://developers.kakao.com) → 내 애플리케이션 → 애플리케이션 추가
2. **앱** → **플랫폼 키**에서 **네이티브 앱 키** 확인
3. **카카오 로그인** 활성화
4. 동의항목: 닉네임(필수), 프로필 사진(선택), 카카오계정(이메일)(선택)

### 플랫폼 등록

| 플랫폼 | 값 |
|--------|-----|
| Android 패키지명 | `com.money.money_shift` |
| Android 키 해시 | 아래 §2에서 추출한 Debug / Release 키 해시 |
| iOS 번들 ID | `com.money.moneyShift` |

Redirect URI(자동): `kakao{NATIVE_APP_KEY}://oauth`

---

## 2. 디버그 키 해시(Debug Key Hash) 추출

에뮬레이터·실기기 디버그 빌드용 키 해시를 카카오 콘솔 Android 플랫폼에 등록합니다.

### A. 앱 실행 시 Dart 로그 (권장)

디버그 모드에서 `main()` 이 `KakaoSdk.init` 직후 키 해시를 출력합니다.

```text
========== Kakao Debug Key Hash ==========
origin (Key Hash): AbCdEfGhIjKlMnOpQrStUvWxYz=
packageName: com.money.money_shift
...
==========================================
```

`flutter run` 후 Logcat / 디버그 콘솔에서 `Kakao Debug Key Hash` 로 검색하세요.

수동 호출:

```dart
await KakaoAuthService.printDebugKeyHash();
```

### B. Windows PowerShell + keytool / OpenSSL

기본 디버그 키스토어 (`%USERPROFILE%\.android\debug.keystore`, 비밀번호 `android`):

```powershell
keytool -exportcert -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android | openssl sha1 -binary | openssl base64
```

OpenSSL 이 없다면 Git Bash 또는 WSL 에서 동일 명령을 실행합니다.

### C. macOS / Linux

```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64
```

### D. Release / Play App Signing

스토어 배포 전 **업로드 키** 또는 Play App Signing 인증서의 키 해시도 콘솔에 추가하세요.

```bash
keytool -exportcert -alias upload -keystore upload-keystore.jks | openssl sha1 -binary | openssl base64
```

---

## 3. 네이티브 앱 키를 프로젝트에 넣기

세 곳을 **동일 값**으로 맞춥니다. 플레이스홀더 `YOUR_NATIVE_APP_KEY` 를 실제 키로 교체합니다.

| 위치 | 용도 |
|------|------|
| `lib/core/config/kakao_config.dart` → `fallbackNativeAppKey` | Dart `KakaoSdk.init` |
| `android/kakao.properties` → `kakao.native.app.key` | AndroidManifest `kakao{key}://oauth` |
| `ios/Flutter/Kakao-Keys.xcconfig` → `KAKAO_NATIVE_APP_KEY` | Info.plist URL Scheme |

또는 빌드 시 주입:

```bash
flutter run --dart-define=KAKAO_NATIVE_APP_KEY=실제키
```

(`--dart-define` 사용 시에도 Android/iOS 네이티브 스킴 파일은 별도로 맞춰야 Redirect 가 동작합니다.)

---

## 4. 플랫폼 설정 요약 (이미 코드에 반영)

### Android

- `INTERNET` 권한
- `AuthCodeHandlerActivity` + `kakao${kakaoNativeAppKey}://oauth`  
  (Flutter SDK v2 명칭. 구 네이티브 SDK의 `KakaoTalkRedirectActivity` 와 동일 역할)
- `queries` → `com.kakao.talk` (설치 여부 확인)

### iOS

- `CFBundleURLTypes` → `kakao$(KAKAO_NATIVE_APP_KEY)`
- `LSApplicationQueriesSchemes` → `kakaokompassauth`, `kakaolink`, `kakaoplus`
- `Runner/Runner.entitlements` 연결됨 (Associated Domains 는 초대 Universal Links 용으로 주석 처리)

---

## 5. 앱 동작

1. `main()` → `KakaoSdk.init(nativeAppKey: KakaoConfig.nativeAppKey)`
2. 로그인 화면 **카카오 로그인** 버튼
3. `isKakaoTalkInstalled()`  
   - 설치됨 → `loginWithKakaoTalk()`  
   - 실패(취소 제외) 또는 미설치 → `loginWithKakaoAccount()`
4. Access Token + `UserApi.me()` (닉네임, 이메일, 프로필 이미지) → 목업 세션 로그인

관련 코드:

- `lib/features/auth/data/kakao_auth_service.dart`
- `lib/features/auth/presentation/widgets/kakao_login_button.dart`
- `lib/features/auth/presentation/login_screen.dart`

---

## 6. 체크리스트

- [ ] 네이티브 앱 키 3곳 동기화
- [ ] Debug 키 해시 콘솔 등록
- [ ] Android 패키지명 / iOS Bundle ID 등록
- [ ] 카카오 로그인 ON + 동의항목
- [ ] 실기기에서 카카오톡 로그인 / 미설치 시 계정 로그인 확인
