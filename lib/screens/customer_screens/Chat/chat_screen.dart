import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_detail_screen.dart';
import 'package:skill_link/screens/customer_screens/bottom_bar/bottom_bar.dart';

class CustomerChatScreen extends StatefulWidget {
  const CustomerChatScreen({super.key});

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      final value = _searchController.text.trim().toLowerCase();

      if (value != _searchQuery && mounted) {
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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _signedOutView();
    }

    final customerId = user.uid;

    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: const CustomerBottomBar(selectedIndex: 3),
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: _ambientCircle(size: 330, color: _primary.withOpacity(0.09)),
          ),
          Positioned(
            bottom: -165,
            left: -135,
            child: _ambientCircle(
              size: 350,
              color: _secondary.withOpacity(0.06),
            ),
          ),
          SafeArea(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('customerId', isEqualTo: customerId)
                  // .orderBy(
                  //   'updatedAt',
                  //   descending: true,
                  // )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _loadingScreen();
                }

                if (snapshot.hasError) {
                  return _errorScreen(snapshot.error.toString());
                }

                final allChats = snapshot.data?.docs ?? [];

                final uniqueChats = _removeDuplicateChats(allChats);

                final unreadTotal = uniqueChats.fold<int>(0, (total, doc) {
                  final data = doc.data();
                  return total + _intValue(data['unreadCountCustomer']);
                });

                return RefreshIndicator(
                  color: _primary,
                  onRefresh: () async {
                    await Future<void>.delayed(
                      const Duration(milliseconds: 500),
                    );
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _header(
                              unreadTotal: unreadTotal,
                              totalChats: uniqueChats.length,
                            ),
                            const SizedBox(height: 20),
                            _heroCard(
                              totalChats: uniqueChats.length,
                              unreadTotal: unreadTotal,
                            ),
                            const SizedBox(height: 18),
                            _searchBar(),
                            const SizedBox(height: 20),
                            _sectionHeader(
                              totalChats: uniqueChats.length,
                              unreadTotal: unreadTotal,
                            ),
                            const SizedBox(height: 13),
                            if (uniqueChats.isEmpty)
                              _emptyState()
                            else
                              ...uniqueChats.map(
                                (chatDoc) => _chatConversationCard(chatDoc),
                              ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _removeDuplicateChats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> chats,
  ) {
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> unique = {};

    for (final chat in chats) {
      final data = chat.data();

      final workerId = (data['workerId'] ?? '').toString();

      if (workerId.isEmpty) continue;

      final currentTime = _dateFromValue(data['updatedAt']);

      if (!unique.containsKey(workerId)) {
        unique[workerId] = chat;
      } else {
        final oldTime = _dateFromValue(unique[workerId]!.data()['updatedAt']);

        if (currentTime.isAfter(oldTime)) {
          unique[workerId] = chat;
        }
      }
    }

    return unique.values.toList()..sort(
      (a, b) => _dateFromValue(
        b.data()['updatedAt'],
      ).compareTo(_dateFromValue(a.data()['updatedAt'])),
    );
  }

  Widget _header({required int unreadTotal, required int totalChats}) {
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
                'Chat with your connected workers',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: unreadTotal > 0
                ? _primary.withOpacity(0.09)
                : _success.withOpacity(0.09),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                unreadTotal > 0
                    ? Icons.mark_chat_unread_outlined
                    : Icons.done_all_rounded,
                color: unreadTotal > 0 ? _primary : _success,
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                unreadTotal > 0 ? '$unreadTotal unread' : '$totalChats chats',
                style: TextStyle(
                  color: unreadTotal > 0 ? _primary : _success,
                  fontSize: 9.4,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroCard({required int totalChats, required int unreadTotal}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
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
          Positioned(
            bottom: -95,
            left: -55,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
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
                        'CUSTOMER MESSAGING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      unreadTotal > 0
                          ? '$unreadTotal new messages'
                          : 'Stay connected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      totalChats == 0
                          ? 'Your worker conversations will appear here.'
                          : 'You have $totalChats active worker conversations.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 11.2,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                height: 94,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                    if (unreadTotal > 0)
                      Positioned(
                        top: 17,
                        right: 15,
                        child: Container(
                          height: 20,
                          constraints: const BoxConstraints(minWidth: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadTotal > 99 ? '99+' : '$unreadTotal',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
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

  Widget _searchBar() {
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
          hintText: 'Search workers or services...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10.8,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 21,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: _searchController.clear,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _textSecondary,
                    size: 18,
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

  Widget _sectionHeader({required int totalChats, required int unreadTotal}) {
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
                'Latest worker messages and updates',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
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
            '$totalChats total',
            style: const TextStyle(
              color: _primary,
              fontSize: 9.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chatConversationCard(
    QueryDocumentSnapshot<Map<String, dynamic>> chatDoc,
  ) {
    final chat = chatDoc.data();
    final workerId = chat['workerId']?.toString().trim() ?? '';

    if (workerId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(workerId)
          .snapshots(),
      builder: (context, workerSnapshot) {
        if (workerSnapshot.connectionState == ConnectionState.waiting &&
            !workerSnapshot.hasData) {
          return _chatSkeleton();
        }

        final worker = workerSnapshot.data?.data();

        if (worker == null) {
          return const SizedBox.shrink();
        }

        final workerName = _fallback(worker['name'], 'Worker');
        final workerSkill = _fallback(worker['skill'], 'Skilled worker');
        final workerPhone = worker['phone']?.toString();
        final workerImageUrl = worker['imageUrl']?.toString();

        final combinedSearch =
            '$workerName $workerSkill '
                    '${chat['lastMessage'] ?? ''}'
                .toLowerCase();

        if (_searchQuery.isNotEmpty && !combinedSearch.contains(_searchQuery)) {
          return const SizedBox.shrink();
        }

        final lastMessage = _fallback(chat['lastMessage'], 'No messages yet');
        final unreadCount = _intValue(chat['unreadCountCustomer']);
        final updatedAt = _dateFromValue(chat['updatedAt']);
        final lastMessageSenderId =
            chat['lastMessageSenderId']?.toString().trim() ?? '';
        final isLastMessageMine =
            lastMessageSenderId == FirebaseAuth.instance.currentUser?.uid;

        return Dismissible(
          key: ValueKey(chatDoc.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmArchive(context),
          onDismissed: (_) async {
            await chatDoc.reference.set({
              'archivedByCustomer': true,
              'archivedAtCustomer': FieldValue.serverTimestamp(),
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
                    fontSize: 10.5,
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatDetailScreen(
                      chatId: chatDoc.id,
                      workerName: workerName,
                      workerSkill: workerSkill,
                      workerPhone: workerPhone,
                      workerImageUrl: workerImageUrl,
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 13),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: unreadCount > 0
                      ? _primary.withOpacity(0.045)
                      : _surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: unreadCount > 0
                        ? _primary.withOpacity(0.20)
                        : _border,
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
                    _workerAvatar(name: workerName, imageUrl: workerImageUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  workerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.w900
                                        : FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatChatTime(updatedAt),
                                style: TextStyle(
                                  color: unreadCount > 0
                                      ? _primary
                                      : _textSecondary,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  workerSkill,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _primary,
                                    fontSize: 8.6,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                color: _primary,
                                size: 13,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (isLastMessageMine) ...[
                                const Icon(
                                  Icons.done_all_rounded,
                                  color: _textSecondary,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unreadCount > 0
                                        ? _textPrimary
                                        : _textSecondary,
                                    fontSize: 10.4,
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (unreadCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  height: 22,
                                  constraints: const BoxConstraints(
                                    minWidth: 22,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _primary,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: _primary,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _workerAvatar({required String name, String? imageUrl}) {
    final url = imageUrl?.trim() ?? '';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_primary, _secondary]),
            borderRadius: BorderRadius.circular(19),
          ),
          clipBehavior: Clip.antiAlias,
          child: url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return _initialsAvatar(name);
                  },
                )
              : _initialsAvatar(name),
        ),
        Positioned(
          right: -3,
          bottom: -3,
          child: Container(
            height: 17,
            width: 17,
            decoration: BoxDecoration(
              color: _success,
              shape: BoxShape.circle,
              border: Border.all(color: _surface, width: 3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _initialsAvatar(String name) {
    return Center(
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _chatSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDF4),
              borderRadius: BorderRadius.circular(19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 11,
                  width: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 9,
                  width: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 9,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 30),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 15,
            offset: Offset(0, 7),
          ),
        ],
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
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: _primary,
              size: 37,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'No conversations yet',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'When a worker connects with your request, your conversation will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      child: Column(
        children: [
          _header(unreadTotal: 0, totalChats: 0),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _border),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: _primary,
                      strokeWidth: 2.6,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Loading conversations...',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorScreen(String error) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      child: Column(
        children: [
          _header(unreadTotal: 0, totalChats: 0),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 62,
                      width: 62,
                      decoration: BoxDecoration(
                        color: _danger.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.cloud_off_rounded,
                        color: _danger,
                        size: 31,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Unable to load conversations',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Please check your internet connection and Firestore index.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      error,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _danger,
                        fontSize: 8.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signedOutView() {
    return const Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Please sign in again to view your conversations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmArchive(BuildContext context) {
    return showModalBottomSheet<bool>(
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
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: _danger.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.archive_outlined,
                  color: _danger,
                  size: 30,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Archive conversation?',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'This conversation will be hidden from your active chat list.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Archive',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  DateTime _dateFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatChatTime(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    if (_isSameDay(date, now)) {
      final hour = date.hour == 0
          ? 12
          : (date.hour > 12 ? date.hour - 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    if (difference.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      return days[date.weekday - 1];
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  int _intValue(dynamic value) {
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _fallback(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'SW';

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          backgroundColor: isError ? _danger : _textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
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
