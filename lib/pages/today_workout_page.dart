import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_page.dart';
import '../models/workout_recommendation.dart';
import '../models/workout_record.dart';
import '../models/today_workout_next.dart';
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
  WorkoutRecommendation? _recommendation;
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
      final recommendation = await _apiService.getTodayWorkout(widget.userId);
      final nextWorkout = await _apiService.getNextWorkout(widget.userId);

      if (!mounted) return;
      setState(() {
        _todayRecord = record;
        _recommendation = recommendation;
        _isCompleted = (record != null && !record.revoked) || recommendation.completed;

        if (nextWorkout != null && nextWorkout.content.isNotEmpty) {
          _nextWorkout = nextWorkout.content;
        } else if (_isCompleted) {
          _nextWorkout = '待明天系统更新';
        } else {
          _nextWorkout = '待今日训练完成后解锁';
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
      final recommendation = await _apiService.completeTodayWorkout(widget.userId);
      final record = await _apiService.getTodayRecord(widget.userId);
      final nextWorkout = await _apiService.getNextWorkout(widget.userId);

      if (!mounted) return;
      setState(() {
        _todayRecord = record;
        _recommendation = recommendation;
        _isCompleted = (record != null && !record.revoked) || recommendation.completed;
        if (nextWorkout != null && nextWorkout.content.isNotEmpty) {
          _nextWorkout = nextWorkout.content;
        } else if (_isCompleted) {
          _nextWorkout = recommendation.recommendedContent;
        }
        _isLoading = false;
      });

      ToastManager().success('已打卡');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ToastManager().error('完成失败: $e');
    }
  }

  void _showStatusDialog() async {
    final result = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(
        builder: (context) => ChatPage(userId: widget.userId),
      ),
    );

    if (result == true) {
      _loadTodayWorkout(); // 如果计划已更新，刷新首页
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: Text(
          '今日训练',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
        ),
        actions: [
          IconButton(
            icon: const AppDuotoneIcon(index: 2, color: AppColors.primary, size: 22, isSelected: true),
            onPressed: _showStatusDialog,
            tooltip: '智能助手',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary, size: 20),
            onPressed: _loadTodayWorkout,
            tooltip: '刷新',
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(top: false, child: _buildBody(context)),
      floatingActionButton: FloatingActionButton(
        onPressed: _showStatusDialog,
        backgroundColor: AppColors.primary,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: const AppDuotoneIcon(index: 2, color: Colors.white, size: 28, isSelected: true),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_recommendation == null && _isLoading) {
      return const Center(
        child: AppStatusCard(
          icon: Icons.hourglass_bottom_rounded,
          title: '正在加载今日训练',
          message: '请稍候，马上为你准备今天的内容。',
          compact: true,
        ),
      );
    }

    if (_errorMessage != null && _recommendation == null) {
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

    if (_recommendation == null) {
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
        ? (_todayRecord?.content ?? _recommendation!.recommendedContent)
        : _recommendation!.recommendedContent;
    final workoutItems = _parseWorkoutItems(displayedWorkout);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        if (_recommendation?.recommendationType != 'BASE_PLAN' && !_isCompleted)
          _buildAiReasonBanner(),
        _buildHeroCard(context, displayedWorkout: displayedWorkout),
        const SizedBox(height: AppSpacing.sm),
        if (!_isCompleted) ...[
          _buildStatusEntryCard(),
          const SizedBox(height: AppSpacing.lg),
        ],
        _buildWorkoutListCard(
          context,
          workoutItems: workoutItems,
          fallbackText: displayedWorkout,
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildNextWorkoutCard(),
        const SizedBox(height: AppSpacing.lg),
        _buildCompletionCards(context),
        if (_showTip) ...[
          const SizedBox(height: AppSpacing.lg),
          _buildTipCard(),
        ],
      ],
    );
  }

  Widget _buildAiReasonBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.psychology_alt_rounded, color: AppColors.warning, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI 已为你调整今日计划',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _recommendation?.recommendationReason ?? '根据你的身体状态，AI 建议今天进行调整。',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF856404),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.accent.withValues(alpha: 0.95),
            AppColors.accent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            // 背景装饰圆圈
            Positioned(
              right: -30,
              top: -20,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -40,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeroBadge(statusText, _isCompleted),
                      Text(
                        _isCompleted ? 'STREAK 1 DAY' : 'FOCUS MODE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '今日训练主题',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    headline,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // 今日聚焦内容区 - 独占一行，空间充裕
                  _buildHeroFocusContent(context, displayedWorkout),
                  const SizedBox(height: AppSpacing.lg),
                  // 主 CTA 按钮
                  _buildHeroCtaButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroFocusContent(BuildContext context, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                '训练内容',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCtaButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isCompleted ? null : _completeWorkout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.2),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isCompleted ? Icons.check_circle : Icons.play_arrow_rounded,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _isCompleted ? '今日已完成' : '打卡今日训练',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroGauge({required double progress}) {
    final progressLabel = '${(progress * 100).round()}%';

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
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
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              Text(
                _isCompleted ? '已打卡' : '进行中',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusEntryCard() {
    return GestureDetector(
      onTap: _showStatusDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const AppDuotoneIcon(index: 2, color: Colors.white, size: 20, isSelected: true),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI 智能助手',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '身体感觉疲劳？让 AI 帮你实时调整计划',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Text(
                '去对话',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildHeroBadge(String text, bool completed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.bolt,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextWorkoutCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: '下次目标',
          subtitle: '完成后为你准备的后续内容',
        ),
        const SizedBox(height: AppSpacing.md),
        AppSurfaceCard(
          borderRadius: AppRadius.xl,
          padding: const EdgeInsets.all(AppSpacing.lg),
          backgroundColor: AppColors.primary.withValues(alpha: 0.04),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.next_plan_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nextWorkout.isEmpty ? '待定' : _nextWorkout,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isCompleted ? '明天将开始此阶段' : '完成当前训练后激活',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.border, size: 14),
            ],
          ),
        ),
      ],
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCompleted ? '今日动作回顾' : '今日动作列表',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isCompleted ? '已完成动作明细' : '按顺序完成以下动作',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            AppBadge(
              label: '${workoutItems.length} 项',
              customIconIndex: 12,
              color: AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppSurfaceCard(
          borderRadius: AppRadius.xl,
          padding: const EdgeInsets.all(AppSpacing.md),
          backgroundColor: Colors.white,
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          child: Column(
            children: [
              if (workoutItems.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  alignment: Alignment.center,
                  child: Text(
                    fallbackText,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                )
              else
                ...List.generate(workoutItems.length, (index) {
                  final item = workoutItems[index];
                  final isLast = index == workoutItems.length - 1;
                  final itemColor = _isCompleted ? AppColors.success : AppColors.primary;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: itemColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: _isCompleted
                                  ? const Icon(Icons.check, color: AppColors.success, size: 16)
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: itemColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                item,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (_isCompleted)
                              const Icon(Icons.verified_rounded, color: AppColors.success, size: 20)
                            else
                              const Icon(Icons.chevron_right_rounded, color: AppColors.border, size: 20),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          color: AppColors.border.withValues(alpha: 0.4),
                          indent: 48,
                        ),
                    ],
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
        backgroundColor: Colors.white,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.success,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '训练打卡完成！',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '继续保持这个节奏，期待你明天的进步。',
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
      backgroundColor: Colors.white,
      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日训练目标',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '完成后点击顶部按钮即可推进计划进度。',
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.infoSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.info,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '小提示',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.info,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '断练不重置。只要不打卡，无论过几天，都会保留同一项训练内容。',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B6584),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _closeTip,
            child: Icon(
              Icons.close_rounded,
              color: AppColors.info.withValues(alpha: 0.4),
              size: 18,
            ),
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
      return '暂无内容';
    }
    // 增加展示长度限制
    if (compact.length <= 32) {
      return compact;
    }
    return '${compact.substring(0, 32)}…';
  }
}
