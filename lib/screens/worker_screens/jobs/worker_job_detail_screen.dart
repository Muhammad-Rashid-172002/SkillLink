import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skill_link/design_system/widgets/skillnova_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_components.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_models.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_jobs_repository.dart';
import 'package:skill_link/screens/worker_screens/messages/worker_chat_detail_screen.dart';
import 'package:skill_link/services/emergency_service.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerJobDetailV2Screen extends StatefulWidget {
  const WorkerJobDetailV2Screen({
    super.key,
    required this.requestId,
    this.repository,
    this.enableLocationSharing = true,
    this.onMessage,
    this.onCall,
    this.onSos,
  });

  final String requestId;
  final WorkerJobsRepository? repository;
  final bool enableLocationSharing;
  final Future<void> Function(WorkerJob job)? onMessage;
  final Future<void> Function(String phone)? onCall;
  final Future<void> Function(WorkerJob job)? onSos;

  @override
  State<WorkerJobDetailV2Screen> createState() =>
      _WorkerJobDetailV2ScreenState();
}

class _WorkerJobDetailV2ScreenState extends State<WorkerJobDetailV2Screen> {
  late final WorkerJobsRepository _repository;
  late final Stream<WorkerJob?> _jobStream;
  late final Stream<WorkerCoordinate?> _workerCoordinateStream;
  Timer? _locationTimer;
  bool _isUpdating = false;
  bool _isOpeningChat = false;
  bool _isSendingSos = false;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseWorkerJobsRepository();
    _jobStream = _repository.watchJob(widget.requestId);
    _workerCoordinateStream = _repository.watchWorkerCoordinate();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _syncLocationSharing(WorkerJob job) {
    if (!widget.enableLocationSharing) return;
    final shouldShare = job.status.status == WorkerJobStatus.onTheWay;
    if (!shouldShare) {
      _locationTimer?.cancel();
      _locationTimer = null;
      return;
    }
    if (_locationTimer != null) return;
    _locationTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _shareLocation(job.id),
    );
    _shareLocation(job.id);
  }

  Future<void> _shareLocation(String requestId) async {
    try {
      final result = await _repository.shareLocation(requestId);
      if (!mounted) return;
      setState(() {
        _locationMessage = switch (result) {
          WorkerLocationUpdateResult.shared =>
            'Foreground location shared for this active journey.',
          WorkerLocationUpdateResult.permissionDenied =>
            'Location permission is denied. Enable it to share your position.',
          WorkerLocationUpdateResult.serviceDisabled =>
            'Location services are off. Turn them on to share your position.',
        };
      });
      if (result != WorkerLocationUpdateResult.shared) {
        _locationTimer?.cancel();
        _locationTimer = null;
      }
    } on WorkerJobTransitionException catch (error) {
      _locationTimer?.cancel();
      _locationTimer = null;
      if (mounted) setState(() => _locationMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationMessage =
              'Location could not be updated. Check your connection and permissions.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WorkerJob?>(
      stream: _jobStream,
      builder: (context, snapshot) {
        Widget body;
        Widget bottom = const SizedBox.shrink();
        if (snapshot.hasError) {
          body = const WorkerJobsStateView(
            icon: Icons.cloud_off_outlined,
            title: 'Unable to load job',
            message: 'Check your connection and try again.',
          );
        } else if (!snapshot.hasData) {
          body = snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : const WorkerJobsStateView(
                  icon: Icons.find_in_page_outlined,
                  title: 'Job not found',
                  message:
                      'This request may have been removed or is no longer available.',
                );
        } else {
          final job = snapshot.data!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncLocationSharing(job);
          });
          if (job.workerId != _repository.currentWorkerId) {
            body = const WorkerJobsStateView(
              icon: Icons.lock_outline_rounded,
              title: 'Job unavailable',
              message: 'This job is not assigned to your worker account.',
            );
          } else {
            body = StreamBuilder<WorkerCoordinate?>(
              stream: _workerCoordinateStream,
              builder: (context, workerSnapshot) {
                return _content(job, workerSnapshot.data);
              },
            );
            if (job.status.next != null) bottom = _lifecycleBar(job);
          }
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Job details')),
          body: body,
          bottomNavigationBar: bottom,
        );
      },
    );
  }

  Widget _content(WorkerJob job, WorkerCoordinate? workerCoordinate) {
    return ListView(
      key: const ValueKey('worker-job-detail-scroll'),
      padding: const EdgeInsets.fromLTRB(
        SkillNovaSpacing.md,
        SkillNovaSpacing.sm,
        SkillNovaSpacing.md,
        SkillNovaSpacing.xxl,
      ),
      children: [
        _statusHeader(job),
        const SizedBox(height: SkillNovaSpacing.md),
        _customerSection(job),
        const SizedBox(height: SkillNovaSpacing.md),
        _serviceSection(job),
        if (job.imageUrls.isNotEmpty) ...[
          const SizedBox(height: SkillNovaSpacing.md),
          _images(job),
        ],
        const SizedBox(height: SkillNovaSpacing.md),
        _locationSection(job, workerCoordinate),
        if (job.status.isActive) ...[
          const SizedBox(height: SkillNovaSpacing.md),
          _safetySection(job),
        ],
        if (job.status.status == WorkerJobStatus.completed) ...[
          const SizedBox(height: SkillNovaSpacing.md),
          _reviewSection(job),
        ],
        if (job.status.status == WorkerJobStatus.cancelled &&
            job.cancellationReason.isNotEmpty) ...[
          const SizedBox(height: SkillNovaSpacing.md),
          WorkerJobSection(
            title: 'Cancellation details',
            icon: Icons.info_outline_rounded,
            child: Text(job.cancellationReason),
          ),
        ],
        const SizedBox(height: SkillNovaSpacing.md),
        _progress(job),
      ],
    );
  }

  Widget _statusHeader(WorkerJob job) {
    final colors = Theme.of(context).colorScheme;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: WorkerJobStatusBadge(status: job.status)),
            ],
          ),
          const SizedBox(height: SkillNovaSpacing.md),
          Text(job.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: SkillNovaSpacing.xs),
          Text(job.category, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: SkillNovaSpacing.md),
          Wrap(
            spacing: SkillNovaSpacing.md,
            runSpacing: SkillNovaSpacing.xs,
            children: [
              _inlineFact(
                Icons.calendar_today_outlined,
                workerJobDateLabel(job.relevantDate),
              ),
              if (job.urgency.isNotEmpty)
                _inlineFact(Icons.priority_high_rounded, job.urgency),
            ],
          ),
        ],
      ),
    );
  }

  Widget _customerSection(WorkerJob job) {
    final customer = job.customer;
    return WorkerJobSection(
      title: 'Customer',
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          Row(
            children: [
              WorkerJobCustomerAvatar(customer: customer, size: 54),
              const SizedBox(width: SkillNovaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer?.name ?? 'Customer information unavailable',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      customer?.serviceArea.isNotEmpty == true
                          ? customer!.serviceArea
                          : job.serviceArea,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SkillNovaSpacing.md),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: _isOpeningChat ? 'Opening…' : 'Message',
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: _isOpeningChat ? null : () => _openMessage(job),
                ),
              ),
              const SizedBox(width: SkillNovaSpacing.sm),
              Expanded(
                child: SecondaryButton(
                  label: customer?.phone.isNotEmpty == true
                      ? 'Call'
                      : 'Phone unavailable',
                  icon: Icons.call_outlined,
                  onPressed: customer?.phone.isNotEmpty == true
                      ? () => _callCustomer(customer!.phone)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _serviceSection(WorkerJob job) {
    return WorkerJobSection(
      title: 'Service details',
      icon: Icons.assignment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('Posted budget', formatWorkerJobBudget(job.budget)),
          if (job.urgency.isNotEmpty) _detailRow('Urgency', job.urgency),
          if (job.address.isNotEmpty)
            _detailRow('Service address', job.address),
          if (job.description.isNotEmpty) ...[
            const SizedBox(height: SkillNovaSpacing.sm),
            Text('Description', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: SkillNovaSpacing.xs),
            Text(job.description),
          ],
          if (job.notes.isNotEmpty) ...[
            const SizedBox(height: SkillNovaSpacing.sm),
            Text(
              'Customer notes',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: SkillNovaSpacing.xs),
            Text(job.notes),
          ],
          if (job.description.isEmpty && job.notes.isEmpty)
            Text(
              'No additional service description was provided.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }

  Widget _images(WorkerJob job) {
    return WorkerJobSection(
      title: 'Request images',
      icon: Icons.photo_library_outlined,
      child: SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: job.imageUrls.length,
          separatorBuilder: (_, _) =>
              const SizedBox(width: SkillNovaSpacing.xs),
          itemBuilder: (context, index) {
            final url = job.imageUrls[index];
            return InkWell(
              onTap: () => _openImage(url),
              borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
                child: Image.network(
                  url,
                  width: 118,
                  height: 104,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 118,
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _locationSection(WorkerJob job, WorkerCoordinate? workerCoordinate) {
    final service = job.serviceCoordinate;
    final hasMap = service != null || workerCoordinate != null;
    final statusMessage = switch (job.status.status) {
      WorkerJobStatus.accepted =>
        'Foreground location sharing starts only after you select “On my way”.',
      WorkerJobStatus.onTheWay =>
        _locationMessage ??
            'Foreground location sharing is active while this screen is open.',
      WorkerJobStatus.inProgress =>
        'Journey location sharing has stopped because the service is in progress.',
      _ => 'No active journey location sharing.',
    };
    return WorkerJobSection(
      title: 'Location and tracking',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (job.address.isNotEmpty) ...[
            Text(job.address, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: SkillNovaSpacing.sm),
          ],
          if (hasMap)
            ClipRRect(
              borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
              child: SizedBox(
                height: 220,
                child: SkillNovaMap(
                  label: 'Service location',
                  latitude: service?.latitude,
                  longitude: service?.longitude,
                  builder: (_) => GoogleMap(
                    key: const ValueKey('worker-job-map'),
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        (service ?? workerCoordinate!).latitude,
                        (service ?? workerCoordinate!).longitude,
                      ),
                      zoom: 13,
                    ),
                    markers: {
                      if (service != null)
                        Marker(
                          markerId: const MarkerId('service-location'),
                          position: LatLng(service.latitude, service.longitude),
                          infoWindow: const InfoWindow(
                            title: 'Service location',
                          ),
                        ),
                      if (workerCoordinate != null)
                        Marker(
                          markerId: const MarkerId('worker-location'),
                          position: LatLng(
                            workerCoordinate.latitude,
                            workerCoordinate.longitude,
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ),
                          infoWindow: const InfoWindow(
                            title: 'Your current location',
                          ),
                        ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                  ),
                ),
              ),
            )
          else
            Container(
              key: const ValueKey('worker-job-no-map'),
              width: double.infinity,
              padding: const EdgeInsets.all(SkillNovaSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
              ),
              child: const Text(
                'A map is unavailable because this job has no valid coordinates.',
                textAlign: TextAlign.center,
              ),
            ),
          if (job.distanceKm != null) ...[
            const SizedBox(height: SkillNovaSpacing.sm),
            _inlineFact(
              Icons.near_me_outlined,
              '${job.distanceKm!.toStringAsFixed(1)} km straight-line distance',
            ),
          ],
          const SizedBox(height: SkillNovaSpacing.sm),
          Text(statusMessage, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: SkillNovaSpacing.xs),
          Text(
            'No route or arrival time is calculated.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _safetySection(WorkerJob job) {
    return WorkerJobSection(
      title: 'Safety',
      icon: Icons.shield_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.hasActiveEmergency
                ? 'An SOS alert is already active for this job.'
                : 'SOS shares your current location and job details with the SkillNova admin. It does not automatically contact emergency services.',
          ),
          const SizedBox(height: SkillNovaSpacing.md),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Call Police 15',
                  icon: Icons.local_police_outlined,
                  onPressed: _callPolice,
                ),
              ),
              const SizedBox(width: SkillNovaSpacing.sm),
              Expanded(
                child: SkillNovaButton(
                  label: job.hasActiveEmergency
                      ? 'SOS active'
                      : _isSendingSos
                      ? 'Sending…'
                      : 'Send SOS',
                  icon: Icons.sos_rounded,
                  variant: SkillNovaButtonVariant.destructive,
                  onPressed: job.hasActiveEmergency || _isSendingSos
                      ? null
                      : () => _sendSos(job),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewSection(WorkerJob job) {
    final review = job.review;
    return WorkerJobSection(
      title: 'Customer review',
      icon: Icons.star_outline_rounded,
      child: review == null
          ? const Text('No review yet')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: SkillNovaColors.rating,
                    ),
                    const SizedBox(width: SkillNovaSpacing.xs),
                    Text(
                      review.rating.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                if (review.text.isNotEmpty) ...[
                  const SizedBox(height: SkillNovaSpacing.sm),
                  Text(review.text),
                ],
              ],
            ),
    );
  }

  Widget _progress(WorkerJob job) {
    const steps = [
      WorkerJobStatus.accepted,
      WorkerJobStatus.onTheWay,
      WorkerJobStatus.inProgress,
      WorkerJobStatus.completed,
    ];
    final current = steps.indexOf(job.status.status);
    return WorkerJobSection(
      title: 'Job progress',
      icon: Icons.route_outlined,
      child: Column(
        children: List.generate(steps.length, (index) {
          final presentation = workerJobStatusPresentation(steps[index]);
          final reached = current >= index;
          final color = reached
              ? workerJobStatusColor(context, presentation.status)
              : Theme.of(context).colorScheme.outline;
          return Row(
            children: [
              Column(
                children: [
                  Icon(
                    reached
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: color,
                    size: 22,
                  ),
                  if (index != steps.length - 1)
                    Container(
                      width: 2,
                      height: 24,
                      color: color.withValues(alpha: .4),
                    ),
                ],
              ),
              const SizedBox(width: SkillNovaSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    presentation.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: reached ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _lifecycleBar(WorkerJob job) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        SkillNovaSpacing.md,
        SkillNovaSpacing.sm,
        SkillNovaSpacing.md,
        SkillNovaSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: PrimaryButton(
          key: const ValueKey('worker-job-primary-action'),
          label: workerJobPrimaryAction(job.status.status),
          icon: switch (job.status.status) {
            WorkerJobStatus.accepted => Icons.navigation_rounded,
            WorkerJobStatus.onTheWay => Icons.handyman_rounded,
            WorkerJobStatus.inProgress => Icons.task_alt_rounded,
            _ => Icons.arrow_forward_rounded,
          },
          loading: _isUpdating,
          fullWidth: true,
          onPressed: _isUpdating ? null : () => _advance(job),
        ),
      ),
    );
  }

  Future<void> _advance(WorkerJob job) async {
    if (_isUpdating) return;
    final next = job.status.next;
    if (next == null) return;
    if (next == WorkerJobStatus.completed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Complete this job?'),
          content: const SingleChildScrollView(
            child: Text(
              'This marks the service as completed. The posted budget is customer-provided and is not a confirmed payout or payment.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              key: const ValueKey('confirm-complete-job'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Complete job'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _isUpdating = true);
    try {
      await _repository.transitionJob(
        requestId: job.id,
        expectedStatus: job.status.status,
        nextStatus: next,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Job updated to ${workerJobStatusPresentation(next).label}.',
          ),
        ),
      );
    } on WorkerJobTransitionException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage('The job could not be updated. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _openMessage(WorkerJob job) async {
    if (_isOpeningChat) return;
    setState(() => _isOpeningChat = true);
    try {
      final override = widget.onMessage;
      if (override != null) {
        await override(job);
        return;
      }
      final destination = await _repository.resolveChat(job);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => WorkerChatDetailV2Screen(
            chatId: destination.chatId,
            customerId: destination.customerId,
            customerName: destination.customerName,
            service: destination.service,
            requestId: job.id,
          ),
        ),
      );
    } on WorkerJobTransitionException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Messaging is unavailable right now.');
    } finally {
      if (mounted) setState(() => _isOpeningChat = false);
    }
  }

  Future<void> _callCustomer(String phone) async {
    final override = widget.onCall;
    if (override != null) {
      await override(phone);
      return;
    }
    final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!opened && mounted) _showMessage('The phone dialer is unavailable.');
  }

  Future<void> _callPolice() async {
    final opened = await launchUrl(Uri(scheme: 'tel', path: '15'));
    if (!opened && mounted) _showMessage('Call Police 15 manually.');
  }

  Future<void> _sendSos(WorkerJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send emergency SOS?'),
        content: const SingleChildScrollView(
          child: Text(
            'Your current GPS location and job details will be shared with the SkillNova admin. This does not automatically contact emergency services.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSendingSos = true);
    try {
      final override = widget.onSos;
      if (override != null) {
        await override(job);
      } else {
        await EmergencyService().createEmergencyAlert(
          requestId: job.id,
          requestData: job.data,
          workerId: _repository.currentWorkerId ?? '',
          raisedByRole: 'worker',
          jobStatus: job.status.firestoreValue,
          reason: 'Emergency assistance required',
        );
      }
      if (mounted) {
        _showMessage('SOS alert sent to the SkillNova admin.');
      }
    } on EmergencyServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage('SOS could not be sent. Call Police 15 if needed.');
      }
    } finally {
      if (mounted) setState(() => _isSendingSos = false);
    }
  }

  void _openImage(String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: IconButton(
                tooltip: 'Close image',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: SkillNovaSpacing.sm),
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _inlineFact(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
