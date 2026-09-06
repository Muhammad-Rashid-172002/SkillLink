import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';

import 'worker_chat_detail_screen.dart';
import 'worker_chat_models.dart';
import 'worker_chat_repository.dart';

class WorkerMessagesScreen extends StatefulWidget {
  const WorkerMessagesScreen({
    super.key,
    this.dataSource,
    this.onOpenConversation,
  });

  final WorkerChatDataSource? dataSource;
  final ValueChanged<WorkerConversation>? onOpenConversation;

  @override
  State<WorkerMessagesScreen> createState() => _WorkerMessagesScreenState();
}

class _WorkerMessagesScreenState extends State<WorkerMessagesScreen>
    with SingleTickerProviderStateMixin {
  late final WorkerChatDataSource _dataSource;
  late final Stream<List<WorkerConversation>> _conversationsStream;
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? FirebaseWorkerChatRepository();
    _conversationsStream = _dataSource.watchConversations();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_searchChanged);
  }

  void _searchChanged() {
    final value = _searchController.text.trim();
    if (value != _query && mounted) setState(() => _query = value);
  }

  @override
  void dispose() {
    _searchController.removeListener(_searchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const WorkerBottomBar(selectedIndex: 3),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SkillNovaSpacing.md,
                SkillNovaSpacing.md,
                SkillNovaSpacing.md,
                SkillNovaSpacing.sm,
              ),
              child: Text(
                'Messages',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SkillNovaSpacing.md,
              ),
              child: TextField(
                key: const ValueKey('worker-message-search'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search customers, services, or messages',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            const SizedBox(height: SkillNovaSpacing.sm),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Active'),
                Tab(text: 'Archived'),
              ],
            ),
            Expanded(
              child: StreamBuilder<List<WorkerConversation>>(
                stream: _conversationsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _MessagesState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Messages could not be loaded',
                      description: 'Check your connection and try again.',
                      actionLabel: 'Try again',
                      onAction: _refresh,
                    );
                  }
                  final all = snapshot.data ?? const <WorkerConversation>[];
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _conversationList(
                        all.where((item) => !item.archived).toList(),
                        archived: false,
                      ),
                      _conversationList(
                        all.where((item) => item.archived).toList(),
                        archived: true,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conversationList(
    List<WorkerConversation> conversations, {
    required bool archived,
  }) {
    final visible = conversations
        .where((conversation) => conversation.matches(_query))
        .toList(growable: false);
    if (visible.isEmpty) {
      final searching = _query.isNotEmpty;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: ValueKey(
            archived ? 'worker-archived-empty' : 'worker-active-empty',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * .14),
            _MessagesState(
              icon: searching
                  ? Icons.search_off_rounded
                  : archived
                  ? Icons.archive_outlined
                  : Icons.chat_bubble_outline_rounded,
              title: searching
                  ? 'No matching conversations'
                  : archived
                  ? 'No archived conversations'
                  : 'No conversations yet',
              description: searching
                  ? 'Try a customer name, service, or message preview.'
                  : archived
                  ? 'Conversations you archive remain readable here.'
                  : 'Accepted job conversations will appear here.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        key: ValueKey(archived ? 'worker-archived-list' : 'worker-active-list'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          SkillNovaSpacing.md,
          SkillNovaSpacing.sm,
          SkillNovaSpacing.md,
          SkillNovaSpacing.xxl,
        ),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: SkillNovaSpacing.xs),
        itemBuilder: (context, index) {
          final conversation = visible[index];
          return _ConversationCard(
            conversation: conversation,
            onTap: () => _open(conversation),
            onArchiveChanged: () => _setArchived(conversation, !archived),
          );
        },
      ),
    );
  }

  Future<void> _refresh() async {
    try {
      await _dataSource.refreshConversations();
    } catch (_) {
      if (mounted) _showMessage('Messages could not be refreshed.');
    }
  }

  Future<void> _setArchived(
    WorkerConversation conversation,
    bool archived,
  ) async {
    try {
      await _dataSource.setArchived(conversation.id, archived);
      if (mounted) {
        _showMessage(
          archived ? 'Conversation archived.' : 'Conversation restored.',
        );
      }
    } catch (_) {
      if (mounted) _showMessage('The conversation could not be updated.');
    }
  }

  Future<void> _open(WorkerConversation conversation) async {
    final callback = widget.onOpenConversation;
    if (callback != null) {
      callback(conversation);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => WorkerChatDetailV2Screen(
          chatId: conversation.id,
          customerId: conversation.customerId,
          customerName: conversation.customerName,
          service: conversation.service,
          requestId: conversation.requestId,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.onTap,
    required this.onArchiveChanged,
  });

  final WorkerConversation conversation;
  final VoidCallback onTap;
  final VoidCallback onArchiveChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = conversation.unreadCount;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
      ),
      child: InkWell(
        key: ValueKey('worker-conversation-${conversation.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
        child: Padding(
          padding: const EdgeInsets.all(SkillNovaSpacing.sm),
          child: Row(
            children: [
              _CustomerAvatar(
                name: conversation.customerName,
                photoUrl: conversation.customerPhoto,
              ),
              const SizedBox(width: SkillNovaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: unread > 0 ? FontWeight.w800 : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _conversationTime(conversation.updatedAt),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      conversation.service,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.latestPreview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: unread > 0 ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Semantics(
                            label: '$unread unread messages',
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(
                                  SkillNovaRadius.pill,
                                ),
                              ),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                        PopupMenuButton<bool>(
                          tooltip: conversation.archived
                              ? 'Conversation options'
                              : 'Archive conversation',
                          onSelected: (_) => onArchiveChanged(),
                          itemBuilder: (_) => [
                            PopupMenuItem<bool>(
                              value: true,
                              child: Text(
                                conversation.archived ? 'Restore' : 'Archive',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  const _CustomerAvatar({required this.name, required this.photoUrl});

  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Center(
      child: Text(
        _initials(name),
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return Container(
      width: 52,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .10),
        shape: BoxShape.circle,
      ),
      child: photoUrl.isEmpty
          ? fallback
          : Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class _MessagesState extends StatelessWidget {
  const _MessagesState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SkillNovaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: SkillNovaSpacing.sm),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: SkillNovaSpacing.xs),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: SkillNovaSpacing.md),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return 'C';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _conversationTime(DateTime? value) {
  if (value == null) return '';
  final now = DateTime.now();
  if (DateUtils.isSameDay(now, value)) return DateFormat.jm().format(value);
  if (now.difference(value).inDays < 7) return DateFormat.E().format(value);
  return DateFormat.MMMd().format(value);
}
