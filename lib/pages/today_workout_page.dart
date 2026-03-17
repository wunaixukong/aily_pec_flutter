import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/toast_overlay.dart';

/// 今日训练页面 - 核心页面
class TodayWorkoutPage extends StatefulWidget {
  final int userId;
  final VoidCallback? onGoToPlan;
  
  const TodayWorkoutPage({
    super.key, 
    required this.userId,
    this.onGoToPlan,
  });

  @override
  State<TodayWorkoutPage> createState() => _TodayWorkoutPageState();
}

class _TodayWorkoutPageState extends State<TodayWorkoutPage> {
  final ApiService _apiService = ApiService();
  String _todayWorkout = '';
  bool _isLoading = false;
  String? _errorMessage;
  bool _isCompleted = false;
  String _nextWorkout = '';
  bool _showTip = true;
  bool _hasCompletedToday = false;

  /// 获取今天的完成状态存储key
  String get _todayCompletionKey {
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return 'completed_$dateStr';
  }

  @override
  void initState() {
    super.initState();
    _loadCompletionStatus();
    _loadTodayWorkout();
    _loadTipState();
  }

  /// 加载提示框状态
  Future<void> _loadTipState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showTip = !(prefs.getBool('tip_closed') ?? false);
    });
  }

  /// 关闭提示框
  Future<void> _closeTip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tip_closed', true);
    setState(() {
      _showTip = false;
    });
  }

  /// 加载今天的完成状态
  Future<void> _loadCompletionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasCompletedToday = prefs.getBool(_todayCompletionKey) ?? false;
    });
  }

  /// 保存今天的完成状态
  Future<void> _saveCompletionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_todayCompletionKey, true);
    setState(() {
      _hasCompletedToday = true;
    });
  }

  /// 加载今日训练内容
  Future<void> _loadTodayWorkout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      // 如果今天已完成，保持完成状态
      _isCompleted = _hasCompletedToday;
    });

    try {
      final workout = await _apiService.getTodayWorkout(widget.userId);
      setState(() {
        _todayWorkout = workout;
        // 如果今天已完成，设置下次训练目标
        if (_hasCompletedToday && _nextWorkout.isEmpty) {
          _nextWorkout = workout;
        }
        _isLoading = false;
      });
    } catch (e) {
      // 提取错误信息，去掉 "Exception:" 前缀
      String errorMsg = e.toString();
      if (errorMsg.startsWith('Exception:')) {
        errorMsg = errorMsg.substring('Exception:'.length).trim();
      }
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  /// 完成今日训练
  Future<void> _completeWorkout() async {
    // 检查今天是否已完成
    if (_hasCompletedToday) {
      ToastManager().warning('今天已经完成训练了，明天再来吧！');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final nextWorkout = await _apiService.completeTodayWorkout(widget.userId);
      
      // 保存今天的完成状态
      await _saveCompletionStatus();
      
      setState(() {
        _isCompleted = true;
        _nextWorkout = nextWorkout;
        _isLoading = false;
      });
      
      ToastManager().success('训练完成！');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ToastManager().error('完成失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日训练'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodayWorkout,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('加载中...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      final isNoActivePlan = _errorMessage!.contains('没有激活');
      final isNoProgress = _errorMessage!.contains('进度指针');
      
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isNoActivePlan || isNoProgress 
                    ? Icons.fitness_center 
                    : Icons.error_outline,
                size: 64,
                color: isNoActivePlan || isNoProgress ? Colors.grey : Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                isNoActivePlan 
                    ? '还没有激活的训练计划'
                    : isNoProgress 
                        ? '进度指针未初始化'
                        : '出错了',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              if (isNoActivePlan || isNoProgress)
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onGoToPlan?.call();
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('去计划管理'),
                ),
            ],
          ),
        ),
      );
    }

    // 训练内容为空，显示引导创建计划
    if (_todayWorkout.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.fitness_center,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              const Text(
                '还没有训练内容',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '创建一个训练计划，开始你的健身之旅',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  widget.onGoToPlan?.call();
                },
                icon: const Icon(Icons.add),
                label: const Text('创建训练计划'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          const Text(
            '今天该练',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // 训练内容卡片
          Card(
            elevation: 4,
            child: Container(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                _todayWorkout,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // 完成按钮
          if (!_isCompleted)
            ElevatedButton.icon(
              onPressed: _completeWorkout,
              icon: const Icon(Icons.check_circle),
              label: const Text(
                '完成训练',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            )
          else
            Column(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  '今日训练已完成！',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 24),
                // 下次训练目标卡片（仅展示，不可点击）
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fitness_center, color: Colors.orange.shade600, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '下次训练目标',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _nextWorkout,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          
          const Spacer(),
          
          // 提示信息
          if (_showTip)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '提示：断练不重置！只要不点击"完成"，无论过几天，打开都显示同一项训练内容。',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                  InkWell(
                    onTap: _closeTip,
                    child: const Icon(Icons.close, color: Colors.blue, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
