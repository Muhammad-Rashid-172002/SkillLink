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
  static const Color _primaryDark = Color(0xFF087A38);
  static const Color _secondary = Color(0xFF14B8A6);
  static const Color _background = Color(0xFFF3F7F5);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF101827);
  static const Color _textSecondary = Color(0xFF667085);
  static const Color _border = Color(0xFFE5EBE8);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;

    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: const WorkerBottomBar(selectedIndex: 4),
      body: uid == null
          ? SafeArea(child: _authErrorState())
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState ==
                    ConnectionState.waiting) {
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
                    final completedJobs =
                        jobsSnapshot.data?.docs.length ?? 0;

                    return Stack(
                      children: [
                        Positioned(
                          top: -140,
                          right: -120,
                          child: _ambientCircle(
                            size: 330,
                            color: _primary.withOpacity(.10),
                          ),
                        ),
                        Positioned(
                          bottom: -180,
                          left: -150,
                          child: _ambientCircle(
                            size: 360,
                            color: _secondary.withOpacity(.07),
                          ),
                        ),
                        SafeArea(
                          bottom: false,
                          child: RefreshIndicator(
                            color: _primary,
                            onRefresh: () async {
                              await Future<void>.delayed(
                                const Duration(milliseconds: 500),
                              );
                            },
                            child: CustomScrollView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              slivers: [
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    12,
                                    18,
                                    110,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildListDelegate(
                                      [
                                        _topHeader(context),
                                        const SizedBox(height: 16),
                                        _profileHero(
                                          context: context,
                                          user: user,
                                          completedJobs: completedJobs,
                                          email:
                                              currentUser?.email ??
                                              (user['email'] ?? '')
                                                  .toString(),
                                        ),
                                        const SizedBox(height: 18),
                                        _availabilityCard(user),
                                        const SizedBox(height: 22),
                                        _sectionHeading(
                                          title: 'Performance',
                                          subtitle:
                                              'Track your professional growth',
                                        ),
                                        const SizedBox(height: 12),
                                        _performanceGrid(
                                          user: user,
                                          completedJobs: completedJobs,
                                        ),
                                        const SizedBox(height: 22),
                                        _sectionHeading(
                                          title: 'Work Management',
                                          subtitle:
                                              'Jobs, earnings and customer feedback',
                                        ),
                                        const SizedBox(height: 12),
                                        _menuGroup(
                                          children: [
                                            _menuTile(
                                              icon:
                                                  Icons.work_history_rounded,
                                              title: 'Completed Jobs',
                                              subtitle:
                                                  'Review your completed service history',
                                              iconBackground:
                                                  const Color(0xFFEAF8EF),
                                              iconColor: _primary,
                                              trailingText:
                                                  '$completedJobs',
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
                                                  'Manage credits and payment activity',
                                              iconBackground:
                                                  const Color(0xFFFFF7E8),
                                              iconColor: _warning,
                                              trailingText:
                                                  '${_toInt(user['credits'])} credits',
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
                                                  'Read customer feedback about your work',
                                              iconBackground:
                                                  const Color(0xFFFFF7E8),
                                              iconColor: _warning,
                                              trailingText:
                                                  _toDouble(user['rating'])
                                                      .toStringAsFixed(1),
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
                                        _sectionHeading(
                                          title: 'Professional Details',
                                          subtitle:
                                              'Information visible to customers',
                                        ),
                                        const SizedBox(height: 12),
                                        _professionalInfoCard(user),
                                        const SizedBox(height: 22),
                                        _sectionHeading(
                                          title: 'Account & Support',
                                          subtitle:
                                              'Security, assistance and legal information',
                                        ),
                                        const SizedBox(height: 12),
                                        _menuGroup(
                                          children: [
                                            _menuTile(
                                              icon: Icons
                                                  .support_agent_rounded,
                                              title: 'Help & Support',
                                              subtitle:
                                                  'Contact the SkillNova support team',
                                              iconBackground:
                                                  const Color(0xFFEFF6FF),
                                              iconColor: _blue,
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
                                              icon:
                                                  Icons.privacy_tip_rounded,
                                              title: 'Privacy Policy',
                                              subtitle:
                                                  'Review how your data is protected',
                                              iconBackground:
                                                  const Color(0xFFF3F4F6),
                                              iconColor:
                                                  const Color(0xFF475569),
                                              onTap: () =>
                                                  _openPrivacyPolicy(
                                                    context,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 22),
                                        _trustCard(user),
                                        const SizedBox(height: 20),
                                        _logoutButton(context),
                                        const SizedBox(height: 15),
                                        const Center(
                                          child: Text(
                                            'SkillNova Worker • Professional Services',
                                            style: TextStyle(
                                              color: Color(0xFF98A2B3),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _topHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _secondary],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(.20),
                blurRadius: 17,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Profile',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.45,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Manage your professional presence',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => _showMessage(
              context,
              'Connect your worker profile edit screen here.',
            ),
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 14,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: _primary,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileHero({
    required BuildContext context,
    required Map<String, dynamic> user,
    required int completedJobs,
    required String email,
  }) {
    final name = (user['name'] ?? 'Worker').toString().trim();
    final skill =
        (user['skill'] ?? 'Professional Service').toString().trim();
    final location =
        (user['location'] ?? user['city'] ?? 'Service area not added')
            .toString()
            .trim();
    final rating = _toDouble(user['rating']);
    final isOnline = user['isOnline'] == true;
    final isVerified =
        user['identityVerificationStatus'] == 'approved' ||
        user['isVerified'] == true;
    final imageUrl = _profileImageUrl(user);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withOpacity(.23),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF075E2C),
                    Color(0xFF0F8B42),
                    Color(0xFF16A34A),
                    Color(0xFF20BFA3),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -85,
            right: -60,
            child: Container(
              height: 210,
              width: 210,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -60,
            child: Container(
              height: 210,
              width: 210,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 96,
                          width: 96,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.24),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(.32),
                            ),
                          ),
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child:
                                            CircularProgressIndicator(
                                          color: _primary,
                                          strokeWidth: 2.2,
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) =>
                                        _profilePlaceholder(name),
                                  )
                                : _profilePlaceholder(name),
                          ),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 4,
                          child: Container(
                            height: 25,
                            width: 25,
                            decoration: BoxDecoration(
                              color:
                                  isOnline ? _primary : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                            ),
                          ),
                        ),
                        if (isVerified)
                          Positioned(
                            left: -2,
                            bottom: 4,
                            child: Container(
                              height: 29,
                              width: 29,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: _blue,
                                size: 24,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Worker' : name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                height: 1.08,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.45,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(.13),
                                ),
                              ),
                              child: Text(
                                skill,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: Color(0xDDFFFFFF),
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xDDFFFFFF),
                                      fontSize: 9.8,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(.14),
                    ),
                  ),
                  child: Row(
                    children: [
                      _heroMetric(
                        icon: Icons.star_rounded,
                        value: rating.toStringAsFixed(1),
                        label: 'Rating',
                      ),
                      _heroDivider(),
                      _heroMetric(
                        icon: Icons.work_outline_rounded,
                        value: '$completedJobs',
                        label: 'Jobs',
                      ),
                      _heroDivider(),
                      _heroMetric(
                        icon: Icons.workspace_premium_outlined,
                        value: isVerified ? 'Verified' : 'Active',
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.mail_outline_rounded,
                        color: Color(0xCCFFFFFF),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 9.7,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.13),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isOnline ? 'ONLINE' : 'OFFLINE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7.8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetric({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xCFFFFFFF),
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() {
    return Container(
      width: 1,
      height: 38,
      color: Colors.white.withOpacity(.18),
    );
  }

  Widget _availabilityCard(Map<String, dynamic> user) {
    final isOnline = user['isOnline'] == true;
    final canAcceptJobs = user['canAcceptJobs'] == true;
    final verificationStatus =
        user['identityVerificationStatus']?.toString() ??
        'not_submitted';

    final Color statusColor = isOnline && canAcceptJobs
        ? _primary
        : _warning;

    final String title = isOnline && canAcceptJobs
        ? 'You are available for new jobs'
        : 'Your job availability is limited';

    final String subtitle = verificationStatus == 'pending'
        ? 'Identity verification is currently under review.'
        : verificationStatus == 'rejected'
            ? 'Verification was rejected. Submit your documents again.'
            : !canAcceptJobs
                ? 'Complete verification to start accepting customer jobs.'
                : 'Go online to receive nearby customer requests.';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              isOnline && canAcceptJobs
                  ? Icons.bolt_rounded
                  : Icons.info_outline_rounded,
              color: statusColor,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 9.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(.09),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isOnline ? 'ONLINE' : 'OFFLINE',
              style: TextStyle(
                color: statusColor,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading({
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 31,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_primary, _secondary],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _performanceGrid({
    required Map<String, dynamic> user,
    required int completedJobs,
  }) {
    final rating = _toDouble(user['rating']);
    final reviews = _toInt(user['totalReviews']);
    final credits = _toInt(user['credits']);

    return Row(
      children: [
        Expanded(
          child: _performanceCard(
            icon: Icons.work_outline_rounded,
            title: 'Jobs',
            value: '$completedJobs',
            caption: 'Completed',
            iconColor: _primary,
            iconBackground: const Color(0xFFEAF8EF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _performanceCard(
            icon: Icons.star_rounded,
            title: 'Rating',
            value: rating.toStringAsFixed(1),
            caption: '$reviews reviews',
            iconColor: _warning,
            iconBackground: const Color(0xFFFFF7E8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _performanceCard(
            icon: Icons.toll_rounded,
            title: 'Credits',
            value: '$credits',
            caption: 'Available',
            iconColor: _blue,
            iconBackground: const Color(0xFFEFF6FF),
          ),
        ),
      ],
    );
  }

  Widget _performanceCard({
    required IconData icon,
    required String title,
    required String value,
    required String caption,
    required Color iconColor,
    required Color iconBackground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 37,
            width: 37,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 7.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _professionalInfoCard(Map<String, dynamic> user) {
    final experience =
        (user['experience'] ?? 'Not added').toString().trim();
    final hourlyRate =
        (user['hourlyRate'] ?? 'Not added').toString().trim();
    final location =
        (user['location'] ?? user['city'] ?? 'Not added')
            .toString()
            .trim();
    final bio = (user['bio'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _infoItem(
                  icon: Icons.work_outline_rounded,
                  label: 'EXPERIENCE',
                  value: experience,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoItem(
                  icon: Icons.payments_outlined,
                  label: 'HOURLY RATE',
                  value: hourlyRate.toLowerCase().contains('rs')
                      ? hourlyRate
                      : 'Rs. $hourlyRate',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoItem(
            icon: Icons.location_on_outlined,
            label: 'SERVICE AREA',
            value: location,
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFF0FDF4),
                    Color(0xFFF8FAFC),
                  ],
                ),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: const Color(0xFFDCFCE7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: _primary,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'ABOUT ME',
                        style: TextStyle(
                          color: _primaryDark,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    style: const TextStyle(
                      color: Color(0xFF475467),
                      fontSize: 10.3,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: _primary.withOpacity(.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _primary, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 7.7,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 10.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuGroup({required List<Widget> children}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
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
    String? trailingText,
  }) {
    return Material(
      color: _surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 13, 14),
          child: Row(
            children: [
              Container(
                height: 47,
                width: 47,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trailingText,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF98A2B3),
                size: 13,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 72),
      child: Divider(
        height: 1,
        thickness: 1,
        color: _border,
      ),
    );
  }

  Widget _trustCard(Map<String, dynamic> user) {
    final verificationStatus =
        user['identityVerificationStatus']?.toString() ??
        'not_submitted';
    final approved = verificationStatus == 'approved';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: approved
              ? const [
                  Color(0xFFEAF8EF),
                  Color(0xFFF7FCF9),
                ]
              : const [
                  Color(0xFFFFF7E8),
                  Color(0xFFFFFCF5),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: approved
              ? const Color(0xFFBBE8C9)
              : const Color(0xFFFDE4A9),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: approved
                  ? _primary.withOpacity(.11)
                  : _warning.withOpacity(.11),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              approved
                  ? Icons.verified_user_rounded
                  : Icons.shield_outlined,
              color: approved ? _primary : _warning,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  approved
                      ? 'Identity Verified'
                      : 'Build More Customer Trust',
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  approved
                      ? 'Your professional identity has been reviewed and approved.'
                      : 'Complete identity verification to unlock job acceptance.',
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 9.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            approved
                ? Icons.check_circle_rounded
                : Icons.arrow_forward_ios_rounded,
            color: approved ? _primary : _warning,
            size: approved ? 23 : 14,
          ),
        ],
      ),
    );
  }

  Widget _logoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        onPressed: () => _showLogoutDialog(context),
        icon: const Icon(
          Icons.logout_rounded,
          color: _danger,
          size: 19,
        ),
        label: const Text(
          'Logout from Worker Account',
          style: TextStyle(
            color: _danger,
            fontSize: 12.5,
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
            borderRadius: BorderRadius.circular(25),
          ),
          icon: Container(
            height: 62,
            width: 62,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE4E6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: _danger,
              size: 29,
            ),
          ),
          title: const Text(
            'Logout from SkillNova?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'You will need to sign in again to access jobs, wallet and worker tools.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: _textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
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

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
        ),
        (route) => false,
      );
    } catch (_) {
      if (!context.mounted) return;

      _showMessage(
        context,
        'Unable to logout. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse(
      'https://skillnova-privacy-center.vercel.app/',
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        _showMessage(
          context,
          'Could not open Privacy Policy.',
          isError: true,
        );
      }
    } catch (_) {
      if (!context.mounted) return;

      _showMessage(
        context,
        'Could not open Privacy Policy.',
        isError: true,
      );
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

  String _profileImageUrl(Map<String, dynamic> user) {
    final candidates = [
      user['profileImageUrl'],
      user['profileImage'],
      user['imageUrl'],
      user['photoUrl'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  Widget _profilePlaceholder(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    final initials = parts.isEmpty
        ? 'WK'
        : parts.length == 1
            ? parts.first.substring(0, 1).toUpperCase()
            : '${parts.first.substring(0, 1)}'
                  '${parts.last.substring(0, 1)}'
                .toUpperCase();

    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFEAF8EF),
            Color(0xFFD9F6E2),
          ],
        ),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: _primaryDark,
          fontSize: 25,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _loadingState() {
    return const Scaffold(
      backgroundColor: _background,
      body: Center(
        child: CircularProgressIndicator(
          color: _primary,
          strokeWidth: 2.6,
        ),
      ),
    );
  }

  Widget _errorState({required String message}) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFFECACA),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: _danger,
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
        ),
      ),
    );
  }

  Widget _authErrorState() {
    return _errorState(
      message: 'No signed-in worker account was found.',
    );
  }

  Widget _ambientCircle({
    required double size,
    required Color color,
  }) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
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
