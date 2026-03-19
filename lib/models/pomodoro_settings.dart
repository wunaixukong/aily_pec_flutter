/// 番茄钟设置模型
class PomodoroSettings {
  final int workDuration; // 工作时长（分钟）
  final int shortBreakDuration; // 短休息时长（分钟）
  final int longBreakDuration; // 长休息时长（分钟）
  final int longBreakInterval; // 长休息间隔（多少个番茄钟后）
  final bool vibrateEnabled; // 是否启用振动
  final bool notificationsEnabled; // 是否启用通知

  PomodoroSettings({
    this.workDuration = 1, // 测试：默认1分钟
    this.shortBreakDuration = 1, // 测试：1分钟
    this.longBreakDuration = 1, // 测试：1分钟
    this.longBreakInterval = 4,
    this.vibrateEnabled = true,
    this.notificationsEnabled = true,
  });

  factory PomodoroSettings.fromJson(Map<String, dynamic> json) {
    return PomodoroSettings(
      workDuration: json['workDuration'] as int? ?? 60,
      shortBreakDuration: json['shortBreakDuration'] as int? ?? 10,
      longBreakDuration: json['longBreakDuration'] as int? ?? 20,
      longBreakInterval: json['longBreakInterval'] as int? ?? 4,
      vibrateEnabled: json['vibrateEnabled'] as bool? ?? true,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workDuration': workDuration,
      'shortBreakDuration': shortBreakDuration,
      'longBreakDuration': longBreakDuration,
      'longBreakInterval': longBreakInterval,
      'vibrateEnabled': vibrateEnabled,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  PomodoroSettings copyWith({
    int? workDuration,
    int? shortBreakDuration,
    int? longBreakDuration,
    int? longBreakInterval,
    bool? vibrateEnabled,
    bool? notificationsEnabled,
  }) {
    return PomodoroSettings(
      workDuration: workDuration ?? this.workDuration,
      shortBreakDuration: shortBreakDuration ?? this.shortBreakDuration,
      longBreakDuration: longBreakDuration ?? this.longBreakDuration,
      longBreakInterval: longBreakInterval ?? this.longBreakInterval,
      vibrateEnabled: vibrateEnabled ?? this.vibrateEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

/// 番茄钟状态枚举
enum PomodoroState {
  idle,      // 空闲
  running,   // 运行中
  paused,    // 暂停
  completed, // 已完成
}

/// 番茄钟阶段枚举
enum PomodoroPhase {
  work,        // 工作
  shortBreak,  // 短休息
  longBreak,   // 长休息
}