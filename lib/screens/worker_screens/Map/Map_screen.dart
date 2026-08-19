import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/worker_screens/Map/worker_job_detail.dart';

class MapSreen extends StatefulWidget {
  const MapSreen({super.key});

  @override
  State<MapSreen> createState() => _MapSreenState();
}

class _MapSreenState extends State<MapSreen> {
  static const LatLng pabbiCenter = LatLng(34.0097, 71.9970);

  static const Color _primary = Color(0xFF16A34A);
  static const Color _primaryDark = Color(0xFF0F7A38);
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE7ECF3);

  GoogleMapController? mapController;
  bool _mapExpanded = false;
  bool _isMapView = false;
  bool _isLocating = false;
  Position? _workerPosition;
  String? _selectedJobId;
  Map<String, dynamic>? _selectedJobData;

  @override
  void initState() {
    super.initState();
    _ensureWorkerLocation();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getRequestsStream(
    String workerSkill,
  ) {
    return FirebaseFirestore.instance
        .collection('requests')
        .where('status', isEqualTo: 'searching')
        .where('category', isEqualTo: workerSkill)
        .snapshots();
  }

  Set<Marker> _buildMarkers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) {
      final data = doc.data();
      final lat = (data['lat'] as num?)?.toDouble() ?? 34.0097;
      final lng = (data['lng'] as num?)?.toDouble() ?? 71.9970;

      return Marker(
        markerId: MarkerId(doc.id),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(
          title: (data['title'] ?? 'Job Request').toString(),
          snippet: (data['location'] ?? '').toString(),
          onTap: () => _openJobDetail(doc.id, data),
        ),
        onTap: () {
          setState(() {
            _selectedJobId = doc.id;
            _selectedJobData = data;
          });
          mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: LatLng(lat, lng), zoom: 15),
            ),
          );
        },
      );
    }).toSet();
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: const WorkerBottomBar(selectedIndex: 1),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .snapshots(),
          builder: (context, workerSnapshot) {
            if (workerSnapshot.connectionState == ConnectionState.waiting) {
              return _fullPageLoader();
            }

            if (workerSnapshot.hasError) {
              return _fullPageError('Unable to load your worker profile.');
            }

            final workerData = workerSnapshot.data?.data();
            final workerSkill = (workerData?['skill'] ?? '').toString().trim();

            if (workerSkill.isEmpty) {
              return _missingSkillState();
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: getRequestsStream(workerSkill),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _fullPageLoader();
                }

                if (snapshot.hasError) {
                  return _fullPageError('Unable to load nearby job requests.');
                }

                final documents = snapshot.data?.docs ?? [];

                final String currentWorkerId =
                    FirebaseAuth.instance.currentUser!.uid;

                final docs = documents.where((doc) {
                  final data = doc.data();

                  final String assignedWorkerId =
                      data['workerId']?.toString().trim() ?? '';

                  final bool isPublic = assignedWorkerId.isEmpty;

                  final bool isForCurrentWorker =
                      assignedWorkerId == currentWorkerId;

                  return isPublic || isForCurrentWorker;
                }).toList();

                return RefreshIndicator(
                  color: _primary,
                  onRefresh: () async {
                    setState(() {});
                    await Future<void>.delayed(
                      const Duration(milliseconds: 400),
                    );
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _header(
                              count: docs.length,
                              workerSkill: workerSkill,
                            ),
                            const SizedBox(height: 16),
                            _viewModeToggle(),
                            const SizedBox(height: 18),
                            if (_isMapView) ...[
                              _googleMap(docs),
                              const SizedBox(height: 14),
                              if (_selectedJobId != null &&
                                  _selectedJobData != null)
                                _requestCard(_selectedJobId!, _selectedJobData!)
                              else
                                _mapDiscoveryHint(docs.length),
                            ] else ...[
                              _sectionHeader(docs.length),
                              const SizedBox(height: 14),
                              if (docs.isEmpty)
                                _emptyState(workerSkill)
                              else
                                ...docs.map(
                                  (doc) => _requestCard(doc.id, doc.data()),
                                ),
                            ],
                          ]),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _header({required int count, required String workerSkill}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nearby jobs',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 27,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Live $workerSkill requests around you',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF8EF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD5F0DE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.work_outline_rounded, color: _primary, size: 16),
              const SizedBox(width: 6),
              Text(
                '$count ${count == 1 ? 'job' : 'jobs'}',
                style: const TextStyle(
                  color: _primaryDark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _viewModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _viewModeButton(
              label: 'List',
              icon: Icons.view_agenda_outlined,
              selected: !_isMapView,
              onTap: () {
                if (!_isMapView) return;
                setState(() {
                  _isMapView = false;
                  _selectedJobId = null;
                  _selectedJobData = null;
                });
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _viewModeButton(
              label: 'Map',
              icon: Icons.map_outlined,
              selected: _isMapView,
              onTap: () {
                if (_isMapView) return;
                setState(() => _isMapView = true);
                _ensureWorkerLocation();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewModeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          decoration: BoxDecoration(
            color: selected ? _surface : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x100F172A),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? _primary : _textSecondary),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _textPrimary : _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapDiscoveryHint(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF8EF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.touch_app_rounded,
              color: _primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              count == 0
                  ? 'New nearby jobs will appear on this map automatically.'
                  : 'Tap a job marker to preview budget, location and request details.',
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ensureWorkerLocation() async {
    if (_isLocating) return;

    setState(() => _isLocating = true);
    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() => _workerPosition = position);

      await mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 14.2,
          ),
        ),
      );
    } catch (_) {
      // Nearby jobs remain available even when location permission is denied.
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Widget _googleMap(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final mapHeight = _mapExpanded ? 640.0 : (_isMapView ? 540.0 : 250.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      height: mapHeight,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: const CameraPosition(
                target: pabbiCenter,
                zoom: 13,
              ),
              markers: _buildMarkers(docs),
              myLocationEnabled: _workerPosition != null,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (controller) {
                mapController = controller;
                if (docs.isNotEmpty) {
                  _fitMarkers(docs);
                }
              },
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x190F172A),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.radar_rounded, size: 17, color: _primary),
                  SizedBox(width: 7),
                  Text(
                    'Live requests',
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
          Positioned(
            top: 14,
            right: 14,
            child: Column(
              children: [
                _mapActionButton(
                  icon: _mapExpanded
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  onTap: () => setState(() => _mapExpanded = !_mapExpanded),
                ),
                const SizedBox(height: 10),
                _mapActionButton(
                  icon: Icons.my_location_rounded,
                  onTap: _ensureWorkerLocation,
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: _textPrimary.withOpacity(0.92),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.touch_app_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      docs.isEmpty
                          ? 'No map requests available right now'
                          : 'Tap a marker to view job details',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
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

  Widget _mapActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x180F172A),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, color: _textPrimary, size: 21),
        ),
      ),
    );
  }

  Widget _sectionHeader(int count) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available jobs',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Choose a request that suits you',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (count > 0)
          Text(
            '$count found',
            style: const TextStyle(
              color: _primary,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }

  Widget _requestCard(String requestId, Map<String, dynamic> item) {
    final category = (item['category'] ?? 'Service').toString();
    final title = (item['title'] ?? 'No title').toString();
    final budget = (item['budget'] ?? 'Budget not provided').toString();
    final location = (item['location'] ?? 'Location not provided').toString();
    final urgency = (item['urgency'] ?? 'Normal').toString();
    final urgencyStyle = _urgencyStyle(urgency);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B0F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBox(category),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16.5,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _badge(
                label: urgencyStyle.label,
                foreground: urgencyStyle.foreground,
                background: urgencyStyle.background,
              ),
            ],
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Column(
              children: [
                _infoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: location,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: _border),
                ),
                _infoRow(
                  icon: Icons.payments_outlined,
                  label: 'Budget',
                  value: budget,
                  valueColor: _primaryDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8EF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.near_me_outlined, color: _primary, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Nearby',
                      style: TextStyle(
                        color: _primaryDark,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _viewButton(requestId, item),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBox(String category) {
    IconData icon = Icons.handyman_rounded;

    switch (category.trim().toLowerCase()) {
      case 'electrician':
        icon = Icons.electrical_services_rounded;
        break;
      case 'ac repair':
        icon = Icons.ac_unit_rounded;
        break;
      case 'painter':
        icon = Icons.format_paint_rounded;
        break;
      case 'plumber':
        icon = Icons.plumbing_rounded;
        break;
      case 'carpenter':
        icon = Icons.carpenter_rounded;
        break;
      case 'cleaner':
        icon = Icons.cleaning_services_rounded;
        break;
    }

    return Container(
      height: 50,
      width: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8EF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: _primary, size: 25),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _border),
          ),
          child: Icon(icon, size: 18, color: _textSecondary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor ?? _textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge({
    required String label,
    required Color foreground,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _viewButton(String requestId, Map<String, dynamic> item) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: () => _openJobDetail(requestId, item),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: _primary,
          padding: const EdgeInsets.symmetric(horizontal: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          children: [
            Text(
              'View job',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
            SizedBox(width: 7),
            Icon(Icons.arrow_forward_rounded, size: 17),
          ],
        ),
      ),
    );
  }

  void _openJobDetail(String requestId, Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerJobDetailScreen(
          requestId: requestId,
          title: (item['title'] ?? '').toString(),
          category: (item['category'] ?? '').toString(),
          location: (item['location'] ?? '').toString(),
          distance: 'Nearby',
          budget: (item['budget'] ?? '').toString(),
          urgency: (item['urgency'] ?? '').toString(),
        ),
      ),
    );
  }

  Future<void> _fitMarkers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty || mapController == null) return;

    final coordinates = docs.map((doc) {
      final data = doc.data();
      return LatLng(
        (data['lat'] as num?)?.toDouble() ?? pabbiCenter.latitude,
        (data['lng'] as num?)?.toDouble() ?? pabbiCenter.longitude,
      );
    }).toList();

    if (coordinates.length == 1) {
      await mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: coordinates.first, zoom: 14),
        ),
      );
      return;
    }

    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (final point in coordinates.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    await mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        70,
      ),
    );
  }

  Widget _emptyState(String workerSkill) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 29),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            height: 68,
            width: 68,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF8EF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_searching_rounded,
              size: 31,
              color: _primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No nearby jobs right now',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'New ${workerSkill.toLowerCase()} requests in your area will appear here automatically.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _missingSkillState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _border),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.manage_accounts_outlined, size: 46, color: _primary),
              SizedBox(height: 14),
              Text(
                'Complete your worker profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Add your primary skill to discover matching jobs on the map.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
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

  Widget _fullPageLoader() {
    return const Center(
      child: CircularProgressIndicator(color: _primary, strokeWidth: 2.6),
    );
  }

  Widget _fullPageError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7F7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDC2626),
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _UrgencyStyle _urgencyStyle(String urgency) {
    switch (urgency.trim().toLowerCase()) {
      case 'urgent':
      case 'emergency':
      case 'high':
        return const _UrgencyStyle(
          label: 'URGENT',
          foreground: Color(0xFFB91C1C),
          background: Color(0xFFFEE2E2),
        );
      case 'low':
        return const _UrgencyStyle(
          label: 'LOW',
          foreground: Color(0xFF2563EB),
          background: Color(0xFFDBEAFE),
        );
      default:
        return const _UrgencyStyle(
          label: 'NORMAL',
          foreground: Color(0xFFB45309),
          background: Color(0xFFFEF3C7),
        );
    }
  }
}

class _UrgencyStyle {
  final String label;
  final Color foreground;
  final Color background;

  const _UrgencyStyle({
    required this.label,
    required this.foreground,
    required this.background,
  });
}
