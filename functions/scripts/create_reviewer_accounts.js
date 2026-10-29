#!/usr/bin/env node
/* eslint-disable max-len */
/**
 * Creates (or repairs) the two Google Play reviewer accounts:
 *   - a CUSTOMER account that opens straight into the customer app
 *   - a WORKER account that is verified and can accept jobs
 *
 * Run it yourself with Admin credentials — nothing is hardcoded in the app:
 *
 *   cd functions
 *   gcloud auth application-default login     # or GOOGLE_APPLICATION_CREDENTIALS=<service-account.json>
 *   node scripts/create_reviewer_accounts.js --project skilllink-e1064 \
 *     --customer-email playreview.customer@<your-domain> \
 *     --worker-email playreview.worker@<your-domain> \
 *     --customer-phone +923000000001 --worker-phone +923000000002
 *
 * Passwords are generated randomly and printed ONCE. Paste them into
 * Play Console > App content > App access. Re-running resets the passwords.
 *
 * The phone numbers are attached directly to the Auth users so reviewers
 * never need an SMS code. Use numbers you control (or reserved test numbers
 * also added under Firebase Console > Authentication > Phone > test numbers).
 */
const crypto = require("node:crypto");
const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const accounts = require("../accounts");

/**
 * Reads a --flag value.
 * @param {string} name Flag name.
 * @param {*} fallback Default.
 * @return {*} Value.
 */
function arg(name, fallback) {
  const index = process.argv.indexOf(`--${name}`);
  return index > -1 ? process.argv[index + 1] : fallback;
}

const project = arg("project");
const config = [
  {role: "customer", email: arg("customer-email"), phone: arg("customer-phone"), name: "Play Reviewer (Customer)"},
  {role: "worker", email: arg("worker-email"), phone: arg("worker-phone"), name: "Play Reviewer (Worker)"},
];
if (!project || config.some((c) => !c.email || !c.phone)) {
  console.error("Missing --project, --customer-email, --worker-email, --customer-phone or --worker-phone.");
  process.exit(1);
}

initializeApp({credential: applicationDefault(), projectId: project});
const auth = getAuth();
const db = getFirestore();

/**
 * Random reviewer password.
 * @return {string} Password.
 */
function password() {
  // 16 chars, letters + digits (meets the app's 8+ letter/number rule).
  return crypto.randomBytes(12).toString("base64").replace(/[^A-Za-z0-9]/g, "").slice(0, 14) + "7a";
}

/**
 * Creates or repairs one reviewer account.
 * @param {Object} entry Account spec.
 * @return {Promise<Object>} Credentials.
 */
async function upsert({role, email, phone, name}) {
  const pass = password();
  let user;
  try {
    user = await auth.getUserByEmail(email);
    user = await auth.updateUser(user.uid, {password: pass, emailVerified: true, phoneNumber: phone, displayName: name, disabled: false});
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    user = await auth.createUser({email, password: pass, emailVerified: true, phoneNumber: phone, displayName: name});
  }

  const ref = db.collection("users").doc(user.uid);
  const snapshot = await ref.get();
  const existingRole = snapshot.exists ? accounts.resolveStoredRole(snapshot.data()).role : null;
  if (existingRole && existingRole !== role) {
    throw new Error(`${email} already exists as a ${existingRole}. Use a different email.`);
  }
  const base = snapshot.exists ? {} : {...accounts.initialProfile({uid: user.uid, role, name, email, phoneNumber: phone, emailVerified: true}), createdAt: FieldValue.serverTimestamp()};
  await ref.set({
    ...base,
    role,
    name,
    emailVerified: true,
    phoneVerified: true,
    phoneNumber: phone,
    phone,
    profileCompleted: true,
    accountStatus: "active",
    city: "Islamabad",
    area: "F-7",
    isPlayReviewer: true,
    ...(role === "worker" ? {
      skill: "Plumber",
      experience: "5 years",
      hourlyRate: "1500",
      bio: "Demo worker profile for Google Play review.",
      identityVerificationStatus: "approved",
      verificationLevel: "identity_verified",
      canAcceptJobs: true,
    } : {
      identityVerificationStatus: "not_required",
      verificationLevel: "basic",
    }),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await auth.setCustomUserClaims(user.uid, {...(user.customClaims || {}), role});
  return {role, email, password: pass, uid: user.uid};
}

(async () => {
  const results = [];
  for (const entry of config) results.push(await upsert(entry));
  console.log("\nPlay Console > App content > App access — paste these:\n");
  for (const r of results) {
    console.log(`${r.role.toUpperCase()}: email ${r.email}  password ${r.password}`);
  }
  console.log("\nThe worker account is verified (Plumber) and can accept Plumber jobs for free.");
})().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
