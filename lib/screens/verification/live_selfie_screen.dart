import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class LiveSelfieScreen extends StatefulWidget {
  const LiveSelfieScreen({super.key});

  @override
  State<LiveSelfieScreen> createState() => _LiveSelfieScreenState();
}

class _LiveSelfieScreenState extends State<LiveSelfieScreen> {
  final _picker = ImagePicker();
  XFile? _selfie;
  bool _uploading = false;

  Future<void> _capture() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;
    setState(() => _selfie = image);
  }

  Future<void> _upload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selfie == null || _uploading) return;

    setState(() => _uploading = true);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path =
          'private_verifications/workers/${user.uid}/live_selfie_$timestamp.jpg';

      await FirebaseStorage.instance
          .ref(path)
          .putFile(
            File(_selfie!.path),
            SettableMetadata(contentType: 'image/jpeg'),
          );

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
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      _message(e.message ?? 'Unable to upload selfie.', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error
            ? const Color(0xFFDC2626)
            : const Color(0xFF16A34A),
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Live Selfie'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Take a fresh selfie',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Face the camera directly, remove sunglasses or masks, and use good lighting.',
            style: TextStyle(color: Color(0xFF64748B), height: 1.45),
          ),
          const SizedBox(height: 22),
          Container(
            height: 360,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: _selfie == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 150,
                        height: 190,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(.08),
                          borderRadius: BorderRadius.circular(75),
                          border: Border.all(
                            color: const Color(0xFF10B981),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.face_rounded,
                          size: 85,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _capture,
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Open front camera'),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(_selfie!.path), fit: BoxFit.cover),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: FilledButton.icon(
                          onPressed: _capture,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retake'),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Important: this screen enforces a fresh camera capture, but it is not advanced anti-spoof liveness. Blink/head-turn challenges or a certified liveness provider should be added later.',
              style: TextStyle(color: Color(0xFF92400E), height: 1.4),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
              onPressed: (_selfie == null || _uploading) ? null : _upload,
              icon: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.shield_outlined),
              label: const Text('Securely upload selfie'),
            ),
          ),
        ],
      ),
    );
  }
}
