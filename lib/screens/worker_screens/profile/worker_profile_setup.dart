import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:skill_link/models/service_data.dart';
import 'package:skill_link/screens/verification/worker_verification_center.dart';

class WorkerProfileSetupScreen extends StatefulWidget {
  const WorkerProfileSetupScreen({super.key});

  @override
  State<WorkerProfileSetupScreen> createState() =>
      _WorkerProfileSetupScreenState();
}

class _WorkerProfileSetupScreenState extends State<WorkerProfileSetupScreen> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF14B8A6);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _warning = Color(0xFFF59E0B);

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
      _showMessage('Please complete all required fields.', isError: true);
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
            'profileCompleted': true,
            'isOnline': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WorkerVerificationCenterScreen()),
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Profile could not be saved. ${error.toString()}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: _ambientCircle(size: 340, color: _primary.withOpacity(0.09)),
          ),
          Positioned(
            bottom: -170,
            left: -140,
            child: _ambientCircle(
              size: 360,
              color: _secondary.withOpacity(0.06),
            ),
          ),
          SafeArea(
            child: Form(
              key: _formKey,
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _topBar(),
                        const SizedBox(height: 20),
                        _heroCard(),
                        const SizedBox(height: 18),
                        _progressCard(),
                        const SizedBox(height: 20),
                        _profilePhoto(),
                        const SizedBox(height: 24),
                        _sectionHeader(
                          icon: Icons.person_outline_rounded,
                          title: 'Basic information',
                          subtitle: 'Tell customers who you are',
                        ),
                        const SizedBox(height: 12),
                        _formCard(
                          children: [
                            _professionalField(
                              label: 'Full name',
                              hint: 'Enter your full name',
                              icon: Icons.person_outline_rounded,
                              controller: nameController,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Full name is required';
                                }

                                if (value.trim().length < 3) {
                                  return 'Enter a valid full name';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            _professionalField(
                              label: 'Phone number',
                              hint: '+92 300 0000000',
                              icon: Icons.phone_outlined,
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\-\s]'),
                                ),
                              ],
                              validator: (value) {
                                final text = value?.trim() ?? '';

                                if (text.isEmpty) {
                                  return 'Phone number is required';
                                }

                                if (text.length < 10) {
                                  return 'Enter a valid phone number';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            _skillDropdown(),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _sectionHeader(
                          icon: Icons.handyman_outlined,
                          title: 'Work details',
                          subtitle: 'Add your experience and service pricing',
                        ),
                        const SizedBox(height: 12),
                        _formCard(
                          children: [
                            _professionalField(
                              label: 'Work experience',
                              hint: 'Example: 3 years',
                              icon: Icons.work_outline_rounded,
                              controller: experienceController,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Experience is required';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            _professionalField(
                              label: 'Hourly rate',
                              hint: 'Example: 800',
                              icon: Icons.payments_outlined,
                              controller: rateController,
                              keyboardType: TextInputType.number,
                              prefixText: 'Rs. ',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                final rate = int.tryParse(value?.trim() ?? '');

                                if (rate == null || rate <= 0) {
                                  return 'Enter a valid hourly rate';
                                }

                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _sectionHeader(
                          icon: Icons.location_on_outlined,
                          title: 'Service location',
                          subtitle: 'Help nearby customers discover you',
                        ),
                        const SizedBox(height: 12),
                        _locationCard(),
                        const SizedBox(height: 20),
                        _sectionHeader(
                          icon: Icons.description_outlined,
                          title: 'Professional summary',
                          subtitle: 'Describe your skills and work quality',
                        ),
                        const SizedBox(height: 12),
                        _bioCard(),
                        const SizedBox(height: 24),
                        _privacyNote(),
                        const SizedBox(height: 18),
                        _submitButton(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isSaving) Positioned.fill(child: _savingOverlay()),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => Navigator.maybePop(context),
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x070F172A),
                    blurRadius: 14,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _textPrimary,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Worker profile',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Complete your professional account',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.09),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, color: _primary, size: 13),
              SizedBox(width: 5),
              Text(
                'SECURE',
                style: TextStyle(
                  color: _primary,
                  fontSize: 8.4,
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
      padding: const EdgeInsets.fromLTRB(20, 21, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(29),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.24),
            blurRadius: 28,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -55,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -55,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'WORKER ONBOARDING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Build your professional profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.55,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add accurate work details so customers can discover and trust your services.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 11,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                height: 88,
                width: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: const Icon(
                  Icons.handyman_rounded,
                  color: Colors.white,
                  size: 39,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile setup progress',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 11.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  child: LinearProgressIndicator(
                    value: 0.75,
                    minHeight: 6,
                    color: _primary,
                    backgroundColor: Color(0xFFDCFCE7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '75%',
            style: TextStyle(
              color: _primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profilePhoto() {
    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 104,
                width: 104,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _secondary],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.20),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: _surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF94A3B8),
                    size: 48,
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: 5,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      _showMessage(
                        'Profile image picker can be connected here.',
                      );
                    },
                    child: Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primary, _secondary],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: _surface, width: 3),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Add profile photo',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 11.3,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'A clear photo helps build customer trust',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 9.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          height: 39,
          width: 39,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primary, size: 19),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 9.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 15,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _professionalField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 11.2,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Icon(icon, color: _primary, size: 20),
            prefixText: prefixText,
            prefixStyle: const TextStyle(
              color: _textPrimary,
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            counterStyle: const TextStyle(
              color: _textSecondary,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _danger, width: 1.5),
            ),
            errorStyle: const TextStyle(
              color: _danger,
              fontSize: 8.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 7),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 10.4,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: _danger,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Main skill'),

        DropdownButtonFormField2<String>(
          isExpanded: true,

          // Version 3.x mein value ki jagah valueListenable use hota hai
          valueListenable: ValueNotifier<String?>(selectedSkill),

          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
          ),

          items: allServices.map((service) {
            return DropdownItem<String>(
              value: service.title,
              height: 58,
              child: Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: service.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(service.icon, color: service.color, size: 19),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      service.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          onChanged: (value) {
            if (value == null) return;

            setState(() {
              selectedSkill = value;
            });
          },

          buttonStyleData: const FormFieldButtonStyleData(
            height: 54,
            padding: EdgeInsets.only(right: 8),
          ),

          iconStyleData: const IconStyleData(
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _textSecondary,
            ),
          ),

          dropdownStyleData: DropdownStyleData(
            maxHeight: 370,
            elevation: 8,
            offset: const Offset(0, -4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
          ),

          menuItemStyleData: const MenuItemStyleData(
            padding: EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ],
    );
  }

  Widget _locationCard() {
    return _formCard(
      children: [
        _professionalField(
          label: 'Service area',
          hint: 'City, area or neighborhood',
          icon: Icons.location_on_outlined,
          controller: locationController,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Service location is required';
            }

            return null;
          },
        ),
        const SizedBox(height: 13),
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isGettingLocation ? null : _captureLocation,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: _locationCaptured
                    ? _primary.withOpacity(0.08)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _locationCaptured
                      ? _primary.withOpacity(0.28)
                      : _border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isGettingLocation
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                          )
                        : Icon(
                            _locationCaptured
                                ? Icons.check_circle_rounded
                                : Icons.my_location_rounded,
                            color: _primary,
                            size: 18,
                          ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _locationCaptured
                              ? 'Location captured'
                              : 'Use current location',
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 10.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _locationCaptured
                              ? 'GPS coordinates are ready'
                              : 'Improve nearby job recommendations',
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 8.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color(0xFF94A3B8),
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bioCard() {
    return _formCard(
      children: [
        _professionalField(
          label: 'Short bio',
          hint:
              'Tell customers about your experience, specialties and work quality...',
          icon: Icons.description_outlined,
          controller: bioController,
          maxLines: 5,
          maxLength: 300,
          validator: (value) {
            final text = value?.trim() ?? '';

            if (text.isNotEmpty && text.length < 20) {
              return 'Write at least 20 characters';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _privacyNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withOpacity(0.13)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: _primary,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your information is protected',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 10.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your profile details are used to connect you with relevant customers and nearby jobs.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 8.8,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveWorkerProfile,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primary,
          disabledBackgroundColor: _primary.withOpacity(0.55),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 19),
            const SizedBox(width: 9),
            Text(
              _isSaving ? 'Saving profile...' : 'Save & continue',
              style: const TextStyle(
                fontSize: 12.2,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (!_isSaving) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _savingOverlay() {
    return ColoredBox(
      color: _textPrimary.withOpacity(0.28),
      child: Center(
        child: Container(
          width: 245,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(23),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220F172A),
                blurRadius: 30,
                offset: Offset(0, 15),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _primary, strokeWidth: 2.7),
              SizedBox(height: 16),
              Text(
                'Creating your profile',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Please wait while we securely save your professional information.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.2,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLocationSettingsDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: _warning.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.location_off_outlined,
                  color: _warning,
                  size: 29,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Location permission required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Location permission is permanently disabled. Open app settings to enable it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await Geolocator.openAppSettings();
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Open settings',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          backgroundColor: isError ? _danger : _textPrimary,
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
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
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
