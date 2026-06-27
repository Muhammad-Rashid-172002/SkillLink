import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PaymentMethodScreen extends StatelessWidget {
  final String credits;
  final String price;

  const PaymentMethodScreen({
    super.key,
    required this.credits,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text("Payment Method")),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text(
                    "$credits Credits",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    price,
                    style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _paymentTile(
              icon: Icons.account_balance_wallet,
              title: "EasyPaisa",
            ),

            const SizedBox(height: 12),

            _paymentTile(icon: Icons.payments_rounded, title: "JazzCash"),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser!.uid;

                  final int creditsToAdd = int.parse(credits);

                  await FirebaseFirestore.instance
                      .collection("users")
                      .doc(uid)
                      .update({"credits": FieldValue.increment(creditsToAdd)});

                  await FirebaseFirestore.instance
                      .collection("transactions")
                      .add({
                        "workerId": uid,
                        "title": "Bought $credits credits",
                        "amount": "+$credits Credits",
                        "type": "credit_purchase",
                        "createdAt": FieldValue.serverTimestamp(),
                      });

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("$credits credits added successfully"),
                    ),
                  );

                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  "Continue Payment",
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
// 
  Widget _paymentTile({required IconData icon, required String title}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        ],
      ),
    );
  }
}
