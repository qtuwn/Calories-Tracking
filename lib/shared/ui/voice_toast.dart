import 'dart:async';
import 'package:flutter/material.dart';

/// Type of voice toast notification
enum VoiceToastType {
  success,
  error,
  info,
}

/// Global overlay entry to ensure only one toast is shown at a time
OverlayEntry? _currentToastEntry;

/// Timer to auto-dismiss the toast
Timer? _dismissTimer;

/// Shows a non-intrusive overlay toast near the voice button area
/// 
/// This toast appears center-bottom, just above the voice button (80-120px above bottom).
/// It automatically dismisses after 1.8-2.5 seconds and replaces any previous toast.
/// 
/// [context] - BuildContext (must be mounted)
/// [message] - Message to display (max 2 lines with ellipsis)
/// [type] - Type of toast (success, error, info)
void showVoiceToast(
  BuildContext context, {
  required String message,
  required VoiceToastType type,
}) {
  // Safety check: ensure context is still mounted
  if (!context.mounted) {
    return;
  }

  // Remove previous toast if exists
  _hideCurrentToast();

  // Get overlay
                                                                                                                                                              final overlay = Overlay.of(context, rootOverlay: true);

  // Determine colors and icon based on type
  Color backgroundColor;
  Color iconColor;
  IconData iconData;

  switch (type) {
    case VoiceToastType.success:
      backgroundColor = const Color(0xFF22C55E); // Green
      iconColor = Colors.white;
      iconData = Icons.check_circle;
      break;
    case VoiceToastType.error:
      backgroundColor = const Color(0xFFEF4444); // Red
      iconColor = Colors.white;
      iconData = Icons.error;
      break;
    case VoiceToastType.info:
      backgroundColor = const Color(0xFF334155); // Dark grey
      iconColor = Colors.white;
      iconData = Icons.info;
      break;
  }

  // Create overlay entry with animation
  final overlayEntry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        _VoiceToastWidget(
          message: message,
          backgroundColor: backgroundColor,
          iconColor: iconColor,
          iconData: iconData,
          onDismiss: () => _hideCurrentToast(),
        ),
      ],
    ),
  );

  // Insert overlay
  overlay.insert(overlayEntry);
  _currentToastEntry = overlayEntry;

  // Auto-dismiss after 2 seconds
  _dismissTimer = Timer(const Duration(milliseconds: 2000), () {
    _hideCurrentToast();
  });
}

/// Hides the current toast if it exists
void _hideCurrentToast() {
  _dismissTimer?.cancel();
  _dismissTimer = null;

  if (_currentToastEntry != null) {
    _currentToastEntry!.remove();
    _currentToastEntry = null;
  }
}

/// Widget that displays the voice toast with animation
class _VoiceToastWidget extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Color iconColor;
  final IconData iconData;
  final VoidCallback onDismiss;

  const _VoiceToastWidget({
    required this.message,
    required this.backgroundColor,
    required this.iconColor,
    required this.iconData,
    required this.onDismiss,
  });

  @override
  State<_VoiceToastWidget> createState() => _VoiceToastWidgetState();
}

class _VoiceToastWidgetState extends State<_VoiceToastWidget>
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
    // Position: center-bottom, higher to avoid overlapping content
    final bottomOffset = kBottomNavigationBarHeight + 72;
    
    // Responsive width with horizontal margin
    final screenW = MediaQuery.sizeOf(context).width;
    final maxW = screenW - 32;
    final constrainedWidth = maxW < 360 ? maxW : 360.0;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomOffset,
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
                    borderRadius: BorderRadius.circular(24),
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

