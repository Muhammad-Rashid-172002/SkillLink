import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';
import 'package:skill_link/design_system/widgets/skillnova_text_field.dart';
import 'package:skill_link/models/service_data.dart';
import 'package:skill_link/screens/customer_screens/customer_my_request_scree/request_tracking_screen.dart';

/// How quickly the customer needs help. [value] is stored on the request.
enum RequestUrgency {
  normal('Normal', 'Within a few hours', Icons.schedule_rounded),
  urgent('Urgent', 'As soon as possible', Icons.bolt_rounded),
  emergency('Emergency', 'Right now', Icons.warning_amber_rounded);

  const RequestUrgency(this.value, this.description, this.icon);
  final String value;
  final String description;
  final IconData icon;
}

/// Customer flow for posting a public request, or a direct request to one
/// professional when [selectedWorkerId] is given.
class Request extends StatefulWidget {
  final String? selectedWorkerId;
  final String? selectedService;
  const Request({super.key, this.selectedWorkerId, this.selectedService});

  @override
  State<Request> createState() => _RequestState();
}

class _RequestState extends State<Request> {
  static const int _maxImages = 5;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = [];

  late ServiceOption _service =
      serviceOptionFor(widget.selectedService ?? '') ?? allServices.first;
  RequestUrgency _urgency = RequestUrgency.normal;

  bool _isSubmitting = false;
  bool _isGettingLocation = false;
  double? _latitude;
  double? _longitude;
  String? _savedAddress;
  String? _directWorkerName;

  String? get _directWorkerId {
    final id = widget.selectedWorkerId?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  /// Pre-fills the service location from the customer's saved profile so
  /// posting never depends on a live GPS fix, and loads the direct worker's
  /// name for a clear "sending to" banner.
  Future<void> _loadDefaults() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final users = FirebaseFirestore.instance.collection('users');
      final profile = (await users.doc(uid).get()).data() ?? const {};
      final area = profile['area']?.toString().trim() ?? '';
      final city = profile['city']?.toString().trim() ?? '';
      final address = [area, city].where((part) => part.isNotEmpty).join(', ');
      final lat = profile['lat'];
      final lng = profile['lng'];
      String? workerName;
      final workerId = _directWorkerId;
      if (workerId != null) {
        final worker = (await users.doc(workerId).get()).data();
        workerName = worker?['name']?.toString().trim();
      }
      if (!mounted) return;
      setState(() {
        if (address.isNotEmpty) {
          _savedAddress = address;
          if (_locationController.text.trim().isEmpty) {
            _locationController.text = address;
          }
        }
        if (lat is num && lng is num) {
          _latitude = lat.toDouble();
          _longitude = lng.toDouble();
        }
        if (workerName != null && workerName.isNotEmpty) {
          _directWorkerName = workerName;
        }
      });
    } catch (_) {
      // Defaults are a convenience; the form still works without them.
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _postRequest() async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      _toast('Please check the highlighted fields.', SkillNovaTone.error);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('Please sign in again to post a request.', SkillNovaTone.error);
      return;
    }
    if (_latitude == null || _longitude == null) {
      // No saved coordinates: nearby matching needs a location fix.
      await _fillCurrentLocation();
      if (_latitude == null || _longitude == null) return;
    }

    final selectedWorkerId = _directWorkerId;
    final isDirectRequest = selectedWorkerId != null;
    setState(() => _isSubmitting = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final requestRef = firestore.collection('requests').doc();
      final imageUrls = await _uploadRequestImages(
        userId: user.uid,
        requestId: requestRef.id,
      );

      await requestRef.set({
        'customerId': user.uid,
        // Null means public job, otherwise direct worker request.
        'workerId': selectedWorkerId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _service.title,
        'location': _locationController.text.trim(),
        'budget': _budgetController.text.trim(),
        'urgency': _urgency.value,
        'status': 'searching',
        'isDirectRequest': isDirectRequest,
        'requestType': isDirectRequest ? 'direct' : 'public',
        'imageUrls': imageUrls,
        'imageCount': imageUrls.length,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'latitude': _latitude,
        'longitude': _longitude,
      });

      // Matching workers (or the chosen worker, for a direct request) are
      // notified by the sendJobNotification Cloud Function. The app never
      // lists or messages other users from the customer's device.

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RequestTrackingScreen(requestId: requestRef.id),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _toast(
        'Your request couldn’t be posted. Check your connection and try '
        'again — nothing was charged.',
        SkillNovaTone.error,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Location
  // ---------------------------------------------------------------------------

  Future<Position?> _getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _toast(
          'Turn on location services, or type your address.',
          SkillNovaTone.warning,
        );
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _toast(
          'Location access is off. Allow it in settings to find '
          'professionals near you.',
          SkillNovaTone.warning,
        );
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      _toast('We couldn’t get your location right now.', SkillNovaTone.error);
      return null;
    }
  }

  Future<void> _fillCurrentLocation() async {
    if (_isGettingLocation) return;
    FocusScope.of(context).unfocus();
    setState(() => _isGettingLocation = true);
    final position = await _getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _isGettingLocation = false;
      if (position != null) {
        _latitude = position.latitude;
        _longitude = position.longitude;
        if (_locationController.text.trim().isEmpty) {
          _locationController.text = 'My current location';
        }
      }
    });
    if (position != null) {
      _toast('Location pinned for nearby matching.', SkillNovaTone.success);
    }
  }

  // ---------------------------------------------------------------------------
  // Photos
  // ---------------------------------------------------------------------------

  Future<void> _addPhotos() async {
    if (_selectedImages.length >= _maxImages) {
      _toast('You can add up to $_maxImages photos.', SkillNovaTone.info);
      return;
    }
    final source = kIsWeb
        ? ImageSource.gallery
        : await showModalBottomSheet<ImageSource>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('Choose from gallery'),
                    onTap: () =>
                        Navigator.pop(sheetContext, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Take a photo'),
                    onTap: () =>
                        Navigator.pop(sheetContext, ImageSource.camera),
                  ),
                  const SizedBox(height: SkillNovaSpacing.xs),
                ],
              ),
            ),
          );
    if (source == null) return;
    try {
      final images = source == ImageSource.gallery
          ? await _imagePicker.pickMultiImage(imageQuality: 82, maxWidth: 1600)
          : [
              ?await _imagePicker.pickImage(
                source: ImageSource.camera,
                imageQuality: 82,
                maxWidth: 1600,
              ),
            ];
      if (images.isEmpty || !mounted) return;
      final remaining = _maxImages - _selectedImages.length;
      setState(() => _selectedImages.addAll(images.take(remaining)));
      if (images.length > remaining) {
        _toast('Only $_maxImages photos can be added.', SkillNovaTone.info);
      }
    } catch (_) {
      _toast('We couldn’t open your photos.', SkillNovaTone.error);
    }
  }

  Future<List<String>> _uploadRequestImages({
    required String userId,
    required String requestId,
  }) async {
    final urls = <String>[];
    for (var index = 0; index < _selectedImages.length; index++) {
      final image = _selectedImages[index];
      final extension = _fileExtension(image.name);
      final reference = FirebaseStorage.instance
          .ref()
          .child('request_images')
          .child(userId)
          .child(requestId)
          .child('${DateTime.now().millisecondsSinceEpoch}_$index.$extension');
      // Bytes work on every platform; `File` does not exist on the web.
      final snapshot = await reference.putData(
        await image.readAsBytes(),
        SettableMetadata(
          contentType: extension == 'png'
              ? 'image/png'
              : extension == 'webp'
              ? 'image/webp'
              : 'image/jpeg',
          customMetadata: {'requestId': requestId, 'uploadedBy': userId},
        ),
      );
      urls.add(await snapshot.ref.getDownloadURL());
    }
    return urls;
  }

  String _fileExtension(String name) {
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : 'jpg';
    return const {'png', 'webp', 'jpeg', 'jpg'}.contains(extension)
        ? extension
        : 'jpg';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  void _toast(String message, SkillNovaTone tone) {
    if (!mounted) return;
    SkillNovaToast.show(context, message, tone: tone);
  }

  Future<void> _chooseService() async {
    final chosen = await showModalBottomSheet<ServiceOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
            SkillNovaSpacing.gutter,
            0,
            SkillNovaSpacing.gutter,
            SkillNovaSpacing.xl,
          ),
          children: [
            Text(
              'Choose a service',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: SkillNovaSpacing.md),
            ListGroup(
              children: [
                for (final service in allServices)
                  ListRow(
                    icon: service.icon,
                    tone: SkillNovaTone.info,
                    title: service.title,
                    subtitle: service.description,
                    trailing: service.title == _service.title
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.pop(sheetContext, service),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (chosen != null) setState(() => _service = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final direct = _directWorkerId != null;
    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        appBar: AppBar(
          title: Text(direct ? 'Request a professional' : 'New request'),
        ),
        body: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
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
                      maxWidth: 640,
                      child: AbsorbPointer(
                        absorbing: _isSubmitting,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              direct
                                  ? 'Describe the job and we’ll send it straight '
                                        'to them.'
                                  : 'Describe the job once — verified '
                                        'professionals nearby can respond.',
                              style: text.bodyMedium,
                            ),
                            if (direct) ...[
                              const SizedBox(height: SkillNovaSpacing.md),
                              InfoBanner(
                                icon: Icons.person_pin_outlined,
                                title: _directWorkerName == null
                                    ? 'Direct request'
                                    : 'Sending to $_directWorkerName',
                                message:
                                    'Only this professional will see your '
                                    'request.',
                              ),
                            ],
                            const SizedBox(height: SkillNovaSpacing.xl),
                            _section('Service'),
                            _servicePicker(),
                            const SizedBox(height: SkillNovaSpacing.xl),
                            _section('The problem'),
                            SkillNovaTextField(
                              label: 'Short title',
                              controller: _titleController,
                              hint: 'e.g. Ceiling fan isn’t spinning',
                              prefixIcon: Icons.short_text_rounded,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              maxLength: 80,
                              validator: (value) {
                                final title = value?.trim() ?? '';
                                if (title.isEmpty) {
                                  return 'Add a short title so professionals '
                                      'know what it’s about.';
                                }
                                if (title.length < 5) {
                                  return 'Make the title a little longer '
                                      '(5+ characters).';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: SkillNovaSpacing.md),
                            SkillNovaTextField(
                              label: 'Details',
                              controller: _descriptionController,
                              hint:
                                  'What’s happening, when it started, anything '
                                  'already tried…',
                              textCapitalization: TextCapitalization.sentences,
                              minLines: 4,
                              maxLines: 6,
                              maxLength: 600,
                              validator: (value) {
                                final details = value?.trim() ?? '';
                                if (details.isEmpty) {
                                  return 'Describe the problem so you get '
                                      'accurate quotes.';
                                }
                                if (details.length < 15) {
                                  return 'Add a bit more detail (15+ '
                                      'characters).';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: SkillNovaSpacing.md),
                            _photos(),
                            const SizedBox(height: SkillNovaSpacing.xl),
                            _section('Where and budget'),
                            SkillNovaTextField(
                              label: 'Service address',
                              controller: _locationController,
                              hint: 'Area, street or landmark',
                              prefixIcon: Icons.location_on_outlined,
                              textCapitalization: TextCapitalization.words,
                              validator: (value) =>
                                  (value?.trim().isEmpty ?? true)
                                  ? 'Add where the job is.'
                                  : null,
                            ),
                            const SizedBox(height: SkillNovaSpacing.xs),
                            _locationActions(),
                            const SizedBox(height: SkillNovaSpacing.md),
                            SkillNovaTextField(
                              label: 'Budget',
                              controller: _budgetController,
                              hint: 'e.g. 1500',
                              prefixIcon: Icons.payments_outlined,
                              helper:
                                  'An estimate in PKR. Professionals may '
                                  'suggest a different price.',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(7),
                              ],
                              validator: (value) {
                                final budget = int.tryParse(
                                  value?.trim() ?? '',
                                );
                                if (budget == null || budget <= 0) {
                                  return 'Enter an amount in rupees, e.g. '
                                      '1500.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: SkillNovaSpacing.xl),
                            _section('When do you need it?'),
                            _urgencyChoices(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _submitBar(direct),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: SkillNovaSpacing.sm),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    ),
  );

  Widget _servicePicker() => SkillNovaCard(
    onTap: _chooseService,
    semanticLabel: 'Service: ${_service.title}. Tap to change.',
    child: Row(
      children: [
        IconTile(icon: _service.icon, tone: SkillNovaTone.info),
        const SizedBox(width: SkillNovaSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _service.title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                _service.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: SkillNovaSpacing.xs),
        Text(
          'Change',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    ),
  );

  Widget _photos() {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Photos', style: text.labelLarge),
            const SizedBox(width: SkillNovaSpacing.xs),
            Text('Optional', style: text.bodySmall),
            const Spacer(),
            Text(
              '${_selectedImages.length}/$_maxImages',
              style: text.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: SkillNovaSpacing.xs),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (_selectedImages.length < _maxImages)
                Semantics(
                  button: true,
                  label: 'Add photos of the problem',
                  child: InkWell(
                    onTap: _addPhotos,
                    borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
                    child: Container(
                      width: 84,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(
                          SkillNovaRadius.medium,
                        ),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: colors.primary,
                          ),
                          const SizedBox(height: 4),
                          Text('Add', style: text.labelMedium),
                        ],
                      ),
                    ),
                  ),
                ),
              for (var i = 0; i < _selectedImages.length; i++)
                Padding(
                  padding: const EdgeInsets.only(left: SkillNovaSpacing.xs),
                  child: _thumbnail(i),
                ),
            ],
          ),
        ),
        const SizedBox(height: SkillNovaSpacing.xs),
        Text(
          'Photos help professionals quote accurately.',
          style: text.bodySmall,
        ),
      ],
    );
  }

  Widget _thumbnail(int index) {
    final image = _selectedImages[index];
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
          child: SizedBox(
            width: 84,
            height: 84,
            child: kIsWeb
                ? Image.network(image.path, fit: BoxFit.cover)
                : Image.file(File(image.path), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: IconButton.filled(
            tooltip: 'Remove photo',
            iconSize: 16,
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              backgroundColor: Colors.black54,
            ),
            onPressed: () => setState(() => _selectedImages.removeAt(index)),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _locationActions() {
    final pinned = _latitude != null && _longitude != null;
    return Wrap(
      spacing: SkillNovaSpacing.xs,
      runSpacing: SkillNovaSpacing.xs,
      children: [
        if (_savedAddress != null &&
            _locationController.text.trim() != _savedAddress)
          ActionChip(
            avatar: const Icon(Icons.home_outlined, size: 18),
            label: const Text('Use saved address'),
            onPressed: () =>
                setState(() => _locationController.text = _savedAddress!),
          ),
        ActionChip(
          avatar: _isGettingLocation
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded, size: 18),
          label: Text(pinned ? 'Update my location' : 'Use my location'),
          onPressed: _isGettingLocation ? null : _fillCurrentLocation,
        ),
        if (pinned)
          const StatusBadge(
            label: 'Location pinned',
            tone: SkillNovaTone.success,
            icon: Icons.check_rounded,
          ),
      ],
    );
  }

  Widget _urgencyChoices() {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final urgency in RequestUrgency.values)
          Padding(
            padding: const EdgeInsets.only(bottom: SkillNovaSpacing.xs),
            child: Semantics(
              selected: urgency == _urgency,
              inMutuallyExclusiveGroup: true,
              child: SkillNovaCard(
                onTap: () => setState(() => _urgency = urgency),
                padding: const EdgeInsets.symmetric(
                  horizontal: SkillNovaSpacing.md,
                  vertical: SkillNovaSpacing.sm,
                ),
                borderColor: urgency == _urgency ? colors.primary : null,
                color: urgency == _urgency ? colors.primaryContainer : null,
                child: Row(
                  children: [
                    Icon(
                      urgency.icon,
                      color: urgency == RequestUrgency.emergency
                          ? colors.error
                          : colors.primary,
                    ),
                    const SizedBox(width: SkillNovaSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(urgency.value, style: text.titleSmall),
                          Text(urgency.description, style: text.bodySmall),
                        ],
                      ),
                    ),
                    Icon(
                      urgency == _urgency
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: urgency == _urgency
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _submitBar(bool direct) {
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
        maxWidth: 640,
        child: PrimaryButton(
          label: direct ? 'Send request' : 'Post request',
          icon: Icons.send_rounded,
          loading: _isSubmitting,
          fullWidth: true,
          onPressed: _postRequest,
        ),
      ),
    );
  }
}
