import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_models.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_jobs_screen.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_leads_screen.dart';

/// Compatibility wrapper for historical worker job routes.
class JobsByStatusScreen extends StatelessWidget {
  const JobsByStatusScreen({
    super.key,
    required this.title,
    required this.status,
    this.embedded = false,
  });

  final String title;
  final String status;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase().replaceAll(' ', '_');
    if (normalized == 'searching' || normalized == 'available') {
      return const WorkerLeadsScreen();
    }
    final group = switch (normalized) {
      'completed' => WorkerJobGroup.completed,
      'cancelled' || 'canceled' || 'rejected' => WorkerJobGroup.cancelled,
      _ => WorkerJobGroup.active,
    };
    return WorkerJobsScreen(initialGroup: group, embedded: embedded);
  }
}
