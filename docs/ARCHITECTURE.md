# Money Shift — 핵심 아키텍처

Clean Architecture 를 참고한 feature 단위 구조입니다.  
기존 `lib/services`, `lib/models`, `lib/features/rooms` UI 는 유지하고,  
신규 도메인 진입점은 `features/{auth,store,schedule,attendance}` 를 사용합니다.

```
lib/
  core/           # 공통 (geo Haversine, firebase, permissions, constants)
  models/         # Firestore 스키마 모델
  services/       # 저수준 Firestore/FCM CRUD (인프라)
  features/
    auth/         # 카카오 로그인 · users upsert · FCM bind
    store/        # stores · store_members
    schedule/     # schedules · shift_requests · 푸시 트리거
    attendance/   # GPS 반경 검증 · attendances
    rooms/        # 기존 UI (점진 이관)
    schedules/    # 기존 UI
```

## 인증 (카카오 UID = Document ID)

1. `KakaoAuthService.signIn()` → `user.id.toString()`
2. `AuthIntegrationService.signInWithKakao()` → `users/{kakaoUid}` Upsert  
   (`role`: `owner` | `worker`, `fcmToken`, 닉네임·프로필)
3. `FcmService.bindUser(kakaoUid)` → `users/{uid}.fcmToken` 자동 갱신

진입: `import 'package:money_shift/features/auth/auth.dart';` → `AuthService`

## GPS 출퇴근

`GeofenceService` / `AttendanceLocationService`  
Haversine (`core/geo/geo_distance.dart`) 으로 매장 좌표와 현재 위치 거리(m) 계산.  
기본 반경 `AppConstants.attendanceGeofenceRadiusMeters` (100m).

진입: `AttendanceService.clockIn/clockOut`

## 권한

`StorePermissionGuard` — 수정/삭제는 **사장·매니저** 또는 **본인**만.  
서비스 레이어에서 `RoomPermissionDeniedException` 등으로 실패.

## FCM

| 단계 | 담당 |
|------|------|
| 토큰 저장 | `FcmService.bindUser` → `users/{uid}.fcmToken` |
| 포그라운드/백그라운드 | `FcmService` + `firebaseMessagingBackgroundHandler` |
| Firestore 트리거 전송 | Cloud Functions `functions/index.js` (`onScheduleCreated` 등) |
| 클라이언트 큐 | `NotificationService` → `notification_jobs` → `dispatchNotificationJob` |

배포: `docs/FCM_DEPLOY.md`

## 스키마 상세

`docs/FIRESTORE_SCHEMA.md`
