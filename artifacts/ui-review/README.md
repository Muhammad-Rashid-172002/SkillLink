# SkillNova UI review screenshots (30 Oct 2026)

Real screenshots taken by driving the **web builds** of the mobile app and the
admin console in headless Chromium (Playwright), connected to the **local
Firebase emulators** (project id `skilllink-e1064`, emulator only — no
production traffic). All accounts and records are clearly labelled QA test
data (`qa.*@skillnova.test`, titles starting with "QA test").

- `mobile/` — phone viewport 390×844 @2x. Numbers follow the order of the flows:
  01–16 onboarding + customer signup/verification/profile, 20–36 worker signup,
  profile, CNIC + selfie verification, 40–46 customer explore + post request,
  50–58 worker lead → accept → on my way + location sharing, 59–63 customer live
  tracking (moving worker), 64–74 start → complete → review, 77–81 second
  (urgent) request, 82–88 two-way chat, 89–90 notifications, 91–99 profiles,
  settings, dark mode, help, 100–104 support form and SOS.
- `admin/` — desktop 1440×900 unless the name says otherwise (1024, 768, 390).
  01–07 login + verification approval, 08–19 every section, 20–24 SOS
  investigate/resolve, support resolve, audit log, 30–40 responsive widths.

Limits: the Google Maps SDK is not loaded in this environment, so map areas
show the app's own fallback card; road ETA shows "still calculating" because
the Routes API cannot be reached from the sandbox. Android was not run here.
`31_emergency_alerts_390_before_fix.png` shows a bug that was then fixed
(`38_emergency_alerts_390.png` is after the fix).
