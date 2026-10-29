#!/usr/bin/env node
/* eslint-disable max-len */
/**
 * One-time migration for EXISTING accounts after deploying the new rules and
 * functions. Safe to re-run. Dry-run by default.
 *
 *   cd functions
 *   node scripts/backfill_accounts.js --project skilllink-e1064            # report only
 *   node scripts/backfill_accounts.js --project skilllink-e1064 --apply    # write
 *
 * For every users/{uid}:
 *   - resolves the role from stored data only (never guesses),
 *   - repairs a non-canonical / legacy role field,
 *   - sets the `role` custom claim,
 *   - writes public_profiles/{uid} (name, photo, city, worker skills, rating).
 * Accounts whose role cannot be determined are listed, not changed.
 */
const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const accounts = require("../accounts");

const index = process.argv.indexOf("--project");
const project = index > -1 ? process.argv[index + 1] : null;
const apply = process.argv.includes("--apply");
if (!project) {
  console.error("Usage: node scripts/backfill_accounts.js --project <id> [--apply]");
  process.exit(1);
}
initializeApp({credential: applicationDefault(), projectId: project});
const auth = getAuth();
const db = getFirestore();

(async () => {
  const stats = {total: 0, ok: 0, repaired: 0, claims: 0, publicProfiles: 0, unresolved: [], missingAuth: []};
  let last = null;
  for (;;) {
    let query = db.collection("users").orderBy("__name__").limit(300);
    if (last) query = query.startAfter(last);
    const page = await query.get();
    if (page.empty) break;
    for (const doc of page.docs) {
      stats.total++;
      const data = doc.data();
      const {role, source} = accounts.resolveStoredRole(data);
      if (!role) {
        stats.unresolved.push(`${doc.id} (${data.email || "no email"}): ${source}`);
        continue;
      }
      if (role === "admin") continue;
      if (source !== "stored") {
        stats.repaired++;
        if (apply) {
          await doc.ref.set({role, roleRecoveredFrom: source, roleRecoveredAt: FieldValue.serverTimestamp()}, {merge: true});
        }
      } else {
        stats.ok++;
      }
      try {
        const user = await auth.getUser(doc.id);
        if ((user.customClaims || {}).role !== role) {
          stats.claims++;
          if (apply) await auth.setCustomUserClaims(doc.id, {...(user.customClaims || {}), role});
        }
      } catch (error) {
        if (error.code === "auth/user-not-found") stats.missingAuth.push(doc.id);
        else throw error;
      }
      const profile = accounts.publicProfileOf(doc.id, {...data, role});
      if (profile && !["suspended", "blocked", "deleted"].includes(profile.accountStatus)) {
        stats.publicProfiles++;
        if (apply) await db.collection("public_profiles").doc(doc.id).set({...profile, updatedAt: new Date()});
      }
    }
    last = page.docs[page.docs.length - 1];
  }
  console.log(JSON.stringify({mode: apply ? "APPLIED" : "DRY RUN", ...stats}, null, 2));
  if (stats.unresolved.length) {
    console.log("\nThese accounts have no trustworthy role. Fix them in the admin console (set users/{uid}.role), or the owner will be asked once in the app:");
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
