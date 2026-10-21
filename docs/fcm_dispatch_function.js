/**
 * [DEPRECATED — 참고용]
 * 실제 배포 소스는 `functions/index.js` 입니다.
 * 배포: docs/FCM_DEPLOY.md 참고
 *
 * Cloud Functions (Node 20) — notification_jobs 소비 → FCM 전송
 */
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp();

exports.dispatchNotificationJob = onDocumentCreated(
  'notification_jobs/{jobId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const job = snap.data();
    if (job.status !== 'queued' || !job.fcmToken) {
      return;
    }

    try {
      await getMessaging().send({
        token: job.fcmToken,
        notification: {
          title: job.title || 'Money Shift',
          body: job.body || '',
        },
        data: Object.fromEntries(
          Object.entries(job.data || {}).map(([k, v]) => [k, String(v)]),
        ),
      });
      await snap.ref.update({
        status: 'sent',
        sentAt: new Date().toISOString(),
      });
    } catch (err) {
      await snap.ref.update({
        status: 'failed',
        error: String(err),
      });
      console.error('FCM send failed', err);
    }
  },
);
