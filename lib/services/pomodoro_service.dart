import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pomodoro_settings.dart';

/// 番茄钟服务类
class PomodoroService extends ChangeNotifier {
  static const String _settingsKey = 'pomodoro_settings';
  static const String _stateKey = 'pomodoro_state';

  Timer? _timer;
  PomodoroSettings _settings = PomodoroSettings();
  PomodoroState _state = PomodoroState.idle;
  PomodoroPhase _currentPhase = PomodoroPhase.work;
  int _remainingSeconds = 0;
  int _completedSessions = 0;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Getters
  PomodoroSettings get settings => _settings;
  PomodoroState get state => _state;
  PomodoroPhase get currentPhase => _currentPhase;
  int get remainingSeconds => _remainingSeconds;
  int get completedSessions => _completedSessions;

  double get progress {
    if (_getCurrentPhaseDuration() == 0) return 0.0;
    final elapsed = _getCurrentPhaseDuration() - _remainingSeconds;
    return elapsed / _getCurrentPhaseDuration();
  }

  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  PomodoroService() {
    _initializeService();
  }

  /// 初始化服务
  Future<void> _initializeService() async {
    await _initializeNotifications();
    await _loadSettings();
    await _loadState();
  }

  /// 初始化通知
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);

    // 请求通知权限
    await Permission.notification.request();

    // 创建通知渠道（Android）
    const androidChannel = AndroidNotificationChannel(
      'pomodoro_timer',
      '番茄钟通知',
      description: '番茄钟计时器通知',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    if (settingsJson != null) {
      try {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        _settings = PomodoroSettings.fromJson(settingsMap);
      } catch (e) {
        debugPrint('加载番茄钟设置失败: $e');
      }
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(_settings.toJson()));
  }

  /// 加载状态
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final stateJson = prefs.getString(_stateKey);
    if (stateJson != null) {
      try {
        final stateMap = jsonDecode(stateJson) as Map<String, dynamic>;
        _completedSessions = stateMap['completedSessions'] as int? ?? 0;
        final phaseIndex = stateMap['currentPhase'] as int? ?? 0;
        _currentPhase = PomodoroPhase.values[phaseIndex];

        // 如果之前正在运行，继续计时
        if (stateMap['isRunning'] == true) {
          _remainingSeconds = stateMap['remainingSeconds'] as int? ??
              _getCurrentPhaseDuration();
          _startTimer();
        } else {
          _remainingSeconds = _getCurrentPhaseDuration();
        }
      } catch (e) {
        debugPrint('加载番茄钟状态失败: $e');
        _resetToIdle();
      }
    } else {
      _resetToIdle();
    }
  }

  /// 保存状态
  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final stateMap = {
      'completedSessions': _completedSessions,
      'currentPhase': _currentPhase.index,
      'remainingSeconds': _remainingSeconds,
      'isRunning': _state == PomodoroState.running,
    };
    await prefs.setString(_stateKey, jsonEncode(stateMap));
  }

  /// 获取当前阶段的时长（秒）
  int _getCurrentPhaseDuration() {
    switch (_currentPhase) {
      case PomodoroPhase.work:
        return _settings.workDuration * 60;
      case PomodoroPhase.shortBreak:
        return _settings.shortBreakDuration * 60;
      case PomodoroPhase.longBreak:
        return _settings.longBreakDuration * 60;
    }
  }

  /// 重置为空闲状态
  void _resetToIdle() {
    _state = PomodoroState.idle;
    _currentPhase = PomodoroPhase.work;
    _remainingSeconds = _getCurrentPhaseDuration();
    notifyListeners();
  }

  /// 开始番茄钟
  Future<void> startPomodoro() async {
    if (_state == PomodoroState.idle || _state == PomodoroState.paused) {
      _state = PomodoroState.running;
      if (_remainingSeconds == 0) {
        _remainingSeconds = _getCurrentPhaseDuration();
      }
      _startTimer();
      await _saveState();
    }
  }

  /// 暂停番茄钟
  Future<void> pausePomodoro() async {
    if (_state == PomodoroState.running) {
      _timer?.cancel();
      _state = PomodoroState.paused;
      await _saveState();
      notifyListeners();
    }
  }

  /// 停止番茄钟
  Future<void> stopPomodoro() async {
    _timer?.cancel();
    _resetToIdle();
    await _saveState();
  }

  /// 重置番茄钟
  Future<void> resetPomodoro() async {
    _timer?.cancel();
    _remainingSeconds = _getCurrentPhaseDuration();
    _state = PomodoroState.idle;
    await _saveState();
  }

  /// 开始计时器
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _onPhaseComplete();
      }
    });
  }

  /// 当前阶段完成
  Future<void> _onPhaseComplete() async {
    _timer?.cancel();
    _state = PomodoroState.completed;

    // 发送通知
    if (_settings.notificationsEnabled) {
      await _showNotification();
    }

    // 振动提醒
    if (_settings.vibrateEnabled) {
      HapticFeedback.heavyImpact();
    }

    // 自动进入下一阶段
    await _moveToNextPhase();
  }

  /// 移动到下一阶段
  Future<void> _moveToNextPhase() async {
    if (_currentPhase == PomodoroPhase.work) {
      _completedSessions++;

      // 判断是否需要长休息
      if (_completedSessions % _settings.longBreakInterval == 0) {
        _currentPhase = PomodoroPhase.longBreak;
      } else {
        _currentPhase = PomodoroPhase.shortBreak;
      }
    } else {
      // 休息结束后回到工作阶段
      _currentPhase = PomodoroPhase.work;
    }

    _remainingSeconds = _getCurrentPhaseDuration();
    _state = PomodoroState.idle;
    await _saveState();
  }

  /// 显示通知
  Future<void> _showNotification() async {
    String title;
    String body;

    switch (_currentPhase) {
      case PomodoroPhase.work:
        title = '🍅 工作时间结束';
        body = '该休息一下了！';
        break;
      case PomodoroPhase.shortBreak:
        title = '☕ 短休息结束';
        body = '准备好继续工作了吗？';
        break;
      case PomodoroPhase.longBreak:
        title = '🌟 长休息结束';
        body = '精神焕发，开始新的工作周期！';
        break;
    }

    const androidDetails = AndroidNotificationDetails(
      'pomodoro_timer',
      '番茄钟通知',
      channelDescription: '番茄钟计时器通知',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      title,
      body,
      details,
    );
  }

  /// 更新设置
  Future<void> updateSettings(PomodoroSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();

    // 如果当前是空闲状态，更新当前阶段的剩余时间
    if (_state == PomodoroState.idle) {
      _remainingSeconds = _getCurrentPhaseDuration();
    }

    notifyListeners();
  }

  /// 获取当前阶段显示文本
  String getCurrentPhaseText() {
    switch (_currentPhase) {
      case PomodoroPhase.work:
        return '工作时间';
      case PomodoroPhase.shortBreak:
        return '短休息';
      case PomodoroPhase.longBreak:
        return '长休息';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}