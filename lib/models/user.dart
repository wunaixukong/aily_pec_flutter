/// 用户模型类 - 与后端 User 实体对应
class User {
  final int? id;
  final String username;
  final String? password; // 创建用户时需要
  final String? email;
  final String? nickname;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    this.id,
    required this.username,
    this.password,
    this.email,
    this.nickname,
    this.createdAt,
    this.updatedAt,
  });

  /// 从 JSON 解析
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int?,
      username: json['username'] as String,
      password: json['password'] as String?,
      email: json['email'] as String?,
      nickname: json['nickname'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      if (password != null) 'password': password,
      'email': email,
      'nickname': nickname,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'User{id: $id, username: $username, email: $email}';
  }
}
