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
  Stream<String> chatWithAiStream(int userId, String description) async* {
    try {
      final response = await _dio.post(
        '/message/$userId/chat/stream',
        data: {'description': description},
        options: Options(responseType: ResponseType.stream),
      );

      final Stream<List<int>> stream = (response.data.stream as Stream).cast<List<int>>();

      // 手动按行解析，避免 LineSplitter 的异常中断
      StringBuffer buffer = StringBuffer();

      await for (final chunk in stream) {
        // 将字节转换为字符串，并追加到缓存
        final String chunkString = utf8.decode(chunk, allowMalformed: true);
        buffer.write(chunkString);

        // 检查是否有换行符，如果有，处理完整行
        String currentContent = buffer.toString();
        while (currentContent.contains('\n')) {
          final int index = currentContent.indexOf('\n');
          final String line = currentContent.substring(0, index).trim();
          currentContent = currentContent.substring(index + 1);
          buffer = StringBuffer(currentContent);

          debugPrint('--- SSE RAW LINE: $line');

          if (line.isEmpty) continue;

          if (line.startsWith('data:')) {
            final data = line.substring(5).trim();
            if (data == '[DONE]') return;
            // 过滤掉纯 complete 标记，它只通过 event 信号处理，不作为文本展示
            if (data == 'complete') continue;

            try {
              if (data.startsWith('{')) {
                final Map<String, dynamic> jsonData = jsonDecode(data);
                yield jsonData['content']?.toString() ?? jsonData['data']?.toString() ?? data;
              } else {
                yield data;
              }
            } catch (e) {
              yield data;
            }
          } else if (line.startsWith('event:')) {
            final event = line.substring(6).trim();
            // 兼容 event:done (旧协议) 和 event:complete/error (新协议)
            if (event == 'complete' || event == 'error' || event == 'done') {
              yield '[[EVENT:$event]]';
            }
          } else if (!line.startsWith(':')) {
            yield line;
          }
        }
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
        throw Exception(rawData['message']?.toString() ?? '获取聊天记录失败');
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
        .where((message) => message.content.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
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
