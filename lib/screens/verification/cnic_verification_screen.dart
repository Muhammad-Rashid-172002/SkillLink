import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CnicVerificationScreen extends StatefulWidget {
  const CnicVerificationScreen({super.key});

  @override
  State<CnicVerificationScreen> createState() => _CnicVerificationScreenState();
}

class _CnicVerificationScreenState extends State<CnicVerificationScreen> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF0F9D73);
  static const Color _primaryDark = Color(0xFF087A59);
  static const Color _secondary = Color(0xFF14B8A6);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _warning = Color(0xFFF59E0B);

  final ImagePicker _picker = ImagePicker();

  XFile? _front;
  XFile? _back;
  bool _uploading = false;
  double _uploadProgress = 0;

  bool get _canUpload => _front != null && _back != null && !_uploading;

  int get _completedSteps {
    var count = 0;
    if (_front != null) count++;
    if (_back != null) count++;
    return count;
  }

  Future<void> _capture({required bool isFront}) async {
    if (_uploading) return;

    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 1800,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image == null || !mounted) return;

      setState(() {
        if (isFront) {
          _front = image;
        } else {
          _back = image;
        }
      });
    } on Exception catch (error) {
      if (!mounted) return;
      _showMessage(
        'Camera open nahi ho saka. Permission aur device camera check karein.',
        isError: true,
      );
      debugPrint('CNIC camera error: $error');
    }
  }

  Future<void> _upload() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Session expire ho gayi hai. Dobara login karein.',
        isError: true,
      );
      return;
    }

    if (_front == null || _back == null || _uploading) {
      _showMessage(
        'CNIC front aur back dono images capture karein.',
        isError: true,
      );
      return;
    }

    final confirmed = await _showUploadConfirmation();
    if (!confirmed || !mounted) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final basePath = 'private_verifications/workers/${user.uid}';

      final frontPath = '$basePath/cnic_front_$timestamp.jpg';
      final backPath = '$basePath/cnic_back_$timestamp.jpg';

      await _uploadFile(
        file: File(_front!.path),
        storagePath: frontPath,
        progressStart: 0,
        progressEnd: 0.45,
      );

      await _uploadFile(
        file: File(_back!.path),
        storagePath: backPath,
        progressStart: 0.45,
        progressEnd: 0.90,
      );

      if (mounted) {
        setState(() => _uploadProgress = 0.94);
      }

      await FirebaseFirestore.instance
          .collection('verification_requests')
          .doc(user.uid)
          .set({
            'workerId': user.uid,
            'cnicFrontPath': frontPath,
            'cnicBackPath': backPath,
            'cnicCapturedAt': FieldValue.serverTimestamp(),
            'identityStatus': 'not_submitted',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() => _uploadProgress = 1);

      await _showSuccessDialog();

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.message ?? 'CNIC upload nahi ho saka. Dobara try karein.',
        isError: true,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Unexpected error aya hai. Dobara try karein.',
        isError: true,
      );
      debugPrint('CNIC upload error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  Future<void> _uploadFile({
    required File file,
    required String storagePath,
    required double progressStart,
    required double progressEnd,
  }) async {
    final task = FirebaseStorage.instance
        .ref(storagePath)
        .putFile(
          file,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: const {
              'documentType': 'cnic',
              'visibility': 'private',
            },
          ),
        );

    task.snapshotEvents.listen((snapshot) {
      if (!mounted || snapshot.totalBytes == 0) return;

      final currentProgress = snapshot.bytesTransferred / snapshot.totalBytes;
      final scaledProgress =
          progressStart + ((progressEnd - progressStart) * currentProgress);

      setState(() => _uploadProgress = scaledProgress);
    });

    await task;
  }

  Future<bool> _showUploadConfirmation() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260F172A),
                  blurRadius: 34,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_primary, _secondary],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Submit CNIC for verification?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Make sure both images are clear, readable and belong to you. After submission, the admin will review your documents.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: const Text(
                          'Review Again',
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: _primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        icon: const Icon(Icons.lock_rounded, size: 18),
                        label: const Text(
                          'Secure Upload',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260F172A),
                  blurRadius: 36,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: _primary,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'CNIC uploaded securely',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your documents have been saved securely. Continue the remaining verification steps.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.all(16),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              color: isError ? _danger : _primary,
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: (isError ? _danger : _primary).withOpacity(0.26),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 21,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _completedSteps / 2;

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: -130,
            right: -95,
            child: _ambientCircle(size: 280, color: _primary.withOpacity(0.10)),
          ),
          Positioned(
            bottom: -150,
            left: -110,
            child: _ambientCircle(
              size: 310,
              color: _secondary.withOpacity(0.07),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    children: [
                      _buildHero(progress),
                      const SizedBox(height: 18),
                      _buildGuidelinesCard(),
                      const SizedBox(height: 18),
                      _buildImageCard(
                        title: 'CNIC Front Side',
                        subtitle:
                            'Capture the side containing your photo and CNIC number.',
                        badge: 'STEP 1',
                        file: _front,
                        icon: Icons.badge_outlined,
                        onTap: () => _capture(isFront: true),
                      ),
                      const SizedBox(height: 15),
                      _buildImageCard(
                        title: 'CNIC Back Side',
                        subtitle:
                            'Capture the address and issue details side clearly.',
                        badge: 'STEP 2',
                        file: _back,
                        icon: Icons.credit_card_rounded,
                        onTap: () => _capture(isFront: false),
                      ),
                      const SizedBox(height: 18),
                      _buildPrivacyCard(),
                      const SizedBox(height: 22),
                      _buildUploadButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_uploading) _buildBlockingLoader(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _uploading ? null : () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x080F172A),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: _textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CNIC Verification',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.45,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Secure identity document upload',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_primary, _secondary]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDark, _primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -45,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'IDENTITY CHECK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '$_completedSteps/2 READY',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Verify your CNIC securely',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Capture both sides of your original CNIC to continue worker verification.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.84),
                  fontSize: 11.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.16),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelinesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: _warning, size: 20),
              SizedBox(width: 8),
              Text(
                'Before you capture',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _guidelineRow(
            Icons.crop_free_rounded,
            'Keep all four corners visible',
          ),
          _guidelineRow(
            Icons.wb_sunny_outlined,
            'Use good lighting and avoid glare',
          ),
          _guidelineRow(
            Icons.visibility_outlined,
            'Make sure text and photo are readable',
          ),
          _guidelineRow(
            Icons.block_rounded,
            'Do not upload a photocopy or screenshot',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _guidelineRow(IconData icon, String text, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 11),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard({
    required String title,
    required String subtitle,
    required String badge,
    required XFile? file,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final selected = file != null;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: selected ? _primary.withOpacity(0.35) : _border,
          width: selected ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 16, 17, 14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: _primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 9.7,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? _primary.withOpacity(0.10)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      selected ? 'READY' : badge,
                      style: TextStyle(
                        color: selected ? _primary : _textSecondary,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: selected
                  ? const Color(0xFFF8FAFC)
                  : const Color(0xFFFAFCFE),
              child: InkWell(
                onTap: _uploading ? null : onTap,
                child: SizedBox(
                  height: 230,
                  width: double.infinity,
                  child: selected
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(file.path), fit: BoxFit.cover),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.12),
                                      Colors.black.withOpacity(0.50),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: _primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'Captured',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 14,
                              child: FilledButton.icon(
                                onPressed: _uploading ? null : onTap,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(
                                    0.94,
                                  ),
                                  foregroundColor: _textPrimary,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Retake Photo',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 82,
                              height: 82,
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 38,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Open Camera',
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Tap here to capture this CNIC side',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 10.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    color: _primary,
                                    size: 15,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Secure capture',
                                    style: TextStyle(
                                      color: _primary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_person_outlined, color: Color(0xFF2563EB), size: 23),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your documents stay private',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Only private Firebase Storage paths are saved. Public download URLs are not stored in Firestore.',
                  style: TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 10,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton.icon(
            onPressed: _canUpload ? _upload : null,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: const Color(0xFFD8E2E8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(19),
              ),
              elevation: 0,
            ),
            icon: Icon(
              _canUpload
                  ? Icons.cloud_upload_rounded
                  : Icons.lock_outline_rounded,
              size: 20,
            ),
            label: Text(
              _canUpload
                  ? 'Securely Upload CNIC'
                  : 'Capture Both Sides to Continue',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Your submission will be reviewed by the SkillNova admin team.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBlockingLoader() {
    final percent = (_uploadProgress * 100).clamp(0, 100).round();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.50),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 34),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 34,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 82,
                    height: 82,
                    child: CircularProgressIndicator(
                      value: _uploadProgress > 0 ? _uploadProgress : null,
                      strokeWidth: 7,
                      color: _primary,
                      backgroundColor: _primary.withOpacity(0.10),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Uploading securely...',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Please keep the app open while your CNIC images are being uploaded.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ambientCircle({required double size, required Color color}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
