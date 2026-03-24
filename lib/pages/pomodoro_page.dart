import 'package:flutter/material.dart';
import '../models/pomodoro_settings.dart';
import '../services/pomodoro_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_ui.dart';

/// 番茄钟页面
class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  late PomodoroService _pomodoroService;

  @override
  void initState() {
    super.initState();
    _pomodoroService = PomodoroService();
    _pomodoroService.addListener(_onPomodoroStateChanged);
    _pomodoroService.sendTestNotification();
  }

  @override
  void dispose() {
    _pomodoroService.removeListener(_onPomodoroStateChanged);
    super.dispose();
  }

  void _onPomodoroStateChanged() {
    // 只有在状态或阶段改变时才刷新整个页面，倒计时由子组件处理
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final phaseColor = _getPhaseColor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('番茄钟'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: '设置',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              AppBadge(
                label: _pomodoroService.getCurrentPhaseText(),
                icon: Icons.timelapse,
                color: phaseColor,
              ),
              const Spacer(),
              Text(
                _getStateText(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppSurfaceCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                RepaintBoundary(
                  child: _TimerDisplay(
                    service: _pomodoroService,
                    phaseColor: phaseColor,
                    stateText: _getStateText(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _getPrimaryAction(),
                        icon: Icon(_getPrimaryActionIcon()),
                        label: Text(_getPrimaryActionText()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: phaseColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if (_pomodoroService.state != PomodoroState.idle) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pomodoroService.stopPomodoro,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('停止'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: '今日完成',
                  value: '${_pomodoroService.completedSessions}',
                  helper: '个番茄钟',
                  icon: Icons.emoji_events_outlined,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatCard(
                  title: '当前阶段',
                  value: _pomodoroService.getCurrentPhaseText(),
                  helper: _stateSummary(),
                  icon: Icons.auto_awesome_motion,
                  color: phaseColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppSurfaceCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            backgroundColor: AppColors.infoSoft,
            border: Border.all(color: AppColors.info.withValues(alpha: 0.16)),
            boxShadow: const [],
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    '番茄钟会在后台持续运行，并在阶段切换时发送通知提醒。',
                    style: TextStyle(color: AppColors.info, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPhaseColor() {
    switch (_pomodoroService.currentPhase) {
      case PomodoroPhase.work:
        return AppColors.pomodoroWork;
      case PomodoroPhase.shortBreak:
        return AppColors.pomodoroShortBreak;
      case PomodoroPhase.longBreak:
        return AppColors.pomodoroLongBreak;
    }
  }

  String _getStateText() {
    switch (_pomodoroService.state) {
      case PomodoroState.idle:
        return '准备开始';
      case PomodoroState.running:
        return '进行中';
      case PomodoroState.paused:
        return '已暂停';
      case PomodoroState.completed:
        return '已完成';
    }
  }

  String _stateSummary() {
    switch (_pomodoroService.state) {
      case PomodoroState.idle:
        return '等待启动';
      case PomodoroState.running:
        return '计时进行中';
      case PomodoroState.paused:
        return '可继续当前阶段';
      case PomodoroState.completed:
        return '可重置并开始下一轮';
    }
  }

  VoidCallback? _getPrimaryAction() {
    switch (_pomodoroService.state) {
      case PomodoroState.idle:
      case PomodoroState.paused:
        return _pomodoroService.startPomodoro;
      case PomodoroState.running:
        return _pomodoroService.pausePomodoro;
      case PomodoroState.completed:
        return _pomodoroService.resetPomodoro;
    }
  }

  IconData _getPrimaryActionIcon() {
    switch (_pomodoroService.state) {
      case PomodoroState.idle:
      case PomodoroState.paused:
        return Icons.play_arrow_rounded;
      case PomodoroState.running:
        return Icons.pause_rounded;
      case PomodoroState.completed:
        return Icons.refresh_rounded;
    }
  }

  String _getPrimaryActionText() {
    switch (_pomodoroService.state) {
      case PomodoroState.idle:
        return '开始';
      case PomodoroState.paused:
        return '继续';
      case PomodoroState.running:
        return '暂停';
      case PomodoroState.completed:
        return '重置';
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => _PomodoroSettingsDialog(
        currentSettings: _pomodoroService.settings,
        onSettingsChanged: (newSettings) {
          _pomodoroService.updateSettings(newSettings);
        },
      ),
    );
  }
}

/// 独立的计时器展示组件，用于局部刷新和重绘隔离
class _TimerDisplay extends StatefulWidget {
  final PomodoroService service;
  final Color phaseColor;
  final String stateText;

  const _TimerDisplay({
    required this.service,
    required this.phaseColor,
    required this.stateText,
  });

  @override
  State<_TimerDisplay> createState() => _TimerDisplayState();
}

class _TimerDisplayState extends State<_TimerDisplay> {
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_update);
  }

  @override
  void dispose() {
    widget.service.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 292,
      height: 292,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景圆环
          const SizedBox(
            width: 292,
            height: 292,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 14,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.border),
            ),
          ),
          // 进度圆环
          SizedBox(
            width: 292,
            height: 292,
            child: CircularProgressIndicator(
              value: widget.service.progress,
              strokeWidth: 14,
              backgroundColor: Colors.transparent,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(widget.phaseColor),
            ),
          ),
          // 中心内容
          Container(
            width: 224,
            height: 224,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.phaseColor.withValues(alpha: 0.08),
              border: Border.all(
                color: widget.phaseColor.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.service.formattedTime,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.stateText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.helper,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBadge(label: title, icon: icon, color: color),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            helper,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 番茄钟设置对话框
class _PomodoroSettingsDialog extends StatefulWidget {
  final PomodoroSettings currentSettings;
  final Function(PomodoroSettings) onSettingsChanged;

  const _PomodoroSettingsDialog({
    required this.currentSettings,
    required this.onSettingsChanged,
  });

  @override
  State<_PomodoroSettingsDialog> createState() =>
      _PomodoroSettingsDialogState();
}

class _PomodoroSettingsDialogState extends State<_PomodoroSettingsDialog> {
  late int _workDuration;
  late int _shortBreakDuration;
  late int _longBreakDuration;
  late int _longBreakInterval;
  late bool _vibrateEnabled;
  late bool _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    _workDuration = widget.currentSettings.workDuration;
    _shortBreakDuration = widget.currentSettings.shortBreakDuration;
    _longBreakDuration = widget.currentSettings.longBreakDuration;
    _longBreakInterval = widget.currentSettings.longBreakInterval;
    _vibrateEnabled = widget.currentSettings.vibrateEnabled;
    _notificationsEnabled = widget.currentSettings.notificationsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('番茄钟设置'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDurationSetting(
                '工作时长',
                _workDuration,
                (value) => setState(() => _workDuration = value),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildDurationSetting(
                '短休息时长',
                _shortBreakDuration,
                (value) => setState(() => _shortBreakDuration = value),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildDurationSetting(
                '长休息时长',
                _longBreakDuration,
                (value) => setState(() => _longBreakDuration = value),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildDurationSetting(
                '长休息间隔',
                _longBreakInterval,
                (value) => setState(() => _longBreakInterval = value),
                suffix: '个番茄钟',
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('振动提醒'),
                      subtitle: const Text('阶段切换时触发震动反馈'),
                      value: _vibrateEnabled,
                      onChanged: (value) =>
                          setState(() => _vibrateEnabled = value),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('通知提醒'),
                      subtitle: const Text('后台运行时推送通知提醒'),
                      value: _notificationsEnabled,
                      onChanged: (value) =>
                          setState(() => _notificationsEnabled = value),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final newSettings = PomodoroSettings(
              workDuration: _workDuration,
              shortBreakDuration: _shortBreakDuration,
              longBreakDuration: _longBreakDuration,
              longBreakInterval: _longBreakInterval,
              vibrateEnabled: _vibrateEnabled,
              notificationsEnabled: _notificationsEnabled,
            );
            widget.onSettingsChanged(newSettings);
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildDurationSetting(
    String label,
    int value,
    Function(int) onChanged, {
    String suffix = '分钟',
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 140,
          child: TextFormField(
            initialValue: value.toString(),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(suffixText: suffix),
            onChanged: (text) {
              final newValue = int.tryParse(text);
              if (newValue != null && newValue > 0) {
                onChanged(newValue);
              }
            },
          ),
        ),
      ],
    );
  }
}
