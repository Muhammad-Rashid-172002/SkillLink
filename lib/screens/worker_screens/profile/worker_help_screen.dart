import 'package:flutter/material.dart';
import 'package:skill_link/screens/shared/skillnova_help_support.dart';

import 'worker_safety_screen.dart';

class WorkerHelpScreen extends StatelessWidget {
  const WorkerHelpScreen({super.key});

  @override
  Widget build(BuildContext context) => SkillNovaHelpSupportScreen(
    audience: SkillNovaHelpAudience.worker,
    safetyBuilder: (_) => const WorkerSafetyScreen(),
  );
}
