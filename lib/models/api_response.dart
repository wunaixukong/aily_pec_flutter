/// 统一 API 响应模型
class ApiResponse<T> {
  final T? data;
  final bool success;
  final String? message;
  final String? code;

  ApiResponse({
    this.data,
    required this.success,
    this.message,
    this.code,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJson,
  ) {
    return ApiResponse(
      data: json['data'] != null && fromJson != null
          ? fromJson(json['data'])
          : json['data'] as T?,
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      code: json['code'] as String?,
    );
  }

  /// 检查响应是否成功，不成功则抛出异常
  void checkSuccess() {
    if (!success) {
      throw Exception(message ?? '请求失败');
    }
  }
}
