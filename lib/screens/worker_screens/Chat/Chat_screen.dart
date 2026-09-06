import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/messages/worker_messages_screen.dart';

/// Compatibility wrapper for historical imports.
/// Worker Messages V2 is the single authoritative implementation.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) => const WorkerMessagesScreen();
}
