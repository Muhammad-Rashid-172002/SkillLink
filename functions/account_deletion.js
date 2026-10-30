/* eslint-disable max-len */
/**
 * Permanent account deletion for SkillNova, run only by the trusted backend
 * (callable Cloud Functions `adminDeleteUser` / `adminDeleteUsers`).
 *
 * Data model decisions (see docs/ADMIN_USER_MANAGEMENT.md):
 *  - Deleted: the Auth account, users/{uid} (+ subcollections),
 *    public_profiles/{uid}, verification_requests/{uid}, the user's own
 *    notifications and live-tracking documents, private request contact
 *    details, and the user's Storage files (profile photo, identity
 *    documents, request photos).
 *  - Kept but anonymised (shared with another person): requests, chats and
 *    messages, reviews written by the user, support requests.
 *  - Kept unchanged (safety, financial, audit): emergency_alerts, reports,
 *    payment_requests, transactions, payment_receipts, admin_audit_logs,
 *    reviews ABOUT a deleted worker (other customers' content).
 *
 * Every step is idempotent, so a failed run can simply be retried. Progress
 * is recorded in account_deletions/{uid}.
 *
 * Dependencies are injected so the whole flow is unit tested without
 * Firebase (functions/test/account_deletion.test.js).
 */

const DELETION_REASONS = Object.freeze({
  fake_account: "Fake Account",
  invalid_information: "Invalid Information",
  failed_verification: "Failed Verification",
  duplicate_account: "Duplicate Account",
  spam_abuse: "Spam or Abuse",
  policy_violation: "Policy Violation",
  other: "Other",
});

/** Maximum accounts in one bulk call. */
const MAX_BULK_DELETE = 20;

/** Job states in which a person is actively relying on the other party. */
const ACTIVE_JOB_STATUSES = new Set([
  "accepted", "on_the_way", "ontheway", "in_progress", "started",
]);
/** Requests that are still open and should be closed for the other side. */
const OPEN_REQUEST_STATUSES = new Set([
  "searching", "pending", "requested", "waiting_worker",
]);

const DELETED_NAME = "Deleted user";
const QUERY_PAGE = 200;

/** Error carrying a callable error code (mapped to HttpsError by index.js). */
class DeletionError extends Error {
  /**
   * @param {string} code Callable error code.
   * @param {string} message Message safe to show to an admin.
   */
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

/**
 * Validates and normalises the reason an admin gave.
 *
 * @param {*} reason Reason key.
 * @param {*} detail Free text (required for "other").
 * @return {{reason: string, detail: ?string}} Normalised reason.
 */
function normalizeReason(reason, detail) {
  const key = String(reason || "").trim().toLowerCase();
  if (!Object.prototype.hasOwnProperty.call(DELETION_REASONS, key)) {
    throw new DeletionError("invalid-argument", "Choose a valid deletion reason.");
  }
  const text = String(detail || "").trim().slice(0, 500);
  if (key === "other" && text.length < 3) {
    throw new DeletionError("invalid-argument", "Describe the reason for deleting this account.");
  }
  return {reason: key, detail: text || null};
}

/**
 * Normalises a uid list for bulk deletion.
 *
 * @param {*} uids Raw list.
 * @return {string[]} Unique, trimmed uids.
 */
function normalizeUidList(uids) {
  if (!Array.isArray(uids) || uids.length === 0) {
    throw new DeletionError("invalid-argument", "Select at least one account.");
  }
  const unique = [...new Set(uids.map((uid) => String(uid || "").trim()).filter(Boolean))];
  if (unique.length === 0) {
    throw new DeletionError("invalid-argument", "Select at least one account.");
  }
  if (unique.length > MAX_BULK_DELETE) {
    throw new DeletionError("invalid-argument", `At most ${MAX_BULK_DELETE} accounts can be deleted at once.`);
  }
  return unique;
}

/**
 * Throws unless uid belongs to an active admin (admins/{uid}.isActive).
 * The client-supplied role is never trusted.
 *
 * @param {Object} db Firestore.
 * @param {?string} uid Caller uid from the verified ID token.
 */
async function assertActiveAdmin(db, uid) {
  if (!uid) throw new DeletionError("unauthenticated", "Sign in required.");
  const snap = await db.collection("admins").doc(uid).get();
  if (!snap.exists || (snap.data() || {}).isActive !== true) {
    throw new DeletionError("permission-denied", "Admin access required.");
  }
}

const normalizeStatus = (value) =>
  String(value || "").trim().toLowerCase().replace(/[\s-]+/g, "_");

/**
 * Runs a query in pages and calls fn for every document.
 *
 * @param {Object} query Firestore query.
 * @param {Function} fn Async callback(doc).
 * @return {Promise<number>} Documents visited.
 */
async function forEachDoc(query, fn) {
  const snapshot = await query.limit(QUERY_PAGE * 10).get();
  for (const doc of snapshot.docs) await fn(doc);
  return snapshot.docs.length;
}

/**
 * Deletes one account and its data. Idempotent: safe to call again after a
 * partial failure or for an account that is already gone.
 *
 * @param {Object} deps Injected services.
 * @param {Object} deps.db Firestore (Admin SDK).
 * @param {Object} deps.auth Firebase Auth (Admin SDK).
 * @param {Object} deps.bucket Default Storage bucket (Admin SDK).
 * @param {Function} [deps.now] Clock.
 * @param {Object} params Request.
 * @param {string} params.adminUid Verified caller uid.
 * @param {string} params.targetUid Account to delete.
 * @param {string} params.reason Reason key (validated).
 * @param {?string} params.detail Reason text.
 * @param {string} params.requestId Correlation id for logs and audit.
 * @return {Promise<Object>} {uid, status, failedSteps, steps}.
 */
async function deleteUserAccount(deps, params) {
  const {db, auth, bucket} = deps;
  const now = deps.now || (() => new Date());
  const {adminUid, targetUid, reason, detail, requestId} = params;
  const uid = String(targetUid || "").trim();

  // Defence in depth: the callable checks this too.
  await assertActiveAdmin(db, adminUid);
  if (!uid) throw new DeletionError("invalid-argument", "A user id is required.");
  if (uid === adminUid) {
    throw new DeletionError("failed-precondition", "You cannot delete your own admin account.");
  }

  const adminTarget = await db.collection("admins").doc(uid).get();
  if (adminTarget.exists) {
    throw new DeletionError("failed-precondition", "Admin accounts cannot be deleted from the console.");
  }

  const userRef = db.collection("users").doc(uid);
  const recordRef = db.collection("account_deletions").doc(uid);
  const [userSnap, recordSnap, authUser] = await Promise.all([
    userRef.get(),
    recordRef.get(),
    auth.getUser(uid).catch((error) => {
      if (error && error.code === "auth/user-not-found") return null;
      throw error;
    }),
  ]);
  const record = recordSnap.exists ? recordSnap.data() || {} : null;

  const alreadyDeleted = !userSnap.exists && !authUser;
  if (alreadyDeleted && !record) {
    throw new DeletionError("not-found", "This account does not exist.");
  }
  // When the profile and Auth user are already gone (a previous run), the
  // idempotent clean-up below runs again, so a retry finishes anything an
  // earlier run could not (e.g. a Storage outage).

  const profile = userSnap.exists ? userSnap.data() || {} : (record && record.profileSnapshot) || {};
  const role = normalizeStatus(profile.role) || (record && record.role) || "unknown";

  // Never strand the other person mid-job: active jobs must be finished or
  // cancelled first.
  const active = [];
  for (const field of ["customerId", "workerId"]) {
    const snap = await db.collection("requests").where(field, "==", uid).get();
    for (const doc of snap.docs) {
      if (ACTIVE_JOB_STATUSES.has(normalizeStatus((doc.data() || {}).status))) active.push(doc.id);
    }
  }
  if (active.length > 0) {
    throw new DeletionError("failed-precondition",
        `This account has ${active.length} active job${active.length === 1 ? "" : "s"}. Complete or cancel ${active.length === 1 ? "it" : "them"} before deleting the account.`);
  }

  const attempts = ((record && record.attempts) || 0) + 1;
  await recordRef.set({
    uid,
    role,
    status: "in_progress",
    reason,
    reasonDetail: detail || null,
    requestedBy: adminUid,
    requestId,
    attempts,
    startedAt: now(),
    // Minimal snapshot so a retry still knows who this was; no documents,
    // CNIC numbers or addresses.
    profileSnapshot: {role, name: profile.name || null},
  }, {merge: true});

  const steps = {};
  const failedSteps = [];
  const step = async (name, fn) => {
    try {
      const result = await fn();
      steps[name] = {ok: true, ...(result === undefined ? {} : {count: result})};
    } catch (error) {
      steps[name] = {ok: false, error: String((error && error.message) || error).slice(0, 300)};
      failedSteps.push(name);
    }
  };

  // 1. Lock the account immediately (syncAccountState also disables Auth).
  await step("lockAccount", async () => {
    if (userSnap.exists) {
      await userRef.set({accountStatus: "deleted", accountStatusUpdatedAt: now()}, {merge: true});
    }
    if (authUser) {
      await auth.updateUser(uid, {disabled: true});
      await auth.revokeRefreshTokens(uid);
    }
  });

  // 2. Storage: files that belong only to this person.
  await step("storage", async () => {
    let removed = 0;
    for (const prefix of [
      `profile_images/workers/${uid}/`,
      `private_verifications/workers/${uid}/`,
      `request_images/${uid}/`,
    ]) {
      const [files] = await bucket.getFiles({prefix});
      for (const file of files) {
        await file.delete({ignoreNotFound: true});
        removed += 1;
      }
    }
    const photo = bucket.file(`customer_profiles/${uid}.jpg`);
    const [exists] = await photo.exists();
    if (exists) {
      await photo.delete({ignoreNotFound: true});
      removed += 1;
    }
    return removed;
  });

  // 3. Requests the person posted: close open ones, anonymise the rest.
  await step("customerRequests", () => forEachDoc(
      db.collection("requests").where("customerId", "==", uid),
      async (doc) => {
        const data = doc.data() || {};
        const update = {
          customerDeleted: true,
          customerName: DELETED_NAME,
          customerPhone: null,
          customerEmail: null,
          customerPhotoUrl: null,
          location: "Address removed",
          address: null,
          latitude: null,
          longitude: null,
          imageUrls: [],
          updatedAt: now(),
        };
        if (OPEN_REQUEST_STATUSES.has(normalizeStatus(data.status))) {
          Object.assign(update, {status: "cancelled", cancelledBy: "customer", cancellationReason: "account_deleted", cancelledAt: now()});
        }
        await doc.ref.set(update, {merge: true});
        const privateDocs = await doc.ref.collection("private").get();
        for (const privateDoc of privateDocs.docs) await privateDoc.ref.delete();
      }));

  // 4. Jobs assigned to the person (as worker).
  await step("workerRequests", () => forEachDoc(
      db.collection("requests").where("workerId", "==", uid),
      async (doc) => {
        const data = doc.data() || {};
        const update = {
          workerDeleted: true,
          workerName: DELETED_NAME,
          workerPhone: null,
          workerPhotoUrl: null,
          updatedAt: now(),
        };
        if (OPEN_REQUEST_STATUSES.has(normalizeStatus(data.status))) {
          Object.assign(update, {status: "cancelled", cancelledBy: "worker", cancellationReason: "account_deleted", cancelledAt: now()});
        }
        await doc.ref.set(update, {merge: true});
      }));

  // 5. Live locations are personal data with no retention value.
  await step("liveTracking", async () => {
    let count = 0;
    for (const field of ["customerId", "workerId"]) {
      count += await forEachDoc(db.collection("live_tracking").where(field, "==", uid),
          (doc) => doc.ref.delete());
    }
    return count;
  });

  // 6. Chats stay for the other participant; the deleted side is anonymised.
  await step("chats", async () => {
    let count = 0;
    count += await forEachDoc(db.collection("chats").where("customerId", "==", uid),
        (doc) => doc.ref.set({customerDeleted: true, customerName: DELETED_NAME, customerImageUrl: null, customerPhotoUrl: null}, {merge: true}));
    count += await forEachDoc(db.collection("chats").where("workerId", "==", uid),
        (doc) => doc.ref.set({workerDeleted: true, workerName: DELETED_NAME, workerImageUrl: null, workerPhone: null}, {merge: true}));
    return count;
  });

  // 7. The person's own notifications.
  await step("notifications", () => forEachDoc(
      db.collection("notifications").where("userId", "==", uid),
      (doc) => doc.ref.delete()));

  // 8. Reviews the person wrote stay (they shape another worker's rating)
  //    but no longer name them. Reviews ABOUT a deleted worker are left as
  //    they are: they are other customers' content.
  await step("reviewsWritten", () => forEachDoc(
      db.collection("reviews").where("customerId", "==", uid),
      (doc) => doc.ref.set({customerName: "Former customer", customerPhotoUrl: null, customerDeleted: true}, {merge: true})));

  // 9. Support requests are kept as a service record without contact data.
  await step("supportRequests", () => forEachDoc(
      db.collection("support_requests").where("userId", "==", uid),
      (doc) => doc.ref.set({name: DELETED_NAME, email: null, phone: null, userDeleted: true}, {merge: true})));

  // 10. Identity verification record (documents were removed in step 2).
  await step("verificationRequest", async () => {
    await db.collection("verification_requests").doc(uid).delete();
  });

  // 11. Public profile.
  await step("publicProfile", async () => {
    await db.collection("public_profiles").doc(uid).delete();
  });

  // 12. Firebase Authentication account.
  await step("authAccount", async () => {
    try {
      await auth.deleteUser(uid);
    } catch (error) {
      if (!(error && error.code === "auth/user-not-found")) throw error;
    }
  });

  // 13. Profile document last, so a failed run can still find the account.
  await step("userProfile", async () => {
    const subcollections = typeof userRef.listCollections === "function" ?
      await userRef.listCollections() : [];
    for (const collection of subcollections) {
      const docs = await collection.get();
      for (const doc of docs.docs) await doc.ref.delete();
    }
    await userRef.delete();
  });

  const status = failedSteps.length > 0 ? "partial_failure" :
    alreadyDeleted && record.status === "completed" ? "already_deleted" : "completed";
  await recordRef.set({
    status: status === "already_deleted" ? "completed" : status,
    steps,
    failedSteps,
    finishedAt: now(),
    ...(status === "completed" ? {completedAt: now()} : {}),
  }, {merge: true});

  return {uid, status, failedSteps, steps};
}

/**
 * Writes one append-only audit entry for a deletion attempt.
 *
 * @param {Object} db Firestore.
 * @param {Object} entry Fields.
 * @return {Promise<void>}
 */
async function writeDeletionAudit(db, entry) {
  await db.collection("admin_audit_logs").add({
    action: entry.result === "completed" || entry.result === "already_deleted" ?
      "user_deleted" : entry.result === "partial_failure" ?
        "user_deletion_partial" : "user_deletion_rejected",
    adminUid: entry.adminUid,
    targetUid: entry.targetUid,
    reason: entry.reason || null,
    reasonDetail: entry.detail || null,
    result: entry.result,
    failedSteps: entry.failedSteps || [],
    error: entry.error || null,
    requestId: entry.requestId,
    createdAt: entry.createdAt || new Date(),
  });
}

/**
 * Deletes one account and always audits the outcome.
 *
 * @param {Object} deps See deleteUserAccount.
 * @param {Object} params See deleteUserAccount.
 * @return {Promise<Object>} Result; rejected attempts rethrow.
 */
async function deleteAndAudit(deps, params) {
  try {
    const result = await deleteUserAccount(deps, params);
    await writeDeletionAudit(deps.db, {...params, result: result.status, failedSteps: result.failedSteps});
    return result;
  } catch (error) {
    await writeDeletionAudit(deps.db, {
      ...params,
      result: "rejected",
      error: String((error && error.message) || error).slice(0, 300),
    }).catch(() => null);
    throw error;
  }
}

/**
 * Bulk deletion: sequential, capped, every account audited separately.
 *
 * @param {Object} deps See deleteUserAccount.
 * @param {Object} params adminUid, uids, reason, detail, reasons, requestId.
 * @return {Promise<Object>} {results, succeeded, failed}.
 */
async function deleteUsersInBulk(deps, params) {
  await assertActiveAdmin(deps.db, params.adminUid);
  const uids = normalizeUidList(params.uids);
  const perUser = params.reasons && typeof params.reasons === "object" ? params.reasons : {};
  const results = [];
  for (const uid of uids) {
    try {
      const own = perUser[uid] ? normalizeReason(perUser[uid].reason, perUser[uid].detail) : null;
      const chosen = own || normalizeReason(params.reason, params.detail);
      const result = await deleteAndAudit(deps, {
        adminUid: params.adminUid,
        targetUid: uid,
        reason: chosen.reason,
        detail: chosen.detail,
        requestId: `${params.requestId}:${uid}`,
      });
      results.push({uid, status: result.status, failedSteps: result.failedSteps});
    } catch (error) {
      results.push({uid, status: "failed", code: error.code || "internal", message: String(error.message || error)});
    }
  }
  const ok = (r) => r.status === "completed" || r.status === "already_deleted";
  return {
    results,
    succeeded: results.filter(ok).length,
    failed: results.filter((r) => !ok(r)).length,
  };
}

module.exports = {
  DELETION_REASONS,
  MAX_BULK_DELETE,
  ACTIVE_JOB_STATUSES,
  DeletionError,
  normalizeReason,
  normalizeUidList,
  assertActiveAdmin,
  deleteUserAccount,
  deleteAndAudit,
  deleteUsersInBulk,
  writeDeletionAudit,
};
