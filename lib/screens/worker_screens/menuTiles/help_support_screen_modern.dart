// Legacy wrapper. New code should use WorkerHelpScreen directly.
import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_help_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) => const WorkerHelpScreen();
}
