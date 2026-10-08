// Security tests for firestore.rules, run against the local emulators only.
//
//   cd firestore-tests && ./run.sh
//
// No dependencies: accounts come from the Auth emulator and every read/write
// goes through the Firestore emulator's REST API with that user's ID token,
// so the real rules decide. Fixtures are written with the emulator's
// `Bearer owner` token, which bypasses rules (emulator-only).
import test from "node:test";
import assert from "node:assert/strict";

const PROJECT = process.env.GCLOUD_PROJECT || "demo-skillnova-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;
if (!FIRESTORE || !AUTH) {
  throw new Error("Run through ./run.sh so the emulators are started.");
}
if (!PROJECT.startsWith("demo-")) {
  throw new Error(`Refusing to run against non-demo project ${PROJECT}.`);
}

const DOCS = `projects/${PROJECT}/databases/(default)/documents`;
const BASE = `http://${FIRESTORE}/v1/${DOCS}`;

// ------------------------------------------------------------ value codec
function encode(value) {
  if (value === null || value === undefined) return {nullValue: null};
  if (value instanceof Date) return {timestampValue: value.toISOString()};
  if (Array.isArray(value)) {
    return {arrayValue: {values: value.map(encode)}};
  }
  switch (typeof value) {
    case "string": return {stringValue: value};
    case "boolean": return {booleanValue: value};
    case "number":
      return Number.isInteger(value) ?
        {integerValue: String(value)} : {doubleValue: value};
    case "object": return {mapValue: {fields: fields(value)}};
  }
  throw new Error(`Cannot encode ${value}`);
}
function fields(object) {
  return Object.fromEntries(
      Object.entries(object).map(([key, value]) => [key, encode(value)]));
}

// ---------------------------------------------------------------- clients
async function call(method, url, token, body) {
  const response = await fetch(url, {
    method,
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  return {status: response.status, body: text};
}

const OWNER = "owner";

/** Writes fixture data, bypassing rules. */
async function seed(path, data) {
  const result = await call("PATCH", `${BASE}/${path}`, OWNER,
      {fields: fields(data)});
  assert.equal(result.status, 200, `seed ${path}: ${result.body}`);
}

let counter = 0;
async function account(label) {
  counter += 1;
  const response = await fetch(
      `http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({
          email: `${label}.${counter}.${Date.now()}@rules.test`,
          password: "RulesTest2026x",
          returnSecureToken: true,
        }),
      });
  const json = await response.json();
  assert.ok(json.idToken, `sign up failed: ${JSON.stringify(json)}`);
  return {uid: json.localId, token: json.idToken};
}

function as(user) {
  const token = user.token;
  return {
    get: (path) => call("GET", `${BASE}/${path}`, token),
    /** Creates a document; fails if it already exists. */
    create: (path, data) => call("PATCH",
        `${BASE}/${path}?currentDocument.exists=false`, token,
        {fields: fields(data)}),
    /** Merge-updates only the given fields of an existing document. */
    update: (path, data) => {
      const mask = Object.keys(data)
          .map((key) => `updateMask.fieldPaths=${encodeURIComponent(key)}`)
          .join("&");
      return call("PATCH",
          `${BASE}/${path}?currentDocument.exists=true&${mask}`, token,
          {fields: fields(data)});
    },
    /** Overwrites (or creates) a whole document. */
    set: (path, data) => call("PATCH", `${BASE}/${path}`, token,
        {fields: fields(data)}),
    delete: (path) => call("DELETE", `${BASE}/${path}`, token),
    /** Atomic batch, like a client transaction/batch commit. */
    commit: (writes) => call("POST",
        `http://${FIRESTORE}/v1/${DOCS}:commit`, token, {
          writes: writes.map((write) => ({
            update: {name: `${DOCS}/${write.path}`, fields: fields(write.data)},
            ...(write.mask ? {updateMask: {fieldPaths: write.mask}} : {}),
            ...(write.exists === undefined ? {} :
              {currentDocument: {exists: write.exists}}),
          })),
        }),
  };
}

async function allowed(promise, label) {
  const result = await promise;
  assert.ok(result.status === 200,
      `${label}: expected ALLOWED, got ${result.status} ${result.body}`);
}
async function denied(promise, label) {
  const result = await promise;
  assert.ok(result.status === 403,
      `${label}: expected DENIED (403), got ${result.status} ${result.body}`);
}

// --------------------------------------------------------------- fixtures
let customer; let otherCustomer; let worker; let otherWorker; let admin;
let pendingWorker;

const workerProfile = (extra = {}) => ({
  role: "worker",
  name: "Worker",
  skill: "Plumber",
  accountStatus: "active",
  identityVerificationStatus: "approved",
  verificationLevel: "identity_verified",
  canAcceptJobs: true,
  credits: 5,
  rating: 4.5,
  totalReviews: 2,
  completedJobs: 3,
  ...extra,
});

test.before(async () => {
  const reset = await fetch(
      `http://${FIRESTORE}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
      {method: "DELETE"});
  assert.equal(reset.status, 200);

  customer = await account("customer");
  otherCustomer = await account("customer2");
  worker = await account("worker");
  otherWorker = await account("worker2");
  pendingWorker = await account("pending");
  admin = await account("admin");

  await seed(`users/${customer.uid}`, {role: "customer", name: "Cara"});
  await seed(`users/${otherCustomer.uid}`, {role: "customer", name: "Omar"});
  await seed(`users/${worker.uid}`, workerProfile());
  await seed(`users/${otherWorker.uid}`, workerProfile({name: "Other"}));
  await seed(`users/${pendingWorker.uid}`, workerProfile({
    identityVerificationStatus: "pending",
    verificationLevel: "unverified",
    canAcceptJobs: false,
  }));
  await seed(`users/${admin.uid}`, {role: "customer", name: "Admin"});
  await seed(`admins/${admin.uid}`, {isActive: true});
});

// =================================================================== users
test("users: profiles are protected from other people", async () => {
  await denied(as(customer).update(`users/${otherCustomer.uid}`,
      {name: "Hacked"}), "customer edits another customer");
  await denied(as(customer).update(`users/${worker.uid}`,
      {name: "Hacked"}), "customer edits a worker");
  await denied(as(worker).update(`users/${otherWorker.uid}`,
      {skill: "Electrician"}), "worker edits another worker");
  await denied(as(customer).get(`users/${otherCustomer.uid}`),
      "customer reads another customer's profile");
  await allowed(as(customer).get(`users/${worker.uid}`),
      "customer reads a worker's public profile");
});

test("users: owners can edit ordinary profile fields", async () => {
  await allowed(as(customer).update(`users/${customer.uid}`,
      {name: "Cara B", phone: "0300"}), "customer edits own name");
  await allowed(as(worker).update(`users/${worker.uid}`,
      {bio: "20 years", hourlyRate: "1500", isOnline: true}),
  "worker edits own profile");
});

test("users: nobody can change their role or make themselves admin",
    async () => {
      await denied(as(customer).update(`users/${customer.uid}`,
          {role: "worker"}), "customer -> worker");
      await denied(as(customer).update(`users/${customer.uid}`,
          {role: "admin"}), "customer -> admin role");
      await denied(as(worker).update(`users/${worker.uid}`,
          {role: "customer"}), "worker -> customer");
      await denied(as(customer).create(`admins/${customer.uid}`,
          {isActive: true}), "customer creates own admins doc");
      await denied(as(customer).set(`admins/${customer.uid}`,
          {isActive: true}), "customer sets own admins doc");
      await denied(as(admin).set(`admins/${customer.uid}`,
          {isActive: true}), "even an admin cannot mint admins from a client");
    });

test("users: sign-up cannot grant privileges", async () => {
  const fresh = await account("fresh");
  await denied(as(fresh).create(`users/${fresh.uid}`,
      {role: "admin", name: "x"}), "sign up as admin");
  await denied(as(fresh).create(`users/${fresh.uid}`, {
    role: "worker", identityVerificationStatus: "approved",
  }), "sign up pre-approved");
  await denied(as(fresh).create(`users/${fresh.uid}`,
      {role: "worker", canAcceptJobs: true}), "sign up accepting jobs");
  await denied(as(fresh).create(`users/${fresh.uid}`,
      {role: "worker", credits: 100}), "sign up with credits");
  await denied(as(fresh).create(`users/${fresh.uid}`,
      {role: "worker", rating: 5}), "sign up with rating");
  await denied(as(fresh).create(`users/${fresh.uid}`,
      {role: "worker", isVerified: true}), "sign up with legacy verified");
  await denied(as(fresh).create(`users/${fresh.uid}`,
      {role: "worker", accountStatus: "blocked_bypass"}),
  "sign up with custom status");
  const intruder = await account("intruder");
  await denied(as(intruder).create(`users/${fresh.uid}`,
      {role: "customer"}), "create someone else's profile");
  await allowed(as(fresh).create(`users/${fresh.uid}`, {
    role: "worker", name: "New", identityVerificationStatus: "not_submitted",
    canAcceptJobs: false,
  }), "normal worker sign up");
});

test("users: workers cannot verify, unblock or pay themselves", async () => {
  const self = as(pendingWorker);
  const path = `users/${pendingWorker.uid}`;
  await denied(self.update(path, {identityVerificationStatus: "approved"}),
      "self-approve identity");
  await denied(self.update(path, {verificationLevel: "identity_verified"}),
      "self-raise verification level");
  await denied(self.update(path, {canAcceptJobs: true}),
      "pending worker switches on job acceptance");
  await denied(self.update(path, {isVerified: true}), "legacy isVerified");
  await denied(self.update(path, {verificationStatus: "verified"}),
      "legacy verificationStatus");
  await denied(self.update(path, {backgroundVerificationStatus: "approved"}),
      "background verification");
  await denied(self.update(path, {accountStatus: "active_vip"}),
      "account status");
  await denied(self.update(path, {isBlocked: false}), "legacy unblock");
  await denied(self.update(path, {credits: 500}), "add credits");
  await denied(self.update(path, {leadCredits: 500}), "legacy credits");
  await allowed(self.update(path, {credits: 4}), "spend a credit");
  await allowed(self.update(path, {
    identityVerificationStatus: "pending", verificationLevel: "unverified",
  }), "submit verification (stays pending)");
});

test("users: ratings and job counts are server-only", async () => {
  for (const [field, value] of [
    ["rating", 5], ["totalReviews", 99], ["averageRating", 5],
    ["avgRating", 5], ["completedJobs", 500], ["statsUpdatedAt", new Date()],
  ]) {
    await denied(as(worker).update(`users/${worker.uid}`, {[field]: value}),
        `worker sets own ${field}`);
    await denied(as(customer).update(`users/${worker.uid}`,
        {[field]: value}), `customer sets worker ${field}`);
  }
  await denied(as(customer).update(`users/${worker.uid}`,
      {rating: 1, totalReviews: 3, updatedAt: new Date()}),
  "customer refreshes worker aggregate (old client path)");
});

test("users: admins manage verification and status", async () => {
  await allowed(as(admin).update(`users/${pendingWorker.uid}`, {
    identityVerificationStatus: "approved", canAcceptJobs: true,
  }), "admin approves a worker");
  await allowed(as(admin).update(`users/${otherWorker.uid}`,
      {accountStatus: "blocked"}), "admin blocks a worker");
  await allowed(as(admin).update(`users/${otherWorker.uid}`,
      {accountStatus: "active"}), "admin unblocks a worker");
});

// ================================================================ requests
const openRequest = (customerId, extra = {}) => ({
  customerId,
  workerId: null,
  title: "Leaking tap",
  category: "Plumber",
  budget: "1500",
  status: "searching",
  isDirectRequest: false,
  ...extra,
});

test("requests: only customers create their own requests", async () => {
  await allowed(as(customer).create("requests/r_new",
      openRequest(customer.uid)), "customer posts a request");
  await denied(as(customer).create("requests/r_forged",
      openRequest(otherCustomer.uid)), "post as another customer");
  await denied(as(worker).create("requests/r_worker",
      openRequest(worker.uid)), "worker posts a request");
  await denied(as(customer).create("requests/r_done",
      openRequest(customer.uid, {status: "completed"})),
  "post an already completed request");
  await denied(as(customer).create("requests/r_reviewed",
      openRequest(customer.uid, {reviewed: true})),
  "post a pre-reviewed request");
});

test("requests: customers cannot fake progress or assign workers",
    async () => {
      await seed("requests/r_c1", openRequest(customer.uid));
      const me = as(customer);
      await denied(me.update("requests/r_c1", {status: "completed"}),
          "customer marks own request completed");
      await denied(me.update("requests/r_c1",
          {workerId: worker.uid, status: "accepted"}),
      "customer assigns a worker");
      await denied(me.update("requests/r_c1", {customerId: otherCustomer.uid}),
          "customer transfers request");
      await denied(as(otherCustomer).update("requests/r_c1",
          {status: "cancelled"}), "another customer cancels it");
      await allowed(me.update("requests/r_c1",
          {status: "cancelled", cancelledAt: new Date()}),
      "customer cancels an unassigned request");

      await seed("requests/r_c2", openRequest(customer.uid,
          {workerId: worker.uid, status: "accepted"}));
      await denied(me.update("requests/r_c2", {status: "cancelled"}),
          "customer cancels after a worker accepted");
      await allowed(me.update("requests/r_c2",
          {hasActiveEmergency: true, lastEmergencyAt: new Date()}),
      "customer raises SOS on a live job");
    });

test("requests: workers accept and progress only their own jobs",
    async () => {
      await seed("requests/r_w1", openRequest(customer.uid));
      await denied(as(worker).update("requests/r_w1",
          {status: "accepted", workerId: otherWorker.uid}),
      "worker assigns a lead to someone else");
      await denied(as(worker).update("requests/r_w1",
          {status: "accepted", workerId: worker.uid, budget: "99999"}),
      "worker rewrites the budget while accepting");
      await allowed(as(worker).update("requests/r_w1",
          {status: "accepted", workerId: worker.uid, acceptedAt: new Date()}),
      "worker accepts an open lead");
      await denied(as(otherWorker).update("requests/r_w1",
          {status: "accepted", workerId: otherWorker.uid}),
      "second worker steals an accepted job");

      await seed("requests/r_direct", openRequest(customer.uid,
          {workerId: worker.uid, isDirectRequest: true}));
      await denied(as(otherWorker).update("requests/r_direct",
          {status: "accepted", workerId: otherWorker.uid}),
      "worker takes a direct request meant for another worker");

      await allowed(as(worker).update("requests/r_w1", {
        status: "completed", completedAt: new Date(),
        reviewPending: true, reviewed: false,
      }), "assigned worker completes the job");
      await denied(as(worker).update("requests/r_w1", {reviewed: true}),
          "worker marks the job as reviewed");
      await denied(as(worker).update("requests/r_w1",
          {customerId: worker.uid}), "worker takes over the customer");
    });

// ================================================================= reviews
async function completedJob(id, customerId = customer.uid,
    workerId = worker.uid, status = "completed") {
  await seed(`requests/${id}`, openRequest(customerId,
      {workerId, status, reviewed: false, reviewPending: true}));
}
const review = (requestId, extra = {}) => ({
  workerId: worker.uid,
  customerId: customer.uid,
  requestId,
  rating: 5,
  review: "Great work",
  createdAt: new Date(),
  ...extra,
});
const submitReview = (user, requestId, data) => as(user).commit([
  {path: `reviews/${requestId}`, data, exists: false},
  {
    path: `requests/${requestId}`,
    data: {reviewed: true, reviewPending: false, reviewedAt: new Date()},
    mask: ["reviewed", "reviewPending", "reviewedAt"],
    exists: true,
  },
]);

test("reviews: the customer reviews a completed job once", async () => {
  await completedJob("rv1");
  await allowed(submitReview(customer, "rv1", review("rv1")),
      "customer reviews their completed job");
  await denied(as(customer).set("reviews/rv1", review("rv1", {rating: 1})),
      "customer overwrites (duplicates) the review");
  await denied(as(customer).update("reviews/rv1", {rating: 1}),
      "customer edits the review");
  await denied(as(customer).delete("reviews/rv1"), "customer deletes it");
  await denied(as(otherCustomer).update("reviews/rv1", {review: "bad"}),
      "another customer edits it");
  await denied(as(worker).update("reviews/rv1", {rating: 5}),
      "the worker edits their review");
  await allowed(as(admin).update("reviews/rv1", {isHidden: true}),
      "admin moderates a review");
});

test("reviews: rating must be a whole number from 1 to 5", async () => {
  for (const [label, rating] of [["0", 0], ["6", 6], ["-1", -1],
    ["4.5", 4.5], ["text", "5"]]) {
    const id = `rv_range_${label.replace(/\W/g, "_")}`;
    await completedJob(id);
    await denied(submitReview(customer, id, review(id, {rating})),
        `rating ${label}`);
  }
});

test("reviews: only for the right job, customer and worker", async () => {
  await completedJob("rv_open", customer.uid, worker.uid, "accepted");
  await denied(submitReview(customer, "rv_open", review("rv_open")),
      "review before the job is completed");

  await completedJob("rv_other");
  await denied(submitReview(otherCustomer, "rv_other", review("rv_other",
      {customerId: otherCustomer.uid})), "review someone else's job");

  await completedJob("rv_wrong_worker");
  await denied(submitReview(customer, "rv_wrong_worker",
      review("rv_wrong_worker", {workerId: otherWorker.uid})),
  "review a worker who did not do the job");

  await completedJob("rv_mismatch");
  await denied(as(customer).create("reviews/rv_elsewhere",
      review("rv_mismatch")), "review stored under another id");

  await denied(submitReview(worker, "rv_mismatch", review("rv_mismatch",
      {customerId: worker.uid})), "worker reviews themselves");

  await completedJob("rv_extra");
  await denied(submitReview(customer, "rv_extra", review("rv_extra",
      {isHidden: false, helpful: 100})), "review with extra fields");

  await completedJob("rv_flag_only");
  await denied(as(customer).update("requests/rv_flag_only",
      {reviewed: true}), "mark reviewed without a review");
});

// =========================================================== notifications
test("notifications: clients cannot notify other users", async () => {
  await denied(as(customer).create("notifications/n_fake", {
    userId: worker.uid, customerId: customer.uid, title: "New job",
    type: "job", isRead: false,
  }), "customer fans out a job alert");
  await denied(as(worker).create("notifications/n_self", {
    userId: worker.uid, title: "x", isRead: false,
  }), "worker creates a notification");

  await seed("notifications/n1",
      {userId: worker.uid, title: "New job", isRead: false});
  await denied(as(otherWorker).get("notifications/n1"),
      "read another user's notification");
  await denied(as(worker).update("notifications/n1", {title: "Edited"}),
      "edit notification text");
  await allowed(as(worker).update("notifications/n1",
      {isRead: true, readAt: new Date()}), "mark own notification read");
  await allowed(as(admin).create("notifications/n_admin",
      {userId: worker.uid, title: "Credits added", isRead: false}),
  "admin console sends a notification");
});

// =================================================================== admin
test("admin data: non-admins cannot write it", async () => {
  await denied(as(customer).set("admin_settings/general",
      {maintenanceMode: true}), "customer writes admin settings");
  await denied(as(worker).set("admin_settings/general",
      {maintenanceMode: true}), "worker writes admin settings");
  await allowed(as(admin).set("admin_settings/general",
      {maintenanceMode: false}), "admin writes settings");
  await denied(as(worker).create("admin_audit_logs/a1",
      {action: "x"}), "worker writes an audit log");
  await denied(as(admin).update("admin_audit_logs/a1", {action: "y"}),
      "audit logs are append-only");
});

test("payments, credits and verification stay with admins", async () => {
  await seed("payment_requests/p1",
      {workerId: worker.uid, status: "pending", credits: 10});
  await denied(as(worker).update("payment_requests/p1",
      {status: "approved"}), "worker approves own payment");
  await denied(as(worker).create("payment_requests/p2",
      {workerId: worker.uid, status: "approved"}), "submit approved payment");
  await allowed(as(worker).create("payment_requests/p3",
      {workerId: worker.uid, status: "pending", credits: 10}),
  "submit a pending payment");
  await denied(as(otherWorker).get("payment_requests/p1"),
      "read another worker's payment");

  await denied(as(worker).create("transactions/t1",
      {workerId: worker.uid, type: "credit_purchase", amount: "+100"}),
  "worker records a credit purchase");

  await denied(as(worker).set(`verification_requests/${worker.uid}`,
      {workerId: worker.uid, status: "approved"}),
  "worker approves own verification request");
  await denied(as(worker).set(`verification_requests/${otherWorker.uid}`,
      {workerId: otherWorker.uid, status: "pending"}),
  "worker writes another worker's verification");
  await allowed(as(worker).set(`verification_requests/${worker.uid}`,
      {workerId: worker.uid, status: "pending", identityStatus: "pending"}),
  "worker submits verification");
});
