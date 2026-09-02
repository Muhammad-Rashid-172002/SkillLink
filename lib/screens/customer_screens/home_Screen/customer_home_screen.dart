import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:skill_link/Notification_screen/notification_screen.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_cards.dart';
import 'package:skill_link/design_system/widgets/skillnova_inputs.dart';
import 'package:skill_link/models/service_data.dart';
import 'package:skill_link/screens/customer_screens/Request/Request.dart'
    hide ServiceOption;
import 'package:skill_link/screens/customer_screens/customer_my_request_scree/request_tracking_screen.dart';
import 'package:skill_link/screens/customer_screens/home_Screen/AllServicesScreen.dart';
import 'package:skill_link/screens/customer_screens/home_Screen/customer_home_repository.dart';
import 'package:skill_link/screens/customer_screens/home_Screen/top_rated_workers_screen.dart';
import 'package:skill_link/screens/customer_screens/muneTile/edit_profile.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/WorkerPublicProfileScreen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key, this.onSelectTab, this.dataSource});

  final ValueChanged<int>? onSelectTab;
  final CustomerHomeDataSource? dataSource;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  static const List<String> _popularServiceNames = [
    'Plumber',
    'Electrician',
    'AC Repair',
    'Cleaner',
    'Carpenter',
    'Appliance Repair',
    'Home Painter',
    'Mobile Repair',
  ];

  final TextEditingController _serviceController = TextEditingController();
  late final CustomerHomeDataSource _dataSource;
  late Stream<Map<String, dynamic>?> _userStream;
  late Stream<int> _notificationStream;
  late Stream<List<CustomerHomeRecord>> _workersStream;
  late Stream<List<CustomerHomeRecord>> _requestsStream;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? FirebaseCustomerHomeDataSource();
    _createStreams();
  }

  void _createStreams() {
    _userStream = _dataSource.watchProfile();
    _notificationStream = _dataSource.watchUnreadNotificationCount();
    _workersStream = _dataSource.watchEligibleProfessionals();
    _requestsStream = _dataSource.watchCustomerRequests();
  }

  @override
  void dispose() {
    _serviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dataSource.userId.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: ErrorState(
              title: 'Session unavailable',
              message: 'Please sign in again to continue.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            key: const PageStorageKey('customer-home-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SkillNovaSpacing.md,
                        SkillNovaSpacing.sm,
                        SkillNovaSpacing.md,
                        SkillNovaSpacing.xxxl,
                      ),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 8 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: SkillNovaSpacing.xl),
                            _buildServiceEntry(),
                            const SizedBox(height: SkillNovaSpacing.xl),
                            _buildActiveBooking(),
                            _buildPopularServices(),
                            const SizedBox(height: SkillNovaSpacing.xxl),
                            _buildProfessionals(),
                            const SizedBox(height: SkillNovaSpacing.xxl),
                            _buildTrustCard(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    await _dataSource.refresh();
  }

  Widget _buildHeader() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SkeletonCard(height: 76);
        }

        final profile = snapshot.data ?? const <String, dynamic>{};
        final fullName = _string(profile, ['name'], fallback: 'Customer');
        final firstName = fullName.split(RegExp(r'\s+')).first;
        final photoUrl = _string(profile, [
          'profileImage',
          'profileImageUrl',
          'photoUrl',
        ]);
        final location = _profileLocation(profile);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greeting()}, $firstName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: SkillNovaSpacing.xs),
                  Semantics(
                    button: true,
                    label: location == null
                        ? 'Add your service location'
                        : 'Current location, $location',
                    child: InkWell(
                      onTap: _openLocationProfile,
                      borderRadius: BorderRadius.circular(
                        SkillNovaRadius.small,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: SkillNovaSpacing.xxs),
                            Flexible(
                              child: Text(
                                location ?? 'Add your service location',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: SkillNovaSpacing.xxs),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SkillNovaSpacing.sm),
            _buildNotificationsButton(),
            const SizedBox(width: SkillNovaSpacing.xs),
            _CustomerAvatar(name: fullName, photoUrl: photoUrl),
          ],
        );
      },
    );
  }

  Widget _buildNotificationsButton() {
    return StreamBuilder<int>(
      stream: _notificationStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final colors = Theme.of(context).colorScheme;
        return Semantics(
          button: true,
          label: count == 0 ? 'Notifications' : '$count unread notifications',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton.outlined(
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: colors.error,
                      borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count >= 99 ? '99+' : '$count',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onError,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServiceEntry() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(SkillNovaSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: SkillNovaElevation.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you need help with?',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: SkillNovaSpacing.xs),
          Text(
            'Describe the service and we’ll help you get started.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: SkillNovaSpacing.md),
          SkillNovaSearchField(
            controller: _serviceController,
            hintText: 'AC leaking, need a plumber, home cleaning...',
            onSubmitted: _openRequestFromSearch,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Start a request by voice',
                  onPressed: _openGeneralRequest,
                  icon: const Icon(Icons.mic_none_rounded),
                ),
                IconButton(
                  tooltip: 'Start a request with a photo',
                  onPressed: _openGeneralRequest,
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBooking() {
    return StreamBuilder<List<CustomerHomeRecord>>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(bottom: SkillNovaSpacing.xl),
            child: SkeletonCard(height: 190),
          );
        }
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.only(bottom: SkillNovaSpacing.xl),
            child: ErrorState(
              title: 'Booking updates unavailable',
              message:
                  'Your bookings are safe. Updates could not be loaded right now.',
            ),
          );
        }

        final active = [...?snapshot.data].where((document) {
          return _isActiveStatus(document.data['status']);
        }).toList()..sort((a, b) => _dateOf(b.data).compareTo(_dateOf(a.data)));

        if (active.isEmpty) return const SizedBox.shrink();

        final document = active.first;
        final data = document.data;
        final status = _statusPresentation(data['status']);
        final workerId = _string(data, ['workerId']);
        final workerName = _string(data, ['workerName']);
        final service = _string(data, [
          'category',
          'title',
        ], fallback: 'Service booking');

        return Padding(
          padding: const EdgeInsets.only(bottom: SkillNovaSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Active booking'),
              const SizedBox(height: SkillNovaSpacing.sm),
              ActiveBookingCard(
                service: service,
                statusLabel: status.label,
                statusMessage: status.message,
                progress: status.progress,
                workerLabel: workerName.isNotEmpty
                    ? workerName
                    : workerId.isNotEmpty
                    ? 'Professional assigned'
                    : null,
                onTrack: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RequestTrackingScreen(requestId: document.id),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPopularServices() {
    final services = _popularServiceNames
        .map(
          (name) => allServices.firstWhere(
            (service) => service.title == name,
            orElse: () => allServices.first,
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Popular services',
          actionLabel: 'See all',
          onAction: _openAllServices,
        ),
        const SizedBox(height: SkillNovaSpacing.sm),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: services.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: SkillNovaSpacing.sm),
            itemBuilder: (context, index) {
              final service = services[index];
              return ServiceCategoryCard(
                label: service.title,
                icon: service.icon,
                accent: service.color,
                onTap: () => _openRequest(service.title),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recommended professionals',
          subtitle: 'Identity-verified professionals with strong ratings',
          actionLabel: 'View all',
          onAction: _openAllWorkers,
        ),
        const SizedBox(height: SkillNovaSpacing.sm),
        StreamBuilder<List<CustomerHomeRecord>>(
          stream: _workersStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return SizedBox(
                height: 278,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: 2,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: SkillNovaSpacing.sm),
                  itemBuilder: (_, _) =>
                      const SkeletonCard(width: 286, height: 278),
                ),
              );
            }
            if (snapshot.hasError) {
              return ErrorState(
                title: 'Professionals unavailable',
                message: 'We could not load professionals right now.',
                actionLabel: 'Try again',
                onAction: _resetStreams,
              );
            }

            final workers = [...?snapshot.data]
              ..sort((a, b) {
                return _doubleOf(
                  b.data['rating'],
                ).compareTo(_doubleOf(a.data['rating']));
              });

            if (workers.isEmpty) {
              return EmptyState(
                icon: Icons.person_search_outlined,
                title: 'No professionals available yet',
                message: 'You can still create a service request.',
                actionLabel: 'Create request',
                onAction: _openGeneralRequest,
              );
            }

            return SizedBox(
              height: 278,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: workers.take(6).length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: SkillNovaSpacing.sm),
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  return _professionalCard(worker.id, worker.data);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _professionalCard(String workerId, Map<String, dynamic> data) {
    final name = _string(data, ['name'], fallback: 'Skilled professional');
    final skill = _string(data, ['skill'], fallback: 'Professional service');
    final photoUrl = _string(data, [
      'profileImage',
      'profileImageUrl',
      'photoUrl',
    ]);
    final reviewCount = _intOf(data['totalReviews'] ?? data['reviewCount']);
    final completed = _intOf(
      data['completedJobs'] ??
          data['totalCompletedJobs'] ??
          data['jobsCompleted'],
    );
    final rawRate = _string(data, ['hourlyRate', 'startingRate']);
    final rate = rawRate.isEmpty ? null : _formatRate(rawRate);

    return ProfessionalCard(
      name: name,
      skill: skill,
      photoUrl: photoUrl,
      rating: _doubleOf(data['rating']),
      reviewCount: reviewCount,
      completedJobs: completed > 0 ? completed : null,
      startingRate: rate,
      verified: data['identityVerificationStatus'] == 'approved',
      onViewProfile: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkerPublicProfileScreen(workerId: workerId),
          ),
        );
      },
      onBook: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Request(selectedWorkerId: workerId),
          ),
        );
      },
    );
  }

  Widget _buildTrustCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SkillNovaSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: SkillNovaColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: SkillNovaColors.success,
            ),
          ),
          const SizedBox(width: SkillNovaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book with confidence',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: SkillNovaSpacing.xxs),
                Text(
                  'Identity checks • Community ratings • In-booking safety support',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _resetStreams() {
    setState(_createStreams);
  }

  void _openGeneralRequest() => _openRequest(null);

  void _openRequest(String? service) {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Request(selectedService: service)),
    );
  }

  void _openRequestFromSearch(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) {
      _openGeneralRequest();
      return;
    }

    ServiceOption? match;
    for (final service in allServices) {
      final title = service.title.toLowerCase();
      if (query.contains(title) || title.contains(query)) {
        match = service;
        break;
      }
    }
    _openRequest(match?.title);
  }

  Future<void> _openAllServices() async {
    final service = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AllServicesScreen()),
    );
    if (service != null && mounted) _openRequest(service);
  }

  void _openAllWorkers() {
    if (widget.onSelectTab != null) {
      widget.onSelectTab!(1);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TopRatedWorkersScreen()),
    );
  }

  void _openLocationProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerEditProfileScreen()),
    );
  }

  String? _profileLocation(Map<String, dynamic> profile) {
    final city = _string(profile, ['city']);
    final area = _string(profile, ['area']);
    if (area.isNotEmpty && city.isNotEmpty) return '$area, $city';
    if (city.isNotEmpty) return '$city, Pakistan';
    final location = _string(profile, ['location', 'address']);
    return location.isEmpty ? null : location;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  bool _isActiveStatus(dynamic value) {
    const active = {
      'searching',
      'waiting_worker',
      'accepted',
      'on_the_way',
      'in_progress',
      'pending',
      'requested',
      'started',
    };
    return active.contains(_normalizedStatus(value));
  }

  _StatusPresentation _statusPresentation(dynamic value) {
    return switch (_normalizedStatus(value)) {
      'waiting_worker' => const _StatusPresentation(
        label: 'Awaiting reply',
        message: 'Your selected professional has been notified.',
        progress: 0.35,
      ),
      'accepted' => const _StatusPresentation(
        label: 'Confirmed',
        message: 'A professional has accepted your booking.',
        progress: 0.5,
      ),
      'on_the_way' => const _StatusPresentation(
        label: 'On the way',
        message: 'Your professional is travelling to the service location.',
        progress: 0.72,
      ),
      'in_progress' || 'started' => const _StatusPresentation(
        label: 'In progress',
        message: 'Your service is currently in progress.',
        progress: 0.9,
      ),
      _ => const _StatusPresentation(
        label: 'Finding help',
        message: 'Your request is open for eligible professionals.',
        progress: 0.2,
      ),
    };
  }

  String _normalizedStatus(dynamic value) {
    return value?.toString().trim().toLowerCase().replaceAll(' ', '_') ?? '';
  }

  DateTime _dateOf(Map<String, dynamic> data) {
    final value = data['updatedAt'] ?? data['createdAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _string(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != 'null') return value;
    }
    return fallback;
  }

  double _doubleOf(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _intOf(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatRate(String rate) {
    final compact = rate.trim();
    if (compact.toLowerCase().contains('rs')) return compact;
    return 'Rs $compact/hr';
  }
}

class _CustomerAvatar extends StatelessWidget {
  const _CustomerAvatar({required this.name, required this.photoUrl});

  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    Widget fallback() => ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: Text(
          initials.isEmpty ? 'SN' : initials,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colors.primary),
        ),
      ),
    );

    return Semantics(
      image: true,
      label: '$name profile photo',
      child: Container(
        width: 48,
        height: 48,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.outlineVariant),
        ),
        child: photoUrl.isEmpty
            ? fallback()
            : Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              ),
      ),
    );
  }
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.label,
    required this.message,
    required this.progress,
  });

  final String label;
  final String message;
  final double progress;
}
