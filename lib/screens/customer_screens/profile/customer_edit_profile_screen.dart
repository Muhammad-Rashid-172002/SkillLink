import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_models.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_repository.dart';

class CustomerEditProfileScreen extends StatefulWidget {
  const CustomerEditProfileScreen({
    super.key,
    this.initialProfile,
    this.repository,
    this.imagePicker,
  });

  final CustomerProfile? initialProfile;
  final CustomerProfileRepository? repository;
  final CustomerProfileImagePicker? imagePicker;

  @override
  State<CustomerEditProfileScreen> createState() =>
      _CustomerEditProfileScreenState();
}

class _CustomerEditProfileScreenState extends State<CustomerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _area = TextEditingController();
  final _address = TextEditingController();
  final _bio = TextEditingController();

  late final CustomerProfileRepository _repository;
  late final CustomerProfileImagePicker _imagePicker;
  CustomerProfile? _profile;
  String? _selectedImagePath;
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseCustomerProfileRepository();
    _imagePicker = widget.imagePicker ?? DeviceCustomerProfileImagePicker();
    if (widget.initialProfile case final profile?) {
      _apply(profile);
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      _apply(await _repository.loadProfile());
    } catch (_) {
      _error = 'Unable to load your profile. Please try again.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(CustomerProfile profile) {
    _profile = profile;
    _name.text = profile.name == 'Customer' ? '' : profile.name;
    _email.text = profile.identity.email;
    _phone.text = profile.identity.phone;
    _city.text = profile.city;
    _area.text = profile.area;
    _address.text = profile.address;
    _bio.text = profile.bio;
  }

  Future<void> _choosePhoto(ImageSource source) async {
    Navigator.maybePop(context);
    try {
      final path = await _imagePicker.pick(source);
      if (path != null && mounted) setState(() => _selectedImagePath = path);
    } on FormatException catch (error) {
      _message(error.message, error: true);
    } catch (_) {
      _message('Unable to select that photo.', error: true);
    }
  }

  void _showPhotoSources() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Change profile photo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListTile(
                key: const Key('photo-gallery'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => _choosePhoto(ImageSource.gallery),
              ),
              ListTile(
                key: const Key('photo-camera'),
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () => _choosePhoto(ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var photoUrl = _profile?.photoUrl ?? '';
      if (_selectedImagePath != null) {
        setState(() => _uploading = true);
        try {
          photoUrl = await _repository.uploadProfilePhoto(_selectedImagePath!);
        } finally {
          if (mounted) setState(() => _uploading = false);
        }
      }
      await _repository.updateProfile(
        CustomerProfileUpdate(
          name: _name.text.trim(),
          city: _city.text.trim(),
          area: _area.text.trim(),
          address: _address.text.trim(),
          bio: _bio.text.trim(),
          photoUrl: photoUrl,
        ),
      );
      if (!mounted) return;
      _message('Profile updated.');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your changes could not be saved. Please try again.',
        );
        _message(_error!, error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _phone,
      _city,
      _area,
      _address,
      _bio,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
          ? _FailureState(
              message: _error ?? 'Profile unavailable',
              onRetry: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _PhotoEditor(
                    profile: _profile!,
                    selectedPath: _selectedImagePath,
                    uploading: _uploading,
                    onTap: _saving ? null : _showPhotoSources,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Personal information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile-name-field'),
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter your name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile-email-field'),
                    controller: _email,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: _profile!.identity.emailVerified
                          ? 'Verified email'
                          : 'Account email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      helperText: 'Email changes require account verification.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile-phone-field'),
                    controller: _phone,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Verified phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                      helperText: 'Phone number changes require verification.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Service location',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Updating these labels does not change your saved coordinates.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile-city-field'),
                    controller: _city,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile-area-field'),
                    controller: _area,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Area / service area',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile-address-field'),
                    controller: _address,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile-bio-field'),
                    controller: _bio,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 240,
                    decoration: const InputDecoration(
                      labelText: 'About you',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      key: const Key('profile-save-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('profile-save-button'),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _uploading
                          ? 'Uploading photo…'
                          : _saving
                          ? 'Saving…'
                          : 'Save changes',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PhotoEditor extends StatelessWidget {
  const _PhotoEditor({
    required this.profile,
    required this.selectedPath,
    required this.uploading,
    required this.onTap,
  });
  final CustomerProfile profile;
  final String? selectedPath;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget image;
    if (selectedPath != null) {
      image = Image.file(
        File(selectedPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _Initials(profile: profile),
      );
    } else if (profile.photoUrl.isNotEmpty) {
      image = Image.network(
        profile.photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _Initials(profile: profile),
      );
    } else {
      image = _Initials(profile: profile);
    }
    return Center(
      child: Semantics(
        button: true,
        label: 'Change profile photo',
        child: InkWell(
          key: const Key('profile-photo-editor'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(60),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 104,
                height: 104,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: .1),
                ),
                child: image,
              ),
              if (uploading)
                Container(
                  key: const Key('photo-upload-progress'),
                  width: 104,
                  height: 104,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x88000000),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.primary,
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 18,
                    color: colors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.profile});
  final CustomerProfile profile;
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      profile.initials,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(SkillNovaSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
