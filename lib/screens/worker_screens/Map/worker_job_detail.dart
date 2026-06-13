import 'package:flutter/material.dart';

class WorkerJobDetailScreen extends StatelessWidget {
  final String title;
  final String category;
  final String location;
  final String distance;
  final String budget;
  final String urgency;

  const WorkerJobDetailScreen({
    super.key,
    required this.title,
    required this.category,
    required this.location,
    required this.distance,
    required this.budget,
    required this.urgency,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text("Job Details")),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              category,
              style: const TextStyle(
                color: Color(0xFF16A34A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            _row(Icons.location_on_outlined, location),
            _row(Icons.near_me_outlined, distance),
            _row(Icons.payments_outlined, budget),
            _row(Icons.priority_high_rounded, urgency),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      title: const Text("Accept Job?"),
                      content: const Text(
                        "1 lead credit will be deducted from your wallet after accepting this job.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Job Accepted Successfully"),
                              ),
                            );
                          },
                          child: const Text("Accept"),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                ),
                child: const Text(
                  "Accept Job",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF16A34A)),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
