import 'package:flutter/material.dart';
import 'package:skill_link/Widgets/CategoryCard.dart';
import 'package:skill_link/Widgets/WorkerTile.dart';
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
      bottomNavigationBar: const CustomerBottomBar(selectedIndex: 1),
      appBar: AppBar(title: const Text("Explore")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search
            TextField(
              decoration: InputDecoration(
                hintText: "Search workers...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              "Popular Categories",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: .9,
              children: const [
                CategoryCard(
                  title: "Electrician",
                  icon: Icons.electrical_services,
                ),
                CategoryCard(title: "Plumber", icon: Icons.plumbing),
                CategoryCard(title: "Painter", icon: Icons.format_paint),
                CategoryCard(title: "Carpenter", icon: Icons.carpenter),
                CategoryCard(title: "AC Repair", icon: Icons.ac_unit),
                CategoryCard(title: "Cleaner", icon: Icons.cleaning_services),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              "Top Rated Workers",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            const WorkerTile(
              name: "Ali Khan",
              skill: "Electrician",
              rating: "4.9",
            ),

            const WorkerTile(
              name: "Usman Ahmad",
              skill: "Plumber",
              rating: "4.8",
            ),

            const WorkerTile(
              name: "Hamza Shah",
              skill: "Painter",
              rating: "4.7",
            ),
          ],
        ),
      ),
    );
  }
}
