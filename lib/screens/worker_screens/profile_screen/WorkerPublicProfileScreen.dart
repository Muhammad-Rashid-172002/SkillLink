import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerPublicProfileScreen extends StatelessWidget {
  final String workerId;

  const WorkerPublicProfileScreen({
    super.key,
    required this.workerId,
  });

  Future<void> _callWorker(BuildContext context, String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number not found")),
      );
      return;
    }

    final Uri uri = Uri(scheme: "tel", path: phone);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot open phone dialer")),
      );
    }
  }

  Future<void> _openChat(
    BuildContext context,
    Map<String, dynamic> worker,
  ) async {
    final customerId = FirebaseAuth.instance.currentUser!.uid;

    final existingChat = await FirebaseFirestore.instance
        .collection("chats")
        .where("customerId", isEqualTo: customerId)
        .where("workerId", isEqualTo: workerId)
        .limit(1)
        .get();

    String chatId;

    if (existingChat.docs.isNotEmpty) {
      chatId = existingChat.docs.first.id;
    } else {
      final chatDoc = await FirebaseFirestore.instance.collection("chats").add({
        "customerId": customerId,
        "workerId": workerId,
        "service": worker["skill"] ?? "",
        "lastMessage": "",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      chatId = chatDoc.id;
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: chatId,
          workerName: worker["name"] ?? "Worker",
          workerSkill: worker["skill"] ?? "",
        ),
      ),
    );
  }

  Future<void> _hireWorker(BuildContext context, Map<String, dynamic> worker) async {
    final customerId = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection("requests").add({
      "customerId": customerId,
      "workerId": workerId,
      "category": worker["skill"] ?? "",
      "title": "Direct Hire Request",
      "description": "Customer hired worker from public profile.",
      "location": "",
      "budget": worker["hourlyRate"] ?? "",
      "urgency": "Normal",
      "status": "accepted",
      "createdAt": FieldValue.serverTimestamp(),
      "acceptedAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Hire request created successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text("Worker Profile")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(workerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text("Worker not found"));
          }

          final worker = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                _profileCard(worker),
                const SizedBox(height: 20),
                _aboutCard(worker),
                const SizedBox(height: 20),
                _reviewsSection(),
                const SizedBox(height: 24),
                _actionButtons(context, worker),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _profileCard(Map<String, dynamic> worker) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _box(),
      child: Column(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: const Color(0xFF2563EB).withOpacity(.10),
            child: const Icon(
              Icons.person,
              size: 58,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            worker["name"] ?? "Worker",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            worker["skill"] ?? "",
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
              const SizedBox(width: 4),
              Text(
                "${worker["rating"] ?? 0} • ${worker["totalReviews"] ?? 0} Reviews",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Rs ${worker["hourlyRate"] ?? "0"}",
            style: const TextStyle(
              color: Color(0xFF16A34A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("requests")
                .where("workerId", isEqualTo: workerId)
                .where("status", isEqualTo: "completed")
                .snapshots(),
            builder: (context, snapshot) {
              final completedJobs = snapshot.data?.docs.length ?? 0;

              return Text(
                "$completedJobs Completed Jobs",
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _aboutCard(Map<String, dynamic> worker) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "About Worker",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            worker["bio"] ??
                "Experienced and trusted worker available for home services.",
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("reviews")
          .where("workerId", isEqualTo: workerId)
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: _box(),
            child: const Text(
              "No reviews yet",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: _box(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Reviews",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ...snapshot.data!.docs.map((doc) {
                final review = doc.data() as Map<String, dynamic>;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text(review["review"] ?? "No review text"),
                  subtitle: Text("${review["rating"]} Stars"),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButtons(BuildContext context, Map<String, dynamic> worker) {
    return Row(
      children: [
        Expanded(
          child: _outlineButton(
            Icons.call_rounded,
            "Call",
            () => _callWorker(
              context,
              worker["phone"]?.toString() ?? "",
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _outlineButton(
            Icons.chat_rounded,
            "Chat",
            () => _openChat(context, worker),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _hireButton(
            () => _hireWorker(context, worker),
          ),
        ),
      ],
    );
  }

  Widget _outlineButton(
    IconData icon,
    String text,
    VoidCallback onTap,
  ) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: const Color(0xFF2563EB)),
        label: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF2563EB),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _hireButton(VoidCallback onTap) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
        ),
        child: const Text(
          "Hire",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    );
  }
}