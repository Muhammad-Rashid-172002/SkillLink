import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_models.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_jobs_screen.dart';

/// Profile-menu compatibility route for canonical completed job history.
class CompletedJobsScreen extends StatelessWidget {
  const CompletedJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WorkerJobsScreen(initialGroup: WorkerJobGroup.completed);
  }
}
