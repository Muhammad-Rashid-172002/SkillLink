# SkillNova — Audit, Fixes & Delivery Report (30 Oct 2026)

Rollback point: `_backups/skill_link_pre_audit_20261030.tgz` (full project including `.git`, taken
before any change). Nothing has been deployed to Firebase or Google Play.

## How this was verified (read first)

| Check | Where it ran | Result |
|---|---|---|
| `dart analyze` (app + admin + tests), Flutter 3.41.6 / Dart 3.11.4 | Cloud sandbox, using your own Flutter SDK + pub cache | **0 errors, 0 warnings** (only style "info" hints that already existed) |
| Cloud Functions lint (`eslint`) | Cloud sandbox | Pass |
| Cloud Functions unit tests (`npm test`) | Cloud sandbox | **16/16 pass** (9 new tests for the role logic) |
| Firestore security-rules tests (emulator) | Cloud sandbox, your emulator jar | **21/21 pass** (rewritten for the new rules) |
| Storage security-rules tests (emulator) | Cloud sandbox | **13/13 pass** (new) |
| Polyline decoding / distance formatting | Cloud sandbox (pure Dart) | Pass |
| `flutter test` (widget tests) | **Not run** — Flutter's test engine for Linux can't be downloaded here | Run `sh tool/verify.sh` on your Mac |
| Android / iOS builds, real devices, OTP SMS, Google Maps rendering, two-device live tracking | **Not run** — needs your Mac/phones and Firebase/Google Cloud console | See "Still to do on your side" |

I am not claiming that OTP delivery, map rendering or live tracking work on real devices. The code
and configuration are fixed, and the security rules are tested, but each of those three needs a test
on a real phone.

## 1. Root causes found and fixed

| Problem | Root cause | Fix |
|---|---|---|
| Google Maps blank on Android | `MAPS_API_KEY` is in `android/local.properties`, but `build.gradle.kts` used `project.findProperty()`, which never reads local.properties, so the manifest got an empty key. | `build.gradle.kts` now reads local.properties → Gradle property → env var, and warns at build time if the key is missing. |
| Maps / location / camera on iOS | No `GMSServices.provideAPIKey`. No usage-description strings (iOS kills the app when it asks for location, camera, photos or microphone). | `AppDelegate.swift` provides the key from `Info.plist` (`GMSApiKey` = `$(MAPS_API_KEY)` from the git-ignored `ios/Flutter/Secrets.xcconfig`). Added all usage strings. |
| Phone OTP fails on iOS | The reCAPTCHA fallback URL scheme was missing. | Added the encoded app ID URL scheme and the `remote-notification` background mode (silent APNs push). |
| "Invalid account role", or a customer ending up as a worker on a 2nd device | The client decided the role: on login it fell back to a role cached on the device, or to the tab the person tapped, and wrote it to Firestore. The old FCM-token bug also left half-created profiles with no role. | The role is now **server-authoritative**. The new `initializeAccount` Cloud Function is the only place a role is written. It never changes an existing role, never guesses when the evidence conflicts, and sets the `role` custom claim. The app's `RoleResolver` only reads stored data. The device cache is only ever forwarded to the server, which accepts it only for an empty account. |
| Phone/email "verified" could be faked | Rules let the client set `phoneVerified: true` and `emailVerified: true`. | Rules require the ID token to prove them (`phone_number`, `email_verified`). The session now checks Firebase Auth's linked phone, not the Firestore flag. OTP: max 5 wrong codes, then a forced resend, plus extra error messages. |
| Workers could read every customer's email/phone | `users` read rule: `|| isWorker()`. | Customer profiles are private. The new `public_profiles` collection (name, photo, city, skills, rating — no email, phone or GPS) is kept in sync by `syncAccountState`. All worker-side reads were moved to it. The customer's phone goes only to the assigned worker, in `requests/{id}/private/contact` (Cloud Function, deleted when the job ends). |
| Worker "live location" was public | It was written to the worker's public `users` doc (`lat`/`lng`). | It is now written only to `live_tracking/{requestId}`, readable by that job's customer, worker and admins. Rules check that the writer is the assigned worker, the job is active, coordinates are valid and timestamps come from the server. |
| Workers could set any job status (e.g. straight to "completed") | Worker update rule didn't check transitions. | Rules enforce `accepted → on_the_way → in_progress → completed` (+ worker cancel before work starts). Accepting a job needs a verified, available, active worker. |
| Customer reviews never loaded on a worker's public profile | The repository read other customers' `users` docs and requests, which the rules deny, so the whole stream errored. | Names/photos are stored on the review (validated by rules) plus `public_profiles`. The stream no longer fails. |
| Storage rules not deployed | `firebase.json` had no `storage` entry, and only one path had a rule. | New `storage.rules` (owner-only uploads, image/audio type and size checks, chat media limited to the chat's participants, ID documents admin-read only). Added to `firebase.json`. |
| Build breaks on Linux/CI | Imports used `customer_screens/chat/`, but the folder is `Chat/` (works only on macOS's case-insensitive disk). | Fixed the imports (80+ analyzer errors gone). |

## 2. Payments removed — SkillNova is free

- **Worker app:** the Wallet/"Lead credits" screens and the payment-proof upload are deleted. Accepting a lead no longer spends a credit or writes a transaction. The "needs credits" readiness state is gone. A "Jobs are free on SkillNova" card was added, and lead detail shows "Free to accept".
- **Admin:** the Credits and Payment-requests screens and the credit service are removed. The settings page shows "Pricing: free". The dashboard no longer counts payments.
- **Rules:** clients can no longer create `payment_requests` or `transactions`, or change `credits`. Old records stay readable by their owner and admins. No user data was deleted.
- To charge later, add a server-side function that checks payment before `accept`. The status rules already gate acceptance on the server.

## 3. Live tracking + ETA

- **Worker** (`worker_job_detail_screen` + `worker_jobs_repository.shareLocation`): sharing starts only when the job is **on the way**, from the job screen, with a runtime permission request and clear messages for permission denied or GPS off. Writes are throttled (`shouldPublishLocation`): at least 8 s apart, skipped for moves under 20 m, with a 45 s heartbeat. It reuses a cached GPS fix under 10 s old. Sharing stops automatically at in-progress, completed or cancelled (status check + `syncLiveTrackingWithJobStatus`). Stale docs are expired every 15 min (`expireStaleLiveTracking`). Firestore queues writes while offline.
- **ETA:** `computeJobRoute` (Google Routes API, server-side secret key) is called at most every 45 s. Its destination is now the job's service location, not the customer's phone. With no route, the app says "still calculating"; **no straight-line ETA is ever shown**.
- **Customer** (`LiveTrackingPanel`): green worker marker that glides to each new position (rotates by heading), service-location marker, road-route polyline, the sentence *"Your worker is on the way and is expected to arrive in approximately X minutes."*, ETA/distance chips, "last updated N seconds ago", a stale-location warning, and a re-center button. The worker's name/photo card, chat, call and SOS stay above the map.
- Background tracking (screen off or another app open) is **not** enabled on purpose. It needs Play/App Store background-location declarations. Workers are told to keep the job screen open.

## 4. Other improvements

- **Notifications:** new cancellation push + in-app notification to the other party. The existing job/status/review/chat notifications are unchanged ("arrived" uses the existing "Job started" message).
- **Support:** every customer-facing support address is now **MuhammadRashid172002@gmail.com** (app config, admin config, email reply-to). The SMTP sender address was left alone (it must match the authenticated mail account). New in-app **"Send us a message"** form (`support_requests`, sender + admin only).
- **Admin:** new **Support requests** screen (filter, search, paging, resolve/re-open) and **Audit log** screen. Block/unblock/delete now write audit entries. The `adminSetAccountStatus` callable needs a reason for suspensions. `syncAccountState` disables the Firebase Auth user and revokes sessions on suspend/block.
- **Design:** new green design system (UI UX Pro Max-guided, AA-checked) applied through theme tokens to the whole app and the admin console. Poppins headings + Inter body. Plain-language onboarding (Find → Book in 3 steps → Track) and role-selection copy. See `docs/design-system/MASTER.md`.
- **Admin stack decision:** I kept Flutter. The console already covers users, workers, jobs, reviews, reports, SOS, verification, notifications and settings on the same Firebase backend. A React rewrite would duplicate about 15k lines with no security gain and a high risk of losing features.

## 5. Firebase changes (not deployed)

New/changed Cloud Functions: `initializeAccount`, `syncAccountState`, `adminSetAccountStatus`, `expireStaleLiveTracking`
(scheduled), `shareCustomerContact`, `sendCancellationNotification`, and an updated `computeJobRoute`.
New collections: `public_profiles`, `requests/{id}/private/contact`, `support_requests`.
Rules: `firestore.rules` (rewritten), `storage.rules` (new). Migration scripts:
`functions/scripts/backfill_accounts.js`, `functions/scripts/create_reviewer_accounts.js`.

### Deploy order (when you approve)

```bash
cd functions && npm ci && cd ..
firebase deploy --only functions            # 1. functions first (sign-up needs initializeAccount)
node functions/scripts/backfill_accounts.js --project skilllink-e1064          # 2. dry run
node functions/scripts/backfill_accounts.js --project skilllink-e1064 --apply  # 3. claims + public profiles
firebase deploy --only firestore:rules,firestore:indexes,storage   # 4. rules last
```

If the rules go out before the functions, new sign-ups will fail. Existing accounts keep working
either way.

## 6. Still to do on your side (external configuration)

1. **Google Cloud → APIs:** enable *Maps SDK for Android*, *Maps SDK for iOS* and *Routes API*. Billing must be on — I could not check this.
2. **Keys:** restrict the Android key to package `com.rashidapps.skillnova` plus the SHA-1 of your upload key (`5A:1E:BF:AE:…:2B:2E`) **and** the Play App Signing key (Play Console → App integrity), with only the Maps SDK for Android API. Create a separate iOS key (bundle ID restricted), put it in `ios/Flutter/Secrets.xcconfig` (copy from `.example`), and run `cd ios && pod install`. Set the server key with `firebase functions:secrets:set GOOGLE_ROUTES_API_KEY` (Routes API only).
3. **Phone OTP:** Firebase Console → Authentication → Phone enabled. Add the **Play App Signing SHA-1 and SHA-256** to the Android app in Firebase (Play Integrity needs them, and this is the usual reason SMS codes don't arrive from Play builds). Enable the Play Integrity API. Upload an APNs auth key for iOS. Optionally add test phone numbers.
4. **iOS Google Sign-In:** `GoogleService-Info.plist` has no `CLIENT_ID`. Add an iOS OAuth client in Firebase, re-download the plist, and add `REVERSED_CLIENT_ID` to the URL types.
5. **Privacy policy page** (`skillnova-privacy-center.vercel.app`): update its contact email, mention live location sharing during active jobs, and remove any mention of payments.
6. Run `sh tool/verify.sh` on your Mac and send me `_claude_tmp/verify.log`. I'll fix anything `flutter test` reports.

## 7. Google Play resubmission checklist

- [ ] Deploy (section 5), then run `create_reviewer_accounts.js` → two accounts with random passwords, verified email, phone attached (no SMS needed), and a verified Plumber worker. Credentials go **only** in Play Console → App content → **App access**, never in code.
- [ ] Reviewer instructions: "Choose 'I need a service' → Sign in with the customer account. For the worker app: sign out → 'I offer a service' → Sign in with the worker account. To see live tracking: post a Plumber request as the customer, accept it as the worker, tap 'On my way'."
- [ ] Sign in with both accounts on a fresh install. Check: no role error, no OTP, no payment screen, no dead ends.
- [ ] **Data safety:** location (precise, shared with the job's other party, app functionality), name, email, phone, photos, messages, audio (voice notes), ID images (worker verification), device ID (FCM token). Not sold, encrypted in transit, account deletion path.
- [ ] **Permissions declaration:** foreground location only (no background), camera, microphone, notifications.
- [ ] **Account deletion:** Play requires an in-app path plus a web link. The app currently says deletion is handled by support. Make sure the email/web form actually deletes the account (this is still pending in code).
- [ ] Target the latest API level and upload a release build signed with the upload key.
- [ ] Approval is not guaranteed.

## 8. Completed / partial / pending

**Completed:** role security + invalid-role root cause; server role function + claims; phone/email
verification hardening; OTP UX limits; payment removal (app, admin, rules); Android/iOS Maps
configuration; iOS permission strings; live-tracking pipeline (worker publish, rules, customer map,
Routes ETA, stale expiry); customer privacy (`public_profiles`, private contact); job status transition
rules; storage rules; reviews with customer name/photo; review loading bug; cancellation
notifications; support email + in-app support form + admin support inbox; admin audit log;
green design system for app + admin; rules/functions test suites.

**Partially completed:**

- UI redesign: theme-level redesign of every screen plus new copy for onboarding and role selection. Individual screens were not rebuilt one by one, and none were visually checked on devices.
- Responsive design: the existing breakpoints are kept, but nothing was tested on real screens.
- Admin: removed payments and added support and audit screens. Admin "view live location" and charts are unchanged.
- Notifications: there is no separate "arrived" event.

**Pending / not done:**

- `flutter test` + builds (needs your Mac).
- Real-device OTP, maps and two-device tracking tests.
- Background location while the app is closed.
- Account-deletion backend.
- Moving the worker directory to `public_profiles`: worker `users` docs are still publicly readable, including the worker's base `lat`/`lng`, email and phone. This is the next privacy step.
- Bundled fonts (Poppins/Inter still load at runtime through `google_fonts`).
- Paging for very large admin user lists.

## 9. Run locally

```bash
cd ~/Desktop/My_Project/skill_link
flutter pub get && flutter run                      # app (MAPS_API_KEY in android/local.properties)
cd skilllink_admin && flutter pub get && flutter run -d chrome   # admin
sh tool/verify.sh                                   # analyze + tests + rules tests + debug APK
```
