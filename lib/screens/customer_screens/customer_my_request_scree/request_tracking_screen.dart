import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RequestTrackingScreen extends StatelessWidget {
  final String requestId;

  const RequestTrackingScreen({
    super.key,
    required this.requestId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Request Tracking"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("requests")
            .doc(requestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Request not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data["status"] ?? "searching";
          final workerId = data["workerId"];

          if (status == "searching" || status == "pending") {
            return _searchingView(data);
          }

          if (status == "accepted" && workerId != null) {
            return _acceptedView(workerId, data);
          }

          if (status == "completed") {
            return _completedView(data);
          }

          return _searchingView(data);
        },
      ),
    );
  }

  Widget _searchingView(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            height: 130,
            width: 130,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 70,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            "Searching Nearby Workers...",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Please wait while we find a suitable worker for your request.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 30),
          LinearProgressIndicator(
            color: const Color(0xFF2563EB),
            backgroundColor: const Color(0xFF2563EB).withOpacity(.12),
          ),
          const SizedBox(height: 34),
          _requestSummary(data),
        ],
      ),
    );
  }

  Widget _acceptedView(String workerId, Map<String, dynamic> requestData) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(workerId)
          .snapshots(),
      builder: (context, workerSnapshot) {
        if (workerSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2563EB)),
          );
        }

        if (!workerSnapshot.hasData || !workerSnapshot.data!.exists) {
          return const Center(child: Text("Worker profile not found"));
        }

        final worker = workerSnapshot.data!.data() as Map<String, dynamic>;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                height: 110,
                width: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 72,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                "Worker Accepted Your Request",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "You can now chat or call the worker.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              _workerCard(worker),
              const SizedBox(height: 20),
              _requestSummary(requestData),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _outlineButton(
                      icon: Icons.call_rounded,
                      text: "Call",
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _primaryButton(
                      icon: Icons.chat_rounded,
                      text: "Chat",
                      onTap: () {
                        // yahan baad me ChatDetailScreen open karna
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _completedView(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const SizedBox(height: 80),
          const Icon(
            Icons.task_alt_rounded,
            size: 110,
            color: Color(0xFF16A34A),
          ),
          const SizedBox(height: 24),
          const Text(
            "Job Completed",
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Thanks for using SkillLink.",
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 30),
          _requestSummary(data),
        ],
      ),
    );
  }

  Widget _workerCard(Map<String, dynamic> worker) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 86,
            width: 86,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFF16A34A),
              size: 50,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            worker["name"] ?? "Worker",
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            worker["skill"] ?? "Skilled Worker",
            style: const TextStyle(
              color: Color(0xFF16A34A),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
              const SizedBox(width: 4),
              Text(
                worker["rating"]?.toString() ?? "4.8",
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.work_rounded, color: Color(0xFF64748B), size: 18),
              const SizedBox(width: 4),
              Text(
                worker["experience"] ?? "Experience",
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            worker["location"] ?? "",
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestSummary(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Request Details",
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _infoRow(Icons.title_rounded, data["title"] ?? ""),
          const SizedBox(height: 8),
          _infoRow(Icons.category_rounded, data["category"] ?? ""),
          const SizedBox(height: 8),
          _infoRow(Icons.location_on_rounded, data["location"] ?? ""),
          const SizedBox(height: 8),
          _infoRow(Icons.payments_rounded, data["budget"] ?? ""),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF94A3B8), size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _outlineButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 54,
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
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF2563EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF2563EB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}