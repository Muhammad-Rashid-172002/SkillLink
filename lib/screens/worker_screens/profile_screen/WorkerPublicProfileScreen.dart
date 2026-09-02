import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_cards.dart';
import 'package:skill_link/screens/customer_screens/Chat/customer_chat_service.dart';
import 'package:skill_link/screens/customer_screens/Explore/explore_models.dart';
import 'package:skill_link/screens/customer_screens/Request/Request.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/worker_public_profile_components.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/worker_public_profile_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerPublicProfileScreen extends StatefulWidget {
  const WorkerPublicProfileScreen({
    super.key,
    required this.workerId,
    this.distanceKm,
    this.dataSource,
    this.onRequestService,
    this.onMessage,
  });

  final String workerId;
  final double? distanceKm;
  final WorkerPublicProfileDataSource? dataSource;
  final VoidCallback? onRequestService;
  final VoidCallback? onMessage;

  @override
  State<WorkerPublicProfileScreen> createState() =>
      _WorkerPublicProfileScreenState();
}

class _WorkerPublicProfileScreenState extends State<WorkerPublicProfileScreen> {
  late final WorkerPublicProfileDataSource _dataSource;
  late Stream<Map<String, dynamic>?> _workerStream;
  late Stream<List<PublicWorkerReview>> _reviewsStream;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? FirebaseWorkerPublicProfileDataSource();
    _createStreams();
  }

  void _createStreams() {
    _workerStream = _dataSource.watchWorker(widget.workerId);
    _reviewsStream = _dataSource.watchReviews(widget.workerId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _workerStream,
      builder: (context, snapshot) {
        final worker = snapshot.data;
        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        if (loading) return _loadingScaffold();
        if (snapshot.hasError) {
          return _errorScaffold(
            'The professional profile could not be loaded right now.',
          );
        }
        if (worker == null) {
          return _errorScaffold('This professional profile is unavailable.');
        }
        if (!_isEligible(worker)) {
          return _errorScaffold(
            'This professional is not currently available for requests.',
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text('Professional profile'),
          ),
          body: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                key: PageStorageKey('professional-${widget.workerId}'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            SkillNovaSpacing.md,
                            SkillNovaSpacing.xs,
                            SkillNovaSpacing.md,
                            SkillNovaSpacing.xxxl,
                          ),
                          child: _profileContent(worker),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _bottomActions(worker),
        );
      },
    );
  }

  Widget _profileContent(Map<String, dynamic> worker) {
    final name = firstText(worker, const ['name'], 'Professional');
    final skill = firstText(worker, const ['skill'], 'Professional service');
    final photo = firstText(worker, const [
      'profileImage',
      'profileImageUrl',
      'photoUrl',
      'imageUrl',
    ], '');
    final city = firstText(worker, const ['city', 'location'], '');
    final bio = firstText(worker, const ['bio'], '');
    final experience = firstText(worker, const [
      'experience',
      'experienceYears',
    ], '');
    final rawRate = firstText(worker, const ['hourlyRate', 'startingRate'], '');
    final rating = numberOf(worker['rating']) ?? 0;
    final reviewCount = integerOf(
      worker['totalReviews'] ?? worker['reviewsCount'] ?? worker['reviewCount'],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkerProfileHero(
          name: name,
          skill: skill,
          photoUrl: photo,
          rating: rating,
          reviewCount: reviewCount,
          verified: worker['identityVerificationStatus'] == 'approved',
          location: city.isEmpty ? null : city,
          distanceKm: widget.distanceKm,
        ),
        const SizedBox(height: SkillNovaSpacing.md),
        WorkerVerificationCard(
          identityVerified: worker['identityVerificationStatus'] == 'approved',
          emailVerified: worker['emailVerified'] == true,
          phoneVerified: worker['phoneVerified'] == true,
        ),
        const SizedBox(height: SkillNovaSpacing.md),
        WorkerAboutCard(
          skill: skill,
          bio: bio.isEmpty ? null : bio,
          experience: experience.isEmpty ? null : experience,
          rate: rawRate.isEmpty ? null : formatRate(rawRate),
        ),
        const SizedBox(height: SkillNovaSpacing.xxl),
        const SectionHeader(
          title: 'Customer reviews',
          subtitle: 'Feedback connected to completed SkillNova requests',
        ),
        const SizedBox(height: SkillNovaSpacing.sm),
        _reviews(rating, reviewCount),
      ],
    );
  }

  Widget _reviews(double profileRating, int profileReviewCount) {
    return StreamBuilder<List<PublicWorkerReview>>(
      stream: _reviewsStream,
      builder: (context, snapshot) {
        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        if (loading) return const SkeletonCard(height: 220);
        if (snapshot.hasError) {
          return const ErrorState(
            title: 'Reviews unavailable',
            message: 'Public reviews could not be loaded right now.',
          );
        }
        final reviews = snapshot.data ?? const [];
        if (reviews.isEmpty) {
          return const EmptyState(
            icon: Icons.rate_review_outlined,
            title: 'No public reviews yet',
            message:
                'Verified customer feedback will appear after completed services.',
          );
        }

        final loadedAverage =
            reviews.fold<double>(0, (total, review) => total + review.rating) /
            reviews.length;
        final summaryRating = profileRating > 0 ? profileRating : loadedAverage;
        final summaryCount = profileReviewCount > 0
            ? profileReviewCount
            : reviews.length;
        return Container(
          padding: const EdgeInsets.all(SkillNovaSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(SkillNovaRadius.large),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WorkerRatingSummary(
                rating: summaryRating,
                reviewCount: summaryCount,
              ),
              const SizedBox(height: SkillNovaSpacing.lg),
              ...reviews.map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: SkillNovaSpacing.sm),
                  child: WorkerReviewCard(review: review),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomActions(Map<String, dynamic> worker) {
    final phone = firstText(worker, const ['phone', 'phoneNumber'], '');
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        SkillNovaSpacing.md,
        SkillNovaSpacing.sm,
        SkillNovaSpacing.md,
        SkillNovaSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (phone.isNotEmpty) ...[
              IconButton.outlined(
                tooltip: 'Call professional',
                onPressed: () => _callWorker(phone),
                icon: const Icon(Icons.call_outlined),
              ),
              const SizedBox(width: SkillNovaSpacing.xs),
            ],
            Expanded(
              child: SecondaryButton(
                label: 'Message',
                icon: Icons.chat_bubble_outline_rounded,
                onPressed: () => _messageWorker(worker),
              ),
            ),
            const SizedBox(width: SkillNovaSpacing.xs),
            Expanded(
              child: PrimaryButton(
                label: 'Request service',
                onPressed: _requestService,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isEligible(Map<String, dynamic> worker) {
    final accountStatus = firstText(worker, const [
      'accountStatus',
    ], '').toLowerCase();
    return worker['role'] == 'worker' &&
        worker['profileCompleted'] == true &&
        worker['identityVerificationStatus'] == 'approved' &&
        worker['canAcceptJobs'] == true &&
        worker['isBlocked'] != true &&
        worker['blocked'] != true &&
        (accountStatus.isEmpty || accountStatus == 'active');
  }

  Future<void> _refresh() async {
    await _dataSource.refresh(widget.workerId);
    if (!mounted) return;
    setState(_createStreams);
  }

  void _requestService() {
    if (widget.onRequestService != null) {
      widget.onRequestService!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Request(selectedWorkerId: widget.workerId),
      ),
    );
  }

  Future<void> _messageWorker(Map<String, dynamic> worker) async {
    if (widget.onMessage != null) {
      widget.onMessage!();
      return;
    }
    final customer = FirebaseAuth.instance.currentUser;
    if (customer == null) {
      _showMessage('Please sign in again to start a conversation.');
      return;
    }
    try {
      final destination = await CustomerChatService().resolveDirect(
        workerId: widget.workerId,
        workerName: firstText(worker, const ['name'], 'Professional'),
        workerSkill: firstText(worker, const ['skill'], ''),
        workerPhone: firstText(worker, const ['phone', 'phoneNumber'], ''),
        workerImageUrl: firstText(worker, const [
          'profileImage',
          'profileImageUrl',
          'photoUrl',
          'imageUrl',
        ], ''),
        workerVerified:
            worker['role'] == 'worker' &&
            worker['identityVerificationStatus'] == 'approved',
      );
      if (!mounted) return;
      await CustomerChatNavigator.open(context, destination);
    } catch (error) {
      if (mounted) _showMessage('Conversation could not be opened right now.');
    }
  }

  Future<void> _callWorker(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (mounted) _showMessage('The phone dialer is unavailable.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _loadingScaffold() {
    return Scaffold(
      appBar: AppBar(title: const Text('Professional profile')),
      body: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(SkillNovaSpacing.md),
          child: Column(
            children: [
              SkeletonCard(height: 290),
              SizedBox(height: SkillNovaSpacing.md),
              SkeletonCard(height: 180),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Professional profile'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(SkillNovaSpacing.lg),
            child: ErrorState(
              title: 'Profile unavailable',
              message: message,
              actionLabel: 'Try again',
              onAction: () => setState(_createStreams),
            ),
          ),
        ),
      ),
    );
  }
}
