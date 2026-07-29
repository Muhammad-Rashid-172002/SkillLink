# SkillNova Admin Verification Integration

Copy these files:

```text
lib/services/verification_management_service.dart
lib/screens/admin_verification_requests_screen.dart
```

## Sidebar

Add before Settings:

```dart
_SidebarItem('Verification', Icons.verified_user_rounded),
```

New order:

```text
0 Dashboard
1 Users
2 Workers
3 Jobs
4 Reviews
5 Reports
6 Credits
7 Notifications
8 Verification
9 Settings
```

## Dashboard screen

Add import:

```dart
import 'package:skilllink_admin/screens/admin_verification_requests_screen.dart';
```

Update `_pageTitles`:

```dart
static const _pageTitles = <String>[
  'Dashboard',
  'Users',
  'Workers',
  'Jobs',
  'Reviews',
  'Reports',
  'Credits',
  'Notifications',
  'Verification',
  'Settings',
];
```

In both mobile and desktop switch expressions:

```dart
8 => const AdminVerificationRequestsScreen(),
9 => const AdminSettingsScreen(),
```

## Required Storage rule

The admin web app uses `getData()` for private files. Give only admins read access:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isAdmin() {
      return request.auth != null && request.auth.token.admin == true;
    }

    match /private_verifications/workers/{workerId}/{allPaths=**} {
      allow write: if request.auth != null
                   && request.auth.uid == workerId
                   && request.resource.size < 8 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
      allow read: if isAdmin();
    }
  }
}
```

## Important

`role: admin` in Firestore is not the same as a Firebase Auth custom claim. Set
`admin: true` using Firebase Admin SDK or a Cloud Function, then sign out and sign
in again so the token refreshes.
