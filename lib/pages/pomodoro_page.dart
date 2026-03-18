import 'package:flutter/material.dart';
import '../services/pomodoro_service.dart';
import '../models/pomodoro_settings.dart';

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
  }

  @override
  void dispose() {
    _pomodoroService.removeListener(_onPomodoroStateChanged);
    _pomodoroService.dispose();
    super.dispose();
  }

  void _onPomodoroStateChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('番茄钟'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: '设置',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // 当前阶段显示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getPhaseColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getPhaseColor().withValues(alpha: 0.3)),
              ),
              child: Text(
                _pomodoroService.getCurrentPhaseText(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _getPhaseColor(),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 圆形进度指示器
            SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 背景圆环
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.grey.shade200,
                      ),
                    ),
                  ),
                  // 进度圆环
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: CircularProgressIndicator(
                      value: _pomodoroService.progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(_getPhaseColor()),
                    ),
                  ),
                  // 时间显示
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _pomodoroService.formattedTime,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getStateText(),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 开始/暂停按钮
                ElevatedButton(
                  onPressed: _getPrimaryAction(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getPhaseColor(),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getPrimaryActionIcon()),
                      const SizedBox(width: 8),
                      Text(
                        _getPrimaryActionText(),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),

                // 停止按钮
                if (_pomodoroService.state != PomodoroState.idle)
                  OutlinedButton(
                    onPressed: () => _pomodoroService.stopPomodoro(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stop),
                        SizedBox(width: 8),
                        Text('停止', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 40),

            // 完成统计
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events, color: Colors.orange),
                  const SizedBox(width: 12),
                  Text(
                    '今日完成: ${_pomodoroService.completedSessions} 个番茄钟',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // 提示信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '番茄钟会在后台运行并发送通知提醒',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPhaseColor() {
    switch (_pomodoroService.currentPhase) {
      case PomodoroPhase.work:
        return Colors.red;
      case PomodoroPhase.shortBreak:
        return Colors.green;
      case PomodoroPhase.longBreak:
        return Colors.blue;
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

  VoidCallback? _getPrimaryAction() {
    switch (_pomodoroService.state) {
      case PomodoroState.idle:
      case PomodoroState.paused:
        return () => _pomodoroService.startPomodoro();
      case PomodoroState.running:
        return () => _pomodoroService.pausePomodoro();
      case PomodoroState.completed:
        return () => _pomodoroService.resetPomodoro();
    }
  }

  IconData _getPrimaryActionIcon() {
    switch (_pomodoroService.state) {
      case PomodoroState.idle:
      case PomodoroState.paused:
        return Icons.play_arrow;
      case PomodoroState.running:
        return Icons.pause;
      case PomodoroState.completed:
        return Icons.refresh;
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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 工作时长
            _buildDurationSetting(
              '工作时长',
              _workDuration,
              (value) => setState(() => _workDuration = value),
            ),
            const SizedBox(height: 16),

            // 短休息时长
            _buildDurationSetting(
              '短休息时长',
              _shortBreakDuration,
              (value) => setState(() => _shortBreakDuration = value),
            ),
            const SizedBox(height: 16),

            // 长休息时长
            _buildDurationSetting(
              '长休息时长',
              _longBreakDuration,
              (value) => setState(() => _longBreakDuration = value),
            ),
            const SizedBox(height: 16),

            // 长休息间隔
            _buildDurationSetting(
              '长休息间隔',
              _longBreakInterval,
              (value) => setState(() => _longBreakInterval = value),
              suffix: '个番茄钟',
            ),
            const SizedBox(height: 20),

            // 振动开关
            SwitchListTile(
              title: const Text('振动提醒'),
              value: _vibrateEnabled,
              onChanged: (value) => setState(() => _vibrateEnabled = value),
              contentPadding: EdgeInsets.zero,
            ),

            // 通知开关
            SwitchListTile(
              title: const Text('通知提醒'),
              value: _notificationsEnabled,
              onChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
              contentPadding: EdgeInsets.zero,
            ),
          ],
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
      children: [
        Expanded(
          child: Text(label),
        ),
        SizedBox(
          width: 100,
          child: TextFormField(
            initialValue: value.toString(),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              suffix: Text(suffix),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
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