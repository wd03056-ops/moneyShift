# 초대 딥링크 / 앱링크 설정 가이드

공유 링크 형식: `https://moneyshift.app/join?code=TVQ63FWB`

## 동작 요약

| 상황 | 동작 |
|------|------|
| 앱 설치됨 + App Links 검증됨 | 시스템이 앱으로 바로 오픈 → 참여 화면 |
| 앱 미설치 / 검증 실패 | 브라우저가 `docs/web/join/index.html` 랜딩 → 스토어 |
| 구 링크 `moneyshift://join?code=` | 앱 설치 시에만 동작 (메신저에선 HTTPS 권장) |

## 1. 웹 호스팅

다음을 `https://moneyshift.app`에 배포하세요.

| 경로 | 파일 |
|------|------|
| `/join` 또는 `/join/index.html` | `docs/web/join/index.html` |
| `/.well-known/assetlinks.json` | `docs/deeplink/assetlinks.json` |
| `/.well-known/apple-app-site-association` | `docs/deeplink/apple-app-site-association` |

`assetlinks.json`의 SHA-256은 Play App Signing 인증서 지문으로 교체합니다.

```bash
keytool -list -v -keystore upload-keystore.jks -alias upload
```

AASA의 `TEAMID`는 Apple Developer Team ID로 교체합니다.  
Content-Type은 `application/json` (확장자 없이 서빙).

## 2. Android

- `AndroidManifest.xml`에 `https://moneyshift.app/join` App Links + `moneyshift://` 스킴 등록됨
- Play Console → Deep links에서 도메인 확인
- 검증:  
  `adb shell am start -a android.intent.action.VIEW -d "https://moneyshift.app/join?code=DEMOJOIN"`

## 3. iOS

- `Info.plist`에 URL Scheme `moneyshift` 등록됨
- Xcode → Runner → Signing & Capabilities → **Associated Domains**  
  `applinks:moneyshift.app` 추가
- Bundle ID가 AASA `appID`와 일치해야 함

## 4. 앱 코드

- 링크 생성: `RoomInviteModel.inviteLink` → HTTPS
- 수신: `InviteDeepLinkService` (`app_links`)
- 미로그인 시 코드 저장 후, 로그인하면 `JoinRoomScreen`으로 이동

## 5. 스토어 URL

`AppConstants.playStoreUrl` / `appStoreUrl` 및 랜딩 HTML의 App Store ID를 배포 전 실제 값으로 교체하세요.
