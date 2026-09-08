import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skill_link/models/service_data.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_components.dart';

import 'worker_profile_models.dart';
import 'worker_profile_repository.dart';

class WorkerEditProfileScreen extends StatefulWidget {
  const WorkerEditProfileScreen({
    super.key,
    required this.profile,
    this.repository,
    this.imagePicker,
    this.onSaved,
  });

  final WorkerProfile profile;
  final WorkerProfileRepository? repository;
  final WorkerProfileImagePicker? imagePicker;
  final VoidCallback? onSaved;

  @override
  State<WorkerEditProfileScreen> createState() =>
      _WorkerEditProfileScreenState();
}

class _WorkerEditProfileScreenState extends State<WorkerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final WorkerProfileRepository _repository;
  late final WorkerProfileImagePicker _imagePicker;
  late final TextEditingController _name;
  late final TextEditingController _experience;
  late final TextEditingController _rate;
  late final TextEditingController _city;
  late final TextEditingController _area;
  late final TextEditingController _bio;
  String? _skill;
  String? _selectedPhotoPath;
  bool _saving = false;
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _repository = widget.repository ?? FirebaseWorkerProfileRepository();
    _imagePicker = widget.imagePicker ?? DeviceWorkerProfileImagePicker();
    _name = TextEditingController(
      text: profile.name == 'Professional' ? '' : profile.name,
    );
    _experience = TextEditingController(text: profile.experience);
    _rate = TextEditingController(text: profile.hourlyRate);
    _city = TextEditingController(
      text: profile.city.isNotEmpty ? profile.city : profile.legacyLocation,
    );
    _area = TextEditingController(text: profile.area);
    _bio = TextEditingController(text: profile.bio);
    _skill =
        allServices.any((service) => service.title == profile.canonicalSkill)
        ? profile.canonicalSkill
        : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _experience.dispose();
    _rate.dispose();
    _city.dispose();
    _area.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              key: const ValueKey('worker-photo-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              key: const ValueKey('worker-photo-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final path = await _imagePicker.pick(source);
      if (path != null && mounted) setState(() => _selectedPhotoPath = path);
    } on WorkerProfileException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('The photo could not be selected. Please try again.');
    }
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _uploadProgress = _selectedPhotoPath == null ? null : 0;
    });
    try {
      var photoUrl = widget.profile.photoUrl;
      final photoPath = _selectedPhotoPath;
      if (photoPath != null) {
        photoUrl = await _repository.uploadProfilePhoto(
          photoPath,
          onProgress: (value) {
            if (mounted) setState(() => _uploadProgress = value.clamp(0, 1));
          },
        );
      }
      await _repository.updateProfile(
        WorkerProfileUpdate(
          name: _name.text,
          skill: _skill!,
          experience: _experience.text,
          hourlyRate: _rate.text,
          city: _city.text,
          area: _area.text,
          bio: _bio.text,
          photoUrl: photoUrl,
        ),
      );
      if (!mounted) return;
      final callback = widget.onSaved;
      if (callback != null) {
        setState(() {
          _saving = false;
          _uploadProgress = null;
        });
        callback();
      } else {
        Navigator.pop(context, true);
      }
    } on WorkerProfileException catch (error) {
      _finishWithError(error.message);
    } catch (_) {
      _finishWithError('Profile changes could not be saved. Please try again.');
    }
  }

  void _finishWithError(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _uploadProgress = null;
    });
    _showError(message);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final identity = widget.profile.identity;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit professional profile')),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          32 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _photoEditor()),
              if (_uploadProgress != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  key: const ValueKey('worker-photo-upload-progress'),
                  value: _uploadProgress,
                ),
                const SizedBox(height: 4),
                Text(
                  'Uploading photo ${((_uploadProgress ?? 0) * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
              TextFormField(
                key: const ValueKey('worker-edit-name'),
                controller: _name,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Enter at least 3 characters'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: const ValueKey('worker-edit-skill'),
                isExpanded: true,
                initialValue: _skill,
                items: allServices
                    .map(
                      (service) => DropdownMenuItem(
                        value: service.title,
                        child: Text(
                          service.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _skill = value),
                decoration: const InputDecoration(
                  labelText: 'Primary service',
                  prefixIcon: Icon(Icons.handyman_outlined),
                ),
                validator: (value) =>
                    value == null ? 'Choose a supported service' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('worker-edit-experience'),
                controller: _experience,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Experience',
                  hintText: 'For example: 5 years',
                  prefixIcon: Icon(Icons.work_history_outlined),
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Add your experience'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('worker-edit-rate'),
                controller: _rate,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Starting service rate (Rs per hour)',
                  helperText:
                      'This is not a guaranteed final job price or payout.',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) => validateWorkerRate(value ?? ''),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('worker-edit-city'),
                      controller: _city,
                      enabled: !_saving,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'City'),
                      validator: (_) =>
                          _city.text.trim().isEmpty && _area.text.trim().isEmpty
                          ? 'Add city or area'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('worker-edit-area'),
                      controller: _area,
                      enabled: !_saving,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Service area',
                      ),
                      validator: (_) =>
                          _city.text.trim().isEmpty && _area.text.trim().isEmpty
                          ? 'Add city or area'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('worker-edit-bio'),
                controller: _bio,
                enabled: !_saving,
                minLines: 4,
                maxLines: 7,
                maxLength: 300,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Professional bio (optional)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 20),
              SettingsSection(
                title: 'Verified identity (read-only)',
                children: [
                  AccountInfoTile(
                    label: identity.emailVerified
                        ? 'Verified email'
                        : 'Account email (not verified)',
                    value: identity.email.isEmpty
                        ? 'Not linked'
                        : identity.email,
                    icon: Icons.email_outlined,
                  ),
                  const Divider(height: 1),
                  AccountInfoTile(
                    label: identity.phoneVerified ? 'Verified phone' : 'Phone',
                    value: identity.phoneVerified
                        ? identity.phone
                        : 'Not linked',
                    icon: Icons.phone_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Edit Profile never writes email or phone to Firestore as verified identity. Exact map coordinates and existing location-sharing consent are also unchanged.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('worker-edit-save'),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoEditor() {
    final selected = _selectedPhotoPath;
    final fallback = Center(
      child: Text(
        widget.profile.initials,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    Widget content;
    if (selected != null) {
      content = Image.file(
        File(selected),
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (widget.profile.photoUrl.isNotEmpty) {
      content = Image.network(
        widget.profile.photoUrl,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      content = fallback;
    }
    return Column(
      children: [
        CircleAvatar(
          radius: 54,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: .10),
          child: ClipOval(
            child: SizedBox.square(dimension: 104, child: content),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          key: const ValueKey('worker-edit-photo'),
          onPressed: _saving ? null : _choosePhoto,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Change profile photo'),
        ),
        Text(
          'JPG, PNG, or WebP · up to 5 MB',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
