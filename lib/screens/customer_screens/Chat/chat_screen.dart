import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';

import 'chat_components.dart';
import 'chat_models.dart';
import 'customer_chat_repository.dart';
import 'customer_chat_service.dart';

class CustomerChatsScreen extends StatefulWidget {
  const CustomerChatsScreen({
    super.key,
    this.dataSource,
    this.onOpenConversation,
  });

  final CustomerChatDataSource? dataSource;
  final ValueChanged<CustomerConversation>? onOpenConversation;

  @override
  State<CustomerChatsScreen> createState() => _CustomerChatsScreenState();
}

class _CustomerChatsScreenState extends State<CustomerChatsScreen>
    with SingleTickerProviderStateMixin {
  late final CustomerChatDataSource _dataSource;
  late final Stream<List<CustomerConversation>> _conversationStream;
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? FirebaseCustomerChatRepository();
    _conversationStream = _dataSource.watchConversations();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dataSource.customerId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SkillNovaSpacing.md,
                SkillNovaSpacing.md,
                SkillNovaSpacing.md,
                SkillNovaSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Messages', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Stay connected with your professionals',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: SkillNovaSpacing.md),
                  ConversationSearchField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                  const SizedBox(height: SkillNovaSpacing.sm),
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Conversations'),
                      Tab(text: 'Archived'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<CustomerConversation>>(
                stream: _conversationStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const _ConversationLoadingState();
                  }
                  if (snapshot.hasError) {
                    return _ConversationState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Messages could not be loaded',
                      description: 'Check your connection and try again.',
                      actionLabel: 'Try again',
                      onAction: _dataSource.refreshConversations,
                    );
                  }
                  final conversations = snapshot.data ?? const [];
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _conversationList(
                        conversations.where((item) => !item.archived).toList(),
                        archived: false,
                      ),
                      _conversationList(
                        conversations.where((item) => item.archived).toList(),
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
    List<CustomerConversation> conversations, {
    required bool archived,
  }) {
    final results = conversations
        .where((item) => item.matches(_query))
        .toList();
    if (results.isEmpty) {
      if (_query.trim().isNotEmpty) {
        return const _ConversationState(
          icon: Icons.search_off_rounded,
          title: 'No matching conversations',
          description: 'Try another professional, service, or message.',
        );
      }
      return _ConversationState(
        icon: archived ? Icons.archive_outlined : Icons.forum_outlined,
        title: archived ? 'No archived messages' : 'No messages yet',
        description: archived
            ? 'Conversations you archive will appear here.'
            : 'Your conversations with professionals will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _dataSource.refreshConversations,
      child: ListView.separated(
        key: PageStorageKey(archived ? 'archived-chats' : 'active-chats'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          SkillNovaSpacing.md,
          SkillNovaSpacing.sm,
          SkillNovaSpacing.md,
          100,
        ),
        itemCount: results.length,
        separatorBuilder: (_, _) => const SizedBox(height: SkillNovaSpacing.sm),
        itemBuilder: (context, index) {
          final conversation = results[index];
          return ConversationTile(
            conversation: conversation,
            onTap: () => _open(conversation),
            onArchive: () => _toggleArchive(conversation),
          );
        },
      ),
    );
  }

  Future<void> _open(CustomerConversation conversation) async {
    FocusScope.of(context).unfocus();
    if (widget.onOpenConversation != null) {
      widget.onOpenConversation!(conversation);
      return;
    }
    final destination = CustomerChatDestination(
      chatId: conversation.id,
      workerId: conversation.workerId,
      workerName: conversation.workerName,
      workerSkill: conversation.service,
      workerPhone: conversation.workerPhone,
      workerImageUrl: conversation.workerPhoto,
      workerVerified: conversation.workerVerified,
      requestId: conversation.requestId,
    );
    await CustomerChatNavigator.open(context, destination);
  }

  Future<void> _toggleArchive(CustomerConversation conversation) async {
    try {
      await _dataSource.setArchived(conversation.id, !conversation.archived);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            conversation.archived
                ? 'Conversation restored.'
                : 'Conversation archived.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation could not be updated.')),
      );
    }
  }
}

class _ConversationLoadingState extends StatelessWidget {
  const _ConversationLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(SkillNovaSpacing.md),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: SkillNovaSpacing.sm),
      itemBuilder: (_, _) => Container(
        height: 88,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ConversationState extends StatelessWidget {
  const _ConversationState({
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
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SkillNovaSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(SkillNovaRadius.large),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 34),
            ),
            const SizedBox(height: SkillNovaSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SkillNovaSpacing.xs),
            Text(
              description,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: SkillNovaSpacing.md),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
