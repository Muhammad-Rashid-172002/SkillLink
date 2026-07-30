import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/onboarding_screen/OnboardingScreen.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/worker_screens/menuTiles/CompletedJobsScreen.dart';
import 'package:skill_link/screens/worker_screens/menuTiles/ReviewsScreen.dart';
import 'package:skill_link/screens/worker_screens/menuTiles/Wallet_screen.dart';
import 'package:skill_link/screens/worker_screens/menuTiles/help_support_screen_modern.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerProfileScreen extends StatelessWidget {
  const WorkerProfileScreen({super.key});

  static const Color _primary = Color(0xFF16A34A);
  static const Color _primaryDark = Color(0xFF0F7A38);
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE7ECF3);
  static const Color _danger = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;

    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: const WorkerBottomBar(selectedIndex: 4),
      body: SafeArea(
        bottom: false,
        child: uid == null
            ? _authErrorState(context)
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return _loadingState();
                  }

                  if (userSnapshot.hasError) {
                    return _errorState(
                      message: 'Unable to load your worker profile.',
                    );
                  }

                  final user = userSnapshot.data?.data();

                  if (user == null) {
                    return _errorState(
                      message: 'Worker profile data was not found.',
                    );
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('requests')
                        .where('workerId', isEqualTo: uid)
                        .where('status', isEqualTo: 'completed')
                        .snapshots(),
                    builder: (context, jobsSnapshot) {
                      final completedJobs = jobsSnapshot.data?.docs.length ?? 0;

                      return RefreshIndicator(
                        color: _primary,
                        onRefresh: () async {
                          await Future<void>.delayed(
                            const Duration(milliseconds: 450),
                          );
                        },
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                30,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  _header(context),
                                  const SizedBox(height: 20),
                                  _profileHeroCard(
                                    context: context,
                                    user: user,
                                    completedJobs: completedJobs,
                                    email:
                                        currentUser?.email ??
                                        (user['email'] ?? '').toString(),
                                  ),
                                  const SizedBox(height: 24),
                                  _sectionLabel(title: 'WORK & PERFORMANCE'),
                                  const SizedBox(height: 10),
                                  _menuGroup(
                                    children: [
                                      _menuTile(
                                        icon: Icons.work_history_rounded,
                                        title: 'Completed Jobs',
                                        subtitle:
                                            'View your completed service history',
                                        iconBackground: const Color(0xFFEAF8EF),
                                        iconColor: _primary,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const CompletedJobsScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      _groupDivider(),
                                      _menuTile(
                                        icon: Icons
                                            .account_balance_wallet_rounded,
                                        title: 'Wallet & Earnings',
                                        subtitle:
                                            'Manage credits, earnings and activity',
                                        iconBackground: const Color(0xFFFFF7E8),
                                        iconColor: const Color(0xFFF59E0B),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const WalletScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      _groupDivider(),
                                      _menuTile(
                                        icon: Icons.star_rounded,
                                        title: 'Reviews & Ratings',
                                        subtitle:
                                            'Check customer feedback and ratings',
                                        iconBackground: const Color(0xFFFFF7E8),
                                        iconColor: const Color(0xFFF59E0B),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const ReviewsRatingsScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  _sectionLabel(title: 'ACCOUNT & SUPPORT'),
                                  const SizedBox(height: 10),
                                  _menuGroup(
                                    children: [
                                      _groupDivider(),
                                      _menuTile(
                                        icon: Icons.support_agent_rounded,
                                        title: 'Help & Support',
                                        subtitle:
                                            'Get assistance from SkillNova support',
                                        iconBackground: const Color(0xFFEFF6FF),
                                        iconColor: const Color(0xFF2563EB),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const HelpSupportScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      _groupDivider(),
                                      _menuTile(
                                        icon: Icons.privacy_tip_rounded,
                                        title: 'Privacy Policy',
                                        subtitle:
                                            'Review how your data is protected',
                                        iconBackground: const Color(0xFFF3F4F6),
                                        iconColor: const Color(0xFF475569),
                                        onTap: () =>
                                            _openPrivacyPolicy(context),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  _logoutButton(context),
                                  const SizedBox(height: 14),
                                  const Center(
                                    child: Text(
                                      'SkillNova Worker App',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final Uri uri = Uri.parse('https://skillnova-privacy-center.vercel.app/');

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && context.mounted) {
        _showMessage(context, 'Could not open Privacy Policy.', isError: true);
      }
    } catch (e) {
      debugPrint('Privacy Policy error: $e');

      if (!context.mounted) return;

      _showMessage(context, 'Could not open Privacy Policy.', isError: true);
    }
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          backgroundColor: isError ? _danger : _textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Worker Profile',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Manage your professional identity',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileHeroCard({
    required BuildContext context,
    required Map<String, dynamic> user,
    required int completedJobs,
    required String email,
  }) {
    final name = (user['name'] ?? 'Worker').toString();
    final skill = (user['skill'] ?? 'Skilled Worker').toString();
    final rating = _toDouble(user['rating']);
    final totalReviews = _toInt(user['totalReviews']);
    final isVerified = user['isVerified'] == true;
    final imageUrl =
        (user['profileImage'] ??
                user['profileImageUrl'] ??
                user['imageUrl'] ??
                '')
            .toString();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryDark, _primary, Color(0xFF3DD56E)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -50,
                  top: -70,
                  child: Container(
                    height: 170,
                    width: 170,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 35,
                  bottom: -75,
                  child: Container(
                    height: 125,
                    width: 125,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 86,
                              width: 86,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return _profilePlaceholder();
                                            },
                                      )
                                    : _profilePlaceholder(),
                              ),
                            ),
                            if (isVerified)
                              Positioned(
                                right: -1,
                                bottom: 2,
                                child: Container(
                                  height: 25,
                                  width: 25,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFF2563EB),
                                    size: 21,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 21,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    skill,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (email.isNotEmpty) ...[
                                  const SizedBox(height: 9),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.mail_outline_rounded,
                                        color: Color(0xD9FFFFFF),
                                        size: 15,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xD9FFFFFF),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 21),
                    Row(
                      children: [
                        Expanded(
                          child: _quickStatusChip(
                            icon: Icons.verified_user_outlined,
                            label: isVerified
                                ? 'Verified profile'
                                : 'Profile active',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _quickStatusChip(
                            icon: Icons.circle,
                            label: 'Available for work',
                            iconSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 17),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.work_outline_rounded,
                    title: 'Jobs',
                    value: '$completedJobs',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.star_rounded,
                    title: 'Rating',
                    value: rating.toStringAsFixed(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.rate_review_outlined,
                    title: 'Reviews',
                    value: '$totalReviews',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profilePlaceholder() {
    return const ColoredBox(
      color: Color(0xFFEAF8EF),
      child: Icon(Icons.person_rounded, color: _primary, size: 47),
    );
  }

  Widget _quickStatusChip({
    required IconData icon,
    required String label,
    double iconSize = 16,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: iconSize),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel({required String title}) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.15,
      ),
    );
  }

  Widget _menuGroup({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBackground,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 31,
                width: 31,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF94A3B8),
                  size: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 74),
      child: Divider(height: 1, thickness: 1, color: _border),
    );
  }

  Widget _logoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () => _showLogoutDialog(context),
        icon: const Icon(
          Icons.logout_rounded,
          color: Color(0xFFDC2626),
          size: 20,
        ),
        label: const Text(
          'Logout',
          style: TextStyle(
            color: Color(0xFFDC2626),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF7F7),
          side: const BorderSide(color: Color(0xFFFECACA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
          contentPadding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: const Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFFFE4E6),
                child: Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Logout?',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout from your SkillNova worker account?',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: _textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OnboardingScreen(),
                ),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to logout. Please try again.')),
      );
    }
  }

  Widget _loadingState() {
    return const Center(
      child: CircularProgressIndicator(color: _primary, strokeWidth: 2.6),
    );
  }

  Widget _errorState({required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7F7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDC2626),
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _authErrorState(BuildContext context) {
    return _errorState(message: 'No signed-in worker account was found.');
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  static const Color _primary = Color(0xFF16A34A);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE7ECF3);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(icon, color: _primary, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 19,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
