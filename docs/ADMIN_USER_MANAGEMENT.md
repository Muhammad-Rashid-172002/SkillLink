# Admin – User Management & Permanent Account Deletion

Status: implemented and tested locally (emulators). **Not deployed.**

## What admins get (Admin console → Users)

- Stats: total, verified, unverified, pending verification, rejected,
  suspended, new this week. Stat cards double as filters.
- Filters: All, Verified, Unverified, Pending Verification, Rejected,
  Suspended, Incomplete Profiles; account type (customer / worker); sort by
  registration date; search by name, email, phone (local `03…` or `+92…`)
  or user ID; 20 per page.
- Table (desktop) / cards (tablet & phone): name, email, phone, type,
  registration date, email and phone verification, CNIC review status
  (workers), overall verification, account status, actions.
- User details: profile, verification, profile completeness, identity
  documents (loaded through the admin-only Storage rule), approve / reject
  pending verification through the existing verification workflow.
- Suspend / reactivate (reason required) through `adminSetAccountStatus`.
- Delete (single): confirmation with name, email or masked phone, type,
  reason (Fake Account, Invalid Information, Failed Verification, Duplicate
  Account, Spam or Abuse, Policy Violation, Other + text) and an explicit
  "I understand" checkbox.
- Bulk delete: select users or "select all filtered" (max 50 per run),
  common reason or per-account reasons, progress bar, success/failure counts
  and a failure report. The console sends 10 accounts per call; the server
  accepts at most 20.

What "verified" means: workers — identity (CNIC + selfie) approved by an
admin; customers — email **and** phone verified. Existing accounts and the
legacy client-writable `isVerified` flag never count as verified.

The old console actions that wrote directly from the browser (toggle
`isVerified`, delete `users/{uid}` only) were removed.

## Backend (functions/account_deletion.js, callable functions)

`adminDeleteUser {uid, reason, reasonDetail}` and
`adminDeleteUsers {uids[≤20], reason, reasonDetail, reasons{uid:{reason}}}`.

Checks, in order: caller signed in → caller is an active admin
(`admins/{uid}.isActive`, read on the server) → valid reason → target is
not the caller → target is not an admin → target exists (profile, Auth user
or an unfinished deletion record) → target has no active job (accepted /
on the way / in progress), so nobody is stranded mid-job.

| Data | What happens |
|---|---|
| Firebase Auth user | disabled + tokens revoked first, then deleted |
| `users/{uid}` (+ subcollections) | deleted last |
| `public_profiles/{uid}` | deleted |
| `verification_requests/{uid}` | deleted |
| `notifications` where `userId == uid` | deleted |
| `live_tracking` where customer/worker is the user | deleted |
| `requests` posted by the user | kept for the worker's history; open ones cancelled (`account_deleted`); address, coordinates, photos, name and contact removed; `private/*` contact docs deleted |
| `requests` assigned to the user (worker) | kept; open direct requests cancelled; name/phone/photo removed |
| `chats` + messages | kept for the other person; deleted side's name/photo removed, `customerDeleted`/`workerDeleted` set |
| `reviews` written by the user | kept (they are part of a worker's rating) with the name removed |
| `reviews` about a deleted worker | kept unchanged (other customers' content) |
| `support_requests` | kept as a service record without name/email/phone |
| `emergency_alerts`, `reports`, `payment_requests`, `transactions`, `admin_audit_logs` | kept unchanged (safety, fraud, financial, audit) |
| Storage `profile_images/workers/{uid}/`, `customer_profiles/{uid}.jpg`, `private_verifications/workers/{uid}/`, `request_images/{uid}/` | deleted |
| Storage `chat_media/…`, `chat_audio/…` | kept (shared conversation) |
| Storage `payment_receipts/{uid}/` | kept (financial) |

Reliability: every step is idempotent and recorded in
`account_deletions/{uid}` (status `in_progress` / `completed` /
`partial_failure`, steps, failed steps, attempts, request id, reason). A
failure in one step does not stop the others; the response lists failed
steps and the admin can simply delete again to finish. Re-deleting a
completed account re-runs clean-up and returns `already_deleted`.

Triggers that write `users/{workerId}` (`syncWorkerRating`,
`syncWorkerCompletedJobs`) now skip profiles that no longer exist, so a
deleted account is never recreated.

Storage bucket: the functions clean the bucket named in
`functions/.env.skilllink-e1064` (`SKILLNOVA_STORAGE_BUCKET`, the bucket from
`firebase_options.dart`), so the emulator and production clean the same
bucket.

## Audit log

Each attempt writes one `admin_audit_logs` entry: `action`
(`user_deleted`, `user_deletion_partial`, `user_deletion_rejected`),
`adminUid`, `targetUid`, `reason`, `reasonDetail`, `result`,
`failedSteps`, `error`, `requestId`, `createdAt`. Suspension, SOS actions
and verification approve / reject / resubmission are audited too. Rules
keep audit entries append-only (no client update/delete, admins included).

## Security rules

- `users/{uid}`: `allow delete: if false` (was admin). Profiles are deleted
  only by the Cloud Function together with Auth and related data.
- New `account_deletions/{uid}`: admin read, no client writes.
- Storage rules unchanged; tests added proving other users can't read
  identity documents or delete someone else's files.

## Local verification

```
cd functions && npm ci && npm run lint && npm test
sh firestore-tests/run.sh            # Firestore rules (needs Java 21)
cd firestore-tests && npm install && cd .. && sh firestore-tests/run_storage.sh
cd skilllink_admin && flutter pub get && flutter analyze && flutter test
flutter test test/user_management_test.dart   # in skilllink_admin
cd .. && flutter analyze && flutter test
sh tool/verify.sh
```

Try it end to end on emulators only:

```
firebase emulators:start --config firebase.qa-emulators.json --project skilllink-e1064
cd skilllink_admin && flutter run -d chrome \
  --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

Deploying (only when you decide to): `firebase deploy --only
functions:adminDeleteUser,functions:adminDeleteUsers,functions:syncWorkerRating,functions:syncWorkerCompletedJobs,firestore:rules`
then the admin web app.
