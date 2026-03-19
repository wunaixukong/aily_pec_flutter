import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/pomodoro_settings.dart';

/// 番茄钟服务类（单例）
///
/// 核心设计：用绝对时间 endTime 驱动计时
/// - 启动时记录 endTime，注册定时通知
/// - App 在前台：Timer 每秒刷新 UI 倒计时
/// - App 退后台/被杀：系统定时通知照常弹出
/// - App 重新打开：从 endTime 重算剩余时间
class PomodoroService extends ChangeNotifier {
  static const String _settingsKey = 'pomodoro_settings';
  static const String _stateKey = 'pomodoro_state';
  static const int _notificationId = 0;

  /// 单例
  static final PomodoroService _instance = PomodoroService._internal();
  factory PomodoroService() => _instance;

  Timer? _timer;
  PomodoroSettings _settings = PomodoroSettings();
  PomodoroState _state = PomodoroState.idle;
  PomodoroPhase _currentPhase = PomodoroPhase.work;
  int _remainingSeconds = 0;
  int _completedSessions = 0;

  /// 计时结束的绝对时间（核心字段）
  DateTime? _endTime;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

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

  PomodoroService._internal() {
    _initializeService();
  }

  /// 初始化服务
  Future<void> _initializeService() async {
    tz.initializeTimeZones();
    await _initializeNotifications();
    await _loadSettings();
    await _loadState();
    _initialized = true;
  }

  /// 等待初始化完成
  Future<void> ensureInitialized() async {
    while (!_initialized) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
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

    // 请求精确闹钟权限（Android 12+）
    await Permission.scheduleExactAlarm.request();

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

  /// 加载状态（基于 endTime 重算剩余时间）
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final stateJson = prefs.getString(_stateKey);
    if (stateJson != null) {
      try {
        final stateMap = jsonDecode(stateJson) as Map<String, dynamic>;
        _completedSessions = stateMap['completedSessions'] as int? ?? 0;
        final phaseIndex = stateMap['currentPhase'] as int? ?? 0;
        _currentPhase = PomodoroPhase.values[phaseIndex];

        final isRunning = stateMap['isRunning'] == true;
        final endTimeMs = stateMap['endTimeMs'] as int?;

        if (isRunning && endTimeMs != null) {
          _endTime = DateTime.fromMillisecondsSinceEpoch(endTimeMs);
          final now = DateTime.now();

          if (_endTime!.isAfter(now)) {
            // 还没到时间，继续计时
            _remainingSeconds = _endTime!.difference(now).inSeconds;
            _state = PomodoroState.running;
            _startUiTimer();
          } else {
            // 已经过了结束时间（后台完成了），进入下一阶段
            _endTime = null;
            await _onPhaseComplete();
          }
        } else if (stateMap['isPaused'] == true) {
          // 暂停状态：保留剩余秒数
          _remainingSeconds = stateMap['remainingSeconds'] as int? ??
              _getCurrentPhaseDuration();
          _state = PomodoroState.paused;
          _endTime = null;
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
    notifyListeners();
  }

  /// 保存状态
  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final stateMap = {
      'completedSessions': _completedSessions,
      'currentPhase': _currentPhase.index,
      'remainingSeconds': _remainingSeconds,
      'isRunning': _state == PomodoroState.running,
      'isPaused': _state == PomodoroState.paused,
      'endTimeMs': _endTime?.millisecondsSinceEpoch,
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
    _endTime = null;
    notifyListeners();
  }

  /// 开始番茄钟
  Future<void> startPomodoro() async {
    if (_state == PomodoroState.idle || _state == PomodoroState.paused) {
      _state = PomodoroState.running;
      if (_remainingSeconds <= 0) {
        _remainingSeconds = _getCurrentPhaseDuration();
      }

      // 计算结束的绝对时间
      _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));

      // 注册定时通知（App 退后台也能弹）
      if (_settings.notificationsEnabled) {
        await _scheduleNotification();
      }

      _startUiTimer();
      await _saveState();
    }
  }

  /// 暂停番茄钟
  Future<void> pausePomodoro() async {
    if (_state == PomodoroState.running) {
      _timer?.cancel();
      _state = PomodoroState.paused;

      // 从 endTime 精确算出剩余时间
      if (_endTime != null) {
        final now = DateTime.now();
        _remainingSeconds = _endTime!.difference(now).inSeconds;
        if (_remainingSeconds < 0) _remainingSeconds = 0;
      }
      _endTime = null;

      // 取消定时通知
      await _cancelScheduledNotification();

      await _saveState();
      notifyListeners();
    }
  }

  /// 停止番茄钟
  Future<void> stopPomodoro() async {
    _timer?.cancel();
    await _cancelScheduledNotification();
    _resetToIdle();
    await _saveState();
  }

  /// 重置番茄钟
  Future<void> resetPomodoro() async {
    _timer?.cancel();
    await _cancelScheduledNotification();
    _remainingSeconds = _getCurrentPhaseDuration();
    _state = PomodoroState.idle;
    _endTime = null;
    await _saveState();
    notifyListeners();
  }

  /// 启动 UI 刷新定时器（仅在前台用于刷新倒计时显示）
  void _startUiTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_endTime == null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      _remainingSeconds = _endTime!.difference(now).inSeconds;

      if (_remainingSeconds <= 0) {
        _remainingSeconds = 0;
        timer.cancel();
        _onPhaseComplete();
      } else {
        notifyListeners();
      }
    });
  }

  /// 当前阶段完成
  Future<void> _onPhaseComplete() async {
    _timer?.cancel();
    _endTime = null;
    _state = PomodoroState.completed;

    // 如果 App 在前台，发一条即时通知（后台的由 scheduleNotification 处理）
    if (_settings.notificationsEnabled) {
      await _showImmediateNotification();
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
    notifyListeners();
  }

  /// 注册定时通知（到 endTime 时由系统弹出，即使 App 被杀）
  Future<void> _scheduleNotification() async {
    if (_endTime == null) return;

    // 取消之前的定时通知
    await _cancelScheduledNotification();

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
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduledTime = tz.TZDateTime.from(_endTime!, tz.local);

    try {
      await _notifications.zonedSchedule(
        _notificationId,
        title,
        body,
        scheduledTime,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
      debugPrint('定时通知已注册: $scheduledTime');
    } catch (e) {
      debugPrint('注册定时通知失败: $e');
    }
  }

  /// 取消定时通知
  Future<void> _cancelScheduledNotification() async {
    await _notifications.cancel(_notificationId);
  }

  /// 显示即时通知（App 在前台时阶段完成触发）
  Future<void> _showImmediateNotification() async {
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
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationId + 1, // 用不同 ID 避免覆盖
      title,
      body,
      details,
    );
  }

  /// 发送测试通知：立即弹一条 + 每隔20秒定时弹一条（共10条，覆盖约3分钟）
  /// 由系统调度，App 退后台/被杀也能弹
  Future<void> sendTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'pomodoro_timer',
      '番茄钟通知',
      channelDescription: '番茄钟计时器通知',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 立即弹一条
    await _notifications.show(
      99,
      '🍅 通知测试',
      '番茄钟通知功能正常！',
      details,
    );

    // 取消之前的测试定时通知
    for (int i = 0; i < 10; i++) {
      await _notifications.cancel(100 + i);
    }

    // 每隔20秒注册一条定时通知，共10条
    final now = DateTime.now();
    for (int i = 1; i <= 10; i++) {
      final scheduledTime = tz.TZDateTime.from(
        now.add(Duration(seconds: 20 * i)),
        tz.local,
      );
      try {
        await _notifications.zonedSchedule(
          100 + i,
          '🍅 测试通知 #$i',
          '第 ${20 * i} 秒 - App在后台也能收到！',
          scheduledTime,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        debugPrint('测试通知 #$i 已注册: $scheduledTime');
      } catch (e) {
        debugPrint('注册测试通知 #$i 失败: $e');
      }
    }
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
