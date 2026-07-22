import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          "Wallet & Earnings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("transactions")
            .where("workerId", isEqualTo: uid)
            //.orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString()),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          double totalEarnings = 0;
          int totalCredits = 0;

          for (var doc in docs) {

            final data = doc.data() as Map<String, dynamic>;

            final amount =
                data["amount"].toString().replaceAll(RegExp(r'[^0-9]'), "");

            final value = int.tryParse(amount) ?? 0;

            if (data["type"] == "job_payment") {
              totalEarnings += value;
            }

            if (data["type"] == "credit_purchase") {
              totalCredits += value;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [

                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xff2563EB),
                        Color(0xff60A5FA),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),

                  child: Column(
                    children: [

                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 55,
                      ),

                      const SizedBox(height: 15),

                      const Text(
                        "Total Earnings",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        "Rs ${totalEarnings.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [

                    Expanded(
                      child: _statCard(
                        "Credits",
                        "$totalCredits",
                        Icons.stars,
                        Colors.orange,
                      ),
                    ),

                    const SizedBox(width: 15),

                    Expanded(
                      child: _statCard(
                        "Transactions",
                        docs.length.toString(),
                        Icons.receipt_long,
                        Colors.green,
                      ),
                    ),

                  ],
                ),

                const SizedBox(height: 25),

                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: "Search transaction...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Recent Transactions",
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // PART-2 me yahan realtime transaction list ayegi

              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [

          CircleAvatar(
            backgroundColor: color.withOpacity(.15),
            child: Icon(
              icon,
              color: color,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(title),

        ],
      ),
    );
  }
}