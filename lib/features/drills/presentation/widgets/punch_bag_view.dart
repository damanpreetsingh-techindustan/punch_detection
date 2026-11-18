import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/bag_targets.dart';

/// The KnockUp bag with the 1–6 targets. Draws its own number badges over
/// the printed ones, so the numbers stay correct when the targets mirror for
/// a southpaw stance.
///
/// [highlight]: the called target (pulses ember, or green when [hitFlash]).
/// [next]: the following call, drawn as a faint ring.
/// [dimmed]: rest time; the bag fades back.
/// [onTapTarget]: makes the targets tappable (legend / drill editor).
class PunchBagView extends StatefulWidget {
  final int? highlight;
  final int? next;
  final bool hitFlash;
  final bool dimmed;

  /// null = the user's setting (Settings → Southpaw).
  final bool? southpaw;
  final ValueChanged<int>? onTapTarget;

  const PunchBagView({
    super.key,
    this.highlight,
    this.next,
    this.hitFlash = false,
    this.dimmed = false,
    this.southpaw,
    this.onTapTarget,
  });

  @override
  State<PunchBagView> createState() => _PunchBagViewState();
}

class _PunchBagViewState extends State<PunchBagView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.southpaw != null) return _bag(widget.southpaw!);
    return Obx(() => _bag(StorageService.to.southpaw.value));
  }

  Widget _bag(bool southpaw) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.maxWidth;
          final badge = size * BagTargets.badgeFraction;
          return AnimatedOpacity(
            opacity: widget.dimmed ? 0.35 : 1,
            duration: const Duration(milliseconds: 300),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    BagTargets.asset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                for (final t in BagTargets.all)
                  _target(t.number, size, badge, southpaw),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _target(int n, double size, double badge, bool southpaw) {
    final p = BagTargets.positionFor(n, southpaw: southpaw);
    final isOn = widget.highlight == n;
    final isNext = !isOn && widget.next == n;
    final glow = widget.hitFlash ? AppColors.success : AppColors.primary;
    final hit = badge * 1.6; // tap area bigger than the badge
    return Positioned(
      left: p.dx * size - hit / 2,
      top: p.dy * size - hit / 2,
      width: hit,
      height: hit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTapTarget == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTapTarget!(n);
              },
        child: Center(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final pulse = isOn ? 1 + _pulse.value * 0.12 : 1.0;
              return Transform.scale(scale: pulse, child: child);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isOn ? badge * 1.25 : badge,
              height: isOn ? badge * 1.25 : badge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOn ? glow : const Color(0xFF111114),
                border: Border.all(
                  color: isOn
                      ? Colors.white
                      : isNext
                      ? AppColors.gold
                      : AppColors.primary,
                  width: isNext ? badge * 0.07 : badge * 0.05,
                ),
                boxShadow: isOn
                    ? [
                        BoxShadow(
                          color: glow.withValues(alpha: 0.8),
                          blurRadius: badge * 0.9,
                          spreadRadius: badge * 0.15,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                '$n',
                style: TextStyle(
                  fontSize: badge * (isOn ? 0.62 : 0.55),
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: isNext ? AppColors.gold : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
