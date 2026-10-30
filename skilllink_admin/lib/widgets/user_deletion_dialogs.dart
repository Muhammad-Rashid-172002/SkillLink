import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skilllink_admin/services/ser_management_service.dart';
import 'package:skilllink_admin/theme/admin_design.dart';

/// What the admin chose in a deletion dialog.
class DeletionRequest {
  const DeletionRequest({
    required this.reason,
    this.detail = '',
    this.perUserReasons = const {},
  });

  final DeletionReason reason;
  final String detail;
  final Map<String, DeletionReason> perUserReasons;
}

/// Confirmation for deleting one account. Returns null when cancelled.
Future<DeletionRequest?> showDeleteUserDialog(
  BuildContext context,
  ManagedUser user,
) {
  return showDialog<DeletionRequest>(
    context: context,
    builder: (_) => _DeletionDialog(users: [user]),
  );
}

/// Confirmation for deleting several accounts. Returns null when cancelled.
Future<DeletionRequest?> showBulkDeleteDialog(
  BuildContext context,
  List<ManagedUser> users,
) {
  return showDialog<DeletionRequest>(
    context: context,
    builder: (_) => _DeletionDialog(users: users),
  );
}

class _DeletionDialog extends StatefulWidget {
  const _DeletionDialog({required this.users});
  final List<ManagedUser> users;

  @override
  State<_DeletionDialog> createState() => _DeletionDialogState();
}

class _DeletionDialogState extends State<_DeletionDialog> {
  DeletionReason? _reason;
  final _detail = TextEditingController();
  bool _understood = false;
  bool _perUser = false;
  final Map<String, DeletionReason> _perUserReasons = {};

  bool get _bulk => widget.users.length > 1;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  bool get _valid {
    if (!_understood || _reason == null) return false;
    if (_reason == DeletionReason.other && _detail.text.trim().length < 3) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final user = widget.users.first;
    return AlertDialog(
      icon: const Icon(
        Icons.delete_forever_rounded,
        color: kAdminDanger,
        size: 32,
      ),
      title: Text(
        _bulk
            ? 'Permanently delete ${widget.users.length} accounts?'
            : 'Permanently delete this account?',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_bulk)
                _SummaryCard(
                  rows: [
                    ('Name', user.displayName),
                    if (user.email.isNotEmpty)
                      ('Email', user.email)
                    else
                      (
                        'Phone',
                        user.maskedPhone.isEmpty
                            ? 'Not provided'
                            : user.maskedPhone,
                      ),
                    ('Account type', user.roleLabel),
                  ],
                )
              else
                _SummaryCard(
                  rows: [
                    ('Accounts', '${widget.users.length}'),
                    (
                      'Customers',
                      '${widget.users.where((u) => u.isCustomer).length}',
                    ),
                    (
                      'Workers',
                      '${widget.users.where((u) => u.isWorker).length}',
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kAdminDanger.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: kAdminDanger.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'This is permanent and cannot be undone. The sign-in '
                  'account, profile, photos and identity documents are '
                  'deleted. Shared history (jobs, chats, reviews written) is '
                  'kept for the other person with the name removed. Safety, '
                  'report and audit records are kept.',
                  style: text.bodySmall?.copyWith(color: kAdminText),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _bulk ? 'Reason (applies to all)' : 'Reason for deletion',
                style: text.titleSmall,
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<DeletionReason>(
                key: const Key('deletion-reason'),
                initialValue: _reason,
                hint: const Text('Choose a reason'),
                items: [
                  for (final reason in DeletionReason.values)
                    DropdownMenuItem(value: reason, child: Text(reason.label)),
                ],
                onChanged: (value) => setState(() => _reason = value),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_reason == DeletionReason.other) ...[
                const SizedBox(height: 10),
                TextField(
                  key: const Key('deletion-reason-detail'),
                  controller: _detail,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Describe the reason',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_bulk) ...[
                const SizedBox(height: 4),
                SwitchListTile(
                  key: const Key('per-user-reasons'),
                  contentPadding: EdgeInsets.zero,
                  value: _perUser,
                  onChanged: (value) => setState(() => _perUser = value),
                  title: const Text('Set a different reason per account'),
                ),
                if (_perUser)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final u in widget.users)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    u.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<DeletionReason>(
                                  value: _perUserReasons[u.id],
                                  hint: const Text('Same as above'),
                                  items: [
                                    for (final reason in DeletionReason.values)
                                      if (reason != DeletionReason.other)
                                        DropdownMenuItem(
                                          value: reason,
                                          child: Text(reason.label),
                                        ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    if (value == null) {
                                      _perUserReasons.remove(u.id);
                                    } else {
                                      _perUserReasons[u.id] = value;
                                    }
                                  }),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const Key('deletion-confirm'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _understood,
                onChanged: (value) =>
                    setState(() => _understood = value ?? false),
                title: Text(
                  _bulk
                      ? 'I understand these ${widget.users.length} accounts '
                            'will be deleted permanently.'
                      : 'I understand this account will be deleted '
                            'permanently.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('deletion-submit'),
          style: FilledButton.styleFrom(backgroundColor: kAdminDanger),
          onPressed: _valid
              ? () => Navigator.pop(
                  context,
                  DeletionRequest(
                    reason: _reason!,
                    detail: _detail.text.trim(),
                    perUserReasons: _perUser
                        ? Map.of(_perUserReasons)
                        : const {},
                  ),
                )
              : null,
          icon: const Icon(Icons.delete_forever_rounded),
          label: Text(
            _bulk ? 'Delete ${widget.users.length} accounts' : 'Delete account',
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kAdminCanvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: kAdminTextMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kAdminText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Runs a bulk deletion in server-sized chunks, showing progress and then
/// a success/failure report. Returns the combined outcome.
Future<BulkDeletionOutcome?> runBulkDeletion(
  BuildContext context, {
  required UserAdminGateway gateway,
  required List<ManagedUser> users,
  required DeletionRequest request,
}) {
  return showDialog<BulkDeletionOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _BulkProgressDialog(gateway: gateway, users: users, request: request),
  );
}

class _BulkProgressDialog extends StatefulWidget {
  const _BulkProgressDialog({
    required this.gateway,
    required this.users,
    required this.request,
  });

  final UserAdminGateway gateway;
  final List<ManagedUser> users;
  final DeletionRequest request;

  @override
  State<_BulkProgressDialog> createState() => _BulkProgressDialogState();
}

class _BulkProgressDialogState extends State<_BulkProgressDialog> {
  final List<DeletionOutcome> _results = [];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final ids = widget.users.map((u) => u.id).toList();
    for (var i = 0; i < ids.length; i += UserManagementService.maxBulkPerCall) {
      final chunk = ids.sublist(
        i,
        (i + UserManagementService.maxBulkPerCall).clamp(0, ids.length),
      );
      BulkDeletionOutcome outcome;
      try {
        outcome = await widget.gateway.deleteUsers(
          chunk,
          reason: widget.request.reason,
          detail: widget.request.detail,
          perUserReasons: {
            for (final id in chunk)
              if (widget.request.perUserReasons[id] != null)
                id: widget.request.perUserReasons[id]!,
          },
        );
      } catch (error) {
        outcome = BulkDeletionOutcome([
          for (final id in chunk)
            DeletionOutcome(
              uid: id,
              status: 'failed',
              message: 'Network or server error. Try again.',
            ),
        ]);
      }
      if (!mounted) return;
      setState(() => _results.addAll(outcome.results));
    }
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.users.length;
    final ok = _results.where((r) => r.succeeded).length;
    final failed = _results.length - ok;
    final names = {for (final u in widget.users) u.id: u.displayName};
    final failures = _results.where((r) => !r.succeeded).toList();
    return AlertDialog(
      title: Text(_done ? 'Bulk deletion finished' : 'Deleting accounts…'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              key: const Key('bulk-progress'),
              value: total == 0 ? 1 : _results.length / total,
              color: kAdminBrand,
              backgroundColor: kAdminBorder,
            ),
            const SizedBox(height: 10),
            Text('${_results.length} of $total processed'),
            const SizedBox(height: 6),
            Text(
              '$ok deleted · $failed failed',
              key: const Key('bulk-counts'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (failures.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Failures'),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final failure in failures)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.error_outline_rounded,
                          color: kAdminDanger,
                        ),
                        title: Text(names[failure.uid] ?? failure.uid),
                        subtitle: Text(failure.description),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_done)
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, BulkDeletionOutcome(_results)),
            child: const Text('Close'),
          ),
      ],
    );
  }
}

/// Asks for a confirmation with an optional free-text reason. Returns the
/// reason ('' when [askReason] is false) or null when cancelled. The dialog
/// owns its text controller, so it is never used after being disposed.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool askReason = true,
  String reasonLabel = 'Reason (required)',
  bool danger = false,
  Key? fieldKey,
  Key? confirmKey,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      askReason: askReason,
      reasonLabel: reasonLabel,
      danger: danger,
      fieldKey: fieldKey,
      confirmKey: confirmKey,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.askReason,
    required this.reasonLabel,
    required this.danger,
    this.fieldKey,
    this.confirmKey,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool askReason;
  final String reasonLabel;
  final bool danger;
  final Key? fieldKey;
  final Key? confirmKey;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.message),
              if (widget.askReason) ...[
                const SizedBox(height: 12),
                TextField(
                  key: widget.fieldKey,
                  controller: _controller,
                  autofocus: true,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: widget.reasonLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: widget.confirmKey,
          style: widget.danger
              ? FilledButton.styleFrom(backgroundColor: kAdminDanger)
              : null,
          onPressed: () {
            final reason = _controller.text.trim();
            if (widget.askReason && reason.isEmpty) return;
            Navigator.pop(context, reason);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
