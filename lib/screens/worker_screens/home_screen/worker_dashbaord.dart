import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: const WorkerBottomBar(selectedIndex: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topHeader(),
              const SizedBox(height: 24),
              _earningCard(),
              const SizedBox(height: 24),
              _statsRow(),
              const SizedBox(height: 28),
              _sectionHeader("New Job Requests", "View all"),
              const SizedBox(height: 16),
              _requestList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topHeader() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final name = data?["name"] ?? "Worker";

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hello, $name 👋",
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Manage your jobs",
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        );
      },
    );
  }

  Widget _earningCard() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("requests")
          .where("workerId", isEqualTo: uid)
          .where("status", isEqualTo: "completed")
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        int totalEarnings = 0;

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final budgetText = data["budget"]?.toString() ?? "0";
          final amount =
              int.tryParse(budgetText.replaceAll(RegExp(r'[^0-9]'), "")) ?? 0;
          totalEarnings += amount;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Total Earnings",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Rs. $totalEarnings",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${docs.length} jobs completed",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 62,
                width: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statsRow() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Row(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("requests")
                .where("status", isEqualTo: "searching")
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;

              return _statCard(
                title: "Pending",
                value: "$count",
                icon: Icons.pending_actions_rounded,
                color: const Color(0xFFF59E0B),
              );
            },
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("requests")
                .where("workerId", isEqualTo: uid)
                .where(
                  "status",
                  whereIn: ["accepted", "on_the_way", "in_progress"],
                )
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;

              return _statCard(
                title: "Active Jobs",
                value: "$count",
                icon: Icons.work_history_rounded,
                color: const Color(0xFF2563EB),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String action) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          action,
          style: const TextStyle(
            color: Color(0xFF16A34A),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _requestList() {
    final workerId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(workerId)
          .snapshots(),
      builder: (context, workerSnapshot) {
        if (!workerSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF16A34A)),
          );
        }

        final workerData = workerSnapshot.data!.data() as Map<String, dynamic>;

        final workerSkill = workerData["skill"] ?? "";

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("requests")
              .where("status", isEqualTo: "searching")
              .where("category", isEqualTo: workerSkill)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF16A34A)),
              );
            }

            if (snapshot.data!.docs.isEmpty) {
              return _emptyJobs();
            }

            final docs = snapshot.data!.docs;

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                return _jobCard(
                  requestId: doc.id,
                  title: data["title"] ?? "",
                  category: data["category"] ?? "",
                  location: data["location"] ?? "",
                  budget: data["budget"] ?? "",
                  urgency: data["urgency"] ?? "Normal",
                  workerId: workerId,
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _jobCard({
    required String requestId,
    required String title,
    required String category,
    required String location,
    required String budget,
    required String urgency,
    required String workerId,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            category,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _infoRow(Icons.location_on_outlined, location),
          const SizedBox(height: 8),
          _infoRow(Icons.payments_outlined, budget),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _outlineButton("Reject")),
              const SizedBox(width: 12),
              Expanded(
                child: _acceptButtonReal(
                  requestId: requestId,
                  workerId: workerId,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _acceptButtonReal({
    required String requestId,
    required String workerId,
  }) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: () async {
          final requestDoc = await FirebaseFirestore.instance
              .collection("requests")
              .doc(requestId)
              .get();

          final requestData = requestDoc.data() as Map<String, dynamic>;
          final customerId = requestData["customerId"];
          final category = requestData["category"];

          await FirebaseFirestore.instance
              .collection("requests")
              .doc(requestId)
              .update({
                "status": "accepted",
                "workerId": workerId,
                "acceptedAt": FieldValue.serverTimestamp(),
              });

          await FirebaseFirestore.instance.collection("chats").add({
            "customerId": customerId,
            "workerId": workerId,
            "requestId": requestId,
            "service": category,
            "lastMessage": "",
            "updatedAt": FieldValue.serverTimestamp(),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Job accepted successfully")),
          );
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF16A34A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          "Accept",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _emptyJobs() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Text(
          "No new job requests found",
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _outlineButton(String text) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
