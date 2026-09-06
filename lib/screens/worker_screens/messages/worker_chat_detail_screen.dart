import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/customer_screens/chat/chat_components.dart';
import 'package:skill_link/screens/customer_screens/chat/chat_models.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_detail_screen.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_models.dart';
import 'package:url_launcher/url_launcher.dart';

import 'worker_chat_models.dart';
import 'worker_chat_repository.dart';

class WorkerChatDetailV2Screen extends StatefulWidget {
  const WorkerChatDetailV2Screen({
    super.key,
    required this.chatId,
    required this.customerId,
    required this.customerName,
    required this.service,
    this.requestId = '',
    this.dataSource,
    this.onViewJob,
    this.onCall,
  });

  final String chatId;
  final String customerId;
  final String customerName;
  final String service;
  final String requestId;
  final WorkerChatDataSource? dataSource;
  final ValueChanged<String>? onViewJob;
  final ValueChanged<String>? onCall;

  @override
  State<WorkerChatDetailV2Screen> createState() =>
      _WorkerChatDetailV2ScreenState();
}

class _WorkerChatDetailV2ScreenState extends State<WorkerChatDetailV2Screen> {
  late final WorkerChatDataSource _dataSource;
  late final Stream<WorkerChatContext?> _chatStream;
  late final Stream<CustomerMessagePage> _latestMessagesStream;
  final Map<String, Stream<WorkerChatCustomer?>> _customerStreams = {};
  final Map<String, Stream<WorkerChatRequest?>> _requestStreams = {};
  final Map<String, CustomerChatMessage> _olderMessages = {};
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Stopwatch _recordingClock = Stopwatch();

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

  String get _workerId => _dataSource.workerId;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? FirebaseWorkerChatRepository();
    _chatStream = _dataSource.watchChat(widget.chatId);
    _latestMessagesStream = _dataSource.watchLatestMessages(
      widget.chatId,
      pageSize: workerMessagePageSize,
    );
    _messageController.addListener(_handleTyping);
    _scrollController.addListener(_handleScroll);
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _audioDuration = duration);
    });
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _audioPosition = position);
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
    _recordingClock.stop();
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
      // Typing is ephemeral and must not block messaging.
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WorkerChatContext?>(
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
          return _unavailable();
        }
        final customerStream = _customerStreams.putIfAbsent(
          chat.customerId,
          () => _dataSource.watchCustomer(chat.customerId),
        );
        return StreamBuilder<WorkerChatCustomer?>(
          stream: customerStream,
          builder: (context, customerSnapshot) {
            final customer = customerSnapshot.data;
            final name =
                customer?.name ??
                (widget.customerName.trim().isEmpty
                    ? 'Customer'
                    : widget.customerName.trim());
            final service = chat.service.isEmpty
                ? widget.service
                : chat.service;
            final requestId = chat.requestId.isEmpty
                ? widget.requestId
                : chat.requestId;
            if (requestId.isEmpty) {
              return _authorizedScaffold(chat, customer, name, service, null);
            }
            final requestStream = _requestStreams.putIfAbsent(
              requestId,
              () => _dataSource.watchRequest(requestId, chat.customerId),
            );
            return StreamBuilder<WorkerChatRequest?>(
              stream: requestStream,
              builder: (context, requestSnapshot) {
                if (requestSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !requestSnapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final request = requestSnapshot.data;
                if (requestSnapshot.hasError || request == null) {
                  return _unavailable();
                }
                return _authorizedScaffold(
                  chat,
                  customer,
                  name,
                  request.service.isEmpty ? service : request.service,
                  request,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _authorizedScaffold(
    WorkerChatContext chat,
    WorkerChatCustomer? customer,
    String name,
    String service,
    WorkerChatRequest? request,
  ) {
    final phone = request == null ? '' : customer?.phone ?? '';
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 0,
        title: _WorkerChatHeader(
          name: name,
          service: service,
          photoUrl: customer?.photoUrl ?? '',
          onCall: phone.isEmpty ? null : () => _call(phone),
        ),
        actions: [
          PopupMenuButton<bool>(
            tooltip: 'Conversation options',
            onSelected: (_) => _toggleArchive(chat.archived),
            itemBuilder: (_) => [
              PopupMenuItem<bool>(
                value: true,
                child: Text(
                  chat.archived
                      ? 'Restore conversation'
                      : 'Archive conversation',
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (request != null)
              _WorkerJobContext(
                request: request,
                canViewJob: _canViewJob(request.status),
                onViewJob: () => _viewJob(request.id),
              ),
            Expanded(child: _messages(chat, name)),
            if (chat.customerTyping) TypingIndicator(workerName: name),
            if (_isRecording) _RecordingBanner(onCancel: _cancelRecording),
            MessageComposer(
              controller: _messageController,
              isRecording: _isRecording,
              isUploading: _isUploading,
              onSend: () => _sendText(chat.customerId, service),
              onAttachment: () => _pickAndSendImage(chat.customerId, service),
              onMicrophone: () => _toggleRecording(chat.customerId, service),
              replyLabel: _replyingTo == null
                  ? null
                  : 'Replying to ${_replyingTo!.senderId == _workerId ? 'yourself' : name}: ${_replyingTo!.replyPreview}',
              onCancelReply: () => setState(() => _replyingTo = null),
            ),
          ],
        ),
      ),
    );
  }

  Scaffold _unavailable() {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: const _ThreadState(
        icon: Icons.lock_outline_rounded,
        title: 'Conversation unavailable',
        description: 'This chat is not available to your worker account.',
      ),
    );
  }

  Widget _messages(WorkerChatContext chat, String customerName) {
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
            description: 'Message $customerName about ${chat.service}.',
          );
        }
        _scheduleInitialScroll();
        _scheduleRead(chat, messages);
        return ListView.builder(
          key: const ValueKey('worker-chat-message-list'),
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
            final storedDuration = Duration(
              milliseconds: chatInt(
                message.data['durationMs'] ?? message.data['audioDurationMs'],
              ),
            );
            return Column(
              children: [
                if (showDay)
                  _DaySeparator(label: messageDay(message.createdAt)),
                MessageBubble(
                  message: message,
                  currentUserId: _workerId,
                  workerName: customerName,
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
                        ? (_audioDuration == Duration.zero
                              ? storedDuration
                              : _audioDuration)
                        : storedDuration,
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
        pageSize: workerMessagePageSize,
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
        final added = _scrollController.position.maxScrollExtent - oldMax;
        _scrollController.jumpTo(
          (_scrollController.position.pixels + added).clamp(
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
    WorkerChatContext chat,
    List<CustomerChatMessage> messages,
  ) {
    final latest = messages.last;
    if (latest.id == _lastReadMessageId ||
        latest.senderId == _workerId ||
        latest.status == CustomerMessageStatus.seen) {
      return;
    }
    _lastReadMessageId = latest.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_markReadSafely(chat.lastMessageTime));
    });
  }

  Future<void> _markReadSafely(dynamic observedLastMessageTime) async {
    try {
      await _dataSource.markConversationRead(
        widget.chatId,
        observedLastMessageTime: observedLastMessageTime,
      );
    } catch (_) {
      // Read receipts can retry on the next incoming snapshot/open.
    }
  }

  Future<void> _sendText(String customerId, String service) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _workerId.isEmpty) return;
    _messageController.clear();
    await _send(customerId, service, {'type': 'text', 'text': text});
  }

  Future<void> _send(
    String customerId,
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
            'text': reply.replyPreview.isEmpty
                ? 'Original message unavailable'
                : reply.replyPreview,
          };
    try {
      await _setTypingSafely(false);
      await _dataSource.sendMessage(
        widget.chatId,
        customerId: customerId,
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

  Future<void> _pickAndSendImage(String customerId, String service) async {
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
      await _send(customerId, service, {
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

  Future<void> _toggleRecording(String customerId, String service) async {
    if (_isRecording) {
      await _stopAndSendRecording(customerId, service);
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
      _recordingClock
        ..reset()
        ..start();
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

  Future<void> _stopAndSendRecording(String customerId, String service) async {
    try {
      final path = await _audioRecorder.stop() ?? _recordingPath;
      _recordingClock.stop();
      final durationMs = _recordingClock.elapsedMilliseconds;
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
      await _send(customerId, service, {
        'type': 'audio',
        'text': '',
        'audioUrl': url,
        'durationMs': durationMs,
      });
      await _deleteLocalRecording(path);
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

  Future<void> _cancelRecording() async {
    final path = await _audioRecorder.stop() ?? _recordingPath;
    _recordingClock
      ..stop()
      ..reset();
    if (path != null) await _deleteLocalRecording(path);
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingPath = null;
      });
    }
  }

  Future<void> _deleteLocalRecording(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
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
            if (message.reactions.containsKey(_workerId))
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
            if (message.senderId == _workerId && !message.isDeleted)
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

  bool _canViewJob(String status) {
    return const {
      'accepted',
      'on_the_way',
      'on the way',
      'ontheway',
      'in_progress',
      'in progress',
      'started',
      'completed',
      'cancelled',
      'canceled',
      'rejected',
    }.contains(status);
  }

  void _viewJob(String requestId) {
    final callback = widget.onViewJob;
    if (callback != null) {
      callback(requestId);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => WorkerJobDetailV2Screen(requestId: requestId),
      ),
    );
  }

  Future<void> _call(String phone) async {
    final callback = widget.onCall;
    if (callback != null) {
      callback(phone);
      return;
    }
    final opened = await launchUrl(Uri(scheme: 'tel', path: phone.trim()));
    if (!opened && mounted) _showMessage('The phone dialer is unavailable.');
  }

  Future<void> _toggleArchive(bool archived) async {
    try {
      await _dataSource.setArchived(widget.chatId, !archived);
      if (mounted) {
        _showMessage(
          archived ? 'Conversation restored.' : 'Conversation archived.',
        );
      }
    } catch (_) {
      _showMessage('The conversation could not be updated.');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _WorkerChatHeader extends StatelessWidget {
  const _WorkerChatHeader({
    required this.name,
    required this.service,
    required this.photoUrl,
    this.onCall,
  });

  final String name;
  final String service;
  final String photoUrl;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Center(
      child: Text(
        name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase(),
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
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
        ),
        const SizedBox(width: SkillNovaSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              Text(
                service,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (onCall != null)
          IconButton(
            key: const ValueKey('worker-chat-call'),
            tooltip: 'Call customer',
            onPressed: onCall,
            icon: const Icon(Icons.call_outlined),
          ),
      ],
    );
  }
}

class _WorkerJobContext extends StatelessWidget {
  const _WorkerJobContext({
    required this.request,
    required this.canViewJob,
    required this.onViewJob,
  });

  final WorkerChatRequest request;
  final bool canViewJob;
  final VoidCallback onViewJob;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = workerJobStatusOf(request.status);
    final statusLabel = status.status == WorkerJobStatus.unknown
        ? request.status == 'searching'
              ? 'Searching'
              : 'Status unavailable'
        : status.label;
    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        key: const ValueKey('worker-chat-job-context'),
        padding: const EdgeInsets.symmetric(
          horizontal: SkillNovaSpacing.md,
          vertical: SkillNovaSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.work_outline_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: SkillNovaSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.service,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(
                    request.budget.isEmpty
                        ? statusLabel
                        : '$statusLabel · Posted budget ${request.budget}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (canViewJob)
              TextButton(
                key: const ValueKey('worker-chat-view-job'),
                onPressed: onViewJob,
                child: const Text('View job'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecordingBanner extends StatelessWidget {
  const _RecordingBanner({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.mic_rounded, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Recording voice message')),
            TextButton(
              key: const ValueKey('worker-chat-cancel-recording'),
              onPressed: onCancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
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
          ],
        ),
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SkillNovaSpacing.sm),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
