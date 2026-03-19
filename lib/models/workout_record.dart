/// 训练记录模型类 - 对齐接口文档
class WorkoutRecord {
  final int? id;
  final int userId;
  final int? planId; // 对齐接口 plan_id
  final int? workoutDayId;
  final String content;
  final String? workoutDate;
  final DateTime? createTime;

  WorkoutRecord({
    this.id,
    required this.userId,
    this.planId,
    this.workoutDayId,
    required this.content,
    this.workoutDate,
    this.createTime,
  });

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) {
    return WorkoutRecord(
      id: json['id'] as int?,
      userId: json['userId'] as int,
      planId: json['plan_id'] as int?, // 处理下划线
      workoutDayId: json['workoutDayId'] as int?,
      content: json['content'] as String,
      workoutDate: json['workoutDate'] as String?,
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'plan_id': planId, // 处理下划线
      'workoutDayId': workoutDayId,
      'content': content,
      'workoutDate': workoutDate,
      if (createTime != null) 'createTime': createTime?.toIso8601String(),
    };
  }
}
