import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_cards.dart';
import 'package:skill_link/design_system/widgets/skillnova_inputs.dart';
import 'package:skill_link/models/service_data.dart';
import 'package:skill_link/screens/customer_screens/Explore/explore_filter_sheets.dart';
import 'package:skill_link/screens/customer_screens/Explore/explore_models.dart';
import 'package:skill_link/screens/customer_screens/Explore/explore_repository.dart';
import 'package:skill_link/screens/customer_screens/Request/Request.dart'
    hide ServiceOption;
import 'package:skill_link/screens/worker_screens/profile_screen/WorkerPublicProfileScreen.dart';

class Explore extends StatefulWidget {
  const Explore({super.key, this.dataSource, this.locationService});

  final ExploreDataSource? dataSource;
  final ExploreLocationService? locationService;

  @override
  State<Explore> createState() => _ExploreState();
}

class _ExploreState extends State<Explore> {
  final TextEditingController _searchController = TextEditingController();
  late final ExploreDataSource _dataSource;
  late final ExploreLocationService _locationService;
  late Stream<Map<String, dynamic>?> _profileStream;
  late Stream<List<ExploreProfessional>> _professionalsStream;

  ExploreFilters _filters = const ExploreFilters();
  ExploreSort _sort = ExploreSort.recommended;
  SkillNovaCoordinate? _deviceLocation;
  GoogleMapController? _mapController;
  CameraPosition? _lastCamera;
  List<ExploreProfessional> _latestVisible = const [];
  SkillNovaCoordinate? _latestCustomerLocation;
  String _query = '';
  String? _selectedWorkerId;
  bool _mapMode = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? FirebaseExploreDataSource();
    _locationService = widget.locationService ?? DeviceExploreLocationService();
    _createStreams();
  }

  void _createStreams() {
    _profileStream = _dataSource.watchCustomerProfile();
    _professionalsStream = _dataSource.watchEligibleProfessionals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dataSource.customerId.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: ErrorState(
              title: 'Session unavailable',
              message: 'Please sign in again to explore professionals.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: _profileStream,
          builder: (context, profileSnapshot) {
            final profile = profileSnapshot.data;
            final savedLocation = customerCoordinate(profile);
            final currentLocation = _deviceLocation ?? savedLocation;
            _latestCustomerLocation = currentLocation;
            final locationLabel = customerLocationLabel(profile);

            return StreamBuilder<List<ExploreProfessional>>(
              stream: _professionalsStream,
              builder: (context, snapshot) {
                final loading =
                    snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;
                final professionals = snapshot.data ?? const [];
                final visible = _filterAndSort(professionals, currentLocation);
                _latestVisible = visible;

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    key: const PageStorageKey('explore-v2-scroll'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                SkillNovaSpacing.md,
                                SkillNovaSpacing.md,
                                SkillNovaSpacing.md,
                                SkillNovaSpacing.xxxl,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _header(locationLabel, currentLocation),
                                  const SizedBox(height: SkillNovaSpacing.lg),
                                  _searchAndActions(currentLocation),
                                  const SizedBox(height: SkillNovaSpacing.md),
                                  _categoryChips(),
                                  const SizedBox(height: SkillNovaSpacing.lg),
                                  _modeControl(),
                                  const SizedBox(height: SkillNovaSpacing.md),
                                  if (currentLocation == null)
                                    _locationNotice(),
                                  if (currentLocation == null)
                                    const SizedBox(height: SkillNovaSpacing.md),
                                  if (loading)
                                    _loadingState()
                                  else if (snapshot.hasError)
                                    ErrorState(
                                      title: 'Professionals unavailable',
                                      message:
                                          'We could not load professionals right now.',
                                      actionLabel: 'Try again',
                                      onAction: _resetStreams,
                                    )
                                  else ...[
                                    _resultsHeader(visible.length),
                                    const SizedBox(height: SkillNovaSpacing.sm),
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      child: _mapMode
                                          ? _mapResults(
                                              visible,
                                              currentLocation,
                                            )
                                          : _listResults(
                                              visible,
                                              currentLocation,
                                            ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
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

  Widget _header(String locationLabel, SkillNovaCoordinate? location) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Explore professionals', style: theme.textTheme.headlineSmall),
        const SizedBox(height: SkillNovaSpacing.xs),
        InkWell(
          onTap: _locate,
          borderRadius: BorderRadius.circular(SkillNovaRadius.small),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: SkillNovaSpacing.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  location == null
                      ? Icons.location_off_outlined
                      : Icons.location_on_outlined,
                  color: theme.colorScheme.primary,
                  size: 19,
                ),
                const SizedBox(width: SkillNovaSpacing.xs),
                Flexible(
                  child: Text(
                    location == null ? 'Use current location' : locationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: SkillNovaSpacing.xxs),
                if (_locating)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.my_location_rounded, size: 17),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _searchAndActions(SkillNovaCoordinate? location) {
    return Column(
      children: [
        SkillNovaSearchField(
          key: const ValueKey('explore-search'),
          controller: _searchController,
          hintText: 'Search plumber, electrician, AC repair...',
          onChanged: (value) {
            setState(() => _query = value.trim().toLowerCase());
          },
          trailing: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
        const SizedBox(height: SkillNovaSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openFilters(location),
                icon: const Icon(Icons.tune_rounded, size: 19),
                label: Text(
                  _filters.activeCount == 0
                      ? 'Filters'
                      : 'Filters (${_filters.activeCount})',
                ),
              ),
            ),
            const SizedBox(width: SkillNovaSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openSort(location),
                icon: const Icon(Icons.swap_vert_rounded, size: 19),
                label: Text(_sort.label, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _categoryChips() {
    final categories = ['All', ...allServices.map((service) => service.title)];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: SkillNovaSpacing.xs),
        itemBuilder: (context, index) {
          final category = categories[index];
          return ChoiceChip(
            key: ValueKey('category-$category'),
            label: Text(category),
            selected: _filters.category == category,
            onSelected: (_) {
              setState(() {
                _filters = ExploreFilters(
                  category: category,
                  minimumRating: _filters.minimumRating,
                  minimumRate: _filters.minimumRate,
                  maximumRate: _filters.maximumRate,
                  maximumDistanceKm: _filters.maximumDistanceKm,
                );
                _selectedWorkerId = null;
              });
              _scheduleMapFit();
            },
          );
        },
      ),
    );
  }

  Widget _modeControl() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(SkillNovaSpacing.xxs),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
      ),
      child: Row(
        children: [
          _modeButton(
            label: 'List',
            icon: Icons.view_agenda_outlined,
            selected: !_mapMode,
          ),
          _modeButton(
            label: 'Map',
            icon: Icons.map_outlined,
            selected: _mapMode,
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool selected,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: selected ? colors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(SkillNovaRadius.small),
        child: InkWell(
          onTap: () {
            if (_mapMode == (label == 'Map')) return;
            setState(() {
              _mapMode = label == 'Map';
              _selectedWorkerId = null;
            });
          },
          borderRadius: BorderRadius.circular(SkillNovaRadius.small),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: SkillNovaSpacing.xs),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _locationNotice() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SkillNovaSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
      ),
      child: Row(
        children: [
          Icon(
            Icons.near_me_disabled_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: SkillNovaSpacing.sm),
          Expanded(
            child: Text(
              'Enable location to see real distances and nearest sorting.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: _locate, child: const Text('Enable')),
        ],
      ),
    );
  }

  Widget _resultsHeader(int count) {
    return SectionHeader(
      title: '$count ${count == 1 ? 'professional' : 'professionals'}',
      subtitle: 'Only currently eligible, identity-verified providers',
      actionLabel: _filters.isActive || _query.isNotEmpty ? 'Clear' : null,
      onAction: _filters.isActive || _query.isNotEmpty ? _clearFilters : null,
    );
  }

  Widget _loadingState() {
    return Column(
      children: List.generate(
        3,
        (index) => const Padding(
          padding: EdgeInsets.only(bottom: SkillNovaSpacing.sm),
          child: SkeletonCard(height: 230),
        ),
      ),
    );
  }

  Widget _listResults(
    List<ExploreProfessional> professionals,
    SkillNovaCoordinate? customerLocation,
  ) {
    if (professionals.isEmpty) return _emptyResults();
    return Column(
      key: const PageStorageKey('explore-list-results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: professionals
          .map((professional) {
            return Padding(
              padding: const EdgeInsets.only(bottom: SkillNovaSpacing.sm),
              child: _professionalCard(professional, customerLocation),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _professionalCard(
    ExploreProfessional professional,
    SkillNovaCoordinate? customerLocation,
  ) {
    final coordinate = professional.publicCoordinate;
    final distance = customerLocation != null && coordinate != null
        ? distanceInKilometers(customerLocation, coordinate)
        : null;
    return ProfessionalCard(
      width: double.infinity,
      name: professional.name,
      skill: professional.skill,
      photoUrl: professional.photoUrl,
      rating: professional.rating,
      reviewCount: professional.reviewCount,
      verified: true,
      experience: professional.experience.isEmpty
          ? null
          : professional.experience,
      startingRate: professional.rateText.isEmpty
          ? null
          : formatRate(professional.rateText),
      distanceKm: distance,
      onViewProfile: () => _openProfile(professional, distance),
      onBook: () => _requestService(professional.id),
    );
  }

  Widget _emptyResults() {
    final filtered = _filters.isActive || _query.isNotEmpty;
    return EmptyState(
      icon: filtered
          ? Icons.manage_search_outlined
          : Icons.person_search_outlined,
      title: filtered
          ? 'No matching professionals'
          : 'No professionals available',
      message: filtered
          ? 'Try a broader search or clear your current filters.'
          : 'Eligible professionals will appear here when available.',
      actionLabel: filtered ? 'Clear filters' : null,
      onAction: filtered ? _clearFilters : null,
    );
  }

  Widget _mapResults(
    List<ExploreProfessional> professionals,
    SkillNovaCoordinate? customerLocation,
  ) {
    final mapped = professionals
        .where((professional) => professional.publicCoordinate != null)
        .toList(growable: false);
    if (mapped.isEmpty) {
      return const EmptyState(
        key: ValueKey('map-empty'),
        icon: Icons.location_off_outlined,
        title: 'No public locations to show',
        message:
            'These professionals can still be viewed in the list, but none has shared a valid public service location.',
      );
    }

    final selected = mapped
        .where((professional) => professional.id == _selectedWorkerId)
        .firstOrNull;
    final markers = mapped.map((professional) {
      final coordinate = professional.publicCoordinate!;
      return Marker(
        markerId: MarkerId(professional.id),
        position: LatLng(coordinate.latitude, coordinate.longitude),
        infoWindow: InfoWindow(
          title: professional.name,
          snippet: professional.skill,
        ),
        onTap: () => setState(() => _selectedWorkerId = professional.id),
      );
    }).toSet();
    final first = customerLocation ?? mapped.first.publicCoordinate!;
    final initialCamera =
        _lastCamera ??
        CameraPosition(
          target: LatLng(first.latitude, first.longitude),
          zoom: 12.5,
        );

    return Column(
      key: const ValueKey('map-results'),
      children: [
        Container(
          height: 430,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SkillNovaRadius.large),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: initialCamera,
                  markers: markers,
                  myLocationEnabled: customerLocation != null,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onCameraMove: (position) => _lastCamera = position,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _fitMap(mapped, customerLocation);
                  },
                ),
              ),
              Positioned(
                top: SkillNovaSpacing.sm,
                left: SkillNovaSpacing.sm,
                child: _mapCount(mapped.length),
              ),
              Positioned(
                top: SkillNovaSpacing.sm,
                right: SkillNovaSpacing.sm,
                child: IconButton.filled(
                  tooltip: 'Use current location',
                  onPressed: _locate,
                  icon: const Icon(Icons.my_location_rounded),
                ),
              ),
            ],
          ),
        ),
        if (selected != null) ...[
          const SizedBox(height: SkillNovaSpacing.sm),
          _professionalCard(selected, customerLocation),
        ],
      ],
    );
  }

  Widget _mapCount(int count) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SkillNovaSpacing.sm,
        vertical: SkillNovaSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
        boxShadow: SkillNovaElevation.subtle,
      ),
      child: Text('$count on map', style: theme.textTheme.labelMedium),
    );
  }

  List<ExploreProfessional> _filterAndSort(
    List<ExploreProfessional> source,
    SkillNovaCoordinate? customerLocation,
  ) {
    final visible = source.where((professional) {
      final matchesSearch =
          _query.isEmpty ||
          professional.name.toLowerCase().contains(_query) ||
          professional.skill.toLowerCase().contains(_query) ||
          professional.city.toLowerCase().contains(_query);
      final matchesCategory =
          _filters.category == 'All' ||
          professional.skill.toLowerCase().contains(
            _filters.category.toLowerCase(),
          );
      final matchesRating = professional.rating >= _filters.minimumRating;
      final rate = professional.numericRate;
      final matchesMinimumRate =
          _filters.minimumRate == null ||
          (rate != null && rate >= _filters.minimumRate!);
      final matchesMaximumRate =
          _filters.maximumRate == null ||
          (rate != null && rate <= _filters.maximumRate!);
      final workerLocation = professional.publicCoordinate;
      final distance = customerLocation != null && workerLocation != null
          ? distanceInKilometers(customerLocation, workerLocation)
          : null;
      final matchesDistance =
          _filters.maximumDistanceKm == null ||
          (distance != null && distance <= _filters.maximumDistanceKm!);
      return matchesSearch &&
          matchesCategory &&
          matchesRating &&
          matchesMinimumRate &&
          matchesMaximumRate &&
          matchesDistance;
    }).toList();

    final effectiveSort =
        _sort == ExploreSort.nearest && customerLocation == null
        ? ExploreSort.recommended
        : _sort;
    visible.sort((first, second) {
      final result = switch (effectiveSort) {
        ExploreSort.highestRated => _compareRating(first, second),
        ExploreSort.lowestRate => _compareRate(first, second, ascending: true),
        ExploreSort.highestRate => _compareRate(
          first,
          second,
          ascending: false,
        ),
        ExploreSort.nearest => _compareDistance(
          first,
          second,
          customerLocation!,
        ),
        ExploreSort.recommended => _recommendedScore(
          second,
        ).compareTo(_recommendedScore(first)),
      };
      return result != 0 ? result : first.name.compareTo(second.name);
    });
    return visible.take(40).toList(growable: false);
  }

  int _compareRating(ExploreProfessional first, ExploreProfessional second) {
    final rating = second.rating.compareTo(first.rating);
    return rating != 0
        ? rating
        : second.reviewCount.compareTo(first.reviewCount);
  }

  int _compareRate(
    ExploreProfessional first,
    ExploreProfessional second, {
    required bool ascending,
  }) {
    final firstRate = first.numericRate;
    final secondRate = second.numericRate;
    if (firstRate == null && secondRate == null) return 0;
    if (firstRate == null) return 1;
    if (secondRate == null) return -1;
    return ascending
        ? firstRate.compareTo(secondRate)
        : secondRate.compareTo(firstRate);
  }

  int _compareDistance(
    ExploreProfessional first,
    ExploreProfessional second,
    SkillNovaCoordinate customer,
  ) {
    final firstLocation = first.publicCoordinate;
    final secondLocation = second.publicCoordinate;
    if (firstLocation == null && secondLocation == null) return 0;
    if (firstLocation == null) return 1;
    if (secondLocation == null) return -1;
    return distanceInKilometers(
      customer,
      firstLocation,
    ).compareTo(distanceInKilometers(customer, secondLocation));
  }

  double _recommendedScore(ExploreProfessional professional) {
    final reviewConfidence = math.log(professional.reviewCount + 1) * 4;
    return professional.rating * 20 + reviewConfidence;
  }

  Future<void> _openFilters(SkillNovaCoordinate? location) async {
    final updated = await showExploreFilterSheet(
      context: context,
      current: _filters,
      distanceAvailable: location != null,
    );
    if (updated == null || !mounted) return;
    setState(() {
      _filters = updated;
      _selectedWorkerId = null;
    });
    _scheduleMapFit();
  }

  Future<void> _openSort(SkillNovaCoordinate? location) async {
    final selected = await showExploreSortSheet(
      context: context,
      current: _sort,
      distanceAvailable: location != null,
    );
    if (selected == null || !mounted) return;
    setState(() => _sort = selected);
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final location = await _locationService.currentLocation();
      if (!mounted) return;
      if (location == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission or service is unavailable.'),
          ),
        );
        return;
      }
      setState(() {
        _deviceLocation = location;
        _lastCamera = CameraPosition(
          target: LatLng(location.latitude, location.longitude),
          zoom: 13.5,
        );
      });
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(_lastCamera!),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _refresh() => _dataSource.refresh();

  void _resetStreams() => setState(_createStreams);

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _filters = const ExploreFilters();
      _sort = ExploreSort.recommended;
      _selectedWorkerId = null;
    });
    _scheduleMapFit();
  }

  void _openProfile(ExploreProfessional professional, double? distance) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerPublicProfileScreen(
          workerId: professional.id,
          distanceKm: distance,
        ),
      ),
    );
  }

  void _requestService(String workerId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Request(selectedWorkerId: workerId)),
    );
  }

  void _scheduleMapFit() {
    if (!_mapMode) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitMap(_latestVisible, _latestCustomerLocation);
    });
  }

  Future<void> _fitMap(
    List<ExploreProfessional> professionals,
    SkillNovaCoordinate? customer,
  ) async {
    final controller = _mapController;
    if (controller == null) return;
    final points = professionals
        .map((professional) => professional.publicCoordinate)
        .whereType<SkillNovaCoordinate>()
        .toList();
    if (customer != null) points.add(customer);
    if (points.isEmpty) return;
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(points.first.latitude, points.first.longitude),
          13.5,
        ),
      );
      return;
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    if ((maxLat - minLat).abs() < 0.0001 && (maxLng - minLng).abs() < 0.0001) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 13.5),
      );
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        64,
      ),
    );
  }
}
