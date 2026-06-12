import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/bottom_bar/bottom_bar.dart';

class Explore extends StatefulWidget {
  const Explore({super.key});

  @override
  State<Explore> createState() => _ExploreState();
}

class _ExploreState extends State<Explore> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const CustomerBottomBar(
        selectedIndex: 1,
      ),
      appBar: AppBar(
        title: const Text("Explore"),
      ),
      body: const Center(
        child: Text("Explore Screen"),
      ),
    );
  }
}