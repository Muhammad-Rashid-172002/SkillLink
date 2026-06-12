import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({super.key});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const WorkerBottomBar(
  selectedIndex: 4,
),
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: const Center(
        child: Text("Worker Profile Screen"),
      ),
    );
  }
}