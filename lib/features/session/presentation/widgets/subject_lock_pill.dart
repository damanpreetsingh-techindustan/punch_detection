import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/size_box.dart';
import '../../../vision_detection/domain/subject_lock/subject_lock.dart';

/// Small pill on the camera preview once the reference photo is taken: who
/// the camera follows, with the photo. Tap = retake the photo.
/// (Before the photo, [ReferencePhotoCard] is shown instead.)
class SubjectLockPill extends StatelessWidget {
  final Rx<SubjectLockState> state;
  final VoidCallback onTap;

  /// Hidden while this returns false (lock off, camera not running).
  final bool Function() isVisible;

  final Rx<ui.Image?>? photo;

  /// Debug colours: learned from the photo / seen now. Both should match the
  /// user's shirt (checks the pixel mapping on a new device).
  final Rx<Color?>? referenceColor;
  final Rx<Color?>? liveColor;

  const SubjectLockPill({
    super.key,
    required this.state,
    required this.onTap,
    required this.isVisible,
    this.photo,
    this.referenceColor,
    this.liveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!isVisible()) return const SizedBox.shrink();
      final String label;
      final Color color;
      switch (state.value) {
        case SubjectLockState.waitingForUser:
        case SubjectLockState.holdStill:
        case SubjectLockState.enrolling:
          return const SizedBox.shrink();
        case SubjectLockState.locked:
          label = 'Tracking you';
          color = AppColors.lime;
        case SubjectLockState.verifying:
          label = 'Show your face to confirm it is you';
          color = AppColors.amber;
        case SubjectLockState.otherPerson:
          label = 'Other person in view · tap to retake photo';
          color = AppColors.red;
      }
      final ui.Image? image = photo?.value;
      Widget dot(Color? fill) => Container(
        width: 9.w,
        height: 9.w,
        margin: EdgeInsets.only(left: 4.w),
        decoration: BoxDecoration(
          color: fill ?? Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textMuted, width: 0.8),
        ),
      );
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1E2E).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999.r),
            border: Border.all(color: color),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null)
                ClipOval(
                  child: RawImage(
                    image: image,
                    width: 16.w,
                    height: 16.w,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Icon(Icons.person_pin_rounded, color: color, size: 12.w),
              4.width,
              // Flexible: the label is the longest part of the pill ("Other
              // person in view..."), so it is the one that gives way to a
              // narrow screen / landscape width instead of overflowing.
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 9.ts(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (AppConstants.showAllFeatures && referenceColor != null) ...[
                dot(referenceColor!.value),
                dot(liveColor?.value),
              ],
            ],
          ),
        ),
      );
    });
  }
}

/// Card on the camera preview at the start of a session: asks the user to
/// stand in front of the camera and hold still, then shows the reference
/// photo that was taken. Nothing the camera sees counts until then.
class ReferencePhotoCard extends StatelessWidget {
  final Rx<SubjectLockState> state;
  final RxInt holdStillSeconds;
  final Rx<ui.Image?>? photo;
  final VoidCallback onSkip;

  /// Hidden while this returns false (lock off, camera not running).
  final bool Function() isVisible;

  const ReferencePhotoCard({
    super.key,
    required this.state,
    required this.holdStillSeconds,
    required this.onSkip,
    required this.isVisible,
    this.photo,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!isVisible()) return const SizedBox.shrink();
      final String title;
      final String subtitle;
      final Color color;
      switch (state.value) {
        case SubjectLockState.locked:
        case SubjectLockState.verifying:
        case SubjectLockState.otherPerson:
          return const SizedBox.shrink();
        case SubjectLockState.waitingForUser:
          title = 'Reference photo';
          subtitle = 'Stand in front of the camera, face and shoulders in view';
          color = AppColors.amber;
        case SubjectLockState.holdStill:
          title = 'Hold still… ${holdStillSeconds.value}';
          subtitle = 'Taking your reference photo';
          color = AppColors.lime;
        case SubjectLockState.enrolling:
          title = 'Photo taken';
          subtitle = 'Learning your look…';
          color = AppColors.lime;
      }
      final ui.Image? image = photo?.value;
      final bool canSkip = state.value != SubjectLockState.enrolling;
      return Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1E2E).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: RawImage(
                  image: image,
                  width: 36.w,
                  height: 48.w,
                  fit: BoxFit.cover,
                ),
              )
            else
              Icon(Icons.photo_camera_front_rounded, color: color, size: 26.w),
            8.width,
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 12.ts(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  2.height,
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 9.ts(context),
                    ),
                  ),
                ],
              ),
            ),
            if (canSkip) ...[
              6.width,
              TextButton(
                onPressed: onSkip,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.ts(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
