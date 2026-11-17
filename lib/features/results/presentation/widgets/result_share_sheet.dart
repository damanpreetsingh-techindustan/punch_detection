import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/knockup_logo.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../history/domain/history_insights.dart';
import '../controllers/results_controller.dart';

/// Preview of the result image card with a Share button.
void showResultShareSheet(BuildContext context, ResultsController controller) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ShareSheet(controller: controller),
  );
}

class _ShareSheet extends StatefulWidget {
  final ResultsController controller;

  const _ShareSheet({required this.controller});

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // 320 x 400 card at 3.4x → ~1088 x 1360, good for stories and chats.
      final ui.Image image = await boundary.toImage(pixelRatio: 3.4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/knockup_result_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      final punches = widget.controller.result.totalPunches;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: 'I just threw $punches punches with ${AppConstants.appName} 🥊',
        ),
      );
    } catch (_) {
      Get.snackbar(
        'Could not share',
        'Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Share your session', style: AppTextStyles.heading2()),
            16.height,
            Center(
              child: FittedBox(
                child: RepaintBoundary(
                  key: _cardKey,
                  child: ResultShareCard(controller: widget.controller),
                ),
              ),
            ),
            20.height,
            PrimaryButton(
              label: 'Share',
              icon: Icons.ios_share_rounded,
              loading: _sharing,
              onPressed: _sharing ? null : _share,
            ),
          ],
        ),
      ),
    );
  }
}

/// The image people share: fixed 320 x 400 logical size, no screen scaling,
/// so it looks the same on every phone.
class ResultShareCard extends StatelessWidget {
  final ResultsController controller;

  const ResultShareCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final r = controller.result;
    final drill = r.drill;
    final stats = <(String, String)>[
      ('TIME', DateLabels.duration(r.durationSeconds)),
      ('PER MIN', controller.pace.round().toString()),
      if (drill != null) ('BEST STREAK', '${drill.bestStreak}'),
    ];
    return Container(
      width: 320,
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(28),
        gradient: const RadialGradient(
          center: Alignment(0, -0.4),
          radius: 1.1,
          colors: [Color(0x55FF4D2E), AppColors.bg],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KnockUpLogo(scale: 0.8),
          const Spacer(),
          Text(
            controller.title.toUpperCase(),
            style: AppTextStyles.tag().copyWith(
              fontSize: 11,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${r.totalPunches}',
            style: AppTextStyles.number().copyWith(
              fontSize: 96,
              shadows: [
                Shadow(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  blurRadius: 30,
                ),
              ],
            ),
          ),
          Text(
            'punches',
            style: AppTextStyles.bodyLarge().copyWith(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              for (final s in stats)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.$1,
                        style: AppTextStyles.tag().copyWith(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.$2,
                        style: AppTextStyles.number().copyWith(fontSize: 22),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            AppConstants.tagline,
            style: AppTextStyles.bodyMedium().copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
