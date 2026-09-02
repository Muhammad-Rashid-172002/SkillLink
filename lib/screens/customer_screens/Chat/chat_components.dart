import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_status.dart';

import 'chat_models.dart';

class ConversationSearchField extends StatelessWidget {
  const ConversationSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('conversation-search'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search conversations',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onArchive,
  });

  final CustomerConversation conversation;
  final VoidCallback onTap;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = conversation.unreadCount;
    return Semantics(
      button: true,
      label: unread > 0
          ? '${conversation.workerName}, $unread unread messages'
          : 'Conversation with ${conversation.workerName}',
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
        child: InkWell(
          key: ValueKey('conversation-${conversation.id}'),
          onTap: onTap,
          onLongPress: onArchive,
          borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
          child: Container(
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.all(SkillNovaSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
              border: Border.all(
                color: unread > 0
                    ? theme.colorScheme.primary.withValues(alpha: .32)
                    : theme.colorScheme.outlineVariant,
              ),
              boxShadow: SkillNovaElevation.subtle,
            ),
            child: Row(
              children: [
                _ChatAvatar(
                  name: conversation.workerName,
                  imageUrl: conversation.workerPhoto,
                  size: 54,
                  key: ValueKey(
                    conversation.workerPhoto.isEmpty
                        ? 'conversation-photo-fallback-${conversation.id}'
                        : 'conversation-photo-${conversation.id}',
                  ),
                ),
                const SizedBox(width: SkillNovaSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    conversation.workerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: unread > 0
                                              ? FontWeight.w800
                                              : FontWeight.w700,
                                        ),
                                  ),
                                ),
                                if (conversation.workerVerified) ...[
                                  const SizedBox(width: 4),
                                  Tooltip(
                                    message: 'Identity verified',
                                    child: Icon(
                                      Icons.verified_rounded,
                                      size: 17,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: SkillNovaSpacing.xs),
                          Text(
                            conversationTime(conversation.updatedAt),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        conversation.service,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (conversation.lastMessageType == 'image') ...[
                            const Icon(Icons.photo_outlined, size: 15),
                            const SizedBox(width: 4),
                          ] else if (conversation.lastMessageType == 'audio' ||
                              conversation.lastMessageType == 'voice') ...[
                            const Icon(Icons.mic_none_rounded, size: 15),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              conversation.latestPreview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: unread > 0
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(width: SkillNovaSpacing.xs),
                            Container(
                              key: ValueKey(
                                'conversation-unread-${conversation.id}',
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
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
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
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
}

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.name,
    required this.skill,
    required this.photoUrl,
    required this.verified,
    required this.onViewProfile,
    this.onCall,
  });

  final String name;
  final String skill;
  final String photoUrl;
  final bool verified;
  final VoidCallback onViewProfile;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _ChatAvatar(name: name, imageUrl: photoUrl, size: 44),
        const SizedBox(width: SkillNovaSpacing.sm),
        Expanded(
          child: InkWell(
            key: const ValueKey('chat-view-profile'),
            onTap: onViewProfile,
            borderRadius: BorderRadius.circular(SkillNovaRadius.small),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified_rounded,
                          color: theme.colorScheme.primary,
                          size: 17,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    skill,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onCall != null)
          IconButton(
            key: const ValueKey('chat-call'),
            tooltip: 'Call professional',
            onPressed: onCall,
            icon: const Icon(Icons.call_outlined),
          ),
      ],
    );
  }
}

class BookingContextBanner extends StatelessWidget {
  const BookingContextBanner({
    super.key,
    required this.service,
    required this.status,
    required this.onTap,
  });

  final String service;
  final BookingStatusPresentation status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        key: const ValueKey('chat-booking-context'),
        onTap: onTap,
        child: Container(
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(SkillNovaRadius.small),
                ),
                child: Icon(status.icon, color: status.color, size: 21),
              ),
              const SizedBox(width: SkillNovaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                    Text(status.label, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Text('View booking', style: theme.textTheme.labelMedium),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageReplyPreview extends StatelessWidget {
  const MessageReplyPreview({
    super.key,
    required this.reply,
    required this.currentUserId,
    required this.workerName,
  });

  final Map<String, dynamic> reply;
  final String currentUserId;
  final String workerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(SkillNovaSpacing.xs),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(SkillNovaRadius.small),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply['senderId'] == currentUserId ? 'You' : workerName,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            reply['text']?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class ImageMessageBubble extends StatelessWidget {
  const ImageMessageBubble({
    super.key,
    required this.imageUrl,
    required this.onOpen,
  });

  final String imageUrl;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240, maxHeight: 260),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SkillNovaRadius.small),
          child: imageUrl.isEmpty
              ? _attachmentError(context, 'Photo unavailable')
              : InkWell(
                  key: const ValueKey('chat-image-message'),
                  onTap: onOpen,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loading) => loading == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                    errorBuilder: (_, _, _) =>
                        _attachmentError(context, 'Photo unavailable'),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _attachmentError(BuildContext context, String label) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class AudioMessageBubble extends StatelessWidget {
  const AudioMessageBubble({
    super.key,
    required this.playing,
    required this.loading,
    required this.position,
    required this.duration,
    required this.onToggle,
    required this.onSeek,
  });

  final bool playing;
  final bool loading;
  final Duration position;
  final Duration duration;
  final VoidCallback? onToggle;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();
    return SizedBox(
      key: const ValueKey('chat-audio-message'),
      width: 230,
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: playing ? 'Pause voice message' : 'Play voice message',
            onPressed: onToggle,
            icon: loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
          ),
          Expanded(
            child: Slider(
              value: value,
              max: max,
              onChanged: duration.inMilliseconds > 0 ? onSeek : null,
            ),
          ),
          Text(
            _durationLabel(duration.inMilliseconds > 0 ? duration : position),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.workerName,
    required this.onReply,
    required this.onLongPress,
    required this.imageBuilder,
    required this.audioBuilder,
  });

  final CustomerChatMessage message;
  final String currentUserId;
  final String workerName;
  final VoidCallback onReply;
  final VoidCallback onLongPress;
  final Widget Function(String url) imageBuilder;
  final Widget Function(String messageId, String url) audioBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outgoing = message.senderId == currentUserId;
    final grouped = <String, int>{};
    for (final value in message.reactions.values) {
      grouped[value.toString()] = (grouped[value.toString()] ?? 0) + 1;
    }
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        label: outgoing ? 'Your message' : '$workerName message',
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 240) onReply();
          },
          onLongPress: onLongPress,
          child: Container(
            key: ValueKey('message-${message.id}'),
            margin: EdgeInsets.only(
              left: outgoing ? 42 : 0,
              right: outgoing ? 0 : 42,
              bottom: grouped.isEmpty ? 8 : 18,
            ),
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 7),
            decoration: BoxDecoration(
              color: outgoing
                  ? theme.colorScheme.primary.withValues(alpha: .12)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(SkillNovaRadius.medium),
                topRight: const Radius.circular(SkillNovaRadius.medium),
                bottomLeft: Radius.circular(
                  outgoing ? SkillNovaRadius.medium : 4,
                ),
                bottomRight: Radius.circular(
                  outgoing ? 4 : SkillNovaRadius.medium,
                ),
              ),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.replyTo != null && !message.isDeleted)
                      MessageReplyPreview(
                        reply: message.replyTo!,
                        currentUserId: currentUserId,
                        workerName: workerName,
                      ),
                    if (message.isDeleted)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.block_outlined, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Message deleted',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (message.type == 'image')
                      imageBuilder(message.imageUrl)
                    else if (message.type == 'audio' || message.type == 'voice')
                      audioBuilder(message.id, message.audioUrl)
                    else
                      Text(message.text, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            messageTime(message.createdAt),
                            style: theme.textTheme.bodySmall,
                          ),
                          if (outgoing) ...[
                            const SizedBox(width: 4),
                            _MessageStatus(status: message.status),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (grouped.isNotEmpty)
                  Positioned(
                    right: outgoing ? 0 : null,
                    left: outgoing ? null : 0,
                    bottom: -20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(
                          SkillNovaRadius.pill,
                        ),
                      ),
                      child: Text(
                        grouped.entries
                            .map(
                              (entry) => entry.value > 1
                                  ? '${entry.key} ${entry.value}'
                                  : entry.key,
                            )
                            .join(' '),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key, required this.workerName});

  final String workerName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$workerName is typing',
      child: Container(
        key: const ValueKey('chat-typing-indicator'),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        alignment: Alignment.centerLeft,
        child: Text(
          '$workerName is typing…',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class MessageComposer extends StatelessWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.isRecording,
    required this.isUploading,
    required this.onSend,
    required this.onAttachment,
    required this.onMicrophone,
    this.replyLabel,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final bool isRecording;
  final bool isUploading;
  final VoidCallback onSend;
  final VoidCallback onAttachment;
  final VoidCallback onMicrophone;
  final String? replyLabel;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyLabel != null)
                Row(
                  children: [
                    Icon(Icons.reply_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        replyLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel reply',
                      onPressed: onCancelReply,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    key: const ValueKey('chat-attachment'),
                    tooltip: 'Attach photo',
                    onPressed: isUploading ? null : onAttachment,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chat-composer-field'),
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: isRecording
                            ? 'Recording voice message…'
                            : 'Write a message…',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      return IconButton.filled(
                        key: ValueKey(
                          hasText ? 'chat-send' : 'chat-microphone',
                        ),
                        tooltip: hasText
                            ? 'Send message'
                            : isRecording
                            ? 'Stop recording'
                            : 'Record voice message',
                        onPressed: isUploading
                            ? null
                            : hasText
                            ? onSend
                            : onMicrophone,
                        icon: isUploading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                hasText
                                    ? Icons.send_rounded
                                    : isRecording
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                              ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.size,
  });

  final String name;
  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Center(
      child: Text(
        initialsFor(name),
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .10),
        shape: BoxShape.circle,
      ),
      child: imageUrl.isEmpty
          ? fallback
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class _MessageStatus extends StatelessWidget {
  const _MessageStatus({required this.status});

  final CustomerMessageStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      CustomerMessageStatus.sending => 'Sending',
      CustomerMessageStatus.sent => 'Sent',
      CustomerMessageStatus.delivered => 'Delivered',
      CustomerMessageStatus.seen => 'Seen',
    };
    final icon = switch (status) {
      CustomerMessageStatus.sending => Icons.schedule_rounded,
      CustomerMessageStatus.sent => Icons.check_rounded,
      CustomerMessageStatus.delivered ||
      CustomerMessageStatus.seen => Icons.done_all_rounded,
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Icon(
          icon,
          size: 16,
          color: status == CustomerMessageStatus.seen
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

String initialsFor(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  final values = words.take(2).toList();
  if (values.isEmpty) return 'SN';
  return values.map((word) => word.substring(0, 1).toUpperCase()).join();
}

String conversationTime(DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  if (DateUtils.isSameDay(date, now)) return DateFormat('h:mm a').format(date);
  final yesterday = now.subtract(const Duration(days: 1));
  if (DateUtils.isSameDay(date, yesterday)) return 'Yesterday';
  if (now.difference(date).inDays < 7) return DateFormat('EEE').format(date);
  return DateFormat('d MMM').format(date);
}

String messageTime(DateTime? date) =>
    date == null ? 'Sending…' : DateFormat('h:mm a').format(date);

String messageDay(DateTime? date) {
  if (date == null) return 'Today';
  final now = DateTime.now();
  if (DateUtils.isSameDay(date, now)) return 'Today';
  if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))) {
    return 'Yesterday';
  }
  return DateFormat(
    date.year == now.year ? 'd MMMM' : 'd MMMM yyyy',
  ).format(date);
}

String _durationLabel(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
