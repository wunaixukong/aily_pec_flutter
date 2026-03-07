import 'package:dio/dio.dart';
import '../models/user.dart';

/// API 服务类 - 处理与后端的通信
class ApiService {
  // 本地开发地址
  // Android 模拟器使用: http://10.0.2.2:8080/api
  // 真机调试使用本机 IP: http://192.168.0.115:8080/api
  static const String baseUrl = 'http://192.168.0.115:8080/api';
  
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
