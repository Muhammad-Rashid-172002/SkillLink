import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';
import 'package:skill_link/design_system/widgets/skillnova_text_field.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String credits;
  final String price;

  const PaymentMethodScreen({
    super.key,
    required this.credits,
    required this.price,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  static const String _bankName = 'Bank Alfalah';
  static const String _accountHolder = 'Muhammad Rashid';
  static const String _accountNumber = '57635002775917';

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _transactionController = TextEditingController();

  XFile? _receipt;
  bool _submitting = false;

  int get _credits => int.tryParse(widget.credits) ?? 0;
  int get _amount =>
      int.tryParse(widget.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  void dispose() {
    _transactionController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (image == null || !mounted) return;
      setState(() => _receipt = image);
    } catch (_) {
      if (mounted) _snack('Unable to select receipt.', error: true);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final user = FirebaseAuth.instance.currentUser;
    final transactionId = _transactionController.text.trim();

    if (user == null) {
      _snack('Please sign in again.', error: true);
      return;
    }
    if (_credits <= 0 || _amount <= 0) {
      _snack('Invalid package information.', error: true);
      return;
    }
    if (transactionId.isEmpty) {
      _snack('Enter the transaction ID from your receipt.', error: true);
      return;
    }
    if (_receipt == null) {
      _snack('Add a photo or screenshot of your receipt.', error: true);
      return;
    }

    setState(() => _submitting = true);
    Reference? uploadedRef;

    try {
      final db = FirebaseFirestore.instance;

      final pending = await db
          .collection('payment_requests')
          .where('workerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (pending.docs.isNotEmpty) {
        throw Exception(
          'You already have a payment request waiting for approval.',
        );
      }

      final duplicate = await db
          .collection('payment_requests')
          .where('transactionId', isEqualTo: transactionId)
          .limit(1)
          .get();

      if (duplicate.docs.isNotEmpty) {
        throw Exception('This transaction ID has already been submitted.');
      }

      final requestRef = db.collection('payment_requests').doc();
      final extension = _receipt!.name.toLowerCase().endsWith('.png')
          ? 'png'
          : 'jpg';
      final receiptPath =
          'payment_receipts/${user.uid}/${requestRef.id}.$extension';

      uploadedRef = FirebaseStorage.instance.ref(receiptPath);
      // Bytes work on every platform; `File` does not exist on the web.
      await uploadedRef.putData(
        await _receipt!.readAsBytes(),
        SettableMetadata(
          contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
          customMetadata: {'workerId': user.uid, 'requestId': requestRef.id},
        ),
      );

      final userDoc = await db.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? <String, dynamic>{};

      await requestRef.set({
        'workerId': user.uid,
        'workerName': (userData['name'] ?? user.displayName ?? '').toString(),
        'workerEmail': (user.email ?? userData['email'] ?? '').toString(),
        'credits': _credits,
        'amount': _amount,
        'currency': 'PKR',
        'paymentMethod': 'bank_transfer',
        'bankName': _bankName,
        'transactionId': transactionId,
        'receiptPath': receiptPath,
        'status': 'pending',
        'creditsAdded': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'approvedAt': null,
        'approvedBy': null,
        'rejectedAt': null,
        'rejectedBy': null,
        'rejectionReason': null,
      });

      if (!mounted) return;
      _snack('Payment submitted for review.');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (uploadedRef != null) {
        try {
          await uploadedRef.delete();
        } catch (_) {}
      }
      if (mounted) {
        _snack(
          e is FirebaseException
              ? 'Your payment couldn’t be submitted. Check your connection '
                    'and try again.'
              : e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Pay for credits')),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    SkillNovaSpacing.gutter,
                    SkillNovaSpacing.xs,
                    SkillNovaSpacing.gutter,
                    SkillNovaSpacing.xl,
                  ),
                  child: ContentWidth(
                    maxWidth: 560,
                    child: AbsorbPointer(
                      absorbing: _submitting,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _summary(),
                          const SizedBox(height: SkillNovaSpacing.xl),
                          _step(1, 'Transfer the amount'),
                          _bankDetails(),
                          const SizedBox(height: SkillNovaSpacing.xl),
                          _step(2, 'Add your payment proof'),
                          SkillNovaTextField(
                            label: 'Transaction ID',
                            controller: _transactionController,
                            hint: 'As shown on your receipt',
                            prefixIcon: Icons.tag_rounded,
                            textInputAction: TextInputAction.done,
                          ),
                          const SizedBox(height: SkillNovaSpacing.md),
                          _receiptPicker(),
                          const SizedBox(height: SkillNovaSpacing.lg),
                          Text(
                            'Our team checks each payment manually. Credits '
                            'are added as soon as yours is approved.',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary() {
    final text = Theme.of(context).textTheme;
    return SkillNovaCard(
      child: Row(
        children: [
          const IconTile(icon: Icons.bolt_rounded, size: 48),
          const SizedBox(width: SkillNovaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_credits lead credits', style: text.titleMedium),
                Text('Bank transfer', style: text.bodySmall),
              ],
            ),
          ),
          Text('Rs. $_amount', style: text.titleLarge),
        ],
      ),
    );
  }

  Widget _step(int number, String title) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: SkillNovaSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: colors.primary,
            child: Text(
              '$number',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: colors.onPrimary),
            ),
          ),
          const SizedBox(width: SkillNovaSpacing.sm),
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }

  Widget _bankDetails() {
    return ListGroup(
      children: [
        const ListRow(
          icon: Icons.account_balance_outlined,
          title: _bankName,
          subtitle: 'Bank',
        ),
        const ListRow(
          icon: Icons.person_outline_rounded,
          title: _accountHolder,
          subtitle: 'Account holder',
        ),
        ListRow(
          icon: Icons.numbers_rounded,
          title: _accountNumber,
          subtitle: 'Account number',
          trailing: TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: _accountNumber),
              );
              if (mounted) _snack('Account number copied.');
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
          ),
        ),
      ],
    );
  }

  Widget _receiptPicker() {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final receipt = _receipt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkillNovaFieldLabel('Receipt'),
        Semantics(
          button: true,
          label: receipt == null ? 'Add receipt photo' : 'Change receipt photo',
          child: InkWell(
            onTap: _pickReceipt,
            borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SkillNovaSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                children: [
                  if (receipt == null)
                    const IconTile(icon: Icons.upload_file_rounded)
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        SkillNovaRadius.xsmall,
                      ),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: kIsWeb
                            ? Image.network(receipt.path, fit: BoxFit.cover)
                            : Image.file(File(receipt.path), fit: BoxFit.cover),
                      ),
                    ),
                  const SizedBox(width: SkillNovaSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receipt == null ? 'Add receipt' : 'Receipt added',
                          style: text.titleSmall,
                        ),
                        Text(
                          receipt == null
                              ? 'A clear screenshot or photo'
                              : 'Tap to choose a different one',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (receipt != null)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: SkillNovaColors.success,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(
        SkillNovaSpacing.gutter,
        SkillNovaSpacing.sm,
        SkillNovaSpacing.gutter,
        SkillNovaSpacing.sm,
      ),
      child: ContentWidth(
        maxWidth: 560,
        child: PrimaryButton(
          label: 'Submit payment',
          loading: _submitting,
          fullWidth: true,
          onPressed: _submit,
        ),
      ),
    );
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    SkillNovaToast.show(
      context,
      message,
      tone: error ? SkillNovaTone.error : SkillNovaTone.success,
    );
  }
}
