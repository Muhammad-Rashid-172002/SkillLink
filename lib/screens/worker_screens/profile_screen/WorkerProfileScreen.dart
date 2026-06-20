import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';

class WorkerProfileScreen extends StatelessWidget {
  const WorkerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: const WorkerBottomBar(selectedIndex: 4),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = userSnapshot.data!.data() as Map<String, dynamic>;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Worker Profile",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 24),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("requests")
                        .where("workerId", isEqualTo: uid)
                        .where("status", isEqualTo: "completed")
                        .snapshots(),
                    builder: (context, jobsSnapshot) {
                      final completedJobs = jobsSnapshot.data?.docs.length ?? 0;

                      return _profileCard(
                        user: user,
                        completedJobs: completedJobs,
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  _menuTile(Icons.work_rounded, "Completed Jobs"),
                  _menuTile(Icons.account_balance_wallet_rounded, "Wallet & Earnings"),
                  _menuTile(Icons.star_rounded, "Reviews & Ratings"),
                  _menuTile(Icons.settings_rounded, "Settings"),
                  _menuTile(Icons.support_agent_rounded, "Help & Support"),
                  _menuTile(Icons.privacy_tip_rounded, "Privacy Policy"),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        "Logout",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _profileCard({
    required Map<String, dynamic> user,
    required int completedJobs,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFFE2E8F0),
            child: Icon(Icons.person, size: 55, color: Color(0xFF16A34A)),
          ),
          const SizedBox(height: 16),

          Text(
            user["name"] ?? "Worker",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 6),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user["skill"] ?? "Worker",
              style: const TextStyle(
                color: Color(0xFF16A34A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatCard(title: "Jobs", value: "$completedJobs"),
              _StatCard(title: "Rating", value: "${user["rating"] ?? 0}"),
              _StatCard(title: "Reviews", value: "${user["totalReviews"] ?? 0}"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _menuTile(IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF16A34A)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF16A34A),
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}