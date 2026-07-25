import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:skill_link/screens/worker_screens/Wallat/Wallat_screen.dart';

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
  Future<void> _sendCustomerNotification({
    required String title,
    required String message,
  }) async {
    final requestDoc = await FirebaseFirestore.instance
        .collection("requests")
        .doc(widget.requestId)
        .get();

    final requestData = requestDoc.data();
    final customerId = requestData?["customerId"];

    if (customerId == null) return;

    await FirebaseFirestore.instance.collection("notifications").add({
      "userId": customerId,
      "requestId": widget.requestId,
      "title": title,
      "message": message,
      "isRead": false,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

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
  updateData["reviewPending"] = true;
  updateData["reviewed"] = false;
}

    await FirebaseFirestore.instance
        .collection("requests")
        .doc(widget.requestId)
        .update(updateData);

    String notificationTitle = "";
    String notificationMessage = "";

    if (status == "on_the_way") {
      notificationTitle = "Worker On The Way";
      notificationMessage = "Your worker is heading to your location.";
    } else if (status == "in_progress") {
      notificationTitle = "Work Started";
      notificationMessage = "Worker has started your job.";
    } else if (status == "completed") {
      notificationTitle = "Job Completed";
      notificationMessage =
          "Your job has been completed. Please rate the worker.";
    }

    if (notificationTitle.isNotEmpty) {
      await _sendCustomerNotification(
        title: notificationTitle,
        message: notificationMessage,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF16A34A), Color(0xFF14B8A6)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16A34A).withOpacity(.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("requests")
              .doc(widget.requestId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(context, snapshot.error.toString());
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF16A34A),
                  strokeWidth: 2.6,
                ),
              );
            }

            final data = snapshot.data?.data() as Map<String, dynamic>?;

            final status = data?["status"] ?? "searching";

            return Column(
              children: [
                _buildTopSection(context, status: status),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainJobCard(status),
                        const SizedBox(height: 16),
                        _buildDetailsSection(),
                        const SizedBox(height: 16),
                        _buildStatusProgress(status),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("requests")
            .doc(widget.requestId)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;

          final status = data?["status"] ?? "searching";

          return _buildBottomActionBar(context, status);
        },
      ),
    );
  }

  Widget _actionButton(BuildContext context, String status) {
    if (status == "searching" || status == "pending") {
      return _button(
        text: "Accept Job",
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF16A34A),
        onTap: () async {
          final uid = FirebaseAuth.instance.currentUser!.uid;

          final workerDoc = await FirebaseFirestore.instance
              .collection("users")
              .doc(uid)
              .get();

          final workerData = workerDoc.data() as Map<String, dynamic>;

          final credits = workerData["credits"] ?? 0;

          if (credits <= 0) {
            _showNoCreditsDialog();
            return;
          }

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final workerRef = FirebaseFirestore.instance
                .collection("users")
                .doc(uid);

            final requestRef = FirebaseFirestore.instance
                .collection("requests")
                .doc(widget.requestId);

            final freshWorkerDoc = await transaction.get(workerRef);

            final freshCredits =
                (freshWorkerDoc.data()?["credits"] ?? 0) as int;

            if (freshCredits <= 0) {
              throw Exception("No credits available");
            }

            transaction.update(workerRef, {
              "credits": freshCredits - 1,
              "updatedAt": FieldValue.serverTimestamp(),
            });

            transaction.update(requestRef, {
              "status": "accepted",
              "workerId": uid,
              "acceptedAt": FieldValue.serverTimestamp(),
              "updatedAt": FieldValue.serverTimestamp(),
            });

            final transactionRef = FirebaseFirestore.instance
                .collection("transactions")
                .doc();

            transaction.set(transactionRef, {
              "workerId": uid,
              "requestId": widget.requestId,
              "title": "Used 1 lead credit",
              "amount": "-1 Credit",
              "type": "lead_used",
              "createdAt": FieldValue.serverTimestamp(),
            });
          });

          await _sendCustomerNotification(
            title: "Job Accepted",
            message: "Your job has been accepted by a worker.",
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Job accepted. 1 credit deducted.")),
          );
        },
      );
    }

    if (status == "accepted") {
      return _button(
        text: "Start Journey",
        icon: Icons.directions_run_rounded,
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
        icon: Icons.construction_rounded,
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
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF16A34A),
        onTap: () async {
          stopLiveLocationTimer();

          await _updateStatus(context, "completed", "Job completed");
        },
      );
    }

    return Container(
      width: double.infinity,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withOpacity(.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF16A34A).withOpacity(.16)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 21),
          SizedBox(width: 8),
          Text(
            "Job Completed",
            style: TextStyle(
              color: Color(0xFF16A34A),
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showNoCreditsDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "No Credits",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 30,
                    offset: Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 78,
                    width: 78,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFC107),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 40,
                      color: Color(0xFFF59E0B),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Insufficient Credits",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "You don't have enough credits to accept this job.\n\nPurchase more credits to continue receiving customer requests.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 26),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Maybe Later",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(
                            Icons.shopping_cart_checkout_rounded,
                          ),
                          label: const Text(
                            "Buy Credits",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: () {
                            Navigator.pop(context);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WallatScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _button({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    String text = "Searching";
    Color color = const Color(0xFFF59E0B);
    IconData icon = Icons.search_rounded;

    if (status == "accepted") {
      text = "Accepted";
      color = const Color(0xFF2563EB);
      icon = Icons.check_circle_outline_rounded;
    } else if (status == "on_the_way") {
      text = "On The Way";
      color = const Color(0xFF0EA5E9);
      icon = Icons.directions_run_rounded;
    } else if (status == "in_progress") {
      text = "In Progress";
      color = const Color(0xFFF59E0B);
      icon = Icons.construction_rounded;
    } else if (status == "completed") {
      text = "Completed";
      color = const Color(0xFF16A34A);
      icon = Icons.verified_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String title, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF16A34A), size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 11.3,
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

  Widget _buildTopSection(BuildContext context, {required String status}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Material(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF0F172A),
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Job Details",
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Review job information and manage progress",
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainJobCard(String status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16A34A), Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -65,
            right: -45,
            child: Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.category.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.45,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _heroInfo(
                      icon: Icons.payments_outlined,
                      label: "Budget",
                      value: widget.budget,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _heroInfo(
                      icon: Icons.priority_high_rounded,
                      label: "Urgency",
                      value: widget.urgency,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.13),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withOpacity(.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.72),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF16A34A),
                size: 19,
              ),
              SizedBox(width: 8),
              Text(
                "Job Information",
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _row(Icons.location_on_outlined, "LOCATION", widget.location),
          _row(Icons.near_me_outlined, "DISTANCE", widget.distance),
          _row(Icons.category_outlined, "CATEGORY", widget.category),
          _row(Icons.payments_outlined, "BUDGET", widget.budget),
          _row(Icons.priority_high_rounded, "URGENCY", widget.urgency),
        ],
      ),
    );
  }

  Widget _buildStatusProgress(String status) {
    final steps = ["accepted", "on_the_way", "in_progress", "completed"];

    final currentIndex = status == "searching" || status == "pending"
        ? -1
        : steps.indexOf(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Job Progress",
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: List.generate(steps.length, (index) {
              final isCompleted = currentIndex >= index;
              final isCurrent = currentIndex == index;

              return Expanded(
                child: Row(
                  children: [
                    Container(
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(
                                color: const Color(0xFF16A34A).withOpacity(.25),
                                width: 4,
                              )
                            : null,
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check_rounded
                            : Icons.circle_outlined,
                        color: isCompleted
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                        size: 15,
                      ),
                    ),
                    if (index != steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: currentIndex > index
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Accepted",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                "On Way",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                "Working",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                "Done",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, String status) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 18,
            offset: Offset(0, -7),
          ),
        ],
      ),
      child: SafeArea(top: false, child: _actionButton(context, status)),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(.09),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: Color(0xFFEF4444),
                  size: 33,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Unable to load job",
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text("Go Back"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
