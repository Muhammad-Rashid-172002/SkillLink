import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

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
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF14B8A6);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

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
      _snack('Please enter transaction ID.', error: true);
      return;
    }
    if (_receipt == null) {
      _snack('Please upload payment receipt.', error: true);
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
      final extension = _receipt!.path.toLowerCase().endsWith('.png')
          ? 'png'
          : 'jpg';
      final receiptPath =
          'payment_receipts/${user.uid}/${requestRef.id}.$extension';

      uploadedRef = FirebaseStorage.instance.ref(receiptPath);
      await uploadedRef.putFile(
        File(_receipt!.path),
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
      _snack('Payment submitted. Waiting for admin approval.');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (uploadedRef != null) {
        try {
          await uploadedRef.delete();
        } catch (_) {}
      }
      if (mounted) {
        _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _packageCard(),
                    const SizedBox(height: 24),
                    _section(
                      Icons.account_balance_outlined,
                      'Bank Transfer',
                      'Transfer payment to the account below',
                    ),
                    const SizedBox(height: 14),
                    _bankCard(),
                    const SizedBox(height: 24),
                    _section(
                      Icons.receipt_long_outlined,
                      'Payment Proof',
                      'Enter transaction ID and upload receipt',
                    ),
                    const SizedBox(height: 14),
                    _proofCard(),
                    const SizedBox(height: 18),
                    _note(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
    ),
    child: Row(
      children: [
        IconButton.filledTonal(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Method',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Complete your credit package payment',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.lock_outline_rounded, color: _primary),
      ],
    ),
  );

  Widget _packageCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [_primary, _secondary]),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 33,
          backgroundColor: Color(0x28FFFFFF),
          child: Icon(Icons.toll_rounded, color: Colors.white, size: 33),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.credits} Credits',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'SkillNova worker credit package',
                style: TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Text(
          widget.price,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _section(IconData icon, String title, String subtitle) => Row(
    children: [
      Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: _primary.withOpacity(.09),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: _primary, size: 19),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _bankCard() => _whiteCard(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFFDC2626),
              child: Icon(Icons.account_balance_rounded, color: Colors.white),
            ),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _bankName,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manual bank transfer',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ACCOUNT HOLDER',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                _accountHolder,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Divider(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACCOUNT NUMBER',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 5),
                        SelectableText(
                          _accountNumber,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () async {
                      await Clipboard.setData(
                        const ClipboardData(text: _accountNumber),
                      );
                      if (mounted) {
                        _snack('Account number copied.');
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, color: _primary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        Text(
          'Transfer exactly ${widget.price} and keep your receipt.',
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _proofCard() => _whiteCard(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaction ID',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Use the bank reference number shown on your receipt.',
          style: TextStyle(
            color: _textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _transactionController,
          enabled: !_submitting,
          decoration: InputDecoration(
            hintText: 'Example: TXN123456789',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: const Icon(Icons.tag_rounded, color: _primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 18),
        InkWell(
          onTap: _submitting ? null : _pickReceipt,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _receipt == null
                  ? const Color(0xFFF8FAFC)
                  : _primary.withOpacity(.07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _receipt == null ? _border : _primary),
            ),
            child: _receipt == null
                ? const Column(
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        color: _primary,
                        size: 38,
                      ),
                      SizedBox(height: 9),
                      Text(
                        'Upload payment receipt',
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tap to select from gallery',
                        style: TextStyle(color: _textSecondary, fontSize: 9.5),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.file(
                          File(_receipt!.path),
                          height: 66,
                          width: 66,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Receipt selected\nTap to replace it',
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w800,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const Icon(Icons.check_circle_rounded, color: _primary),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );

  Widget _note() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFF59E0B).withOpacity(.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(.18)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: Color(0xFFF59E0B)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Credits are added only after admin verification. '
            'Fake payment proof may result in account suspension.',
            style: TextStyle(
              color: Color(0xFF92400E),
              fontSize: 9.7,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _whiteCard(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _border),
    ),
    child: child,
  );

  Widget _bottomBar() => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: _border)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 58,
        child: ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            disabledBackgroundColor: _primary.withOpacity(.55),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  height: 23,
                  width: 23,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file_rounded),
                    SizedBox(width: 9),
                    Text(
                      'Submit Payment Proof',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? const Color(0xFFDC2626) : _primary,
        content: Text(message),
      ),
    );
  }
}
