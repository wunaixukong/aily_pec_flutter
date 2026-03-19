import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/workout_day.dart';
import '../models/workout_plan.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_ui.dart';
import '../widgets/toast_overlay.dart';

/// 计划管理页面
class PlanManagementPage extends StatefulWidget {
  final int userId;

  const PlanManagementPage({super.key, required this.userId});

  @override
  State<PlanManagementPage> createState() => _PlanManagementPageState();
}

class _PlanManagementPageState extends State<PlanManagementPage> {
  final ApiService _apiService = ApiService();
  List<WorkoutPlan> _plans = [];
  final Set<int> _expandedPlanIds = <int>{};
  bool _isLoading = false;
  String? _errorMessage;

  List<WorkoutPlan> _sortPlans(List<WorkoutPlan> plans) {
    final sortedPlans = List<WorkoutPlan>.from(plans);
    sortedPlans.sort((a, b) {
      if (a.isActive != b.isActive) {
        return a.isActive ? -1 : 1;
      }

      final aTime = a.updateTime ?? a.createTime;
      final bTime = b.updateTime ?? b.createTime;
      if (aTime != null && bTime != null) {
        final timeCompare = bTime.compareTo(aTime);
        if (timeCompare != 0) {
          return timeCompare;
        }
      } else if (aTime != null) {
        return -1;
      } else if (bTime != null) {
        return 1;
      }

      return (a.id ?? 0).compareTo(b.id ?? 0);
    });
    return sortedPlans;
  }

  void _togglePlanExpansion(WorkoutPlan plan) {
    final planId = plan.id;
    if (plan.isActive || planId == null) {
      return;
    }

    setState(() {
      if (_expandedPlanIds.contains(planId)) {
        _expandedPlanIds.remove(planId);
      } else {
        _expandedPlanIds.add(planId);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final plans = await _apiService.getUserPlans(widget.userId);
      if (!mounted) return;
      setState(() {
        // 初始加载和显式刷新时进行排序，将激活的置顶
        _plans = _sortPlans(plans);
        final planIds = _plans.map((plan) => plan.id).whereType<int>().toSet();
        _expandedPlanIds.removeWhere((id) => !planIds.contains(id));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _activatePlan(WorkoutPlan plan) async {
    try {
      await _apiService.activatePlan(plan.id!, widget.userId);
      if (!mounted) return;

      setState(() {
        for (final p in _plans) {
          p.isActive = false;
        }
        plan.isActive = true;
        if (plan.id != null) {
          _expandedPlanIds.remove(plan.id);
        }
        // 手动激活时不重新排序列表，避免卡片跳动
      });

      ToastManager().success('已激活');
    } catch (e) {
      ToastManager().error('激活失败: $e');
    }
  }

  Future<void> _deletePlan(WorkoutPlan plan) async {
    try {
      await _apiService.deletePlan(plan.id!);
      if (!mounted) return;
      _loadPlans();
      ToastManager().success('计划已删除');
    } catch (e) {
      ToastManager().error('删除失败: $e');
    }
  }

  void _showEditPlanDialog(WorkoutPlan plan) {
    final nameController = TextEditingController(text: plan.name);
    final dayControllers = plan.workoutDays
        .map((day) => TextEditingController(text: day.content))
        .toList();

    _showPlanDialog(
      title: '编辑训练计划',
      nameController: nameController,
      dayControllers: dayControllers,
      onSubmit: () async {
        if (nameController.text.isEmpty) {
          ToastManager().warning('请输入计划名称');
          return false;
        }

        final validDays = dayControllers
            .where((c) => c.text.isNotEmpty)
            .toList();
        if (validDays.isEmpty) {
          ToastManager().warning('请至少添加一个训练日');
          return false;
        }

        final workoutDays = validDays.asMap().entries.map((entry) {
          return WorkoutDay(
            id: entry.key < plan.workoutDays.length
                ? plan.workoutDays[entry.key].id
                : null,
            dayOrder: entry.key + 1,
            content: entry.value.text,
          );
        }).toList();

        final updatedPlan = WorkoutPlan(
          id: plan.id,
          userId: plan.userId,
          name: nameController.text,
          isActive: plan.isActive,
          workoutDays: workoutDays,
          createTime: plan.createTime,
          updateTime: plan.updateTime,
        );

        try {
          final returnedPlan = await _apiService.editPlan(updatedPlan);
          if (!mounted) return false;

          setState(() {
            final index = _plans.indexWhere((p) => p.id == plan.id);
            if (index != -1) {
              _plans[index] = returnedPlan;
            }
          });

          ToastManager().success('计划编辑成功');
          return true;
        } catch (e) {
          ToastManager().error('编辑失败: $e');
          return false;
        }
      },
    );
  }

  void _showCreatePlanDialog() {
    final nameController = TextEditingController();
    final dayControllers = [TextEditingController()];

    _showPlanDialog(
      title: '创建训练计划',
      nameController: nameController,
      dayControllers: dayControllers,
      onSubmit: () async {
        if (nameController.text.isEmpty) {
          ToastManager().warning('请输入计划名称');
          return false;
        }

        final validDays = dayControllers
            .where((c) => c.text.isNotEmpty)
            .toList();
        if (validDays.isEmpty) {
          ToastManager().warning('请至少添加一个训练日');
          return false;
        }

        final workoutDays = validDays.asMap().entries.map((entry) {
          return WorkoutDay(dayOrder: entry.key + 1, content: entry.value.text);
        }).toList();

        final newPlan = WorkoutPlan(
          userId: widget.userId,
          name: nameController.text,
          workoutDays: workoutDays,
        );

        try {
          await _apiService.createPlan(newPlan);
          if (!mounted) return false;
          _loadPlans();
          ToastManager().success('计划创建成功');
          return true;
        } catch (e) {
          ToastManager().error('创建失败: $e');
          return false;
        }
      },
    );
  }

  void _showPlanDialog({
    required String title,
    required TextEditingController nameController,
    required List<TextEditingController> dayControllers,
    required Future<bool> Function() onSubmit,
  }) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '计划名称',
                      hintText: '例如：PPL 三分化',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const AppSectionHeader(
                    title: '训练日配置',
                    subtitle: '按训练顺序填写每天的内容。',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...List.generate(dayControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: dayControllers[index],
                              decoration: InputDecoration(
                                labelText: '第${index + 1}天',
                                hintText: '例如：推 - 胸 + 肩 + 三头',
                              ),
                            ),
                          ),
                          if (dayControllers.length > 1) ...[
                            const SizedBox(width: AppSpacing.xs),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: AppColors.error,
                              onPressed: () {
                                setDialogState(() {
                                  dayControllers.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          dayControllers.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('添加训练日'),
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
              onPressed: () async {
                final shouldClose = await onSubmit();
                if (shouldClose && context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('训练计划'),
        actions: [
          TextButton.icon(
            onPressed: _showCreatePlanDialog,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('新建'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: AppStatusCard(
          icon: Icons.hourglass_bottom_rounded,
          title: '正在加载训练计划',
          message: '正在获取你的计划列表。',
          compact: true,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppStatusCard(
            icon: Icons.error_outline,
            title: '计划加载失败',
            message: _errorMessage,
            accentColor: AppColors.error,
            action: ElevatedButton(
              onPressed: _loadPlans,
              child: const Text('重试'),
            ),
          ),
        ),
      );
    }

    if (_plans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppStatusCard(
            icon: Icons.calendar_month_outlined,
            title: '还没有训练计划',
            message: '创建你的第一个计划，然后激活它用于今日训练。',
            accentColor: AppColors.info,
            action: ElevatedButton.icon(
              onPressed: _showCreatePlanDialog,
              icon: const Icon(Icons.add),
              label: const Text('创建第一个计划'),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        final plan = _plans[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildPlanCard(plan),
        );
      },
    );
  }

  Widget _buildPlanCard(WorkoutPlan plan) {
    final isActive = plan.isActive;
    final isExpanded =
        isActive || (plan.id != null && _expandedPlanIds.contains(plan.id));
    final highlightColor = isActive ? AppColors.textPrimary : AppColors.primary;
    final visibleDays = isExpanded
        ? plan.workoutDays
        : plan.workoutDays.take(2).toList();
    final remainingDays = plan.workoutDays.length - visibleDays.length;
    final showExpandHint = !isActive && plan.workoutDays.length > 2;

    return AppSurfaceCard(
      onTap: isActive ? null : () => _togglePlanExpansion(plan),
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: isActive ? const Color(0xFFF1F4FF) : Colors.white,
      boxShadow: isActive
          ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ]
          : AppShadows.card,
      border: Border.all(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.6)
            : AppColors.border,
        width: isActive ? 2.5 : 1.0,
      ),
      child: Stack(
        children: [
          if (isActive) ...[
            Positioned(
              top: -24,
              right: -24,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.04),
                ),
              ),
            ),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          maxLines: isExpanded ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${plan.workoutDays.length} 个训练周期',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '执行中',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    AppBadge(label: '待命', color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    isExpanded ? '已展示全部内容' : '预览训练结构',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: 0.7)
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${plan.workoutDays.length} UNITS',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: highlightColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ...visibleDays.asMap().entries.map((entry) {
                final day = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == visibleDays.length - 1
                        ? 0
                        : AppSpacing.sm,
                  ),
                  child: _buildWorkoutDayRow(day, isActive: isActive),
                );
              }),
              if (!isActive &&
                  (remainingDays > 0 || (showExpandHint && isExpanded)))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (remainingDays > 0)
                        Text(
                          '还有 $remainingDays 个阶段',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      if (showExpandHint)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            isExpanded ? '点击收起' : '点击展开全部阶段',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: isActive
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: const Text(
                              '当前活跃计划',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () => _activatePlan(plan),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                            ),
                            child: const Text(
                              '启用此计划',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filledTonal(
                    onPressed: () => _showEditPlanDialog(plan),
                    style: IconButton.styleFrom(
                      backgroundColor: isActive
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.surfaceAlt,
                      foregroundColor: isActive
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton.filledTonal(
                    onPressed: () => _confirmDelete(plan),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFFEAEA),
                      foregroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 22),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutDayRow(WorkoutDay day, {required bool isActive}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.dayOrder}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              day.content,
              maxLines: isActive ? null : 1,
              overflow: isActive ? null : TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.4,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(WorkoutPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除计划“${plan.name}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePlan(plan);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
