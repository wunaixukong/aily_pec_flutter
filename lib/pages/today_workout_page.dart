import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_record.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_ui.dart';
import '../widgets/toast_overlay.dart';

/// 今日训练页面 - 核心页面
class TodayWorkoutPage extends StatefulWidget {
  final int userId;
  final VoidCallback? onGoToPlan;

  const TodayWorkoutPage({super.key, required this.userId, this.onGoToPlan});

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
  WorkoutRecord? _todayRecord;

  @override
  void initState() {
    super.initState();
    _loadTodayWorkout();
    _loadTipState();
  }

  Future<void> _loadTipState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showTip = !(prefs.getBool('tip_closed') ?? false);
    });
  }

  Future<void> _closeTip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tip_closed', true);
    if (!mounted) return;
    setState(() {
      _showTip = false;
    });
  }

  Future<void> _loadTodayWorkout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final record = await _apiService.getTodayRecord(widget.userId);
      final workout = await _apiService.getTodayWorkout(widget.userId);

      if (!mounted) return;
      setState(() {
        _todayRecord = record;
        _isCompleted = record != null;
        _todayWorkout = workout;
        if (_isCompleted) {
          _nextWorkout = workout;
        }
        _isLoading = false;
      });
    } catch (e) {
      var errorMsg = e.toString();
      if (errorMsg.startsWith('Exception:')) {
        errorMsg = errorMsg.substring('Exception:'.length).trim();
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  Future<void> _completeWorkout() async {
    if (_isCompleted) {
      ToastManager().warning('今天已经完成训练了，明天再来吧！');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final nextWorkout = await _apiService.completeTodayWorkout(widget.userId);
      final record = await _apiService.getTodayRecord(widget.userId);

      if (!mounted) return;
      setState(() {
        _todayRecord = record;
        _isCompleted = true;
        _nextWorkout = nextWorkout;
        _isLoading = false;
      });

      ToastManager().success('训练完成！');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ToastManager().error('完成失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('今日训练'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodayWorkout,
            tooltip: '刷新',
          ),
        ],
      ),
      body: SafeArea(top: false, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: AppStatusCard(
          icon: Icons.hourglass_bottom_rounded,
          title: '正在加载今日训练',
          message: '请稍候，马上为你准备今天的内容。',
          compact: true,
        ),
      );
    }

    if (_errorMessage != null) {
      final isNoActivePlan = _errorMessage!.contains('没有激活');
      final isNoProgress = _errorMessage!.contains('进度指针');
      final canNavigate = isNoActivePlan || isNoProgress;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppStatusCard(
            icon: canNavigate ? Icons.fitness_center : Icons.error_outline,
            title: isNoActivePlan
                ? '还没有激活的训练计划'
                : isNoProgress
                ? '进度数据还未准备好'
                : '加载失败',
            message: _errorMessage!,
            accentColor: canNavigate ? AppColors.warning : AppColors.error,
            action: canNavigate
                ? ElevatedButton.icon(
                    onPressed: widget.onGoToPlan,
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('去计划管理'),
                  )
                : ElevatedButton(
                    onPressed: _loadTodayWorkout,
                    child: const Text('重新加载'),
                  ),
          ),
        ),
      );
    }

    if (_todayWorkout.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppStatusCard(
            icon: Icons.fitness_center,
            title: '还没有训练内容',
            message: '先创建并激活一个训练计划，再开始今天的训练。',
            accentColor: AppColors.info,
            action: ElevatedButton.icon(
              onPressed: widget.onGoToPlan,
              icon: const Icon(Icons.add),
              label: const Text('创建训练计划'),
            ),
          ),
        ),
      );
    }

    final displayedWorkout = _isCompleted
        ? (_todayRecord?.content ?? '')
        : _todayWorkout;
    final workoutItems = _parseWorkoutItems(displayedWorkout);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        _buildHeroCard(context, displayedWorkout: displayedWorkout),
        const SizedBox(height: AppSpacing.lg),
        _buildWorkoutListCard(
          context,
          workoutItems: workoutItems,
          fallbackText: displayedWorkout,
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildCompletionCards(context),
        if (_showTip) ...[
          const SizedBox(height: AppSpacing.lg),
          _buildTipCard(),
        ],
      ],
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required String displayedWorkout,
  }) {
    final theme = Theme.of(context);
    final progress = _isCompleted ? 1.0 : 0.62;
    final statusText = _isCompleted ? '已完成' : '待完成';
    final headline = _isCompleted ? '今天训练已打卡' : '准备完成今天训练';
    final supporting = _isCompleted
        ? '当前内容已经完成，继续保持节奏，下一次训练目标已为你准备好。'
        : '聚焦今天这一组动作，完成后即可推进下一次训练。';

    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBadge(
                        label: statusText,
                        icon: _isCompleted ? Icons.check_circle : Icons.bolt,
                        color: Colors.white,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '今日训练',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.84),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        headline,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        supporting,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _buildHeroGauge(progress: progress),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildHeroMetric(
                      context,
                      icon: Icons.fitness_center,
                      label: '训练内容',
                      value: _previewText(displayedWorkout),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 42,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  Expanded(
                    child: _buildHeroMetric(
                      context,
                      icon: _isCompleted ? Icons.flag : Icons.track_changes,
                      label: _isCompleted ? '下次目标' : '当前节奏',
                      value: _isCompleted
                          ? _previewText(_nextWorkout)
                          : '完成即可推进',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCompleted ? null : _completeWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.24),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                icon: Icon(
                  _isCompleted ? Icons.check_circle : Icons.play_arrow_rounded,
                ),
                label: Text(_isCompleted ? '今日已完成' : '完成今日训练'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroGauge({required double progress}) {
    final progressLabel = '${(progress * 100).round()}%';

    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 108,
            height: 108,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                progressLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _isCompleted ? '已完成' : '进行中',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutListCard(
    BuildContext context, {
    required List<String> workoutItems,
    required String fallbackText,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: _isCompleted ? '今日动作回顾' : '今日动作列表',
          subtitle: _isCompleted
              ? '你已经完成今天训练，以下是本次完成内容。'
              : '按顺序完成下面动作即可完成今天训练。',
          trailing: AppBadge(
            label: '${workoutItems.length} 项',
            icon: Icons.format_list_bulleted_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSurfaceCard(
          borderRadius: AppRadius.xl,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              if (workoutItems.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    fallbackText,
                    style: theme.textTheme.titleMedium?.copyWith(height: 1.5),
                  ),
                )
              else
                ...List.generate(workoutItems.length, (index) {
                  final item = workoutItems[index];
                  final itemColor = _isCompleted
                      ? AppColors.success
                      : AppColors.primary;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == workoutItems.length - 1
                          ? 0
                          : AppSpacing.md,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: _isCompleted
                            ? AppColors.successSoft
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: itemColor.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: itemColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            alignment: Alignment.center,
                            child: _isCompleted
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: AppColors.success,
                                    size: 20,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: itemColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  _isCompleted ? '已完成' : '待执行',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: itemColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionCards(BuildContext context) {
    if (_isCompleted) {
      return AppSurfaceCard(
        borderRadius: AppRadius.xl,
        backgroundColor: AppColors.successSoft,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.18)),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppBadge(
                    label: '今日完成',
                    icon: Icons.check_circle,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '今日训练已完成！',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: AppColors.success),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '继续保持训练节奏，明天也来完成下一次安排。',
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

    return AppSurfaceCard(
      borderRadius: AppRadius.xl,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(Icons.track_changes, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppBadge(
                  label: '今日目标',
                  icon: Icons.bolt,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '完成本次训练后即可推进下一次内容。',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '保持动作质量，完成后点击上方按钮打卡。',
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

  Widget _buildTipCard() {
    return AppSurfaceCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: AppColors.infoSoft,
      border: Border.all(color: AppColors.info.withValues(alpha: 0.16)),
      boxShadow: const [],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: AppColors.info,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '训练提示',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.info,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '断练不重置。只要不点击“完成”，无论过几天，打开都显示同一项训练内容。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.info,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _closeTip,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, color: AppColors.info, size: 18),
            tooltip: '关闭提示',
          ),
        ],
      ),
    );
  }

  List<String> _parseWorkoutItems(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final lineItems = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.replaceFirst(RegExp(r'^[-•·\d\s.)、]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lineItems.length > 1) {
      return lineItems;
    }

    final separatorPattern = RegExp(r'[；;]+');
    final inlineItems = normalized
        .split(separatorPattern)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (inlineItems.length > 1) {
      return inlineItems;
    }

    return normalized.isEmpty ? const [] : [normalized];
  }

  String _previewText(String text) {
    final compact = text.replaceAll('\n', ' ').trim();
    if (compact.isEmpty) {
      return '暂无';
    }
    if (compact.length <= 18) {
      return compact;
    }
    return '${compact.substring(0, 18)}…';
  }
}
