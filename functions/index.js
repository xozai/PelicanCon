"use strict";

const { initializeApp } = require("firebase-admin/app");
const { getFirestore }  = require("firebase-admin/firestore");
const { getAuth }       = require("firebase-admin/auth");
const { getMessaging }  = require("firebase-admin/messaging");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

initializeApp();

// ---------------------------------------------------------------------------
// broadcastAnnouncement
// Called by AnnouncementService.swift after writing the announcement document.
// Params: { announcementId: string, title: string, body: string }
// Reads every fcmToken from the `users` collection and fan-outs via FCM
// sendEachForMulticast (batched at 500, the FCM hard limit per call).
// Stale / invalid tokens are cleared from Firestore as a side-effect.
// ---------------------------------------------------------------------------
exports.broadcastAnnouncement = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const { announcementId, title, body } = request.data;
    if (!announcementId || !title || !body) {
      throw new HttpsError(
        "invalid-argument",
        "announcementId, title, and body are required."
      );
    }

    // Server-side admin guard (defence-in-depth; Firestore rules enforce this too)
    const callerDoc = await getFirestore()
      .collection("users")
      .doc(request.auth.uid)
      .get();
    if (!callerDoc.exists || callerDoc.data().isAdmin !== true) {
      throw new HttpsError("permission-denied", "Admin privileges required.");
    }

    // Collect all non-empty FCM tokens from the users collection
    const usersSnapshot = await getFirestore().collection("users").get();
    const tokens = [];
    usersSnapshot.forEach((doc) => {
      const token = doc.data().fcmToken;
      if (typeof token === "string" && token.length > 0) {
        tokens.push(token);
      }
    });

    if (tokens.length === 0) {
      return { sent: 0, failed: 0 };
    }

    // Batch in groups of 500 (FCM multicast hard limit)
    const BATCH_SIZE = 500;
    let successCount  = 0;
    let failureCount  = 0;
    const staleTokens = [];

    for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
      const batch = tokens.slice(i, i + BATCH_SIZE);

      const multicastMessage = {
        tokens,
        notification: { title, body },
        data: {
          type:           "announcement",
          announcementId: announcementId,
        },
        apns: {
          payload: {
            aps: { sound: "default", badge: 1 },
          },
        },
      };

      const response = await getMessaging().sendEachForMulticast(multicastMessage);
      successCount += response.successCount;
      failureCount += response.failureCount;

      // Collect tokens that Firebase says are no longer registered
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const code = resp.error && resp.error.code;
          if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
          ) {
            staleTokens.push(batch[idx]);
          }
        }
      });
    }

    // Best-effort: null out stale tokens so future broadcasts are leaner.
    // Firestore `in` queries are capped at 30 items per call.
    if (staleTokens.length > 0) {
      const db = getFirestore();
      const chunkSize = 30;
      for (let i = 0; i < staleTokens.length; i += chunkSize) {
        const chunk = staleTokens.slice(i, i + chunkSize);
        try {
          const staleSnap = await db
            .collection("users")
            .where("fcmToken", "in", chunk)
            .get();
          const writeBatch = db.batch();
          staleSnap.forEach((doc) => {
            writeBatch.update(doc.ref, { fcmToken: null });
          });
          await writeBatch.commit();
        } catch (_) {
          // Non-fatal — stale cleanup is best-effort
        }
      }
    }

    return { sent: successCount, failed: failureCount };
  }
);

// ---------------------------------------------------------------------------
// deleteOwnAccount
// Called by AdminService.swift deleteOwnAccount() with empty params {}.
// The Swift side has already deleted the user's Firestore documents,
// Storage files, and conversation memberships before calling this.
// This function handles the one thing the client SDK cannot do after
// credential expiry: delete the Firebase Auth record itself.
// ---------------------------------------------------------------------------
exports.deleteOwnAccount = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const uid = request.auth.uid;
    await getAuth().deleteUser(uid);
    return { deleted: uid };
  }
);

// ---------------------------------------------------------------------------
// removeAuthUser
// Called by AdminService.swift removeUser() with { targetUid }.
// Verifies the caller is an admin in Firestore before acting.
// Revokes all refresh tokens first (immediately invalidates active sessions
// on other devices), then deletes the Auth account.
// ---------------------------------------------------------------------------
exports.removeAuthUser = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const { targetUid } = request.data;
    if (!targetUid || typeof targetUid !== "string") {
      throw new HttpsError("invalid-argument", "targetUid is required.");
    }

    // Server-side admin check
    const callerDoc = await getFirestore()
      .collection("users")
      .doc(request.auth.uid)
      .get();
    if (!callerDoc.exists || callerDoc.data().isAdmin !== true) {
      throw new HttpsError("permission-denied", "Admin privileges required.");
    }

    // Revoke sessions, then delete the Auth record
    await getAuth().revokeRefreshTokens(targetUid);
    await getAuth().deleteUser(targetUid);

    return { deleted: targetUid };
  }
);
