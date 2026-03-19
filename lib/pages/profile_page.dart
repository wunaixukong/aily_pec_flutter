import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_ui.dart';
import 'pomodoro_page.dart';

/// 个人中心页面 - "我的"
class ProfilePage extends StatefulWidget {
  final int userId;

  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiService _apiService = ApiService();
  User? _user;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _apiService.getUserById(widget.userId);
      if (!mounted) return;
      setState(() {
        _user = user;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserInfo,
            tooltip: '刷新',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          _buildProfileHero(context),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(title: '功能与信息', subtitle: '常用工具和应用信息入口。'),
          const SizedBox(height: AppSpacing.md),
          _buildFeatureGrid(context),
        ],
      ),
    );
  }

  Widget _buildProfileHero(BuildContext context) {
    if (_isLoading) {
      return const AppStatusCard(
        icon: Icons.person_outline,
        title: '正在加载用户信息',
        message: '请稍候，马上展示你的个人资料。',
        compact: true,
      );
    }

    if (_errorMessage != null && _user == null) {
      return AppStatusCard(
        icon: Icons.error_outline,
        title: '用户信息加载失败',
        message: _errorMessage,
        accentColor: AppColors.error,
        action: ElevatedButton(
          onPressed: _loadUserInfo,
          child: const Text('重新加载'),
        ),
      );
    }

    final displayName = _user?.nickname ?? _user?.username ?? '用户';
    final lastChar = displayName.isNotEmpty
        ? displayName.substring(displayName.length - 1)
        : 'U';
    final secondaryText = _errorMessage != null
        ? '信息加载不完整，点击右上角刷新'
        : (_user?.email != null && _user!.email!.isNotEmpty)
        ? _user!.email!
        : '保持训练，持续进步。';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accent.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.06),
            Colors.white,
          ],
        ),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _buildSquircleAvatar(context, lastChar: lastChar),
            const SizedBox(height: AppSpacing.md),
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              secondaryText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _errorMessage != null
                    ? AppColors.error
                    : AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _buildHeroStat(
                    context,
                    label: '用户 ID',
                    value: '${widget.userId}',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildHeroStat(
                    context,
                    label: '状态',
                    value: _errorMessage == null ? '正常' : '待刷新',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquircleAvatar(
    BuildContext context, {
    required String lastChar,
  }) {
    return Container(
      width: 96,
      height: 96,
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.accent.withValues(alpha: 0.22),
          ],
        ),
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(42)),
        ),
        shadows: AppShadows.card,
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: const ShapeDecoration(
          color: Colors.white,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(38)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          lastChar,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStat(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.02,
      children: [
        _buildFeatureTile(
          context,
          title: '番茄钟',
          subtitle: '进入专注计时与休息提醒',
          icon: Icons.timer_outlined,
          accent: AppColors.primary,
          accentAlt: AppColors.accent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PomodoroPage()),
            );
          },
        ),
        _buildFeatureTile(
          context,
          title: '关于',
          subtitle: '查看应用版本与简介',
          icon: Icons.info_outline,
          accent: AppColors.accent,
          accentAlt: AppColors.primary,
          onTap: _showAboutDialog,
        ),
        _buildInfoTile(context, title: '训练', value: '保持节奏', note: '今天也别中断'),
        _buildInfoTile(
          context,
          title: '状态',
          value: _errorMessage == null ? '稳定' : '需刷新',
          note: '极简 · 清爽 · 专注',
        ),
      ],
    );
  }

  Widget _buildFeatureTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Color accentAlt,
    required VoidCallback onTap,
  }) {
    return AppSurfaceCard(
      onTap: onTap,
      borderRadius: AppRadius.xl,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Stack(
        children: [
          Positioned(
            top: -12,
            right: -12,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentAlt.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDuotoneIcon(
                icon: icon,
                accent: accent,
                accentAlt: accentAlt,
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    '进入',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: accent),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required String title,
    required String value,
    required String note,
  }) {
    return AppSurfaceCard(
      borderRadius: AppRadius.xl,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            note,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuotoneIcon({
    required IconData icon,
    required Color accent,
    required Color accentAlt,
  }) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 6,
            top: 8,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accentAlt.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '胸大鸡',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppSpacing.xs),
            Text('版本 1.0.0'),
            SizedBox(height: AppSpacing.md),
            Text(
              '一款简洁的健身训练计划管理应用。',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
