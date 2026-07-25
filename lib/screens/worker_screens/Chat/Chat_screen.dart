import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/worker_screens/Chat/WorkerChatDetailScreen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF14B8A6);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _danger = Color(0xFFDC2626);

  final TextEditingController _searchController = TextEditingController();

  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
  _customerCache = {};

  String _searchQuery = '';
  WorkerChatFilter _selectedFilter = WorkerChatFilter.all;

  String? get _workerId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      if (!mounted) return;

      final value = _searchController.text.trim().toLowerCase();

      if (value != _searchQuery) {
        setState(() => _searchQuery = value);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workerId = _workerId;

    if (workerId == null) {
      return const Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Center(
            child: Text(
              'Please login again.',
              style: TextStyle(
                color: _textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: const WorkerBottomBar(selectedIndex: 3),
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: _ambientCircle(size: 330, color: _primary.withOpacity(0.09)),
          ),
          Positioned(
            bottom: -170,
            left: -145,
            child: _ambientCircle(
              size: 360,
              color: _secondary.withOpacity(0.06),
            ),
          ),
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: _buildChatStream(workerId),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatStream(String workerId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('workerId', isEqualTo: workerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingScreen();
        }

        if (snapshot.hasError) {
          return _errorScreen(snapshot.error.toString());
        }

        final documents = snapshot.data?.docs ?? [];

        final chats = _prepareUniqueChats(documents);

        final totalUnread = chats.fold<int>(
          0,
          (total, document) => total + _readUnreadCount(document.data()),
        );

        final filteredChats = _applyFilter(chats);

        return RefreshIndicator(
          color: _primary,
          onRefresh: () async {
            _customerCache.clear();

            await Future<void>.delayed(const Duration(milliseconds: 450));

            if (mounted) {
              setState(() {});
            }
          },
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 38),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _header(totalChats: chats.length, totalUnread: totalUnread),
                    const SizedBox(height: 20),
                    _heroCard(
                      totalChats: chats.length,
                      totalUnread: totalUnread,
                    ),
                    const SizedBox(height: 18),
                    _searchField(),
                    const SizedBox(height: 14),
                    _filterChips(
                      totalChats: chats.length,
                      unreadChats: chats
                          .where(
                            (document) => _readUnreadCount(document.data()) > 0,
                          )
                          .length,
                    ),
                    const SizedBox(height: 20),
                    _sectionHeader(count: filteredChats.length),
                    const SizedBox(height: 13),
                    if (filteredChats.isEmpty)
                      _emptyState(
                        isFiltered:
                            _searchQuery.isNotEmpty ||
                            _selectedFilter != WorkerChatFilter.all,
                      )
                    else
                      ...filteredChats.map((document) {
                        final data = document.data();

                        return _buildCustomerChat(
                          chatDocument: document,
                          chatData: data,
                          customerId:
                              data['customerId']?.toString().trim() ?? '',
                        );
                      }),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _prepareUniqueChats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final uniqueChats = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    for (final document in documents) {
      final data = document.data();

      if (data['archivedByWorker'] == true) continue;

      final customerId = data['customerId']?.toString().trim() ?? '';

      if (customerId.isEmpty) continue;

      final existing = uniqueChats[customerId];

      if (existing == null ||
          _getChatTime(data).isAfter(_getChatTime(existing.data()))) {
        uniqueChats[customerId] = document;
      }
    }

    final chats = uniqueChats.values.toList();

    chats.sort(
      (a, b) => _getChatTime(b.data()).compareTo(_getChatTime(a.data())),
    );

    return chats;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilter(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> chats,
  ) {
    switch (_selectedFilter) {
      case WorkerChatFilter.unread:
        return chats
            .where((document) => _readUnreadCount(document.data()) > 0)
            .toList();

      case WorkerChatFilter.active:
        return chats.where((document) {
          final status =
              document.data()['status']?.toString().toLowerCase() ?? '';

          return status != 'completed' && status != 'closed';
        }).toList();

      case WorkerChatFilter.all:
        return chats;
    }
  }

  Widget _header({required int totalChats, required int totalUnread}) {
    return Row(
      children: [
        Container(
          height: 50,
          width: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_primary, _secondary]),
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: const Icon(Icons.forum_rounded, color: Colors.white, size: 25),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Messages',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.45,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Chat with your customers',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: totalUnread > 0 ? _primary.withOpacity(0.10) : _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: totalUnread > 0 ? _primary.withOpacity(0.20) : _border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                totalUnread > 0
                    ? Icons.mark_chat_unread_rounded
                    : Icons.done_all_rounded,
                color: totalUnread > 0 ? _primary : _textSecondary,
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                totalUnread > 0 ? '$totalUnread unseen' : '$totalChats chats',
                style: TextStyle(
                  color: totalUnread > 0 ? _primary : _textSecondary,
                  fontSize: 9.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroCard({required int totalChats, required int totalUnread}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.24),
            blurRadius: 28,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -55,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'WORKER INBOX',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      totalUnread > 0
                          ? '$totalUnread unseen messages'
                          : 'Stay connected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.55,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      totalChats == 0
                          ? 'Customer conversations will appear here.'
                          : 'Manage $totalChats customer conversations and job updates.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 10.8,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                height: 90,
                width: 78,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                    if (totalUnread > 0)
                      Positioned(
                        top: 17,
                        right: 13,
                        child: _unreadBadge(totalUnread, small: true),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Search customer, service or message...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10.7,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 21,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: _textSecondary,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  Widget _filterChips({required int totalChats, required int unreadChats}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _filterChip(
            filter: WorkerChatFilter.all,
            label: 'All',
            count: totalChats,
            icon: Icons.forum_outlined,
          ),
          const SizedBox(width: 9),
          _filterChip(
            filter: WorkerChatFilter.unread,
            label: 'Unseen',
            count: unreadChats,
            icon: Icons.mark_chat_unread_outlined,
          ),
          const SizedBox(width: 9),
          _filterChip(
            filter: WorkerChatFilter.active,
            label: 'Active jobs',
            icon: Icons.work_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required WorkerChatFilter filter,
    required String label,
    required IconData icon,
    int? count,
  }) {
    final selected = _selectedFilter == filter;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          setState(() {
            _selectedFilter = filter;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? _primary : _surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: selected ? _primary : _border),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _primary.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : _textSecondary,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : _textPrimary,
                  fontSize: 9.7,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 19),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withOpacity(0.18)
                        : _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? Colors.white : _primary,
                      fontSize: 7.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({required int count}) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent conversations',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Latest customer messages and job updates',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 9.9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            '$count shown',
            style: const TextStyle(
              color: _primary,
              fontSize: 9.1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerChat({
    required QueryDocumentSnapshot<Map<String, dynamic>> chatDocument,
    required Map<String, dynamic> chatData,
    required String customerId,
  }) {
    if (customerId.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _getCustomer(customerId),
      builder: (context, customerSnapshot) {
        if (customerSnapshot.connectionState == ConnectionState.waiting) {
          return _chatLoadingCard();
        }

        if (customerSnapshot.hasError ||
            !customerSnapshot.hasData ||
            !customerSnapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final customer = customerSnapshot.data!.data() ?? {};

        final customerName = _safeString(
          customer['name'],
          fallback: 'Customer',
        );

        final service = _safeString(
          chatData['service'] ?? chatData['category'],
          fallback: 'Service request',
        );

        final lastMessage = _formatLastMessage(chatData);

        final searchableText = '$customerName $service $lastMessage'
            .toLowerCase();

        if (_searchQuery.isNotEmpty && !searchableText.contains(_searchQuery)) {
          return const SizedBox.shrink();
        }

        return _professionalChatTile(
          chatId: chatDocument.id,
          chatData: chatData,
          customer: customer,
          customerId: customerId,
          customerName: customerName,
          service: service,
          lastMessage: lastMessage,
        );
      },
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getCustomer(
    String customerId,
  ) {
    return _customerCache.putIfAbsent(
      customerId,
      () =>
          FirebaseFirestore.instance.collection('users').doc(customerId).get(),
    );
  }

  Widget _professionalChatTile({
    required String chatId,
    required Map<String, dynamic> chatData,
    required Map<String, dynamic> customer,
    required String customerId,
    required String customerName,
    required String service,
    required String lastMessage,
  }) {
    final unreadCount = _readUnreadCount(chatData);

    final hasUnread = unreadCount > 0;

    final isOnline = customer['isOnline'] == true;

    final profileImage =
        customer['profileImage']?.toString() ??
        customer['profileImageUrl']?.toString() ??
        customer['imageUrl']?.toString() ??
        '';

    final lastMessageTime = _getChatTime(chatData);

    final lastSenderId =
        chatData['lastMessageSenderId']?.toString() ??
        chatData['lastSenderId']?.toString() ??
        '';

    final seen = chatData['lastMessageSeen'] == true;

    return Dismissible(
      key: ValueKey(chatId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _showArchiveDialog(),
      onDismissed: (_) async {
        await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          'archivedByWorker': true,
          'archivedAtWorker': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          _showMessage('Conversation archived.');
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.only(right: 22),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: _danger,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Archive',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.4,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.archive_outlined, color: Colors.white, size: 22),
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            if (hasUnread) {
              await FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .set({
                    'workerUnreadCount': 0,
                    'unreadCountWorker': 0,
                  }, SetOptions(merge: true));
            }

            if (!mounted) return;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkerChatDetailScreen(
                  chatId: chatId,
                  customerId: customerId,
                  customerName: customerName,
                  service: service,
                ),
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 13),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: hasUnread ? const Color(0xFFF0FDF4) : _surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: hasUnread ? _primary.withOpacity(0.28) : _border,
                width: hasUnread ? 1.2 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x070F172A),
                  blurRadius: 15,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                _customerAvatar(
                  profileImage: profileImage,
                  customerName: customerName,
                  isOnline: isOnline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 13.7,
                                fontWeight: hasUnread
                                    ? FontWeight.w900
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatChatTime(lastMessageTime),
                            style: TextStyle(
                              color: hasUnread ? _primary : _textSecondary,
                              fontSize: 8.7,
                              fontWeight: hasUnread
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxWidth: 155),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              service,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 8.4,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            height: 7,
                            width: 7,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? _primary
                                  : const Color(0xFFCBD5E1),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 8.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (lastSenderId == _workerId) ...[
                            Icon(
                              seen
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                              size: 14,
                              color: seen
                                  ? const Color(0xFF2563EB)
                                  : _textSecondary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: hasUnread
                                    ? _textPrimary
                                    : _textSecondary,
                                fontSize: 10.5,
                                fontWeight: hasUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 9),
                            _unreadBadge(unreadCount),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _unreadBadge(int count, {bool small = false}) {
    final label = count > 99 ? '99+' : '$count';

    return Container(
      height: small ? 22 : 24,
      constraints: BoxConstraints(minWidth: small ? 22 : 24),
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 7),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(20),
        border: small ? Border.all(color: Colors.white, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 8 : 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _customerAvatar({
    required String profileImage,
    required String customerName,
    required bool isOnline,
  }) {
    final fallback = Center(
      child: Text(
        _initials(customerName),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_primary, _secondary]),
            borderRadius: BorderRadius.circular(19),
          ),
          clipBehavior: Clip.antiAlias,
          child: profileImage.trim().isEmpty
              ? fallback
              : Image.network(
                  profileImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                ),
        ),
        Positioned(
          right: -3,
          bottom: -3,
          child: Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              color: isOnline ? _primary : const Color(0xFF94A3B8),
              shape: BoxShape.circle,
              border: Border.all(color: _surface, width: 3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chatLoadingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          CircleAvatar(radius: 28, backgroundColor: Color(0xFFE8EDF4)),
          SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(
              minHeight: 5,
              color: _primary,
              backgroundColor: Color(0xFFE2E8F0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({required bool isFiltered}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 30),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            height: 76,
            width: 76,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.09),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              isFiltered
                  ? Icons.search_off_rounded
                  : Icons.chat_bubble_outline_rounded,
              color: _primary,
              size: 37,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            isFiltered ? 'No matching conversations' : 'No conversations yet',
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isFiltered
                ? 'Try another search or reset the selected filter.'
                : 'Customer conversations will appear here when a job chat starts.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 10.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingScreen() {
    return const Center(child: CircularProgressIndicator(color: _primary));
  }

  Widget _errorScreen(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _danger, size: 48),
            const SizedBox(height: 14),
            const Text(
              'Unable to load conversations',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  int _readUnreadCount(Map<String, dynamic> data) {
    final value = data['workerUnreadCount'] ?? data['unreadCountWorker'] ?? 0;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  String _safeString(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return fallback;
    }

    return text;
  }

  String _formatLastMessage(Map<String, dynamic> chatData) {
    final type = _safeString(
      chatData['lastMessageType'],
      fallback: 'text',
    ).toLowerCase();

    final message = _safeString(chatData['lastMessage'], fallback: '');

    switch (type) {
      case 'image':
        return '📷 Photo';
      case 'audio':
        return '🎤 Voice message';
      case 'video':
        return '🎥 Video';
      case 'file':
      case 'document':
        return '📄 Document';
      case 'location':
        return '📍 Location';
      case 'job':
        return '🧰 Job details';
      default:
        return message.isEmpty
            ? 'Start a conversation'
            : message.replaceAll(RegExp(r'\s+'), ' ');
    }
  }

  DateTime _getChatTime(Map<String, dynamic> data) {
    final timestamp =
        data['lastMessageTime'] ?? data['updatedAt'] ?? data['createdAt'];

    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }

    if (timestamp is DateTime) {
      return timestamp;
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatChatTime(DateTime dateTime) {
    if (dateTime.millisecondsSinceEpoch == 0) {
      return '';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final difference = today.difference(date).inDays;

    if (difference == 0) {
      final hour = dateTime.hour == 0
          ? 12
          : dateTime.hour > 12
          ? dateTime.hour - 12
          : dateTime.hour;

      final minute = dateTime.minute.toString().padLeft(2, '0');

      final period = dateTime.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    }

    if (difference == 1) {
      return 'Yesterday';
    }

    if (difference < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      return days[dateTime.weekday - 1];
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'C';

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Future<bool> _showArchiveDialog() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.archive_outlined, color: _danger, size: 38),
              const SizedBox(height: 12),
              const Text(
                'Archive conversation?',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This chat will be hidden without deleting its messages.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary, fontSize: 10.5),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Archive'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          backgroundColor: _textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(message),
        ),
      );
  }

  Widget _ambientCircle({required double size, required Color color}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

enum WorkerChatFilter { all, unread, active }
