import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    print(uid);
    print("Current UID: $uid");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          TextButton(
            onPressed: () async {
              final snapshot = await FirebaseFirestore.instance
                  .collection("notifications")
                  .where("userId", isEqualTo: uid)
                  .where("isRead", isEqualTo: false)
                  .get();

              for (final doc in snapshot.docs) {
                doc.reference.update({"isRead": true});
              }
            },
            child: const Text("Mark All"),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("notifications")
            .where("userId", isEqualTo: uid)
            .orderBy("createdAt", descending: true)
            .snapshots(),
            

        builder: (context, snapshot) {
          // 🔴 Firestore Error
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          // ⏳ Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Data nahi aya
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Empty notifications
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications"));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              IconData icon = Icons.notifications;
              Color color = Colors.green;

              final title = data["title"] ?? "";

              if (title.toLowerCase().contains("chat")) {
                icon = Icons.chat_bubble_rounded;
                color = Colors.blue;
              } else if (title.toLowerCase().contains("payment")) {
                icon = Icons.account_balance_wallet_rounded;
                color = Colors.orange;
              } else if (title.toLowerCase().contains("job") ||
                  title.toLowerCase().contains("worker") ||
                  title.toLowerCase().contains("work")) {
                icon = Icons.work_rounded;
                color = Colors.green;
              }

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 25),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await doc.reference.delete();
                },
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: color.withOpacity(.15),
                      child: Icon(icon, color: color),
                    ),
                    title: Text(
                      data["title"] ?? "",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(data["message"] ?? ""),
                        const SizedBox(height: 8),
                        Text(
                          timeAgo(data["createdAt"]),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    trailing: data["isRead"] == true
                        ? null
                        : Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                    onTap: () async {
                      await doc.reference.update({"isRead": true});

                      // TODO: Open Job/Chat/Wallet Screen
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String timeAgo(Timestamp? ts) {
    if (ts == null) return "";

    final diff = DateTime.now().difference(ts.toDate());

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "${diff.inHours} hr ago";
    if (diff.inDays < 7) return "${diff.inDays} day ago";

    return "${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}";
  }
}
