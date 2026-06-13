import 'package:flutter/material.dart';

class WorkerTile extends StatelessWidget {
  final String name;
  final String skill;
  final String rating;

  const WorkerTile({
    super.key,
    required this.name,
    required this.skill,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          radius: 24,
          child: Icon(Icons.person),
        ),
        title: Text(name),
        subtitle: Text(skill),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star,
                color: Colors.orange, size: 18),
            Text(rating),
          ],
        ),
      ),
    );
  }
}