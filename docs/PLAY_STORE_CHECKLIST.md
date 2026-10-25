# Google Play Store 제출 체크리스트 (Money Shift)

앱 코드에 반영된 항목과, Console에서 직접 채워야 할 항목을 정리합니다.

## 앱에 구현됨

- [x] 개인정보처리방침 인앱 화면 (로그인·내정보)
- [x] 이용약관 인앱 화면
- [x] 계정 삭제 (내정보 → 계정 삭제) — Play 계정 삭제 정책
- [x] 로그아웃
- [x] 오픈소스 라이선스 페이지
- [x] 앱 버전 표시
- [x] 위치 권한 요청 전 고지 다이얼로그 (출퇴근·매장 GPS)
- [x] 만 14세 이상 안내
- [x] 광고 ID 권한 제거 (`AD_ID` tools:node=remove)
- [x] HTTPS only (`usesCleartextTraffic=false`)
- [x] Release R8 minify / shrinkResources
- [x] 웹용 개인정보처리방침 초안: `docs/privacy_policy.html`

## Play Console에서 필수 입력

1. **개인정보처리방침 URL**  
   `https://moneyshift-ten.vercel.app/privacy`  
   (Vercel → Notion 302 리다이렉트. `AppConstants.privacyPolicyUrl`과 동일하게 Console에 등록)

2. **앱 콘텐츠 · Data safety**
   - 수집: 이름/이메일, 정확한 위치(앱 기능), 앱 활동(근무 기록), 기기·기타(푸시 토큰)
   - 위치: **앱 기능** 목적, 판매 안 함, 임시 처리 여부 명시
   - 광고·광고 ID: **사용 안 함**

3. **대상 연령**  
   만 14세 이상(또는 Play 등급 설문에 맞게). Designed for Families 해당 없음.

4. **계정 삭제 URL(웹)**  
   Console에 웹 삭제 안내 페이지가 필요하면,  
   “앱 내 내정보 → 계정 삭제” + 문의 이메일을 안내하는 짧은 페이지를 게시합니다.

5. **스토어 등록 정보**
   - 짧은/긴 설명, 스크린샷(폰), 아이콘 512, feature graphic 1024×500
   - 연락처 이메일: `AppConstants.supportEmail` 교체 후 사용

6. **서명 키**  
   `android/app/build.gradle.kts` release `signingConfig`를  
   upload keystore로 교체한 뒤 AAB 업로드:
   ```bash
   flutter build appbundle --release
   ```

7. **권한 선언 설문**
   - 위치: 출퇴근 인증(포그라운드)
   - 알림: 근무·공지 알림

## 배포 전 코드에서 바꿀 값

| 상수 | 파일 | 내용 |
|------|------|------|
| `supportEmail` | `lib/core/constants/app_constants.dart` | 실제 문의 메일 |
| `privacyPolicyUrl` | 동일 | `https://moneyshift-ten.vercel.app/privacy` |
| `termsOfServiceUrl` | 동일 | Notion 이용약관 URL |
| `applicationId` | 이미 `com.money.money_shift` | 필요 시 확정 |
| release signing | `android/app/build.gradle.kts` | debug 서명 제거 |
