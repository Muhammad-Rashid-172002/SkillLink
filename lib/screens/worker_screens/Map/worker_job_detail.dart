import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class WorkerJobDetailScreen extends StatefulWidget {
  final String requestId;
  final String title;
  final String category;
  final String location;
  final String distance;
  final String budget;
  final String urgency;

  const WorkerJobDetailScreen({
    super.key,
    required this.requestId,
    required this.title,
    required this.category,
    required this.location,
    required this.distance,
    required this.budget,
    required this.urgency,
  });

  @override
  State<WorkerJobDetailScreen> createState() => _WorkerJobDetailScreenState();
}

class _WorkerJobDetailScreenState extends State<WorkerJobDetailScreen> {
  Future<void> _updateStatus(
    BuildContext context,
    String status,
    String message,
  ) async {
    final updateData = {
      "status": status,
      "updatedAt": FieldValue.serverTimestamp(),
    };

    if (status == "accepted") {
      updateData["workerId"] = FirebaseAuth.instance.currentUser!.uid;
      updateData["acceptedAt"] = FieldValue.serverTimestamp();
    }

    if (status == "on_the_way") {
      updateData["onTheWayAt"] = FieldValue.serverTimestamp();
    }

    if (status == "in_progress") {
      updateData["startedAt"] = FieldValue.serverTimestamp();
    }

    if (status == "completed") {
      updateData["completedAt"] = FieldValue.serverTimestamp();
    }

    await FirebaseFirestore.instance
        .collection("requests")
        .doc(widget.requestId)
        .update(updateData);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> updateWorkerLiveLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();

    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection("users").doc(uid).update({
      "lat": position.latitude,
      "lng": position.longitude,
      "locationUpdatedAt": FieldValue.serverTimestamp(),
    });
  }

  Timer? locationTimer;

  void startLiveLocationTimer() {
    locationTimer?.cancel();

    updateWorkerLiveLocation();

    locationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      updateWorkerLiveLocation();
    });
  }

  void stopLiveLocationTimer() {
    locationTimer?.cancel();
    locationTimer = null;
  }

  @override
  void dispose() {
    stopLiveLocationTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text("Job Details")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("requests")
            .doc(widget.requestId)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final status = data?["status"] ?? "searching";

          return Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.category,
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                _row(Icons.location_on_outlined, widget.location),
                _row(Icons.near_me_outlined, widget.distance),
                _row(Icons.payments_outlined, widget.budget),
                _row(Icons.priority_high_rounded, widget.urgency),
                const SizedBox(height: 16),
                _statusBadge(status),
                const Spacer(),
                _actionButton(context, status),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _actionButton(BuildContext context, String status) {
    if (status == "searching" || status == "pending") {
      return _button(
        text: "Accept Job",
        color: const Color(0xFF16A34A),
        onTap: () async {
          await _updateStatus(context, "accepted", "Job accepted successfully");
        },
      );
    }

    if (status == "accepted") {
      return _button(
        text: "On The Way",
        color: const Color(0xFF2563EB),
        onTap: () async {
          await _updateStatus(
            context,
            "on_the_way",
            "Status updated: On The Way",
          );

          startLiveLocationTimer();
        },
      );
    }

    if (status == "on_the_way") {
      return _button(
        text: "Start Work",
        color: const Color(0xFFF59E0B),
        onTap: () async {
          stopLiveLocationTimer();
          await _updateStatus(context, "in_progress", "Work started");
        },
      );
    }

    if (status == "in_progress") {
      return _button(
        text: "Complete Job",
        color: const Color(0xFF16A34A),
        onTap: () async {
          stopLiveLocationTimer();
          await _updateStatus(context, "completed", "Job completed");
        },
      );
    }

    return Container(
      width: double.infinity,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        "Job Completed ✅",
        style: TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _button({
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    String text = "Searching";
    Color color = const Color(0xFFF59E0B);

    if (status == "accepted") {
      text = "Accepted";
      color = const Color(0xFF2563EB);
    } else if (status == "on_the_way") {
      text = "On The Way";
      color = const Color(0xFF0EA5E9);
    } else if (status == "in_progress") {
      text = "In Progress";
      color = const Color(0xFFF59E0B);
    } else if (status == "completed") {
      text = "Completed";
      color = const Color(0xFF16A34A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF16A34A)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
