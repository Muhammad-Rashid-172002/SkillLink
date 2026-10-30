import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skilllink_admin/services/ser_management_service.dart';
import 'package:skilllink_admin/services/verification_management_service.dart';
import 'package:skilllink_admin/theme/admin_design.dart';
import 'package:skilllink_admin/widgets/user_deletion_dialogs.dart';

/// Full details for one user, opened from User Management. Verification is
/// reviewed through the existing verification workflow; documents are
/// fetched only through admin-authorised Storage access.
class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({
    super.key,
    required this.user,
    required this.gateway,
  });

  final ManagedUser user;
  final UserAdminGateway gateway;

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  late Future<VerificationDetails?> _verification;
  bool _busy = false;

  ManagedUser get user => widget.user;

  @override
  void initState() {
    super.initState();
    _verification = user.isWorker
        ? widget.gateway.loadVerification(user.id)
        : Future.value(null);
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? kAdminDanger : null,
      ),
    );
  }

  Future<void> _guard(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _toast(success);
    } catch (_) {
      if (mounted) _toast('That did not work. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve(VerificationRequestModel request) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve identity verification?'),
        content: Text(
          'Confirm that you checked the CNIC and selfie of '
          '${user.displayName}. They will be able to accept jobs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _guard(
      () => widget.gateway.approveVerification(request),
      'Verification approved.',
    );
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _reject(VerificationRequestModel request) async {
    final reason = await showReasonDialog(
      context,
      title: 'Reject identity verification',
      message: 'Tell ${user.displayName} what to fix before resubmitting.',
      reasonLabel: 'Reason shown to the worker',
      confirmLabel: 'Reject',
      danger: true,
    );
    if (reason == null || !mounted) return;
    await _guard(
      () => widget.gateway.rejectVerification(request, reason),
      'Verification rejected.',
    );
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final request = await showDeleteUserDialog(context, user);
    if (request == null || !mounted) return;
    setState(() => _busy = true);
    final outcome = await widget.gateway.deleteUser(
      user.id,
      reason: request.reason,
      detail: request.detail,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(outcome.description, error: !outcome.succeeded);
    if (outcome.succeeded) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = user.id == widget.gateway.currentAdminUid;
    return Scaffold(
      backgroundColor: kAdminCanvas,
      appBar: AppBar(
        title: Text(user.displayName),
        actions: [
          if (!isSelf)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                key: const Key('detail-delete'),
                style: FilledButton.styleFrom(backgroundColor: kAdminDanger),
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('Delete user'),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Section(
                title: 'Profile',
                children: [
                  _Row('Name', user.displayName),
                  _Row('Account type', user.roleLabel),
                  _Row('Email', user.email.isEmpty ? '—' : user.email),
                  _Row('Phone', user.phone.isEmpty ? '—' : user.phone),
                  _Row(
                    'Registered',
                    user.createdAt == null
                        ? 'Unknown'
                        : DateFormat(
                            'd MMM yyyy, h:mm a',
                          ).format(user.createdAt!),
                  ),
                  _Row('Account status', user.accountStatusLabel),
                  _Row('User ID', user.id),
                  if (user.isWorker)
                    _Row(
                      'Service',
                      user.rawData['skill']?.toString() ?? 'Not set',
                    ),
                ],
              ),
              _Section(
                title: 'Verification',
                children: [
                  _Row(
                    'Email',
                    user.emailVerified ? 'Verified' : 'Not verified',
                  ),
                  _Row(
                    'Phone',
                    user.phoneVerified ? 'Verified' : 'Not verified',
                  ),
                  if (user.isWorker)
                    _Row('Identity (CNIC)', user.identityStatusLabel),
                  _Row('Overall', switch (user.verification) {
                    UserVerification.verified => 'Verified',
                    UserVerification.pending => 'Pending verification',
                    UserVerification.rejected => 'Rejected',
                    UserVerification.unverified => 'Unverified',
                  }),
                ],
              ),
              _Section(
                title: 'Profile completeness',
                children: [
                  if (user.missingProfileItems.isEmpty)
                    const _Row('Status', 'Complete')
                  else
                    for (final item in user.missingProfileItems)
                      _Row('Missing', item),
                ],
              ),
              if (user.isWorker)
                FutureBuilder<VerificationDetails?>(
                  future: _verification,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _Section(
                        title: 'Verification documents',
                        children: [LinearProgressIndicator()],
                      );
                    }
                    if (snapshot.hasError) {
                      return const _Section(
                        title: 'Verification documents',
                        children: [
                          Text('Documents could not be loaded. Try again.'),
                        ],
                      );
                    }
                    final details = snapshot.data;
                    if (details == null) {
                      return const _Section(
                        title: 'Verification documents',
                        children: [
                          Text('This worker has not submitted documents.'),
                        ],
                      );
                    }
                    final request = details.request;
                    return _Section(
                      title: 'Verification documents',
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final (label, path) in [
                              ('CNIC front', request.cnicFrontPath),
                              ('CNIC back', request.cnicBackPath),
                              ('Live selfie', request.liveSelfiePath),
                            ])
                              _DocumentTile(
                                label: label,
                                path: path,
                                load: widget.gateway.documentUrl,
                              ),
                          ],
                        ),
                        if (request.isPending) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                key: const Key('detail-approve'),
                                onPressed: _busy
                                    ? null
                                    : () => _approve(request),
                                icon: const Icon(Icons.verified_rounded),
                                label: const Text('Approve verification'),
                              ),
                              OutlinedButton.icon(
                                key: const Key('detail-reject'),
                                onPressed: _busy
                                    ? null
                                    : () => _reject(request),
                                icon: const Icon(Icons.block_rounded),
                                label: const Text('Reject'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
            ],
          ),
          if (_busy)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kAdminText,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: kAdminTextMuted),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: kAdminText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatefulWidget {
  const _DocumentTile({
    required this.label,
    required this.path,
    required this.load,
  });

  final String label;
  final String path;
  final Future<String?> Function(String path) load;

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  late final Future<String?> _url = widget.path.isEmpty
      ? Future.value(null)
      : widget.load(widget.path);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: kAdminCanvas,
                child: FutureBuilder<String?>(
                  future: _url,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final url = snapshot.data;
                    if (snapshot.hasError || url == null) {
                      return Center(
                        child: Text(
                          widget.path.isEmpty ? 'Not uploaded' : 'Unavailable',
                        ),
                      );
                    }
                    return Image.network(
                      url,
                      fit: BoxFit.cover,
                      semanticLabel: widget.label,
                      errorBuilder: (_, _, _) =>
                          const Center(child: Text('Unavailable')),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
