import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/notification_management_service.dart';

enum NotificationFilter {
  all,
  unread,
  customers,
  workers,
  broadcast,
  archived,
}

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final NotificationManagementService _service =
      NotificationManagementService();
  final TextEditingController _searchController = TextEditingController();

  NotificationFilter _selectedFilter = NotificationFilter.all;
  String _searchQuery = '';
  bool _gridView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ManagedNotification> _filterNotifications(
    List<ManagedNotification> notifications,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    return notifications.where((notification) {
      final matchesSearch = query.isEmpty ||
          notification.title.toLowerCase().contains(query) ||
          notification.message.toLowerCase().contains(query) ||
          notification.targetUserName.toLowerCase().contains(query);

      final matchesFilter = switch (_selectedFilter) {
        NotificationFilter.all => !notification.isArchived,
        NotificationFilter.unread =>
          !notification.isRead && !notification.isArchived,
        NotificationFilter.customers =>
          notification.audience == 'customers' && !notification.isArchived,
        NotificationFilter.workers =>
          notification.audience == 'workers' && !notification.isArchived,
        NotificationFilter.broadcast =>
          notification.audience == 'all' && !notification.isArchived,
        NotificationFilter.archived => notification.isArchived,
      };

      return matchesSearch && matchesFilter;
    }).toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
  }

  Future<void> _showCreateNotificationDialog() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    String audience = 'all';
    String type = 'general';

    final result = await showDialog<_NotificationFormResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 54,
                              width: 54,
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(17),
                              ),
                              child: const Icon(
                                Icons.notifications_active_rounded,
                                color: Color(0xFF16A34A),
                                size: 27,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create Notification',
                                    style: GoogleFonts.inter(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Users ko app notification bhejein.',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: const Color(0xFF64748B),
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
                        const SizedBox(height: 24),
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            labelText: 'Notification title',
                            hintText: 'Example: New feature available',
                            prefixIcon: const Icon(Icons.title_rounded),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: messageController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: 'Message',
                            hintText: 'Notification message likhein...',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: audience,
                                decoration: InputDecoration(
                                  labelText: 'Audience',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('All Users'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'customers',
                                    child: Text('Customers'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'workers',
                                    child: Text('Workers'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setDialogState(() => audience = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: type,
                                decoration: InputDecoration(
                                  labelText: 'Type',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'general',
                                    child: Text('General'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'promotion',
                                    child: Text('Promotion'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'alert',
                                    child: Text('Alert'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'update',
                                    child: Text('App Update'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setDialogState(() => type = value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  final title = titleController.text.trim();
                                  final message = messageController.text.trim();

                                  if (title.isEmpty || message.isEmpty) return;

                                  Navigator.pop(
                                    dialogContext,
                                    _NotificationFormResult(
                                      title: title,
                                      message: message,
                                      audience: audience,
                                      type: type,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.send_rounded),
                                label: const Text('Send notification'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    messageController.dispose();

    if (result == null) return;

    try {
      await _service.createNotification(
        title: result.title,
        message: result.message,
        audience: result.audience,
        type: result.type,
      );

      if (!mounted) return;
      _showMessage('Notification successfully create ho gayi.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Notification create nahi ho saki: $error',
        isError: true,
      );
    }
  }

  Future<void> _toggleRead(ManagedNotification notification) async {
    try {
      await _service.markAsRead(
        notificationId: notification.id,
        isRead: !notification.isRead,
      );

      if (!mounted) return;
      _showMessage(
        notification.isRead
            ? 'Notification unread mark ho gayi.'
            : 'Notification read mark ho gayi.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Notification update nahi ho saki: $error',
        isError: true,
      );
    }
  }

  Future<void> _toggleArchive(ManagedNotification notification) async {
    try {
      if (notification.isArchived) {
        await _service.restoreNotification(notification.id);
      } else {
        await _service.archiveNotification(notification.id);
      }

      if (!mounted) return;
      _showMessage(
        notification.isArchived
            ? 'Notification restore ho gayi.'
            : 'Notification archive ho gayi.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Notification archive update nahi ho saki: $error',
        isError: true,
      );
    }
  }

  Future<void> _deleteNotification(
    ManagedNotification notification,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Delete notification?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'Ye notification Firestore se permanently delete ho jayegi.',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.deleteNotification(notification.id);

      if (!mounted) return;
      _showMessage('Notification delete ho gayi.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Notification delete nahi ho saki: $error',
        isError: true,
      );
    }
  }

  void _showNotificationDetails(ManagedNotification notification) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _NotificationIcon(
                        type: notification.type,
                        size: 58,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              style: GoogleFonts.inter(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _AudienceBadge(
                                  audience: notification.audience,
                                ),
                                _TypeBadge(type: notification.type),
                                _ReadBadge(isRead: notification.isRead),
                              ],
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
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      notification.message,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        height: 1.7,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _InfoTile(
                        icon: Icons.group_outlined,
                        label: 'Audience',
                        value: _audienceLabel(notification.audience),
                      ),
                      _InfoTile(
                        icon: Icons.person_outline_rounded,
                        label: 'Target',
                        value: notification.targetUserName,
                      ),
                      _InfoTile(
                        icon: Icons.calendar_today_outlined,
                        label: 'Created',
                        value: _formatDateTime(notification.createdAt),
                      ),
                      _InfoTile(
                        icon: Icons.inventory_2_outlined,
                        label: 'Status',
                        value: notification.isArchived
                            ? 'Archived'
                            : 'Active',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _toggleArchive(notification);
                          },
                          icon: Icon(
                            notification.isArchived
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                          ),
                          label: Text(
                            notification.isArchived
                                ? 'Restore'
                                : 'Archive',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _toggleRead(notification);
                          },
                          icon: Icon(
                            notification.isRead
                                ? Icons.mark_email_unread_outlined
                                : Icons.mark_email_read_outlined,
                          ),
                          label: Text(
                            notification.isRead
                                ? 'Mark unread'
                                : 'Mark read',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.notificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _NotificationsErrorState(
            message: 'Notifications load nahi ho sake.\n${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF16A34A),
            ),
          );
        }

        final allNotifications = snapshot.data!.docs
            .map(ManagedNotification.fromDocument)
            .toList();

        final filteredNotifications =
            _filterNotifications(allNotifications);

        final activeNotifications = allNotifications
            .where((notification) => !notification.isArchived)
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotificationsHeader(
                total: activeNotifications.length,
                unread: activeNotifications
                    .where((notification) => !notification.isRead)
                    .length,
                broadcasts: activeNotifications
                    .where((notification) => notification.audience == 'all')
                    .length,
                workers: activeNotifications
                    .where(
                      (notification) =>
                          notification.audience == 'workers',
                    )
                    .length,
                onCreate: _showCreateNotificationDialog,
              ),
              const SizedBox(height: 22),
              _NotificationsToolbar(
                controller: _searchController,
                selectedFilter: _selectedFilter,
                resultCount: filteredNotifications.length,
                gridView: _gridView,
                onSearchChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                onFilterChanged: (filter) {
                  setState(() => _selectedFilter = filter);
                },
                onViewChanged: (value) {
                  setState(() => _gridView = value);
                },
              ),
              const SizedBox(height: 18),
              if (filteredNotifications.isEmpty)
                const _EmptyNotificationsState()
              else if (_gridView)
                _NotificationsGrid(
                  notifications: filteredNotifications,
                  onView: _showNotificationDetails,
                  onRead: _toggleRead,
                  onArchive: _toggleArchive,
                  onDelete: _deleteNotification,
                )
              else
                _NotificationsTable(
                  notifications: filteredNotifications,
                  onView: _showNotificationDetails,
                  onRead: _toggleRead,
                  onArchive: _toggleArchive,
                  onDelete: _deleteNotification,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.total,
    required this.unread,
    required this.broadcasts,
    required this.workers,
    required this.onCreate,
  });

  final int total;
  final int unread;
  final int broadcasts;
  final int workers;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _NotificationStatCard(
        title: 'Total Notifications',
        value: '$total',
        icon: Icons.notifications_rounded,
        color: const Color(0xFF2563EB),
      ),
      _NotificationStatCard(
        title: 'Unread',
        value: '$unread',
        icon: Icons.mark_email_unread_rounded,
        color: const Color(0xFFD97706),
      ),
      _NotificationStatCard(
        title: 'Broadcasts',
        value: '$broadcasts',
        icon: Icons.campaign_rounded,
        color: const Color(0xFF7C3AED),
      ),
      _NotificationStatCard(
        title: 'Worker Alerts',
        value: '$workers',
        icon: Icons.engineering_rounded,
        color: const Color(0xFF16A34A),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderTitle(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: _CreateButton(onTap: onCreate),
                  ),
                ],
              );
            }

            return Row(
              children: [
                const Expanded(child: _HeaderTitle()),
                _CreateButton(onTap: onCreate),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 950
                ? 4
                : constraints.maxWidth >= 540
                    ? 2
                    : 1;

            final width =
                (constraints.maxWidth - ((columns - 1) * 14)) / columns;

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: cards
                  .map((card) => SizedBox(width: width, child: card))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notifications',
          style: GoogleFonts.inter(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Manage notifications for customers and workers.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_alert_rounded),
      label: const Text('Create Notification'),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _NotificationStatCard extends StatelessWidget {
  const _NotificationStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
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

class _NotificationsToolbar extends StatelessWidget {
  const _NotificationsToolbar({
    required this.controller,
    required this.selectedFilter,
    required this.resultCount,
    required this.gridView,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onViewChanged,
  });

  final TextEditingController controller;
  final NotificationFilter selectedFilter;
  final int resultCount;
  final bool gridView;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<NotificationFilter> onFilterChanged;
  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 970;

          final search = SizedBox(
            width: compact ? double.infinity : 340,
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search title, message or target...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          controller.clear();
                          onSearchChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF16A34A),
                    width: 1.6,
                  ),
                ),
              ),
            ),
          );

          final filters = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: NotificationFilter.values.map((filter) {
              final selected = selectedFilter == filter;

              return ChoiceChip(
                selected: selected,
                onSelected: (_) => onFilterChanged(filter),
                label: Text(_filterLabel(filter)),
                selectedColor:
                    const Color(0xFF16A34A).withOpacity(0.12),
                backgroundColor: const Color(0xFFF8FAFC),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFE2E8F0),
                ),
                labelStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF64748B),
                ),
              );
            }).toList(),
          );

          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$resultCount notifications',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 12),
              _ViewButton(
                icon: Icons.table_rows_rounded,
                selected: !gridView,
                onTap: () => onViewChanged(false),
              ),
              const SizedBox(width: 6),
              _ViewButton(
                icon: Icons.grid_view_rounded,
                selected: gridView,
                onTap: () => onViewChanged(true),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                search,
                const SizedBox(height: 14),
                filters,
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: controls,
                ),
              ],
            );
          }

          return Row(
            children: [
              search,
              const SizedBox(width: 16),
              Expanded(child: filters),
              const SizedBox(width: 10),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _NotificationsTable extends StatelessWidget {
  const _NotificationsTable({
    required this.notifications,
    required this.onView,
    required this.onRead,
    required this.onArchive,
    required this.onDelete,
  });

  final List<ManagedNotification> notifications;
  final ValueChanged<ManagedNotification> onView;
  final ValueChanged<ManagedNotification> onRead;
  final ValueChanged<ManagedNotification> onArchive;
  final ValueChanged<ManagedNotification> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          dataRowMinHeight: 76,
          dataRowMaxHeight: 92,
          horizontalMargin: 20,
          columnSpacing: 28,
          columns: const [
            DataColumn(label: _TableHeading('NOTIFICATION')),
            DataColumn(label: _TableHeading('AUDIENCE')),
            DataColumn(label: _TableHeading('TYPE')),
            DataColumn(label: _TableHeading('READ STATUS')),
            DataColumn(label: _TableHeading('CREATED')),
            DataColumn(label: _TableHeading('ACTIONS')),
          ],
          rows: notifications.map((notification) {
            return DataRow(
              color: WidgetStateProperty.resolveWith((states) {
                if (!notification.isRead) {
                  return const Color(0xFFF8FFF9);
                }
                return null;
              }),
              cells: [
                DataCell(
                  SizedBox(
                    width: 330,
                    child: Row(
                      children: [
                        _NotificationIcon(
                          type: notification.type,
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: notification.isRead
                                      ? FontWeight.w700
                                      : FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                notification.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  height: 1.35,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  _AudienceBadge(audience: notification.audience),
                ),
                DataCell(_TypeBadge(type: notification.type)),
                DataCell(_ReadBadge(isRead: notification.isRead)),
                DataCell(
                  Text(
                    _formatDate(notification.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
                DataCell(
                  _NotificationActions(
                    notification: notification,
                    onView: onView,
                    onRead: onRead,
                    onArchive: onArchive,
                    onDelete: onDelete,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NotificationsGrid extends StatelessWidget {
  const _NotificationsGrid({
    required this.notifications,
    required this.onView,
    required this.onRead,
    required this.onArchive,
    required this.onDelete,
  });

  final List<ManagedNotification> notifications;
  final ValueChanged<ManagedNotification> onView;
  final ValueChanged<ManagedNotification> onRead;
  final ValueChanged<ManagedNotification> onArchive;
  final ValueChanged<ManagedNotification> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 3
            : constraints.maxWidth >= 760
                ? 2
                : 1;

        final width =
            (constraints.maxWidth - ((columns - 1) * 16)) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: notifications.map((notification) {
            return SizedBox(
              width: width,
              child: _NotificationCard(
                notification: notification,
                onView: onView,
                onRead: onRead,
                onArchive: onArchive,
                onDelete: onDelete,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onView,
    required this.onRead,
    required this.onArchive,
    required this.onDelete,
  });

  final ManagedNotification notification;
  final ValueChanged<ManagedNotification> onView;
  final ValueChanged<ManagedNotification> onRead;
  final ValueChanged<ManagedNotification> onArchive;
  final ValueChanged<ManagedNotification> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: notification.isRead
            ? Colors.white
            : const Color(0xFFF8FFF9),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: notification.isRead
              ? const Color(0xFFE6ECF2)
              : const Color(0xFFBBE4C8),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _NotificationIcon(
                type: notification.type,
                size: 48,
              ),
              const Spacer(),
              _NotificationActions(
                notification: notification,
                onView: onView,
                onRead: onRead,
                onArchive: onArchive,
                onDelete: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            notification.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: notification.isRead
                  ? FontWeight.w800
                  : FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            notification.message,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              height: 1.55,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _AudienceBadge(audience: notification.audience),
              _TypeBadge(type: notification.type),
              _ReadBadge(isRead: notification.isRead),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 7),
              Text(
                _formatDateTime(notification.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => onView(notification),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('View notification'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF16A34A)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationActions extends StatelessWidget {
  const _NotificationActions({
    required this.notification,
    required this.onView,
    required this.onRead,
    required this.onArchive,
    required this.onDelete,
  });

  final ManagedNotification notification;
  final ValueChanged<ManagedNotification> onView;
  final ValueChanged<ManagedNotification> onRead;
  final ValueChanged<ManagedNotification> onArchive;
  final ValueChanged<ManagedNotification> onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Notification actions',
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      onSelected: (value) {
        switch (value) {
          case 'view':
            onView(notification);
            break;
          case 'read':
            onRead(notification);
            break;
          case 'archive':
            onArchive(notification);
            break;
          case 'delete':
            onDelete(notification);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'view',
          child: _ActionMenuItem(
            icon: Icons.visibility_outlined,
            text: 'View details',
          ),
        ),
        PopupMenuItem(
          value: 'read',
          child: _ActionMenuItem(
            icon: notification.isRead
                ? Icons.mark_email_unread_outlined
                : Icons.mark_email_read_outlined,
            text: notification.isRead
                ? 'Mark unread'
                : 'Mark read',
          ),
        ),
        PopupMenuItem(
          value: 'archive',
          child: _ActionMenuItem(
            icon: notification.isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined,
            text: notification.isArchived ? 'Restore' : 'Archive',
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: _ActionMenuItem(
            icon: Icons.delete_outline_rounded,
            text: 'Delete notification',
            danger: true,
          ),
        ),
      ],
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          color: Color(0xFF64748B),
          size: 20,
        ),
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({
    required this.type,
    required this.size,
  });

  final String type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    final icon = _typeIcon(type);

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(size * 0.30),
      ),
      child: Icon(
        icon,
        color: color,
        size: size * 0.47,
      ),
    );
  }
}

class _AudienceBadge extends StatelessWidget {
  const _AudienceBadge({required this.audience});

  final String audience;

  @override
  Widget build(BuildContext context) {
    final color = switch (audience) {
      'workers' => const Color(0xFF16A34A),
      'customers' => const Color(0xFF2563EB),
      _ => const Color(0xFF7C3AED),
    };

    return _Badge(
      text: _audienceLabel(audience).toUpperCase(),
      color: color,
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return _Badge(
      text: _typeLabel(type).toUpperCase(),
      color: _typeColor(type),
    );
  }
}

class _ReadBadge extends StatelessWidget {
  const _ReadBadge({required this.isRead});

  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return _Badge(
      text: isRead ? 'READ' : 'UNREAD',
      color: isRead
          ? const Color(0xFF64748B)
          : const Color(0xFFD97706),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _ActionMenuItem extends StatelessWidget {
  const _ActionMenuItem({
    required this.icon,
    required this.text,
    this.danger = false,
  });

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color =
        danger ? const Color(0xFFDC2626) : const Color(0xFF334155);

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 275,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFF16A34A)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF334155),
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

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF16A34A)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected
                ? const Color(0xFF16A34A)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _TableHeading extends StatelessWidget {
  const _TableHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.7,
        color: const Color(0xFF64748B),
      ),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 70),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 58,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 14),
          Text(
            'No notifications found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Search ya selected filter ke mutabiq koi notification nahi mili.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsErrorState extends StatelessWidget {
  const _NotificationsErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFDA4AF)),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: const Color(0xFF991B1B),
          ),
        ),
      ),
    );
  }
}

class _NotificationFormResult {
  const _NotificationFormResult({
    required this.title,
    required this.message,
    required this.audience,
    required this.type,
  });

  final String title;
  final String message;
  final String audience;
  final String type;
}

String _filterLabel(NotificationFilter filter) {
  switch (filter) {
    case NotificationFilter.all:
      return 'All';
    case NotificationFilter.unread:
      return 'Unread';
    case NotificationFilter.customers:
      return 'Customers';
    case NotificationFilter.workers:
      return 'Workers';
    case NotificationFilter.broadcast:
      return 'Broadcast';
    case NotificationFilter.archived:
      return 'Archived';
  }
}

String _audienceLabel(String audience) {
  switch (audience) {
    case 'workers':
      return 'Workers';
    case 'customers':
      return 'Customers';
    default:
      return 'All Users';
  }
}

String _typeLabel(String type) {
  switch (type) {
    case 'promotion':
      return 'Promotion';
    case 'alert':
      return 'Alert';
    case 'update':
      return 'App Update';
    default:
      return 'General';
  }
}

Color _typeColor(String type) {
  switch (type) {
    case 'promotion':
      return const Color(0xFF7C3AED);
    case 'alert':
      return const Color(0xFFDC2626);
    case 'update':
      return const Color(0xFF2563EB);
    default:
      return const Color(0xFF16A34A);
  }
}

IconData _typeIcon(String type) {
  switch (type) {
    case 'promotion':
      return Icons.local_offer_rounded;
    case 'alert':
      return Icons.warning_amber_rounded;
    case 'update':
      return Icons.system_update_alt_rounded;
    default:
      return Icons.notifications_active_rounded;
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Unknown';
  return DateFormat('dd MMM yyyy').format(date);
}

String _formatDateTime(DateTime? date) {
  if (date == null) return 'Unknown';
  return DateFormat('dd MMM yyyy, hh:mm a').format(date);
}
