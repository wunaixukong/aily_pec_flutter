import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/user.dart';
import '../models/workout_plan.dart';
import '../models/api_response.dart';
import '../models/workout_record.dart';
import '../models/workout_recommendation.dart';

/// API 服务类 - 处理与后端的通信
class ApiService {
  // 远程服务器地址
  static const String baseUrl = 'http://123.207.199.246:8080';

  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    // 添加日志拦截器（调试用）
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  /// 获取所有用户
  Future<List<User>> getUsers() async {
    try {
      final response = await _dio.get('/users');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('获取用户列表失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 根据 ID 获取用户
  Future<User> getUserById(int id) async {
    try {
      final response = await _dio.get('/users/$id');

      if (response.statusCode == 200) {
        if (response.data is Map<String, dynamic>) {
          final apiResponse = ApiResponse<User>.fromJson(
            response.data as Map<String, dynamic>,
            (data) => User.fromJson(data as Map<String, dynamic>),
          );
          apiResponse.checkSuccess();
          return apiResponse.data!;
        }
        return User.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('获取用户失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 创建用户
  Future<User> createUser(User user) async {
    try {
      final response = await _dio.post('/users', data: user.toJson());

      if (response.statusCode == 201 || response.statusCode == 200) {
        return User.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('创建用户失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 更新用户
  Future<User> updateUser(int id, User user) async {
    try {
      final response = await _dio.put('/users/$id', data: user.toJson());

      if (response.statusCode == 200) {
        return User.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('更新用户失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 删除用户
  Future<void> deleteUser(int id) async {
    try {
      final response = await _dio.delete('/users/$id');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('删除用户失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  // ==================== 训练计划接口 ====================

  /// 创建训练计划
  Future<WorkoutPlan> createPlan(WorkoutPlan plan) async {
    try {
      final response = await _dio.post('/plans', data: plan.toJson());

      if (response.statusCode == 201 || response.statusCode == 200) {
        return WorkoutPlan.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('创建计划失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 编辑训练计划
  Future<WorkoutPlan> editPlan(WorkoutPlan plan) async {
    try {
      final response = await _dio.post('/plans/edit', data: plan.toJson());

      if (response.statusCode == 200) {
        // 后端返回统一响应格式 {"data": {...}, "success": true}
        final responseData = response.data as Map<String, dynamic>;
        final planData = responseData['data'] as Map<String, dynamic>;
        return WorkoutPlan.fromJson(planData);
      } else {
        throw Exception('编辑计划失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 获取用户的所有计划
  Future<List<WorkoutPlan>> getUserPlans(int userId) async {
    try {
      final response = await _dio.get('/plans/user/$userId');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((json) => WorkoutPlan.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('获取计划列表失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 获取当前激活的计划
  Future<WorkoutPlan> getActivePlan(int userId) async {
    try {
      final response = await _dio.get('/plans/active/$userId');

      if (response.statusCode == 200) {
        return WorkoutPlan.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('获取激活计划失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 激活指定计划
  Future<void> activatePlan(int planId, int userId) async {
    try {
      final response = await _dio.put('/plans/$planId/activate?userId=$userId');

      if (response.statusCode != 200) {
        throw Exception('激活计划失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 删除计划
  Future<void> deletePlan(int planId) async {
    try {
      final response = await _dio.delete('/plans/$planId');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('删除计划失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  // ==================== 今日训练接口 ====================

  /// 获取今天该练什么
  Future<WorkoutRecommendation> getTodayWorkout(int userId) async {
    try {
      final response = await _dio.get('/today/$userId');

      if (response.statusCode == 200) {
        // 处理统一响应格式
        if (response.data is Map<String, dynamic>) {
          final apiResponse = ApiResponse<WorkoutRecommendation>.fromJson(
            response.data as Map<String, dynamic>,
            (data) => WorkoutRecommendation.fromJson(data as Map<String, dynamic>),
          );
          apiResponse.checkSuccess();
          return apiResponse.data!;
        }
        throw Exception('API 返回格式错误');
      } else {
        throw Exception('获取今日训练失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 初始化进度指针
  Future<void> initProgress(int userId, int planId) async {
    try {
      final response = await _dio.post('/today/$userId/init', data: {'planId': planId});

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 处理统一响应格式
        if (response.data is Map<String, dynamic>) {
          final apiResponse = ApiResponse<dynamic>.fromJson(
            response.data as Map<String, dynamic>,
            null,
          );
          apiResponse.checkSuccess();
        }
      } else {
        throw Exception('初始化进度失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 完成今日训练（推进指针）
  Future<WorkoutRecommendation> completeTodayWorkout(int userId) async {
    try {
      final response = await _dio.post('/today/$userId/complete');

      if (response.statusCode == 200) {
        // 处理统一响应格式
        if (response.data is Map<String, dynamic>) {
          final apiResponse = ApiResponse<WorkoutRecommendation>.fromJson(
            response.data as Map<String, dynamic>,
            (data) => WorkoutRecommendation.fromJson(data as Map<String, dynamic>),
          );
          apiResponse.checkSuccess();
          return apiResponse.data!;
        }
        throw Exception('API 返回格式错误');
      } else {
        throw Exception('完成训练失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 获取聊天历史记录，按页加载旧消息
  Future<ChatHistoryPage> getChatHistory(
    int userId, {
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/message/$userId/history',
        queryParameters: {
          'pageNum': pageNum,
          'pageSize': pageSize,
          'page': pageNum,
          'size': pageSize,
        },
      );

      if (response.statusCode == 200) {
        return _parseChatHistoryPage(
          response.data,
          pageNum: pageNum,
          pageSize: pageSize,
        );
      }

      throw Exception('获取聊天记录失败: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 提交今日身体状态（例如：受伤、疲劳）- 流式对话版
  Stream<ChatStreamEvent> chatWithAiStream(int userId, String description) async* {
    try {
      final response = await _dio.post(
        '/message/$userId/chat/stream',
        data: {'description': description},
        options: Options(responseType: ResponseType.stream),
      );

      final Stream<List<int>> stream = (response.data.stream as Stream).cast<List<int>>();

      StringBuffer buffer = StringBuffer();
      String? currentEvent;
      final dataLines = <String>[];

      ChatStreamEvent? consumeCurrentEvent() {
        if (currentEvent == null && dataLines.isEmpty) {
          return null;
        }

        final event = (currentEvent ?? 'message').trim();
        final data = dataLines.join('\n').trim();
        debugPrint('--- SSE EVENT: $event | DATA: $data');

        currentEvent = null;
        dataLines.clear();

        if (data.isNotEmpty) {
          return _parseChatStreamEvent(event: event, data: data);
        }
        if (event == 'complete' || event == 'done' || event == 'error') {
          return ChatStreamLifecycleEvent(type: _mapLifecycleType(event));
        }
        return null;
      }

      await for (final chunk in stream) {
        final String chunkString = utf8.decode(chunk, allowMalformed: true);
        buffer.write(chunkString);

        String currentContent = buffer.toString();
        while (currentContent.contains('\n')) {
          final int index = currentContent.indexOf('\n');
          final String rawLine = currentContent.substring(0, index);
          currentContent = currentContent.substring(index + 1);
          buffer = StringBuffer(currentContent);

          final line = rawLine.replaceAll('\r', '');
          debugPrint('--- SSE RAW LINE: $line');

          if (line.isEmpty) {
            final parsed = consumeCurrentEvent();
            if (parsed != null) {
              yield parsed;
            }
            continue;
          }

          if (line.startsWith(':')) {
            continue;
          }

          if (line.startsWith('event:')) {
            currentEvent = line.substring(6).trim();
            continue;
          }

          if (line.startsWith('data:')) {
            dataLines.add(line.substring(5).trim());
            continue;
          }

          dataLines.add(line.trim());
        }
      }

      final parsed = consumeCurrentEvent();
      if (parsed != null) {
        yield parsed;
      }
    } on DioException catch (e) {
      debugPrint('Chat Dio Error: ${e.type} - ${e.message}');
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    } catch (e, stack) {
      debugPrint('Chat Stream Error: $e');
      debugPrint('Stack: $stack');
      throw Exception('解析流数据失败: $e');
    }
  }

  /// 执行聊天卡片动作（依赖后端返回的真实接口定义）
  Future<UndoWorkoutResult> executeChatAction(
    int userId,
    ChatActionButton action,
  ) async {
    final request = action.request;
    if (request == null || request.path.trim().isEmpty) {
      throw Exception('后端尚未提供可执行的撤回接口定义');
    }

    try {
      final method = request.method.toUpperCase();
      final mergedQuery = <String, dynamic>{...?request.queryParameters};
      mergedQuery.putIfAbsent('userId', () => userId);
      final payload = <String, dynamic>{...?request.body};
      payload.putIfAbsent('userId', () => userId);

      late final Response response;
      switch (method) {
        case 'GET':
          response = await _dio.get(request.path, queryParameters: mergedQuery);
          break;
        case 'PUT':
          response = await _dio.put(request.path, data: payload, queryParameters: mergedQuery);
          break;
        case 'PATCH':
          response = await _dio.patch(request.path, data: payload, queryParameters: mergedQuery);
          break;
        case 'DELETE':
          response = await _dio.delete(request.path, data: payload, queryParameters: mergedQuery);
          break;
        case 'POST':
        default:
          response = await _dio.post(request.path, data: payload, queryParameters: mergedQuery);
          break;
      }

      if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 204) {
        throw Exception('撤回失败: ${response.statusCode}');
      }

      final container = _unwrapResponseData(response.data);
      final latestRecord = _extractWorkoutRecord(container);
      final latestWorkout = _extractWorkoutRecommendation(container);
      final message = _extractResponseMessage(response.data) ?? '今日打卡已撤回';

      return UndoWorkoutResult(
        message: message,
        latestRecord: latestRecord,
        latestWorkout: latestWorkout,
        rawData: response.data,
      );
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 提交今日身体状态（例如：受伤、疲劳）
  Future<void> submitTodayStatus(int userId, String description) async {
    try {
      final response = await _dio.post(
        '/today/$userId/status',
        data: {'description': description},
      );

      if (response.statusCode == 200) {
        if (response.data is Map<String, dynamic>) {
          final apiResponse = ApiResponse<dynamic>.fromJson(
            response.data as Map<String, dynamic>,
            null,
          );
          apiResponse.checkSuccess();
        }
      } else {
        throw Exception('提交状态失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  // ==================== 训练记录接口 (文档对齐) ====================

  /// 获取所有训练记录列表
  Future<List<WorkoutRecord>> getRecordList(int userId) async {
    try {
      final response = await _dio.get('/record/list/$userId');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((json) => WorkoutRecord.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('获取记录列表失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 获取今日已练内容
  Future<WorkoutRecord?> getTodayRecord(int userId) async {
    try {
      final response = await _dio.get('/record/today/$userId');

      if (response.statusCode == 200) {
        if (response.data == null) return null;
        final List<dynamic> data = response.data as List<dynamic>;
        if (data.isEmpty) return null;
        // 返回今天的最新一条记录
        return WorkoutRecord.fromJson(data.first as Map<String, dynamic>);
      } else {
        throw Exception('获取今日记录失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  /// 保存训练记录
  Future<WorkoutRecord> saveRecord(WorkoutRecord record) async {
    try {
      final response = await _dio.post('/record/save', data: record.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final apiResponse = ApiResponse<WorkoutRecord>.fromJson(
          response.data as Map<String, dynamic>,
          (data) => WorkoutRecord.fromJson(data as Map<String, dynamic>),
        );
        apiResponse.checkSuccess();
        return apiResponse.data!;
      } else {
        throw Exception('保存记录失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
  }

  // ==================== 番茄钟配置接口 (仅记录，暂不调用) ====================

  /// 获取当前时间生效配置：GET /pomodoro/config/current/{userId}
  Future<dynamic> getCurrentPomodoroConfig(int userId) async {
    return _dio.get('/pomodoro/config/current/$userId');
  }

  /// 获取所有激活配置列表：GET /pomodoro/config/active-list/{userId}
  Future<dynamic> getActivePomodoroConfigs(int userId) async {
    return _dio.get('/pomodoro/config/active-list/$userId');
  }

  /// 创建/更新配置：POST /pomodoro/config
  Future<dynamic> savePomodoroConfig(Map<String, dynamic> config) async {
    return _dio.post('/pomodoro/config', data: config);
  }

  ChatHistoryPage _parseChatHistoryPage(
    dynamic rawData, {
    required int pageNum,
    required int pageSize,
  }) {
    final container = _unwrapResponseData(rawData);
    if (container is List) {
      final messages = _parseChatMessages(container);
      return ChatHistoryPage(
        messages: messages,
        pageNum: pageNum,
        pageSize: pageSize,
        hasMore: messages.length >= pageSize,
      );
    }

    if (container is! Map<String, dynamic>) {
      throw Exception('聊天记录返回格式错误');
    }

    final dataList = _extractMessageList(container);
    final messages = _parseChatMessages(dataList);
    final currentPage = _readInt(container, const ['pageNum', 'page', 'current']) ?? pageNum;
    final currentPageSize = _readInt(container, const ['pageSize', 'size']) ?? pageSize;
    final total = _readInt(container, const ['total', 'totalCount']);
    final explicitHasMore = _readBool(container, const ['hasMore', 'hasNext', 'more']);

    final hasMore = explicitHasMore ??
        (total != null
            ? currentPage * currentPageSize < total
            : messages.length >= currentPageSize);

    return ChatHistoryPage(
      messages: messages,
      pageNum: currentPage,
      pageSize: currentPageSize,
      hasMore: hasMore,
    );
  }

  dynamic _unwrapResponseData(dynamic rawData) {
    if (rawData is Map<String, dynamic>) {
      if (rawData['success'] == false) {
        throw Exception(rawData['message']?.toString() ?? '请求失败');
      }

      final data = rawData['data'];
      if (data is List || data is Map<String, dynamic>) {
        return data;
      }
    }
    return rawData;
  }

  List<dynamic> _extractMessageList(Map<String, dynamic> container) {
    const keys = ['records', 'list', 'items', 'rows', 'content', 'messages'];
    for (final key in keys) {
      final value = container[key];
      if (value is List) {
        return value;
      }
    }
    return const [];
  }

  List<ChatMessage> _parseChatMessages(List<dynamic> rawList) {
    final messages = rawList
        .whereType<Map>()
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .where((message) => message.hasVisibleContent)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  ChatStreamEvent? _parseChatStreamEvent({
    required String event,
    required String data,
  }) {
    if (data == '[DONE]') {
      return const ChatStreamLifecycleEvent(type: ChatStreamLifecycleType.complete);
    }

    if (data == 'complete') {
      return const ChatStreamLifecycleEvent(type: ChatStreamLifecycleType.complete);
    }

    if (data == 'error') {
      return const ChatStreamLifecycleEvent(type: ChatStreamLifecycleType.error);
    }

    final normalizedEvent = event.toLowerCase();

    try {
      if (data.startsWith('{') || data.startsWith('[')) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          final blockEvents = _parseBlockEvents(decoded);
          if (blockEvents.isNotEmpty) {
            return ChatStreamBatchEvent(events: blockEvents);
          }

          final explicitEvent = _readString(decoded, const ['event', 'type', 'messageType'])
              ?.toLowerCase();
          final resolvedEvent = explicitEvent ?? normalizedEvent;

          if (_isCardEvent(resolvedEvent, decoded)) {
            final message = ChatMessage.fromJson({
              ...decoded,
              'messageType': 'actionCard',
              'role': decoded['role'] ?? 'assistant',
              'timestamp': decoded['timestamp'] ?? DateTime.now().toIso8601String(),
            });
            return ChatStreamCardEvent(message: message);
          }

          if (_isLifecycleEvent(resolvedEvent)) {
            return ChatStreamLifecycleEvent(type: _mapLifecycleType(resolvedEvent));
          }

          final text = _readString(
                decoded,
                const ['content', 'text', 'message', 'reply', 'delta', 'data', 'assistantMessage'],
              ) ??
              '';
          if (text.isNotEmpty) {
            return ChatStreamTextEvent(text: text);
          }
        }
      }
    } catch (_) {
      // 降级为纯文本处理
    }

    if (_isLifecycleEvent(normalizedEvent)) {
      return ChatStreamLifecycleEvent(type: _mapLifecycleType(normalizedEvent));
    }

    return ChatStreamTextEvent(text: data);
  }

  bool _isCardEvent(String event, Map<String, dynamic> json) {
    if (event.contains('card') || event.contains('action')) {
      return true;
    }
    return json['actionCard'] is Map ||
        json['card'] is Map ||
        json['structuredContent'] is Map ||
        json['actions'] is List ||
        json['buttons'] is List;
  }

  List<ChatStreamEvent> _parseBlockEvents(Map<String, dynamic> json) {
    final blocks = json['blocks'];
    if (blocks is! List) {
      return const [];
    }

    final events = <ChatStreamEvent>[];
    for (final item in blocks.whereType<Map>()) {
      final block = Map<String, dynamic>.from(item);
      final blockType = _readString(block, const ['type'])?.toLowerCase() ?? '';
      final blockData = block['data'];
      if (blockData is! Map) {
        continue;
      }
      final data = Map<String, dynamic>.from(blockData);

      if (blockType == 'text') {
        final text = _readString(
              data,
              const ['content', 'text', 'message', 'reply'],
            ) ??
            '';
        if (text.isNotEmpty) {
          events.add(ChatStreamTextEvent(text: text));
        }
        continue;
      }

      if (blockType == 'card') {
        final message = ChatMessage.fromJson({
          ...data,
          'messageType': 'actionCard',
          'role': json['role'] ?? 'assistant',
          'timestamp': json['timestamp'] ?? DateTime.now().toIso8601String(),
        });
        if (message.hasVisibleContent) {
          events.add(ChatStreamCardEvent(message: message));
        }
      }
    }

    return events;
  }

  bool _isLifecycleEvent(String event) {
    return event == 'complete' || event == 'done' || event == 'error';
  }

  ChatStreamLifecycleType _mapLifecycleType(String event) {
    if (event == 'error') {
      return ChatStreamLifecycleType.error;
    }
    return ChatStreamLifecycleType.complete;
  }

  WorkoutRecord? _extractWorkoutRecord(dynamic container) {
    if (container is Map<String, dynamic>) {
      const keys = ['todayRecord', 'record', 'workoutRecord', 'latestRecord'];
      for (final key in keys) {
        final value = container[key];
        if (value is Map<String, dynamic>) {
          return WorkoutRecord.fromJson(value);
        }
        if (value is Map) {
          return WorkoutRecord.fromJson(Map<String, dynamic>.from(value));
        }
      }
    }
    return null;
  }

  WorkoutRecommendation? _extractWorkoutRecommendation(dynamic container) {
    if (container is Map<String, dynamic>) {
      const keys = ['todayWorkout', 'workout', 'recommendation', 'latestWorkout'];
      for (final key in keys) {
        final value = container[key];
        if (value is Map<String, dynamic>) {
          return WorkoutRecommendation.fromJson(value);
        }
        if (value is Map) {
          return WorkoutRecommendation.fromJson(Map<String, dynamic>.from(value));
        }
      }
    }
    return null;
  }

  String? _extractResponseMessage(dynamic rawData) {
    if (rawData is Map<String, dynamic>) {
      return _readString(rawData, const ['message', 'msg', 'statusText']);
    }
    return null;
  }

  int? _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) {
        return value;
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  bool? _readBool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) {
        return value;
      }
      if (value is String) {
        if (value.toLowerCase() == 'true') {
          return true;
        }
        if (value.toLowerCase() == 'false') {
          return false;
        }
      }
    }
    return null;
  }

  String? _readString(Map<String, dynamic> json, List<String> keys) {
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

  /// 处理 Dio 错误
  String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.receiveTimeout:
        return '接收超时，请稍后重试';
      case DioExceptionType.badResponse:
        return '服务器响应错误: ${error.response?.statusCode}';
      case DioExceptionType.connectionError:
        return '连接错误，请检查后端服务是否启动';
      default:
        return error.message ?? '未知错误';
    }
  }
}

sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class ChatStreamBatchEvent extends ChatStreamEvent {
  final List<ChatStreamEvent> events;

  const ChatStreamBatchEvent({required this.events});
}

class ChatStreamTextEvent extends ChatStreamEvent {
  final String text;

  const ChatStreamTextEvent({required this.text});
}

class ChatStreamCardEvent extends ChatStreamEvent {
  final ChatMessage message;

  const ChatStreamCardEvent({required this.message});
}

enum ChatStreamLifecycleType { complete, error }

class ChatStreamLifecycleEvent extends ChatStreamEvent {
  final ChatStreamLifecycleType type;

  const ChatStreamLifecycleEvent({required this.type});
}

class UndoWorkoutResult {
  final String message;
  final WorkoutRecord? latestRecord;
  final WorkoutRecommendation? latestWorkout;
  final dynamic rawData;

  const UndoWorkoutResult({
    required this.message,
    this.latestRecord,
    this.latestWorkout,
    this.rawData,
  });
}
