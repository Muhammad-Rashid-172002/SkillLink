import 'package:flutter/material.dart';
import 'package:skill_link/config/skillnova_support_config.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/Role_selection_screen/role_selection.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_account_screens.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_components.dart';
import 'package:skill_link/screens/verification/worker_verification_center.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/worker_screens/Wallat/Wallat_screen.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_models.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_jobs_screen.dart';
import 'package:skill_link/screens/worker_screens/menuTiles/ReviewsScreen.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/WorkerPublicProfileScreen.dart';

import 'worker_account_screen.dart';
import 'worker_edit_profile_screen.dart';
import 'worker_help_screen.dart';
import 'worker_privacy_screen.dart';
import 'worker_profile_components.dart';
import 'worker_profile_models.dart';
import 'worker_profile_repository.dart';
import 'worker_safety_screen.dart';
import 'worker_settings_screen.dart';

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({
    super.key,
    this.repository,
    this.onEdit,
    this.onSettings,
    this.onVerification,
    this.onPublicProfile,
    this.onCredits,
    this.onReviews,
    this.onCompletedJobs,
    this.onLoggedOut,
  });

  final WorkerProfileRepository? repository;
  final VoidCallback? onEdit;
  final VoidCallback? onSettings;
  final VoidCallback? onVerification;
  final VoidCallback? onPublicProfile;
  final VoidCallback? onCredits;
  final VoidCallback? onReviews;
  final VoidCallback? onCompletedJobs;
  final VoidCallback? onLoggedOut;

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  late final WorkerProfileRepository _repository;
  late Stream<WorkerProfile> _profileStream;
  bool _updatingAvailability = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseWorkerProfileRepository();
    _profileStream = _repository.watchProfile();
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  void _runOrOpen(VoidCallback? callback, Widget screen) {
    if (callback != null) {
      callback();
    } else {
      _open(screen);
    }
  }

  Future<void> _setAvailability(bool value) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(value ? 'Accept new jobs?' : 'Pause new jobs?'),
        content: Text(
          value
              ? 'SkillNova will mark your eligible profile as accepting new jobs. This is not a real-time online indicator.'
              : 'Your existing jobs are unchanged, but your profile will stop receiving new matching leads.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(value ? 'Accept jobs' : 'Pause'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _updatingAvailability = true);
    try {
      await _repository.setAcceptingJobs(value);
    } on WorkerProfileException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Accepting-jobs status could not be updated.');
    } finally {
      if (mounted) setState(() => _updatingAvailability = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out of SkillNova?'),
        content: const Text(
          'Your account data will remain safe. You will need to sign in again to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await _repository.signOut();
      if (!mounted) return;
      final callback = widget.onLoggedOut;
      if (callback != null) {
        setState(() => _loggingOut = false);
        callback();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
          (_) => false,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      _showMessage('Logout failed. Please try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Professional profile')),
      body: StreamBuilder<WorkerProfile>(
        stream: _profileStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _errorState();
          final profile = snapshot.data;
          if (profile == null) return _errorState();
          return _content(profile);
        },
      ),
      bottomNavigationBar: const WorkerBottomBar(selectedIndex: 4),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 52),
            const SizedBox(height: 12),
            const Text('Your worker profile could not be loaded.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  setState(() => _profileStream = _repository.watchProfile()),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(WorkerProfile profile) {
    return SafeArea(
      top: false,
      child: ListView(
        key: const PageStorageKey('canonical-worker-profile'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          WorkerProfileHeader(
            profile: profile,
            onEdit: () => _runOrOpen(
              widget.onEdit,
              WorkerEditProfileScreen(
                profile: profile,
                repository: _repository,
              ),
            ),
            onSettings: () => _runOrOpen(
              widget.onSettings,
              WorkerSettingsScreen(profile: profile, repository: _repository),
            ),
          ),
          const SizedBox(height: SkillNovaSpacing.md),
          WorkerReadinessCard(profile: profile),
          const SizedBox(height: SkillNovaSpacing.md),
          WorkerAvailabilityCard(
            profile: profile,
            updating: _updatingAvailability,
            onChanged: _setAvailability,
          ),
          const SizedBox(height: SkillNovaSpacing.md),
          WorkerProfileSummary(profile: profile),
          const SizedBox(height: 24),
          SettingsSection(
            title: 'Professional profile',
            children: [
              WorkerProfessionalSnapshot(profile: profile),
              const Divider(height: 1),
              ProfileMenuTile(
                icon: Icons.edit_outlined,
                title: 'Edit professional profile',
                subtitle:
                    'Photo, service, bio, experience, rate, and service area',
                onTap: () => _runOrOpen(
                  widget.onEdit,
                  WorkerEditProfileScreen(
                    profile: profile,
                    repository: _repository,
                  ),
                ),
              ),
              const Divider(height: 1),
              ProfileMenuTile(
                icon: Icons.visibility_outlined,
                title: 'Public profile preview',
                subtitle: profile.publiclyVisible
                    ? 'View the profile customers can currently open'
                    : 'Unavailable until your profile is eligible and accepting jobs',
                onTap: () {
                  if (!profile.publiclyVisible) {
                    _showMessage(
                      'Public preview is unavailable while the profile is ineligible or not accepting jobs.',
                    );
                    return;
                  }
                  _runOrOpen(
                    widget.onPublicProfile,
                    WorkerPublicProfileScreen(workerId: profile.identity.uid),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSection(
            title: 'Work & readiness',
            children: [
              ProfileMenuTile(
                icon: Icons.verified_user_outlined,
                title: 'Verification: ${profile.verificationLabel}',
                subtitle: profile.verificationAction,
                onTap: () => _runOrOpen(
                  widget.onVerification,
                  const WorkerVerificationCenterScreen(),
                ),
              ),
              const Divider(height: 1),
              ProfileMenuTile(
                icon: Icons.toll_outlined,
                title: 'Lead credits',
                subtitle:
                    '${profile.credits} available · required to accept a lead',
                onTap: () => _runOrOpen(widget.onCredits, const WallatScreen()),
              ),
              const Divider(height: 1),
              ProfileMenuTile(
                icon: Icons.star_outline_rounded,
                title: 'Reviews',
                subtitle:
                    '${profile.reviewCount} maintained reviews · ${profile.rating > 0 ? profile.rating.toStringAsFixed(1) : 'No rating yet'}',
                onTap: () =>
                    _runOrOpen(widget.onReviews, const ReviewsRatingsScreen()),
              ),
              const Divider(height: 1),
              ProfileMenuTile(
                icon: Icons.history_rounded,
                title: 'Completed jobs',
                subtitle: 'Open the completed group in canonical Worker Jobs',
                onTap: () => _runOrOpen(
                  widget.onCompletedJobs,
                  const WorkerJobsScreen(
                    initialGroup: WorkerJobGroup.completed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSection(
            title: 'Account',
            children: [
              ProfileMenuTile(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: profile.identity.email.isEmpty
                    ? 'Not linked in Firebase Authentication'
                    : '${profile.identity.email}${profile.identity.emailVerified ? ' · Verified' : ' · Not verified'}',
                onTap: () =>
                    _open(WorkerAccountInformationScreen(profile: profile)),
              ),
              const Divider(height: 1),
              ProfileMenuTile(
                icon: Icons.phone_outlined,
                title: 'Phone',
                subtitle: profile.identity.phoneVerified
                    ? '${profile.identity.phone} · Verified'
                    : 'Not linked in Firebase Authentication',
                onTap: () =>
                    _open(WorkerAccountInformationScreen(profile: profile)),
              ),
              const Divider(height: 1),
              ProfileMenuTile(
                icon: Icons.settings_outlined,
                title: 'Account & settings',
                subtitle:
                    'Identity, privacy, theme, notifications, and security',
                onTap: () => _runOrOpen(
                  widget.onSettings,
                  WorkerSettingsScreen(
                    profile: profile,
                    repository: _repository,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSection(
            title: 'Support & safety',
            children: [
              ProfileMenuTile(
                icon: Icons.support_agent_outlined,
                title: 'Help & Support',
                subtitle:
                    'Leads, verification, jobs, messages, reviews, and account help',
                onTap: () => _open(const WorkerHelpScreen()),
              ),
              const Divider(height: 1),
              ProfileMenuTile(
                icon: Icons.health_and_safety_outlined,
                title: 'Safety',
                subtitle:
                    'SOS, foreground location sharing, and emergency guidance',
                onTap: () => _open(
                  WorkerSafetyScreen(
                    onReport: () => _open(const WorkerHelpScreen()),
                  ),
                ),
              ),
              const Divider(height: 1),
              ProfileMenuTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy',
                subtitle: 'What customers can see and what stays private',
                onTap: () => _open(const WorkerPrivacyScreen()),
              ),
              const Divider(height: 1),
              ProfileMenuTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'The rules for using SkillNova',
                onTap: () => _open(
                  const LegalDocumentScreen(
                    title: 'Terms of Service',
                    url: SkillNovaSupportConfig.termsOfServiceUrl,
                  ),
                ),
              ),
              const Divider(height: 1),
              ProfileMenuTile(
                icon: Icons.info_outline_rounded,
                title: 'About SkillNova',
                subtitle: 'Product information and actual app version',
                onTap: () => showSkillNovaAboutDialog(
                  context,
                  helpBuilder: (_) => const WorkerHelpScreen(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const ValueKey('worker-profile-logout'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _loggingOut ? null : _confirmLogout,
            icon: _loggingOut
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            label: Text(_loggingOut ? 'Logging out…' : 'Log out'),
          ),
        ],
      ),
    );
  }
}
