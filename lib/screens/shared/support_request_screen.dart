import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/config/skillnova_support_config.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';

/// In-app message to SkillNova support. Saved to `support_requests` (only the
/// sender and admins can read it) and answered from the admin console.
class SupportRequestScreen extends StatefulWidget {
  const SupportRequestScreen({super.key, this.onSubmit});

  /// Test hook; production writes to Firestore.
  final Future<void> Function(String topic, String message)? onSubmit;

  @override
  State<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _SupportRequestScreenState extends State<SupportRequestScreen> {
  static const _topics = [
    'Booking or job problem',
    'Account or sign-in',
    'Verification',
    'Report a person',
    'App not working',
    'Something else',
  ];

  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  String _topic = _topics.first;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    try {
      final text = _message.text.trim();
      final hook = widget.onSubmit;
      if (hook != null) {
        await hook(_topic, text);
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw StateError('signed-out');
        final profile =
            (await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get())
                .data() ??
            const <String, dynamic>{};
        await FirebaseFirestore.instance.collection('support_requests').add({
          'userId': user.uid,
          'name': profile['name'] ?? user.displayName ?? '',
          'email': user.email ?? '',
          'role': profile['role'] ?? '',
          'subject': _topic,
          'message': text,
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      SkillNovaToast.show(
        context,
        'Message sent. We usually reply within 1–2 working days.',
        tone: SkillNovaTone.success,
      );
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      SkillNovaToast.show(
        context,
        'Your message couldn’t be sent. Check your connection, or email '
        '${SkillNovaSupportConfig.supportEmail}.',
        tone: SkillNovaTone.error,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Message support')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(SkillNovaSpacing.gutter),
            children: [
              Text(
                'Tell us what happened. A real person from SkillNova will '
                'reply by email.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: SkillNovaSpacing.lg),
              Text('What is it about?', style: theme.textTheme.titleSmall),
              const SizedBox(height: SkillNovaSpacing.xs),
              Wrap(
                spacing: SkillNovaSpacing.xs,
                runSpacing: SkillNovaSpacing.xs,
                children: [
                  for (final topic in _topics)
                    ChoiceChip(
                      label: Text(topic),
                      selected: _topic == topic,
                      onSelected: (_) => setState(() => _topic = topic),
                    ),
                ],
              ),
              const SizedBox(height: SkillNovaSpacing.lg),
              TextFormField(
                controller: _message,
                minLines: 5,
                maxLines: 10,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Your message',
                  hintText: 'For example: my worker has not arrived yet',
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value?.trim().length ?? 0) < 10
                    ? 'Please write at least a short sentence (10 letters).'
                    : null,
              ),
              const SizedBox(height: SkillNovaSpacing.lg),
              PrimaryButton(
                label: 'Send message',
                icon: Icons.send_rounded,
                fullWidth: true,
                loading: _sending,
                onPressed: _submit,
              ),
              const SizedBox(height: SkillNovaSpacing.md),
              Text(
                'Or email ${SkillNovaSupportConfig.supportEmail}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
