import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/worker_screens/Map/worker_job_detail.dart';

class MapSreen extends StatefulWidget {
  const MapSreen({super.key});

  @override
  State<MapSreen> createState() => _MapSreenState();
}

class _MapSreenState extends State<MapSreen> {
  final requests = [
    {
      "title": "Fan is not working",
      "category": "Electrician",
      "location": "Pabbi Bazar",
      "distance": "1.2 km",
      "budget": "Rs. 1000",
      "urgency": "Urgent",
    },
    {
      "title": "AC cooling issue",
      "category": "AC Repair",
      "location": "Nowshera Cantt",
      "distance": "3.5 km",
      "budget": "Rs. 2500",
      "urgency": "Normal",
    },
    {
      "title": "Room painting needed",
      "category": "Painter",
      "location": "University Road",
      "distance": "5.1 km",
      "budget": "Rs. 5000",
      "urgency": "Normal",
    },
  ];



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: const WorkerBottomBar(selectedIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _mapPreview(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(),
                    const SizedBox(height: 14),
                    ...requests.map((item) => _requestCard(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(22, 18, 22, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Nearby Requests",
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Icon(Icons.tune_rounded, color: Color(0xFF16A34A)),
        ],
      ),
    );
  }

  Widget _mapPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD1FAE5), Color(0xFFEFF6FF)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.map_rounded, size: 90, color: Color(0xFF16A34A)),
          ),
          _pin(left: 45, top: 42),
          _pin(right: 60, top: 72),
          _pin(left: 120, bottom: 38),
          Positioned(
            left: 18,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                "3 jobs near you",
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pin({double? left, double? right, double? top, double? bottom}) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16A34A).withOpacity(.35),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.location_on_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _sectionHeader() {
    return const Text(
      "Available Jobs",
      style: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _requestCard(Map<String, String> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(item["category"]!),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item["title"]!,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item["category"]!,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                item["budget"]!,
                style: const TextStyle(
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow(Icons.location_on_outlined, item["location"]!),
          const SizedBox(height: 8),
          _infoRow(Icons.near_me_outlined, item["distance"]!),
          const SizedBox(height: 14),
          Row(
            children: [
              _badge(item["urgency"]!),
              const Spacer(),
              _acceptButton(item),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBox(String category) {
    IconData icon = Icons.handyman_rounded;

    if (category == "Electrician") icon = Icons.electrical_services_rounded;
    if (category == "AC Repair") icon = Icons.ac_unit_rounded;
    if (category == "Painter") icon = Icons.format_paint_rounded;

    return Container(
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withOpacity(.10),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: const Color(0xFF16A34A), size: 27),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: text == "Urgent"
            ? const Color(0xFFEF4444).withOpacity(.10)
            : const Color(0xFF16A34A).withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: text == "Urgent"
              ? const Color(0xFFEF4444)
              : const Color(0xFF16A34A),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

 Widget _acceptButton(Map<String, String> item) {
  return SizedBox(
    height: 42,
    child: ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkerJobDetailScreen(
              title: item["title"]!,
              category: item["category"]!,
              location: item["location"]!,
              distance: item["distance"]!,
              budget: item["budget"]!,
              urgency: item["urgency"]!,
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: const Color(0xFF16A34A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      child: const Text(
        "View Job",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}
}
