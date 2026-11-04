# SkillNova authentication: setup for Firebase project `skillnova-2e776`

## Why login and Google Sign-In fail today

On 31 Oct the app's Firebase files (`lib/firebase_options.dart`,
`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`,
`firebase.json`) were switched to the new project **skillnova-2e776**. The
backend was never moved:

- `.firebaserc` still deployed to **skilllink-e1064**, so the new project has
  no `initializeAccount` Cloud Function and none of SkillNova's Firestore /
  Storage rules.
- Every login and sign-up ends by calling `initializeAccount` (it creates
  `users/{uid}` and assigns the role on the server). In the new project that
  call fails, so the app showed "We couldn't set up your account right now"
  (or the generic "Something went wrong on our side") right after a
  successful Firebase sign-in. Reproduced on the emulators with the
  functions switched off: `initializeAccount failed: internal`.
- Google: the new `google-services.json` has `"oauth_client": []` — no
  Android OAuth client (SHA fingerprints) and no Web client ID. google_sign_in
  7.x on Android needs that Web client ID (`default_web_client_id`), so it
  fails with a client configuration error before any account is chosen. The
  iOS plist has no `CLIENT_ID` / `REVERSED_CLIENT_ID`.

The app code was correct for a configured project; it now also explains
these failures instead of showing a generic error.

## Done in the repository

- `.firebaserc` (root and `skilllink_admin/`): default = `skillnova-2e776`,
  alias `legacy` = `skilllink-e1064`.
- `functions/.env.skillnova-2e776`: storage bucket and email sender for the
  new project.
- Admin console (`skilllink_admin/lib/firebase_options.dart`, `firebase.json`,
  `cors.json`) points at the new project's web app.
- iOS `Info.plist`: phone-auth URL scheme updated to the new iOS app id.
- Clear messages for wrong password, duplicate email, offline, cancelled
  Google sign-in, missing backend / Google configuration.

## Firebase Console (project skillnova-2e776)

1. **Authentication → Sign-in method**: enable **Email/Password**, **Google**
   (pick a support email) and **Phone** (the app verifies phone numbers).
2. **Firestore Database → Create database** (production mode) if it does not
   exist yet. **Storage → Get started** if not set up.
3. **Project settings → Your apps → Android `com.rashidapps.skillnova` → Add
   fingerprint**. Add every certificate that signs a build:

   | Certificate | SHA-1 | SHA-256 |
   |---|---|---|
   | Debug (this Mac, `~/.android/debug.keystore`) | `23:55:93:88:6E:AA:E7:2A:79:3F:FB:D9:D8:13:6C:E7:85:40:F6:71` | `AF:21:7B:88:CE:DA:89:7E:59:6B:2E:79:0F:8D:85:E5:92:FA:A9:4A:06:11:52:B5:06:5C:E2:F5:60:35:83:BF` |
   | Upload key (`android/app/skillnova-upload-key.jks`) | `5A:1E:BF:AE:B6:8C:D0:A9:FA:01:10:60:8E:6D:FA:EB:7B:2A:5B:2E` | `E5:F8:34:2E:EB:A3:14:91:F0:88:39:02:0B:C5:F2:DD:84:76:D0:E1:F5:4D:BF:55:5D:08:62:EB:6F:67:5B:6B` |
   | Google Play App Signing key | Play Console → Test and release → App integrity → App signing | same page |

   The old project also had `66:95:C6:BB:32:C7:3F:00:CD:FA:6A:CA:B0:BB:B0:77:F9:53:60:98`
   and `50:C9:00:B7:30:B3:B3:7F:2C:D3:F9:5B:CD:D5:55:2B:A2:3B:BC:BC`
   registered; one of them is very likely the Play App Signing key — check
   it against Play Console and add it.
4. After adding fingerprints and enabling Google, **download the new
   `google-services.json`** (it must now contain `oauth_client` entries with
   `client_type: 1` and `client_type: 3`) into `android/app/`.
5. **iOS app `com.rashidapps.skillnova`**: download the new
   `GoogleService-Info.plist` (it must contain `CLIENT_ID` and
   `REVERSED_CLIENT_ID`), put it in `ios/Runner/`, then add the
   `REVERSED_CLIENT_ID` value as a second string under `CFBundleURLSchemes`
   in `ios/Runner/Info.plist`. Run `flutterfire configure --project
   skillnova-2e776` afterwards so `lib/firebase_options.dart` carries the iOS
   client id.
6. **Authentication → Settings → Authorized domains**: add the domain the
   admin console is hosted on (for example `skillnova-2e776.web.app`).

## Google Cloud Console (same project)

- **APIs & Services → Credentials**: after step 3/4 you should see an
  "Android client (auto created by Google Service)" per SHA-1 and a
  "Web client (auto created by Google Service)". Nothing to create by hand.
- **OAuth consent screen**: app name SkillNova, support email, publish to
  *In production* (in *Testing* only listed test users can sign in).
- If the API keys are restricted, allow the Android package
  `com.rashidapps.skillnova` with the SHA-1s above and the iOS bundle id.

## Deploy the backend to the new project (your approval needed)

```
firebase use skillnova-2e776
firebase functions:secrets:set GMAIL_APP_PASSWORD      # Gmail App Password
firebase functions:secrets:set GOOGLE_ROUTES_API_KEY   # Routes API key
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

Then create the first admin: add `admins/{yourUid}` with `isActive: true`
in the Firestore console (the admin console checks it on the server).

Existing users and data stay in `skilllink-e1064`; they are not copied.

## Test after setup

1. Register with email/password → "Verify your email" screen.
2. Sign out, sign in again → no error; verified accounts reach their
   dashboard (customer → Customer Home, worker → Worker Home).
3. Wrong password → "Invalid email or password…".
4. Register an existing email → "This email is already registered…".
5. Continue with Google (new user, from the Customer or Worker tab) → account
   created with that role; sign out and Google again → same account, same
   role; Google with a different tab never changes the role.
6. Airplane mode → "Please check your internet connection…".
7. Close and reopen the app → still signed in.
