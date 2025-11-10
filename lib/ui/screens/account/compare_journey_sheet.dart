import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../providers/compare_journey_provider.dart';
import '../../../providers/profile_provider.dart';

class CompareJourneySheet extends StatefulWidget {
  const CompareJourneySheet({super.key});

  @override
  State<CompareJourneySheet> createState() => _CompareJourneySheetState();
}

class _CompareJourneySheetState extends State<CompareJourneySheet> {
  bool _isSharing = false;

  Future<Map<String, double?>> _askWeights(
    BuildContext ctx, {
    double? current,
  }) async {
    final startCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    if (current != null) {
      // show current weight as a hint in the dialog
      // not pre-filling the start/target to let user enter their numbers
    }

    final res = await showDialog<Map<String, double?>>(
      context: ctx,
      builder: (_) {
        return AlertDialog(
          title: const Text('Thông tin cân nặng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: startCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Cân nặng bắt đầu (kg)',
                ),
              ),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Mục tiêu (kg)'),
              ),
              if (current != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Cân nặng hiện tại: ${current.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                final s = double.tryParse(startCtrl.text.replaceAll(',', '.'));
                final t = double.tryParse(targetCtrl.text.replaceAll(',', '.'));
                Navigator.of(ctx).pop({'start': s, 'target': t});
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    return {
      'start': res == null ? null : res['start'],
      'target': res == null ? null : res['target'],
    };
  }

  Future<void> _pick(BuildContext ctx, bool left) async {
    final provider = ctx.read<CompareJourneyProvider>();
    final source = await showModalBottomSheet<ImageSource?>(
      context: ctx,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh mới'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    if (left) {
      await provider.pickLeft(source);
    } else {
      await provider.pickRight(source);
    }
    setState(() {});
  }

  Future<void> _share(BuildContext ctx) async {
    final provider = ctx.read<CompareJourneyProvider>();
    setState(() => _isSharing = true);
    try {
      final profile = ctx.read<ProfileProvider>().profile;
      final weights = await _askWeights(ctx, current: profile.weightKg);
      if (!mounted) return;
      final combined = await provider.createDecoratedCombinedImage(
        saveToHistory: true,
        startKg: weights['start'],
        currentKg: profile.weightKg,
        targetKg: weights['target'],
      );
      if (combined == null) return;
      // Use SharePlus.instance.share with ShareParams to avoid deprecated APIs
      await SharePlus.instance.share(
        ShareParams(
          text: 'So sánh hành trình cân nặng của tôi',
          files: [XFile(combined.path)],
        ),
      );
    } finally {
      setState(() => _isSharing = false);
    }
  }

  void _openPreview(BuildContext ctx) {
    final provider = ctx.read<CompareJourneyProvider>();
    final l = provider.leftFile();
    final r = provider.rightFile();
    if (l == null || r == null) return;
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: 420,
          child: _BeforeAfterPreview(left: l, right: r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1F1726),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'So sánh hành trình thay đổi',
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pick(context, true),
                    child: Consumer<CompareJourneyProvider>(
                      builder: (ctx, prov, _) {
                        final has = prov.hasLeft;
                        return SizedBox(
                          height: 120,
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: has
                                      ? Colors.deepPurple.shade300
                                      : Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(10),
                                  image: has && prov.leftPath != null
                                      ? DecorationImage(
                                          image: FileImage(
                                            File(prov.leftPath!),
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                height: 120,
                              ),
                              if (!has)
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Thêm ảnh để bắt đầu ghi lại hành trình cân nặng',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // overlay actions
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Row(
                                  children: [
                                    if (has)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        onPressed: () => _pick(context, true),
                                      ),
                                    if (has)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        onPressed: () async {
                                          await prov.clearLeft();
                                          setState(() {});
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pick(context, false),
                    child: Consumer<CompareJourneyProvider>(
                      builder: (ctx, prov, _) {
                        final has = prov.hasRight;
                        return Stack(
                          children: [
                            SizedBox(
                              height: 120,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: has
                                      ? Colors.deepPurple.shade300
                                      : Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(10),
                                  image: has && prov.rightPath != null
                                      ? DecorationImage(
                                          image: FileImage(
                                            File(prov.rightPath!),
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            if (!has)
                              const Center(
                                child: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Row(
                                children: [
                                  if (has)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      onPressed: () => _pick(context, false),
                                    ),
                                  if (has)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      onPressed: () async {
                                        await prov.clearRight();
                                        setState(() {});
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // history thumbnails
            FutureBuilder<List<String>>(
              future: context.read<CompareJourneyProvider>().getHistoryPaths(),
              builder: (ctx, snap) {
                final list = snap.data ?? [];
                if (list.isEmpty) return const SizedBox.shrink();
                return SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (c, i) {
                      final p = list[i];
                      return GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: Image.file(File(p), fit: BoxFit.contain),
                            ),
                          );
                        },
                        onLongPress: () async {
                          final provRef = context
                              .read<CompareJourneyProvider>();
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Xóa ảnh lưu'),
                              content: const Text(
                                'Bạn có muốn xóa ảnh này khỏi lịch sử?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Hủy'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await provRef.removeHistoryEntry(p);
                            setState(() {});
                          }
                        },
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(File(p)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: list.length,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Consumer<CompareJourneyProvider>(
                    builder: (ctx, prov, _) {
                      return ElevatedButton(
                        onPressed: prov.hasLeft && prov.hasRight
                            ? () => _openPreview(ctx)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4B2B88),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('Xem so sánh'),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Consumer<CompareJourneyProvider>(
                    builder: (ctx, prov, _) {
                      return ElevatedButton(
                        onPressed: prov.hasLeft && prov.hasRight && !_isSharing
                            ? () => _share(ctx)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4B2B88),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _isSharing
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Chia sẻ'),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _BeforeAfterPreview extends StatefulWidget {
  final File left;
  final File right;
  const _BeforeAfterPreview({required this.left, required this.right});

  @override
  State<_BeforeAfterPreview> createState() => _BeforeAfterPreviewState();
}

class _BeforeAfterPreviewState extends State<_BeforeAfterPreview> {
  double _divider = 0.5;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(child: Image.file(widget.right, fit: BoxFit.cover)),
            // left image clipped by divider
            Positioned.fill(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final w = constraints.maxWidth * _divider;
                  return Stack(
                    children: [
                      Positioned(
                        width: w,
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Image.file(widget.left, fit: BoxFit.cover),
                      ),
                      Positioned(
                        left: w - 12,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (e) {},
                          onPanUpdate: (e) {
                            final box = context.findRenderObject() as RenderBox;
                            final local = box.globalToLocal(e.globalPosition);
                            setState(
                              () => _divider = (local.dx / box.size.width)
                                  .clamp(0.0, 1.0),
                            );
                          },
                          child: Container(
                            width: 24,
                            color: Colors.transparent,
                            child: Center(
                              child: Container(width: 3, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
