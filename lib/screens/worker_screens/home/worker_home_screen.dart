import 'package:flutter/material.dart';
import 'package:skill_link/Notification_screen/notification_screen.dart';
import 'package:skill_link/screens/verification/worker_verification_center.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/worker_screens/Chat/Chat_screen.dart';
import 'package:skill_link/screens/worker_screens/Map/Map_screen.dart';
import 'package:skill_link/screens/worker_screens/Map/worker_job_detail.dart';
import 'package:skill_link/screens/worker_screens/Wallat/Wallat_screen.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_components.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_repository.dart';
import 'package:skill_link/screens/worker_screens/home_screen/JobsByStatusScreen.dart';
import 'package:skill_link/screens/worker_screens/navigation/worker_navigation_scope.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/WorkerProfileScreen.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key, this.onSelectTab, this.repository});

  final ValueChanged<int>? onSelectTab;
  final WorkerHomeRepository? repository;

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  late final WorkerHomeRepository _repository;
  late Stream<WorkerHomeProfile> _profileStream;
  late Stream<WorkerActiveJobsSnapshot> _activeJobsStream;
  Stream<List<WorkerLeadPreview>>? _leadStream;
  String? _leadKey;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseWorkerHomeRepository();
    if (_repository.currentWorkerId != null) {
      _profileStream = _repository.watchProfile();
      _activeJobsStream = _repository.watchActiveJobs();
    } else {
      _profileStream = Stream.error('Signed out');
      _activeJobsStream = Stream.value(const WorkerActiveJobsSnapshot());
    }
  }

  void _retry() {
    if (_repository.currentWorkerId == null) return;
    setState(() {
      _profileStream = _repository.watchProfile();
      _activeJobsStream = _repository.watchActiveJobs();
      _leadStream = null;
      _leadKey = null;
    });
  }

  Stream<List<WorkerLeadPreview>> _leadsFor(
    WorkerHomeProfile worker,
    WorkerReadiness readiness,
  ) {
    if (!readiness.canReceiveLeads) return Stream.value(const []);
    final coordinate = worker.coordinate;
    final key =
        '${worker.uid}:${worker.querySkill}:'
        '${coordinate?.latitude}:${coordinate?.longitude}';
    if (_leadStream == null || _leadKey != key) {
      _leadKey = key;
      _leadStream = _repository.watchLeads(worker);
    }
    return _leadStream!;
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  void _tab(int index, Widget fallback) {
    final select = widget.onSelectTab;
    select == null ? _open(fallback) : select(index);
  }

  void _openJob({
    required String id,
    required String title,
    required String category,
    required String location,
    required String budget,
    required String urgency,
    double? distanceKm,
  }) {
    _open(
      WorkerJobDetailScreen(
        requestId: id,
        title: title,
        category: category,
        location: location,
        distance: distanceKm == null
            ? 'Distance unavailable'
            : formatWorkerDistance(distanceKm),
        budget: budget.isEmpty
            ? 'Budget not provided'
            : formatWorkerBudget(budget),
        urgency: urgency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final embedded = WorkerNavigationScope.isEmbedded(context);
    return Scaffold(
      bottomNavigationBar: embedded
          ? null
          : const WorkerBottomBar(selectedIndex: 0),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<WorkerHomeProfile>(
          stream: _profileStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return WorkerHomeErrorState(onRetry: _retry);
            }
            return _dashboard(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _dashboard(WorkerHomeProfile worker) {
    final readiness = WorkerEligibilityAdapter.evaluate(worker);
    return RefreshIndicator(
      onRefresh: () async => _retry(),
      child: ListView(
        key: const Key('worker-home-content'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          WorkerHomeHeader(
            worker: worker,
            onNotifications: () => _open(const NotificationScreen()),
          ),
          const SizedBox(height: 20),
          WorkerReadinessCard(
            readiness: readiness,
            onAction: readiness.state == WorkerReadinessState.needsCredits
                ? () => _open(const WallatScreen())
                : readiness.state == WorkerReadinessState.blocked ||
                      readiness.state == WorkerReadinessState.inactive
                ? () => _tab(4, const WorkerProfileScreen())
                : () => _open(const WorkerVerificationCenterScreen()),
          ),
          const SizedBox(height: 22),
          const WorkerSectionHeader(title: 'Current work'),
          const SizedBox(height: 10),
          StreamBuilder<WorkerActiveJobsSnapshot>(
            stream: _activeJobsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const _CardLoader(key: Key('active-job-loading'));
              }
              if (snapshot.hasError) {
                return const WorkerHomeEmptyCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'Current work unavailable',
                  message:
                      'Your active assignment could not be loaded right now.',
                );
              }
              final active = snapshot.data;
              final job = active?.featured;
              if (job == null) {
                return const WorkerHomeEmptyCard(
                  icon: Icons.work_outline_rounded,
                  title: 'No active job',
                  message: 'Accepted and in-progress work will appear here.',
                );
              }
              return ActiveWorkerJobCard(
                job: job,
                hasAdditionalJobs: active!.hasAdditionalJobs,
                onTap: () => _openJob(
                  id: job.id,
                  title: job.title,
                  category: job.category,
                  location: job.location,
                  budget: job.budget,
                  urgency: job.urgency,
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          WorkerSectionHeader(
            title: 'New leads',
            actionLabel: 'See all leads',
            onAction: () => _tab(1, const MapSreen()),
          ),
          const SizedBox(height: 10),
          if (!readiness.canReceiveLeads)
            WorkerHomeEmptyCard(
              icon: Icons.lock_outline_rounded,
              title: 'Leads are locked',
              message: readiness.message,
            )
          else
            StreamBuilder<List<WorkerLeadPreview>>(
              stream: _leadsFor(worker, readiness),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const _CardLoader(key: Key('lead-loading'));
                }
                if (snapshot.hasError) {
                  return const WorkerHomeEmptyCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'Leads unavailable',
                    message: 'Relevant leads could not be loaded right now.',
                  );
                }
                final leads = snapshot.data ?? const <WorkerLeadPreview>[];
                if (leads.isEmpty) {
                  return const WorkerHomeEmptyCard(
                    icon: Icons.inbox_outlined,
                    title: 'No new leads',
                    message:
                        'Eligible requests matching your primary skill will appear here.',
                  );
                }
                return Column(
                  children: leads
                      .map(
                        (lead) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: WorkerLeadPreviewCard(
                            lead: lead,
                            onTap: () => _openJob(
                              id: lead.id,
                              title: lead.title,
                              category: lead.category,
                              location: lead.location,
                              budget: lead.budget,
                              urgency: lead.urgency,
                              distanceKm: lead.distanceKm,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          const SizedBox(height: 12),
          LeadCreditCard(
            credits: worker.credits,
            onTap: () => _open(const WallatScreen()),
          ),
          const SizedBox(height: 12),
          VerificationSummaryCard(
            worker: worker,
            onTap: () => _open(const WorkerVerificationCenterScreen()),
          ),
          if (worker.rating != null || worker.reviewCount != null) ...[
            const SizedBox(height: 22),
            const WorkerSectionHeader(title: 'Performance'),
            const SizedBox(height: 10),
            WorkerPerformanceSummary(worker: worker),
          ],
          const SizedBox(height: 22),
          const WorkerSectionHeader(title: 'Quick actions'),
          const SizedBox(height: 8),
          WorkerQuickActions(
            onLeads: () => _tab(1, const MapSreen()),
            onJobs: () => _tab(
              2,
              const JobsByStatusScreen(title: 'My jobs', status: 'all'),
            ),
            onMessages: () => _tab(3, const ChatScreen()),
            onProfile: () => _tab(4, const WorkerProfileScreen()),
          ),
        ],
      ),
    );
  }
}

class _CardLoader extends StatelessWidget {
  const _CardLoader({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 96,
    child: Center(child: CircularProgressIndicator()),
  );
}
