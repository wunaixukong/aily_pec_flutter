/// 训练日模型
class WorkoutDay {
  final int? id;
  final int dayOrder;
  final String content;
  final DateTime? createTime;

  WorkoutDay({
    this.id,
    required this.dayOrder,
    required this.content,
    this.createTime,
  });

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    return WorkoutDay(
      id: json['id'] as int?,
      dayOrder: json['dayOrder'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dayOrder': dayOrder,
      'content': content,
      'createTime': createTime?.toIso8601String(),
    };
  }
}
