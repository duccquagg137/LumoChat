const admin = require("firebase-admin");
const { logger } = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

admin.initializeApp();

const db = admin.firestore();
const REGION = "asia-southeast1";

exports.sendPushOnNotificationCreated = onDocumentCreated(
  {
    document: "notifications/{notificationId}",
    region: REGION,
    retry: true,
  },
  async (event) => {
    const snap = event.data;
    if (!snap || !snap.exists) {
      return;
    }

    const data = snap.data() || {};
    const recipientId = String(data.recipientId || "");
    const title = String(data.title || "LumoChat");
    const body = String(data.body || "");
    const type = String(data.type || "");
    const entityId = String(data.entityId || "");
    const metadata = data.data && typeof data.data === "object" ? data.data : {};

    if (!recipientId) {
      logger.warn("Skip notification push: missing recipientId", {
        notificationId: snap.id,
      });
      return;
    }

    const userRef = db.collection("users").doc(recipientId);
    const userSnap = await userRef.get();
    const userData = userSnap.data() || {};
    const tokensRaw = Array.isArray(userData.fcmTokens) ? userData.fcmTokens : [];
    const tokens = [...new Set(tokensRaw.map((t) => String(t).trim()).filter(Boolean))];

    if (tokens.length === 0) {
      logger.info("Skip notification push: no tokens", {
        notificationId: snap.id,
        recipientId,
      });
      await snap.ref.set(
        {
          pushedAt: admin.firestore.FieldValue.serverTimestamp(),
          pushResult: { successCount: 0, failureCount: 0, skipped: "no_tokens" },
        },
        { merge: true },
      );
      return;
    }

    const payload = {
      notification: { title, body },
      data: {
        notificationId: snap.id,
        type,
        entityId,
        ...toStringMap(metadata),
      },
      tokens,
      android: { priority: "high" },
      apns: {
        headers: { "apns-priority": "10" },
        payload: { aps: { sound: "default" } },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(payload);
    const invalidTokens = [];
    response.responses.forEach((r, index) => {
      if (r.success) return;
      const code = r.error?.code || "";
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        invalidTokens.push(tokens[index]);
      }
    });

    if (invalidTokens.length > 0) {
      await userRef.set(
        {
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
          fcmUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    await snap.ref.set(
      {
        pushedAt: admin.firestore.FieldValue.serverTimestamp(),
        pushResult: {
          successCount: response.successCount,
          failureCount: response.failureCount,
          invalidTokenCount: invalidTokens.length,
        },
      },
      { merge: true },
    );
  },
);

function toStringMap(value) {
  if (!value || typeof value !== "object") return {};
  const out = {};
  for (const [k, v] of Object.entries(value)) {
    out[k] = typeof v === "string" ? v : JSON.stringify(v);
  }
  return out;
}
