import 'package:dio/dio.dart';
import '../models/user.dart';
import '../models/workout_plan.dart';
import '../models/api_response.dart';

/// API 服务类 - 处理与后端的通信
class ApiService {
  // 远程服务器地址
  static const String baseUrl = 'http://123.207.199.246:8080/api';
  
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
  Future<String> getTodayWorkout(int userId) async {
    try {
      final response = await _dio.get('/today/$userId');
      
      if (response.statusCode == 200) {
        // 处理统一响应格式
        if (response.data is Map<String, dynamic>) {
          final apiResponse = ApiResponse<String>.fromJson(
            response.data as Map<String, dynamic>,
            (data) => data as String,
          );
          apiResponse.checkSuccess();
          return apiResponse.data ?? '';
        }
        // 直接返回字符串（兼容旧格式）
        return response.data as String;
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
  Future<String> completeTodayWorkout(int userId) async {
    try {
      final response = await _dio.post('/today/$userId/complete');
      
      if (response.statusCode == 200) {
        // 处理统一响应格式
        if (response.data is Map<String, dynamic>) {
          final apiResponse = ApiResponse<String>.fromJson(
            response.data as Map<String, dynamic>,
            (data) => data as String,
          );
          apiResponse.checkSuccess();
          return apiResponse.data ?? '';
        }
        // 直接返回字符串（兼容旧格式）
        return response.data as String;
      } else {
        throw Exception('完成训练失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求错误: ${_handleDioError(e)}');
    }
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
