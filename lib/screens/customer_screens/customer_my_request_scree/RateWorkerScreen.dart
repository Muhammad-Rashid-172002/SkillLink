import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RateWorkerScreen extends StatefulWidget {
  final String workerId;
  final String requestId;

  const RateWorkerScreen({
    super.key,
    required this.workerId,
    required this.requestId,
  });

  @override
  State<RateWorkerScreen> createState() => _RateWorkerScreenState();
}

class _RateWorkerScreenState extends State<RateWorkerScreen> {
  int selectedRating = 5;
  final TextEditingController reviewController = TextEditingController();
  bool isLoading = false;

  Future<void> submitReview() async {
    if (isLoading) return;

    final customerId = FirebaseAuth.instance.currentUser!.uid;
    final reviewText = reviewController.text.trim();

    setState(() => isLoading = true);

    try {
      await FirebaseFirestore.instance.collection("reviews").add({
        "workerId": widget.workerId,
        "customerId": customerId,
        "requestId": widget.requestId,
        "rating": selectedRating,
        "review": reviewText,
        "createdAt": FieldValue.serverTimestamp(),
      });

      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection("reviews")
          .where("workerId", isEqualTo: widget.workerId)
          .get();

      double total = 0;

      for (final doc in reviewsSnapshot.docs) {
        final data = doc.data();
        total += (data["rating"] as num).toDouble();
      }

      final avgRating = total / reviewsSnapshot.docs.length;

      await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.workerId)
          .update({
        "rating": double.parse(avgRating.toStringAsFixed(1)),
        "totalReviews": reviewsSnapshot.docs.length,
      });

      await FirebaseFirestore.instance
          .collection("requests")
          .doc(widget.requestId)
          .update({
        "reviewed": true,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Review submitted successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Rate Worker"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Icon(
              Icons.star_rounded,
              size: 90,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(height: 20),
            const Text(
              "How was the service?",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your review helps other customers choose better workers.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final star = index + 1;

                return IconButton(
                  onPressed: () {
                    setState(() => selectedRating = star);
                  },
                  icon: Icon(
                    star <= selectedRating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 38,
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: reviewController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Write your review...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1.6,
                  ),
                ),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Submit Review",
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
}