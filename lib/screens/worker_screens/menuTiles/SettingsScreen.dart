import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  bool notificationEnabled = true;
  bool darkMode = false;

  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          "Settings",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),

        child: Column(
          children: [

            /// PROFILE CARD

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),

              child: Column(
                children: [

                  const CircleAvatar(
                    radius: 42,
                    backgroundColor: Color(0xff2563EB),
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Text(
                    user?.displayName ?? "Worker",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    user?.email ?? "",
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Account",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),

            const SizedBox(height: 15),

            _menuTile(
              Icons.person_outline,
              "Edit Profile",
              () {},
            ),

            _menuTile(
              Icons.lock_outline,
              "Change Password",
              () {},
            ),

            _menuTile(
              Icons.phone_outlined,
              "Change Phone",
              () {},
            ),

            _menuTile(
              Icons.email_outlined,
              "Change Email",
              () {},
            ),
            // Is code ko _menuTile() ke niche add karo

const SizedBox(height: 25),

const Align(
  alignment: Alignment.centerLeft,
  child: Text(
    "General",
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  ),
),

const SizedBox(height: 15),

_menuTile(
  Icons.language_rounded,
  "Language",
  () {
    _showLanguageDialog();
  },
),

_menuTile(
  Icons.location_on_outlined,
  "Location Permission",
  () {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Location permission screen coming soon."),
      ),
    );
  },
),

_menuTile(
  Icons.privacy_tip_outlined,
  "Privacy Policy",
  () {
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => const PrivacyPolicyScreen(),
    //   ),
    // );
  },
),

_menuTile(
  Icons.description_outlined,
  "Terms & Conditions",
  () {
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => const TermsScreen(),
    //   ),
    // );
  },
),

const SizedBox(height: 25),

const Align(
  alignment: Alignment.centerLeft,
  child: Text(
    "Support",
    style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 18,
    ),
  ),
),

const SizedBox(height: 15),

_menuTile(
  Icons.help_center_outlined,
  "Help Center",
  () {
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => const HelpCenterScreen(),
    //   ),
    // );
  },
),

_menuTile(
  Icons.support_agent,
  "Contact Support",
  () {
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => const ContactSupportScreen(),
    //   ),
    // );
  },
),

_menuTile(
  Icons.bug_report_outlined,
  "Report Bug",
  () {
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => const ReportBugScreen(),
    //   ),
    // );
  },
),

const SizedBox(height: 30),

SizedBox(
  width: double.infinity,
  height: 55,
  child: ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    icon: const Icon(
      Icons.logout,
      color: Colors.white,
    ),
    label: const Text(
      "Logout",
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
    onPressed: _logoutDialog,
  ),
),

            const SizedBox(height: 25),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Preferences",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),

            const SizedBox(height: 15),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),

              child: SwitchListTile(
                value: notificationEnabled,
                activeColor: Colors.green,
                title: const Text(
                  "Notifications",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                secondary: const Icon(
                  Icons.notifications_active,
                  color: Colors.green,
                ),
                onChanged: (value) {
                  setState(() {
                    notificationEnabled = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),

              child: SwitchListTile(
                value: darkMode,
                activeColor: Colors.green,
                title: const Text(
                  "Dark Mode",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                secondary: const Icon(
                  Icons.dark_mode,
                  color: Colors.indigo,
                ),
                onChanged: (value) {
                  setState(() {
                    darkMode = value;
                  });
                },
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _menuTile(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),

      child: ListTile(
        onTap: onTap,

        leading: Icon(
          icon,
          color: Colors.green,
        ),

        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
        ),
      ),
    );
  }
  void _showLanguageDialog() {
  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: const Text("Choose Language"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("English"),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text("Urdu"),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    },
  );
}

void _logoutDialog() {
  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text("Logout"),
        content: const Text(
          "Are you sure you want to logout?",
        ),
        actions: [

          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(context);

              await FirebaseAuth.instance.signOut();

              if (!mounted) return;

              Navigator.pushNamedAndRemoveUntil(
                context,
                "/login",
                (route) => false,
              );
            },
            child: const Text(
              "Logout",
              style: TextStyle(color: Colors.white),
            ),
          ),

        ],
      );
    },
  );
}
}