// CivilHand Interactive Swipe-to-Confirm Action Slider
// Native Flutter gesture detection, spring physics, and animated completion

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeToConfirmSlider extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color activeColor;
  final Future<void> Function() onConfirmed;

  const SwipeToConfirmSlider({
    super.key,
    required this.label,
    this.icon = Icons.arrow_forward_rounded,
    this.activeColor = const Color(0xFF4F46E5),
    required this.onConfirmed,
  });

  @override
  State<SwipeToConfirmSlider> createState() => _SwipeToConfirmSliderState();
}

class _SwipeToConfirmSliderState extends State<SwipeToConfirmSlider>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isCompleted = false;
  bool _isLoading = false;

  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_isCompleted || _isLoading) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  Future<void> _onHorizontalDragEnd(DragEndDetails details, double maxDrag) async {
    if (_isCompleted || _isLoading) return;

    if (_dragPosition >= maxDrag * 0.82) {
      // Swiped past threshold -> complete
      HapticFeedback.mediumImpact();
      setState(() {
        _dragPosition = maxDrag;
        _isCompleted = true;
        _isLoading = true;
      });

      try {
        await widget.onConfirmed();
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // Release below threshold -> snap back with spring curve
      _resetAnimation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
        CurvedAnimation(parent: _resetController, curve: Curves.easeOutBack),
      )..addListener(() {
          setState(() {
            _dragPosition = _resetAnimation.value;
          });
        });
      _resetController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double height = 58.0;
    const double thumbSize = 48.0;
    const double padding = 5.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag = constraints.maxWidth - thumbSize - (padding * 2);
        final double progress = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

        return Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9), // Slate 100
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Stack(
            children: [
              // 1. Fill gradient that follows thumb
              Container(
                width: _dragPosition + thumbSize + padding,
                decoration: BoxDecoration(
                  color: widget.activeColor.withOpacity(0.15 + (progress * 0.15)),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),

              // 2. Central label (fades out as thumb passes over it)
              Center(
                child: Opacity(
                  opacity: (1.0 - (progress * 1.5)).clamp(0.0, 1.0),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

              // 3. Draggable Slider Thumb
              Positioned(
                left: padding + _dragPosition,
                top: padding,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => _onHorizontalDragUpdate(d, maxDrag),
                  onHorizontalDragEnd: (d) => _onHorizontalDragEnd(d, maxDrag),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    height: thumbSize,
                    width: thumbSize,
                    decoration: BoxDecoration(
                      color: _isCompleted ? const Color(0xFF16A34A) : widget.activeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.activeColor.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              _isCompleted ? Icons.check_rounded : widget.icon,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
