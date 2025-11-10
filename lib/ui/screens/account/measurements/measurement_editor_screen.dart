import 'package:flutter/material.dart';

class MeasurementEditorScreen extends StatefulWidget {
  final String title;
  final String unit;
  final double min;
  final double max;
  final double initialValue;
  final int decimals;
  final String? imageAsset;

  const MeasurementEditorScreen({
    super.key,
    required this.title,
    required this.unit,
    this.min = 0,
    this.max = 200,
    this.initialValue = 0,
    this.decimals = 1,
    this.imageAsset,
  });

  @override
  State<MeasurementEditorScreen> createState() =>
      _MeasurementEditorScreenState();
}

class _MeasurementEditorScreenState extends State<MeasurementEditorScreen> {
  late double value;

  @override
  void initState() {
    super.initState();
    value = widget.initialValue.clamp(widget.min, widget.max);
  }

  String get formattedValue {
    return value.toStringAsFixed(widget.decimals) +
        (widget.unit.isNotEmpty ? ' ${widget.unit}' : '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // background gradient top
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Color(0xFF3A0B73), Color(0x00000000)],
                ),
              ),
            ),
            Column(
              children: [
                // header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // illustration area
                      SizedBox(
                        height: 180,
                        child: widget.imageAsset != null
                            ? Image.asset(
                                widget.imageAsset!,
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, err, stack) => const Icon(
                                  Icons.person_outline,
                                  size: 96,
                                  color: Colors.white24,
                                ),
                              )
                            : const Icon(
                                Icons.person_outline,
                                size: 96,
                                color: Colors.white24,
                              ),
                      ),

                      const SizedBox(height: 24),

                      // value
                      Text(
                        formattedValue,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 18),

                      // pointer + ruler
                      SizedBox(
                        height: 120,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Positioned.fill(
                              left: 40,
                              child: CustomPaint(
                                painter: _RulerPainter(
                                  min: widget.min,
                                  max: widget.max,
                                  divisions: 40,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                            // pointer line
                            Positioned(
                              left:
                                  40 +
                                  _valueToOffset(
                                    value,
                                    widget.min,
                                    widget.max,
                                    context,
                                  ),
                              top: 12,
                              bottom: 12,
                              child: Container(
                                width: 2,
                                color: const Color(0xFF9A7FFF),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // slider for input (hidden style)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            activeTrackColor: const Color(0xFF9A7FFF),
                            inactiveTrackColor: Colors.white10,
                          ),
                          child: Slider(
                            value: value,
                            min: widget.min,
                            max: widget.max,
                            divisions: ((widget.max - widget.min) * (10))
                                .round(),
                            onChanged: (v) => setState(() => value = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Save button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9A7FFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(value);
                      },
                      child: const Text('Ghi lại'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _valueToOffset(double v, double min, double max, BuildContext ctx) {
    final width =
        MediaQuery.of(ctx).size.width - 40 - 32; // left offset + padding
    final t = ((v - min) / (max - min)).clamp(0.0, 1.0);
    return t * width;
  }
}

class _RulerPainter extends CustomPainter {
  final double min;
  final double max;
  final int divisions;
  final Color color;

  _RulerPainter({
    required this.min,
    required this.max,
    this.divisions = 20,
    this.color = Colors.white24,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    final minor = 6.0;
    final major = 14.0;
    for (int i = 0; i <= divisions; i++) {
      final dx = (size.width) * (i / divisions);
      final isMajor = i % 5 == 0;
      final h = isMajor ? major : minor;
      canvas.drawLine(
        Offset(dx, size.height - h),
        Offset(dx, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
