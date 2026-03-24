import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.border,
    this.boxShadow,
    this.onTap,
    this.margin,
    this.borderRadius = AppRadius.lg,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: radius,
        border: border ?? Border.all(color: AppColors.border),
        boxShadow: boxShadow ?? AppShadows.card,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: radius, onTap: onTap, child: content),
    );
  }
}

class AppGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? color;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final Border? border;

  const AppGlassCard({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.lg,
    this.color,
    this.blur = 10,
    this.opacity = 0.1,
    this.padding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (color ?? Colors.white).withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border:
                border ??
                Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AppDuotoneIcon extends StatelessWidget {
  final int index; // 0: 训练, 1: 计划, 2: 我的
  final Color color;
  final double size;
  final bool isSelected;

  const AppDuotoneIcon({
    super.key,
    required this.index,
    required this.color,
    this.size = 24,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isSelected ? size * 1.2 : 0,
            height: isSelected ? size * 1.2 : 0,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
          ),
          CustomPaint(
            size: Size(size, size),
            painter: _PremiumIconPainter(
              index: index,
              color: color,
              strokeWidth: isSelected ? 2.5 : 2.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumIconPainter extends CustomPainter {
  final int index;
  final Color color;
  final double strokeWidth;

  _PremiumIconPainter({
    required this.index,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    if (index == 0) {
      // 导航：训练图标 (Bolt)
      final path = Path()
        ..moveTo(w * 0.55, h * 0.1)
        ..lineTo(w * 0.2, h * 0.55)
        ..lineTo(w * 0.5, h * 0.55)
        ..lineTo(w * 0.45, h * 0.9)
        ..lineTo(w * 0.8, h * 0.45)
        ..lineTo(w * 0.5, h * 0.45)
        ..close();
      canvas.drawPath(path, paint);
    } else if (index == 1) {
      // 导航：计划图标 (Layers)
      canvas.drawRRect(
        RRect.fromLTRBR(w * 0.1, h * 0.15, w * 0.9, h * 0.35, const Radius.circular(4)),
        paint,
      );
      canvas.drawRRect(
        RRect.fromLTRBR(w * 0.1, h * 0.45, w * 0.7, h * 0.65, const Radius.circular(4)),
        paint,
      );
      canvas.drawRRect(
        RRect.fromLTRBR(w * 0.1, h * 0.75, w * 0.5, h * 0.95, const Radius.circular(4)),
        paint,
      );
    } else if (index == 2) {
      // 导航：助手图标 (Sparkles/Chat)
      final path = Path()
        ..moveTo(w * 0.2, h * 0.5)
        ..quadraticBezierTo(w * 0.2, h * 0.2, w * 0.5, h * 0.2)
        ..quadraticBezierTo(w * 0.8, h * 0.2, w * 0.8, h * 0.5)
        ..quadraticBezierTo(w * 0.8, h * 0.8, w * 0.5, h * 0.8)
        ..lineTo(w * 0.3, h * 0.9)
        ..lineTo(w * 0.35, h * 0.75)
        ..quadraticBezierTo(w * 0.2, h * 0.7, w * 0.2, h * 0.5);
      canvas.drawPath(path, paint);
      // 绘制一个小星星装饰
      canvas.drawCircle(Offset(w * 0.65, h * 0.4), 1.5, paint..style = PaintingStyle.fill);
    } else if (index == 3) {
      // 导航：我的图标 (User)
      canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.22, paint);
      final path = Path()
        ..moveTo(w * 0.15, h * 0.9)
        ..quadraticBezierTo(w * 0.15, h * 0.65, w * 0.5, h * 0.65)
        ..quadraticBezierTo(w * 0.85, h * 0.65, w * 0.85, h * 0.9);
      canvas.drawPath(path, paint);
    } else if (index == 10) {
      // 页面：训练内容 (Hexagon Core)
      final path = Path();
      for (var i = 0; i < 6; i++) {
        final angle = (i * 60) * (3.1415926 / 180);
        final x = w * 0.5 + w * 0.45 * (i % 2 == 0 ? 0.9 : 1.0) * (0.8) * (i == 0 || i == 3 ? 1.1 : 1) * 0; // Just kidding, let's do a real hexagon
      }
      // Simple Hexagon
      path.moveTo(w * 0.5, h * 0.1);
      path.lineTo(w * 0.9, h * 0.3);
      path.lineTo(w * 0.9, h * 0.7);
      path.lineTo(w * 0.5, h * 0.9);
      path.lineTo(w * 0.1, h * 0.7);
      path.lineTo(w * 0.1, h * 0.3);
      path.close();
      canvas.drawPath(path, paint);
      canvas.drawCircle(Offset(w * 0.5, h * 0.5), 2, paint..style = PaintingStyle.fill);
    } else if (index == 11) {
      // 页面：节奏/目标 (Crosshair)
      canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.35, paint);
      canvas.drawLine(Offset(w * 0.5, h * 0.1), Offset(w * 0.5, h * 0.3), paint);
      canvas.drawLine(Offset(w * 0.5, h * 0.7), Offset(w * 0.5, h * 0.9), paint);
      canvas.drawLine(Offset(w * 0.1, h * 0.5), Offset(w * 0.3, h * 0.5), paint);
      canvas.drawLine(Offset(w * 0.7, h * 0.5), Offset(w * 0.9, h * 0.5), paint);
    } else if (index == 12) {
      // 页面：列表 (Steps)
      canvas.drawLine(Offset(w * 0.2, h * 0.2), Offset(w * 0.2, h * 0.8), paint);
      canvas.drawCircle(Offset(w * 0.2, h * 0.2), 1.5, paint..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(w * 0.2, h * 0.5), 1.5, paint..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(w * 0.2, h * 0.8), 1.5, paint..style = PaintingStyle.fill);
      canvas.drawLine(Offset(w * 0.4, h * 0.2), Offset(w * 0.85, h * 0.2), paint..style = PaintingStyle.stroke);
      canvas.drawLine(Offset(w * 0.4, h * 0.5), Offset(w * 0.75, h * 0.5), paint..style = PaintingStyle.stroke);
      canvas.drawLine(Offset(w * 0.4, h * 0.8), Offset(w * 0.65, h * 0.8), paint..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class AppStatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color accentColor;
  final bool compact;

  const AppStatusCard({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.accentColor = AppColors.info,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSurfaceCard(
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 56 : 72,
            height: compact ? 56 : 72,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(icon, color: accentColor, size: compact ? 28 : 36),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

class AppBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final int? customIconIndex;

  const AppBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.customIconIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customIconIndex != null) ...[
            AppDuotoneIcon(index: customIconIndex!, color: color, size: 14),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
