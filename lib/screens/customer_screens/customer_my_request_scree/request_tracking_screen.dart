import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_detail_screen.dart';
import 'package:skill_link/screens/customer_screens/customer_my_request_scree/RateWorkerScreen.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestTrackingScreen extends StatefulWidget {
  final String requestId;

  const RequestTrackingScreen({super.key, required this.requestId});

  @override
  State<RequestTrackingScreen> createState() => _RequestTrackingScreenState();
}

class _RequestTrackingScreenState extends State<RequestTrackingScreen> {
  bool searchingDone = false;

  Widget _timeline(String status) {
    return Column(
      children: [
        _step("Request Sent", "Looking for available workers", true),
        _step(
          "Worker Accepted",
          "Worker accepted your job",
          [
            "accepted",
            "on_the_way",
            "in_progress",
            "completed",
          ].contains(status),
        ),
        _step(
          "On The Way",
          "Worker is heading to you",
          ["on_the_way", "in_progress", "completed"].contains(status),
        ),
        _step(
          "Job In Progress",
          "Work started at your location",
          ["in_progress", "completed"].contains(status),
        ),
        _step("Completed", "Job successfully finished", status == "completed"),
      ],
    );
  }

  Widget _step(String title, String subtitle, bool active) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: active ? Colors.green : Colors.grey.shade300,
        child: Icon(active ? Icons.check : Icons.circle, color: Colors.white),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => searchingDone = true);
      }
    });
  }

  Future<void> _makePhoneCall(String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Phone number not found")));
      return;
    }

    final Uri phoneUri = Uri(scheme: "tel", path: phone);

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cannot open phone dialer")));
    }
  }

  Future<void> _openChat({
    required String workerId,
    required Map<String, dynamic> worker,
  }) async {
    final requestDoc = await FirebaseFirestore.instance
        .collection("requests")
        .doc(widget.requestId)
        .get();

    final requestData = requestDoc.data() as Map<String, dynamic>;

    String? chatId = requestData["chatId"];

    if (chatId == null || chatId.isEmpty) {
      final chatDoc = await FirebaseFirestore.instance.collection("chats").add({
        "customerId": requestData["customerId"],
        "workerId": workerId,
        "requestId": widget.requestId,
        "service": requestData["category"],
        "lastMessage": "",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      chatId = chatDoc.id;

      await FirebaseFirestore.instance
          .collection("requests")
          .doc(widget.requestId)
          .update({
            "chatId": chatId,
            "suggestedWorkerId": workerId,
            "updatedAt": FieldValue.serverTimestamp(),
          });
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: chatId!,
          workerName: worker["name"] ?? "Worker",
          workerSkill: worker["skill"] ?? "Unknown",
        ),
      ),
    );
  }

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
            .doc(widget.requestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            );
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text("Request not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data["status"] ?? "searching";
          final workerId = data["workerId"];

          if (status == "accepted" && workerId != null) {
            return _acceptedView(workerId, data);
          }
          if (status == "on_the_way" && workerId != null) {
            return _statusView(
              workerId: workerId,
              requestData: data,
              icon: Icons.directions_bike_rounded,
              title: "Worker On The Way",
              subtitle: "Your worker is heading to your location.",
              color: const Color(0xFF0EA5E9),
            );
          }

          if (status == "in_progress" && workerId != null) {
            return _statusView(
              workerId: workerId,
              requestData: data,
              icon: Icons.build_circle_rounded,
              title: "Job In Progress",
              subtitle: "Work has started at your location.",
              color: const Color(0xFFF59E0B),
            );
          }

          if (status == "completed") {
            return _completedView(data);
          }

          if (!searchingDone) {
            return _searchingView(data);
          }

          return _nearestWorkerFinder(data);
        },
      ),
    );
  }

  Widget _statusView({
    required String workerId,
    required Map<String, dynamic> requestData,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(workerId)
          .snapshots(),
      builder: (context, workerSnapshot) {
        if (!workerSnapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: color));
        }

        final worker = workerSnapshot.data!.data() as Map<String, dynamic>;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Icon(icon, size: 95, color: color),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              _workerCard(worker),
              const SizedBox(height: 20),
              _requestSummary(requestData),
              const SizedBox(height: 20),
              _timeline(requestData["status"] ?? "searching"),
            ],
          ),
        );
      },
    );
  }

  Widget _nearestWorkerFinder(Map<String, dynamic> requestData) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "worker")
          .where("skill", isEqualTo: requestData["category"])
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _searchingView(requestData);
        }

        if (snapshot.data!.docs.isEmpty) {
          return _noWorkerFound(requestData);
        }

        final workerDoc = snapshot.data!.docs.first;
        final worker = workerDoc.data() as Map<String, dynamic>;

        return _foundWorkerView(
          requestData: requestData,
          workerId: workerDoc.id,
          worker: worker,
        );
      },
    );
  }

  Widget _foundWorkerView({
    required Map<String, dynamic> requestData,
    required String workerId,
    required Map<String, dynamic> worker,
  }) {
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
              Icons.person_search_rounded,
              size: 64,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            "Nearby Worker Found",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "This worker matches your service category.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 15,
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
                  onTap: () {
                    _makePhoneCall(worker["phone"]?.toString() ?? "");
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _primaryButton(
                  icon: Icons.chat_rounded,
                  text: "Chat",
                  onTap: () {
                    _openChat(workerId: workerId, worker: worker);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection("requests")
                    .doc(widget.requestId)
                    .update({
                      "suggestedWorkerId": workerId,
                      "status": "waiting_worker",
                      "updatedAt": FieldValue.serverTimestamp(),
                    });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Request sent to worker")),
                );
              },
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              label: const Text(
                "Send Request to Worker",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
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
        if (!workerSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2563EB)),
          );
        }

        if (!workerSnapshot.data!.exists) {
          return const Center(child: Text("Worker profile not found"));
        }

        final worker = workerSnapshot.data!.data() as Map<String, dynamic>;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(
                Icons.check_circle_rounded,
                size: 90,
                color: Color(0xFF16A34A),
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
              const SizedBox(height: 28),
              _workerCard(worker),
              const SizedBox(height: 20),
              _requestSummary(requestData),
            ],
          ),
        );
      },
    );
  }

  Widget _noWorkerFound(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const SizedBox(height: 80),
          const Icon(
            Icons.person_off_rounded,
            size: 90,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 20),
          const Text(
            "No Worker Found",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "No matching worker is available right now.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 28),
          _requestSummary(data),
        ],
      ),
    );
  }

  Widget _completedView(Map<String, dynamic> data) {
    final reviewed = data["reviewed"] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.task_alt, size: 100, color: Colors.green),
          const SizedBox(height: 20),

          const Text(
            "Job Completed",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 20),
          _requestSummary(data),
          const SizedBox(height: 20),
          _timeline("completed"),
          const SizedBox(height: 30),

          if (!reviewed)
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RateWorkerScreen(
                        workerId: data["workerId"],
                        requestId: widget.requestId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.star, color: Colors.white),
                label: const Text(
                  "Rate Worker",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                "Review submitted ✅",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
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
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 44,
            backgroundColor: Color(0xFFEAFBF0),
            child: Icon(
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
          const SizedBox(height: 12),
          Text(
            worker["phone"] ?? "",
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
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
