/**
 * Money Shift — Cloud Functions (2nd gen)
 *
 * 인박스: users/{uid}/notifications/{id}
 * FCM: Admin SDK messaging
 *
 * 트리거 (8종 이벤트):
 *  1. room_members / store_members onCreate → 사장 (직원 등록)
 *  2. schedules onCreate → 알바 (근무 배정)
 *  3. schedules onUpdate(changeRequestedByStaff) → 사장 (일정 변경 요청)
 *  4. schedules onUpdate(승인/거절) → 알바 (일정 변경 결과)
 *  5. shift_swaps / shift_requests(swap) 3단계 대타
 *  6. attendances onCreate / clockOut → 사장 (출퇴근)
 *  7. schedules onUpdate(isAbsent) → 알바 (결근)
 *  8. notices onCreate → 매장 전 직원 (공지)
 *  + notification_jobs 큐 소비
 *
 * 배포: npm install && firebase deploy --only functions
 */
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { logger } = require('firebase-functions');

initializeApp();
setGlobalOptions({
  region: 'asia-northeast3',
  maxInstances: 20,
});

const db = getFirestore();
const messaging = getMessaging();

// ---------------------------------------------------------------------------
// Templates (Flutter NotificationTemplates 와 동기화)
// ---------------------------------------------------------------------------

const T = {
  staffJoinedTitle: '[직원 등록] 새로운 팀원이 합류했어요',
  staffJoinedBody: (name) => `${name}님이 직원 등록을 했습니다.`,
  scheduleAssignedTitle: '[근무 배정] 새로운 근무가 등록되었어요',
  scheduleAssignedBody: (store) =>
    `[${store}] 새로운 근무 일정이 배정되었습니다. 일정을 확인해 보세요.`,
  scheduleConfirmedTitle: '[근무 확인] 배정 근무가 확인되었어요',
  scheduleConfirmedBody: (name) =>
    `${name}님이 배정된 근무 일정을 확인했습니다.`,
  scheduleChangeRequestTitle: '[일정 변경 요청]',
  scheduleChangeRequestBody: (name) =>
    `${name}님이 근무 일정 변경을 요청했습니다.`,
  scheduleChangeResultTitle: '[일정 변경 결과]',
  scheduleChangeResultBody: (approved) =>
    `요청하신 근무 일정 변경이 ${approved ? '승인' : '거절'}되었습니다.`,
  swapRequestTitle: '[대타 요청] 근무 대타 요청이 도착했어요',
  swapRequestBody: (name) =>
    `${name}님이 근무 대타를 요청했습니다. 일정을 확인해 보세요.`,
  swapOwnerApprovalTitle: '[대타 승인 요청] 근무자 변경 승인이 필요해요',
  swapOwnerApprovalBody: (store, from, to) =>
    `[${store}] ${from}님의 근무를 ${to}님이 대신 수락했습니다. 최종 승인해 주세요.`,
  swapConfirmedTitle: '[대타 확정] 근무 일정이 변경되었습니다',
  swapConfirmedBody: (store) =>
    `[${store}] 사장님이 대타 요청을 최종 승인하여 근무표가 변경되었습니다.`,
  attendanceTitle: '[출퇴근 알림]',
  attendanceBody: (name, isIn) =>
    `${name}님이 ${isIn ? '출근' : '퇴근'}했습니다.`,
  absentTitle: '[근태 안내] 결근 처리되었습니다',
  absentBody: (store) =>
    `[${store}] 사장님에 의해 해당 근무 일정이 결근으로 처리되었습니다.`,
  noticeTitle: '[매장 공지] 새로운 공지가 등록되었어요',
  noticeBody: (store) =>
    `[${store}] 사장님이 새로운 공지사항을 등록했습니다. 확인해 보세요!`,
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function resolveFcmToken(uid) {
  if (!uid) return null;
  const snap = await db.collection('users').doc(String(uid)).get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  if (typeof data.fcmToken === 'string' && data.fcmToken.length > 0) {
    return data.fcmToken;
  }
  const list = data.fcmTokens;
  if (Array.isArray(list) && list.length > 0 && typeof list[0] === 'string') {
    return list[0];
  }
  return null;
}

/** Flutter NotificationDeepLink.routeForType 과 동기화 */
function targetRouteForType(type) {
  switch (type) {
    case 'register':
    case 'staff_joined':
      return '/employees';
    case 'assign':
    case 'schedule_assigned':
      return '/assigned-schedule';
    case 'schedule_confirmed':
      return '/schedule';
    case 'request_update':
    case 'schedule_change_requested':
    case 'shift_request_created':
      return '/requests/schedule-change';
    case 'result_update':
    case 'schedule_change_approved':
    case 'schedule_change_rejected':
      return '/schedule';
    case 'sub_request':
    case 'swap_requested':
      return '/requests/substitute/accept';
    case 'sub_accept':
    case 'swap_colleague_accepted':
      return '/requests/substitute/approve';
    case 'sub_confirm':
    case 'swap_owner_approved':
      return '/schedule';
    case 'commute':
    case 'attendance_clock_in':
    case 'attendance_clock_out':
      return '/commute-history';
    case 'commute_correction':
      return '/requests/commute-correction';
    case 'commute_correction_result':
      return '/commute-history';
    case 'absent':
    case 'schedule_absent':
      return '/my-attendance';
    case 'notice':
    case 'store_notice':
      return '/notices/detail';
    default:
      return '/notifications';
  }
}

/** users/{uid}.notificationCategories — false면 해당 타입 스킵 */
function categoryEnabled(userData, type) {
  const cats = (userData && userData.notificationCategories) || {};
  const t = String(type || '');
  if (
    t === 'commute' ||
    t === 'attendance_clock_in' ||
    t === 'attendance_clock_out' ||
    t === 'commute_correction' ||
    t === 'commute_correction_result'
  ) {
    return cats.commute !== false;
  }
  if (t === 'notice' || t === 'store_notice') {
    return cats.notice !== false;
  }
  // 근무·배정·대타·변경 등
  return cats.schedule !== false;
}

function buildDeepLinkFields(type, data = {}) {
  const storeId = data.storeId || '';
  const targetRoute = data.targetRoute || targetRouteForType(type);
  const params = {
    ...(storeId ? { storeId } : {}),
    ...(data.scheduleId ? { scheduleId: String(data.scheduleId), shiftId: String(data.scheduleId) } : {}),
    ...(data.shiftId ? { shiftId: String(data.shiftId) } : {}),
    ...(data.requestId ? { requestId: String(data.requestId), id: String(data.requestId) } : {}),
    ...(data.swapId ? { swapId: String(data.swapId), requestId: String(data.swapId), id: String(data.swapId) } : {}),
    ...(data.noticeId ? { noticeId: String(data.noticeId), id: String(data.noticeId) } : {}),
    ...(data.action ? { action: String(data.action) } : {}),
    ...(data.approved != null ? { approved: String(data.approved) } : {}),
  };
  return { targetRoute, params };
}

async function resolveStoreOwnerUid(storeId) {
  if (!storeId) return null;
  const storeSnap = await db.collection('stores').doc(String(storeId)).get();
  if (storeSnap.exists) {
    const ownerId = storeSnap.data()?.ownerId;
    if (ownerId) return String(ownerId);
  }
  const roomSnap = await db.collection('rooms').doc(String(storeId)).get();
  if (roomSnap.exists) {
    const ownerId = roomSnap.data()?.ownerId;
    if (ownerId) return String(ownerId);
  }
  return null;
}

async function resolveStoreName(storeId) {
  if (!storeId) return '매장';
  const storeSnap = await db.collection('stores').doc(String(storeId)).get();
  if (storeSnap.exists) {
    return storeSnap.data()?.name || '매장';
  }
  const roomSnap = await db.collection('rooms').doc(String(storeId)).get();
  if (roomSnap.exists) {
    return roomSnap.data()?.name || '매장';
  }
  return '매장';
}

async function resolveDisplayName(uid, fallback = '직원') {
  if (!uid) return fallback;
  const snap = await db.collection('users').doc(String(uid)).get();
  if (!snap.exists) return fallback;
  const d = snap.data() || {};
  return d.realName || d.displayName || d.nickname || fallback;
}

function stringifyData(data = {}) {
  const out = {};
  for (const [k, v] of Object.entries(data)) {
    if (v === undefined || v === null) continue;
    out[k] = String(v);
  }
  return out;
}

/**
 * Firestore create 로 짧은 시간 중복 발송 차단.
 * 동일 docId 가 이미 있으면 false.
 */
async function claimDedupe(dedupeKey) {
  if (!dedupeKey) return true;
  const safe = String(dedupeKey).replace(/[/#\[\]]/g, '_').slice(0, 700);
  const ref = db.collection('_notification_dedupe').doc(safe);
  try {
    await ref.create({
      createdAt: FieldValue.serverTimestamp(),
    });
    return true;
  } catch (e) {
    if (e && (e.code === 6 || e.code === 'already-exists')) {
      logger.info('sendToUser dedupe skip', { dedupeKey: safe });
      return false;
    }
    throw e;
  }
}

/**
 * users/{uid}/notifications 기록 + FCM 전송
 * 스키마: id, userId, storeId, type, title, body, isRead, createdAt
 * @param {string} [dedupeKey] 있으면 동일 키 재발송 차단
 */
async function sendToUser({
  recipientUid,
  title,
  body,
  type,
  data = {},
  dedupeKey,
}) {
  if (!recipientUid) {
    logger.warn('sendToUser skip — empty recipient', { type });
    return { ok: false, reason: 'no_recipient' };
  }

  if (dedupeKey) {
    const ok = await claimDedupe(`${recipientUid}:${type}:${dedupeKey}`);
    if (!ok) return { ok: false, reason: 'deduped' };
  }

  const userSnap = await db.collection('users').doc(String(recipientUid)).get();
  const userData = userSnap.exists ? userSnap.data() || {} : {};
  if (!categoryEnabled(userData, type)) {
    logger.info('sendToUser skip preference', { recipientUid, type });
    return { ok: false, reason: 'preference_off' };
  }

  const token = await resolveFcmToken(recipientUid);
  const storeId = data.storeId || '';
  const { targetRoute, params } = buildDeepLinkFields(type, { storeId, ...data });
  const payloadData = stringifyData({
    type,
    storeId,
    targetRoute,
    params: JSON.stringify(params),
    ...params,
    ...data,
  });

  const inboxRef = db
    .collection('users')
    .doc(String(recipientUid))
    .collection('notifications')
    .doc();

  await inboxRef.set({
    id: inboxRef.id,
    userId: recipientUid,
    recipientUid,
    storeId,
    type,
    title,
    body,
    targetRoute,
    params,
    data: payloadData,
    fcmToken: token || null,
    read: false,
    isRead: false,
    status: token ? 'sending' : 'no_token',
    createdAt: FieldValue.serverTimestamp(),
    timestamp: FieldValue.serverTimestamp(),
  });

  if (!token) {
    logger.warn('sendToUser no_token', { recipientUid, type });
    return { ok: false, reason: 'no_token', inboxId: inboxRef.id };
  }

  try {
    const messageId = await messaging.send({
      token,
      notification: { title, body },
      data: payloadData,
      android: {
        priority: 'high',
        notification: {
          channelId: 'money_shift_default',
          sound: 'default',
        },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    });
    await inboxRef.update({
      status: 'sent',
      fcmMessageId: messageId,
      sentAt: FieldValue.serverTimestamp(),
    });
    logger.info('FCM sent', { recipientUid, type, messageId });
    return { ok: true, messageId, inboxId: inboxRef.id };
  } catch (err) {
    logger.error('FCM send failed', { recipientUid, type, error: String(err) });
    await inboxRef.update({ status: 'failed', error: String(err) });
    return { ok: false, reason: 'send_failed', error: String(err) };
  }
}

async function listActiveStaffUids(storeId) {
  const uids = new Set();
  const sm = await db
    .collection('store_members')
    .where('storeId', '==', String(storeId))
    .where('isActive', '==', true)
    .get();
  for (const doc of sm.docs) {
    const d = doc.data() || {};
    const role = d.role || '';
    if (role === 'owner') continue;
    if (d.userId) uids.add(String(d.userId));
  }
  const rm = await db
    .collection('room_members')
    .where('roomId', '==', String(storeId))
    .where('isActive', '==', true)
    .get();
  for (const doc of rm.docs) {
    const d = doc.data() || {};
    const role = d.role || '';
    if (role === 'owner') continue;
    if (d.userId) uids.add(String(d.userId));
  }
  return [...uids];
}

// ---------------------------------------------------------------------------
// 1) 직원 등록 — room_members / store_members onCreate
// ---------------------------------------------------------------------------

async function handleMemberJoined(data, docId, source) {
  const role = data.role || '';
  if (role === 'owner') {
    logger.info('member join skip owner', { docId, source });
    return;
  }

  const storeId = data.storeId || data.roomId || '';
  const userId = data.userId || '';
  const displayName =
    data.displayName || (await resolveDisplayName(userId, '직원'));
  let owner = await resolveStoreOwnerUid(storeId);
  if (!owner && data.invitedBy) owner = String(data.invitedBy);
  if (!owner || owner === userId) {
    logger.warn('member join — no owner', { docId, storeId, source });
    return;
  }

  await sendToUser({
    recipientUid: owner,
    title: T.staffJoinedTitle,
    body: T.staffJoinedBody(displayName),
    type: 'register',
    data: { storeId, memberId: docId, userId, source },
  });
}

exports.onRoomMemberCreated = onDocumentCreated(
  'room_members/{memberId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    await handleMemberJoined(snap.data() || {}, event.params.memberId, 'room');
  },
);

exports.onStoreMemberCreated = onDocumentCreated(
  'store_members/{memberId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    await handleMemberJoined(snap.data() || {}, event.params.memberId, 'store');
  },
);

// ---------------------------------------------------------------------------
// 2) 근무 배정 — schedules onCreate
// ---------------------------------------------------------------------------

exports.onScheduleCreated = onDocumentCreated(
  'schedules/{scheduleId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const scheduleId = event.params.scheduleId;
    const workerUid = data.workerUid || data.workerId;
    const storeId = data.storeId || data.roomId || '';
    if (!workerUid) {
      logger.warn('onScheduleCreated — missing workerUid', { scheduleId });
      return;
    }

    // 클라이언트에서 후속 건에 명시한 경우 스킵
    if (
      data.skipAssignNotification === true ||
      data.notifyWorker === false
    ) {
      return;
    }

    const batchId = data.assignmentBatchId || '';
    const storeName =
      data.storeName || (await resolveStoreName(storeId));

    // 기간/일괄 묶음은 batchId 기준 1회만
    await sendToUser({
      recipientUid: workerUid,
      title: T.scheduleAssignedTitle,
      body: T.scheduleAssignedBody(storeName),
      type: 'assign',
      data: { scheduleId, storeId },
      dedupeKey: batchId
        ? `assign:${storeId}:${workerUid}:${batchId}`
        : `assign:${storeId}:${workerUid}:${scheduleId}`,
    });
  },
);

// ---------------------------------------------------------------------------
// 3·4·7) schedules onUpdate — 변경 요청 / 결과 / 결근
// ---------------------------------------------------------------------------

exports.onScheduleUpdated = onDocumentUpdated(
  'schedules/{scheduleId}',
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const scheduleId = event.params.scheduleId;
    const storeId = after.storeId || after.roomId || '';
    const workerUid = after.workerUid || after.workerId || '';
    const storeName = after.storeName || (await resolveStoreName(storeId));

    const prevStatus = before.status || 'normal';
    const nextStatus = after.status || 'normal';

    // 3) 알바 → 사장 일정 변경 요청
    if (
      prevStatus !== 'changeRequestedByStaff' &&
      nextStatus === 'changeRequestedByStaff'
    ) {
      const requester =
        after.pending_change?.requestedBy ||
        after.pendingChange?.requestedBy ||
        workerUid;
      const name = await resolveDisplayName(requester, '직원');
      const ownerUid = await resolveStoreOwnerUid(storeId);
      if (ownerUid) {
        await sendToUser({
          recipientUid: ownerUid,
          title: T.scheduleChangeRequestTitle,
          body: T.scheduleChangeRequestBody(name),
          type: 'request_update',
          data: { scheduleId, storeId, requesterUid: requester },
        });
      }
      return;
    }

    // 4) 사장 → 알바 일정 변경 결과 (staff 요청이 normal 로 해소)
    if (
      prevStatus === 'changeRequestedByStaff' &&
      nextStatus === 'normal' &&
      workerUid
    ) {
      const hadPending =
        before.pending_change != null || before.pendingChange != null;
      const stillPending =
        after.pending_change != null || after.pendingChange != null;
      if (hadPending && !stillPending) {
        // pending 삭제 + times 변경 → 승인 / 시간 동일 → 거절로 추정
        const approved =
          String(before.startTime?.toMillis?.() || before.startTime) !==
            String(after.startTime?.toMillis?.() || after.startTime) ||
          String(before.endTime?.toMillis?.() || before.endTime) !==
            String(after.endTime?.toMillis?.() || after.endTime) ||
          before.date !== after.date;

        // changeResultHint 필드가 있으면 우선
        let isApproved = approved;
        if (after.lastChangeResult === 'approved') isApproved = true;
        if (after.lastChangeResult === 'rejected') isApproved = false;
        if (after.changeResolved === 'approved') isApproved = true;
        if (after.changeResolved === 'rejected') isApproved = false;

        await sendToUser({
          recipientUid: workerUid,
          title: T.scheduleChangeResultTitle,
          body: T.scheduleChangeResultBody(isApproved),
          type: 'result_update',
          data: { scheduleId, storeId, approved: String(isApproved) },
        });
      }
    }

    // 2-b) 직원 배정 근무 확인 → 사장 (기간 묶음은 batchId 로 1회)
    if (before.isConfirmed !== true && after.isConfirmed === true) {
      const ownerUid = await resolveStoreOwnerUid(storeId);
      if (ownerUid) {
        const name = await resolveDisplayName(workerUid, '직원');
        const batchId = after.assignmentBatchId || '';
        await sendToUser({
          recipientUid: ownerUid,
          title: T.scheduleConfirmedTitle,
          body: T.scheduleConfirmedBody(name),
          type: 'schedule_confirmed',
          data: { scheduleId, storeId },
          dedupeKey: `confirm:${batchId || scheduleId}`,
        });
      }
    }

    // 7) 결근 처리
    if (before.isAbsent !== true && after.isAbsent === true && workerUid) {
      await sendToUser({
        recipientUid: workerUid,
        title: T.absentTitle,
        body: T.absentBody(storeName),
        type: 'absent',
        data: { scheduleId, storeId },
        dedupeKey: `absent:${scheduleId}`,
      });
    }
  },
);

// ---------------------------------------------------------------------------
// 5) 대타 — shift_swaps 3단계
// ---------------------------------------------------------------------------

exports.onShiftSwapCreated = onDocumentCreated(
  'shift_swaps/{swapId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() || {};
    const swapId = event.params.swapId;
    const toUid = data.toWorkerId || data.targetWorkerUid;
    const fromUid = data.fromWorkerId || data.applicantUid;
    const storeId = data.storeId || data.roomId || '';
    const scheduleId = data.scheduleId || '';
    if (!toUid) return;

    const fromName = await resolveDisplayName(
      fromUid,
      data.fromDisplayName || '직원',
    );

    await sendToUser({
      recipientUid: toUid,
      title: T.swapRequestTitle,
      body: T.swapRequestBody(fromName),
      type: 'sub_request',
      data: { swapId, storeId, scheduleId, fromUid },
    });
  },
);

exports.onShiftSwapUpdated = onDocumentUpdated(
  'shift_swaps/{swapId}',
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const swapId = event.params.swapId;
    if (before.status === after.status) return;

    const storeId = after.storeId || after.roomId || '';
    const storeName = await resolveStoreName(storeId);
    const fromUid = after.fromWorkerId || after.applicantUid || '';
    const toUid = after.toWorkerId || after.targetWorkerUid || '';
    const fromName = await resolveDisplayName(
      fromUid,
      after.fromDisplayName || '직원',
    );
    const toName = await resolveDisplayName(
      toUid,
      after.toDisplayName || '직원',
    );

    // 2단계: 동료 수락 → 사장
    if (
      before.status === 'pendingColleague' &&
      after.status === 'pendingOwner'
    ) {
      const ownerUid = await resolveStoreOwnerUid(storeId);
      if (ownerUid) {
        await sendToUser({
          recipientUid: ownerUid,
          title: T.swapOwnerApprovalTitle,
          body: T.swapOwnerApprovalBody(storeName, fromName, toName),
          type: 'sub_accept',
          data: { swapId, storeId, fromUid, toUid },
        });
      }
      return;
    }

    // 3단계: 사장 최종 승인 → A, B
    if (after.status === 'approved' && before.status !== 'approved') {
      const recipients = [fromUid, toUid].filter(Boolean);
      await Promise.all(
        recipients.map((uid) =>
          sendToUser({
            recipientUid: uid,
            title: T.swapConfirmedTitle,
            body: T.swapConfirmedBody(storeName),
            type: 'sub_confirm',
            data: { swapId, storeId },
          }),
        ),
      );
    }
  },
);

// shift_requests — change / swap 호환
exports.onShiftRequestCreated = onDocumentCreated(
  'shift_requests/{requestId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() || {};
    const requestId = event.params.requestId;
    const storeId = data.storeId || '';
    const type = data.type || 'change';
    const applicantUid = data.applicantUid || '';
    const targetWorkerUid = data.targetWorkerUid || '';

    if (type === 'swap' && targetWorkerUid) {
      const fromName = await resolveDisplayName(applicantUid, '직원');
      await sendToUser({
        recipientUid: targetWorkerUid,
        title: T.swapRequestTitle,
        body: T.swapRequestBody(fromName),
        type: 'sub_request',
        data: { requestId, storeId, scheduleId: data.scheduleId || '' },
      });
      return;
    }

    // 일정 변경 요청 → 사장
    const ownerUid =
      data.approverUid || (await resolveStoreOwnerUid(storeId));
    if (!ownerUid || ownerUid === applicantUid) return;
    const name = await resolveDisplayName(applicantUid, '직원');
    await sendToUser({
      recipientUid: ownerUid,
      title: T.scheduleChangeRequestTitle,
      body: T.scheduleChangeRequestBody(name),
      type: 'request_update',
      data: { requestId, storeId, scheduleId: data.scheduleId || '' },
    });
  },
);

exports.onShiftRequestUpdated = onDocumentUpdated(
  'shift_requests/{requestId}',
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    if (before.status === after.status) return;

    const requestId = event.params.requestId;
    const storeId = after.storeId || '';
    const type = after.type || 'change';
    const applicantUid = after.applicantUid || '';
    const targetWorkerUid = after.targetWorkerUid || '';
    const storeName = await resolveStoreName(storeId);
    const next = after.status;

    if (type === 'swap') {
      if (
        (before.status === 'pending' ||
          before.status === 'pendingColleague') &&
        (next === 'pendingOwner' || next === 'colleague_accepted')
      ) {
        const ownerUid = await resolveStoreOwnerUid(storeId);
        const fromName = await resolveDisplayName(applicantUid, '직원');
        const toName = await resolveDisplayName(targetWorkerUid, '직원');
        if (ownerUid) {
          await sendToUser({
            recipientUid: ownerUid,
            title: T.swapOwnerApprovalTitle,
            body: T.swapOwnerApprovalBody(storeName, fromName, toName),
            type: 'sub_accept',
            data: { requestId, storeId },
          });
        }
        return;
      }
      if (next === 'approved') {
        const recipients = [applicantUid, targetWorkerUid].filter(Boolean);
        await Promise.all(
          recipients.map((uid) =>
            sendToUser({
              recipientUid: uid,
              title: T.swapConfirmedTitle,
              body: T.swapConfirmedBody(storeName),
              type: 'sub_confirm',
              data: { requestId, storeId },
            }),
          ),
        );
        return;
      }
    }

    // 일정 변경 승인/거절 → 요청자(알바)
    if (next === 'approved' || next === 'rejected') {
      if (!applicantUid) return;
      const approved = next === 'approved';
      await sendToUser({
        recipientUid: applicantUid,
        title: T.scheduleChangeResultTitle,
        body: T.scheduleChangeResultBody(approved),
        type: 'result_update',
        data: { requestId, storeId, approved: String(approved) },
      });
    }
  },
);

// ---------------------------------------------------------------------------
// 6) 출퇴근 — attendances
// ---------------------------------------------------------------------------

function commuteDayKey(ts) {
  try {
    const d =
      ts && typeof ts.toDate === 'function'
        ? ts.toDate()
        : ts
          ? new Date(ts)
          : new Date();
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  } catch (_) {
    return 'unknown';
  }
}

exports.onAttendanceCreated = onDocumentCreated(
  'attendances/{attendanceId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() || {};
    const storeId = data.storeId || '';
    const userId = data.userId || '';
    const ownerUid = await resolveStoreOwnerUid(storeId);
    if (!ownerUid || ownerUid === userId) return;

    const name = await resolveDisplayName(
      userId,
      data.displayName || '직원',
    );
    const day = commuteDayKey(data.clockInAt || data.createdAt);
    await sendToUser({
      recipientUid: ownerUid,
      title: T.attendanceTitle,
      body: T.attendanceBody(name, true),
      type: 'commute',
      data: {
        storeId,
        attendanceId: event.params.attendanceId,
        action: 'clock_in',
      },
      dedupeKey: `commute:${storeId}:${userId}:in:${day}`,
    });
  },
);

exports.onAttendanceUpdated = onDocumentUpdated(
  'attendances/{attendanceId}',
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const hadOut = before.clockOutAt != null;
    const hasOut = after.clockOutAt != null;
    if (hadOut || !hasOut) return;

    const storeId = after.storeId || '';
    const userId = after.userId || '';
    const ownerUid = await resolveStoreOwnerUid(storeId);
    if (!ownerUid || ownerUid === userId) return;

    const name = await resolveDisplayName(userId, '직원');
    const day = commuteDayKey(after.clockOutAt || after.updatedAt);
    await sendToUser({
      recipientUid: ownerUid,
      title: T.attendanceTitle,
      body: T.attendanceBody(name, false),
      type: 'commute',
      data: {
        storeId,
        attendanceId: event.params.attendanceId,
        action: 'clock_out',
      },
      dedupeKey: `commute:${storeId}:${userId}:out:${day}`,
    });
  },
);

// attendance_logs — 클라이언트가 AppNotificationDispatcher 로 이미 알림 발송.
// 동기화용 문서만 두고 푸시/인박스는 중복 방지를 위해 스킵.
exports.onAttendanceLogCreated = onDocumentCreated(
  'attendance_logs/{logId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() || {};
    if (data.clientNotified === true) {
      logger.info('attendance_logs skip — clientAlreadyNotified', {
        logId: event.params.logId,
      });
      return;
    }
    const storeId = data.roomId || data.storeId || '';
    const userId = data.userId || '';
    const type = data.type || '';
    const isIn = type === 'clockIn' || type === 'clock_in';
    const isOut = type === 'clockOut' || type === 'clock_out';
    if (!isIn && !isOut) return;

    const ownerUid = await resolveStoreOwnerUid(storeId);
    if (!ownerUid || ownerUid === userId) return;
    const name = await resolveDisplayName(userId, '직원');
    const day = commuteDayKey(data.timestamp || data.createdAt);
    await sendToUser({
      recipientUid: ownerUid,
      title: T.attendanceTitle,
      body: T.attendanceBody(name, isIn),
      type: 'commute',
      data: { storeId, logId: event.params.logId },
      dedupeKey: `commute:${storeId}:${userId}:${isIn ? 'in' : 'out'}:${day}`,
    });
  },
);

// ---------------------------------------------------------------------------
// 8) 매장 공지 — notices onCreate
// ---------------------------------------------------------------------------

exports.onNoticeCreated = onDocumentCreated(
  'notices/{noticeId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() || {};
    const noticeId = event.params.noticeId;
    const storeId = data.storeId || data.roomId || '';
    const authorId = data.authorId || '';
    const storeName =
      data.storeName || (await resolveStoreName(storeId));

    const staff = await listActiveStaffUids(storeId);
    const recipients = staff.filter((uid) => uid !== authorId);
    if (recipients.length === 0) {
      logger.info('onNoticeCreated — no staff', { noticeId, storeId });
      return;
    }

    await Promise.all(
      recipients.map((uid) =>
        sendToUser({
          recipientUid: uid,
          title: T.noticeTitle,
          body: T.noticeBody(storeName),
          type: 'notice',
          data: { storeId, noticeId },
        }),
      ),
    );
  },
);

// ---------------------------------------------------------------------------
// notification_jobs 큐 소비 (앱 NotificationService)
// ---------------------------------------------------------------------------

exports.dispatchNotificationJob = onDocumentCreated(
  'notification_jobs/{jobId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const job = snap.data() || {};
    if (job.status !== 'queued') {
      logger.info('dispatchNotificationJob skip status', {
        jobId: event.params.jobId,
        status: job.status,
      });
      return;
    }

    let token = job.fcmToken;
    if (!token && job.recipientUid) {
      token = await resolveFcmToken(job.recipientUid);
    }
    if (!token) {
      await snap.ref.update({
        status: 'no_token',
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    try {
      const messageId = await messaging.send({
        token,
        notification: {
          title: job.title || 'Money Shift',
          body: job.body || '',
        },
        data: (() => {
          const jobType = job.type || 'generic';
          const jobData = job.data || {};
          const { targetRoute, params } = buildDeepLinkFields(jobType, {
            storeId: job.storeId || jobData.storeId || '',
            ...jobData,
            ...(job.params || {}),
            ...(job.targetRoute ? { targetRoute: job.targetRoute } : {}),
          });
          return stringifyData({
            type: jobType,
            targetRoute,
            params: JSON.stringify(params),
            ...params,
            ...jobData,
          });
        })(),
        android: {
          priority: 'high',
          notification: {
            channelId: 'money_shift_default',
            sound: 'default',
          },
        },
      });
      await snap.ref.update({
        status: 'sent',
        fcmMessageId: messageId,
        sentAt: FieldValue.serverTimestamp(),
      });
    } catch (err) {
      await snap.ref.update({
        status: 'failed',
        error: String(err),
        updatedAt: FieldValue.serverTimestamp(),
      });
      logger.error('dispatchNotificationJob failed', err);
    }
  },
);
