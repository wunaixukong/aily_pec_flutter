import 'package:flutter/material.dart';
import '../models/workout_plan.dart';
import '../models/workout_day.dart';
import '../services/api_service.dart';
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
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  /// 加载用户的所有计划
  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final plans = await _apiService.getUserPlans(widget.userId);
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 激活计划
  Future<void> _activatePlan(WorkoutPlan plan) async {
    try {
      await _apiService.activatePlan(plan.id!, widget.userId);
      
      // 本地更新激活状态，无需重新请求列表
      setState(() {
        // 1. 将所有计划设为非激活
        for (var p in _plans) {
          p.isActive = false;
        }
        // 2. 将当前计划设为激活
        plan.isActive = true;
      });
      
      ToastManager().success('计划 "${plan.name}" 已激活');
    } catch (e) {
      ToastManager().error('激活失败: $e');
    }
  }

  /// 删除计划
  Future<void> _deletePlan(WorkoutPlan plan) async {
    try {
      await _apiService.deletePlan(plan.id!);
      _loadPlans(); // 刷新列表
      
      ToastManager().success('计划已删除');
    } catch (e) {
      ToastManager().error('删除失败: $e');
    }
  }

  /// 显示编辑计划对话框
  void _showEditPlanDialog(WorkoutPlan plan) {
    final nameController = TextEditingController(text: plan.name);
    final List<TextEditingController> dayControllers = plan.workoutDays
        .map((day) => TextEditingController(text: day.content))
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑训练计划'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '计划名称',
                    hintText: '例如：PPL三分化',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '训练日配置：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...List.generate(dayControllers.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dayControllers[index],
                            decoration: InputDecoration(
                              labelText: '第${index + 1}天',
                              hintText: '例如：推 - 胸+肩+三头',
                            ),
                          ),
                        ),
                        if (dayControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () {
                              setDialogState(() {
                                dayControllers.removeAt(index);
                              });
                            },
                          ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    setDialogState(() {
                      dayControllers.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('添加训练日'),
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
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ToastManager().warning('请输入计划名称');
                  return;
                }

                final validDays = dayControllers
                    .where((c) => c.text.isNotEmpty)
                    .toList();
                
                if (validDays.isEmpty) {
                  ToastManager().warning('请至少添加一个训练日');
                  return;
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
                  
                  // 无感更新：用返回的 plan 替换列表中的旧 plan
                  setState(() {
                    final index = _plans.indexWhere((p) => p.id == plan.id);
                    if (index != -1) {
                      _plans[index] = returnedPlan;
                    }
                  });
                  
                  if (mounted) {
                    Navigator.pop(context); // 关闭对话框
                    ToastManager().success('计划编辑成功');
                  }
                } catch (e) {
                  // 错误打印到日志，不弹框
                  debugPrint('编辑失败: $e');
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示创建计划对话框
  void _showCreatePlanDialog() {
    final nameController = TextEditingController();
    final List<TextEditingController> dayControllers = [
      TextEditingController(text: ''),
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('创建训练计划'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '计划名称',
                    hintText: '例如：PPL三分化',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '训练日配置：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...List.generate(dayControllers.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dayControllers[index],
                            decoration: InputDecoration(
                              labelText: '第${index + 1}天',
                              hintText: '例如：推 - 胸+肩+三头',
                            ),
                          ),
                        ),
                        if (dayControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () {
                              setDialogState(() {
                                dayControllers.removeAt(index);
                              });
                            },
                          ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    setDialogState(() {
                      dayControllers.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('添加训练日'),
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
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ToastManager().warning('请输入计划名称');
                  return;
                }

                // 过滤空内容
                final validDays = dayControllers
                    .where((c) => c.text.isNotEmpty)
                    .toList();
                
                if (validDays.isEmpty) {
                  ToastManager().warning('请至少添加一个训练日');
                  return;
                }

                Navigator.pop(context);

                // 创建计划
                final workoutDays = validDays.asMap().entries.map((entry) {
                  return WorkoutDay(
                    dayOrder: entry.key + 1,
                    content: entry.value.text,
                  );
                }).toList();

                final newPlan = WorkoutPlan(
                  userId: widget.userId,
                  name: nameController.text,
                  workoutDays: workoutDays,
                );

                try {
                  await _apiService.createPlan(newPlan);
                  _loadPlans();
                  
                  ToastManager().success('计划创建成功');
                } catch (e) {
                  ToastManager().error('创建失败: $e');
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
      appBar: AppBar(
        title: const Text('训练计划'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlans,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('加载失败: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPlans,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.fitness_center,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              '还没有训练计划',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreatePlanDialog,
              icon: const Icon(Icons.add),
              label: const Text('创建第一个计划'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _plans.length + 1,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        if (index == _plans.length) {
          // 最后一个：新增按钮
          return _buildAddPlanCard();
        }
        final plan = _plans[index];
        return _buildPlanCard(plan);
      },
    );
  }

  Widget _buildPlanCard(WorkoutPlan plan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: plan.isActive ? 4 : 1,
      color: plan.isActive ? Colors.amber.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (plan.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black87),
                    ),
                    child: const Text(
                      '激活中',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // 训练日列表
            ...plan.workoutDays.map((day) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${day.dayOrder}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        day.content,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            // 操作按钮 - 极简风格
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!plan.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black87),
                    ),
                    child: InkWell(
                      onTap: () => _activatePlan(plan),
                      child: const Text(
                        '启用',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                else
                  const Text(
                    '使用中',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: Colors.grey.shade600, size: 20),
                  onPressed: () => _showEditPlanDialog(plan),
                  tooltip: '编辑',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outlined, color: Colors.grey.shade600, size: 20),
                  onPressed: () => _confirmDelete(plan),
                  tooltip: '删除',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建新增计划卡片
  Widget _buildAddPlanCard() {
    return InkWell(
      onTap: _showCreatePlanDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              '新建训练计划',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(WorkoutPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除计划 "${plan.name}" 吗？'),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
