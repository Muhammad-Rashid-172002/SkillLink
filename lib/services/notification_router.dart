import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/core/auth/auth_session_service.dart';
import 'package:skill_link/core/auth/user_role.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_detail_screen.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_detail_screen.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_detail_screen.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_lead_detail_screen.dart';
import 'package:skill_link/screens/worker_screens/menuTiles/ReviewsScreen.dart';
import 'package:skill_link/screens/worker_screens/messages/worker_chat_detail_screen.dart';

/// Decides where a notification leads, for both push-notification taps and
/// the in-app notification center, so the two can never disagree.
///
/// Role-specific destinations are only returned for a role verified against
/// Firestore, never for one inferred from the notification payload.
abstract final class NotificationRouter {
  static Future<Widget?> destinationFor(Map<String, dynamic> data) async {
    final type = _text(data['type']).toLowerCase();
    final requestId = _text(data['requestId']);

    if (type == 'chat') return _chat(_text(data['chatId']));

    final role = await _verifiedRole();
    if (role == null) return null;

    if (type == 'review') {
      return role == UserRole.worker ? const ReviewsRatingsScreen() : null;
    }

    if (requestId.isEmpty) return null;

    if (role == UserRole.customer) {
      // Every request-related update (accepted, on the way, completed, ...)
      // opens the booking, where tracking and rating live.
      return BookingDetailScreen(requestId: requestId);
    }

    if (role == UserRole.worker) {
      final snapshot = await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .get();
      if (!snapshot.exists) return null;
      final data = snapshot.data() ?? const <String, dynamic>{};
      final status = _text(data['status']).toLowerCase().replaceAll(' ', '_');
      final assignedToMe =
          _text(data['workerId']) == FirebaseAuth.instance.currentUser?.uid;
      return status == 'searching' || !assignedToMe
          ? WorkerLeadDetailScreen(requestId: requestId)
          : WorkerJobDetailV2Screen(requestId: requestId);
    }
    return null;
  }

  static Future<UserRole?> _verifiedRole() async {
    final service = AuthSessionService.instance;
    if (service.verifiedRole.value != null) return service.verifiedRole.value;
    if (FirebaseAuth.instance.currentUser == null) return null;
    final session = await service.resolve();
    return session.stage == SessionStage.home ? session.role : null;
  }

  static Future<Widget?> _chat(String chatId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (chatId.isEmpty || uid == null) return null;
    final firestore = FirebaseFirestore.instance;
    final chat = (await firestore.collection('chats').doc(chatId).get()).data();
    if (chat == null) return null;
    final customerId = _text(chat['customerId']);
    final workerId = _text(chat['workerId']);
    final service = _first(chat, const ['service', 'workerSkill'], 'Service');
    if (customerId.isEmpty || workerId.isEmpty) return null;

    if (uid == workerId) {
      final customer =
          (await firestore.collection('users').doc(customerId).get()).data() ??
          const <String, dynamic>{};
      return WorkerChatDetailV2Screen(
        chatId: chatId,
        customerId: customerId,
        customerName: _first(customer, const ['name', 'fullName'], 'Customer'),
        service: service,
      );
    }

    if (uid == customerId) {
      final worker =
          (await firestore.collection('users').doc(workerId).get()).data() ??
          const <String, dynamic>{};
      final phone = _first(worker, const ['phone', 'phoneNumber'], '');
      final image = _first(worker, const ['profileImageUrl', 'photoUrl'], '');
      return ChatDetailScreen(
        chatId: chatId,
        workerId: workerId,
        workerName: _first(worker, const ['name', 'fullName'], 'Worker'),
        workerSkill: _first(worker, const [
          'skill',
          'service',
          'category',
        ], service),
        workerPhone: phone.isEmpty ? null : phone,
        workerImageUrl: image.isEmpty ? null : image,
        workerVerified:
            UserRole.tryParse(worker['role']) == UserRole.worker &&
            worker['identityVerificationStatus'] == 'approved',
      );
    }
    return null;
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';

  static String _first(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = _text(data[key]);
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }
}
