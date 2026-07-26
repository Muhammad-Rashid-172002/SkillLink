import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skill_link/screens/Role_selection_screen/role_selection.dart';
import 'package:skill_link/screens/customer_screens/bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/customer_screens/muneTile/My_request.dart';
import 'package:skill_link/screens/customer_screens/muneTile/edit_profile.dart';
import 'package:skill_link/screens/customer_screens/muneTile/help_and_support.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF16A34A);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFDC2626);

  bool _isLoggingOut = false;
  bool _notificationsEnabled = true;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedValue = prefs.getBool('notifications_enabled') ?? true;

      if (!mounted) return;

      setState(() {
        _notificationsEnabled = savedValue;
      });
    } catch (e) {
      debugPrint('SharedPreferences load error: $e');
    }
  }

  Future<bool> _saveNotificationSetting(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final saved = await prefs.setBool('notifications_enabled', value);

      if (!saved) return false;
      if (!mounted) return false;

      setState(() {
        _notificationsEnabled = value;
      });

      return true;
    } catch (e) {
      debugPrint('Notification setting save error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    if (uid == null) {
      return _signedOutView();
    }

    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: const CustomerBottomBar(selectedIndex: 4),
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: _ambientCircle(size: 330, color: _primary.withOpacity(0.09)),
          ),
          Positioned(
            bottom: -170,
            left: -140,
            child: _ambientCircle(
              size: 350,
              color: _secondary.withOpacity(0.06),
            ),
          ),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _loadingScreen();
                }

                if (snapshot.hasError) {
                  return _errorScreen(snapshot.error.toString());
                }

                if (!snapshot.hasData ||
                    !snapshot.data!.exists ||
                    snapshot.data!.data() == null) {
                  return _errorScreen('Profile data was not found.');
                }

                final user = snapshot.data!.data()!;

                return RefreshIndicator(
                  color: _primary,
                  onRefresh: () async {
                    await Future<void>.delayed(
                      const Duration(milliseconds: 500),
                    );
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 38),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _header(),
                            const SizedBox(height: 20),
                            _profileHero(user),
                            const SizedBox(height: 18),
                            _accountStats(user),
                            const SizedBox(height: 20),
                            _sectionTitle(
                              title: 'Account',
                              subtitle: 'Manage your personal information',
                            ),
                            const SizedBox(height: 12),
                            _accountMenu(),
                            const SizedBox(height: 20),
                            _sectionTitle(
                              title: 'Preferences',
                              subtitle: 'Control notifications',
                            ),
                            const SizedBox(height: 12),
                            _preferencesMenu(),
                            const SizedBox(height: 20),
                            _sectionTitle(
                              title: 'Support & legal',
                              subtitle: 'Get help and review app policies',
                            ),
                            const SizedBox(height: 12),
                            _supportMenu(),
                            const SizedBox(height: 20),
                            _logoutButton(),
                            const SizedBox(height: 10),
                            const Center(
                              child: Text(
                                'SkillLink Customer Account',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 9,
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
            ),
          ),
          if (_isLoggingOut) Positioned.fill(child: _logoutOverlay()),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          height: 50,
          width: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_primary, _secondary]),
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My profile',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.45,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage your account and preferences',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () {
              _showMessage('Edit profile screen can be connected here.');
            },
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x070F172A),
                    blurRadius: 14,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerEditProfileScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.edit_outlined,
                  color: _primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileHero(Map<String, dynamic> user) {
    final name = _fallback(user['name'], 'Customer');
    final phone = _fallback(user['phone'], 'Phone unavailable');
    final city = _fallback(user['city'], 'City unavailable');
    final area = _fallback(user['area'], '');
    final email =
        FirebaseAuth.instance.currentUser?.email ??
        _fallback(user['email'], 'Email unavailable');
    final profileImage =
        user['profileImage']?.toString() ??
        user['profileImageUrl']?.toString() ??
        user['imageUrl']?.toString() ??
        '';
    final verified = user['isVerified'] == true || user['verified'] == true;

    final location = area.isEmpty ? city : '$area, $city';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(29),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.24),
            blurRadius: 28,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -55,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -95,
            left: -55,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 96,
                    width: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: profileImage.trim().isEmpty
                        ? _initialsAvatar(name)
                        : Image.network(
                            profileImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return _initialsAvatar(name);
                            },
                          ),
                  ),
                  Positioned(
                    right: -3,
                    bottom: 3,
                    child: Container(
                      height: 26,
                      width: 26,
                      decoration: BoxDecoration(
                        color: verified ? _success : _warning,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Icon(
                        verified ? Icons.check_rounded : Icons.person_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'CUSTOMER ACCOUNT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: 17),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.16)),
                ),
                child: Column(
                  children: [
                    _heroInfoRow(icon: Icons.phone_outlined, text: phone),
                    const SizedBox(height: 10),
                    _heroDivider(),
                    const SizedBox(height: 10),
                    _heroInfoRow(icon: Icons.email_outlined, text: email),
                    const SizedBox(height: 10),
                    _heroDivider(),
                    const SizedBox(height: 10),
                    _heroInfoRow(
                      icon: Icons.location_on_outlined,
                      text: location,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initialsAvatar(String name) {
    return Center(
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _heroInfoRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroDivider() {
    return Container(height: 1, color: Colors.white.withOpacity(0.12));
  }

  Widget _accountStats(Map<String, dynamic> user) {
    final customerId = FirebaseAuth.instance.currentUser!.uid;

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection("requests")
          .where("customerId", isEqualTo: customerId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        final totalRequests = docs.length;

        int completedRequests = 0;

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;

          if (data["status"] == "completed") {
            completedRequests++;
          }
        }

        final saved = _intValue(user["savedWorkersCount"]);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Expanded(
                child: _statItem(
                  icon: Icons.assignment_outlined,
                  value: "$totalRequests",
                  label: "Requests",
                  color: _primary,
                ),
              ),

              _statDivider(),

              Expanded(
                child: _statItem(
                  icon: Icons.task_alt_rounded,
                  value: "$completedRequests",
                  label: "Completed",
                  color: _success,
                ),
              ),

              _statDivider(),

              Expanded(
                child: _statItem(
                  icon: Icons.favorite_outline_rounded,
                  value: "$saved",
                  label: "Saved",
                  color: _danger,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 47, color: _border);
  }

  Widget _sectionTitle({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 9.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _accountMenu() {
    return _menuContainer(
      children: [
        _profileTile(
          icon: Icons.edit_note_rounded,
          title: 'Edit profile',
          subtitle: 'Update name, phone and address',
          color: _primary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CustomerEditProfileScreen(),
              ),
            );
          },
        ),
        _divider(),
        _profileTile(
          icon: Icons.assignment_outlined,
          title: 'My requests',
          subtitle: 'Track your posted service requests',
          color: const Color(0xFF8B5CF6),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyRequestsScreen()),
            );
          },
        ),
        _divider(),
        // _profileTile(
        //   icon: Icons.favorite_outline_rounded,
        //   title: 'Saved workers',
        //   subtitle: 'View professionals you saved',
        //   color: _danger,
        //   onTap: () {
        //     _showMessage('Saved Workers screen can be connected here.');
        //   },
        // ),
      ],
    );
  }

  Widget _preferencesMenu() {
    return _menuContainer(
      children: [
        _profileTile(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          subtitle: 'Manage alerts and activity updates',
          color: _warning,
          badge: _notificationsEnabled ? 'On' : 'Off',
          onTap: () {
            _showNotificationSettingsDialog(context);
          },
        ),
        _divider(),
        // _profileTile(
        //   icon: Icons.settings_outlined,
        //   title: 'Settings',
        //   subtitle: 'App, security and account preferences',
        //   color: _textSecondary,
        //   onTap: () {
        //     _showMessage('Settings screen can be connected here.');
        //   },
        // ),
      ],
    );
  }

  Widget _supportMenu() {
    return _menuContainer(
      children: [
        _profileTile(
          icon: Icons.support_agent_outlined,
          title: 'Help & support',
          subtitle: 'Get assistance from SkillLink support',
          color: _success,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
            );
          },
        ),
        _divider(),
        _profileTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'Review how your data is handled',
          color: _primary,
          onTap: _openPrivacyPolicy,
        ),
        _divider(),
        _profileTile(
          icon: Icons.info_outline_rounded,
          title: 'About SkillLink',
          subtitle: 'Version, company and app information',
          color: _secondary,
          badge: 'v1.0',
          onTap: () {
            _showAboutDialog(context);
          },
        ),
      ],
    );
  }

  void _showNotificationSettingsDialog(BuildContext context) {
    bool notificationsEnabled = _notificationsEnabled;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 74,
                      width: 74,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: notificationsEnabled
                              ? const [Color(0xFFF59E0B), Color(0xFFF97316)]
                              : const [Color(0xFF94A3B8), Color(0xFF64748B)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        notificationsEnabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Notifications',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      notificationsEnabled
                          ? 'Notifications are currently enabled.'
                          : 'Notifications are currently disabled.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 22),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Allow Notifications',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Receive job, message and account updates.',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 9.5,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Switch.adaptive(
                            value: notificationsEnabled,
                            activeColor: const Color(0xFFF59E0B),
                            onChanged: (value) {
                              dialogSetState(() {
                                notificationsEnabled = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            child: const Text('Cancel'),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final saved = await _saveNotificationSetting(
                                notificationsEnabled,
                              );

                              if (!dialogContext.mounted) return;

                              Navigator.pop(dialogContext);

                              if (saved) {
                                _showMessage(
                                  notificationsEnabled
                                      ? 'Notifications enabled.'
                                      : 'Notifications disabled.',
                                );
                              } else {
                                _showMessage(
                                  'Notification setting save nahi hui.',
                                  isError: true,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 90,
                  width: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.handyman_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "SkillLink",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),

                const SizedBox(height: 6),

                const Text(
                  "Connecting Customers with Skilled Workers",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                _aboutRow(
                  Icons.verified_outlined,
                  "Version",
                  "1.0.0",
                  const Color(0xFF2563EB),
                ),

                _divider(),

                _aboutRow(
                  Icons.business_outlined,
                  "Company",
                  "Rashid Apps",
                  const Color(0xFF16A34A),
                ),

                _divider(),

                _aboutRow(
                  Icons.person_outline,
                  "Developer",
                  "Muhammad Rashid",
                  const Color(0xFFF59E0B),
                ),

                _divider(),

                _aboutRow(
                  Icons.code_rounded,
                  "Framework",
                  "Flutter + Firebase",
                  const Color(0xFF7C3AED),
                ),

                _divider(),

                _aboutRow(
                  Icons.update_outlined,
                  "Build",
                  "Production",
                  const Color(0xFF0891B2),
                ),

                const SizedBox(height: 22),

                const Text(
                  "© 2026 Rashid Apps\nAll Rights Reserved.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final Uri uri = Uri.parse("https://skilllinkprivacypolicy.vercel.app");

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showMessage("Could not open Privacy Policy.");
    }
  }

  Widget _aboutRow(IconData icon, String title, String value, Color color) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menuContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 15,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _profileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 21),
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
                        fontSize: 11.7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 9.1,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: color,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
              ],
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.only(left: 72),
      child: Divider(height: 1, color: _border),
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _isLoggingOut ? null : _confirmLogout,
        style: OutlinedButton.styleFrom(
          foregroundColor: _danger,
          side: BorderSide(color: _danger.withOpacity(0.35)),
          backgroundColor: _danger.withOpacity(0.045),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text(
          'Logout from account',
          style: TextStyle(fontSize: 11.8, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: _danger.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: _danger,
                  size: 30,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Logout from SkillLink?',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'You will need to sign in again to access your customer account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage('Logout failed. ${error.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  Widget _loadingScreen() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      child: Column(
        children: [
          _header(),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _border),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: _primary,
                      strokeWidth: 2.6,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Loading your profile...',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorScreen(String error) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      child: Column(
        children: [
          _header(),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 62,
                      width: 62,
                      decoration: BoxDecoration(
                        color: _danger.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.person_off_rounded,
                        color: _danger,
                        size: 31,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Unable to load profile',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Please check your internet connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      error,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _danger,
                        fontSize: 8.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signedOutView() {
    return const Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Please sign in again to view your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoutOverlay() {
    return ColoredBox(
      color: _textPrimary.withOpacity(0.28),
      child: Center(
        child: Container(
          width: 235,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(23),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220F172A),
                blurRadius: 30,
                offset: Offset(0, 15),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _danger, strokeWidth: 2.7),
              SizedBox(height: 16),
              Text(
                'Logging out',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Please wait while we securely end your session.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.2,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fallback(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return fallback;
    }

    return text;
  }

  int _intValue(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'CU';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  void _showMessage(String message, {bool isError = false}) {
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

  Widget _ambientCircle({required double size, required Color color}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
