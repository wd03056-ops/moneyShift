# FCM Cloud Functions 배포 가이드

프로젝트: `lunchtime-74f54` (Blaze 요금제 필요)  
리전: `asia-northeast3` (서울)

## 동작 요약

| 트리거 | 함수 | 수신자 |
|--------|------|--------|
| `schedules` 문서 생성 | `onScheduleCreated` | `workerUid` / `workerId` |
| `shift_requests` 생성 | `onShiftRequestCreated` | 매장 `ownerId` · `approverUid` · `targetWorkerUid` |
| `shift_requests` status 변경 | `onShiftRequestUpdated` | `applicantUid` · `targetWorkerUid` |
| `notification_jobs` 생성 | `dispatchNotificationJob` | 잡에 담긴 `fcmToken` / `recipientUid` |

앱 측: 로그인 시 `FcmService.bindUser(uid)` → `users/{uid}.fcmToken` 갱신.

## 1회성 준비

1. Firebase Console → 프로젝트 **Blaze** 업그레이드 (완료됨)
2. Google Cloud에서 Cloud Functions / Cloud Build / Eventarc API 활성화  
   (첫 `firebase deploy --only functions` 시 자동 활성화되는 경우가 많음)
3. Node.js **22** (Cloud Functions 런타임). 로컬은 20+ 가능 (`node -v`)

## 배포 명령어

프로젝트 루트(`c:\projects\money`)에서:

```bash
# 1) Functions 의존성
cd functions
npm install

# 2) 루트로 복귀 후 배포
cd ..
firebase login
firebase use lunchtime-74f54
firebase deploy --only functions
```

특정 함수만:

```bash
firebase deploy --only functions:onScheduleCreated,functions:onShiftRequestCreated,functions:onShiftRequestUpdated,functions:dispatchNotificationJob
```

로그 확인:

```bash
firebase functions:log --only onScheduleCreated
# 또는
cd functions && npm run logs
```

## 첫 배포 실패 시 (Eventarc)

2nd gen Functions 최초 배포에서 아래 오류가 날 수 있습니다.

`Permission denied while using the Eventarc Service Agent`

API·서비스 에이전트 권한이 전파되는 데 **수 분** 걸립니다.  
2~5분 뒤 동일 명령으로 재배포하면 대부분 성공합니다.

```bash
firebase deploy --only functions --project lunchtime-74f54
```

## 설정 주의사항

1. **채널 ID**  
   Android Manifest `money_shift_default` 와 Functions `android.notification.channelId` 가 일치해야 배너가 정상 표시됩니다.

2. **토큰**  
   실기기/에뮬레이터에서 앱 로그인 후 Firestore `users/{kakaoUid}.fcmToken` 이 채워져 있어야 푸시가 갑니다. 토큰이 없으면 Functions는 `notifications` 인박스만 `no_token` 으로 남깁니다.

3. **iOS**  
   Apple Developer Push 인증서 / APNs 키를 Firebase Console → 프로젝트 설정 → Cloud Messaging 에 등록해야 실기기 수신이 됩니다.

4. **알림 정본**  
   근무 배정·교대 요청 푸시는 **Functions 트리거가 정본**입니다.  
   앱 `NotificationService` / `notification_jobs` 는 수동·기타 이벤트용으로 남겨 두었습니다.

5. **요금**  
   Blaze 무료 할당량 내에서 소규모 테스트는 비용이 거의 없습니다. 호출·네트워크 사용량은 GCP 청구에 표시됩니다.

6. **에뮬레이터 (선택)**  
   ```bash
   firebase emulators:start --only functions,firestore
   ```

## 스모크 테스트

1. 앱 로그인 → `users/{uid}` 에 `fcmToken` 확인  
2. Firestore에 `schedules` 문서 1건 생성 (`workerUid` = 본인 UID)  
3. 기기 알림 / `firebase functions:log` 에서 `FCM sent` 확인  

## 소스

- `functions/index.js` — 트리거 본문  
- `lib/services/fcm_service.dart` — 토큰·FG/BG 핸들러  
- `docs/fcm_dispatch_function.js` — 구 샘플 (참고용, 배포 대상 아님)
