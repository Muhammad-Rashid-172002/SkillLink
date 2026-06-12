import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';

class MapSreen extends StatefulWidget {
  const MapSreen({super.key});

  @override
  State<MapSreen> createState() => _MapSreenState();
}

class _MapSreenState extends State<MapSreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const WorkerBottomBar(selectedIndex: 1),
      appBar: AppBar(title: const Text("Map")),
      body: const Center(child: Text("Map Screen")),
    );
  }
}
