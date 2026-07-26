import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_detail_screen.dart';
import 'package:skill_link/screens/customer_screens/customer_my_request_scree/RateWorkerScreen.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestTrackingScreen extends StatefulWidget {
  final String requestId;

  const RequestTrackingScreen({super.key, required this.requestId});

  @override
  State<RequestTrackingScreen> createState() => _RequestTrackingScreenState();
}

class _RequestTrackingScreenState extends State<RequestTrackingScreen> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF16A34A);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFDC2626);

  bool _searchingDone = false;
  bool _isSendingToWorker = false;

  @override
  void initState() {
    super.initState();

    Future<void>.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _searchingDone = true);
      }
    });
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
            child: _ambientCircle(size: 330, color: _primary.withOpacity(0.09)),
          ),
          Positioned(
            bottom: -170,
            left: -140,
            child: _ambientCircle(
              size: 350,
              color: _secondary.withOpacity(0.06),
            ),
          ),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .doc(widget.requestId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _loadingView();
                }

                if (snapshot.hasError) {
                  return _errorView(
                    title: 'Unable to load request',
                    message:
                        'Please check your internet connection and try again.',
                  );
                }

                if (!snapshot.hasData ||
                    !snapshot.data!.exists ||
                    snapshot.data!.data() == null) {
                  return _errorView(
                    title: 'Request not found',
                    message:
                        'This request may have been removed or is no longer available.',
                  );
                }

                final data = snapshot.data!.data()!;
                final status = _statusValue(data['status']);
                final workerId = data['workerId']?.toString().trim();

                return Column(
                  children: [
                    _topBar(status),
                    Expanded(
                      child: _buildStatusBody(
                        status: status,
                        requestData: data,
                        workerId: workerId,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_isSendingToWorker) Positioned.fill(child: _blockingLoader()),
        ],
      ),
    );
  }

  Widget _buildStatusBody({
    required String status,
    required Map<String, dynamic> requestData,
    required String? workerId,
  }) {
    if (status == 'completed') {
      return _completedView(requestData);
    }

    if (workerId != null && workerId.isNotEmpty) {
      if (status == 'accepted') {
        return _activeWorkerView(
          workerId: workerId,
          requestData: requestData,
          status: status,
          heroIcon: Icons.handshake_rounded,
          heroTitle: 'Worker accepted your request',
          heroSubtitle: 'You are now connected with a professional.',
          accent: _success,
          showMap: false,
        );
      }

      if (status == 'on_the_way') {
        return _activeWorkerView(
          workerId: workerId,
          requestData: requestData,
          status: status,
          heroIcon: Icons.directions_bike_rounded,
          heroTitle: 'Worker is on the way',
          heroSubtitle: 'Track the worker’s live location and stay connected.',
          accent: const Color(0xFF0EA5E9),
          showMap: true,
        );
      }

      if (status == 'in_progress') {
        return _activeWorkerView(
          workerId: workerId,
          requestData: requestData,
          status: status,
          heroIcon: Icons.build_circle_rounded,
          heroTitle: 'Job is in progress',
          heroSubtitle: 'Your selected professional has started the work.',
          accent: _warning,
          showMap: false,
        );
      }
    }

    if (!_searchingDone) {
      return _searchingView(requestData);
    }

    return _nearestWorkerFinder(requestData);
  }

  Widget _topBar(String status) {
    final statusDesign = _statusDesign(status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.maybePop(context),
              child: Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
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
                  Icons.arrow_back_ios_new_rounded,
                  color: _textPrimary,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request tracking',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.45,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Live updates for your service request',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: statusDesign.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(statusDesign.icon, color: statusDesign.color, size: 14),
                const SizedBox(width: 5),
                Text(
                  statusDesign.label,
                  style: TextStyle(
                    color: statusDesign.color,
                    fontSize: 9.5,
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

  Widget _activeWorkerView({
    required String workerId,
    required Map<String, dynamic> requestData,
    required String status,
    required IconData heroIcon,
    required String heroTitle,
    required String heroSubtitle,
    required Color accent,
    required bool showMap,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(workerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _inlineLoader('Loading worker details...');
        }

        if (!snapshot.hasData ||
            !snapshot.data!.exists ||
            snapshot.data!.data() == null) {
          return _errorView(
            title: 'Worker profile unavailable',
            message: 'The assigned worker profile could not be loaded.',
            includeTopPadding: false,
          );
        }

        final worker = snapshot.data!.data()!;

        return RefreshIndicator(
          color: accent,
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 550));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 42),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _statusHero(
                      icon: heroIcon,
                      title: heroTitle,
                      subtitle: heroSubtitle,
                      accent: accent,
                    ),
                    const SizedBox(height: 18),
                    if (showMap) ...[
                      _liveWorkerMap(
                        workerId: workerId,
                        worker: worker,
                        accent: accent,
                      ),
                      const SizedBox(height: 18),
                    ],
                    _workerCard(
                      workerId: workerId,
                      worker: worker,
                      accent: accent,
                    ),
                    const SizedBox(height: 18),
                    _requestSummary(requestData),
                    const SizedBox(height: 18),
                    _timelineCard(status),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusHero({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, Color.lerp(accent, _secondary, 0.48)!],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.23),
            blurRadius: 27,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -65,
            right: -50,
            child: Container(
              height: 165,
              width: 165,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -85,
            left: -55,
            child: Container(
              height: 175,
              width: 175,
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
                        'LIVE REQUEST UPDATE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        height: 1.16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.55,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 11.3,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                height: 92,
                width: 78,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Icon(icon, color: Colors.white, size: 42),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveWorkerMap({
    required String workerId,
    required Map<String, dynamic> worker,
    required Color accent,
  }) {
    final lat = _doubleValue(worker['lat'], 34.0097);
    final lng = _doubleValue(worker['lng'], 71.9970);
    final workerPosition = LatLng(lat, lng);

    return Container(
      height: 245,
      width: double.infinity,
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
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: workerPosition,
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('worker'),
                position: workerPosition,
                infoWindow: InfoWindow(
                  title: _fallback(worker['name'], 'Worker'),
                  snippet: 'Live worker location',
                ),
              ),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _surface.withOpacity(0.94),
                borderRadius: BorderRadius.circular(13),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x110F172A),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 9,
                    width: 9,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Live location',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 9.4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workerCard({
    required String workerId,
    required Map<String, dynamic> worker,
    required Color accent,
  }) {
    final name = _fallback(worker['name'], 'Skilled worker');
    final skill = _fallback(worker['skill'], 'Professional service');
    final phone = _fallback(worker['phone'], 'Phone unavailable');
    final location = _fallback(
      worker['location'] ?? worker['city'],
      'Location unavailable',
    );
    final rating = _doubleValue(worker['rating'], 0);
    final completedJobs = _intValue(worker['completedJobs']);
    final verified = worker['isVerified'] == true || worker['verified'] == true;

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
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, Color.lerp(accent, _secondary, 0.45)!],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      height: 20,
                      width: 20,
                      decoration: BoxDecoration(
                        color: _success,
                        shape: BoxShape.circle,
                        border: Border.all(color: _surface, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified_rounded,
                            color: _primary,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      skill,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: _textSecondary,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: _warning, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _workerMetric(
                    icon: Icons.work_outline_rounded,
                    value: '$completedJobs',
                    label: 'Jobs done',
                    color: _primary,
                  ),
                ),
                _metricDivider(),
                Expanded(
                  child: _workerMetric(
                    icon: Icons.phone_outlined,
                    value: phone,
                    label: 'Contact',
                    color: accent,
                  ),
                ),
                _metricDivider(),
                Expanded(
                  child: _workerMetric(
                    icon: Icons.shield_outlined,
                    value: verified ? 'Verified' : 'Trusted',
                    label: 'Profile',
                    color: _success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _makePhoneCall(worker['phone']?.toString() ?? ''),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textPrimary,
                    side: const BorderSide(color: _border),
                    minimumSize: const Size(0, 47),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.call_outlined, size: 17),
                  label: const Text(
                    'Call',
                    style: TextStyle(
                      fontSize: 10.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _openChat(workerId: workerId, worker: worker);
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    foregroundColor: Colors.white,
                    backgroundColor: accent,
                    minimumSize: const Size(0, 47),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  label: const Text(
                    'Chat',
                    style: TextStyle(
                      fontSize: 10.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workerMetric({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 9.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 8.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _metricDivider() {
    return Container(width: 1, height: 30, color: _border);
  }

  Widget _requestSummary(Map<String, dynamic> data) {
    final title = _fallback(data['title'], 'Service request');
    final category = _fallback(data['category'], 'General service');
    final location = _fallback(data['location'], 'Location unavailable');
    final budget = _formatBudget(data['budget']);
    final urgency = _fallback(data['urgency'], 'Normal');
    final description = _fallback(
      data['description'],
      'No additional description was provided.',
    );

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
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: _primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request details',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Summary of your posted service request',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 9.7,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 14.2,
              height: 1.3,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 10.4,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _summaryRow(
                  icon: _categoryIcon(category),
                  label: 'Category',
                  value: category,
                ),
                const SizedBox(height: 10),
                _summaryDivider(),
                const SizedBox(height: 10),
                _summaryRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: location,
                ),
                const SizedBox(height: 10),
                _summaryDivider(),
                const SizedBox(height: 10),
                _summaryRow(
                  icon: Icons.payments_outlined,
                  label: 'Budget',
                  value: budget,
                ),
                const SizedBox(height: 10),
                _summaryDivider(),
                const SizedBox(height: 10),
                _summaryRow(
                  icon: Icons.speed_rounded,
                  label: 'Urgency',
                  value: urgency,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: _primary, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 8.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 10.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryDivider() {
    return Container(height: 1, color: _border);
  }

  Widget _timelineCard(String status) {
    final currentIndex = _statusIndex(status);

    final steps = [
      const TimelineStepData(
        title: 'Request sent',
        subtitle: 'Looking for available workers',
        icon: Icons.send_rounded,
      ),
      const TimelineStepData(
        title: 'Worker accepted',
        subtitle: 'A worker accepted your job',
        icon: Icons.handshake_outlined,
      ),
      const TimelineStepData(
        title: 'On the way',
        subtitle: 'Worker is heading to your location',
        icon: Icons.directions_bike_rounded,
      ),
      const TimelineStepData(
        title: 'Job in progress',
        subtitle: 'Work started at your location',
        icon: Icons.build_circle_outlined,
      ),
      const TimelineStepData(
        title: 'Completed',
        subtitle: 'Job successfully finished',
        icon: Icons.task_alt_rounded,
      ),
    ];

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
          const Text(
            'Request progress',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Follow each stage of your service request',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 9.7,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final active = index <= currentIndex;
            final current = index == currentIndex;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 35,
                      width: 35,
                      decoration: BoxDecoration(
                        color: active
                            ? _statusColorByIndex(index)
                            : const Color(0xFFE8EDF4),
                        shape: BoxShape.circle,
                        boxShadow: current
                            ? [
                                BoxShadow(
                                  color: _statusColorByIndex(
                                    index,
                                  ).withOpacity(0.22),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        active ? Icons.check_rounded : step.icon,
                        color: active ? Colors.white : const Color(0xFF94A3B8),
                        size: 16,
                      ),
                    ),
                    if (index != steps.length - 1)
                      Container(
                        width: 3,
                        height: 42,
                        decoration: BoxDecoration(
                          color: index < currentIndex
                              ? _statusColorByIndex(index + 1)
                              : const Color(0xFFE8EDF4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                step.title,
                                style: TextStyle(
                                  color: active ? _textPrimary : _textSecondary,
                                  fontSize: 11.4,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (current)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColorByIndex(
                                    index,
                                  ).withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'CURRENT',
                                  style: TextStyle(
                                    color: _statusColorByIndex(index),
                                    fontSize: 7.8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.subtitle,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 9.4,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _nearestWorkerFinder(Map<String, dynamic> requestData) {
    final category = requestData['category']?.toString().trim() ?? '';

    final customerLatitude = _nullableDouble(requestData['latitude']);

    final customerLongitude = _nullableDouble(requestData['longitude']);

    if (customerLatitude == null || customerLongitude == null) {
      return _errorView(
        title: 'Location unavailable',
        message:
            'Customer GPS coordinates are missing. Please post the request using your current location.',
        includeTopPadding: false,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'worker')
          .where('profileCompleted', isEqualTo: true)
          .where('skill', isEqualTo: category)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _searchingView(requestData);
        }

        if (snapshot.hasError) {
          return _errorView(
            title: 'Worker search failed',
            message: 'Nearby professionals could not be loaded right now.',
            includeTopPadding: false,
          );
        }

        final workerDocuments = snapshot.data?.docs ?? [];

        final List<NearbyWorkerResult> nearbyWorkers = [];

        for (final workerDocument in workerDocuments) {
          final worker = workerDocument.data();

          final workerLatitude = _nullableDouble(worker['lat']);

          final workerLongitude = _nullableDouble(worker['lng']);

          if (workerLatitude == null || workerLongitude == null) {
            continue;
          }

          final distanceInMeters = Geolocator.distanceBetween(
            customerLatitude,
            customerLongitude,
            workerLatitude,
            workerLongitude,
          );

          final distanceInKm = distanceInMeters / 1000;

          // Sirf 10 KM ke andar workers
          if (distanceInKm <= 10) {
            nearbyWorkers.add(
              NearbyWorkerResult(
                document: workerDocument,
                distanceKm: distanceInKm,
              ),
            );
          }
        }

        // Sabse nearest worker sabse pehle
        nearbyWorkers.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

        if (nearbyWorkers.isEmpty) {
          return _noNearbyWorkersFound(requestData, category);
        }

        return _nearbyWorkersView(
          requestData: requestData,
          nearbyWorkers: nearbyWorkers,
        );
      },
    );
  }

  double? _nullableDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    final text = value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return double.tryParse(text);
  }

  Widget _nearbyWorkersView({
    required Map<String, dynamic> requestData,
    required List<NearbyWorkerResult> nearbyWorkers,
  }) {
    final category = _fallback(requestData['category'], 'Service');

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 42),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _nearbyWorkersHero(
                category: category,
                totalWorkers: nearbyWorkers.length,
              ),
              const SizedBox(height: 18),

              ...nearbyWorkers.map((result) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _nearbyWorkerCard(
                    workerId: result.document.id,
                    worker: result.document.data(),
                    distanceKm: result.distanceKm,
                  ),
                );
              }),

              const SizedBox(height: 4),
              _requestSummary(requestData),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _nearbyWorkersHero({
    required String category,
    required int totalWorkers,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.23),
            blurRadius: 27,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
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
                    'NEARBY PROFESSIONALS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.7,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '$totalWorkers nearby workers found',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$category professionals within 10 KM of your location.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.82),
                    fontSize: 10.8,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            height: 82,
            width: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(.18)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.location_searching_rounded,
                  color: Colors.white,
                  size: 35,
                ),
                Positioned(
                  top: 11,
                  right: 10,
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 22,
                      minWidth: 22,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: _warning,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$totalWorkers',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nearbyWorkerCard({
    required String workerId,
    required Map<String, dynamic> worker,
    required double distanceKm,
  }) {
    final name = _fallback(worker['name'], 'Skilled Worker');

    final skill = _fallback(worker['skill'], 'Professional Service');

    final city = _fallback(worker['city'] ?? worker['location'], 'Nearby');

    final rating = _doubleValue(worker['rating'], 0);

    final totalReviews = _intValue(worker['totalReviews']);

    final completedJobs = _intValue(worker['completedJobs']);

    final verified = worker['isVerified'] == true || worker['verified'] == true;

    return Container(
      width: double.infinity,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_primary, _secondary]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_primary, _secondary],
                          ),
                          borderRadius: BorderRadius.circular(19),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials(name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _textPrimary,
                                      fontSize: 14.7,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (verified) ...[
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: _primary,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              skill,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: _textSecondary,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    city,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _textSecondary,
                                      fontSize: 9.4,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _success.withOpacity(.09),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.near_me_rounded,
                              color: _success,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distanceKm < 1
                                  ? '${(distanceKm * 1000).round()} m'
                                  : '${distanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                color: _success,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _workerMetric(
                            icon: Icons.star_rounded,
                            value: rating.toStringAsFixed(1),
                            label: '$totalReviews reviews',
                            color: _warning,
                          ),
                        ),
                        _metricDivider(),
                        Expanded(
                          child: _workerMetric(
                            icon: Icons.work_outline_rounded,
                            value: '$completedJobs',
                            label: 'Jobs done',
                            color: _primary,
                          ),
                        ),
                        _metricDivider(),
                        Expanded(
                          child: _workerMetric(
                            icon: Icons.near_me_outlined,
                            value: distanceKm < 1
                                ? '${(distanceKm * 1000).round()}m'
                                : '${distanceKm.toStringAsFixed(1)}km',
                            label: 'Distance',
                            color: _success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSendingToWorker
                          ? null
                          : () => _sendRequestToWorker(workerId),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Send Request'),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        foregroundColor: Colors.white,
                        backgroundColor: _primary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 10.6,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noNearbyWorkersFound(
    Map<String, dynamic> requestData,
    String category,
  ) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 42),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(27),
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
                  children: [
                    Container(
                      height: 76,
                      width: 76,
                      decoration: BoxDecoration(
                        color: _warning.withOpacity(.10),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.location_off_outlined,
                        color: _warning,
                        size: 37,
                      ),
                    ),
                    const SizedBox(height: 17),
                    Text(
                      'No nearby $category found',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'No matching professional is currently available within 10 KM of your location.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10.7,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _requestSummary(requestData),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _searchingView(Map<String, dynamic> requestData) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 42),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _searchingHero(),
              const SizedBox(height: 18),
              _requestSummary(requestData),
              const SizedBox(height: 18),
              _timelineCard('searching'),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _searchingHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 25),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
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
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 130,
                width: 130,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.07),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                height: 98,
                width: 98,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.11),
                  shape: BoxShape.circle,
                ),
              ),
              const Icon(
                Icons.person_search_rounded,
                color: _primary,
                size: 52,
              ),
              const Positioned(top: 2, right: 14, child: _PulseDot()),
            ],
          ),
          const SizedBox(height: 21),
          const Text(
            'Searching nearby workers',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.45,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We are matching your request with skilled professionals near your location.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 10.8,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 7,
              color: _primary,
              backgroundColor: _primary.withOpacity(0.10),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: _primary,
                  size: 15,
                ),
                SizedBox(width: 6),
                Text(
                  'Nearby professionals are being notified',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 9.3,
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

  // Widget _foundWorkerView({
  //   required Map<String, dynamic> requestData,
  //   required String workerId,
  //   required Map<String, dynamic> worker,
  // }) {
  //   return CustomScrollView(
  //     physics: const BouncingScrollPhysics(),
  //     slivers: [
  //       SliverPadding(
  //         padding: const EdgeInsets.fromLTRB(20, 18, 20, 42),
  //         sliver: SliverList(
  //           delegate: SliverChildListDelegate([
  //             _statusHero(
  //               icon: Icons.person_search_rounded,
  //               title: 'Nearby worker found',
  //               subtitle:
  //                   'A professional matching your service category is available.',
  //               accent: _success,
  //             ),
  //             const SizedBox(height: 18),
  //             _workerCard(workerId: workerId, worker: worker, accent: _success),
  //             const SizedBox(height: 18),
  //             _requestSummary(requestData),
  //             const SizedBox(height: 18),
  //             SizedBox(
  //               height: 56,
  //               width: double.infinity,
  //               child: ElevatedButton.icon(
  //                 onPressed: _isSendingToWorker
  //                     ? null
  //                     : () => _sendRequestToWorker(workerId),
  //                 style: ElevatedButton.styleFrom(
  //                   elevation: 0,
  //                   foregroundColor: Colors.white,
  //                   backgroundColor: _primary,
  //                   disabledBackgroundColor: _primary.withOpacity(0.55),
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(18),
  //                   ),
  //                 ),
  //                 icon: const Icon(Icons.send_rounded, size: 18),
  //                 label: const Text(
  //                   'Send request to this worker',
  //                   style: TextStyle(
  //                     fontSize: 11.8,
  //                     fontWeight: FontWeight.w900,
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           ]),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // Widget _noWorkerFound(Map<String, dynamic> requestData) {
  //   return CustomScrollView(
  //     physics: const BouncingScrollPhysics(),
  //     slivers: [
  //       SliverPadding(
  //         padding: const EdgeInsets.fromLTRB(20, 18, 20, 42),
  //         sliver: SliverList(
  //           delegate: SliverChildListDelegate([
  //             Container(
  //               width: double.infinity,
  //               padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
  //               decoration: BoxDecoration(
  //                 color: _surface,
  //                 borderRadius: BorderRadius.circular(27),
  //                 border: Border.all(color: _border),
  //                 boxShadow: const [
  //                   BoxShadow(
  //                     color: Color(0x080F172A),
  //                     blurRadius: 18,
  //                     offset: Offset(0, 9),
  //                   ),
  //                 ],
  //               ),
  //               child: Column(
  //                 children: [
  //                   Container(
  //                     height: 75,
  //                     width: 75,
  //                     decoration: BoxDecoration(
  //                       color: _textSecondary.withOpacity(0.09),
  //                       borderRadius: BorderRadius.circular(24),
  //                     ),
  //                     child: const Icon(
  //                       Icons.person_off_rounded,
  //                       color: _textSecondary,
  //                       size: 38,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 17),
  //                   const Text(
  //                     'No worker available yet',
  //                     textAlign: TextAlign.center,
  //                     style: TextStyle(
  //                       color: _textPrimary,
  //                       fontSize: 20,
  //                       fontWeight: FontWeight.w900,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 7),
  //                   const Text(
  //                     'No matching professional is available right now. Your request remains active.',
  //                     textAlign: TextAlign.center,
  //                     style: TextStyle(
  //                       color: _textSecondary,
  //                       fontSize: 10.8,
  //                       height: 1.5,
  //                       fontWeight: FontWeight.w600,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 18),
  //                   Container(
  //                     padding: const EdgeInsets.symmetric(
  //                       horizontal: 11,
  //                       vertical: 9,
  //                     ),
  //                     decoration: BoxDecoration(
  //                       color: _warning.withOpacity(0.09),
  //                       borderRadius: BorderRadius.circular(13),
  //                     ),
  //                     child: const Row(
  //                       mainAxisSize: MainAxisSize.min,
  //                       children: [
  //                         Icon(
  //                           Icons.schedule_rounded,
  //                           color: _warning,
  //                           size: 15,
  //                         ),
  //                         SizedBox(width: 6),
  //                         Text(
  //                           'We will continue checking',
  //                           style: TextStyle(
  //                             color: _warning,
  //                             fontSize: 9.4,
  //                             fontWeight: FontWeight.w900,
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             const SizedBox(height: 18),
  //             _requestSummary(requestData),
  //             const SizedBox(height: 18),
  //             _timelineCard('searching'),
  //           ]),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _completedView(Map<String, dynamic> data) {
    final reviewed = data['reviewed'] == true;
    final workerId = data['workerId']?.toString().trim();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 42),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _statusHero(
                icon: Icons.task_alt_rounded,
                title: 'Job completed successfully',
                subtitle: 'Your service request has been marked as completed.',
                accent: _success,
              ),
              const SizedBox(height: 18),
              _requestSummary(data),
              const SizedBox(height: 18),
              _timelineCard('completed'),
              const SizedBox(height: 18),
              if (!reviewed)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: workerId == null || workerId.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RateWorkerScreen(
                                  workerId: workerId,
                                  requestId: widget.requestId,
                                ),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      foregroundColor: Colors.white,
                      backgroundColor: _success,
                      disabledBackgroundColor: _textSecondary.withOpacity(0.25),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.star_rounded, size: 19),
                    label: const Text(
                      'Rate your worker',
                      style: TextStyle(
                        fontSize: 11.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _success.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _success.withOpacity(0.20)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: _success,
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Your review has been submitted',
                        style: TextStyle(
                          color: _success,
                          fontSize: 10.8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _sendRequestToWorker(String workerId) async {
    setState(() => _isSendingToWorker = true);

    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(widget.requestId)
          .update({
            'suggestedWorkerId': workerId,
            'status': 'waiting_worker',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      _showMessage('Request sent to worker successfully.');
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Request could not be sent. ${error.toString()}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingToWorker = false);
      }
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanedPhone = phone.trim();

    if (cleanedPhone.isEmpty) {
      _showMessage('Worker phone number is not available.', isError: true);
      return;
    }

    final phoneUri = Uri(scheme: 'tel', path: cleanedPhone);

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showMessage('Phone dialer could not be opened.', isError: true);
      }
    } catch (_) {
      _showMessage('Unable to start the phone call.', isError: true);
    }
  }

  Future<void> _openChat({
    required String workerId,
    required Map<String, dynamic> worker,
  }) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(widget.requestId)
          .get();

      final requestData = requestDoc.data();

      if (requestData == null) {
        _showMessage('Request details could not be loaded.', isError: true);
        return;
      }

      String? chatId = requestData['chatId']?.toString().trim();

      if (chatId == null || chatId.isEmpty) {
        final chatDoc = await FirebaseFirestore.instance
            .collection('chats')
            .add({
              'customerId': requestData['customerId'],
              'workerId': workerId,
              'requestId': widget.requestId,
              'service': requestData['category'],
              'lastMessage': '',
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });

        chatId = chatDoc.id;

        await FirebaseFirestore.instance
            .collection('requests')
            .doc(widget.requestId)
            .update({
              'chatId': chatId,
              'suggestedWorkerId': workerId,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            chatId: chatId!,
            workerId: _fallback(worker['workerId'], ''),
            workerName: _fallback(worker['name'], 'Worker'),
            workerSkill: _fallback(worker['skill'], 'Unknown'),
            workerPhone: worker['phone']?.toString(),
            workerImageUrl: worker['profileImage']?.toString(),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Chat could not be opened. ${error.toString()}',
        isError: true,
      );
    }
  }

  Widget _loadingView() {
    return Column(
      children: [
        _topBar('searching'),
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _border),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _primary, strokeWidth: 2.6),
                  SizedBox(height: 15),
                  Text(
                    'Loading request status...',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _inlineLoader(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _primary, strokeWidth: 2.6),
            const SizedBox(height: 14),
            Text(
              message,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView({
    required String title,
    required String message,
    bool includeTopPadding = true,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, includeTopPadding ? 24 : 10, 20, 30),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 62,
                width: 62,
                decoration: BoxDecoration(
                  color: _danger.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: _danger,
                  size: 31,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.7,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blockingLoader() {
    return ColoredBox(
      color: _textPrimary.withOpacity(0.28),
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
                'Sending request',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Please wait while we contact the worker.',
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

  StatusDesign _statusDesign(String status) {
    switch (status) {
      case 'accepted':
        return const StatusDesign(
          label: 'Accepted',
          icon: Icons.handshake_outlined,
          color: _success,
        );
      case 'on_the_way':
        return const StatusDesign(
          label: 'On the way',
          icon: Icons.directions_bike_rounded,
          color: Color(0xFF0EA5E9),
        );
      case 'in_progress':
        return const StatusDesign(
          label: 'In progress',
          icon: Icons.build_circle_outlined,
          color: _warning,
        );
      case 'completed':
        return const StatusDesign(
          label: 'Completed',
          icon: Icons.task_alt_rounded,
          color: _success,
        );
      case 'waiting_worker':
        return const StatusDesign(
          label: 'Waiting',
          icon: Icons.hourglass_top_rounded,
          color: _warning,
        );
      default:
        return const StatusDesign(
          label: 'Searching',
          icon: Icons.person_search_rounded,
          color: _primary,
        );
    }
  }

  String _statusValue(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';

    const supported = {
      'searching',
      'waiting_worker',
      'accepted',
      'on_the_way',
      'in_progress',
      'completed',
    };

    return supported.contains(status) ? status : 'searching';
  }

  int _statusIndex(String status) {
    switch (status) {
      case 'accepted':
        return 1;
      case 'on_the_way':
        return 2;
      case 'in_progress':
        return 3;
      case 'completed':
        return 4;
      default:
        return 0;
    }
  }

  Color _statusColorByIndex(int index) {
    switch (index) {
      case 1:
        return _success;
      case 2:
        return const Color(0xFF0EA5E9);
      case 3:
        return _warning;
      case 4:
        return _success;
      default:
        return _primary;
    }
  }

  String _fallback(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatBudget(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return 'Budget not specified';
    }

    if (text.toLowerCase().contains('rs')) {
      return text;
    }

    return 'Rs. $text';
  }

  double _doubleValue(dynamic value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _intValue(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  IconData _categoryIcon(String category) {
    final value = category.toLowerCase();

    if (value.contains('electric')) {
      return Icons.electrical_services_rounded;
    }
    if (value.contains('plumb')) {
      return Icons.plumbing_rounded;
    }
    if (value.contains('paint')) {
      return Icons.format_paint_rounded;
    }
    if (value.contains('carpenter')) {
      return Icons.carpenter_rounded;
    }
    if (value.contains('ac') || value.contains('air')) {
      return Icons.ac_unit_rounded;
    }
    if (value.contains('clean')) {
      return Icons.cleaning_services_rounded;
    }

    return Icons.home_repair_service_rounded;
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'SW';

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
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

class StatusDesign {
  final String label;
  final IconData icon;
  final Color color;

  const StatusDesign({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class TimelineStepData {
  final String title;
  final String subtitle;
  final IconData icon;

  const TimelineStepData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();

    _scale = Tween<double>(
      begin: 0.85,
      end: 1.45,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacity = Tween<double>(
      begin: 0.9,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.20),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Container(
          height: 12,
          width: 12,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class NearbyWorkerResult {
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final double distanceKm;

  const NearbyWorkerResult({required this.document, required this.distanceKm});
}
