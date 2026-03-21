/// 训练推荐模型
class WorkoutRecommendation {
  final int recommendationId;
  final int? planId;
  final int? baseWorkoutDayId;
  final String baseContent;
  final int? recommendedWorkoutDayId;
  final String recommendedContent;
  final String recommendationType; // BASE_PLAN, ALTERNATIVE, RECOVERY
  final String? recommendationReason;
  final String? statusDescription;
  final bool fallbackUsed;
  final bool completed;

  WorkoutRecommendation({
    required this.recommendationId,
    this.planId,
    this.baseWorkoutDayId,
    required this.baseContent,
    this.recommendedWorkoutDayId,
    required this.recommendedContent,
    required this.recommendationType,
    this.recommendationReason,
    this.statusDescription,
    required this.fallbackUsed,
    required this.completed,
  });

  factory WorkoutRecommendation.fromJson(Map<String, dynamic> json) {
    return WorkoutRecommendation(
      recommendationId: json['recommendationId'] as int,
      planId: json['planId'] as int?,
      baseWorkoutDayId: json['baseWorkoutDayId'] as int?,
      baseContent: json['baseContent'] as String? ?? '',
      recommendedWorkoutDayId: json['recommendedWorkoutDayId'] as int?,
      recommendedContent: json['recommendedContent'] as String? ?? '',
      recommendationType: json['recommendationType'] as String? ?? 'BASE_PLAN',
      recommendationReason: json['recommendationReason'] as String?,
      statusDescription: json['statusDescription'] as String?,
      fallbackUsed: json['fallbackUsed'] as bool? ?? false,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
