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
  final _picker = ImagePicker();
  XFile? _front;
  XFile? _back;
  bool _uploading = false;

  Future<void> _capture(bool front) async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (image == null || !mounted) return;
    setState(() {
      if (front) {
        _front = image;
      } else {
        _back = image;
      }
    });
  }

  Future<void> _upload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _front == null || _back == null || _uploading) return;

    setState(() => _uploading = true);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final base = 'private_verifications/workers/${user.uid}';
      final frontPath = '$base/cnic_front_$timestamp.jpg';
      final backPath = '$base/cnic_back_$timestamp.jpg';

      await FirebaseStorage.instance
          .ref(frontPath)
          .putFile(
            File(_front!.path),
            SettableMetadata(contentType: 'image/jpeg'),
          );
      await FirebaseStorage.instance
          .ref(backPath)
          .putFile(
            File(_back!.path),
            SettableMetadata(contentType: 'image/jpeg'),
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
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      _message(e.message ?? 'Unable to upload CNIC.', error: true);
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
        title: const Text('CNIC Verification'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Capture clear CNIC images',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use the original CNIC. Keep all four corners visible and avoid glare or blur.',
            style: TextStyle(color: Color(0xFF64748B), height: 1.45),
          ),
          const SizedBox(height: 20),
          _imageCard(
            title: 'CNIC front',
            file: _front,
            onTap: () => _capture(true),
          ),
          const SizedBox(height: 14),
          _imageCard(
            title: 'CNIC back',
            file: _back,
            onTap: () => _capture(false),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Only the Firebase Storage path is saved in Firestore. Do not call getDownloadURL() for CNIC documents.',
              style: TextStyle(color: Color(0xFF1E40AF), height: 1.4),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
              onPressed: (_front == null || _back == null || _uploading)
                  ? null
                  : _upload,
              icon: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: const Text('Securely upload CNIC'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageCard({
    required String title,
    required XFile? file,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: _uploading ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 210,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: file == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 42,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap to open camera',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(file.path), fit: BoxFit.cover),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: FilledButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retake'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
