import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Map/worker_job_detail.dart';
import 'package:skill_link/screens/worker_screens/Wallat/Wallat_screen.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_lead_components.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_lead_models.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_leads_repository.dart';

class WorkerLeadDetailScreen extends StatefulWidget {
  const WorkerLeadDetailScreen({
    super.key,
    required this.requestId,
    this.repository,
    this.onAccepted,
    this.onGetCredits,
  });

  final String requestId;
  final WorkerLeadsRepository? repository;
  final ValueChanged<WorkerLead>? onAccepted;
  final VoidCallback? onGetCredits;

  @override
  State<WorkerLeadDetailScreen> createState() => _WorkerLeadDetailScreenState();
}

class _WorkerLeadDetailScreenState extends State<WorkerLeadDetailScreen> {
  late final WorkerLeadsRepository _repository;
  late Stream<WorkerHomeProfile> _workerStream;
  Stream<WorkerLead?>? _leadStream;
  String? _leadKey;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseWorkerLeadsRepository();
    _workerStream = _repository.currentWorkerId == null
        ? Stream.error('Signed out')
        : _repository.watchWorker();
  }

  Stream<WorkerLead?> _streamFor(WorkerHomeProfile worker) {
    final point = worker.coordinate;
    final key = '${worker.uid}:${point?.latitude}:${point?.longitude}';
    if (_leadStream == null || _leadKey != key) {
      _leadKey = key;
      _leadStream = _repository.watchLead(widget.requestId, worker);
    }
    return _leadStream!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lead details')),
      body: StreamBuilder<WorkerHomeProfile>(
        stream: _workerStream,
        builder: (context, workerSnapshot) {
          if (workerSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (workerSnapshot.hasError || !workerSnapshot.hasData) {
            return _errorState('Your worker profile could not be loaded.');
          }
          final worker = workerSnapshot.data!;
          return StreamBuilder<WorkerLead?>(
            stream: _streamFor(worker),
            builder: (context, leadSnapshot) {
              if (leadSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (leadSnapshot.hasError) {
                return _errorState('This lead could not be loaded.');
              }
              final lead = leadSnapshot.data;
              if (lead == null) return _missingState();
              final eligibility = WorkerLeadEligibility.evaluate(worker, lead);
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      key: ValueKey('lead-detail-${lead.id}'),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _serviceHeader(lead),
                        const SizedBox(height: 12),
                        _customerSummary(lead),
                        const SizedBox(height: 12),
                        _requestDetails(lead),
                        const SizedBox(height: 12),
                        _images(lead),
                        const SizedBox(height: 12),
                        _location(lead),
                        const SizedBox(height: 12),
                        _creditCost(worker),
                        if (!eligibility.canAccept) ...[
                          const SizedBox(height: 12),
                          _eligibilityState(eligibility),
                        ],
                      ],
                    ),
                  ),
                  _bottomAction(worker, lead, eligibility),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _serviceHeader(WorkerLead lead) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                workerLeadCategoryIcon(lead.category),
                color: colors.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  lead.category,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              WorkerLeadUrgencyBadge(urgency: lead.urgency),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            lead.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _pill(
                Icons.schedule_rounded,
                workerLeadRelativeTime(lead.createdAt),
              ),
              _pill(
                Icons.radar_rounded,
                lead.isAvailable ? 'Available now' : 'No longer available',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _customerSummary(WorkerLead lead) {
    final customer = lead.customer;
    return _section(
      title: 'Customer summary',
      icon: Icons.person_outline_rounded,
      child: Row(
        children: [
          WorkerLeadCustomerAvatar(customer: customer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer?.publicName ?? 'Customer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(lead.publicServiceArea),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestDetails(WorkerLead lead) {
    return _section(
      title: 'Request details',
      icon: Icons.description_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lead.description),
          if (lead.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Additional notes',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(lead.notes),
          ],
          const SizedBox(height: 14),
          _detailRow('Urgency', lead.urgency),
          _detailRow('Posted budget', lead.postedBudget),
          _detailRow('Posted', _fullDate(lead.createdAt)),
        ],
      ),
    );
  }

  Widget _location(WorkerLead lead) {
    return _section(
      title: 'Service area',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lead.publicServiceArea,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (lead.distanceKm != null) ...[
            const SizedBox(height: 5),
            Text(workerLeadDistance(lead.distanceKm)),
          ],
          const SizedBox(height: 10),
          Text(
            'The exact service address is kept private until this lead is accepted.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _creditCost(WorkerHomeProfile worker) {
    return _section(
      title: 'Lead credits',
      icon: Icons.toll_outlined,
      child: Column(
        children: [
          _detailRow('Lead cost', '1 credit'),
          _detailRow('Your balance', '${worker.credits} credits'),
          const SizedBox(height: 6),
          const Text('Credits are used to accept eligible leads.'),
        ],
      ),
    );
  }

  Widget _images(WorkerLead lead) {
    final images = lead.imageUrls;
    return _section(
      title: 'Request photos',
      icon: Icons.photo_library_outlined,
      child: images.isEmpty
          ? const Text('The customer did not attach any request photos.')
          : SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (context, index) => GestureDetector(
                  key: ValueKey('lead-image-$index'),
                  onTap: () => _openImages(images, index),
                  child: Container(
                    width: 132,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _eligibilityState(WorkerLeadEligibility eligibility) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: eligibility.needsCredits
            ? colors.tertiaryContainer
            : colors.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eligibility.title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(eligibility.message),
        ],
      ),
    );
  }

  Widget _bottomAction(
    WorkerHomeProfile worker,
    WorkerLead lead,
    WorkerLeadEligibility eligibility,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!eligibility.canAccept) ...[
              Text(
                eligibility.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 7),
            ],
            SizedBox(
              width: double.infinity,
              child: eligibility.needsCredits
                  ? ElevatedButton.icon(
                      key: const ValueKey('get-lead-credits'),
                      onPressed: _getCredits,
                      icon: const Icon(Icons.toll_rounded),
                      label: const Text('Get credits'),
                    )
                  : ElevatedButton.icon(
                      key: const ValueKey('accept-lead'),
                      onPressed: eligibility.canAccept && !_isAccepting
                          ? () => _confirmAccept(worker, lead)
                          : null,
                      icon: _isAccepting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        _isAccepting
                            ? 'Accepting lead…'
                            : eligibility.canAccept
                            ? 'Accept lead'
                            : 'Lead unavailable',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAccept(WorkerHomeProfile worker, WorkerLead lead) async {
    if (_isAccepting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Accept this lead?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lead.category,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _dialogLine('Posted budget', lead.postedBudget),
            _dialogLine('Lead cost', '1 credit'),
            _dialogLine(
              'Your balance',
              '${worker.credits} credits → ${worker.credits - 1} credits',
            ),
            const SizedBox(height: 12),
            const Text(
              'Accepting spends 1 lead credit. The posted budget is customer-provided and is not guaranteed earnings or payment.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const ValueKey('confirm-accept-lead'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Accept lead'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _isAccepting) return;
    setState(() => _isAccepting = true);
    try {
      await _repository.acceptLead(lead.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead accepted. 1 credit used.')),
      );
      final callback = widget.onAccepted;
      if (callback != null) {
        callback(lead);
      } else {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => WorkerJobDetailScreen(
              requestId: lead.id,
              title: lead.title,
              category: lead.category,
              location: lead.privateLocation,
              distance: workerLeadDistance(lead.distanceKm),
              budget: lead.postedBudget,
              urgency: lead.urgency,
            ),
          ),
        );
      }
    } on WorkerLeadAcceptanceException catch (error) {
      if (!mounted) return;
      _showFailure(error.message);
      if (error.failure == WorkerLeadAcceptanceFailure.insufficientCredits) {
        // The fresh transaction result is authoritative; the worker can use
        // the visible Get credits route after the profile stream refreshes.
      }
    } catch (_) {
      if (mounted) {
        _showFailure('The lead could not be accepted. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  void _getCredits() {
    final callback = widget.onGetCredits;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const WallatScreen()),
    );
  }

  void _showFailure(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(message),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _dialogLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  Widget _pill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 14), const SizedBox(width: 5), Text(text)],
    ),
  );

  Future<void> _openImages(List<String> images, int initialIndex) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            _LeadImageViewer(images: images, initialIndex: initialIndex),
      ),
    );
  }

  Widget _errorState(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  Widget _missingState() => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('This lead no longer exists.'),
    ),
  );
}

class _LeadImageViewer extends StatefulWidget {
  const _LeadImageViewer({required this.images, required this.initialIndex});
  final List<String> images;
  final int initialIndex;

  @override
  State<_LeadImageViewer> createState() => _LeadImageViewerState();
}

class _LeadImageViewerState extends State<_LeadImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      foregroundColor: Colors.white,
      title: Text('${_index + 1} of ${widget.images.length}'),
    ),
    body: PageView.builder(
      controller: _controller,
      itemCount: widget.images.length,
      onPageChanged: (value) => setState(() => _index = value),
      itemBuilder: (_, index) => InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Image.network(
          widget.images[index],
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

String _fullDate(DateTime? value) {
  if (value == null) return 'Recently';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}
