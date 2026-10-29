import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_leads_screen.dart';

/// Compatibility route. Leads now owns both list and map discovery.
class MapSreen extends StatelessWidget {
  const MapSreen({super.key});

  @override
  Widget build(BuildContext context) => const WorkerLeadsScreen();
}
