/* eslint-disable max-len, require-jsdoc */
// Unit tests for the permanent account deletion flow, using in-memory
// fakes of the Admin SDK surface the flow uses (Firestore, Auth, Storage).
const test = require("node:test");
const assert = require("node:assert/strict");
const d = require("../account_deletion");

// ------------------------------------------------------------------ fakes
function fakeFirestore(seed = {}) {
  const docs = new Map(Object.entries(seed).map(([k, v]) => [k, {...v}]));
  let autoId = 0;
  const failures = new Set();

  function docRef(path) {
    const id = path.split("/").pop();
    return {
      id,
      path,
      async get() {
        const data = docs.get(path);
        return {id, exists: data !== undefined, ref: docRef(path), data: () => (data ? {...data} : undefined)};
      },
      async set(data, options = {}) {
        if (failures.has(`set:${path.split("/")[0]}`)) throw new Error(`injected set failure on ${path}`);
        const before = options.merge ? docs.get(path) || {} : {};
        docs.set(path, {...before, ...data});
      },
      async delete() {
        if (failures.has(`delete:${path.split("/")[0]}`)) throw new Error(`injected delete failure on ${path}`);
        docs.delete(path);
      },
      collection(name) {
        return collectionRef(`${path}/${name}`);
      },
      async listCollections() {
        const prefix = `${path}/`;
        const names = new Set();
        for (const key of docs.keys()) {
          if (key.startsWith(prefix)) names.add(key.slice(prefix.length).split("/")[0]);
        }
        return [...names].map((name) => collectionRef(`${path}/${name}`));
      },
    };
  }

  function query(path, filters = [], max = Infinity) {
    return {
      where(field, op, value) {
        assert.equal(op, "==");
        return query(path, [...filters, [field, value]], max);
      },
      limit(n) {
        return query(path, filters, n);
      },
      async get() {
        const depth = path.split("/").length + 1;
        const matches = [];
        for (const [key, data] of docs) {
          if (!key.startsWith(`${path}/`) || key.split("/").length !== depth) continue;
          if (filters.every(([field, value]) => data[field] === value)) {
            matches.push({id: key.split("/").pop(), ref: docRef(key), data: () => ({...data})});
          }
        }
        return {docs: matches.slice(0, max)};
      },
    };
  }

  function collectionRef(path) {
    return {
      ...query(path),
      doc: (id) => docRef(`${path}/${id}`),
      async add(data) {
        autoId += 1;
        const ref = docRef(`${path}/auto${autoId}`);
        await ref.set(data);
        return ref;
      },
    };
  }

  return {
    docs,
    failures,
    collection: (name) => collectionRef(name),
    data: (path) => docs.get(path),
    all: (collection) => [...docs.entries()].filter(([k]) => k.startsWith(`${collection}/`) && k.split("/").length === 2).map(([, v]) => v),
  };
}

function fakeAuth(uids) {
  const users = new Map(uids.map((uid) => [uid, {uid, disabled: false}]));
  const calls = [];
  let failDelete = false;
  const notFound = () => Object.assign(new Error("not found"), {code: "auth/user-not-found"});
  return {
    users,
    calls,
    set failDelete(value) {
      failDelete = value;
    },
    async getUser(uid) {
      if (!users.has(uid)) throw notFound();
      return users.get(uid);
    },
    async updateUser(uid, props) {
      if (!users.has(uid)) throw notFound();
      Object.assign(users.get(uid), props);
      calls.push(["updateUser", uid, props]);
    },
    async revokeRefreshTokens(uid) {
      calls.push(["revoke", uid]);
    },
    async deleteUser(uid) {
      if (failDelete) throw new Error("auth backend unavailable");
      if (!users.has(uid)) throw notFound();
      users.delete(uid);
      calls.push(["deleteUser", uid]);
    },
  };
}

function fakeBucket(paths) {
  const files = new Set(paths);
  const file = (name) => ({
    name,
    async exists() {
      return [files.has(name)];
    },
    async delete() {
      files.delete(name);
    },
  });
  return {
    files,
    async getFiles({prefix}) {
      return [[...files].filter((name) => name.startsWith(prefix)).map(file)];
    },
    file,
  };
}

const ADMIN = "admin1";
const WORKER = "worker1";
const CUSTOMER = "customer1";
const OTHER = "customer2";

function world() {
  const db = fakeFirestore({
    [`admins/${ADMIN}`]: {isActive: true},
    "admins/admin2": {isActive: true},
    "admins/retired": {isActive: false},
    [`users/${ADMIN}`]: {role: "admin", name: "Admin"},
    [`users/${WORKER}`]: {role: "worker", name: "Wally Worker", phoneNumber: "+923000000001", identityVerificationStatus: "pending"},
    [`users/${WORKER}/private/tokens`]: {fcmToken: "t"},
    [`users/${CUSTOMER}`]: {role: "customer", name: "Cara Customer", email: "cara@test"},
    [`users/${OTHER}`]: {role: "customer", name: "Other Customer"},
    [`public_profiles/${WORKER}`]: {name: "Wally Worker"},
    [`verification_requests/${WORKER}`]: {workerId: WORKER, identityStatus: "pending", cnicFrontPath: `private_verifications/workers/${WORKER}/front.jpg`},
    "requests/r_done": {customerId: OTHER, workerId: WORKER, status: "completed", location: "Other's house"},
    "requests/r_direct": {customerId: OTHER, workerId: WORKER, status: "waiting_worker"},
    "requests/r_open": {customerId: CUSTOMER, status: "searching", location: "Cara's house", latitude: 33.7, longitude: 73.0, imageUrls: ["u"]},
    "requests/r_open/private/contact": {phone: "+923000000002"},
    "requests/r_cust_done": {customerId: CUSTOMER, workerId: "worker9", status: "completed", location: "Cara's house"},
    "requests/r_cust_done/private/contact": {phone: "+923000000002"},
    "live_tracking/r_done": {workerId: WORKER, customerId: OTHER},
    "chats/c1": {customerId: OTHER, workerId: WORKER, workerName: "Wally Worker", workerImageUrl: "x", lastMessage: "hi"},
    "chats/c1/messages/m1": {senderId: WORKER, text: "hello"},
    "notifications/n1": {userId: WORKER, title: "for worker"},
    "notifications/n2": {userId: OTHER, title: "for other"},
    "reviews/rv1": {workerId: WORKER, customerId: OTHER, customerName: "Other Customer", rating: 5},
    "reviews/rv2": {workerId: "worker9", customerId: CUSTOMER, customerName: "Cara Customer", rating: 4},
    "support_requests/s1": {userId: CUSTOMER, name: "Cara Customer", email: "cara@test", message: "help"},
    "emergency_alerts/e1": {workerId: WORKER, raisedBy: WORKER, raisedByName: "Wally Worker"},
    "reports/rp1": {reporterId: OTHER, reportedUserId: WORKER},
    "transactions/t1": {userId: WORKER, amount: 100},
    "admin_audit_logs/old": {action: "worker_identity_approved", targetUserId: WORKER},
  });
  const auth = fakeAuth([ADMIN, WORKER, CUSTOMER, OTHER]);
  const bucket = fakeBucket([
    `profile_images/workers/${WORKER}/photo.jpg`,
    `private_verifications/workers/${WORKER}/front.jpg`,
    `private_verifications/workers/${WORKER}/selfie.jpg`,
    `customer_profiles/${CUSTOMER}.jpg`,
    `customer_profiles/${OTHER}.jpg`,
    `request_images/${CUSTOMER}/r_open/1.jpg`,
    `request_images/${OTHER}/r_done/1.jpg`,
    `private_verifications/workers/worker9/front.jpg`,
    `chat_media/c1/pic.jpg`,
    `payment_receipts/${WORKER}/old.jpg`,
  ]);
  return {db, auth, bucket, deps: {db, auth, bucket, now: () => new Date("2026-10-30T10:00:00Z")}};
}

const params = (targetUid, extra = {}) => ({adminUid: ADMIN, targetUid, reason: "fake_account", detail: null, requestId: "req-1", ...extra});
const audits = (db) => db.all("admin_audit_logs").filter((a) => a.action && a.action.startsWith("user_"));

// ------------------------------------------------------------ validation
test("deletion reasons are validated and Other needs a description", () => {
  assert.deepEqual(d.normalizeReason("Fake_Account"), {reason: "fake_account", detail: null});
  assert.deepEqual(d.normalizeReason("other", "  Impersonating a shop "), {reason: "other", detail: "Impersonating a shop"});
  assert.throws(() => d.normalizeReason("other", ""), {code: "invalid-argument"});
  assert.throws(() => d.normalizeReason("because", ""), {code: "invalid-argument"});
  assert.throws(() => d.normalizeReason(undefined), {code: "invalid-argument"});
  assert.equal(Object.keys(d.DELETION_REASONS).length, 7);
});

test("bulk lists are de-duplicated and capped", () => {
  assert.deepEqual(d.normalizeUidList([" a ", "a", "b", ""]), ["a", "b"]);
  assert.throws(() => d.normalizeUidList([]), {code: "invalid-argument"});
  assert.throws(() => d.normalizeUidList("a"), {code: "invalid-argument"});
  const tooMany = Array.from({length: d.MAX_BULK_DELETE + 1}, (_, i) => `u${i}`);
  assert.throws(() => d.normalizeUidList(tooMany), {code: "invalid-argument"});
  assert.equal(d.normalizeUidList(tooMany.slice(0, d.MAX_BULK_DELETE)).length, d.MAX_BULK_DELETE);
});

// --------------------------------------------------------- authorization
test("only active admins may delete; client claims are ignored", async () => {
  const {db, deps} = world();
  await assert.rejects(d.assertActiveAdmin(db, null), {code: "unauthenticated"});
  await assert.rejects(d.assertActiveAdmin(db, WORKER), {code: "permission-denied"});
  await assert.rejects(d.assertActiveAdmin(db, "retired"), {code: "permission-denied"});
  await d.assertActiveAdmin(db, ADMIN);

  // A non-admin calling the flow directly (e.g. a customer) is refused
  // and nothing is deleted.
  await assert.rejects(d.deleteAndAudit(deps, params(OTHER, {adminUid: CUSTOMER})), {code: "permission-denied"});
  assert.ok(db.data(`users/${OTHER}`));
  assert.equal(audits(db).at(-1).result, "rejected");
  assert.equal(audits(db).at(-1).adminUid, CUSTOMER);
});

test("an admin cannot delete their own account or another admin", async () => {
  const {db, deps} = world();
  await assert.rejects(d.deleteUserAccount(deps, params(ADMIN)), {code: "failed-precondition"});
  await assert.rejects(d.deleteUserAccount(deps, params("admin2")), {code: "failed-precondition"});
  assert.ok(db.data(`users/${ADMIN}`));
});

test("unknown accounts are reported as not found", async () => {
  const {deps} = world();
  await assert.rejects(d.deleteUserAccount(deps, params("ghost")), {code: "not-found"});
});

test("accounts with an active job are not deleted", async () => {
  const {db, auth, deps} = world();
  db.docs.set("requests/r_live", {customerId: OTHER, workerId: WORKER, status: "on_the_way"});
  await assert.rejects(d.deleteUserAccount(deps, params(WORKER)), (error) => error.code === "failed-precondition" && /active job/.test(error.message));
  assert.ok(db.data(`users/${WORKER}`));
  assert.ok(auth.users.has(WORKER));
  assert.equal(db.data(`account_deletions/${WORKER}`), undefined);
});

// -------------------------------------------------------------- cascade
test("worker deletion removes only that worker's own data", async () => {
  const {db, auth, bucket, deps} = world();
  const result = await d.deleteAndAudit(deps, params(WORKER, {reason: "failed_verification"}));
  assert.equal(result.status, "completed");
  assert.deepEqual(result.failedSteps, []);

  // Deleted
  assert.equal(auth.users.has(WORKER), false);
  assert.ok(auth.calls.some(([op, uid]) => op === "revoke" && uid === WORKER));
  for (const path of [`users/${WORKER}`, `users/${WORKER}/private/tokens`, `public_profiles/${WORKER}`, `verification_requests/${WORKER}`, "notifications/n1", "live_tracking/r_done"]) {
    assert.equal(db.data(path), undefined, `${path} should be deleted`);
  }
  for (const path of [`profile_images/workers/${WORKER}/photo.jpg`, `private_verifications/workers/${WORKER}/front.jpg`, `private_verifications/workers/${WORKER}/selfie.jpg`]) {
    assert.equal(bucket.files.has(path), false, `${path} should be deleted`);
  }

  // Other people's data untouched
  assert.ok(db.data(`users/${OTHER}`));
  assert.ok(db.data("notifications/n2"));
  assert.ok(auth.users.has(OTHER));
  for (const path of [`customer_profiles/${OTHER}.jpg`, `request_images/${OTHER}/r_done/1.jpg`, "private_verifications/workers/worker9/front.jpg", "chat_media/c1/pic.jpg"]) {
    assert.ok(bucket.files.has(path), `${path} must be kept`);
  }

  // Shared records kept, deleted side anonymised, references intact
  const chat = db.data("chats/c1");
  assert.equal(chat.workerId, WORKER);
  assert.equal(chat.workerName, "Deleted user");
  assert.equal(chat.workerImageUrl, null);
  assert.equal(chat.lastMessage, "hi");
  assert.ok(db.data("chats/c1/messages/m1"));
  const done = db.data("requests/r_done");
  assert.equal(done.status, "completed");
  assert.equal(done.workerId, WORKER);
  assert.equal(done.workerDeleted, true);
  assert.equal(done.location, "Other's house", "the other customer's address is not touched");
  const direct = db.data("requests/r_direct");
  assert.equal(direct.status, "cancelled");
  assert.equal(direct.cancelledBy, "worker");
  assert.equal(direct.cancellationReason, "account_deleted");

  // Retained records (safety, reports, financial, audit, others' reviews)
  assert.deepEqual(db.data("reviews/rv1"), {workerId: WORKER, customerId: OTHER, customerName: "Other Customer", rating: 5});
  assert.equal(db.data("emergency_alerts/e1").raisedByName, "Wally Worker");
  assert.ok(db.data("reports/rp1"));
  assert.ok(db.data("transactions/t1"));
  assert.ok(db.data("admin_audit_logs/old"));
  assert.ok(bucket.files.has(`payment_receipts/${WORKER}/old.jpg`));

  // Status record and audit
  const record = db.data(`account_deletions/${WORKER}`);
  assert.equal(record.status, "completed");
  assert.equal(record.requestedBy, ADMIN);
  assert.equal(record.reason, "failed_verification");
  assert.deepEqual(record.profileSnapshot, {role: "worker", name: "Wally Worker"});
  const [entry] = audits(db);
  assert.equal(entry.action, "user_deleted");
  assert.equal(entry.adminUid, ADMIN);
  assert.equal(entry.targetUid, WORKER);
  assert.equal(entry.reason, "failed_verification");
  assert.equal(entry.result, "completed");
  assert.equal(entry.requestId, "req-1");
  assert.ok(entry.createdAt instanceof Date);
});

test("customer deletion closes open requests and anonymises kept ones", async () => {
  const {db, auth, bucket, deps} = world();
  const result = await d.deleteUserAccount(deps, params(CUSTOMER, {reason: "other", detail: "Duplicate shop owner"}));
  assert.equal(result.status, "completed");
  assert.equal(auth.users.has(CUSTOMER), false);
  assert.equal(db.data(`users/${CUSTOMER}`), undefined);

  const open = db.data("requests/r_open");
  assert.equal(open.status, "cancelled");
  assert.equal(open.cancellationReason, "account_deleted");
  assert.equal(open.latitude, null);
  assert.deepEqual(open.imageUrls, []);
  assert.equal(db.data("requests/r_open/private/contact"), undefined);

  const done = db.data("requests/r_cust_done");
  assert.equal(done.status, "completed", "history is kept for the worker");
  assert.equal(done.customerId, CUSTOMER, "references are kept");
  assert.equal(done.location, "Address removed");
  assert.equal(db.data("requests/r_cust_done/private/contact"), undefined);

  const review = db.data("reviews/rv2");
  assert.equal(review.rating, 4, "the worker's rating input is kept");
  assert.equal(review.customerName, "Former customer");

  const support = db.data("support_requests/s1");
  assert.equal(support.message, "help");
  assert.equal(support.email, null);
  assert.equal(support.name, "Deleted user");

  assert.equal(bucket.files.has(`customer_profiles/${CUSTOMER}.jpg`), false);
  assert.equal(bucket.files.has(`request_images/${CUSTOMER}/r_open/1.jpg`), false);
  assert.ok(bucket.files.has(`customer_profiles/${OTHER}.jpg`));
  assert.equal(db.data(`account_deletions/${CUSTOMER}`).reasonDetail, "Duplicate shop owner");
});

test("a partial failure is recorded and a retry finishes the job", async () => {
  const {db, auth, deps} = world();
  auth.failDelete = true;
  const first = await d.deleteAndAudit(deps, params(WORKER));
  assert.equal(first.status, "partial_failure");
  assert.deepEqual(first.failedSteps, ["authAccount"]);
  assert.equal(first.steps.authAccount.ok, false);
  assert.equal(db.data(`account_deletions/${WORKER}`).status, "partial_failure");
  assert.ok(auth.users.get(WORKER).disabled, "the account is locked even though Auth deletion failed");
  assert.equal(audits(db).at(-1).action, "user_deletion_partial");

  auth.failDelete = false;
  const retry = await d.deleteAndAudit(deps, params(WORKER, {requestId: "req-2"}));
  assert.equal(retry.status, "completed");
  assert.equal(auth.users.has(WORKER), false);
  const record = db.data(`account_deletions/${WORKER}`);
  assert.equal(record.status, "completed");
  assert.equal(record.attempts, 2);
  assert.deepEqual(record.failedSteps, []);
});

test("a Firestore failure in one step does not stop the other steps", async () => {
  const {db, deps} = world();
  db.failures.add("set:chats");
  const result = await d.deleteUserAccount(deps, params(WORKER));
  assert.equal(result.status, "partial_failure");
  assert.deepEqual(result.failedSteps, ["chats"]);
  assert.equal(db.data("notifications/n1"), undefined);
  db.failures.clear();
  assert.equal((await d.deleteUserAccount(deps, params(WORKER))).status, "completed");
  assert.equal(db.data("chats/c1").workerName, "Deleted user");
});

test("deleting an already deleted account is safe and re-runs clean-up", async () => {
  const {db, bucket, deps} = world();
  await d.deleteUserAccount(deps, params(WORKER));
  // A file that appeared later (or survived a storage outage) is removed
  // by the retry; nothing else changes.
  bucket.files.add(`profile_images/workers/${WORKER}/late.jpg`);
  const before = JSON.stringify([...db.docs].filter(([k]) => !k.startsWith("account_deletions/") && !k.startsWith("admin_audit_logs/")));
  const again = await d.deleteAndAudit(deps, params(WORKER));
  assert.equal(again.status, "already_deleted");
  assert.equal(bucket.files.has(`profile_images/workers/${WORKER}/late.jpg`), false);
  assert.equal(JSON.stringify([...db.docs].filter(([k]) => !k.startsWith("account_deletions/") && !k.startsWith("admin_audit_logs/"))), before);
  const record = db.data(`account_deletions/${WORKER}`);
  assert.equal(record.status, "completed");
  assert.equal(record.attempts, 2);
  assert.equal(audits(db).at(-1).action, "user_deleted");
});

// ---------------------------------------------------------------- bulk
test("bulk deletion is authorised, capped and reports each account", async () => {
  const {db, auth, deps} = world();
  db.docs.set("requests/r_live", {customerId: OTHER, workerId: "worker9", status: "in_progress"});
  await assert.rejects(d.deleteUsersInBulk(deps, {adminUid: WORKER, uids: [CUSTOMER], reason: "spam_abuse", requestId: "b"}), {code: "permission-denied"});
  assert.ok(db.data(`users/${CUSTOMER}`));
  const many = Array.from({length: d.MAX_BULK_DELETE + 1}, (_, i) => `u${i}`);
  await assert.rejects(d.deleteUsersInBulk(deps, {adminUid: ADMIN, uids: many, reason: "spam_abuse", requestId: "b"}), {code: "invalid-argument"});

  const summary = await d.deleteUsersInBulk(deps, {
    adminUid: ADMIN,
    uids: [CUSTOMER, WORKER, ADMIN, OTHER, "ghost"],
    reason: "spam_abuse",
    reasons: {[WORKER]: {reason: "failed_verification"}},
    requestId: "bulk-1",
  });
  assert.equal(summary.succeeded, 2);
  assert.equal(summary.failed, 3);
  const byUid = Object.fromEntries(summary.results.map((r) => [r.uid, r]));
  assert.equal(byUid[CUSTOMER].status, "completed");
  assert.equal(byUid[WORKER].status, "completed");
  assert.equal(byUid[ADMIN].code, "failed-precondition");
  assert.equal(byUid[OTHER].code, "failed-precondition", "OTHER has an active job");
  assert.equal(byUid.ghost.code, "not-found");
  assert.ok(auth.users.has(ADMIN));
  assert.ok(auth.users.has(OTHER));
  assert.equal(db.data(`account_deletions/${WORKER}`).reason, "failed_verification");
  assert.equal(db.data(`account_deletions/${CUSTOMER}`).reason, "spam_abuse");
  const entries = audits(db).filter((a) => String(a.requestId).startsWith("bulk-1:"));
  assert.equal(entries.length, 5, "one audit entry per account");
  assert.deepEqual(entries.map((a) => a.result).sort(), ["completed", "completed", "rejected", "rejected", "rejected"]);
});
