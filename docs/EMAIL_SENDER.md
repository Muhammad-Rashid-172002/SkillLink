# SkillNova email sender

## How emails are sent

| Email | Sent by | Sender |
|---|---|---|
| Sign-up email verification | Callable Cloud Function `sendCustomVerificationEmail` (functions/index.js). The Admin SDK makes the link (`generateEmailVerificationLink`), Nodemailer sends it through Gmail SMTP | `SMTP_USER` / `MAIL_FROM_ADDRESS` |
| App "forgot password" | Callable `sendCustomPasswordResetEmail` (same transport, `generatePasswordResetLink`) | same |
| Fallback when the callable fails (app: `user.sendEmailVerification()` / `sendPasswordResetEmail`) and admin-console password reset | Firebase Authentication's own templates | Firebase Console setting (default `noreply@skilllink-e1064.firebaseapp.com`) |

Before this change the function logged in to SMTP as `ceo@korvenzatech.com`
(Google Workspace App Password in secret `SMTP_APP_PASSWORD`) and set
`From: noreply@korvenzatech.com` (a Workspace alias).

## What changed

- Sender settings are configuration, not code:
  `functions/.env.skilllink-e1064` → `SMTP_USER` and `MAIL_FROM_ADDRESS`
  = `muhammadrashid172002@gmail.com` (not secrets).
- The password is a new Secret Manager secret **`GMAIL_APP_PASSWORD`** (an
  App Password of that Gmail account). A new name means a deploy cannot
  silently reuse the old Workspace password.
- `functions/mail_config.js` refuses a From address that differs from the
  SMTP login (unless it is a verified "Send mail as" alias), because Gmail
  rewrites such a From header to the login mailbox.
- Links, templates, subjects, reply-to and behaviour are unchanged.

## Is a @gmail.com sender supported?

- **Gmail SMTP logged in as that same Gmail account: yes.** Requires
  2-Step Verification on the account and an App Password (Google hides App
  Passwords for some accounts, e.g. with Advanced Protection). Personal Gmail
  has a daily sending limit (about 500 recipients; SMTP clients can hit it
  sooner), fine for sign-ups but not for bulk mail; mail is signed by gmail.com, so it
  passes SPF/DKIM/DMARC.
- **Workspace mailbox sending "From" the Gmail address: not recommended.**
  It needs the Gmail address added and verified under "Send mail as" in
  ceo@korvenzatech.com, and the message would be DKIM-signed by
  korvenzatech.com while claiming gmail.com — likely spam-foldered or
  rejected under DMARC.
- **Firebase Authentication built-in templates: no.** The Console only
  allows `noreply@<project>.firebaseapp.com` or a custom domain you own and
  verify with DNS records; gmail.com cannot be verified. Those fallback
  emails keep Firebase's sender. You can still set the sender *name*
  ("SkillNova") and the reply-to address in Firebase Console →
  Authentication → Templates.

## To make it live (needs your approval; nothing was deployed)

1. In the Google account muhammadrashid172002@gmail.com: turn on 2-Step
   Verification, then create an App Password ("SkillNova SMTP").
2. Store it (it is never committed):
   `firebase functions:secrets:set GMAIL_APP_PASSWORD --project skilllink-e1064`
3. Deploy only the two mail functions:
   `firebase deploy --only functions:sendCustomVerificationEmail,functions:sendCustomPasswordResetEmail --project skilllink-e1064`
4. Optional cleanup later: `firebase functions:secrets:destroy SMTP_APP_PASSWORD`
   once nothing uses it.

## Test safely

- Unit tests: `cd functions && npm test` (mail_config.test.js).
- Emulator, no real email: `functions/.env.local` (git-ignored) points
  `SMTP_HOST=127.0.0.1`, `SMTP_PORT=1025` at a local SMTP catcher, and
  `functions/.secret.local` holds a placeholder `GMAIL_APP_PASSWORD`. Sign
  up a test user in the Auth emulator and call `sendCustomVerificationEmail`;
  the caught message shows the From header and the action link.
- Real check after deploy: sign up with an inbox you control, open the
  email, "Show original" in Gmail, and confirm `From:
  muhammadrashid172002@gmail.com` with SPF/DKIM/DMARC = PASS.
