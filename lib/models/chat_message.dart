enum MessageRole { user, assistant }

class ChatMessage {
  final String? id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: _readString(json, const ['id', 'messageId', 'chatId']),
      role: _parseRole(json),
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
    );
  }

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

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
