import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../../core/widgets/ui/press_scale.dart';
import '../../domain/drill_program.dart';
import '../controllers/drills_controller.dart';
import 'punch_bag_view.dart';

void showDrillDetailSheet(
  BuildContext context,
  DrillProgram program,
  DrillsController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Full width in landscape (Material caps sheets at 640 px otherwise).
    constraints: const BoxConstraints(maxWidth: 1000),
    builder: (_) => _DrillDetail(program: program, controller: controller),
  );
}

/// One drill: the bag playing its first combo, description, tips, all
/// combos, the round choice and Start. Own drills can be edited or deleted.
class _DrillDetail extends StatefulWidget {
  final DrillProgram program;
  final DrillsController controller;

  const _DrillDetail({required this.program, required this.controller});

  @override
  State<_DrillDetail> createState() => _DrillDetailState();
}

class _DrillDetailState extends State<_DrillDetail> {
  static const _roundOptions = [0, 1, 3, 5];
  static const _lengthOptions = [60, 120, 180];
  static const _restOptions = [30, 45, 60];

  late RoundPlan _plan = widget.program.roundPlan;
  Timer? _demo;
  int _comboIndex = 0;
  int _step = -1;

  DrillProgram get p => widget.program;

  @override
  void initState() {
    super.initState();
    // Plays the combos on the bag at the drill's own pace.
    _demo = Timer.periodic(
      Duration(milliseconds: p.callIntervalMs.clamp(500, 1500)),
      (_) => setState(() {
        _step++;
        if (_step >= p.combos[_comboIndex].length) {
          _step = -1; // short gap between combos
          _comboIndex = (_comboIndex + 1) % p.combos.length;
        }
      }),
    );
  }

  @override
  void dispose() {
    _demo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: landscape ? _landscape() : _portrait(),
      ),
    );
  }

  Widget _portrait() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [..._titleBlock(), 14.height, _bagBlock(220), ..._details()],
      ),
    );
  }

  /// Bag on the left (fits the sheet height), everything else scrolls on
  /// the right with Start always reachable.
  Widget _landscape() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: LayoutBuilder(
              builder: (context, box) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._titleBlock(),
                  8.height,
                  _bagBlock(
                    (box.maxHeight.isFinite ? box.maxHeight - 110 : 200.0)
                        .clamp(120.0, 220.0),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _details(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _titleBlock() => [
    Row(
      children: [
        Expanded(child: Text(p.title, style: AppTextStyles.heading2())),
        GlassIconButton(
          icon: Icons.close_rounded,
          size: 38,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
    if (p.subtitle.isNotEmpty) ...[
      2.height,
      Text(p.subtitle, style: AppTextStyles.bodyMedium()),
    ],
  ];

  Widget _bagBlock(double size) {
    final combo = p.combos[_comboIndex];
    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: size),
            child: PunchBagView(
              highlight: _step >= 0 ? combo[_step] : null,
              next: _step + 1 < combo.length ? combo[_step + 1] : null,
            ),
          ),
        ),
        6.height,
        Center(
          child: Text(combo.join(' · '), style: AppTextStyles.number(null, 18)),
        ),
      ],
    );
  }

  List<Widget> _details() => [
    if (p.description.isNotEmpty) ...[
      14.height,
      Text(
        p.description,
        style: AppTextStyles.bodyLarge().copyWith(
          fontSize: 14.fs,
          color: AppColors.textSecondary,
          height: 1.45,
        ),
      ),
    ],
    for (final tip in p.tips)
      Padding(
        padding: EdgeInsets.only(top: 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.tips_and_updates_rounded,
              color: AppColors.gold,
              size: 16.r,
            ),
            8.width,
            Expanded(child: Text(tip, style: AppTextStyles.bodyMedium())),
          ],
        ),
      ),
    16.height,
    _label('Combos'),
    Wrap(
      spacing: 6.r,
      runSpacing: 6.r,
      children: [
        for (final c in p.combos)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 5.r),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              c.join('-'),
              style: AppTextStyles.number(
                null,
                13,
              ).copyWith(letterSpacing: 0.5),
            ),
          ),
      ],
    ),
    16.height,
    _label('Rounds'),
    _choices<int>(
      _withCurrent(_roundOptions, _plan.rounds),
      _plan.rounds,
      (v) => v == 0 ? 'Open' : '$v',
      (v) => setState(() => _plan = _plan.copyWith(rounds: v)),
    ),
    if (!_plan.isOpen) ...[
      12.height,
      _label('Round length'),
      _choices<int>(
        _withCurrent(_lengthOptions, _plan.roundSeconds),
        _plan.roundSeconds,
        (v) => v % 60 == 0 ? '${v ~/ 60} min' : '$v s',
        (v) => setState(() => _plan = _plan.copyWith(roundSeconds: v)),
      ),
      12.height,
      _label('Rest'),
      _choices<int>(
        _withCurrent(_restOptions, _plan.restSeconds),
        _plan.restSeconds,
        (v) => '$v s',
        (v) => setState(() => _plan = _plan.copyWith(restSeconds: v)),
      ),
    ],
    20.height,
    PrimaryButton(
      label: widget.controller.isLocked(p) ? 'Unlock with Pro' : 'Start drill',
      icon: widget.controller.isLocked(p)
          ? Icons.lock_open_rounded
          : Icons.play_arrow_rounded,
      onPressed: () => widget.controller.start(p, _plan),
    ),
    if (p.isCustom) ...[
      10.height,
      Row(
        children: [
          Expanded(
            child: GhostButton(
              label: 'Edit',
              icon: Icons.edit_rounded,
              onPressed: () => widget.controller.editDrill(p),
            ),
          ),
          10.width,
          Expanded(
            child: GhostButton(
              label: 'Delete',
              icon: Icons.delete_outline_rounded,
              color: AppColors.danger,
              onPressed: () => widget.controller.deleteDrill(context, p),
            ),
          ),
        ],
      ),
    ],
  ];

  List<int> _withCurrent(List<int> options, int current) =>
      options.contains(current) ? options : ([...options, current]..sort());

  Widget _label(String text) => Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Text(
      text.toUpperCase(),
      style: AppTextStyles.tag().copyWith(color: AppColors.textSecondary),
    ),
  );

  Widget _choices<T>(
    List<T> options,
    T selected,
    String Function(T) label,
    ValueChanged<T> onPick,
  ) {
    return Wrap(
      spacing: 8.r,
      runSpacing: 8.r,
      children: [
        for (final o in options)
          PressScale(
            onTap: () => onPick(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 8.r),
              decoration: BoxDecoration(
                gradient: o == selected ? AppColors.primaryGradient : null,
                color: o == selected ? null : AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label(o),
                style: AppTextStyles.bodyMedium().copyWith(
                  color: o == selected
                      ? AppColors.onPrimary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
