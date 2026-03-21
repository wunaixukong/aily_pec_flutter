import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_ui.dart';

class ChatPage extends StatefulWidget {
  final int userId;
  final String? initialMessage;

  const ChatPage({
    super.key,
    required this.userId,
    this.initialMessage,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const int _pageSize = 20;

  final ApiService _apiService = ApiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _isLoadingHistory = true;
  bool _isLoadingMoreHistory = false;
  bool _hasMoreHistory = true;
  bool _planUpdated = false;
  bool _initialMessageHandled = false;
  String? _historyErrorMessage;
  int _nextHistoryPage = 1;
  final Queue<String> _streamBuffer = Queue<String>();
  Timer? _typingTimer;
  int? _streamingAssistantMessageIndex;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onComposerChanged);
    _scrollController.addListener(_handleScroll);
    _bootstrapChat();
  }

  @override
  void dispose() {
    _controller.removeListener(_onComposerChanged);
    _scrollController.removeListener(_handleScroll);
    _typingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapChat() async {
    try {
      await _loadChatHistory(initialLoad: true);
    } finally {
      final initialMessage = widget.initialMessage?.trim();
      if (!_initialMessageHandled && initialMessage != null && initialMessage.isNotEmpty) {
        _initialMessageHandled = true;
        unawaited(_sendMessage(initialMessage));
      }
    }
  }

  void _onComposerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.pixels <= 120) {
      unawaited(_loadChatHistory());
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _loadChatHistory({bool initialLoad = false}) async {
    if (initialLoad) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = true;
          _historyErrorMessage = null;
          _hasMoreHistory = true;
          _nextHistoryPage = 1;
        });
      }
    } else {
      if (_isLoadingHistory || _isLoadingMoreHistory || !_hasMoreHistory) {
        return;
      }
      if (mounted) {
        setState(() {
          _isLoadingMoreHistory = true;
          _historyErrorMessage = null;
        });
      }
    }

    final previousMaxScrollExtent = !initialLoad && _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final previousOffset =
        !initialLoad && _scrollController.hasClients ? _scrollController.offset : 0.0;

    try {
      final historyPage = await _apiService.getChatHistory(
        widget.userId,
        pageNum: _nextHistoryPage,
        pageSize: _pageSize,
      );

      if (!mounted) return;

      final mergedMessages = initialLoad
          ? _mergeMessages(historyPage.messages, const [])
          : _mergeMessages(historyPage.messages, _messages);

      setState(() {
        _messages
          ..clear()
          ..addAll(mergedMessages);
        _nextHistoryPage = historyPage.pageNum + 1;
        _hasMoreHistory = historyPage.hasMore && historyPage.messages.isNotEmpty;
        _isLoadingHistory = false;
        _isLoadingMoreHistory = false;
        _historyErrorMessage = null;
      });

      if (initialLoad) {
        _scrollToBottom(animated: false);
      } else {
        _preserveScrollPosition(previousMaxScrollExtent, previousOffset);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyErrorMessage = _normalizeError(e);
        _isLoadingHistory = false;
        _isLoadingMoreHistory = false;
      });
    }
  }

  void _preserveScrollPosition(double previousMaxScrollExtent, double previousOffset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final newMaxScrollExtent = _scrollController.position.maxScrollExtent;
      final delta = newMaxScrollExtent - previousMaxScrollExtent;
      _scrollController.jumpTo(previousOffset + delta);
    });
  }

  List<ChatMessage> _mergeMessages(List<ChatMessage> olderMessages, List<ChatMessage> newerMessages) {
    final seen = <String>{};
    final merged = <ChatMessage>[];

    void append(ChatMessage message) {
      final key =
          '${message.id ?? ''}|${message.role.name}|${message.type.name}|${message.timestamp.millisecondsSinceEpoch}|${message.content}|${message.actionCard?.toJson()}';
      if (seen.add(key)) {
        merged.add(message);
      }
    }

    for (final message in olderMessages) {
      append(message);
    }
    for (final message in newerMessages) {
      append(message);
    }

    merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return merged;
  }

  String _normalizeError(Object error) {
    final raw = error.toString();
    return raw.startsWith('Exception:') ? raw.substring('Exception:'.length).trim() : raw;
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        role: MessageRole.user,
        content: trimmed,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    _streamBuffer.clear();
    _typingTimer?.cancel();
    _typingTimer = null;
    _streamingAssistantMessageIndex = null;
    String fullContent = '';

    void ensureAssistantTextMessage() {
      if (_streamingAssistantMessageIndex != null) {
        return;
      }
      _messages.add(ChatMessage(
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
      ));
      _streamingAssistantMessageIndex = _messages.length - 1;
    }

    void syncAssistantMessage() {
      if (!mounted) return;
      final assistantIndex = _streamingAssistantMessageIndex;
      if (assistantIndex == null || assistantIndex >= _messages.length) {
        return;
      }
      setState(() {
        _messages[assistantIndex] = _messages[assistantIndex].copyWith(
          content: fullContent,
          timestamp: DateTime.now(),
          type: ChatMessageType.text,
          clearActionCard: true,
        );
      });
      _scrollToBottom();
    }

    void startTypingEffect() {
      _typingTimer ??= Timer.periodic(const Duration(milliseconds: 28), (timer) {
        if (_streamBuffer.isEmpty) {
          timer.cancel();
          _typingTimer = null;
          return;
        }

        ensureAssistantTextMessage();
        final chunk = _streamBuffer.removeFirst();
        final chars = chunk.characters.toList();
        final takeCount = chars.length >= 3 ? 2 : 1;
        final visible = chars.take(takeCount).join();
        final remain = chars.skip(takeCount).join();

        fullContent += visible;
        if (remain.isNotEmpty) {
          _streamBuffer.addFirst(remain);
        }
        syncAssistantMessage();
      });
    }

    Future<void> flushRemainingBuffer() async {
      if (_streamBuffer.isEmpty) {
        return;
      }
      ensureAssistantTextMessage();
      while (_streamBuffer.isNotEmpty) {
        fullContent += _streamBuffer.removeFirst();
      }
      syncAssistantMessage();
    }

    try {
      await for (final event in _apiService.chatWithAiStream(widget.userId, trimmed)) {
        if (event is ChatStreamBatchEvent) {
          for (final subEvent in event.events) {
            if (subEvent is ChatStreamTextEvent) {
              ensureAssistantTextMessage();
              _streamBuffer.add(subEvent.text);
              startTypingEffect();
              continue;
            }

            if (subEvent is ChatStreamCardEvent) {
              await flushRemainingBuffer();
              if (!mounted) return;
              setState(() {
                _messages.add(subEvent.message.copyWith(timestamp: DateTime.now()));
              });
              _scrollToBottom();
            }
          }
          continue;
        }

        if (event is ChatStreamTextEvent) {
          ensureAssistantTextMessage();
          _streamBuffer.add(event.text);
          startTypingEffect();
          continue;
        }

        if (event is ChatStreamCardEvent) {
          await flushRemainingBuffer();
          if (!mounted) return;
          setState(() {
            _messages.add(event.message.copyWith(timestamp: DateTime.now()));
          });
          _scrollToBottom();
          continue;
        }

        if (event is ChatStreamLifecycleEvent) {
          if (event.type == ChatStreamLifecycleType.complete) {
            _planUpdated = true;
            await flushRemainingBuffer();
          } else if (event.type == ChatStreamLifecycleType.error) {
            await flushRemainingBuffer();
            if (fullContent.isEmpty) {
              ensureAssistantTextMessage();
              fullContent = 'AI 服务出现错误，请稍后再试。';
              syncAssistantMessage();
            }
          }
        }
      }

      await flushRemainingBuffer();
    } catch (e, stack) {
      debugPrint('Chat Error: $e');
      debugPrint('Stack Trace: $stack');

      var errorMessage = _normalizeError(e);
      if (errorMessage.contains('解析流数据失败')) {
        errorMessage += '\n\n调试信息：请在 Android Studio Logcat 中过滤 "SSE RAW LINE" 或 "Chat Error" 查看原始输出。';
      }

      if (!mounted) return;
      setState(() {
        if (_streamingAssistantMessageIndex == null) {
          _messages.add(ChatMessage(
            role: MessageRole.assistant,
            content: '抱歉，出现了错误：$errorMessage',
            timestamp: DateTime.now(),
          ));
          _streamingAssistantMessageIndex = _messages.length - 1;
        } else {
          final assistantIndex = _streamingAssistantMessageIndex!;
          _messages[assistantIndex] = _messages[assistantIndex].copyWith(
            content: '抱歉，出现了错误：$errorMessage',
            timestamp: DateTime.now(),
            type: ChatMessageType.text,
            clearActionCard: true,
          );
        }
      });
    } finally {
      _typingTimer?.cancel();
      _typingTimer = null;
      _streamBuffer.clear();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _streamingAssistantMessageIndex = null;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _handleActionTap(int index, ChatActionButton action) async {
    final message = _messages[index];
    final card = message.actionCard;
    if (card == null) {
      return;
    }

    if (action.isCancelAction) {
      setState(() {
        _messages[index] = message.copyWith(
          actionCard: card.copyWith(
            status: ChatActionStatus.cancelled,
            statusText: '已取消撤回，当前打卡保持不变',
            clearErrorMessage: true,
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    if (!action.isUndoAction) {
      return;
    }

    setState(() {
      _messages[index] = message.copyWith(
        actionCard: card.copyWith(
          status: ChatActionStatus.loading,
          statusText: '正在撤回今日打卡...',
          clearErrorMessage: true,
        ),
      );
    });

    try {
      final result = await _apiService.executeChatAction(widget.userId, action);
      if (!mounted) return;
      setState(() {
        _messages[index] = _messages[index].copyWith(
          actionCard: _messages[index].actionCard?.copyWith(
            status: ChatActionStatus.success,
            statusText: result.message,
            badge: '已撤回',
            clearErrorMessage: true,
          ),
        );
        _planUpdated = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages[index] = _messages[index].copyWith(
          actionCard: _messages[index].actionCard?.copyWith(
            status: ChatActionStatus.error,
            statusText: '撤回失败，请重试',
            errorMessage: _normalizeError(e),
          ),
        );
      });
    } finally {
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context, _planUpdated),
        ),
        title: const Text(
          '智能助手',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoadingHistory && _messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_historyErrorMessage != null && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textMuted, size: 28),
              const SizedBox(height: AppSpacing.md),
              Text(
                _historyErrorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => _loadChatHistory(initialLoad: true),
                child: const Text('重新加载记录'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHistoryHeader();
        }
        final message = _messages[index - 1];
        return _buildMessageBubble(message, index - 1);
      },
    );
  }

  Widget _buildHistoryHeader() {
    if (_isLoadingMoreHistory) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary),
          ),
        ),
      );
    }

    if (_historyErrorMessage != null && _messages.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Center(
          child: TextButton(
            onPressed: _loadChatHistory,
            child: const Text('加载更多失败，点击重试'),
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.md),
        child: Center(
          child: Text(
            '还没有消息记录',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    if (_hasMoreHistory) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Center(
          child: TextButton(
            onPressed: _loadChatHistory,
            child: const Text('加载更早消息'),
          ),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Center(
        child: Text(
          '没有更多消息了',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: AppColors.primaryContainer,
              radius: 16,
              child: const Icon(Icons.smart_toy, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: message.type == ChatMessageType.actionCard && message.actionCard != null
                ? _buildActionCardMessage(message, index)
                : _buildTextMessageBubble(message),
          ),
          if (isUser) ...[
            const SizedBox(width: AppSpacing.xs),
            CircleAvatar(
              backgroundColor: AppColors.border,
              radius: 16,
              child: const Icon(Icons.person, size: 18, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isUser ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.md),
          topRight: const Radius.circular(AppRadius.md),
          bottomLeft: Radius.circular(isUser ? AppRadius.md : 4),
          bottomRight: Radius.circular(isUser ? 4 : AppRadius.md),
        ),
        boxShadow: isUser ? null : AppShadows.card.sublist(1),
      ),
      child: Text(
        message.content,
        style: TextStyle(
          color: isUser ? Colors.white : AppColors.textPrimary,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildActionCardMessage(ChatMessage message, int index) {
    final card = message.actionCard!;
    final statusColor = _statusColor(card.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content.trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.card.sublist(1),
            ),
            child: Text(
              message.content,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        AppSurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppRadius.lg,
          border: Border.all(color: statusColor.withValues(alpha: 0.18)),
          boxShadow: AppShadows.card.sublist(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (card.subtitle != null && card.subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            card.subtitle!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if ((card.badge ?? '').trim().isNotEmpty)
                    AppBadge(
                      label: card.badge!,
                      color: statusColor,
                      icon: _statusIcon(card.status),
                    ),
                ],
              ),
              if (card.fields.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ...card.fields.map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field.label,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            field.value,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (card.statusText != null && card.statusText!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (card.isLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(_statusIcon(card.status), size: 16, color: statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          card.statusText!,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (card.errorMessage != null && card.errorMessage!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  card.errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
              if (card.actions.isNotEmpty && !card.isFinished) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: card.actions
                      .map((action) => _buildActionButton(action, card, index))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(ChatActionButton action, ChatActionCard card, int index) {
    final isLoading = card.isLoading && action.isUndoAction;

    if (action.style == ChatActionButtonStyle.secondary) {
      return OutlinedButton(
        onPressed: card.isLoading ? null : () => _handleActionTap(index, action),
        child: Text(action.label),
      );
    }

    final backgroundColor = action.style == ChatActionButtonStyle.danger
        ? AppColors.error
        : AppColors.primary;

    return ElevatedButton(
      onPressed: card.isLoading ? null : () => _handleActionTap(index, action),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
      ),
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(action.label),
    );
  }

  Color _statusColor(ChatActionStatus status) {
    switch (status) {
      case ChatActionStatus.loading:
        return AppColors.warning;
      case ChatActionStatus.success:
        return AppColors.success;
      case ChatActionStatus.error:
        return AppColors.error;
      case ChatActionStatus.cancelled:
        return AppColors.textSecondary;
      case ChatActionStatus.idle:
        return AppColors.primary;
    }
  }

  IconData _statusIcon(ChatActionStatus status) {
    switch (status) {
      case ChatActionStatus.loading:
        return Icons.hourglass_top_rounded;
      case ChatActionStatus.success:
        return Icons.check_circle_rounded;
      case ChatActionStatus.error:
        return Icons.error_rounded;
      case ChatActionStatus.cancelled:
        return Icons.remove_circle_outline_rounded;
      case ChatActionStatus.idle:
        return Icons.undo_rounded;
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '描述你的感受或问题...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              maxLines: 5,
              minLines: 1,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: GestureDetector(
              onTap: _isLoading ? null : () => _sendMessage(_controller.text),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isLoading || _controller.text.trim().isEmpty
                      ? AppColors.border
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
