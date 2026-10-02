import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/core/auth/session_router.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_brand.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';
import 'package:skill_link/design_system/widgets/skillnova_text_field.dart';
import 'package:skill_link/models/service_data.dart';
import 'package:skill_link/screens/auth_screens/verification_widgets.dart';

class WorkerProfileSetupScreen extends StatefulWidget {
  const WorkerProfileSetupScreen({super.key});

  @override
  State<WorkerProfileSetupScreen> createState() =>
      _WorkerProfileSetupScreenState();
}

class _WorkerProfileSetupScreenState extends State<WorkerProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final experienceController = TextEditingController();
  final rateController = TextEditingController();
  final locationController = TextEditingController();
  final bioController = TextEditingController();

  String selectedSkill = 'Electrician';

  bool _isSaving = false;
  bool _isGettingLocation = false;
  bool _locationCaptured = false;

  Position? _currentPosition;

  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  XFile? _selectedProfileImage;
  String? _existingProfileImageUrl;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadExistingWorkerProfile);
  }

  Future<void> _loadExistingWorkerProfile() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!document.exists) return;

      final data = document.data();

      nameController.text = data?['name']?.toString() ?? '';
      phoneController.text = data?['phone']?.toString() ?? '';
      experienceController.text = data?['experience']?.toString() ?? '';
      rateController.text = data?['hourlyRate']?.toString() ?? '';
      locationController.text = data?['location']?.toString() ?? '';
      bioController.text = data?['bio']?.toString() ?? '';

      final savedSkill = data?['skill']?.toString();
      if (savedSkill != null &&
          allServices.any((service) => service.title == savedSkill)) {
        selectedSkill = savedSkill;
      }

      final imageUrl = data?['profileImageUrl']?.toString().trim();
      if (imageUrl != null && imageUrl.isNotEmpty) {
        _existingProfileImageUrl = imageUrl;
      }

      final lat = data?['lat'];
      final lng = data?['lng'];

      if (lat is num && lng is num) {
        _currentPosition = Position(
          latitude: lat.toDouble(),
          longitude: lng.toDouble(),
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
        _locationCaptured = true;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('Worker profile loading error: $error');
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    experienceController.dispose();
    rateController.dispose();
    locationController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage('Please turn on location services.', isError: true);
        return null;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage('Location permission was denied.', isError: true);
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationSettingsDialog();
        return null;
      }

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (error) {
      _showMessage(
        'Unable to get location. ${error.toString()}',
        isError: true,
      );
      return null;
    }
  }

  Future<void> _captureLocation() async {
    if (_isGettingLocation) return;

    setState(() => _isGettingLocation = true);

    final position = await _getCurrentLocation();

    if (!mounted) return;

    setState(() {
      _isGettingLocation = false;

      if (position != null) {
        _currentPosition = position;
        _locationCaptured = true;
      }
    });

    if (position != null) {
      _showMessage('Current location captured successfully.');
    }
  }

  Future<void> _saveWorkerProfile() async {
    FocusScope.of(context).unfocus();

    if (_isSaving) return;

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      _showMessage('Please check the highlighted fields.', isError: true);
      return;
    }

    if (_selectedProfileImage == null &&
        (_existingProfileImageUrl == null ||
            _existingProfileImageUrl!.trim().isEmpty)) {
      _showMessage(
        'Add a clear photo of yourself — customers trust profiles with a face.',
        isError: true,
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage('Your session expired. Please login again.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      Position? position = _currentPosition;

      if (position == null) {
        position = await _getCurrentLocation();
      }

      String? profileImageUrl = _existingProfileImageUrl;

      if (_selectedProfileImage != null) {
        profileImageUrl = await _uploadWorkerProfileImage(
          userId: currentUser.uid,
          image: _selectedProfileImage!,
        );
      }

      await currentUser.updateDisplayName(nameController.text.trim());

      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        await currentUser.updatePhotoURL(profileImageUrl);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
            'uid': currentUser.uid,
            'role': 'worker',
            'name': nameController.text.trim(),
            'phone': phoneController.text.trim(),
            'skill': selectedSkill,
            'experience': experienceController.text.trim(),
            'hourlyRate': rateController.text.trim(),
            'location': locationController.text.trim(),
            'lat': position?.latitude,
            'lng': position?.longitude,
            'bio': bioController.text.trim(),
            'profileImageUrl': profileImageUrl,
            'profileCompleted': true,
            'isOnline': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      await SessionRouter.continueSession(context);
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Your profile couldn’t be saved. Check your connection and try '
        'again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image == null || !mounted) return;

      setState(() {
        _selectedProfileImage = image;
      });
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        source == ImageSource.camera
            ? 'Unable to open the camera.'
            : 'Unable to select a photo.',
        isError: true,
      );
    }
  }

  Future<String> _uploadWorkerProfileImage({
    required String userId,
    required XFile image,
  }) async {
    final String extension = _fileExtension(image.name);

    final Reference reference = _storage
        .ref()
        .child('profile_images')
        .child('workers')
        .child(userId)
        .child('profile.$extension');

    // Bytes work on every platform; `File` does not exist on the web.
    final UploadTask uploadTask = reference.putData(
      await image.readAsBytes(),
      SettableMetadata(
        contentType: _contentType(extension),
        customMetadata: {'userId': userId, 'type': 'worker_profile'},
      ),
    );

    final TaskSnapshot snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  String _fileExtension(String path) {
    final String fileName = path.split('/').last;

    if (!fileName.contains('.')) return 'jpg';

    final String extension = fileName.split('.').last.toLowerCase();

    if (extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'png' ||
        extension == 'webp') {
      return extension;
    }

    return 'jpg';
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _showLocationSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.location_off_outlined),
        title: const Text('Turn on location'),
        content: const Text(
          'Location is off, so we can’t pin where you work. You can turn it '
          'on, or just type your service area.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    SkillNovaToast.show(
      context,
      message,
      tone: isError ? SkillNovaTone.error : SkillNovaTone.success,
    );
  }

  Future<void> _choosePhoto() async {
    if (kIsWeb) return _pickProfileImage(ImageSource.gallery);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: SkillNovaSpacing.xs),
          ],
        ),
      ),
    );
    if (source != null) await _pickProfileImage(source);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SkillNovaSpacing.gutter,
                  SkillNovaSpacing.xs,
                  SkillNovaSpacing.xs,
                  0,
                ),
                child: _topBar(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    SkillNovaSpacing.gutter,
                    SkillNovaSpacing.md,
                    SkillNovaSpacing.gutter,
                    SkillNovaSpacing.xl,
                  ),
                  child: ContentWidth(
                    maxWidth: 560,
                    child: Form(
                      key: _formKey,
                      child: AbsorbPointer(
                        absorbing: _isSaving,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const VerificationProgress(step: 3),
                            const SizedBox(height: SkillNovaSpacing.xl),
                            Text(
                              'Set up your professional profile',
                              style: text.headlineSmall,
                            ),
                            const SizedBox(height: SkillNovaSpacing.xs),
                            Text(
                              'This is what customers see before they hire '
                              'you. Next, you’ll verify your identity.',
                              style: text.bodyMedium,
                            ),
                            const SizedBox(height: SkillNovaSpacing.md),
                            _progress(),
                            const SizedBox(height: SkillNovaSpacing.xl),
                            _photo(),
                            const SizedBox(height: SkillNovaSpacing.xl),
                            _section('About you'),
                            ..._basicFields(),
                            const SizedBox(height: SkillNovaSpacing.xl),
                            _section('Your work'),
                            ..._workFields(),
                            const SizedBox(height: SkillNovaSpacing.xl),
                            _section('Where you work'),
                            ..._locationFields(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _saveBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    // Root screen during onboarding: there is nothing to pop back to, so
    // offer a clear way out instead of a dead back arrow.
    final canGoBack = Navigator.of(context).canPop();
    return Row(
      children: [
        if (canGoBack)
          IconButton(
            tooltip: 'Back',
            onPressed: _isSaving ? null : () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          )
        else
          const SkillNovaWordmark(size: 28),
        const Spacer(),
        if (!canGoBack)
          TextButton(
            onPressed: _isSaving ? null : () => SessionRouter.signOut(context),
            child: const Text('Sign out'),
          ),
      ],
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: SkillNovaSpacing.sm),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    ),
  );

  /// Share of the required profile items that are actually filled in.
  double get _completion {
    bool filled(TextEditingController c) => c.text.trim().isNotEmpty;
    final items = [
      _selectedProfileImage != null ||
          (_existingProfileImageUrl?.isNotEmpty ?? false),
      filled(nameController),
      filled(phoneController),
      selectedSkill.isNotEmpty,
      filled(experienceController),
      filled(rateController),
      filled(locationController) || _locationCaptured,
      bioController.text.trim().length >= 20,
    ];
    return items.where((done) => done).length / items.length;
  }

  Widget _progress() {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([
        nameController,
        phoneController,
        experienceController,
        rateController,
        locationController,
        bioController,
      ]),
      builder: (context, _) {
        final completion = _completion;
        return Semantics(
          label: 'Profile ${(completion * 100).round()} percent complete',
          excludeSemantics: true,
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completion,
                    minHeight: 6,
                    backgroundColor: colors.surfaceContainer,
                  ),
                ),
              ),
              const SizedBox(width: SkillNovaSpacing.sm),
              Text(
                '${(completion * 100).round()}% complete',
                style: text.labelMedium,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _photo() {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final image = _selectedProfileImage;
    final existing = _existingProfileImageUrl;
    final ImageProvider? provider = image != null
        ? (kIsWeb
              ? NetworkImage(image.path)
              : FileImage(File(image.path)) as ImageProvider)
        : (existing != null && existing.isNotEmpty)
        ? NetworkImage(existing)
        : null;
    return SkillNovaCard(
      onTap: _choosePhoto,
      semanticLabel: provider == null
          ? 'Add profile photo'
          : 'Change profile photo',
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: colors.surfaceContainer,
            foregroundImage: provider,
            child: Icon(
              Icons.person_rounded,
              size: 36,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: SkillNovaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider == null ? 'Add a profile photo' : 'Profile photo',
                  style: text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'A clear, friendly photo of your face builds trust.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: SkillNovaSpacing.xs),
          Text(
            provider == null ? 'Add' : 'Change',
            style: text.labelLarge?.copyWith(color: colors.primary),
          ),
        ],
      ),
    );
  }

  List<Widget> _basicFields() => [
    SkillNovaTextField(
      label: 'Full name',
      controller: nameController,
      hint: 'As customers should see it',
      prefixIcon: Icons.person_outline_rounded,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      validator: (value) {
        final name = value?.trim() ?? '';
        if (name.isEmpty) return 'Enter your full name.';
        if (name.length < 3) return 'Enter at least 3 characters.';
        return null;
      },
    ),
    const SizedBox(height: SkillNovaSpacing.md),
    SkillNovaTextField(
      label: 'Mobile number',
      controller: phoneController,
      hint: '0300 1234567',
      prefixIcon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
      validator: (value) {
        final phone = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        if (phone.isEmpty) return 'Enter your mobile number.';
        if (phone.length < 10) return 'Enter a valid mobile number.';
        return null;
      },
    ),
  ];

  List<Widget> _workFields() => [
    const SkillNovaFieldLabel('Main service'),
    DropdownButtonFormField<String>(
      initialValue: allServices.any((s) => s.title == selectedSkill)
          ? selectedSkill
          : allServices.first.title,
      isExpanded: true,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.handyman_outlined),
      ),
      items: [
        for (final service in allServices)
          DropdownMenuItem(value: service.title, child: Text(service.title)),
      ],
      onChanged: (value) {
        if (value != null) setState(() => selectedSkill = value);
      },
    ),
    const SizedBox(height: SkillNovaSpacing.xs),
    Text(
      'You’ll receive leads for this service.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    const SizedBox(height: SkillNovaSpacing.md),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SkillNovaTextField(
            label: 'Experience (years)',
            controller: experienceController,
            hint: 'e.g. 3',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            validator: (value) =>
                (value?.trim().isEmpty ?? true) ? 'Add your experience.' : null,
          ),
        ),
        const SizedBox(width: SkillNovaSpacing.sm),
        Expanded(
          child: SkillNovaTextField(
            label: 'Rate per hour (Rs)',
            controller: rateController,
            hint: 'e.g. 800',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              final rate = int.tryParse(value?.trim() ?? '');
              if (rate == null || rate <= 0) return 'Enter an amount.';
              return null;
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: SkillNovaSpacing.md),
    SkillNovaTextField(
      label: 'Short bio',
      controller: bioController,
      hint: 'Your specialties, the kind of jobs you do best, certifications…',
      textCapitalization: TextCapitalization.sentences,
      minLines: 3,
      maxLines: 5,
      maxLength: 300,
      validator: (value) => (value?.trim().length ?? 0) < 20
          ? 'Write at least 20 characters so customers know your work.'
          : null,
    ),
  ];

  List<Widget> _locationFields() {
    final text = Theme.of(context).textTheme;
    return [
      SkillNovaTextField(
        label: 'Service area',
        controller: locationController,
        hint: 'e.g. University Town, Peshawar',
        prefixIcon: Icons.place_outlined,
        textCapitalization: TextCapitalization.words,
        validator: (value) => (value?.trim().isEmpty ?? true)
            ? 'Add the area you work in.'
            : null,
      ),
      const SizedBox(height: SkillNovaSpacing.sm),
      SkillNovaCard(
        child: Row(
          children: [
            IconTile(
              icon: _locationCaptured
                  ? Icons.my_location_rounded
                  : Icons.location_searching_rounded,
              tone: _locationCaptured
                  ? SkillNovaTone.success
                  : SkillNovaTone.info,
            ),
            const SizedBox(width: SkillNovaSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _locationCaptured ? 'Location pinned' : 'Pin your location',
                    style: text.titleSmall,
                  ),
                  Text(
                    'Used to match you with jobs nearby.',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            _isGettingLocation
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _isSaving ? null : _captureLocation,
                    child: Text(_locationCaptured ? 'Update' : 'Use GPS'),
                  ),
          ],
        ),
      ),
    ];
  }

  Widget _saveBar() {
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
          label: 'Save and continue',
          icon: Icons.arrow_forward_rounded,
          loading: _isSaving,
          fullWidth: true,
          onPressed: _saveWorkerProfile,
        ),
      ),
    );
  }
}
