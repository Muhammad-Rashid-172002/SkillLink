/* eslint-disable max-len */
const test = require("node:test");
const assert = require("node:assert/strict");
const a = require("../accounts");

test("new account takes the role chosen at sign-up", () => {
  assert.deepEqual(
      a.planAccountInitialization({exists: false, data: {}, requestedRole: "worker"}),
      {action: "create", role: "worker", source: "sign_up"});
});

test("new account without a valid role asks for one", () => {
  for (const role of [undefined, "", "admin", "superuser"]) {
    assert.equal(
        a.planAccountInitialization({exists: false, data: {}, requestedRole: role}).action,
        "needs_role");
  }
});

test("existing role is never changed by a client request", () => {
  const plan = a.planAccountInitialization({
    exists: true, data: {role: "customer"}, requestedRole: "worker"});
  assert.deepEqual(plan, {action: "keep", role: "customer", source: "stored"});
});

test("non-canonical and legacy roles are repaired server-side", () => {
  assert.equal(a.planAccountInitialization({
    exists: true, data: {role: " Worker "}, requestedRole: "customer"}).role, "worker");
  assert.deepEqual(a.planAccountInitialization({
    exists: true, data: {userType: "client"}, requestedRole: "worker"}),
  {action: "repair", role: "customer", source: "legacy_field"});
});

test("profile evidence beats the requested role", () => {
  assert.equal(a.planAccountInitialization({
    exists: true, data: {skill: "Plumber"}, requestedRole: "customer"}).role, "worker");
});

test("conflicting evidence is never guessed and blocks self-claim", () => {
  const plan = a.planAccountInitialization({exists: true,
    data: {skill: "Plumber", identityVerificationStatus: "not_required"},
    requestedRole: "customer"});
  assert.equal(plan.action, "needs_role");
  assert.equal(plan.source, "conflict");
});

test("owner may claim a role once only for an empty legacy account", () => {
  assert.deepEqual(a.planAccountInitialization({
    exists: true, data: {name: "Ali"}, requestedRole: "customer"}),
  {action: "claim", role: "customer", source: "owner_selection"});
});

test("admin accounts are reported, never converted", () => {
  assert.equal(a.planAccountInitialization({
    exists: true, data: {role: "admin"}, requestedRole: "customer"}).action, "admin");
});

test("public profile hides private fields", () => {
  const profile = a.publicProfileOf("u1", {
    role: "customer", name: "Sara", email: "s@x.com", phoneNumber: "+923001234567",
    fcmToken: "t", lat: 1, lng: 2});
  assert.equal(profile.name, "Sara");
  for (const key of ["email", "phoneNumber", "fcmToken", "lat", "lng"]) {
    assert.equal(key in profile, false, key);
  }
  assert.equal(a.publicProfileOf("x", {role: "admin"}), null);
});
