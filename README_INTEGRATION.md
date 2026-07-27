# SkillNova Worker Verification Module

## Included files

- `worker_verification_center.dart`
- `cnic_verification_screen.dart`
- `live_selfie_screen.dart`
- `firestore.rules.example`
- `storage.rules.example`

## 1. Dependencies

Your project already has:

```yaml
firebase_auth:
cloud_firestore:
firebase_storage:
image_picker:
```

Run:

```bash
flutter pub get
```

No gallery is used for CNIC or selfie. Both are captured from the camera.

## 2. Add files

Copy the `lib/screens/verification` folder into:

```text
lib/screens/verification/
```

## 3. Worker profile routing

In `worker_profile_setup.dart`, replace the navigation that opens `WorkerHomeScreen`
after saving the worker profile:

```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => const WorkerVerificationCenterScreen(),
  ),
);
```

Add this import:

```dart
import 'package:skill_link/screens/verification/worker_verification_center.dart';
```

Also save these worker fields:

```dart
'identityVerificationStatus': 'not_submitted',
'verificationLevel': 'unverified',
'canAcceptJobs': false,
```

Do not overwrite an already approved worker. Prefer setting these fields during initial signup.

## 4. Job acceptance restriction

Before accepting a job:

```dart
final workerDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(FirebaseAuth.instance.currentUser!.uid)
    .get();

final data = workerDoc.data() ?? {};
final canAcceptJobs = data['canAcceptJobs'] == true;
final accountStatus = data['accountStatus']?.toString() ?? 'active';

if (!canAcceptJobs || accountStatus != 'active') {
  throw Exception(
    'Complete identity verification before accepting jobs.',
  );
}
```

For real production security, perform the final job acceptance through a trusted
backend or Cloud Function. UI checks alone are not sufficient.

## 5. Admin approval

On approval, your admin backend should update:

```dart
users/{workerId}
{
  identityVerificationStatus: "approved",
  verificationLevel: "identity_verified",
  canAcceptJobs: true,
  verifiedAt: serverTimestamp
}
```

And:

```dart
verification_requests/{workerId}
{
  identityStatus: "approved",
  reviewedBy: adminUid,
  reviewedAt: serverTimestamp
}
```

On rejection:

```dart
users/{workerId}
{
  identityVerificationStatus: "rejected",
  canAcceptJobs: false
}
```

## 6. Important security note

The included selfie screen forces a fresh front-camera capture. It is not
advanced anti-spoof liveness. A certified liveness provider or blink/head-turn
challenge should be added before treating it as strong biometric proof.
