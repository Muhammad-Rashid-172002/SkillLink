import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_detail_screen.dart';

/// Compatibility entry point retained for older routes.
///
/// Request data is now loaded from Firestore by the canonical Step 8 detail
/// screen, so legacy presentation arguments are intentionally ignored.
class WorkerJobDetailScreen extends StatelessWidget {
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

  final String requestId;
  final String title;
  final String category;
  final String location;
  final String distance;
  final String budget;
  final String urgency;

  @override
  Widget build(BuildContext context) {
    return WorkerJobDetailV2Screen(requestId: requestId);
  }
}
