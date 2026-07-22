import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Map/worker_job_detail.dart';

class JobsByStatusScreen extends StatelessWidget {
  final String title;
  final String status;

  const JobsByStatusScreen({
    super.key,
    required this.title,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    Query query = FirebaseFirestore.instance.collection("requests");

    if (status == "searching") {
      query = query.where("status", isEqualTo: "searching");
    } else {
      query = query
          .where("workerId", isEqualTo: uid)
          .where(
            "status",
            whereIn: ["accepted", "on_the_way", "in_progress"],
          );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkerJobDetailScreen(
                        requestId: jobs[index].id,
                        title: job["title"] ?? "",
                        category: job["category"] ?? "",
                        location: job["location"] ?? "",
                        distance: "Nearby",
                        budget: job["budget"] ?? "",
                        urgency: job["urgency"] ?? "",
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}