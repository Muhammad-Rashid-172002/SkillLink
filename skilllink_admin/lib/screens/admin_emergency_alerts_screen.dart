import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skilllink_admin/services/admin_emergency_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminEmergencyAlertsScreen extends StatefulWidget {
  const AdminEmergencyAlertsScreen({super.key});

  @override
  State<AdminEmergencyAlertsScreen> createState() =>
      _AdminEmergencyAlertsScreenState();
}

class _AdminEmergencyAlertsScreenState
    extends State<AdminEmergencyAlertsScreen> {
  static const _danger = Color(0xFFDC2626);
  static const _dangerDark = Color(0xFF991B1B);
  static const _warning = Color(0xFFD97706);
  static const _success = Color(0xFF059669);
  static const _primary = Color(0xFF2563EB);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  final AdminEmergencyService _service = AdminEmergencyService();
  final TextEditingController _searchController = TextEditingController();

  String _filter = 'all';
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _service.alertsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _messageState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Emergency alerts load nahi ho sake',
                  subtitle: '${snapshot.error}',
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _danger),
                );
              }

              final all = snapshot.data!.docs;
              final query = _searchController.text.trim().toLowerCase();
              final filtered = all.where((doc) {
                final data = doc.data();
                final status = _textValue(data['status']).toLowerCase();
                final matchesFilter = _filter == 'all' || status == _filter;
                if (!matchesFilter) return false;
                if (query.isEmpty) return true;

                final haystack = [
                  doc.id,
                  data['raisedByName'],
                  data['serviceTitle'],
                  data['serviceCategory'],
                  data['reason'],
                  data['jobAddress'],
                  data['requestId'],
                ].map(_textValue).join(' ').toLowerCase();

                return haystack.contains(query);
              }).toList();

              final active = all
                  .where((d) => _statusOf(d.data()) == 'active')
                  .length;
              final investigating = all
                  .where((d) => _statusOf(d.data()) == 'investigating')
                  .length;
              final resolved = all
                  .where((d) => _statusOf(d.data()) == 'resolved')
                  .length;
              final falseAlarm = all
                  .where((d) => _statusOf(d.data()) == 'false_alarm')
                  .length;

              return RefreshIndicator(
                color: _danger,
                onRefresh: () async {
                  await Future<void>.delayed(const Duration(milliseconds: 450));
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(28),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _hero(active),
                          const SizedBox(height: 22),
                          _statsGrid(
                            total: all.length,
                            active: active,
                            investigating: investigating,
                            resolved: resolved,
                            falseAlarm: falseAlarm,
                          ),
                          const SizedBox(height: 22),
                          _toolbar(),
                          const SizedBox(height: 18),
                          if (filtered.isEmpty)
                            _emptyState()
                          else
                            ...filtered.map(_alertCard),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withOpacity(0.18),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(color: _danger),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hero(int active) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_dangerDark, _danger, Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _danger.withOpacity(0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -35,
            child: Icon(
              Icons.sos_rounded,
              size: 150,
              color: Colors.white.withOpacity(0.09),
            ),
          ),
          Row(
            children: [
              Container(
                height: 68,
                width: 68,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: const Icon(
                  Icons.emergency_share_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Control Center',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      active == 0
                          ? 'No active SOS alert right now.'
                          : '$active active SOS ${active == 1 ? 'alert needs' : 'alerts need'} immediate attention.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.84),
                        fontSize: 12.5,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$active ACTIVE',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsGrid({
    required int total,
    required int active,
    required int investigating,
    required int resolved,
    required int falseAlarm,
  }) {
    final items = [
      _StatData(
        'Total Alerts',
        total,
        Icons.notifications_active_rounded,
        _primary,
      ),
      _StatData('Active SOS', active, Icons.sos_rounded, _danger),
      _StatData(
        'Investigating',
        investigating,
        Icons.manage_search_rounded,
        _warning,
      ),
      _StatData('Resolved', resolved, Icons.verified_rounded, _success),
      _StatData('False Alarm', falseAlarm, Icons.report_off_rounded, _muted),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 5
            : constraints.maxWidth >= 760
            ? 3
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items
              .map((item) => SizedBox(width: width, child: _statCard(item)))
              .toList(),
        );
      },
    );
  }

  Widget _statCard(_StatData item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(item.icon, color: item.color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.value}',
                  style: GoogleFonts.inter(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
                Text(
                  item.title,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search name, job, reason or request ID...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          );

          final filter = DropdownButtonFormField<String>(
            value: _filter,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All alerts')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(
                value: 'investigating',
                child: Text('Investigating'),
              ),
              DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
              DropdownMenuItem(
                value: 'false_alarm',
                child: Text('False alarm'),
              ),
            ],
            onChanged: (value) => setState(() => _filter = value ?? 'all'),
          );

          if (constraints.maxWidth < 720) {
            return Column(
              children: [search, const SizedBox(height: 12), filter],
            );
          }

          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 14),
              SizedBox(width: 220, child: filter),
            ],
          );
        },
      ),
    );
  }

  Widget _alertCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = _statusOf(data);
    final design = _statusDesign(status);
    final title = _fallback(data['serviceTitle'], 'Emergency alert');
    final person = _fallback(data['raisedByName'], 'SkillNova user');
    final role = _fallback(data['raisedByRole'], 'user');
    final reason = _fallback(data['reason'], 'Emergency assistance required');
    final address = _fallback(data['jobAddress'], 'Location unavailable');
    final time = _formatTimestamp(data['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: status == 'active' ? _danger.withOpacity(0.35) : _border,
          width: status == 'active' ? 1.4 : 1,
        ),
        boxShadow: status == 'active'
            ? [
                BoxShadow(
                  color: _danger.withOpacity(0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: design.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(design.icon, color: design.color, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$person • ${role.replaceAll('_', ' ')} • $time',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(status, design),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _infoRow(
                  Icons.warning_amber_rounded,
                  'Reason',
                  reason,
                  _danger,
                ),
                const SizedBox(height: 10),
                _infoRow(
                  Icons.location_on_outlined,
                  'Location',
                  address,
                  _primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final buttons = <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _openMaps(data),
                  icon: const Icon(Icons.map_outlined, size: 17),
                  label: const Text('Open Maps'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showDetails(doc.id, data),
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  label: const Text('View Details'),
                ),
                if (status == 'active')
                  ElevatedButton.icon(
                    onPressed: () => _markInvestigating(doc.id),
                    icon: const Icon(Icons.manage_search_rounded, size: 17),
                    label: const Text('Investigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _warning,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (status == 'active' || status == 'investigating')
                  ElevatedButton.icon(
                    onPressed: () => _showResolutionDialog(doc.id, data),
                    icon: const Icon(Icons.task_alt_rounded, size: 17),
                    label: const Text('Resolve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _success,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ];

              return Wrap(spacing: 10, runSpacing: 10, children: buttons);
            },
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String status, _StatusDesign design) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: design.color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        design.label,
        style: GoogleFonts.inter(
          color: design.color,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 9),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: _muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: _text,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              color: _success.withOpacity(0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: _success,
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No emergency alerts found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Selected filter ya search ke mutabiq koi alert available nahi hai.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _messageState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: _danger),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markInvestigating(String alertId) async {
    await _runAction(
      () => _service.markInvestigating(alertId: alertId),
      success: 'Alert marked as investigating.',
    );
  }

  Future<void> _showResolutionDialog(
    String alertId,
    Map<String, dynamic> data,
  ) async {
    final controller = TextEditingController();
    bool falseAlarm = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('Close emergency alert'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Resolution note',
                      hintText: 'Describe action taken by admin...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: falseAlarm,
                    onChanged: (value) =>
                        setDialogState(() => falseAlarm = value ?? false),
                    title: const Text('Mark as false alarm'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isEmpty) return;
                  Navigator.pop(dialogContext, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: falseAlarm ? _muted : _success,
                  foregroundColor: Colors.white,
                ),
                child: Text(falseAlarm ? 'Mark False Alarm' : 'Resolve Alert'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    await _runAction(
      () => _service.resolveAlert(
        alertId: alertId,
        requestId: _textValue(data['requestId']),
        resolution: controller.text,
        falseAlarm: falseAlarm,
      ),
      success: falseAlarm
          ? 'Alert marked as false alarm.'
          : 'Emergency alert resolved.',
    );
  }

  Future<void> _showDetails(String alertId, Map<String, dynamic> data) async {
    final customerId = _textValue(data['customerId']);
    final workerId = _textValue(data['workerId']);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<Map<String, Map<String, dynamic>>>(
              future: _service.loadRelatedUsers(
                customerId: customerId,
                workerId: workerId,
              ),
              builder: (context, snapshot) {
                final customer =
                    snapshot.data?['customer'] ?? const <String, dynamic>{};
                final worker =
                    snapshot.data?['worker'] ?? const <String, dynamic>{};

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: _danger.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.sos_rounded,
                              color: _danger,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Emergency Alert Details',
                                  style: GoogleFonts.inter(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: _text,
                                  ),
                                ),
                                Text(
                                  'Alert ID: $alertId',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _detailTile(
                        'Reason',
                        _fallback(data['reason'], 'Not provided'),
                      ),
                      _detailTile(
                        'Service',
                        _fallback(data['serviceTitle'], 'Service request'),
                      ),
                      _detailTile(
                        'Request ID',
                        _fallback(data['requestId'], 'Unavailable'),
                      ),
                      _detailTile(
                        'Job status',
                        _fallback(data['jobStatus'], 'Unknown'),
                      ),
                      _detailTile(
                        'Address',
                        _fallback(data['jobAddress'], 'Unavailable'),
                      ),
                      _detailTile(
                        'Raised by',
                        _fallback(data['raisedByName'], 'Unknown user'),
                      ),
                      const SizedBox(height: 12),
                      _personPanel('Customer', customer, customerId),
                      const SizedBox(height: 12),
                      _personPanel('Worker', worker, workerId),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _openMaps(data),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Open Maps'),
                          ),
                          if (_phoneOf(customer).isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () => _call(_phoneOf(customer)),
                              icon: const Icon(Icons.call_outlined),
                              label: const Text('Call Customer'),
                            ),
                          if (_phoneOf(worker).isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () => _call(_phoneOf(worker)),
                              icon: const Icon(Icons.call_outlined),
                              label: const Text('Call Worker'),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: _text,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personPanel(String title, Map<String, dynamic> data, String id) {
    final name = _fallback(data['name'] ?? data['fullName'], title);
    final phone = _phoneOf(data);
    final email = _fallback(data['email'], 'Email unavailable');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _primary.withOpacity(0.10),
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title: $name',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  phone.isEmpty ? email : '$phone • $email',
                  style: GoogleFonts.inter(fontSize: 10, color: _muted),
                ),
                Text(
                  'UID: $id',
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMaps(Map<String, dynamic> data) async {
    final direct = _textValue(data['mapsUrl']);
    final lat = data['latitude'];
    final lng = data['longitude'];
    final url = direct.isNotEmpty
        ? direct
        : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Google Maps open nahi ho saka.', error: true);
    }
  }

  Future<void> _call(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: clean);
    if (!await launchUrl(uri)) {
      _snack('Phone dialer open nahi ho saka.', error: true);
    }
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String success,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _snack(success);
    } catch (error) {
      if (mounted) _snack(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? _danger : _success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _phoneOf(Map<String, dynamic> data) {
    for (final key in ['phone', 'phoneNumber', 'mobile']) {
      final value = _textValue(data[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _statusOf(Map<String, dynamic> data) {
    return _textValue(data['status']).toLowerCase().replaceAll(' ', '_');
  }

  _StatusDesign _statusDesign(String status) {
    switch (status) {
      case 'active':
        return const _StatusDesign('ACTIVE SOS', _danger, Icons.sos_rounded);
      case 'investigating':
        return const _StatusDesign(
          'INVESTIGATING',
          _warning,
          Icons.manage_search_rounded,
        );
      case 'resolved':
        return const _StatusDesign(
          'RESOLVED',
          _success,
          Icons.verified_rounded,
        );
      case 'false_alarm':
        return const _StatusDesign(
          'FALSE ALARM',
          _muted,
          Icons.report_off_rounded,
        );
      default:
        return const _StatusDesign(
          'UNKNOWN',
          _primary,
          Icons.help_outline_rounded,
        );
    }
  }

  String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) return 'Just now';
    final date = value.toDate().toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _fallback(dynamic value, String fallback) {
    final text = _textValue(value);
    return text.isEmpty ? fallback : text;
  }

  String _textValue(dynamic value) => value?.toString().trim() ?? '';
}

class _StatusDesign {
  const _StatusDesign(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
}

class _StatData {
  const _StatData(this.title, this.value, this.icon, this.color);
  final String title;
  final int value;
  final IconData icon;
  final Color color;
}
