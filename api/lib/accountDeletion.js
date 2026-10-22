/**
 * 회원 탈퇴 — Firestore 실연동 익명화 + 매장 기록 표시명 언링크
 *
 * users/{uid} 는 삭제 대신 익명화(tombstone).
 * room_members / store_members 는 displayName='(탈퇴한 회원)', isActive=false.
 * schedules / attendance 등 workerId·userId 는 FK 유지, 표시 필드는 '(탈퇴한 회원)'.
 */
const { getAdmin, isConfigured } = require('./firebaseAdmin');

const DELETED_DISPLAY_NAME = '(탈퇴한 회원)';
const COLLECTIONS = {
  users: 'users',
  roomMembers: 'room_members',
  storeMembers: 'store_members',
  schedules: 'schedules',
  attendanceLogs: 'attendance_logs',
  attendances: 'attendances',
  payrolls: 'payrolls',
  shiftSwaps: 'shift_swaps',
  notices: 'notices',
  rooms: 'rooms',
  stores: 'stores',
};

/**
 * 카카오 access token 으로 회원번호 검증
 * @returns {Promise<string|null>} kakao user id string
 */
async function verifyKakaoAccessToken(accessToken) {
  if (!accessToken || typeof accessToken !== 'string') return null;
  try {
    const res = await fetch('https://kapi.kakao.com/v1/user/access_token_info', {
      method: 'GET',
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!res.ok) return null;
    const body = await res.json();
    if (body == null || body.id == null) return null;
    return String(body.id);
  } catch {
    return null;
  }
}

/** 목록 폭탄 방지 — 페이지 단위로 전량 수집 (탈퇴 익명화용) */
async function queryByField(db, collection, field, value, pageSize = 100) {
  try {
    const docs = [];
    let last = null;
    // 안전 상한: 최대 50페이지 (5000 docs)
    for (let page = 0; page < 50; page += 1) {
      let q = db
        .collection(collection)
        .where(field, '==', value)
        .limit(pageSize);
      if (last) q = q.startAfter(last);
      const snap = await q.get();
      if (snap.empty) break;
      docs.push(...snap.docs);
      last = snap.docs[snap.docs.length - 1];
      if (snap.size < pageSize) break;
    }
    return docs;
  } catch (e) {
    // 인덱스 미구성·권한 등으로 실패해도 탈퇴 전체는 계속 진행
    console.error(
      `[accountDeletion] queryByField ${collection}.${field} FAIL:`,
      e && e.message ? e.message : e,
    );
    return [];
  }
}

async function commitInChunks(db, mutators) {
  const CHUNK = 400;
  let written = 0;
  for (let i = 0; i < mutators.length; i += CHUNK) {
    const batch = db.batch();
    const slice = mutators.slice(i, i + CHUNK);
    for (const apply of slice) apply(batch);
    await batch.commit();
    written += slice.length;
  }
  return written;
}

/**
 * @param {{ userId: string, authProvider?: string }} input
 */
async function deleteAccountInFirestore(input) {
  const { db, admin } = getAdmin();
  if (!db || !admin) {
    const err = new Error('firebase_admin_not_configured');
    err.code = 'firebase_admin_not_configured';
    throw err;
  }

  const userId = String(input.userId || '').trim();
  if (!userId) {
    const err = new Error('user_id_required');
    err.code = 'user_id_required';
    throw err;
  }

  const FieldValue = admin.firestore.FieldValue;
  const now = FieldValue.serverTimestamp();
  const summary = {
    userId,
    anonymizedUser: false,
    roomMembers: 0,
    storeMembers: 0,
    schedules: 0,
    attendanceLogs: 0,
    attendances: 0,
    payrolls: 0,
    shiftSwaps: 0,
    notices: 0,
    ownedRoomsTouched: 0,
    ownedStoresTouched: 0,
    notificationsCleared: false,
  };

  const mutators = [];

  // 1) users/{uid} 익명화 (삭제 금지 — 클라이언트 rules 도 delete false)
  const userRef = db.collection(COLLECTIONS.users).doc(userId);
  const userSnap = await userRef.get();
  if (userSnap.exists) {
    mutators.push((batch) => {
      batch.set(
        userRef,
        {
          uid: userId,
          email: '',
          displayName: DELETED_DISPLAY_NAME,
          realName: FieldValue.delete(),
          phoneNumber: FieldValue.delete(),
          kakaoId: FieldValue.delete(),
          googleId: FieldValue.delete(),
          profileImageUrl: FieldValue.delete(),
          fcmToken: FieldValue.delete(),
          fcmTokens: [],
          fcmTokenUpdatedAt: FieldValue.delete(),
          notificationCategories: FieldValue.delete(),
          isNotificationEnabled: false,
          authProvider: 'deleted',
          accountDeleted: true,
          deletedAt: now,
          updatedAt: now,
        },
        { merge: true },
      );
    });
    summary.anonymizedUser = true;
  } else {
    mutators.push((batch) => {
      batch.set(userRef, {
        uid: userId,
        email: '',
        displayName: DELETED_DISPLAY_NAME,
        fcmTokens: [],
        isNotificationEnabled: false,
        authProvider: 'deleted',
        accountDeleted: true,
        deletedAt: now,
        updatedAt: now,
        createdAt: now,
      });
    });
    summary.anonymizedUser = true;
  }

  // users/{uid}/notifications 서브컬렉션 삭제
  try {
    const notifSnap = await userRef.collection('notifications').limit(500).get();
    for (const doc of notifSnap.docs) {
      mutators.push((batch) => batch.delete(doc.ref));
    }
    summary.notificationsCleared = notifSnap.size > 0;
  } catch {
    // ignore subcollection failures
  }

  // 2) room_members — 표시명 익명화 + 비활성 (userId 유지 = 스케줄 FK)
  const roomMembers = await queryByField(
    db,
    COLLECTIONS.roomMembers,
    'userId',
    userId,
  );
  for (const doc of roomMembers) {
    mutators.push((batch) => {
      batch.update(doc.ref, {
        displayName: DELETED_DISPLAY_NAME,
        isActive: false,
        accountDeleted: true,
        linkedUserId: null,
        updatedAt: now,
      });
    });
    summary.roomMembers += 1;
  }

  // 3) store_members
  const storeMembers = await queryByField(
    db,
    COLLECTIONS.storeMembers,
    'userId',
    userId,
  );
  for (const doc of storeMembers) {
    mutators.push((batch) => {
      batch.update(doc.ref, {
        displayName: DELETED_DISPLAY_NAME,
        isActive: false,
        accountDeleted: true,
        linkedUserId: null,
        updatedAt: now,
      });
    });
    summary.storeMembers += 1;
  }

  // 4) schedules — 표시 필드만 익명화 (workerId 유지)
  const schedules = await queryByField(
    db,
    COLLECTIONS.schedules,
    'workerId',
    userId,
  );
  for (const doc of schedules) {
    mutators.push((batch) => {
      batch.set(
        doc.ref,
        {
          workerDisplayName: DELETED_DISPLAY_NAME,
          accountDeleted: true,
          updatedAt: now,
        },
        { merge: true },
      );
    });
    summary.schedules += 1;
  }

  // 5) attendance_logs / attendances
  const attendanceLogs = await queryByField(
    db,
    COLLECTIONS.attendanceLogs,
    'userId',
    userId,
  );
  for (const doc of attendanceLogs) {
    mutators.push((batch) => {
      batch.set(
        doc.ref,
        {
          displayName: DELETED_DISPLAY_NAME,
          userDisplayName: DELETED_DISPLAY_NAME,
          accountDeleted: true,
        },
        { merge: true },
      );
    });
    summary.attendanceLogs += 1;
  }

  const attendances = await queryByField(
    db,
    COLLECTIONS.attendances,
    'userId',
    userId,
  );
  for (const doc of attendances) {
    mutators.push((batch) => {
      batch.set(
        doc.ref,
        {
          displayName: DELETED_DISPLAY_NAME,
          accountDeleted: true,
        },
        { merge: true },
      );
    });
    summary.attendances += 1;
  }

  // 6) payrolls
  const payrolls = await queryByField(
    db,
    COLLECTIONS.payrolls,
    'userId',
    userId,
  );
  for (const doc of payrolls) {
    mutators.push((batch) => {
      batch.set(
        doc.ref,
        {
          displayName: DELETED_DISPLAY_NAME,
          workerDisplayName: DELETED_DISPLAY_NAME,
          accountDeleted: true,
        },
        { merge: true },
      );
    });
    summary.payrolls += 1;
  }

  // 7) shift_swaps
  const swapsFrom = await queryByField(
    db,
    COLLECTIONS.shiftSwaps,
    'fromWorkerId',
    userId,
  );
  const swapsTo = await queryByField(
    db,
    COLLECTIONS.shiftSwaps,
    'toWorkerId',
    userId,
  );
  const swapIds = new Set();
  for (const doc of [...swapsFrom, ...swapsTo]) {
    if (swapIds.has(doc.id)) continue;
    swapIds.add(doc.id);
    const data = doc.data() || {};
    const patch = { accountDeleted: true, updatedAt: now };
    if (data.fromWorkerId === userId) {
      patch.fromWorkerDisplayName = DELETED_DISPLAY_NAME;
    }
    if (data.toWorkerId === userId) {
      patch.toWorkerDisplayName = DELETED_DISPLAY_NAME;
    }
    mutators.push((batch) => batch.set(doc.ref, patch, { merge: true }));
    summary.shiftSwaps += 1;
  }

  // 8) notices author 표시
  const notices = await queryByField(
    db,
    COLLECTIONS.notices,
    'authorId',
    userId,
  );
  for (const doc of notices) {
    mutators.push((batch) => {
      batch.set(
        doc.ref,
        {
          authorDisplayName: DELETED_DISPLAY_NAME,
          accountDeleted: true,
        },
        { merge: true },
      );
    });
    summary.notices += 1;
  }

  // 9) 소유 매장 — ownerDisplayName 익명화 (매장·기록은 유지)
  const ownedRooms = await queryByField(db, COLLECTIONS.rooms, 'ownerId', userId);
  for (const doc of ownedRooms) {
    mutators.push((batch) => {
      batch.set(
        doc.ref,
        {
          ownerDisplayName: DELETED_DISPLAY_NAME,
          ownerAccountDeleted: true,
          updatedAt: now,
        },
        { merge: true },
      );
    });
    summary.ownedRoomsTouched += 1;
  }

  const ownedStores = await queryByField(
    db,
    COLLECTIONS.stores,
    'ownerId',
    userId,
  );
  for (const doc of ownedStores) {
    mutators.push((batch) => {
      batch.set(
        doc.ref,
        {
          ownerDisplayName: DELETED_DISPLAY_NAME,
          ownerAccountDeleted: true,
          updatedAt: now,
        },
        { merge: true },
      );
    });
    summary.ownedStoresTouched += 1;
  }

  const written = await commitInChunks(db, mutators);
  return {
    ok: true,
    displayName: DELETED_DISPLAY_NAME,
    written,
    summary,
  };
}

module.exports = {
  DELETED_DISPLAY_NAME,
  verifyKakaoAccessToken,
  deleteAccountInFirestore,
  isConfigured,
};
