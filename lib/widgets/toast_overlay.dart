import 'package:flutter/material.dart';
import 'dart:async';

/// Toast 通知项
class ToastItem {
  final String message;
  final ToastType type;
  final String id;

  ToastItem({
    required this.message,
    required this.type,
  }) : id = DateTime.now().millisecondsSinceEpoch.toString();
}

/// Toast 类型
enum ToastType {
  success,
  error,
  info,
  warning,
}

/// 全局 Toast 管理器
class ToastManager extends ChangeNotifier {
  static final ToastManager _instance = ToastManager._internal();
  factory ToastManager() => _instance;
  ToastManager._internal();

  final List<ToastItem> _toasts = [];
  List<ToastItem> get toasts => List.unmodifiable(_toasts);

  /// 显示成功提示
  void success(String message) {
    _addToast(message, ToastType.success);
  }

  /// 显示错误提示
  void error(String message) {
    _addToast(message, ToastType.error);
  }

  /// 显示信息提示
  void info(String message) {
    _addToast(message, ToastType.info);
  }

  /// 显示警告提示
  void warning(String message) {
    _addToast(message, ToastType.warning);
  }

  void _addToast(String message, ToastType type) {
    // 限制最多显示 3 个，新的顶掉旧的
    if (_toasts.length >= 3) {
      _toasts.removeAt(0);
    }
    _toasts.add(ToastItem(message: message, type: type));
    notifyListeners();

    // 3 秒后自动移除
    Timer(const Duration(seconds: 3), () {
      _removeToast(_toasts.firstWhere((t) => t.message == message && t.type == type,
          orElse: () => _toasts.first));
    });
  }

  void _removeToast(ToastItem toast) {
    _toasts.removeWhere((t) => t.id == toast.id);
    notifyListeners();
  }

  /// 手动移除指定 Toast
  void remove(String id) {
    _toasts.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// 清空所有 Toast
  void clear() {
    _toasts.clear();
    notifyListeners();
  }
}

/// Toast 气泡组件
class ToastBubble extends StatelessWidget {
  final ToastItem toast;
  final VoidCallback onDismiss;

  const ToastBubble({
    super.key,
    required this.toast,
    required this.onDismiss,
  });

  // 统一使用浅灰半透明背景
  Color get _backgroundColor {
    return Colors.grey.shade50.withValues(alpha: 0.95);
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
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, color: Colors.black87, size: 20),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  toast.message,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onDismiss,
                child: Icon(Icons.close, color: Colors.black54, size: 16),
              ),
            ],
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
        // Toast 层
        if (_manager.toasts.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
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
