import 'workout_day.dart';

/// 训练计划模型
class WorkoutPlan {
  final int? id;
  final int userId;
  final String name;
  bool isActive; // 改为非 final，允许修改激活状态
  final List<WorkoutDay> workoutDays;
  final DateTime? createTime;
  final DateTime? updateTime;

  WorkoutPlan({
    this.id,
    required this.userId,
    required this.name,
    this.isActive = false,
    required this.workoutDays,
    this.createTime,
    this.updateTime,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: json['id'] as int?,
      userId: json['userId'] as int,
      name: json['name'] as String,
      isActive: json['isActive'] as bool? ?? false,
      workoutDays: (json['workoutDays'] as List<dynamic>?)
              ?.map((e) => WorkoutDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'] as String)
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.parse(json['updateTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'isActive': isActive,
      'workoutDays': workoutDays.map((e) => e.toJson()).toList(),
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
    };
  }
}
