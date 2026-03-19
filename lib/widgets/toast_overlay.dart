import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Toast 通知项
class ToastItem {
  final String message;
  final ToastType type;
  final String id;

  ToastItem({required this.message, required this.type})
    : id = DateTime.now().millisecondsSinceEpoch.toString();
}

/// Toast 类型
enum ToastType { success, error, info, warning }

/// 全局 Toast 管理器
class ToastManager extends ChangeNotifier {
  static final ToastManager _instance = ToastManager._internal();
  factory ToastManager() => _instance;
  ToastManager._internal();

  final List<ToastItem> _toasts = [];
  List<ToastItem> get toasts => List.unmodifiable(_toasts);

  void success(String message) => _addToast(message, ToastType.success);
  void error(String message) => _addToast(message, ToastType.error);
  void info(String message) => _addToast(message, ToastType.info);
  void warning(String message) => _addToast(message, ToastType.warning);

  void _addToast(String message, ToastType type) {
    if (_toasts.length >= 3) {
      _toasts.removeAt(0);
    }
    final toast = ToastItem(message: message, type: type);
    _toasts.add(toast);
    notifyListeners();

    Timer(const Duration(seconds: 3), () {
      _removeToast(toast);
    });
  }

  void _removeToast(ToastItem toast) {
    _toasts.removeWhere((t) => t.id == toast.id);
    notifyListeners();
  }

  void remove(String id) {
    _toasts.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void clear() {
    _toasts.clear();
    notifyListeners();
  }
}

/// Toast 气泡组件
class ToastBubble extends StatelessWidget {
  final ToastItem toast;
  final VoidCallback onDismiss;

  const ToastBubble({super.key, required this.toast, required this.onDismiss});

  Color get _accentColor {
    switch (toast.type) {
      case ToastType.success:
        return AppColors.success;
      case ToastType.error:
        return AppColors.error;
      case ToastType.warning:
        return AppColors.warning;
      case ToastType.info:
        return AppColors.info;
    }
  }

  Color get _backgroundColor {
    switch (toast.type) {
      case ToastType.success:
        return AppColors.successSoft;
      case ToastType.error:
        return AppColors.errorSoft;
      case ToastType.warning:
        return AppColors.warningSoft;
      case ToastType.info:
        return AppColors.infoSoft;
    }
  }

  IconData get _icon {
    switch (toast.type) {
      case ToastType.success:
        return Icons.check_circle_outline;
      case ToastType.error:
        return Icons.error_outline;
      case ToastType.warning:
        return Icons.warning_amber_outlined;
      case ToastType.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(toast.id),
      direction: DismissDirection.up,
      onDismissed: (_) => onDismiss(),
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: _backgroundColor.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: _accentColor.withValues(alpha: 0.15)),
            boxShadow: AppShadows.card,
          ),
          child: IntrinsicWidth(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon, color: _accentColor, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    toast.message,
                    style: TextStyle(
                      color: _accentColor.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Toast 覆盖层 - 放在页面顶部
class ToastOverlay extends StatefulWidget {
  final Widget child;

  const ToastOverlay({super.key, required this.child});

  @override
  State<ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<ToastOverlay> {
  final ToastManager _manager = ToastManager();

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onToastChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onToastChanged);
    super.dispose();
  }

  void _onToastChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_manager.toasts.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpacing.xs,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _manager.toasts.map((toast) {
                  return ToastBubble(
                    toast: toast,
                    onDismiss: () => _manager.remove(toast.id),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}
