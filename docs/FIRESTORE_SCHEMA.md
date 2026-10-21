# Money Shift Firestore · FCM 구조

프로젝트: `lunchtime-74f54`  
Document ID 중심 키는 **카카오 UID** (`users/{kakaoUid}`).

## 컬렉션 요약

| 컬렉션 | Document ID | 핵심 필드 |
|--------|-------------|-----------|
| `users` | 카카오 UID | `displayName`, `role`, `fcmToken`, `fcmTokens[]`, `kakaoId` |
| `stores` | auto / `test_store_*` | `name`, `ownerId`, `location{lat,lng}` |
| `store_members` | `{storeId}_{userId}` | `role`, `invitedBy`, `hourlyWage`, `isActive` |
| `schedules` | auto | `storeId`, `createdBy`, `workerUid`, `hourlyWage`, 시간 |
| `shift_requests` | auto | `applicantUid`, `approverUid`, `type`, `status` |
| `attendances` | auto | `userId`, 출퇴근 시각·GPS, `isApproved` |
| `payrolls` | `{storeId}_{workerUid}_{yyyy-MM}` | 확정분·기본급·주휴·야간·연장·총액 |
| `notification_jobs` | auto | 푸시 발송 큐 (`fcmToken`, title, body) |
| `notifications` | auto | 인앱 알림 함 |

레거시 `rooms` / `room_members` 는 기존 UI와 병행됩니다.

## 서비스

| 서비스 | 역할 |
|--------|------|
| `StoreFirestoreService` | 매장 CRUD + owner `store_members` 자동 등록 |
| `StoreMemberService` | 초대/역할/퇴장 + 권한 검증 |
| `ScheduleAssignService` | 배정·수정·삭제 + 배정 푸시 |
| `ShiftRequestService` | 변경/교대/휴가 요청·승인/거절 + 푸시 |
| `AttendanceFirestoreService` | 출퇴근·승인 + 권한 |
| `PayrollFirestoreService` | 월별 정산 재계산 |
| `NotificationService` | UID → `fcmToken` 조회 → `notification_jobs` 적재 |
| `FcmService` | 토큰 등록·포그라운드/오픈 핸들러 |
| `StorePermissionGuard` | 사장/본인 검증 |

## FCM 흐름

1. 로그인 후 `FcmService.bindUser(uid)` → `users/{uid}.fcmToken` 저장  
2. 이벤트 발생 시 `NotificationService.notifyUser(recipientUid: …)`  
3. `notification_jobs` 문서 생성 (Cloud Functions가 FCM HTTP v1 로 전송)  
4. 동시에 `notifications` 인앱 함 기록  

실제 디바이스 푸시 전송은 Cloud Functions Admin SDK (`functions/index.js`).

배포 가이드: `docs/FCM_DEPLOY.md`

## 권한

앱 서비스 레이어에서 `StorePermissionGuard` 로 수정·삭제 전 UID/역할을 검증합니다.  
Firestore Rules 에도 `test_` Mock UID 예외와 로그인 제약이 있습니다.
