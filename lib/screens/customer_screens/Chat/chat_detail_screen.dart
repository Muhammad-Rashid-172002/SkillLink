import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String workerId;
  final String workerName;
  final String workerSkill;
  final String? workerPhone;
  final String? workerImageUrl;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.workerId,

    required this.workerName,
    required this.workerSkill,
    this.workerPhone,
    this.workerImageUrl,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with WidgetsBindingObserver {
  static const Color primary = Color(0xFF2563EB);

  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<String, Duration> _audioPositions = {};
  final Map<String, Duration> _audioDurations = {};
  final Set<String> _playingAudioIds = {};

  DocumentSnapshot<Map<String, dynamic>>? _replyingTo;
  bool _isRecording = false;
  bool _isUploading = false;
  bool _isTyping = false;
  String? _recordingPath;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> get _chatRef =>
      FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _chatRef.collection('messages');

  DocumentReference<Map<String, dynamic>> get _currentUserRef =>
      FirebaseFirestore.instance.collection('users').doc(_currentUserId);

  DocumentReference<Map<String, dynamic>> get _workerRef =>
      FirebaseFirestore.instance.collection('users').doc(widget.workerId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    messageController.addListener(_handleTyping);
    _setOnlineStatus(true);
    _markMessagesAsDeliveredAndSeen();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
      _markMessagesAsDeliveredAndSeen();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _setOnlineStatus(false);
      _setTyping(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    messageController.removeListener(_handleTyping);
    messageController.dispose();
    _scrollController.dispose();

    for (final player in _audioPlayers.values) {
      player.dispose();
    }

    _audioRecorder.dispose();
    _setTyping(false);
    _setOnlineStatus(false);
    super.dispose();
  }

  Future<void> _setOnlineStatus(bool online) async {
    if (_currentUserId.isEmpty) return;

    try {
      await _currentUserRef.set({
        'isOnline': online,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Online status error: $e');
    }
  }

  void _handleTyping() {
    final shouldType = messageController.text.trim().isNotEmpty;
    if (_isTyping == shouldType) return;

    _isTyping = shouldType;
    _setTyping(shouldType);
  }

  Future<void> _setTyping(bool value) async {
    if (_currentUserId.isEmpty) return;

    try {
      await _chatRef.set({
        'typing': {_currentUserId: value},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Typing status error: $e');
    }
  }

  Future<void> sendTextMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || _currentUserId.isEmpty) return;

    messageController.clear();
    await _setTyping(false);

    await _sendMessage({'text': text, 'type': 'text'});
  }

  Future<void> _sendMessage(Map<String, dynamic> content) async {
    final messageRef = _messagesRef.doc();
    final replyData = _buildReplyData();

    try {
      final batch = FirebaseFirestore.instance.batch();

      batch.set(messageRef, {
        'senderId': _currentUserId,
        'receiverId': widget.workerId,
        ...content,
        'replyTo': replyData,
        'reactions': <String, dynamic>{},
        'status': 'sent',
        'isSeen': false,
        'isRead': false,
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final preview = _lastMessagePreview(content);

      batch.set(_chatRef, {
        'participants': [_currentUserId, widget.workerId],
        'customerId': _currentUserId,
        'workerId': widget.workerId,
        'service': widget.workerSkill,
        'lastMessage': preview,
        'lastMessageType': content['type'] ?? 'text',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSenderId': _currentUserId,
        'lastMessageSeen': false,
        'workerUnreadCount': FieldValue.increment(1),
        'unreadCountWorker': FieldValue.increment(1),
        'customerUnreadCount': 0,
        'unreadCountCustomer': 0,
        'archivedByCustomer': false,
        'archivedByWorker': false,
      }, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        setState(() => _replyingTo = null);
      }

      _scrollToBottom();
    } catch (e) {
      _showError('Message send failed: $e');
    }
  }

  Map<String, dynamic>? _buildReplyData() {
    final reply = _replyingTo;
    if (reply == null) return null;

    final data = reply.data();
    if (data == null) return null;

    return {
      'messageId': reply.id,
      'senderId': data['senderId'],
      'type': data['type'] ?? 'text',
      'text': _replyPreview(data),
    };
  }

  String _replyPreview(Map<String, dynamic> data) {
    if (data['isDeleted'] == true) return 'This message was deleted';

    switch (data['type']) {
      case 'image':
        return '📷 Photo';
      case 'audio':
        return '🎤 Voice message';
      default:
        return data['text']?.toString() ?? '';
    }
  }

  String _lastMessagePreview(Map<String, dynamic> content) {
    switch (content['type']) {
      case 'image':
        return '📷 Photo';
      case 'audio':
        return '🎤 Voice message';
      default:
        return content['text']?.toString() ?? '';
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final extension = image.path.split('.').last.toLowerCase();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_media')
          .child(widget.chatId)
          .child('${DateTime.now().millisecondsSinceEpoch}.$extension');

      await storageRef.putFile(File(image.path));
      final imageUrl = await storageRef.getDownloadURL();

      await _sendMessage({'type': 'image', 'text': '', 'imageUrl': imageUrl});
    } catch (e) {
      _showError('Image send failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopAndSendRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _showError('Microphone permission is required.');
        return;
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingPath = path;
      });
    } catch (e) {
      _showError('Recording start failed: $e');
    }
  }

  Future<void> _stopAndSendRecording() async {
    try {
      final path = await _audioRecorder.stop() ?? _recordingPath;

      setState(() => _isRecording = false);

      if (path == null) return;

      setState(() => _isUploading = true);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_audio')
          .child(widget.chatId)
          .child('${DateTime.now().millisecondsSinceEpoch}.m4a');

      await storageRef.putFile(
        File(path),
        SettableMetadata(contentType: 'audio/mp4'),
      );

      final audioUrl = await storageRef.getDownloadURL();

      await _sendMessage({'type': 'audio', 'text': '', 'audioUrl': audioUrl});

      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      _showError('Voice note send failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _recordingPath = null;
        });
      }
    }
  }

  Future<void> _markMessagesAsDeliveredAndSeen() async {
    if (_currentUserId.isEmpty) return;

    try {
      final incomingMessages = await _messagesRef
          .where('receiverId', isEqualTo: _currentUserId)
          .get();

      final unreadMessages = incomingMessages.docs.where((message) {
        final data = message.data();
        return data['isSeen'] != true || data['isRead'] != true;
      }).toList();

      if (unreadMessages.isEmpty) {
        await _chatRef.set({
          'customerUnreadCount': 0,
          'unreadCountCustomer': 0,
        }, SetOptions(merge: true));
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (final message in unreadMessages) {
        batch.update(message.reference, {
          'status': 'seen',
          'isSeen': true,
          'isRead': true,
          'seenAt': FieldValue.serverTimestamp(),
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      batch.set(_chatRef, {
        'customerUnreadCount': 0,
        'unreadCountCustomer': 0,
        'lastMessageSeen': true,
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint('Mark messages read error: $e');
    }
  }

  Future<void> _markIncomingAsDelivered(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
  ) async {
    final undelivered = messages.where((doc) {
      final data = doc.data();
      return data['receiverId'] == _currentUserId &&
          (data['status'] == null || data['status'] == 'sent') &&
          data['isSeen'] != true &&
          data['isRead'] != true;
    }).toList();

    if (undelivered.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final message in undelivered) {
      batch.update(message.reference, {
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Delivered update error: $e');
    }
  }

  Future<void> _deleteMessage(
    DocumentSnapshot<Map<String, dynamic>> message,
  ) async {
    final data = message.data();
    if (data == null || data['senderId'] != _currentUserId) return;

    try {
      await message.reference.update({
        'isDeleted': true,
        'text': '',
        'imageUrl': FieldValue.delete(),
        'audioUrl': FieldValue.delete(),
        'reactions': <String, dynamic>{},
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _showError('Delete failed: $e');
    }
  }

  Future<void> _addReaction(
    DocumentSnapshot<Map<String, dynamic>> message,
    String emoji,
  ) async {
    try {
      await message.reference.set({
        'reactions': {_currentUserId: emoji},
      }, SetOptions(merge: true));
    } catch (e) {
      _showError('Reaction failed: $e');
    }
  }

  Future<void> _removeReaction(
    DocumentSnapshot<Map<String, dynamic>> message,
  ) async {
    try {
      await message.reference.update({
        'reactions.$_currentUserId': FieldValue.delete(),
      });
    } catch (e) {
      _showError('Reaction remove failed: $e');
    }
  }

  void _showMessageMenu(DocumentSnapshot<Map<String, dynamic>> message) {
    final data = message.data();
    if (data == null) return;

    final isMe = data['senderId'] == _currentUserId;
    final isText = data['type'] == 'text' && data['isDeleted'] != true;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['❤️', '👍', '😂', '😮', '😢', '🙏']
                      .map(
                        (emoji) => InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _addReaction(message, emoji);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 25),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _replyingTo = message);
                },
              ),
              if (isText)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy'),
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: data['text']?.toString() ?? ''),
                    );
                    Navigator.pop(sheetContext);
                  },
                ),
              if ((data['reactions'] as Map?)?.containsKey(_currentUserId) ==
                  true)
                ListTile(
                  leading: const Icon(Icons.emoji_emotions_outlined),
                  title: const Text('Remove reaction'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removeReaction(message);
                  },
                ),
              if (isMe && data['isDeleted'] != true)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Delete for everyone',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _deleteMessage(message);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _makePhoneCall() async {
    final phone = widget.workerPhone?.trim() ?? '';

    if (phone.isEmpty) {
      _showError('Worker phone number is not available.');
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showError('Phone dialer could not be opened.');
      }
    } catch (e) {
      _showError('Unable to start phone call: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned(
            top: -130,
            right: -90,
            child: Container(
              height: 260,
              width: 260,
              decoration: BoxDecoration(
                color: primary.withOpacity(.045),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -120,
            child: Container(
              height: 270,
              width: 270,
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(.035),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              Expanded(child: _buildMessages()),
              _buildTypingIndicator(),
              if (_replyingTo != null) _buildReplyComposer(),
              _buildMessageInput(),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 76,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF0F172A),
      surfaceTintColor: Colors.transparent,
      leadingWidth: 52,
      leading: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Center(
          child: Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
            ),
          ),
        ),
      ),
      titleSpacing: 8,
      title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _workerRef.snapshots(),
        builder: (context, snapshot) {
          final userData = snapshot.data?.data();
          final imageUrl =
              userData?['profileImageUrl']?.toString() ??
              userData?['photoUrl']?.toString() ??
              widget.workerImageUrl ??
              '';
          final isOnline = userData?['isOnline'] == true;
          final lastSeen = userData?['lastSeen'];

          return Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(.18),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return _buildAppBarInitial();
                            },
                          )
                        : _buildAppBarInitial(),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      height: 15,
                      width: 15,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFCBD5E1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.workerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _chatRef.snapshots(),
                      builder: (context, chatSnapshot) {
                        final typingMap =
                            chatSnapshot.data?.data()?['typing'] as Map?;
                        final customerTyping =
                            typingMap?[widget.workerId] == true;

                        final subtitle = customerTyping
                            ? 'Typing...'
                            : isOnline
                            ? 'Online'
                            : _lastSeenText(lastSeen);

                        return Row(
                          children: [
                            if (customerTyping || isOnline)
                              Container(
                                height: 6,
                                width: 6,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.2,
                                  color: customerTyping || isOnline
                                      ? primary
                                      : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        _appBarAction(icon: Icons.call_outlined, onTap: _makePhoneCall),
        const SizedBox(width: 7),
        _appBarAction(icon: Icons.more_vert_rounded, onTap: () {}),
        const SizedBox(width: 10),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildAppBarInitial() {
    return Center(
      child: Text(
        widget.workerName.isNotEmpty ? widget.workerName[0].toUpperCase() : 'C',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _appBarAction({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF334155), size: 19),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesRef.orderBy('createdAt').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: primary, strokeWidth: 2.6),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 66,
                    width: 66,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(.09),
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      color: Color(0xFFEF4444),
                      size: 31,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Unable to load chat',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final messages = snapshot.data?.docs ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 27),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x070F172A),
                    blurRadius: 18,
                    offset: Offset(0, 9),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 82,
                    width: 82,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primary.withOpacity(.14),
                          const Color(0xFF06B6D4).withOpacity(.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Icon(
                      Icons.waving_hand_rounded,
                      color: primary,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Start the conversation',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Send a message to ${widget.workerName} about ${widget.workerSkill}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _markIncomingAsDelivered(messages);
          _markMessagesAsDeliveredAndSeen();
        });

        return ListView.builder(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final data = message.data();
            final currentDate = _messageDate(data['createdAt']);
            final previousDate = index == 0
                ? null
                : _messageDate(messages[index - 1].data()['createdAt']);
            final showDate = index == 0 || currentDate != previousDate;

            return Column(
              children: [
                if (showDate) _buildDateSeparator(data['createdAt']),
                _SwipeReplyWrapper(
                  onReply: () {
                    setState(() => _replyingTo = message);
                  },
                  child: _messageBubble(message),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateSeparator(dynamic timestamp) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          _dateSeparatorText(timestamp),
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 9.6,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _messageBubble(DocumentSnapshot<Map<String, dynamic>> message) {
    final data = message.data() ?? {};
    final isMe = data['senderId'] == _currentUserId;
    final isDeleted = data['isDeleted'] == true;
    final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
    final groupedReactions = <String, int>{};

    for (final reaction in reactions.values) {
      final emoji = reaction.toString();
      groupedReactions[emoji] = (groupedReactions[emoji] ?? 0) + 1;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageMenu(message),
        child: Container(
          margin: EdgeInsets.only(bottom: groupedReactions.isNotEmpty ? 18 : 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * .82,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  data['type'] == 'image' ? 5 : 13,
                  data['type'] == 'image' ? 5 : 10,
                  data['type'] == 'image' ? 5 : 10,
                  7,
                ),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFDBEAFE), Color(0xFFCFFAFE)],
                        )
                      : null,
                  color: isMe ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 5),
                    bottomRight: Radius.circular(isMe ? 5 : 20),
                  ),
                  border: Border.all(
                    color: isMe
                        ? const Color(0xFFBFDBFE)
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x080F172A),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data['replyTo'] != null && !isDeleted)
                      _buildQuotedReply(
                        Map<String, dynamic>.from(data['replyTo']),
                        isMe,
                      ),
                    if (isDeleted)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 5,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.block_rounded,
                              size: 15,
                              color: Color(0xFF64748B),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'This message was deleted',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildMessageContent(message.id, data),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatMessageTime(data['createdAt']),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 8.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            _statusIcon(data),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (groupedReactions.isNotEmpty)
                Positioned(
                  bottom: -13,
                  right: isMe ? 8 : null,
                  left: isMe ? null : 8,
                  child: GestureDetector(
                    onTap: () => _showMessageMenu(message),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x120F172A),
                            blurRadius: 7,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: groupedReactions.entries
                            .map(
                              (entry) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: Text(
                                  entry.value > 1
                                      ? '${entry.key}${entry.value}'
                                      : entry.key,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotedReply(Map<String, dynamic> reply, bool isMe) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(.62) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: primary, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply['senderId'] == _currentUserId ? 'You' : widget.workerName,
            style: const TextStyle(
              color: primary,
              fontWeight: FontWeight.w900,
              fontSize: 10.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            reply['text']?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 10.2,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(String messageId, Map<String, dynamic> data) {
    switch (data['type']) {
      case 'image':
        final imageUrl = data['imageUrl']?.toString() ?? '';

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: imageUrl.isEmpty
              ? const SizedBox(
                  height: 180,
                  width: 220,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                )
              : Image.network(
                  imageUrl,
                  height: 220,
                  width: 240,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;

                    return const SizedBox(
                      height: 220,
                      width: 240,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: primary,
                          strokeWidth: 2.5,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) {
                    return const SizedBox(
                      height: 180,
                      width: 220,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    );
                  },
                ),
        );

      case 'audio':
        return _buildAudioPlayer(messageId, data['audioUrl']?.toString() ?? '');

      default:
        return Text(
          data['text']?.toString() ?? '',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        );
    }
  }

  Widget _buildAudioPlayer(String messageId, String audioUrl) {
    final isPlaying = _playingAudioIds.contains(messageId);
    final position = _audioPositions[messageId] ?? Duration.zero;
    final duration = _audioDurations[messageId] ?? Duration.zero;

    final maxMilliseconds = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;

    final value = position.inMilliseconds
        .clamp(0, maxMilliseconds.toInt())
        .toDouble();

    return SizedBox(
      width: 235,
      child: Row(
        children: [
          Material(
            color: primary.withOpacity(.10),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: audioUrl.isEmpty
                  ? null
                  : () => _toggleAudio(messageId, audioUrl),
              child: SizedBox(
                height: 42,
                width: 42,
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: primary,
                  size: 25,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value,
                max: maxMilliseconds,
                activeColor: primary,
                inactiveColor: const Color(0xFFCBD5E1),
                onChanged: duration.inMilliseconds <= 0
                    ? null
                    : (newValue) async {
                        final player = _audioPlayers[messageId];
                        if (player != null) {
                          await player.seek(
                            Duration(milliseconds: newValue.toInt()),
                          );
                        }
                      },
              ),
            ),
          ),
          Text(
            _formatDuration(duration.inMilliseconds > 0 ? duration : position),
            style: const TextStyle(
              fontSize: 9.2,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAudio(String messageId, String audioUrl) async {
    AudioPlayer player = _audioPlayers[messageId] ?? AudioPlayer();

    if (!_audioPlayers.containsKey(messageId)) {
      _audioPlayers[messageId] = player;

      player.onDurationChanged.listen((duration) {
        if (!mounted) return;
        setState(() => _audioDurations[messageId] = duration);
      });

      player.onPositionChanged.listen((position) {
        if (!mounted) return;
        setState(() => _audioPositions[messageId] = position);
      });

      player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _playingAudioIds.remove(messageId);
          _audioPositions[messageId] = Duration.zero;
        });
      });
    }

    if (_playingAudioIds.contains(messageId)) {
      await player.pause();
      setState(() => _playingAudioIds.remove(messageId));
    } else {
      for (final entry in _audioPlayers.entries) {
        if (entry.key != messageId) {
          await entry.value.pause();
        }
      }

      setState(() {
        _playingAudioIds
          ..clear()
          ..add(messageId);
      });

      await player.play(UrlSource(audioUrl));
    }
  }

  Widget _statusIcon(Map<String, dynamic> data) {
    final status =
        data['status']?.toString() ??
        (data['isSeen'] == true ? 'seen' : 'sent');

    switch (status) {
      case 'seen':
        return const Icon(
          Icons.done_all_rounded,
          size: 16,
          color: Color(0xFF2563EB),
        );
      case 'delivered':
        return const Icon(
          Icons.done_all_rounded,
          size: 16,
          color: Color(0xFF94A3B8),
        );
      default:
        return const Icon(
          Icons.done_rounded,
          size: 16,
          color: Color(0xFF94A3B8),
        );
    }
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _chatRef.snapshots(),
      builder: (context, snapshot) {
        final typing = snapshot.data?.data()?['typing'] as Map?;
        final isCustomerTyping = typing?[widget.workerId] == true;

        if (!isCustomerTyping) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 7),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _typingDot(0),
              const SizedBox(width: 4),
              _typingDot(1),
              const SizedBox(width: 4),
              _typingDot(2),
              const SizedBox(width: 8),
              Text(
                '${widget.workerName} is typing',
                style: const TextStyle(
                  color: primary,
                  fontSize: 9.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _typingDot(int index) {
    return Container(
      height: 6,
      width: 6,
      decoration: BoxDecoration(
        color: primary.withOpacity(index == 1 ? .75 : .45),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildReplyComposer() {
    final data = _replyingTo?.data() ?? {};

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 5, 12, 0),
      padding: const EdgeInsets.fromLTRB(13, 10, 7, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['senderId'] == _currentUserId
                      ? 'Replying to yourself'
                      : 'Replying to ${widget.workerName}',
                  style: const TextStyle(
                    color: primary,
                    fontSize: 10.3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _replyPreview(data),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() => _replyingTo = null);
            },
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF64748B),
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
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
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isUploading ? null : _pickAndSendImage,
                child: const SizedBox(
                  height: 46,
                  width: 46,
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: Color(0xFF475569),
                    size: 21,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: messageController,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: _isRecording
                      ? 'Recording voice note...'
                      : 'Write a message...',
                  hintStyle: TextStyle(
                    color: _isRecording
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 13,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: primary, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: messageController,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;

                return GestureDetector(
                  onTap: _isUploading
                      ? null
                      : hasText
                      ? sendTextMessage
                      : _toggleRecording,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      gradient: _isRecording
                          ? const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                            ),
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_isRecording ? const Color(0xFFEF4444) : primary)
                                  .withOpacity(.24),
                          blurRadius: 13,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: _isUploading
                        ? const Padding(
                            padding: EdgeInsets.all(13),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            hasText
                                ? Icons.send_rounded
                                : _isRecording
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(dynamic value) {
    if (value is! Timestamp) return 'Sending...';
    return DateFormat('h:mm a').format(value.toDate());
  }

  String _messageDate(dynamic value) {
    if (value is! Timestamp) return '';
    return DateFormat('yyyy-MM-dd').format(value.toDate());
  }

  String _dateSeparatorText(dynamic value) {
    if (value is! Timestamp) return 'Today';

    final date = value.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDay).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';

    if (date.year == now.year) {
      return DateFormat('d MMMM').format(date);
    }

    return DateFormat('d MMMM yyyy').format(date);
  }

  String _lastSeenText(dynamic value) {
    if (value is! Timestamp) return widget.workerSkill;

    final date = value.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Last seen just now';
    if (difference.inMinutes < 60) {
      return 'Last seen ${difference.inMinutes}m ago';
    }

    final isToday = DateUtils.isSameDay(date, now);
    if (isToday) {
      return 'Last seen today at ${DateFormat('h:mm a').format(date)}';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (DateUtils.isSameDay(date, yesterday)) {
      return 'Last seen yesterday at ${DateFormat('h:mm a').format(date)}';
    }

    return 'Last seen ${DateFormat('d MMM, h:mm a').format(date)}';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _SwipeReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const _SwipeReplyWrapper({required this.child, required this.onReply});

  @override
  State<_SwipeReplyWrapper> createState() => _SwipeReplyWrapperState();
}

class _SwipeReplyWrapperState extends State<_SwipeReplyWrapper> {
  double _dragOffset = 0;
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx <= 0) return;

        setState(() {
          _dragOffset = (_dragOffset + details.delta.dx).clamp(0, 72);
        });

        if (_dragOffset >= 58 && !_triggered) {
          _triggered = true;
          HapticFeedback.lightImpact();
        }
      },
      onHorizontalDragEnd: (_) {
        if (_dragOffset >= 58) widget.onReply();

        setState(() {
          _dragOffset = 0;
          _triggered = false;
        });
      },
      onHorizontalDragCancel: () {
        setState(() {
          _dragOffset = 0;
          _triggered = false;
        });
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_dragOffset > 8)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Opacity(
                opacity: (_dragOffset / 58).clamp(0, 1),
                child: const CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFF2563EB),
                  child: Icon(
                    Icons.reply_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
