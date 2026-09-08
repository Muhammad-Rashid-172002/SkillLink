import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_components.dart';

class WorkerPrivacyScreen extends StatelessWidget {
  const WorkerPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worker privacy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          SafetySupportCard(
            icon: Icons.public_outlined,
            title: 'Public professional profile',
            body:
                'Eligible workers may show their display name, profile photo, primary service, bio, experience, starting service rate, rating and review count, service area, and verification badge to customers.',
          ),
          SafetySupportCard(
            icon: Icons.lock_outline,
            title: 'Private identity and account data',
            body:
                'Your email, phone, CNIC and selfie documents, notification token, exact internal account fields, and admin metadata are not public profile fields. Contact details may be used in legitimate assigned-job flows where supported.',
          ),
          SafetySupportCard(
            icon: Icons.location_on_outlined,
            title: 'Location',
            body:
                'Your service area may be public. Exact map coordinates are not added by Edit Profile. Existing public discovery uses explicitly public coordinates, or legacy coordinates only when shareLocationOnExplore is enabled. On-the-way sharing is foreground-only; this area does not enable background tracking.',
          ),
          SafetySupportCard(
            icon: Icons.chat_bubble_outline,
            title: 'Jobs and messages',
            body:
                'Request conversations are available to their participants. Keep passwords, OTP codes, verification documents, and sensitive financial information out of chat.',
          ),
        ],
      ),
    );
  }
}
