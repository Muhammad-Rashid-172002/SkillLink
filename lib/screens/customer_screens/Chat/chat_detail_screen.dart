import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String workerName;
  final String workerSkill;
  final String? workerPhone;
  final String? workerImageUrl;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.workerName,
    required this.workerSkill,
    this.workerPhone,
    this.workerImageUrl,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);

  final TextEditingController _messageController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  bool _isSending = false;
  bool _showSendButton = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _readSubscription;

  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();

    _messageController.addListener(_messageListener);
    _markIncomingMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.removeListener(_messageListener);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _readSubscription?.cancel();
    super.dispose();
  }

  void _messageListener() {
    final hasText = _messageController.text.trim().isNotEmpty;

    if (hasText != _showSendButton && mounted) {
      setState(() => _showSendButton = hasText);
    }
  }

  void _markIncomingMessagesAsRead() {
    if (_currentUserId.isEmpty) return;

    _readSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .set({
        'unreadCountCustomer': 0,
      }, SetOptions(merge: true));
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isSending) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please sign in again before sending a message.',
        isError: true,
      );
      return;
    }

    setState(() => _isSending = true);

    _messageController.clear();

    try {
      final chatReference = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId);

      final chatDocument = await chatReference.get();
      final chatData = chatDocument.data();

      if (chatData == null) {
        throw Exception('Chat information is unavailable.');
      }

      final customerId =
          chatData['customerId']?.toString().trim() ?? '';
      final workerId =
          chatData['workerId']?.toString().trim() ?? '';

      final receiverId =
          customerId == user.uid ? workerId : customerId;

      if (receiverId.isEmpty) {
        throw Exception('Message receiver was not found.');
      }

      final batch = FirebaseFirestore.instance.batch();

      final messageReference =
          chatReference.collection('messages').doc();

      batch.set(messageReference, {
        'senderId': user.uid,
        'receiverId': receiverId,
        'text': text,
        'type': 'text',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        chatReference,
        {
          'lastMessage': text,
          'lastMessageSenderId': user.uid,
          'lastMessageType': 'text',
          'updatedAt': FieldValue.serverTimestamp(),
          if (customerId == user.uid)
            'unreadCountWorker': FieldValue.increment(1)
          else
            'unreadCountCustomer': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      final notificationReference =
          FirebaseFirestore.instance
              .collection('notifications')
              .doc();

      batch.set(notificationReference, {
        'userId': receiverId,
        'title': 'New Chat Message',
        'message': text,
        'type': 'chat',
        'chatId': widget.chatId,
        'senderId': user.uid,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      _scrollToBottom();
    } catch (error) {
      _messageController.text = text;
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );

      if (!mounted) return;

      _showMessage(
        'Message could not be sent. ${error.toString()}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _makePhoneCall() async {
    final phone = widget.workerPhone?.trim() ?? '';

    if (phone.isEmpty) {
      _showMessage(
        'Worker phone number is not available.',
        isError: true,
      );
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: phone,
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showMessage(
          'Phone dialer could not be opened.',
          isError: true,
        );
      }
    } catch (_) {
      _showMessage(
        'Unable to start the phone call.',
        isError: true,
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return _signedOutScreen();
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: _ambientCircle(
              size: 330,
              color: _primary.withOpacity(0.08),
            ),
          ),
          Positioned(
            bottom: -170,
            left: -140,
            child: _ambientCircle(
              size: 350,
              color: _secondary.withOpacity(0.05),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _chatHeader(),
                _securityBanner(),
                Expanded(
                  child: _messagesStream(),
                ),
                _messageInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        14,
        12,
        14,
        10,
      ),
      padding: const EdgeInsets.fromLTRB(
        10,
        10,
        12,
        10,
      ),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.maybePop(context),
              child: const SizedBox(
                height: 42,
                width: 38,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _textPrimary,
                  size: 17,
                ),
              ),
            ),
          ),
          _workerAvatar(size: 48),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.workerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.verified_rounded,
                      color: _primary,
                      size: 15,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      height: 8,
                      width: 8,
                      decoration: const BoxDecoration(
                        color: _success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${widget.workerSkill} • Active now',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _makePhoneCall,
              child: Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.call_outlined,
                  color: _primary,
                  size: 19,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: _success.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _success.withOpacity(0.12),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: _success,
            size: 14,
          ),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Keep communication and payments inside SkillLink',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 8.9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messagesStream() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return _loadingMessages();
        }

        if (snapshot.hasError) {
          return _messagesError(snapshot.error.toString());
        }

        final messages = snapshot.data?.docs ?? [];

        if (messages.isEmpty) {
          return _emptyConversation();
        }

        _scrollToBottom();

        return ListView.builder(
          controller: _scrollController,
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            18,
          ),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index].data();
            final previousMessage =
                index > 0 ? messages[index - 1].data() : null;

            final timestamp =
                _dateFromValue(message['createdAt']);
            final previousTimestamp = previousMessage == null
                ? null
                : _dateFromValue(
                    previousMessage['createdAt'],
                  );

            final showDateSeparator =
                previousTimestamp == null ||
                    !_isSameDay(
                      timestamp,
                      previousTimestamp,
                    );

            final isMe =
                message['senderId']?.toString() ==
                    _currentUserId;

            final nextMessage = index < messages.length - 1
                ? messages[index + 1].data()
                : null;

            final nextIsSameSender = nextMessage != null &&
                nextMessage['senderId'] ==
                    message['senderId'];

            return Column(
              children: [
                if (showDateSeparator)
                  _dateSeparator(timestamp),
                _messageBubble(
                  message: message,
                  isMe: isMe,
                  compactBottom: nextIsSameSender,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _messageBubble({
    required Map<String, dynamic> message,
    required bool isMe,
    required bool compactBottom,
  }) {
    final text =
        message['text']?.toString().trim() ?? '';
    final createdAt =
        _dateFromValue(message['createdAt']);
    final isRead = message['isRead'] == true;

    return Align(
      alignment:
          isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: compactBottom ? 5 : 12,
          left: isMe ? 48 : 0,
          right: isMe ? 0 : 48,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isMe && !compactBottom) ...[
              _workerAvatar(size: 28),
              const SizedBox(width: 7),
            ] else if (!isMe)
              const SizedBox(width: 35),
            Flexible(
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  14,
                  11,
                  12,
                  8,
                ),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_primary, _secondary],
                        )
                      : null,
                  color: isMe ? null : _surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(19),
                    topRight: const Radius.circular(19),
                    bottomLeft: Radius.circular(
                      isMe ? 19 : 5,
                    ),
                    bottomRight: Radius.circular(
                      isMe ? 5 : 19,
                    ),
                  ),
                  border: isMe
                      ? null
                      : Border.all(color: _border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x090F172A),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        color:
                            isMe ? Colors.white : _textPrimary,
                        fontSize: 11.7,
                        height: 1.42,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(createdAt),
                          style: TextStyle(
                            color: isMe
                                ? Colors.white.withOpacity(0.72)
                                : _textSecondary,
                            fontSize: 7.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isRead
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            color: isRead
                                ? const Color(0xFFBAE6FD)
                                : Colors.white.withOpacity(0.72),
                            size: 13,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        14,
        9,
        14,
        13,
      ),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.97),
        border: const Border(
          top: BorderSide(color: _border),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () {
                  _showMessage(
                    'Attachment support can be connected here.',
                  );
                },
                child: Container(
                  height: 45,
                  width: 45,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: _textSecondary,
                    size: 23,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 45,
                  maxHeight: 120,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization:
                      TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  onSubmitted: (_) {
                    if (_showSendButton) {
                      _sendMessage();
                    }
                  },
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 11.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Write a message...',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10.8,
                      fontWeight: FontWeight.w600,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                gradient: _showSendButton
                    ? const LinearGradient(
                        colors: [_primary, _secondary],
                      )
                    : null,
                color: _showSendButton
                    ? null
                    : const Color(0xFFE8EDF4),
                borderRadius: BorderRadius.circular(15),
                boxShadow: _showSendButton
                    ? [
                        BoxShadow(
                          color: _primary.withOpacity(0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: _showSendButton && !_isSending
                      ? _sendMessage
                      : null,
                  child: Center(
                    child: _isSending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: _showSendButton
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workerAvatar({
    required double size,
  }) {
    final imageUrl = widget.workerImageUrl?.trim() ?? '';

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return _initialsAvatar();
              },
            )
          : _initialsAvatar(),
    );
  }

  Widget _initialsAvatar() {
    return Center(
      child: Text(
        _initials(widget.workerName),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _dateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 13,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: _border),
          ),
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Text(
              _formatDateLabel(date),
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 8.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Expanded(
            child: Divider(color: _border),
          ),
        ],
      ),
    );
  }

  Widget _emptyConversation() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              height: 92,
              width: 92,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primary.withOpacity(0.12),
                    _secondary.withOpacity(0.09),
                  ],
                ),
                borderRadius: BorderRadius.circular(29),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: _primary,
                size: 43,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Start the conversation',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Send a message to ${widget.workerName} about your service request.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 10.7,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 17),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _quickMessage('Hello!'),
                _quickMessage('When can you arrive?'),
                _quickMessage('Please share the estimated cost.'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickMessage(String text) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          _messageController.text = text;
          _messageController.selection =
              TextSelection.collapsed(offset: text.length);
          _messageFocusNode.requestFocus();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _border),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: _primary,
              fontSize: 9.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingMessages() {
    return const Center(
      child: CircularProgressIndicator(
        color: _primary,
        strokeWidth: 2.6,
      ),
    );
  }

  Widget _messagesError(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: _danger,
              size: 38,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load messages',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 10.2,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _signedOutScreen() {
    return const Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: Text(
            'Please sign in again to open this conversation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
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
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }

  bool _isSameDay(
    DateTime first,
    DateTime second,
  ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _formatTime(DateTime date) {
    final hour =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, yesterday)) return 'Yesterday';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
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

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          backgroundColor:
              isError ? _danger : _textPrimary,
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

  Widget _ambientCircle({
    required double size,
    required Color color,
  }) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: 50,
        sigmaY: 50,
      ),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
