import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/messages/worker_chat_detail_screen.dart';

/// Compatibility wrapper for notification routes and historical imports.
/// Worker Chat Detail V2 is the single authoritative implementation.
class WorkerChatDetailScreen extends StatelessWidget {
  const WorkerChatDetailScreen({
    super.key,
    required this.chatId,
    required this.customerId,
    required this.customerName,
    required this.service,
    this.requestId = '',
  });

  final String chatId;
  final String customerId;
  final String customerName;
  final String service;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return WorkerChatDetailV2Screen(
      chatId: chatId,
      customerId: customerId,
      customerName: customerName,
      service: service,
      requestId: requestId,
    );
  }
}
