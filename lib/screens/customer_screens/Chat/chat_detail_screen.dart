import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_detail_screen.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_status.dart';
import 'package:skill_link/screens/customer_screens/customer_my_request_scree/request_tracking_screen.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/WorkerPublicProfileScreen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_components.dart';
import 'chat_models.dart';
import 'customer_chat_repository.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.workerId,
    required this.workerName,
    required this.workerSkill,
    this.workerPhone,
    this.workerImageUrl,
    this.workerVerified = false,
    this.requestId = '',
    this.dataSource,
    this.onViewProfile,
    this.onCall,
    this.onViewBooking,
  });

  final String chatId;
  final String workerId;
  final String workerName;
  final String workerSkill;
  final String? workerPhone;
  final String? workerImageUrl;
  final bool workerVerified;
  final String requestId;
  final CustomerChatDataSource? dataSource;
  final VoidCallback? onViewProfile;
  final VoidCallback? onCall;
  final void Function(String requestId, String status)? onViewBooking;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  static const int _pageSize = 40;

  late final CustomerChatDataSource _dataSource;
  late final Stream<CustomerChatContext?> _chatStream;
  late final Stream<CustomerChatWorker?> _workerStream;
  late final Stream<CustomerMessagePage> _latestMessagesStream;
  final Map<String, Stream<Map<String, dynamic>?>> _bookingStreams = {};
  final Map<String, CustomerChatMessage> _olderMessages = {};
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  CustomerChatMessage? _replyingTo;
  Object? _olderCursor;
  bool _hasMore = false;
  bool _loadingOlder = false;
  bool _didInitialScroll = false;
  bool _isTyping = false;
  bool _isRecording = false;
  bool _isUploading = false;
  String? _recordingPath;
  String? _playingMessageId;
  bool _audioLoading = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  String? _lastReadMessageId;

  String get _customerId => _dataSource.customerId;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? FirebaseCustomerChatRepository();
    _chatStream = _dataSource.watchChat(widget.chatId);
    _workerStream = _dataSource.watchWorker(widget.workerId);
    _latestMessagesStream = _dataSource.watchLatestMessages(
      widget.chatId,
      pageSize: _pageSize,
    );
    _messageController.addListener(_handleTyping);
    _scrollController.addListener(_handleScroll);
    _audioPlayer.onDurationChanged.listen((value) {
      if (mounted) setState(() => _audioDuration = value);
    });
    _audioPlayer.onPositionChanged.listen((value) {
      if (mounted) setState(() => _audioPosition = value);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playingMessageId = null;
        _audioPosition = Duration.zero;
        _audioLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleTyping);
    _messageController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    unawaited(_setTypingSafely(false));
    unawaited(_audioRecorder.dispose());
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 100 &&
        _hasMore &&
        !_loadingOlder) {
      unawaited(_loadOlder());
    }
  }

  void _handleTyping() {
    final next = _messageController.text.trim().isNotEmpty;
    if (next == _isTyping) return;
    _isTyping = next;
    unawaited(_setTypingSafely(next));
  }

  Future<void> _setTypingSafely(bool value) async {
    try {
      await _dataSource.setTyping(widget.chatId, value);
    } catch (_) {
      // Typing is ephemeral and must never prevent core messaging behavior.
    }
  }

  Future<void> _loadOlder() async {
    final cursor = _olderCursor;
    if (cursor == null || !_hasMore || _loadingOlder) return;
    final oldMax = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    setState(() => _loadingOlder = true);
    try {
      final page = await _dataSource.loadOlderMessages(
        widget.chatId,
        cursor,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        for (final message in page.messages) {
          _olderMessages[message.id] = message;
        }
        _olderCursor = page.cursor;
        _hasMore = page.hasMore;
        _loadingOlder = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final addedExtent = _scrollController.position.maxScrollExtent - oldMax;
        _scrollController.jumpTo(
          (_scrollController.position.pixels + addedExtent).clamp(
            0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingOlder = false);
        _showMessage('Older messages could not be loaded.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CustomerChatContext?>(
      stream: _chatStream,
      builder: (context, chatSnapshot) {
        if (chatSnapshot.connectionState == ConnectionState.waiting &&
            !chatSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final chat = chatSnapshot.data;
        if (chatSnapshot.hasError || chat == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Messages')),
            body: const Center(
              child: Text('This conversation is unavailable.'),
            ),
          );
        }
        return StreamBuilder<CustomerChatWorker?>(
          stream: _workerStream,
          builder: (context, workerSnapshot) {
            final worker = workerSnapshot.data;
            final name = worker?.name ?? widget.workerName;
            final skill = chat.service.isNotEmpty
                ? chat.service
                : worker?.skill ?? widget.workerSkill;
            final photo = worker?.photoUrl ?? widget.workerImageUrl ?? '';
            final phone = worker?.phone ?? widget.workerPhone ?? '';
            final verified = worker?.verified ?? widget.workerVerified;
            return Scaffold(
              resizeToAvoidBottomInset: true,
              appBar: AppBar(
                toolbarHeight: 72,
                titleSpacing: 0,
                title: ChatHeader(
                  name: name,
                  skill: skill,
                  photoUrl: photo,
                  verified: verified,
                  onViewProfile: () => _viewProfile(),
                  onCall: phone.isEmpty ? null : () => _call(phone),
                ),
              ),
              body: SafeArea(
                top: false,
                child: Column(
                  children: [
                    _bookingContext(chat, skill),
                    Expanded(child: _messages(chat, name)),
                    if (chat.workerTyping) TypingIndicator(workerName: name),
                    MessageComposer(
                      controller: _messageController,
                      isRecording: _isRecording,
                      isUploading: _isUploading,
                      onSend: () => _sendText(chat.workerId, skill),
                      onAttachment: () =>
                          _pickAndSendImage(chat.workerId, skill),
                      onMicrophone: () =>
                          _toggleRecording(chat.workerId, skill),
                      replyLabel: _replyingTo == null
                          ? null
                          : 'Replying to ${_replyingTo!.senderId == _customerId ? 'yourself' : name}: ${_replyingTo!.replyPreview}',
                      onCancelReply: () => setState(() => _replyingTo = null),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _bookingContext(CustomerChatContext chat, String service) {
    final requestId = chat.requestId.isNotEmpty
        ? chat.requestId
        : widget.requestId;
    if (requestId.isEmpty) return const SizedBox.shrink();
    final stream = _bookingStreams.putIfAbsent(
      requestId,
      () => _dataSource.watchBooking(requestId),
    );
    return StreamBuilder<Map<String, dynamic>?>(
      stream: stream,
      builder: (context, snapshot) {
        final booking = snapshot.data;
        if (booking == null) return const SizedBox.shrink();
        final status = bookingStatusOf(booking['status']);
        final bookingService = chatText(booking, const [
          'category',
          'service',
          'title',
        ], service);
        return BookingContextBanner(
          service: bookingService,
          status: status,
          onTap: () =>
              _viewBooking(requestId, booking['status']?.toString() ?? ''),
        );
      },
    );
  }

  Widget _messages(CustomerChatContext chat, String workerName) {
    return StreamBuilder<CustomerMessagePage>(
      stream: _latestMessagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _ThreadState(
            icon: Icons.cloud_off_outlined,
            title: 'Messages could not be loaded',
            description: 'Check your connection and reopen this conversation.',
          );
        }
        final latestPage =
            snapshot.data ??
            const CustomerMessagePage(messages: [], hasMore: false);
        _olderCursor = _olderMessages.isEmpty
            ? latestPage.cursor
            : _olderCursor ?? latestPage.cursor;
        _hasMore =
            latestPage.hasMore || (_olderMessages.isNotEmpty && _hasMore);
        final messages = mergeCustomerMessages(
          _olderMessages.values,
          latestPage.messages,
        );
        if (messages.isEmpty) {
          return _ThreadState(
            icon: Icons.waving_hand_outlined,
            title: 'Start the conversation',
            description: 'Send a message to $workerName about ${chat.service}.',
          );
        }
        _scheduleInitialScroll();
        _scheduleRead(chat, messages);
        return ListView.builder(
          key: const ValueKey('chat-message-list'),
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            SkillNovaSpacing.md,
            SkillNovaSpacing.sm,
            SkillNovaSpacing.md,
            SkillNovaSpacing.sm,
          ),
          itemCount: messages.length + (_loadingOlder ? 1 : 0),
          itemBuilder: (context, index) {
            if (_loadingOlder && index == 0) {
              return const Padding(
                padding: EdgeInsets.all(SkillNovaSpacing.sm),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final messageIndex = index - (_loadingOlder ? 1 : 0);
            final message = messages[messageIndex];
            final previous = messageIndex == 0
                ? null
                : messages[messageIndex - 1];
            final showDay =
                previous == null ||
                !DateUtils.isSameDay(previous.createdAt, message.createdAt);
            return Column(
              children: [
                if (showDay)
                  _DaySeparator(label: messageDay(message.createdAt)),
                MessageBubble(
                  message: message,
                  currentUserId: _customerId,
                  workerName: workerName,
                  onReply: () => setState(() => _replyingTo = message),
                  onLongPress: () => _showMessageMenu(message),
                  imageBuilder: (url) => ImageMessageBubble(
                    imageUrl: url,
                    onOpen: () => _openImage(url),
                  ),
                  audioBuilder: (id, url) => AudioMessageBubble(
                    playing:
                        _playingMessageId == id &&
                        _audioPlayer.state == PlayerState.playing,
                    loading: _playingMessageId == id && _audioLoading,
                    position: _playingMessageId == id
                        ? _audioPosition
                        : Duration.zero,
                    duration: _playingMessageId == id
                        ? _audioDuration
                        : Duration.zero,
                    onToggle: url.isEmpty ? null : () => _toggleAudio(id, url),
                    onSeek: _playingMessageId == id
                        ? (value) => _audioPlayer.seek(
                            Duration(milliseconds: value.toInt()),
                          )
                        : null,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _scheduleInitialScroll() {
    if (_didInitialScroll) return;
    _didInitialScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _scheduleRead(
    CustomerChatContext chat,
    List<CustomerChatMessage> messages,
  ) {
    final latest = messages.last;
    if (latest.id == _lastReadMessageId ||
        latest.senderId == _customerId ||
        latest.status == CustomerMessageStatus.seen) {
      return;
    }
    _lastReadMessageId = latest.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _dataSource.markConversationRead(
          widget.chatId,
          observedLastMessageTime: chat.lastMessageTime,
        ),
      );
    });
  }

  Future<void> _sendText(String workerId, String service) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await _send(workerId, service, {'type': 'text', 'text': text});
  }

  Future<void> _send(
    String workerId,
    String service,
    Map<String, dynamic> content,
  ) async {
    final reply = _replyingTo;
    final replyData = reply == null
        ? null
        : {
            'messageId': reply.id,
            'senderId': reply.senderId,
            'type': reply.type,
            'text': reply.replyPreview,
          };
    try {
      await _setTypingSafely(false);
      await _dataSource.sendMessage(
        widget.chatId,
        workerId: workerId,
        service: service,
        content: content,
        replyTo: replyData,
      );
      if (!mounted) return;
      setState(() => _replyingTo = null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      _showMessage('Message could not be sent.');
    }
  }

  Future<void> _pickAndSendImage(String workerId, String service) async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (image == null) return;
      setState(() => _isUploading = true);
      final extension = image.path.split('.').last.toLowerCase();
      final reference = FirebaseStorage.instance.ref(
        'chat_media/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      await reference.putFile(File(image.path));
      final url = await reference.getDownloadURL();
      await _send(workerId, service, {
        'type': 'image',
        'text': '',
        'imageUrl': url,
      });
    } catch (_) {
      _showMessage('Photo could not be sent.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _toggleRecording(String workerId, String service) async {
    if (_isRecording) {
      await _stopAndSendRecording(workerId, service);
      return;
    }
    try {
      if (!await _audioRecorder.hasPermission()) {
        _showMessage('Microphone permission is required.');
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
      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordingPath = path;
        });
      }
    } catch (_) {
      _showMessage('Voice recording could not start.');
    }
  }

  Future<void> _stopAndSendRecording(String workerId, String service) async {
    try {
      final path = await _audioRecorder.stop() ?? _recordingPath;
      if (mounted) setState(() => _isRecording = false);
      if (path == null) return;
      if (mounted) setState(() => _isUploading = true);
      final reference = FirebaseStorage.instance.ref(
        'chat_audio/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await reference.putFile(
        File(path),
        SettableMetadata(contentType: 'audio/mp4'),
      );
      final url = await reference.getDownloadURL();
      await _send(workerId, service, {
        'type': 'audio',
        'text': '',
        'audioUrl': url,
      });
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      _showMessage('Voice message could not be sent.');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isRecording = false;
          _recordingPath = null;
        });
      }
    }
  }

  Future<void> _toggleAudio(String id, String url) async {
    try {
      if (_playingMessageId == id &&
          _audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.pause();
        if (mounted) setState(() {});
        return;
      }
      if (_playingMessageId != id) {
        await _audioPlayer.stop();
        setState(() {
          _playingMessageId = id;
          _audioPosition = Duration.zero;
          _audioDuration = Duration.zero;
          _audioLoading = true;
        });
        await _audioPlayer.play(UrlSource(url));
      } else {
        await _audioPlayer.resume();
      }
      if (mounted) setState(() => _audioLoading = false);
    } catch (_) {
      if (mounted) {
        setState(() => _audioLoading = false);
        _showMessage('Voice message could not be played.');
      }
    }
  }

  Future<void> _showMessageMenu(CustomerChatMessage message) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (!message.isDeleted)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['❤️', '👍', '😂', '😮', '😢', '🙏']
                      .map(
                        (emoji) => InkWell(
                          onTap: () {
                            Navigator.pop(sheetContext);
                            unawaited(
                              _dataSource.setReaction(
                                widget.chatId,
                                message.id,
                                emoji,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (!message.isDeleted)
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _replyingTo = message);
                },
              ),
            if (message.reactions.containsKey(_customerId))
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined),
                title: const Text('Remove reaction'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(
                    _dataSource.setReaction(widget.chatId, message.id, null),
                  );
                },
              ),
            if (message.senderId == _customerId && !message.isDeleted)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Delete for everyone'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_deleteMessage(message));
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(CustomerChatMessage message) async {
    try {
      await _dataSource.deleteMessage(widget.chatId, message);
    } catch (_) {
      _showMessage('Message could not be deleted.');
    }
  }

  Future<void> _openImage(String url) async {
    if (url.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: SafeArea(
            child: InteractiveViewer(
              minScale: .8,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loading) => loading == null
                      ? child
                      : const CircularProgressIndicator(color: Colors.white),
                  errorBuilder: (_, _, _) => const Text(
                    'Photo unavailable',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _viewProfile() {
    if (widget.onViewProfile != null) {
      widget.onViewProfile!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => WorkerPublicProfileScreen(workerId: widget.workerId),
      ),
    );
  }

  Future<void> _call(String phone) async {
    if (widget.onCall != null) {
      widget.onCall!();
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showMessage('The phone dialer is unavailable.');
    }
  }

  void _viewBooking(String requestId, String rawStatus) {
    if (widget.onViewBooking != null) {
      widget.onViewBooking!(requestId, rawStatus);
      return;
    }
    final status = bookingStatusOf(rawStatus);
    final screen = status.semantic == BookingSemanticStatus.onTheWay
        ? RequestTrackingScreen(requestId: requestId)
        : BookingDetailScreen(requestId: requestId);
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SkillNovaSpacing.sm),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SkillNovaSpacing.sm,
            ),
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _ThreadState extends StatelessWidget {
  const _ThreadState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SkillNovaSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 48),
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
          ],
        ),
      ),
    );
  }
}
