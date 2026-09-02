import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:skill_link/screens/customer_screens/navigation/customer_navigation_shell.dart';

class CustomerProfileSetupScreen extends StatefulWidget {
  const CustomerProfileSetupScreen({super.key});

  @override
  State<CustomerProfileSetupScreen> createState() =>
      _CustomerProfileSetupScreenState();
}
class _CustomerProfileSetupScreenState
    extends State<CustomerProfileSetupScreen> {
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF16A34A);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE4EAF2);

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
        setState(() {
        });
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

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 520),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: const CustomerNavigationShell(),
          ),
        ),
      );
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

  String _initials() {
    final name = _nameController.text.trim();

    if (name.isEmpty) return 'CU';

    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          backgroundColor: isError
              ? const Color(0xFFDC2626)
              : const Color(0xFF16A34A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: -130,
            right: -120,
            child: _ambientCircle(size: 320, color: _primary.withOpacity(0.10)),
          ),
          Positioned(
            bottom: -150,
            left: -135,
            child: _ambientCircle(
              size: 330,
              color: _secondary.withOpacity(0.08),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: height - 80),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _topBar(),
                      const SizedBox(height: 18),
                      _heroCard(),
                      const SizedBox(height: 20),
                      _profileIdentityCard(),
                      const SizedBox(height: 18),
                      _personalInformationCard(),
                      const SizedBox(height: 18),
                      _addressInformationCard(),
                      const SizedBox(height: 18),
                      _locationCard(),
                      const SizedBox(height: 20),
                      _saveButton(),
                      const SizedBox(height: 14),
                      _privacyNote(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Container(
          height: 43,
          width: 43,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_primary, _secondary]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.22),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.handyman_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SkillNova',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              'Customer onboarding',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 9.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.09),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _primary.withOpacity(0.12)),
          ),
          child: const Row(
            children: [
              Icon(Icons.person_search_rounded, color: _primary, size: 15),
              SizedBox(width: 6),
              Text(
                'CUSTOMER',
                style: TextStyle(
                  color: _primary,
                  fontSize: 10.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -65,
            right: -50,
            child: Container(
              height: 175,
              width: 175,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -45,
            child: Container(
              height: 165,
              width: 165,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
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
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: Colors.white.withOpacity(0.20)),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 27,
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
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'FINAL STEP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.2,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Complete your\ncustomer profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Help nearby professionals understand where you need services and how they can contact you.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.83),
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileIdentityCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _nameController,
            builder: (_, __, ___) {
              return Container(
                height: 66,
                width: 66,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _secondary],
                  ),
                  borderRadius: BorderRadius.circular(21),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.20),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your customer identity',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Your name and city will help workers recognize your requests.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10.8,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: _success.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: _success,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalInformationCard() {
    return _sectionCard(
      icon: Icons.badge_outlined,
      title: 'Personal information',
      subtitle: 'Tell us how workers can identify and contact you.',
      child: Column(
        children: [
          _inputField(
            controller: _nameController,
            focusNode: _nameFocus,
            nextFocus: _phoneFocus,
            label: 'Full name',
            hint: 'Enter your full name',
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              final text = value?.trim() ?? '';

              if (text.isEmpty) return 'Full name is required.';
              if (text.length < 3) {
                return 'Enter at least 3 characters.';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),
          _inputField(
            controller: _phoneController,
            focusNode: _phoneFocus,
            nextFocus: _areaFocus,
            label: 'Phone number',
            hint: '+92 300 1234567',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
              LengthLimitingTextInputFormatter(18),
            ],
            validator: (value) {
              final phone = value?.trim() ?? '';

              if (phone.isEmpty) return 'Phone number is required.';
              if (!_isValidPakistanPhone(phone)) {
                return 'Enter a valid Pakistani mobile number.';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),
          _cityDropdown(),
        ],
      ),
    );
  }

  Widget _addressInformationCard() {
    return _sectionCard(
      icon: Icons.home_work_outlined,
      title: 'Address details',
      subtitle: 'This helps SkillNova show professionals near your area.',
      child: Column(
        children: [
          _inputField(
            controller: _areaController,
            focusNode: _areaFocus,
            nextFocus: _addressFocus,
            label: 'Area or street',
            hint: 'Example: Hayatabad Phase 3',
            icon: Icons.location_on_outlined,
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              final text = value?.trim() ?? '';

              if (text.isEmpty) return 'Area or street is required.';
              if (text.length < 3) {
                return 'Enter a valid area or street.';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),
          _inputField(
            controller: _addressController,
            focusNode: _addressFocus,
            label: 'Complete address',
            hint: 'House number, street and nearby landmark',
            icon: Icons.map_outlined,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              final text = value?.trim() ?? '';

              if (text.isEmpty) return 'Complete address is required.';
              if (text.length < 8) {
                return 'Please provide a more complete address.';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _locationCard() {
    final statusColor = _locationAdded
        ? _success
        : _isGettingLocation
        ? _primary
        : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: _locationAdded ? _success.withOpacity(0.30) : _border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _locationAdded
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current location',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 13.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _locationMessage ??
                          'Add location to discover workers closest to you.',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 10.8,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_locationAdded)
                Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: _success.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: _success,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isGettingLocation ? null : _getCurrentLocation,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: BorderSide(color: _primary.withOpacity(0.24)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: _isGettingLocation
                  ? const SizedBox(
                      height: 17,
                      width: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primary,
                      ),
                    )
                  : Icon(
                      _locationAdded
                          ? Icons.refresh_rounded
                          : Icons.near_me_rounded,
                      size: 18,
                    ),
              label: Text(
                _isGettingLocation
                    ? 'Getting location'
                    : _locationAdded
                    ? 'Update current location'
                    : 'Use current location',
                style: const TextStyle(
                  fontSize: 11.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 43,
                width: 43,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _primary, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 10.4,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    FocusNode? nextFocus,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          textInputAction: maxLines > 1
              ? TextInputAction.newline
              : nextFocus == null
              ? TextInputAction.done
              : TextInputAction.next,
          onFieldSubmitted: (_) {
            if (nextFocus != null) {
              nextFocus.requestFocus();
            }
          },
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          decoration: _inputDecoration(
            hint: hint,
            icon: icon,
            alignIconTop: maxLines > 1,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 3, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 12.3,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    bool alignIconTop = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 12.2,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Padding(
        padding: EdgeInsets.only(top: alignIconTop ? 13 : 0),
        child: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      errorStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }

  Widget _cityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('City'),
        DropdownButtonFormField<String>(
          value: _selectedCity,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _textSecondary,
          ),
          decoration: _inputDecoration(
            hint: 'Select your city',
            icon: Icons.location_city_outlined,
          ),
          items: _cities.map((city) {
            return DropdownMenuItem<String>(
              value: city,
              child: Text(
                city,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }).toList(),
          onChanged: _isSaving
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _selectedCity = value);
                },
        ),
      ],
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveCustomerProfile,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: _primary,
          disabledBackgroundColor: _primary.withOpacity(0.62),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _isSaving
              ? const SizedBox(
                  key: ValueKey('saving'),
                  height: 21,
                  width: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  key: ValueKey('save'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Complete profile',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 9),
                    Icon(Icons.arrow_forward_rounded, size: 19),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _privacyNote() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, color: _textSecondary, size: 14),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Your contact and location details are stored securely.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _ambientCircle({required double size, required Color color}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
