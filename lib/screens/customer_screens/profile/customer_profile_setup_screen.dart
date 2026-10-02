import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/core/auth/session_router.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_brand.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';
import 'package:skill_link/design_system/widgets/skillnova_text_field.dart';
import 'package:skill_link/screens/auth_screens/verification_widgets.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class CustomerProfileSetupScreen extends StatefulWidget {
  const CustomerProfileSetupScreen({super.key});

  @override
  State<CustomerProfileSetupScreen> createState() =>
      _CustomerProfileSetupScreenState();
}

class _CustomerProfileSetupScreenState
    extends State<CustomerProfileSetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _areaFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _cities = const [
    'Peshawar',
    'Islamabad',
    'Rawalpindi',
    'Lahore',
    'Karachi',
    'Quetta',
    'Multan',
    'Faisalabad',
    'Sialkot',
    'Abbottabad',
  ];

  String _selectedCity = 'Peshawar';

  bool _isSaving = false;
  bool _isGettingLocation = false;
  bool _locationAdded = false;

  /// The number was verified by SMS in the previous step; editing it here
  /// would silently desync it from the verified account phone.
  bool _phoneLocked = false;

  Position? _currentPosition;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadExistingProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    _addressController.dispose();

    _nameFocus.dispose();
    _phoneFocus.dispose();
    _areaFocus.dispose();
    _addressFocus.dispose();

    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return;
      }

      // Firebase Auth se name foran show ho jayega
      final displayName = user.displayName?.trim() ?? '';

      if (displayName.isNotEmpty) {
        _nameController.text = displayName;
      }

      // Firestore ko maximum 5 seconds wait karega
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 5));

      if (!doc.exists) return;

      final data = doc.data();

      final savedName = data?['name']?.toString().trim() ?? '';

      if (savedName.isNotEmpty) {
        _nameController.text = savedName;
      }

      _phoneController.text = data?['phone']?.toString() ?? '';
      _phoneLocked =
          data?['phoneVerified'] == true &&
          _phoneController.text.trim().isNotEmpty;
      _areaController.text = data?['area']?.toString() ?? '';
      _addressController.text = data?['address']?.toString() ?? '';

      final savedCity = data?['city']?.toString();

      if (savedCity != null && _cities.contains(savedCity)) {
        _selectedCity = savedCity;
      }

      final lat = data?['lat'];
      final lng = data?['lng'];

      if (lat is num && lng is num) {
        _locationAdded = true;
        _locationMessage = 'Location already added';
      }
    } catch (e) {
      debugPrint('Profile loading error: $e');

      // Error aaye tab bhi form open hoga
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _saveCustomerProfile() async {
    FocusScope.of(context).unfocus();

    if (_isSaving) return;

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      _showMessage('Please check the highlighted fields.', isError: true);
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Your session has expired. Please log in again.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await user.updateDisplayName(_nameController.text.trim());

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'role': 'customer',
        'name': _nameController.text.trim(),
        'phone': _normalizePhone(_phoneController.text),
        'city': _selectedCity,
        'area': _areaController.text.trim(),
        'address': _addressController.text.trim(),
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'lat': _currentPosition?.latitude,
        'lng': _currentPosition?.longitude,
        'locationAdded': _locationAdded,
      }, SetOptions(merge: true));

      if (!mounted) return;

      await SessionRouter.continueSession(context);
    } on FirebaseException catch (error) {
      _showMessage(
        error.message ?? 'Unable to save your profile.',
        isError: true,
      );
    } catch (_) {
      _showMessage('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_isGettingLocation) return;

    setState(() {
      _isGettingLocation = true;
      _locationMessage = 'Checking location permission';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          _locationAdded = false;
          _locationMessage = 'Location services are turned off';
        });

        _showLocationServiceDialog();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          _locationAdded = false;
          _locationMessage = 'Location permission was denied';
        });

        _showMessage(
          'Location permission is required to find nearby workers.',
          isError: true,
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _locationAdded = false;
          _locationMessage = 'Location permission is permanently denied';
        });

        _showPermissionDialog();
        return;
      }

      if (mounted) {
        setState(() => _locationMessage = 'Getting your current location');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _locationAdded = true;
        _locationMessage = 'Current location added successfully';
      });

      _showMessage('Your current location has been added.');
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _locationAdded = false;
        _locationMessage = 'Location request timed out';
      });

      _showMessage(
        'Could not get your location. Please try again.',
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _locationAdded = false;
        _locationMessage = 'Unable to get your current location';
      });

      _showMessage('Unable to access your location right now.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<void> _showLocationServiceDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Turn on location',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'Location services are disabled. Turn them on to find skilled workers near you.',
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
        );
      },
    );
  }

  Future<void> _showPermissionDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Allow location access',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'Location permission is permanently denied. Open app settings and allow location access.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Geolocator.openAppSettings();
              },
              child: const Text('App settings'),
            ),
          ],
        );
      },
    );
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\s+'), '').trim();
  }

  bool _isValidPakistanPhone(String value) {
    final normalized = value
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '');

    return RegExp(r'^(?:\+92|0092|92|0)?3\d{9}$').hasMatch(normalized);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    SkillNovaToast.show(
      context,
      message,
      tone: isError ? SkillNovaTone.error : SkillNovaTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
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
                            'Where should professionals come?',
                            style: text.headlineSmall,
                          ),
                          const SizedBox(height: SkillNovaSpacing.xs),
                          Text(
                            'Last step. This helps us show professionals near '
                            'you and lets them find your place.',
                            style: text.bodyMedium,
                          ),
                          const SizedBox(height: SkillNovaSpacing.xl),
                          _personalInformationCard(),
                          const SizedBox(height: SkillNovaSpacing.xl),
                          _addressInformationCard(),
                          const SizedBox(height: SkillNovaSpacing.lg),
                          _locationCard(),
                          const SizedBox(height: SkillNovaSpacing.md),
                          Text(
                            'Professionals you hire use this address to '
                            'reach you. You can change it any time.',
                            style: text.bodySmall,
                          ),
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
    );
  }

  Widget _topBar() {
    // Root screen during onboarding: offer a way out instead of trapping the
    // person here until the profile is saved.
    return Row(
      children: [
        const SkillNovaWordmark(size: 28),
        const Spacer(),
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

  Widget _personalInformationCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('About you'),
        SkillNovaTextField(
          label: 'Full name',
          controller: _nameController,
          focusNode: _nameFocus,
          hint: 'e.g. Ayesha Khan',
          prefixIcon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          onChanged: (_) => setState(() {}),
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
          controller: _phoneController,
          focusNode: _phoneFocus,
          enabled: !_phoneLocked,
          hint: '0300 1234567',
          prefixIcon: Icons.phone_outlined,
          helper: _phoneLocked ? 'Verified by SMS' : null,
          suffix: _phoneLocked
              ? const Padding(
                  padding: EdgeInsets.only(right: SkillNovaSpacing.sm),
                  child: Icon(
                    Icons.verified_rounded,
                    color: SkillNovaColors.success,
                    size: 20,
                  ),
                )
              : null,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final phone = value?.trim() ?? '';
            if (phone.isEmpty) return 'Enter your mobile number.';
            if (!_isValidPakistanPhone(phone)) {
              return 'Use a Pakistani mobile number, e.g. 0300 1234567.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _addressInformationCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Service address'),
        _cityDropdown(),
        const SizedBox(height: SkillNovaSpacing.md),
        SkillNovaTextField(
          label: 'Area or street',
          controller: _areaController,
          focusNode: _areaFocus,
          hint: 'e.g. Hayatabad Phase 3',
          prefixIcon: Icons.place_outlined,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final area = value?.trim() ?? '';
            if (area.isEmpty) return 'Enter your area or street.';
            if (area.length < 3) return 'Enter a valid area or street.';
            return null;
          },
        ),
        const SizedBox(height: SkillNovaSpacing.md),
        SkillNovaTextField(
          label: 'Full address',
          controller: _addressController,
          focusNode: _addressFocus,
          hint: 'House number, street and a nearby landmark',
          prefixIcon: Icons.home_outlined,
          textCapitalization: TextCapitalization.sentences,
          minLines: 2,
          maxLines: 3,
          validator: (value) {
            final address = value?.trim() ?? '';
            if (address.isEmpty) return 'Enter your full address.';
            if (address.length < 8) {
              return 'Add a little more detail so professionals can find '
                  'you.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _cityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkillNovaFieldLabel('City'),
        _cityField(),
      ],
    );
  }

  Widget _cityField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCity,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.location_city_outlined),
      ),
      items: [
        for (final city in _cities)
          DropdownMenuItem(value: city, child: Text(city)),
      ],
      onChanged: _isSaving
          ? null
          : (value) {
              if (value == null) return;
              setState(() => _selectedCity = value);
            },
    );
  }

  Widget _locationCard() {
    final text = Theme.of(context).textTheme;
    return SkillNovaCard(
      child: Row(
        children: [
          IconTile(
            icon: _locationAdded
                ? Icons.my_location_rounded
                : Icons.location_searching_rounded,
            tone: _locationAdded ? SkillNovaTone.success : SkillNovaTone.info,
          ),
          const SizedBox(width: SkillNovaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _locationAdded ? 'Location pinned' : 'Pin your location',
                  style: text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  _locationMessage ?? 'Optional — improves “near you” results.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: SkillNovaSpacing.xs),
          _isGettingLocation
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: _isSaving ? null : _getCurrentLocation,
                  child: Text(_locationAdded ? 'Update' : 'Use GPS'),
                ),
        ],
      ),
    );
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
          label: 'Finish setup',
          icon: Icons.arrow_forward_rounded,
          loading: _isSaving,
          fullWidth: true,
          onPressed: _saveCustomerProfile,
        ),
      ),
    );
  }
}
