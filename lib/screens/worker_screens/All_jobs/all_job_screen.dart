import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AllJobsScreen extends StatelessWidget {
  const AllJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Jobs"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("requests")
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final jobs = snapshot.data!.docs;

          if (jobs.isEmpty) {
            return const Center(
              child: Text("No jobs found"),
            );
          }

          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index].data() as Map<String, dynamic>;

              return ListTile(
                title: Text(job["title"] ?? ""),
                subtitle: Text(job["location"] ?? ""),
                trailing: Text(job["budget"] ?? ""),
                onTap: () {
                  // Job Detail Screen open karo
                },
              );
            },
          );
        },
      ),
    );
  }
}