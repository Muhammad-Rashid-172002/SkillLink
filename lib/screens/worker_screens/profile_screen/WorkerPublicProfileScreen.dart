import 'package:flutter/material.dart';

class WorkerPublicProfileScreen extends StatelessWidget {
  final String name;
  final String skill;
  final String rating;
  final String price;

  const WorkerPublicProfileScreen({
    super.key,
    required this.name,
    required this.skill,
    required this.rating,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text("Worker Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            _profileCard(),
            const SizedBox(height: 20),
            _aboutCard(),
            const SizedBox(height: 20),
            _reviewCard(),
            const SizedBox(height: 24),
            _actionButtons(),
          ],
        ),
      ),
    );
  }
// profile card
  Widget _profileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _box(),
      child: Column(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: const Color(0xFF2563EB).withOpacity(.10),
            child: const Icon(Icons.person, size: 58, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 14),
          Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(skill, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
              Text(" $rating  •  54 jobs  •  3 years"),
            ],
          ),
          const SizedBox(height: 12),
          Text(price, style: const TextStyle(color: Color(0xFF16A34A), fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _aboutCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _box(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("About Worker", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          SizedBox(height: 10),
          Text(
            "Experienced and trusted worker available for home services. Provides quality work, fair pricing, and quick response.",
            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _box(),
      child: const Row(
        children: [
          Icon(Icons.reviews_rounded, color: Color(0xFF2563EB)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Very professional and completed the work on time.",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(child: _outlineButton(Icons.call_rounded, "Call")),
        const SizedBox(width: 12),
        Expanded(child: _outlineButton(Icons.chat_rounded, "Chat")),
        const SizedBox(width: 12),
        Expanded(child: _hireButton()),
      ],
    );
  }

  Widget _outlineButton(IconData icon, String text) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: Icon(icon, color: const Color(0xFF2563EB)),
        label: Text(text, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _hireButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
        child: const Text("Hire", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
    );
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    );
  }
}