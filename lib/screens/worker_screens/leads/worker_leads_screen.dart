import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/worker_screens/Wallat/Wallat_screen.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_lead_components.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_lead_detail_screen.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_lead_filter_sheet.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_lead_models.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_leads_repository.dart';
import 'package:skill_link/screens/worker_screens/navigation/worker_navigation_scope.dart';

class WorkerLeadsScreen extends StatefulWidget {
  const WorkerLeadsScreen({super.key, this.repository, this.onOpenLead});

  final WorkerLeadsRepository? repository;
  final ValueChanged<String>? onOpenLead;

  @override
  State<WorkerLeadsScreen> createState() => _WorkerLeadsScreenState();
}

class _WorkerLeadsScreenState extends State<WorkerLeadsScreen> {
  late final WorkerLeadsRepository _repository;
  late Stream<WorkerHomeProfile> _workerStream;
  Stream<List<WorkerLead>>? _leadsStream;
  String? _leadsKey;
  final TextEditingController _searchController = TextEditingController();
  WorkerLeadsView _view = WorkerLeadsView.list;
  WorkerLeadSort _sort = WorkerLeadSort.recommended;
  WorkerLeadFilters _filters = const WorkerLeadFilters();
  String _search = '';
  String? _selectedLeadId;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseWorkerLeadsRepository();
    _workerStream = _repository.currentWorkerId == null
        ? Stream.error('Signed out')
        : _repository.watchWorker();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Stream<List<WorkerLead>> _streamFor(WorkerHomeProfile worker) {
    final point = worker.coordinate;
    final key =
        '${worker.uid}:${worker.querySkill}:'
        '${point?.latitude}:${point?.longitude}';
    if (_leadsStream == null || _leadsKey != key) {
      _leadsKey = key;
      _leadsStream = _repository.watchLeads(worker);
    }
    return _leadsStream!;
  }

  void _retry() {
    if (_repository.currentWorkerId == null) return;
    setState(() {
      _workerStream = _repository.watchWorker();
      _leadsStream = null;
      _leadsKey = null;
    });
  }

  void _openLead(String id) {
    final callback = widget.onOpenLead;
    if (callback != null) {
      callback(id);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            WorkerLeadDetailScreen(requestId: id, repository: _repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final embedded = WorkerNavigationScope.isEmbedded(context);
    return Scaffold(
      bottomNavigationBar: embedded
          ? null
          : const WorkerBottomBar(selectedIndex: 1),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<WorkerHomeProfile>(
          stream: _workerStream,
          builder: (context, workerSnapshot) {
            if (workerSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (workerSnapshot.hasError || !workerSnapshot.hasData) {
              return WorkerLeadErrorState(onRetry: _retry);
            }
            final worker = workerSnapshot.data!;
            return StreamBuilder<List<WorkerLead>>(
              stream: _streamFor(worker),
              builder: (context, leadsSnapshot) {
                if (leadsSnapshot.connectionState == ConnectionState.waiting) {
                  return _layout(
                    worker: worker,
                    body: const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (leadsSnapshot.hasError) {
                  return _layout(
                    worker: worker,
                    body: SliverFillRemaining(
                      child: WorkerLeadErrorState(onRetry: _retry),
                    ),
                  );
                }
                final loaded = leadsSnapshot.data ?? const <WorkerLead>[];
                final hasDistance = loaded.any(
                  (lead) => lead.distanceKm != null,
                );
                if (!hasDistance && _sort == WorkerLeadSort.nearest) {
                  _sort = WorkerLeadSort.recommended;
                }
                final visible = filterAndSortWorkerLeads(
                  leads: loaded,
                  search: _search,
                  filters: _filters,
                  sort: _sort,
                );
                final selected = visible
                    .where((lead) => lead.id == _selectedLeadId)
                    .firstOrNull;
                return _layout(
                  worker: worker,
                  body: _view == WorkerLeadsView.list
                      ? _listBody(worker, loaded, visible)
                      : _mapBody(worker, visible, selected),
                  loaded: loaded,
                  hasDistance: hasDistance,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _layout({
    required WorkerHomeProfile worker,
    required Widget body,
    List<WorkerLead> loaded = const [],
    bool hasDistance = false,
  }) {
    return RefreshIndicator(
      onRefresh: () => _repository.refresh(worker),
      child: CustomScrollView(
        key: const PageStorageKey('worker-leads-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            sliver: SliverToBoxAdapter(
              child: _header(worker, loaded, hasDistance),
            ),
          ),
          body,
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _header(
    WorkerHomeProfile worker,
    List<WorkerLead> leads,
    bool hasDistance,
  ) {
    final readiness = WorkerEligibilityAdapter.evaluate(worker);
    final categories =
        leads.map((lead) => lead.category).toSet().toList(growable: false)
          ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leads',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Find service requests that match your work',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        WorkerLeadReadinessBanner(
          readiness: readiness,
          onCredits: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const WallatScreen()),
          ),
        ),
        if (readiness.state != WorkerReadinessState.ready)
          const SizedBox(height: 12),
        SegmentedButton<WorkerLeadsView>(
          key: const ValueKey('lead-view-toggle'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: WorkerLeadsView.list,
              label: Text('List'),
              icon: Icon(Icons.view_agenda_outlined),
            ),
            ButtonSegment(
              value: WorkerLeadsView.map,
              label: Text('Map'),
              icon: Icon(Icons.map_outlined),
            ),
          ],
          selected: {_view},
          onSelectionChanged: (values) {
            setState(() => _view = values.first);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('worker-lead-search'),
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _search = value),
          decoration: InputDecoration(
            hintText: 'Search service, area, or description',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _search = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('worker-lead-filters'),
                onPressed: () async {
                  final value = await showWorkerLeadFilterSheet(
                    context: context,
                    initial: _filters,
                    categories: categories,
                    hasLocation: worker.coordinate != null,
                  );
                  if (value != null && mounted) {
                    setState(() => _filters = value);
                  }
                },
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(
                  _filters.activeCount == 0
                      ? 'Filters'
                      : 'Filters (${_filters.activeCount})',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('worker-lead-sort'),
                onPressed: () async {
                  final value = await showWorkerLeadSortSheet(
                    context: context,
                    selected: _sort,
                    hasDistance: hasDistance,
                  );
                  if (value != null && mounted) setState(() => _sort = value);
                },
                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                label: Text(
                  _sort.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              Icons.work_outline_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${worker.skill} • ${leads.length} loaded',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _listBody(
    WorkerHomeProfile worker,
    List<WorkerLead> loaded,
    List<WorkerLead> visible,
  ) {
    if (visible.isEmpty) {
      return SliverToBoxAdapter(
        child: WorkerLeadEmptyState(
          filtered: _search.isNotEmpty || _filters.isActive,
          skill: worker.skill,
          onClear: _clearFilters,
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: visible.length,
        itemBuilder: (context, index) => WorkerLeadCard(
          lead: visible[index],
          onView: () => _openLead(visible[index].id),
        ),
      ),
    );
  }

  Widget _mapBody(
    WorkerHomeProfile worker,
    List<WorkerLead> visible,
    WorkerLead? selected,
  ) {
    final markerLeads = visible
        .where((lead) => lead.approximateMapCoordinate != null)
        .toList(growable: false);
    final workerPoint = worker.coordinate;
    final firstPoint =
        workerPoint ?? markerLeads.firstOrNull?.approximateMapCoordinate;
    if (firstPoint == null) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 40, 24, 20),
          child: Column(
            children: [
              Icon(Icons.location_off_outlined, size: 52),
              SizedBox(height: 12),
              Text('No valid locations to show', textAlign: TextAlign.center),
              SizedBox(height: 6),
              Text(
                'Leads without valid coordinates remain available in List view.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final markers = <Marker>{
      if (workerPoint != null)
        Marker(
          markerId: const MarkerId('current-worker'),
          position: LatLng(workerPoint.latitude, workerPoint.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Your work location'),
        ),
      ...markerLeads.map((lead) {
        final point = lead.approximateMapCoordinate!;
        return Marker(
          markerId: MarkerId(lead.id),
          position: LatLng(point.latitude, point.longitude),
          infoWindow: InfoWindow(
            title: lead.category,
            snippet: '${lead.postedBudget} • Approximate area',
          ),
          onTap: () => setState(() => _selectedLeadId = lead.id),
        );
      }),
    };
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            Container(
              key: const ValueKey('worker-leads-map'),
              height: 390,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(firstPoint.latitude, firstPoint.longitude),
                  zoom: 11.5,
                ),
                markers: markers,
                compassEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: (controller) => _mapController = controller,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${markerLeads.length} of ${visible.length} leads have valid map locations. Pins show approximate service areas.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (selected != null)
              WorkerLeadCard(
                lead: selected,
                compact: true,
                onView: () => _openLead(selected.id),
              )
            else if (markerLeads.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Tap a lead marker to preview it.'),
              ),
          ],
        ),
      ),
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _search = '';
      _filters = const WorkerLeadFilters();
    });
  }
}
