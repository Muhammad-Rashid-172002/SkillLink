import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';

/// Captures both sides of the worker's CNIC and stores them privately for the
/// identity review. Pops with `true` once uploaded.
class CnicVerificationScreen extends StatefulWidget {
  const CnicVerificationScreen({super.key});

  @override
  State<CnicVerificationScreen> createState() => _CnicVerificationScreenState();
}

class _CnicVerificationScreenState extends State<CnicVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _front;
  XFile? _back;
  bool _uploading = false;
  double _uploadProgress = 0;

  bool get _canUpload => _front != null && _back != null && !_uploading;

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
      setState(() => isFront ? _front = image : _back = image);
    } on Exception catch (error) {
      debugPrint('CNIC camera error: $error');
      _showMessage(
        'We couldn’t open the camera. Allow camera access and try again.',
        isError: true,
      );
    }
  }

  Future<void> _upload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage(
        'Your session has ended. Please sign in again.',
        isError: true,
      );
      return;
    }
    if (!_canUpload) return;

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
        image: _front!,
        storagePath: frontPath,
        progressStart: 0,
        progressEnd: 0.45,
      );
      await _uploadFile(
        image: _back!,
        storagePath: backPath,
        progressStart: 0.45,
        progressEnd: 0.9,
      );
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
      _showMessage('CNIC added.');
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('CNIC upload error: $error');
      if (!mounted) return;
      _showMessage(
        'Your CNIC photos couldn’t be uploaded. Check your connection and '
        'try again.',
        isError: true,
      );
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
    required XFile image,
    required String storagePath,
    required double progressStart,
    required double progressEnd,
  }) async {
    // Bytes work on every platform; `File` does not exist on the web.
    final task = FirebaseStorage.instance
        .ref(storagePath)
        .putData(
          await image.readAsBytes(),
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
      final current = snapshot.bytesTransferred / snapshot.totalBytes;
      setState(
        () => _uploadProgress =
            progressStart + (progressEnd - progressStart) * current,
      );
    });
    await task;
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    SkillNovaToast.show(
      context,
      text,
      tone: isError ? SkillNovaTone.error : SkillNovaTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_uploading,
      child: Scaffold(
        appBar: AppBar(title: const Text('CNIC photos')),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    SkillNovaSpacing.gutter,
                    SkillNovaSpacing.xs,
                    SkillNovaSpacing.gutter,
                    SkillNovaSpacing.xl,
                  ),
                  children: [
                    ContentWidth(
                      maxWidth: 560,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Photograph your CNIC',
                            style: text.headlineSmall,
                          ),
                          const SizedBox(height: SkillNovaSpacing.xs),
                          Text(
                            'Use your original card — not a photocopy or a '
                            'screenshot. Both sides are needed.',
                            style: text.bodyMedium,
                          ),
                          const SizedBox(height: SkillNovaSpacing.xl),
                          _CardSlot(
                            label: 'Front side',
                            hint: 'The side with your photo',
                            image: _front,
                            busy: _uploading,
                            onCapture: () => _capture(isFront: true),
                          ),
                          const SizedBox(height: SkillNovaSpacing.md),
                          _CardSlot(
                            label: 'Back side',
                            hint: 'The side with the address',
                            image: _back,
                            busy: _uploading,
                            onCapture: () => _capture(isFront: false),
                          ),
                          if (_uploading) ...[
                            const SizedBox(height: SkillNovaSpacing.lg),
                            Semantics(
                              label: 'Uploading CNIC photos',
                              value: '${(_uploadProgress * 100).round()}%',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _uploadProgress == 0
                                      ? null
                                      : _uploadProgress,
                                  minHeight: 6,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: SkillNovaSpacing.xl),
                          const ListGroup(
                            title: 'For a quick approval',
                            children: [
                              ListRow(
                                icon: Icons.crop_free_rounded,
                                title: 'All four corners visible',
                              ),
                              ListRow(
                                icon: Icons.wb_sunny_outlined,
                                title: 'Bright light, no glare or blur',
                              ),
                              ListRow(
                                icon: Icons.text_fields_rounded,
                                title: 'Name and CNIC number readable',
                              ),
                            ],
                          ),
                          const SizedBox(height: SkillNovaSpacing.md),
                          Text(
                            'Only SkillNova’s verification team can see these '
                            'photos.',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _actionBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBar() {
    final colors = Theme.of(context).colorScheme;
    final remaining = [_front, _back].where((image) => image == null).length;
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
          label: remaining == 0
              ? 'Upload photos'
              : 'Add $remaining more side${remaining == 1 ? '' : 's'}',
          loading: _uploading,
          fullWidth: true,
          onPressed: _canUpload ? _upload : null,
        ),
      ),
    );
  }
}

/// A card-shaped (85.6 × 54 mm) capture frame for one side of the CNIC.
class _CardSlot extends StatelessWidget {
  const _CardSlot({
    required this.label,
    required this.hint,
    required this.image,
    required this.busy,
    required this.onCapture,
  });

  final String label;
  final String hint;
  final XFile? image;
  final bool busy;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final captured = image != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: text.titleSmall),
            const SizedBox(width: SkillNovaSpacing.xs),
            if (captured)
              const StatusBadge(
                label: 'Added',
                tone: SkillNovaTone.success,
                icon: Icons.check_rounded,
              ),
            const Spacer(),
            if (captured)
              TextButton(
                onPressed: busy ? null : onCapture,
                child: const Text('Retake'),
              ),
          ],
        ),
        const SizedBox(height: SkillNovaSpacing.xs),
        Semantics(
          button: true,
          label: captured ? 'Retake $label' : 'Photograph $label',
          child: InkWell(
            onTap: busy ? null : onCapture,
            borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
            child: AspectRatio(
              aspectRatio: 85.6 / 54,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
                  border: Border.all(
                    color: captured
                        ? SkillNovaColors.success
                        : colors.outlineVariant,
                    width: captured ? 2 : 1,
                  ),
                ),
                child: captured
                    ? (kIsWeb
                          ? Image.network(image!.path, fit: BoxFit.cover)
                          : Image.file(File(image!.path), fit: BoxFit.cover))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 32,
                            color: colors.primary,
                          ),
                          const SizedBox(height: SkillNovaSpacing.xs),
                          Text('Tap to photograph', style: text.labelLarge),
                          Text(hint, style: text.bodySmall),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
