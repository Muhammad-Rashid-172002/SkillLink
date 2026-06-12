import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/bottom_bar/bottom_bar.dart';

class Request extends StatefulWidget {
  const Request({super.key});

  @override
  State<Request> createState() => _RequestState();
}

class _RequestState extends State<Request> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const CustomerBottomBar(
        selectedIndex: 2,
      ),
      appBar: AppBar(
        title: const Text("Request"),
      ),
      body: const Center(
        child: Text("Request Screen"),
      ),
    );
  }
}