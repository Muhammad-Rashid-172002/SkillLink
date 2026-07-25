import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Map/worker_job_detail.dart';

class JobsByStatusScreen extends StatelessWidget {
  final String title;
  final String status;

  const JobsByStatusScreen({
    super.key,
    required this.title,
    required this.status,
  });

  static const Color _background = Color(0xFFF4F7FB);
  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF14B8A6);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    Query query = FirebaseFirestore.instance.collection("requests");

    if (status == "searching") {
      query = query.where("status", isEqualTo: "searching");
    } else {
      query = query
          .where("status", isEqualTo: "searching")
          .where(
            Filter.or(
              Filter("workerId", isNull: true),
              Filter("workerId", isEqualTo: uid),
            ),
          );
    }

    final bool isAvailableJobs = status == "searching";

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSection(context, isAvailableJobs: isAvailableJobs),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  if (!snapshot.hasData) {
                    return _buildLoadingState();
                  }

                  final jobs = snapshot.data!.docs;

                  if (jobs.isEmpty) {
                    return _buildEmptyState(isAvailableJobs: isAvailableJobs);
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final document = jobs[index];
                      final job = document.data() as Map<String, dynamic>;

                      return _buildJobCard(
                        context: context,
                        requestId: document.id,
                        job: job,
                        isAvailableJobs: isAvailableJobs,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(
    BuildContext context, {
    required bool isAvailableJobs,
  }) {
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
          _buildHeader(context),
          const SizedBox(height: 18),
          _buildHeroCard(isAvailableJobs: isAvailableJobs),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
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
                border: Border.all(color: _border),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _textPrimary,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.45,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status == "searching"
                    ? "Explore available work opportunities"
                    : "Track your active and ongoing jobs",
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: _primary.withOpacity(.09),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            status == "searching"
                ? Icons.travel_explore_rounded
                : Icons.assignment_turned_in_outlined,
            color: _primary,
            size: 21,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard({required bool isAvailableJobs}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(.22),
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
          Row(
            children: [
              Expanded(
                child: Column(
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
                        isAvailableJobs ? "AVAILABLE JOBS" : "ACTIVE WORK",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isAvailableJobs
                          ? "Find your next opportunity"
                          : "Manage your current jobs",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      isAvailableJobs
                          ? "Browse open requests and choose work that suits you."
                          : "View accepted, on-the-way and in-progress jobs.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(.82),
                        fontSize: 10.6,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 84,
                width: 74,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.14),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(.18)),
                ),
                child: Icon(
                  isAvailableJobs
                      ? Icons.search_rounded
                      : Icons.handyman_rounded,
                  color: Colors.white,
                  size: 37,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard({
    required BuildContext context,
    required String requestId,
    required Map<String, dynamic> job,
    required bool isAvailableJobs,
  }) {
    final String jobTitle = _safeText(job["title"], fallback: "Untitled Job");

    final String category = _safeText(
      job["category"],
      fallback: "General Service",
    );

    final String location = _safeText(
      job["location"],
      fallback: "Location not provided",
    );

    final String budget = _safeText(job["budget"], fallback: "Budget not set");

    final String urgency = _safeText(job["urgency"], fallback: "Normal");

    final String description = _safeText(
      job["description"],
      fallback: "No description available.",
    );

    final String jobStatus = _safeText(job["status"], fallback: status);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerJobDetailScreen(
                requestId: requestId,
                title: jobTitle,
                category: category,
                location: location,
                distance: "Nearby",
                budget: budget,
                urgency: urgency,
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x070F172A),
                blurRadius: 15,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_primary, _secondary],
                      ),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.work_outline_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jobTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 14.5,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            _buildTag(
                              icon: Icons.category_outlined,
                              label: category,
                              color: _primary,
                            ),
                            _buildTag(
                              icon: Icons.bolt_rounded,
                              label: urgency,
                              color: const Color(0xFFF59E0B),
                            ),
                            if (!isAvailableJobs)
                              _buildTag(
                                icon: _statusIcon(jobStatus),
                                label: _statusLabel(jobStatus),
                                color: _statusColor(jobStatus),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(.08),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      budget,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 15),
              Container(height: 1, color: const Color(0xFFF1F5F9)),
              const SizedBox(height: 13),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: _primary,
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: _primary,
                      size: 17,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 7.8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          height: 175,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: _border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusSkeleton(width: 50, height: 50, radius: 17),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusSkeleton(width: 185, height: 12, radius: 8),
                        SizedBox(height: 9),
                        _StatusSkeleton(width: 120, height: 9, radius: 8),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18),
              _StatusSkeleton(width: double.infinity, height: 9, radius: 8),
              SizedBox(height: 9),
              _StatusSkeleton(width: 220, height: 9, radius: 8),
              SizedBox(height: 18),
              _StatusSkeleton(width: double.infinity, height: 38, radius: 13),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required bool isAvailableJobs}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Container(
                height: 82,
                width: 82,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(.09),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  isAvailableJobs
                      ? Icons.search_off_rounded
                      : Icons.assignment_late_outlined,
                  color: _primary,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isAvailableJobs ? "No available jobs" : "No active jobs",
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAvailableJobs
                    ? "New customer job requests will appear here."
                    : "Your accepted and ongoing jobs will appear here.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.6,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: _border),
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
                "Unable to load jobs",
                style: TextStyle(
                  color: _textPrimary,
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
                  color: _textSecondary,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _safeText(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? "";

    if (text.isEmpty || text.toLowerCase() == "null") {
      return fallback;
    }

    return text;
  }

  String _statusLabel(String value) {
    switch (value) {
      case "accepted":
        return "Accepted";
      case "on_the_way":
        return "On the way";
      case "in_progress":
        return "In progress";
      default:
        return value.replaceAll("_", " ");
    }
  }

  IconData _statusIcon(String value) {
    switch (value) {
      case "accepted":
        return Icons.check_circle_outline_rounded;
      case "on_the_way":
        return Icons.directions_run_rounded;
      case "in_progress":
        return Icons.construction_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _statusColor(String value) {
    switch (value) {
      case "accepted":
        return const Color(0xFF2563EB);
      case "on_the_way":
        return const Color(0xFFF59E0B);
      case "in_progress":
        return const Color(0xFF8B5CF6);
      default:
        return _textSecondary;
    }
  }
}

class _StatusSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _StatusSkeleton({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
