import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:skill_link/screens/customer_screens/bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/customer_screens/customer_my_request_scree/request_tracking_screen.dart';

class Request extends StatefulWidget {
  final String? selectedWorkerId;
  final String? selectedService;
  const Request({super.key, this.selectedWorkerId, this.selectedService});

  @override
  State<Request> createState() => _RequestState();
}

class _RequestState extends State<Request> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _danger = Color(0xFFDC2626);

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  String _selectedCategory = 'AC Repair';
  String _selectedUrgency = 'Normal';

  bool _isSubmitting = false;
  bool _isGettingLocation = false;
  bool _useCurrentLocation = true;
  double? _customerLatitude;
  double? _customerLongitude;

  final List<ServiceOption> _categories = const [
    ServiceOption(
      title: 'AC Repair',
      icon: Icons.ac_unit_rounded,
      color: Color(0xFF0EA5E9),
    ),
    ServiceOption(
      title: 'Appliance Repair',
      icon: Icons.home_repair_service_rounded,
      color: Color(0xFF14B8A6),
    ),
    ServiceOption(
      title: 'Beautician',
      icon: Icons.face_retouching_natural_rounded,
      color: Color(0xFFEC4899),
    ),
    ServiceOption(
      title: 'Car Mechanic',
      icon: Icons.car_repair_rounded,
      color: Color(0xFF6366F1),
    ),
    ServiceOption(
      title: 'Carpenter',
      icon: Icons.carpenter_rounded,
      color: Color(0xFFF97316),
    ),
    ServiceOption(
      title: 'Cleaner',
      icon: Icons.cleaning_services_rounded,
      color: Color(0xFF10B981),
    ),
    ServiceOption(
      title: 'Electrician',
      icon: Icons.electrical_services_rounded,
      color: Color(0xFFF59E0B),
    ),
    ServiceOption(
      title: 'Gardener',
      icon: Icons.grass_rounded,
      color: Color(0xFF22C55E),
    ),
    ServiceOption(
      title: 'Home Painter',
      icon: Icons.format_paint_rounded,
      color: Color(0xFF8B5CF6),
    ),
    ServiceOption(
      title: 'Internet Technician',
      icon: Icons.router_rounded,
      color: Color(0xFF3B82F6),
    ),
    ServiceOption(
      title: 'Mobile Repair',
      icon: Icons.phone_android_rounded,
      color: Color(0xFF0F766E),
    ),
    ServiceOption(
      title: 'Pest Control',
      icon: Icons.pest_control_rounded,
      color: Color(0xFF84CC16),
    ),
    ServiceOption(
      title: 'Plumber',
      icon: Icons.plumbing_rounded,
      color: Color(0xFF06B6D4),
    ),
    ServiceOption(
      title: 'Security Guard',
      icon: Icons.security_rounded,
      color: Color(0xFF475569),
    ),
    ServiceOption(
      title: 'Solar Technician',
      icon: Icons.solar_power_rounded,
      color: Color(0xFFFACC15),
    ),
    ServiceOption(
      title: 'Tailor',
      icon: Icons.checkroom_rounded,
      color: Color(0xFFA855F7),
    ),
    ServiceOption(
      title: 'Welder',
      icon: Icons.construction_rounded,
      color: Color(0xFFEF4444),
    ),
  ];
  final List<UrgencyOption> _urgencies = const [
    UrgencyOption(
      title: 'Normal',
      subtitle: 'Within a few hours',
      icon: Icons.schedule_rounded,
      color: Color(0xFF2563EB),
    ),
    UrgencyOption(
      title: 'Urgent',
      subtitle: 'As soon as possible',
      icon: Icons.bolt_rounded,
      color: Color(0xFFF59E0B),
    ),
    UrgencyOption(
      title: 'Emergency',
      subtitle: 'Immediate assistance',
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFDC2626),
    ),
  ];

  @override
  void initState() {
    super.initState();

    final service = widget.selectedService?.trim();

    if (service != null &&
        service.isNotEmpty &&
        _categories.any((item) => item.title == service)) {
      _selectedCategory = service;
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

  Future<void> _postRequest() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _showMessage('Please complete all required fields.', isError: true);
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please sign in again before posting a request.',
        isError: true,
      );
      return;
    }

    if (_isSubmitting) return;

    // Auto get GPS location if enabled
    if (_useCurrentLocation &&
        (_customerLatitude == null || _customerLongitude == null)) {
      await _fillCurrentLocation();

      if (_customerLatitude == null || _customerLongitude == null) {
        return;
      }
    }

    final String? selectedWorkerId =
        widget.selectedWorkerId?.trim().isNotEmpty == true
        ? widget.selectedWorkerId!.trim()
        : null;

    final bool isDirectRequest = selectedWorkerId != null;

    setState(() => _isSubmitting = true);

    try {
      final DocumentReference<Map<String, dynamic>> requestRef =
          await FirebaseFirestore.instance.collection('requests').add({
            'customerId': user.uid,

            // Null means public job, otherwise direct worker request.
            'workerId': selectedWorkerId,

            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'category': _selectedCategory,
            'location': _locationController.text.trim(),
            'budget': _budgetController.text.trim(),
            'urgency': _selectedUrgency,
            'status': 'searching',

            'isDirectRequest': isDirectRequest,
            'requestType': isDirectRequest ? 'direct' : 'public',

            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'latitude': _customerLatitude,
            'longitude': _customerLongitude,
          });

      if (isDirectRequest) {
        // Direct job: only selected worker receives notification.
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': selectedWorkerId,
          'requestId': requestRef.id,
          'customerId': user.uid,
          'workerId': selectedWorkerId,
          'title': 'Direct Job Request',
          'message':
              'A customer sent you a direct $_selectedCategory service request.',
          'type': 'direct_job',
          'isDirectRequest': true,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Public job: all workers receive notification.
        final QuerySnapshot<Map<String, dynamic>> workers =
            await FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'worker')
                .get();

        final WriteBatch batch = FirebaseFirestore.instance.batch();

        for (final worker in workers.docs) {
          final DocumentReference<Map<String, dynamic>> notificationRef =
              FirebaseFirestore.instance.collection('notifications').doc();

          batch.set(notificationRef, {
            'userId': worker.id,
            'requestId': requestRef.id,
            'customerId': user.uid,
            'workerId': worker.id,
            'title': 'New Job Available',
            'message': '$_selectedCategory job posted near you.',
            'type': 'job',
            'isDirectRequest': false,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RequestTrackingScreen(requestId: requestRef.id),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.message ?? 'Request could not be posted.',
        isError: true,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage('Request could not be posted. $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          _showMessage('Please turn on location services.', isError: true);
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          _showMessage('Location permission was denied.', isError: true);
        }
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showMessage(
            'Location permission is permanently denied. Enable it from settings.',
            isError: true,
          );
        }
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to get your current location.', isError: true);
      }

      return null;
    }
  }

  Future<void> _fillCurrentLocation() async {
    if (_isGettingLocation) return;

    FocusScope.of(context).unfocus();

    setState(() => _isGettingLocation = true);

    final position = await _getCurrentLocation();

    if (!mounted) return;

    if (position != null) {
      _customerLatitude = position.latitude;
      _customerLongitude = position.longitude;

      _locationController.text =
          '${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}';

      _showMessage('Current location added successfully.');
    }

    setState(() => _isGettingLocation = false);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = _categories.firstWhere(
      (item) => item.title == _selectedCategory,
    );

    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: const CustomerBottomBar(selectedIndex: 2),
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: _ambientCircle(size: 330, color: _primary.withOpacity(0.09)),
          ),
          Positioned(
            bottom: -160,
            left: -130,
            child: _ambientCircle(
              size: 340,
              color: _secondary.withOpacity(0.06),
            ),
          ),
          SafeArea(
            child: Form(
              key: _formKey,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _header(),
                        const SizedBox(height: 20),
                        _heroCard(),
                        const SizedBox(height: 24),
                        _progressHeader(),
                        const SizedBox(height: 18),
                        _sectionCard(
                          title: 'Choose a service',
                          subtitle: 'Select the type of professional you need',
                          icon: Icons.home_repair_service_rounded,
                          child: _categoryGrid(),
                        ),
                        const SizedBox(height: 18),
                        _sectionCard(
                          title: 'Describe your problem',
                          subtitle:
                              'Add clear details so workers can respond accurately',
                          icon: Icons.description_outlined,
                          child: Column(
                            children: [
                              _professionalField(
                                controller: _titleController,
                                label: 'Problem title',
                                hint: 'Example: Ceiling fan is not working',
                                icon: Icons.title_rounded,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter a problem title';
                                  }

                                  if (value.trim().length < 5) {
                                    return 'Title must be at least 5 characters';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 15),
                              _descriptionField(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _sectionCard(
                          title: 'Location and budget',
                          subtitle:
                              'Help workers understand where and how much',
                          icon: Icons.location_on_outlined,
                          child: Column(
                            children: [
                              _locationField(),
                              const SizedBox(height: 15),
                              _professionalField(
                                controller: _budgetController,
                                label: 'Estimated budget',
                                hint: 'Example: 1500',
                                icon: Icons.payments_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: false,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                prefixText: 'Rs. ',
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your budget';
                                  }

                                  final budget = int.tryParse(value.trim());

                                  if (budget == null || budget <= 0) {
                                    return 'Enter a valid budget amount';
                                  }

                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _sectionCard(
                          title: 'Set urgency',
                          subtitle:
                              'Tell workers how quickly you need assistance',
                          icon: Icons.speed_rounded,
                          child: _urgencySelector(),
                        ),
                        const SizedBox(height: 18),
                        _summaryCard(selectedCategory),
                        const SizedBox(height: 20),
                        _submitButton(),
                        const SizedBox(height: 10),
                        const Center(
                          child: Text(
                            'Nearby workers will be notified after posting.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 9.8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isSubmitting) Positioned.fill(child: _submittingOverlay()),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          height: 50,
          width: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_primary, _secondary]),
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_task_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create request',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.45,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Post a job and connect with nearby professionals',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.7,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
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
            Icons.help_outline_rounded,
            color: _primary,
            size: 21,
          ),
        ),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(28),
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
            bottom: -90,
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
                        'FAST SERVICE REQUEST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Tell us what\nneeds fixing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Add clear details and nearby professionals will be notified instantly.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 11.7,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                height: 108,
                width: 86,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: const Icon(
                  Icons.home_repair_service_rounded,
                  color: Colors.white,
                  size: 45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressHeader() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 15,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          _stepIndicator(number: '1', label: 'Service', active: true),
          _stepLine(),
          _stepIndicator(number: '2', label: 'Details', active: true),
          _stepLine(),
          _stepIndicator(number: '3', label: 'Post', active: false),
        ],
      ),
    );
  }

  Widget _stepIndicator({
    required String number,
    required String label,
    required bool active,
  }) {
    return Column(
      children: [
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: active ? _primary : const Color(0xFFE8EDF4),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: active ? _textPrimary : _textSecondary,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _stepLine() {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.fromLTRB(7, 0, 7, 18),
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.22),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 17,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 9.8,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }

  Widget _categoryGrid() {
    return GridView.builder(
      itemCount: _categories.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 11,
        crossAxisSpacing: 11,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) {
        final category = _categories[index];
        final selected = _selectedCategory == category.title;

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() {
                _selectedCategory = category.title;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? category.color.withOpacity(0.10)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? category.color : _border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: category.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            category.icon,
                            color: category.color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          category.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? category.color : _textPrimary,
                            fontSize: 9.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        height: 20,
                        width: 20,
                        decoration: BoxDecoration(
                          color: category.color,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _professionalField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 11.7,
            fontWeight: FontWeight.w700,
          ),
          decoration: _inputDecoration(
            hint: hint,
            icon: icon,
            prefixText: prefixText,
          ),
        ),
      ],
    );
  }

  Widget _descriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Problem description'),
        TextFormField(
          controller: _descriptionController,
          minLines: 4,
          maxLines: 6,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please describe your problem';
            }

            if (value.trim().length < 15) {
              return 'Description must be at least 15 characters';
            }

            return null;
          },
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 11.7,
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
          decoration: _inputDecoration(
            hint:
                'Explain what happened, when it started and what help you need...',
            icon: Icons.description_outlined,
            alignLabelTop: true,
          ),
        ),
        const SizedBox(height: 7),
        const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _textSecondary, size: 13),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                'Clear details help workers send better offers.',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 8.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _locationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Service location'),
        TextFormField(
          controller: _locationController,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter the service location';
            }

            return null;
          },
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 11.7,
            fontWeight: FontWeight.w700,
          ),
          decoration: _inputDecoration(
            hint: 'Example: Pabbi Bazar, Nowshera',
            icon: Icons.location_on_outlined,
            suffix: IconButton(
              tooltip: 'Use current location',
              onPressed: _isGettingLocation ? null : _fillCurrentLocation,
              icon: _isGettingLocation
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: _primary,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.my_location_rounded,
                      color: _primary,
                      size: 20,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              const Icon(Icons.gps_fixed_rounded, color: _primary, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Attach GPS coordinates with this request',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 9.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _useCurrentLocation,
                activeColor: _primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (value) {
                  setState(() {
                    _useCurrentLocation = value;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _urgencySelector() {
    return Column(
      children: _urgencies.map((option) {
        final selected = _selectedUrgency == option.title;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            child: InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap: () {
                setState(() {
                  _selectedUrgency = option.title;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: selected
                      ? option.color.withOpacity(0.09)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: selected ? option.color : _border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: option.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(option.icon, color: option.color, size: 21),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.title,
                            style: TextStyle(
                              color: selected ? option.color : _textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            option.subtitle,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 9.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 22,
                      width: 22,
                      decoration: BoxDecoration(
                        color: selected ? option.color : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? option.color
                              : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _summaryCard(ServiceOption selectedCategory) {
    final urgency = _urgencies.firstWhere(
      (item) => item.title == _selectedUrgency,
    );

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            selectedCategory.color.withOpacity(0.12),
            urgency.color.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: selectedCategory.color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Request summary',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  icon: selectedCategory.icon,
                  color: selectedCategory.color,
                  title: 'Service',
                  value: selectedCategory.title,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryItem(
                  icon: urgency.icon,
                  color: urgency.color,
                  title: 'Urgency',
                  value: urgency.title,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 8.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 10.3,
                    fontWeight: FontWeight.w900,
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
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _postRequest,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: _primary,
          disabledBackgroundColor: _primary.withOpacity(0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
          shadowColor: _primary.withOpacity(0.28),
        ),
        icon: const Icon(Icons.send_rounded, size: 19),
        label: const Text(
          'Post service request',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 10.8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? prefixText,
    Widget? suffix,
    bool alignLabelTop = false,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        color: _textPrimary,
        fontWeight: FontWeight.w800,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 10.8,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Padding(
        padding: EdgeInsets.only(bottom: alignLabelTop ? 62 : 0),
        child: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: _danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: _danger, width: 1.5),
      ),
      errorStyle: const TextStyle(
        color: _danger,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _submittingOverlay() {
    return ColoredBox(
      color: _textPrimary.withOpacity(0.26),
      child: Center(
        child: Container(
          width: 245,
          padding: const EdgeInsets.all(23),
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
                'Posting your request',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'We are notifying nearby professionals.',
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

class ServiceOption {
  final String title;
  final IconData icon;
  final Color color;

  const ServiceOption({
    required this.title,
    required this.icon,
    required this.color,
  });
}

class UrgencyOption {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const UrgencyOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
