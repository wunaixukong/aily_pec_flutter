/// Workout record model aligned with current API fields.
class WorkoutRecord {
  final int? id;
  final int userId;
  final int? planId;
  final int? workoutDayId;
  final String content;
  final String? workoutDate;
  final DateTime? createTime;
  final bool revoked;

  WorkoutRecord({
    this.id,
    required this.userId,
    this.planId,
    this.workoutDayId,
    required this.content,
    this.workoutDate,
    this.createTime,
    this.revoked = false,
  });

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) {
    return WorkoutRecord(
      id: _readInt(json['id']),
      userId: _readInt(json['userId']) ?? 0,
      planId: _readInt(json['planId'] ?? json['plan_id']),
      workoutDayId: _readInt(json['workoutDayId']),
      content: (json['content'] as String?) ?? '',
      workoutDate: json['workoutDate'] as String?,
      createTime: _readDateTime(json['createTime']),
      revoked: _readBool(json['revoked']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'plan_id': planId,
      'workoutDayId': workoutDayId,
      'content': content,
      'workoutDate': workoutDate,
      if (createTime != null) 'createTime': createTime!.toIso8601String(),
      'revoked': revoked,
    };
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return false;
  }
}
