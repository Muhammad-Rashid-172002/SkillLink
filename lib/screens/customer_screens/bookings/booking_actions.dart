import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/Chat/customer_chat_service.dart';
import 'package:skill_link/services/emergency_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'booking_models.dart';

Future<void> openBookingChat(
  BuildContext context,
  CustomerBooking booking,
) async {
  if (booking.workerId.isEmpty) return;
  try {
    final destination = await CustomerChatService().resolveBooking(
      requestId: booking.id,
      workerId: booking.workerId,
      service: booking.service,
      existingChatId: bookingText(booking.data, const ['chatId']),
      workerName: booking.workerName,
      workerPhone: booking.workerPhone,
      workerImageUrl: booking.workerPhoto,
      workerVerified: booking.workerVerified,
    );
    if (!context.mounted) return;
    await CustomerChatNavigator.open(context, destination);
  } catch (_) {
    if (context.mounted) {
      showBookingMessage(
        context,
        'Conversation could not be opened right now.',
      );
    }
  }
}

Future<void> callBookingProfessional(BuildContext context, String phone) async {
  final value = phone.trim();
  if (value.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: value);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else if (context.mounted) {
    showBookingMessage(context, 'The phone dialer is unavailable.');
  }
}

Future<void> sendBookingSos(
  BuildContext context,
  CustomerBooking booking,
) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => const _SosReasonSheet(),
  );
  if (reason == null || !context.mounted) return;
  try {
    await EmergencyService().createEmergencyAlert(
      requestId: booking.id,
      requestData: booking.data,
      workerId: booking.workerId,
      raisedByRole: 'customer',
      jobStatus: booking.data['status']?.toString() ?? '',
      reason: reason,
    );
    if (context.mounted) {
      showBookingMessage(
        context,
        'SOS alert sent to SkillNova safety support.',
      );
    }
  } on EmergencyServiceException catch (error) {
    if (context.mounted) showBookingMessage(context, error.message);
  } catch (_) {
    if (context.mounted) {
      showBookingMessage(
        context,
        'SOS could not be sent. Call Police 15 if needed.',
      );
    }
  }
}

void showBookingMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _SosReasonSheet extends StatelessWidget {
  const _SosReasonSheet();

  @override
  Widget build(BuildContext context) {
    const reasons = [
      'I feel unsafe',
      'Threat or violence',
      'Robbery or theft',
      'Medical emergency',
      'Accident',
      'Other emergency',
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send emergency SOS?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the closest reason. Your current location and active booking will be securely sent to safety support.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: reasons
                  .map(
                    (reason) => ListTile(
                      leading: const Icon(Icons.sos_outlined),
                      title: Text(reason),
                      onTap: () => Navigator.pop(context, reason),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}
