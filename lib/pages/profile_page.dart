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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: Text(
          '我的',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _loadUserInfo,
            tooltip: '刷新',
          ),
          const SizedBox(width: AppSpacing.sm),
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
          Row(
            children: [
              const Expanded(
                child: AppSectionHeader(
                  title: '功能与信息',
                  subtitle: '常用工具和应用信息入口',
                ),
              ),
              AppBadge(
                label: '功能',
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
            ],
          ),
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

    final displayName = _user?.nickname ?? _user?.username ?? '未登录用户';
    final lastChar = displayName.isNotEmpty ? displayName.substring(displayName.length - 1) : 'U';
    final secondaryText = _errorMessage != null
        ? '信息加载不完整，点击刷新'
        : (_user?.email != null && _user!.email!.isNotEmpty)
            ? _user!.email!
            : '保持训练，持续进步。';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _buildSquircleAvatar(context, lastChar: lastChar),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      secondaryText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeroStat(
                          context,
                          label: '用户 ID',
                          value: '${widget.userId}',
                          icon: Icons.fingerprint_rounded,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildHeroStat(
                          context,
                          label: '账号状态',
                          value: _errorMessage == null ? '正常' : '待刷新',
                          icon: Icons.verified_user_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
      width: 88,
      height: 88,
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(38)),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        lastChar,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }

  Widget _buildHeroStat(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
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
          title: '配色方案',
          subtitle: '自定义应用的主题与配色',
          icon: Icons.palette_outlined,
          accent: AppColors.accent,
          accentAlt: AppColors.primary,
          onTap: () => _showColorThemeDialog(context),
        ),
        _buildFeatureTile(
          context,
          title: '关于',
          subtitle: '查看应用版本与简介',
          icon: Icons.info_outline,
          accent: Colors.orange,
          accentAlt: Colors.amber,
          onTap: _showAboutDialog,
        ),
        _buildFeatureTile(
          context,
          title: '同步数据',
          subtitle: '从服务器拉取最新资料',
          icon: Icons.sync_rounded,
          accent: AppColors.success,
          accentAlt: Colors.teal,
          onTap: _loadUserInfo,
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
      padding: const EdgeInsets.all(AppSpacing.md),
      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      child: Stack(
        children: [
          Positioned(
            top: -16,
            right: -16,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    '立即进入',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 10, color: accent),
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

  void _showColorThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择配色方案'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              context,
              name: '极简蓝 (当前)',
              color: const Color(0xFF5B6CF0),
            ),
            _buildThemeOption(
              context,
              name: '钢铁黑',
              color: const Color(0xFF182033),
            ),
            _buildThemeOption(
              context,
              name: '动力红',
              color: const Color(0xFFD14343),
            ),
            _buildThemeOption(
              context,
              name: '森林绿',
              color: const Color(0xFF169B62),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String name,
    required Color color,
  }) {
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(name),
      onTap: () {
        // TODO: 实际应用全局主题切换逻辑
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已切换至 $name (UI 演示)')));
      },
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
