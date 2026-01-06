import 'dart:async';
import 'package:flutter/material.dart';

/// Type of app toast notification
enum AppToastType {
  success,
  error,
  info,
}

/// Global overlay entry to ensure only one toast is shown at a time
OverlayEntry? _currentAppToastEntry;

/// Timer to auto-dismiss the toast
Timer? _dismissAppToastTimer;

/// Shows a non-intrusive overlay toast above bottom navigation
/// 
/// This toast appears center-bottom, just above the bottom navigation bar.
/// It automatically dismisses after ~2 seconds and replaces any previous toast.
/// 
/// [context] - BuildContext (must be mounted)
/// [message] - Message to display (max 2 lines with ellipsis)
/// [type] - Type of toast (success, error, info)
/// [extraBottomOffset] - Additional offset for screens with center mic button (default: 0)
void showAppToast(
  BuildContext context, {
  required String message,
  required AppToastType type,
  double extraBottomOffset = 0,
}) {
  // Safety check: ensure context is still mounted
  if (!context.mounted) {
    return;
  }

  // Remove previous toast if exists
  _hideCurrentAppToast();

  // Get overlay
  final overlay = Overlay.of(context, rootOverlay: true);

  // Determine colors and icon based on type
  Color backgroundColor;
  Color iconColor;
  IconData iconData;

  switch (type) {
    case AppToastType.success:
      backgroundColor = const Color(0xFF22C55E); // Green
      iconColor = Colors.white;
      iconData = Icons.check_circle;
      break;
    case AppToastType.error:
      backgroundColor = const Color(0xFFEF4444); // Red
      iconColor = Colors.white;
      iconData = Icons.error;
      break;
    case AppToastType.info:
      backgroundColor = const Color(0xFF334155); // Dark grey
      iconColor = Colors.white;
      iconData = Icons.info;
      break;
  }

  // Create overlay entry with animation
  final overlayEntry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        _AppToastWidget(
          message: message,
          backgroundColor: backgroundColor,
          iconColor: iconColor,
          iconData: iconData,
          extraBottomOffset: extraBottomOffset,
          onDismiss: () => _hideCurrentAppToast(),
        ),
      ],
    ),
  );

  // Insert overlay
  overlay.insert(overlayEntry);
  _currentAppToastEntry = overlayEntry;

  // Auto-dismiss after 2 seconds
  _dismissAppToastTimer = Timer(const Duration(milliseconds: 2000), () {
    _hideCurrentAppToast();
  });
}

/// Hides the current toast if it exists
void _hideCurrentAppToast() {
  _dismissAppToastTimer?.cancel();
  _dismissAppToastTimer = null;

  if (_currentAppToastEntry != null) {
    _currentAppToastEntry!.remove();
    _currentAppToastEntry = null;
  }
}

/// Widget that displays the app toast with animation
class _AppToastWidget extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Color iconColor;
  final IconData iconData;
  final double extraBottomOffset;
  final VoidCallback onDismiss;

  const _AppToastWidget({
    required this.message,
    required this.backgroundColor,
    required this.iconColor,
    required this.iconData,
    this.extraBottomOffset = 0,
    required this.onDismiss,
  });

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Start animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Position: center-bottom, just above bottom navigation bar
    final bottomOffset = kBottomNavigationBarHeight + 72;
    
    // Responsive width with horizontal margin
    final screenW = MediaQuery.sizeOf(context).width;
    final maxW = screenW - 32;
    final constrainedWidth = maxW < 360 ? maxW : 360.0;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomOffset + widget.extraBottomOffset,
      child: SafeArea(
        bottom: true,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: constrainedWidth,
                    minHeight: 48,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.iconData,
                        color: widget.iconColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

