enum MessageRole { user, assistant }

enum ChatMessageType { text, actionCard }

enum ChatActionButtonStyle { primary, secondary, danger }

enum ChatActionStatus { idle, loading, success, error, cancelled }

class ChatActionRequest {
  final String method;
  final String path;
  final Map<String, dynamic>? body;
  final Map<String, dynamic>? queryParameters;

  const ChatActionRequest({
    required this.method,
    required this.path,
    this.body,
    this.queryParameters,
  });

  factory ChatActionRequest.fromJson(Map<String, dynamic> json) {
    return ChatActionRequest(
      method: (ChatMessage._readString(json, const ['method', 'httpMethod']) ?? 'POST')
          .toUpperCase(),
      path: ChatMessage._readString(json, const ['path', 'url', 'endpoint']) ?? '',
      body: ChatMessage._readMap(json, const ['body', 'payload', 'data']),
      queryParameters: ChatMessage._readMap(
        json,
        const ['queryParameters', 'query', 'params'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'path': path,
      if (body != null) 'body': body,
      if (queryParameters != null) 'queryParameters': queryParameters,
    };
  }
}

class ChatActionButton {
  final String id;
  final String label;
  final String actionType;
  final ChatActionButtonStyle style;
  final ChatActionRequest? request;

  const ChatActionButton({
    required this.id,
    required this.label,
    required this.actionType,
    required this.style,
    this.request,
  });

  bool get isUndoAction {
    final normalized = actionType.toLowerCase();
    return normalized.contains('undo') ||
        normalized.contains('revoke') ||
        normalized.contains('rollback') ||
        normalized.contains('withdraw');
  }

  bool get isCancelAction {
    final normalized = actionType.toLowerCase();
    return normalized.contains('cancel') ||
        normalized.contains('dismiss') ||
        normalized.contains('keep') ||
        normalized.contains('close');
  }

  factory ChatActionButton.fromJson(Map<String, dynamic> json) {
    final requestJson = ChatMessage._readMap(
      json,
      const ['request', 'api', 'http', 'invoke'],
    );

    return ChatActionButton(
      id: ChatMessage._readString(json, const ['id', 'actionId', 'key']) ?? '',
      label: ChatMessage._readString(json, const ['label', 'text', 'title', 'name']) ?? '确认',
      actionType: ChatMessage._readString(
            json,
            const ['actionType', 'type', 'intent', 'action'],
          ) ??
          'custom',
      style: _parseStyle(
        ChatMessage._readString(json, const ['style', 'variant', 'buttonStyle']),
      ),
      request: requestJson == null ? null : ChatActionRequest.fromJson(requestJson),
    );
  }

  ChatActionButton copyWith({
    String? id,
    String? label,
    String? actionType,
    ChatActionButtonStyle? style,
    ChatActionRequest? request,
  }) {
    return ChatActionButton(
      id: id ?? this.id,
      label: label ?? this.label,
      actionType: actionType ?? this.actionType,
      style: style ?? this.style,
      request: request ?? this.request,
    );
  }

  static ChatActionButtonStyle _parseStyle(String? value) {
    final normalized = value?.toLowerCase() ?? '';
    if (normalized.contains('danger') || normalized.contains('warn')) {
      return ChatActionButtonStyle.danger;
    }
    if (normalized.contains('secondary') || normalized.contains('ghost')) {
      return ChatActionButtonStyle.secondary;
    }
    return ChatActionButtonStyle.primary;
  }
}

class ChatActionField {
  final String label;
  final String value;

  const ChatActionField({required this.label, required this.value});

  factory ChatActionField.fromJson(Map<String, dynamic> json) {
    return ChatActionField(
      label: ChatMessage._readString(json, const ['label', 'title', 'name']) ?? '',
      value: ChatMessage._readString(json, const ['value', 'content', 'text']) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'value': value,
    };
  }
}

class ChatActionCard {
  final String title;
  final String? subtitle;
  final String? badge;
  final List<ChatActionField> fields;
  final List<ChatActionButton> actions;
  final ChatActionStatus status;
  final String? statusText;
  final String? errorMessage;

  const ChatActionCard({
    required this.title,
    this.subtitle,
    this.badge,
    required this.fields,
    required this.actions,
    this.status = ChatActionStatus.idle,
    this.statusText,
    this.errorMessage,
  });

  bool get isLoading => status == ChatActionStatus.loading;
  bool get isFinished =>
      status == ChatActionStatus.success ||
      status == ChatActionStatus.cancelled;

  factory ChatActionCard.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'];
    final rawActions = json['actions'] ?? json['buttons'];
    final cardLevelRequest = ChatMessage._readMap(
      json,
      const ['request', 'api', 'http', 'invoke'],
    );

    final fields = rawFields is List
        ? rawFields
              .whereType<Map>()
              .map((item) => ChatActionField.fromJson(Map<String, dynamic>.from(item)))
              .where((item) => item.label.isNotEmpty || item.value.isNotEmpty)
              .toList()
        : _buildFallbackFields(json);

    final actions = rawActions is List
        ? rawActions
              .whereType<Map>()
              .map((item) {
                final mapped = Map<String, dynamic>.from(item);
                if (cardLevelRequest != null && mapped['request'] == null) {
                  mapped['request'] = cardLevelRequest;
                }
                return ChatActionButton.fromJson(mapped);
              })
              .where((item) => item.label.trim().isNotEmpty)
              .toList()
        : _buildFallbackActions(json, cardLevelRequest);

    return ChatActionCard(
      title: ChatMessage._readString(json, const ['title', 'cardTitle', 'name']) ?? '操作确认',
      subtitle: ChatMessage._readString(
        json,
        const ['subtitle', 'description', 'message', 'summary'],
      ),
      badge: ChatMessage._readString(json, const ['badge', 'tag', 'statusLabel', 'cardType']),
      fields: fields,
      actions: actions,
      status: _parseStatus(
        ChatMessage._readString(json, const ['status', 'actionStatus', 'cardStatus']),
      ),
      statusText: ChatMessage._readString(
        json,
        const ['statusText', 'resultText', 'result', 'feedback'],
      ),
      errorMessage: ChatMessage._readString(
        json,
        const ['errorMessage', 'error', 'failureReason'],
      ),
    );
  }

  ChatActionCard copyWith({
    String? title,
    String? subtitle,
    String? badge,
    List<ChatActionField>? fields,
    List<ChatActionButton>? actions,
    ChatActionStatus? status,
    String? statusText,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ChatActionCard(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      badge: badge ?? this.badge,
      fields: fields ?? this.fields,
      actions: actions ?? this.actions,
      status: status ?? this.status,
      statusText: statusText ?? this.statusText,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (badge != null) 'badge': badge,
      if (fields.isNotEmpty) 'fields': fields.map((item) => item.toJson()).toList(),
      if (actions.isNotEmpty)
        'actions': actions
            .map(
              (item) => {
                'id': item.id,
                'label': item.label,
                'actionType': item.actionType,
                'style': item.style.name,
                if (item.request != null) 'request': item.request!.toJson(),
              },
            )
            .toList(),
      'status': status.name,
      if (statusText != null) 'statusText': statusText,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  static ChatActionStatus _parseStatus(String? value) {
    final normalized = value?.toLowerCase() ?? '';
    if (normalized.contains('load') || normalized.contains('pending')) {
      return ChatActionStatus.loading;
    }
    if (normalized.contains('success') || normalized.contains('done')) {
      return ChatActionStatus.success;
    }
    if (normalized.contains('error') || normalized.contains('fail')) {
      return ChatActionStatus.error;
    }
    if (normalized.contains('cancel') || normalized.contains('keep')) {
      return ChatActionStatus.cancelled;
    }
    return ChatActionStatus.idle;
  }

  static List<ChatActionField> _buildFallbackFields(Map<String, dynamic> json) {
    final fields = <ChatActionField>[];
    final recommendationId = ChatMessage._readString(json, const ['recommendationId']);
    final recordId = ChatMessage._readString(json, const ['recordId']);

    if (recommendationId != null) {
      fields.add(ChatActionField(label: '推荐记录', value: recommendationId));
    }
    if (recordId != null) {
      fields.add(ChatActionField(label: '打卡记录', value: recordId));
    }
    return fields;
  }

  static List<ChatActionButton> _buildFallbackActions(
    Map<String, dynamic> json,
    Map<String, dynamic>? cardLevelRequest,
  ) {
    final confirmText = ChatMessage._readString(
      json,
      const ['confirmText', 'confirmLabel', 'primaryText'],
    );
    final actionType = ChatMessage._readString(
      json,
      const ['actionType', 'confirmActionType', 'intent'],
    );

    if ((confirmText ?? '').trim().isEmpty && (actionType ?? '').trim().isEmpty) {
      return const [];
    }

    return [
      ChatActionButton.fromJson({
        'id': 'confirm',
        'label': confirmText ?? '确认',
        'actionType': actionType ?? 'custom',
        'style': 'danger',
        'request': cardLevelRequest,
      }),
      ChatActionButton.fromJson({
        'id': 'cancel',
        'label': '取消',
        'actionType': 'cancel',
        'style': 'secondary',
      }),
    ];
  }
}

class ChatMessage {
  final String? id;
  final MessageRole role;
  final ChatMessageType type;
  final String content;
  final DateTime timestamp;
  final ChatActionCard? actionCard;
  final List<dynamic>? renderBlocks;

  ChatMessage({
    this.id,
    required this.role,
    this.type = ChatMessageType.text,
    required this.content,
    required this.timestamp,
    this.actionCard,
    this.renderBlocks,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final messageType = _parseMessageType(json);
    final cardJson = _extractActionCardJson(json);
    final card = cardJson == null ? null : ChatActionCard.fromJson(cardJson);
    final blocks = json['renderBlocks'] as List<dynamic>?;

    return ChatMessage(
      id: _readString(json, const ['id', 'messageId', 'chatId']),
      role: _parseRole(json),
      type: messageType,
      content: _readString(
            json,
            const ['content', 'message', 'text', 'description', 'reply'],
          ) ??
          '',
      timestamp: _parseTimestamp(
            json['timestamp'] ??
                json['createTime'] ??
                json['createdAt'] ??
                json['time'] ??
                json['sendTime'],
          ) ??
          DateTime.now(),
      actionCard: messageType == ChatMessageType.actionCard ? card : null,
      renderBlocks: blocks,
    );
  }

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get hasVisibleContent =>
      content.trim().isNotEmpty || actionCard != null || (renderBlocks?.isNotEmpty ?? false);

  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    ChatMessageType? type,
    String? content,
    DateTime? timestamp,
    ChatActionCard? actionCard,
    List<dynamic>? renderBlocks,
    bool clearActionCard = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      type: type ?? this.type,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      actionCard: clearActionCard ? null : (actionCard ?? this.actionCard),
      renderBlocks: renderBlocks ?? this.renderBlocks,
    );
  }

  static ChatMessageType _parseMessageType(Map<String, dynamic> json) {
    final explicitType = _readString(
      json,
      const ['messageType', 'contentType', 'renderType', 'cardType'],
    );
    final cardJson = _extractActionCardJson(json);
    final hasCard = cardJson != null;
    final normalized = explicitType?.toLowerCase() ?? '';

    if (hasCard ||
        normalized.contains('card') ||
        normalized.contains('action') ||
        normalized.contains('structured')) {
      return ChatMessageType.actionCard;
    }
    return ChatMessageType.text;
  }

  static MessageRole _parseRole(Map<String, dynamic> json) {
    final roleValue = _readString(
      json,
      const ['role', 'messageRole', 'senderRole', 'senderType', 'type'],
    );
    if (roleValue != null) {
      final normalized = roleValue.toLowerCase();
      if (normalized.contains('user') ||
          normalized.contains('human') ||
          normalized.contains('client') ||
          normalized == 'q') {
        return MessageRole.user;
      }
      if (normalized.contains('assistant') ||
          normalized.contains('ai') ||
          normalized.contains('bot') ||
          normalized == 'a') {
        return MessageRole.assistant;
      }
    }

    final isUser = json['isUser'];
    if (isUser is bool) {
      return isUser ? MessageRole.user : MessageRole.assistant;
    }

    final fromUser = json['fromUser'];
    if (fromUser is bool) {
      return fromUser ? MessageRole.user : MessageRole.assistant;
    }

    return MessageRole.assistant;
  }

  static Map<String, dynamic>? _extractActionCardJson(Map<String, dynamic> json) {
    final directCard = _readMap(
      json,
      const ['actionCard', 'card', 'structuredContent', 'payload'],
    );
    if (directCard != null) {
      return directCard;
    }

    final hasActions = json['actions'] is List || json['buttons'] is List;
    final hasFields = json['fields'] is List;
    if (hasActions || hasFields) {
      return json;
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  static Map<String, dynamic>? _readMap(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }
    return null;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      final isMillis = value > 1000000000000;
      return DateTime.fromMillisecondsSinceEpoch(isMillis ? value : value * 1000);
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      final asInt = int.tryParse(trimmed);
      if (asInt != null) {
        return _parseTimestamp(asInt);
      }
      return DateTime.tryParse(trimmed);
    }
    return null;
  }
}

class ChatHistoryPage {
  final List<ChatMessage> messages;
  final int pageNum;
  final int pageSize;
  final bool hasMore;

  const ChatHistoryPage({
    required this.messages,
    required this.pageNum,
    required this.pageSize,
    required this.hasMore,
  });
}
