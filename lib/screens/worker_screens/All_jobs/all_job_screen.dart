import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_jobs_screen.dart';

/// Legacy route retained as a thin entry into the canonical worker Jobs screen.
class AllJobsScreen extends StatelessWidget {
  const AllJobsScreen({super.key});

  @override
  Widget build(BuildContext context) => const WorkerJobsScreen();
}
