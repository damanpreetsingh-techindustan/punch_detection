import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_colors.dart';
import '../utils/size_box.dart';

/// Reusable Common Permission Dialog for handling permanently denied or required permissions.
/// Explains which permissions are required and provides a direct button to open device settings.
class CommonPermissionDialog extends StatelessWidget {
  final String title;
  final String permissionName;
  final String message;
  final VoidCallback? onDismiss;

  static bool _isDialogShowing = false;

  const CommonPermissionDialog({
    super.key,
    required this.title,
    required this.permissionName,
    required this.message,
    this.onDismiss,
  });

  /// Displays the Common Permission Dialog as a modal dialog using Get.dialog.
  static Future<void> show({
    required String permissionName,
    String? customTitle,
    String? customMessage,
    VoidCallback? onDismiss,
  }) async {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    final String title = customTitle ?? '$permissionName Permission Required';
    final String message = customMessage ??
        '$permissionName permission(s) are permanently denied on your device. Please open device settings and enable $permissionName permission to proceed.';

    try {
      await Get.dialog<void>(
        CommonPermissionDialog(
          title: title,
          permissionName: permissionName,
          message: message,
          onDismiss: onDismiss,
        ),
        barrierDismissible: false,
      );
    } finally {
      _isDialogShowing = false;
    }
  }

  /// Helper utility to request a single permission and automatically show CommonPermissionDialog if permanently denied.
  static Future<bool> requestAndCheckPermission(
    Permission permission, {
    required String permissionName,
  }) async {
    PermissionStatus status = await permission.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      await show(permissionName: permissionName);
      status = await permission.status;
      return status.isGranted;
    }

    status = await permission.request();

    if (status.isPermanentlyDenied || status.isRestricted) {
      await show(permissionName: permissionName);
      status = await permission.status;
      return status.isGranted;
    }

    return status.isGranted;
  }

  /// Helper utility to check multiple permissions (e.g. Camera + Microphone) and handle permanently denied states with a SINGLE combined dialog.
  static Future<Map<Permission, bool>> checkAndRequestMultiplePermissions({
    required Map<Permission, String> permissionNames,
  }) async {
    final Map<Permission, bool> results = {};
    final List<String> permanentlyDeniedNames = [];

    // 1. First pass: check current status of all requested permissions
    for (final entry in permissionNames.entries) {
      final permission = entry.key;
      final name = entry.value;

      final status = await permission.status;
      if (status.isGranted) {
        results[permission] = true;
      } else if (status.isPermanentlyDenied || status.isRestricted) {
        permanentlyDeniedNames.add(name);
        results[permission] = false;
      }
    }

    // 2. Second pass: request any ungranted permissions that aren't permanently denied
    final List<Permission> ungrantedPermissions = permissionNames.keys
        .where((p) => results[p] != true && !permanentlyDeniedNames.contains(permissionNames[p]))
        .toList();

    if (ungrantedPermissions.isNotEmpty) {
      final Map<Permission, PermissionStatus> requestStatuses = await ungrantedPermissions.request();
      for (final permission in ungrantedPermissions) {
        final name = permissionNames[permission]!;
        final status = requestStatuses[permission] ?? PermissionStatus.denied;
        results[permission] = status.isGranted;
        if (status.isPermanentlyDenied || status.isRestricted) {
          if (!permanentlyDeniedNames.contains(name)) {
            permanentlyDeniedNames.add(name);
          }
        }
      }
    }

    // 3. If ANY permissions are permanently denied, show ONLY ONE SINGLE DIALOG listing all permanently denied permissions!
    if (permanentlyDeniedNames.isNotEmpty) {
      final String combinedNames = permanentlyDeniedNames.join(' & ');
      await show(
        permissionName: combinedNames,
        customTitle: '$combinedNames Permission Required',
        customMessage:
            '$combinedNames permission(s) are permanently denied on your device. Please open device settings and enable $combinedNames permission to proceed with workout sessions.',
      );

      // Re-verify status after user returns from settings
      for (final permission in permissionNames.keys) {
        final status = await permission.status;
        results[permission] = status.isGranted;
      }
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
        side: BorderSide(color: AppColors.border, width: 1.5.w),
      ),
      backgroundColor: AppColors.panel,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.lime.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.security_update_warning_rounded,
                    color: AppColors.lime,
                    size: 24.w,
                  ),
                ),
                12.width,
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            16.height,
            Text(
              message,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13.sp,
                height: 1.45,
              ),
            ),
            20.height,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.border, width: 1.2.w),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: () {
                      Get.back();
                      if (onDismiss != null) onDismiss!();
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                12.width,
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: () async {
                      Get.back();
                      await openAppSettings();
                    },
                    child: Text(
                      'Open Settings ⚙️',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
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
}
