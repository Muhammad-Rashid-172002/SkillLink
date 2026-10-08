import 'package:flutter/material.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_components.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_detail_screen.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_models.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_jobs_repository.dart';

class WorkerJobsScreen extends StatefulWidget {
  const WorkerJobsScreen({
    super.key,
    this.initialGroup = WorkerJobGroup.active,
    this.embedded = false,
    this.repository,
    this.onOpenJob,
  });

  final WorkerJobGroup initialGroup;
  final bool embedded;
  final WorkerJobsRepository? repository;
  final ValueChanged<String>? onOpenJob;

  @override
  State<WorkerJobsScreen> createState() => _WorkerJobsScreenState();
}

class _WorkerJobsScreenState extends State<WorkerJobsScreen> {
  late final WorkerJobsRepository _repository;
  late WorkerJobGroup _group;
  final TextEditingController _searchController = TextEditingController();
  final Map<WorkerJobGroup, Stream<List<WorkerJob>>> _streams = {};
  String _search = '';
  int _retryToken = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseWorkerJobsRepository();
    _group = widget.initialGroup;
    _searchController.addListener(() {
      final next = _searchController.text;
      if (next == _search || !mounted) return;
      setState(() => _search = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openJob(String id) {
    final callback = widget.onOpenJob;
    if (callback != null) {
      callback(id);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            WorkerJobDetailV2Screen(requestId: id, repository: _repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(leading: const BackButton(), title: const Text('My jobs')),
      body: ContentWidth(
        maxWidth: 760,
        child: SafeArea(
          top: widget.embedded,
          child: Column(
            children: [
              _header(context),
              Expanded(child: _jobStream()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    // Sits on the page canvas like the other tab headers (no white band).
    return Container(
      padding: const EdgeInsets.fromLTRB(
        SkillNovaSpacing.md,
        SkillNovaSpacing.md,
        SkillNovaSpacing.md,
        SkillNovaSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.embedded) ...[
            Text('My jobs', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: SkillNovaSpacing.xxs),
            Text(
              'Manage accepted work and service history',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SkillNovaSpacing.md),
          ],
          TextField(
            key: const ValueKey('worker-jobs-search'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search service, customer, or area',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: SkillNovaSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<WorkerJobGroup>(
              key: const ValueKey('worker-jobs-groups'),
              segments: WorkerJobGroup.values
                  .map(
                    (group) => ButtonSegment<WorkerJobGroup>(
                      value: group,
                      label: Text(group.label),
                    ),
                  )
                  .toList(growable: false),
              selected: {_group},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _group = selection.single);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(
                  Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobStream() {
    return StreamBuilder<List<WorkerJob>>(
      key: ValueKey('${_group.name}-$_retryToken'),
      stream: _streams.putIfAbsent(_group, () => _repository.watchJobs(_group)),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return WorkerJobsStateView(
            icon: Icons.cloud_off_outlined,
            title: 'Unable to load ${_group.label.toLowerCase()} jobs',
            message: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: () => setState(() {
              _streams.remove(_group);
              _retryToken++;
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final jobs = searchWorkerJobs(snapshot.data!, _search);
        if (jobs.isEmpty) {
          final searching = _search.trim().isNotEmpty;
          return WorkerJobsStateView(
            icon: searching
                ? Icons.search_off_rounded
                : switch (_group) {
                    WorkerJobGroup.active => Icons.work_outline_rounded,
                    WorkerJobGroup.completed => Icons.task_alt_rounded,
                    WorkerJobGroup.cancelled => Icons.event_busy_outlined,
                  },
            title: searching
                ? 'No matching jobs'
                : switch (_group) {
                    WorkerJobGroup.active => 'No active jobs',
                    WorkerJobGroup.completed => 'No completed jobs yet',
                    WorkerJobGroup.cancelled => 'No cancelled jobs',
                  },
            message: searching
                ? 'Try another service, customer, or area.'
                : switch (_group) {
                    WorkerJobGroup.active =>
                      'Accepted jobs will appear here as you work through them.',
                    WorkerJobGroup.completed =>
                      'Jobs you complete will become part of your service history.',
                    WorkerJobGroup.cancelled =>
                      'Cancelled or rejected assigned jobs will appear here.',
                  },
          );
        }
        return RefreshIndicator(
          onRefresh: () => _repository.refreshJobs(_group),
          child: ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              SkillNovaSpacing.md,
              SkillNovaSpacing.md,
              SkillNovaSpacing.md,
              SkillNovaSpacing.xxl,
            ),
            itemCount: jobs.length,
            itemBuilder: (context, index) => WorkerJobCard(
              job: jobs[index],
              onView: () => _openJob(jobs[index].id),
            ),
          ),
        );
      },
    );
  }
}
