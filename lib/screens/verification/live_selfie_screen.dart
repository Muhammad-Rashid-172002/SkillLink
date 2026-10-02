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

/// Captures a fresh front-camera selfie and stores it privately for the
/// identity review. Pops with `true` once uploaded.
class LiveSelfieScreen extends StatefulWidget {
  const LiveSelfieScreen({super.key});

  @override
  State<LiveSelfieScreen> createState() => _LiveSelfieScreenState();
}

class _LiveSelfieScreenState extends State<LiveSelfieScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selfie;
  bool _uploading = false;
  double _uploadProgress = 0;

  Future<void> _capture() async {
    if (_uploading) return;
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
        maxWidth: 1600,
      );
      if (image == null || !mounted) return;
      setState(() => _selfie = image);
    } on Exception catch (error) {
      debugPrint('Live selfie capture error: $error');
      _showMessage(
        'We couldn’t open the front camera. Allow camera access and try '
        'again.',
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
    if (_selfie == null || _uploading) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path =
          'private_verifications/workers/${user.uid}/live_selfie_$timestamp.jpg';
      // Bytes work on every platform; `File` does not exist on the web.
      final uploadTask = FirebaseStorage.instance
          .ref(path)
          .putData(
            await _selfie!.readAsBytes(),
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: const {
                'documentType': 'live_selfie',
                'captureMethod': 'front_camera',
                'visibility': 'private',
              },
            ),
          );
      uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted || snapshot.totalBytes == 0) return;
        setState(() {
          _uploadProgress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 0.9;
        });
      });
      await uploadTask;
      await FirebaseFirestore.instance
          .collection('verification_requests')
          .doc(user.uid)
          .set({
            'workerId': user.uid,
            'liveSelfiePath': path,
            'selfieCaptureMethod': 'front_camera',
            'liveSelfieCapturedAt': FieldValue.serverTimestamp(),
            'identityStatus': 'not_submitted',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => _uploadProgress = 1);
      _showMessage('Selfie added.');
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Live selfie upload error: $error');
      if (!mounted) return;
      _showMessage(
        'Your selfie couldn’t be uploaded. Check your connection and try '
        'again.',
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
        appBar: AppBar(title: const Text('Live selfie')),
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
                      maxWidth: 520,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Take a quick selfie',
                            style: text.headlineSmall,
                          ),
                          const SizedBox(height: SkillNovaSpacing.xs),
                          Text(
                            'We compare it with the photo on your CNIC to '
                            'confirm it’s really you.',
                            style: text.bodyMedium,
                          ),
                          const SizedBox(height: SkillNovaSpacing.xl),
                          _preview(),
                          const SizedBox(height: SkillNovaSpacing.xl),
                          const ListGroup(
                            title: 'For a quick approval',
                            children: [
                              ListRow(
                                icon: Icons.center_focus_strong_outlined,
                                title: 'Face the camera, whole face in view',
                              ),
                              ListRow(
                                icon: Icons.wb_sunny_outlined,
                                title: 'Use bright, even light',
                              ),
                              ListRow(
                                icon: Icons.visibility_outlined,
                                title: 'No sunglasses, mask or cap',
                              ),
                            ],
                          ),
                          const SizedBox(height: SkillNovaSpacing.md),
                          Text(
                            'Only SkillNova’s verification team can see this '
                            'photo.',
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

  Widget _preview() {
    final colors = Theme.of(context).colorScheme;
    final selfie = _selfie;
    return Center(
      child: Semantics(
        button: true,
        label: selfie == null ? 'Take selfie' : 'Retake selfie',
        child: GestureDetector(
          onTap: _uploading ? null : _capture,
          child: AnimatedContainer(
            duration: SkillNovaMotion.of(context, SkillNovaMotion.medium),
            width: 220,
            height: 280,
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(120),
              border: Border.all(
                color: selfie == null
                    ? colors.outlineVariant
                    : SkillNovaColors.success,
                width: selfie == null ? 1 : 3,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: selfie == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.face_retouching_natural_rounded,
                        size: 56,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(height: SkillNovaSpacing.xs),
                      Text(
                        'Tap to open camera',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      kIsWeb
                          ? Image.network(selfie.path, fit: BoxFit.cover)
                          : Image.file(File(selfie.path), fit: BoxFit.cover),
                      if (_uploading)
                        ColoredBox(
                          color: Colors.black38,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: _uploadProgress == 0
                                  ? null
                                  : _uploadProgress,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _actionBar() {
    final colors = Theme.of(context).colorScheme;
    final captured = _selfie != null;
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
        maxWidth: 520,
        child: captured
            ? Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Retake',
                      icon: Icons.refresh_rounded,
                      fullWidth: true,
                      onPressed: _uploading ? null : _capture,
                    ),
                  ),
                  const SizedBox(width: SkillNovaSpacing.sm),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Use this photo',
                      loading: _uploading,
                      fullWidth: true,
                      onPressed: _upload,
                    ),
                  ),
                ],
              )
            : PrimaryButton(
                label: 'Open camera',
                icon: Icons.photo_camera_front_outlined,
                fullWidth: true,
                onPressed: _capture,
              ),
      ),
    );
  }
}
