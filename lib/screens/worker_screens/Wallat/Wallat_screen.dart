import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';

class WallatScreen extends StatefulWidget {
  const WallatScreen({super.key});

  @override
  State<WallatScreen> createState() => _WallatScreenState();
}

class _WallatScreenState extends State<WallatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const WorkerBottomBar(
        selectedIndex: 2,
      ),
      appBar: AppBar(
        title: const Text("Wallet"),
      ),
      body: const Center(
        child: Text("Wallet Screen"),
      ),
    );
  }
}