import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/hyper_hitter_logo.dart';
import '../../../../core/utils/common_function.dart';
import '../../../../core/utils/size_box.dart';
import '../controllers/home_controller.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLandscape = CommonFunction.checkOrientationLandscape(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (isLandscape) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Brand Header, Titles & Description
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const HyperHitterLogo(scale: 1.0),
                              IconButton(
                                icon: const Icon(
                                  Icons.settings,
                                  color: AppColors.textPrimary,
                                  size: 20,
                                ),
                                onPressed: controller.openSettings,
                              ),
                            ],
                          ),
                          12.height,
                          Text(
                            'PUNCH DETECTION',
                            style: AppTextStyles.tag(context),
                          ),
                          4.height,
                          Text(
                            'Turn your mounted phone into a real-time punch detector.',
                            style: AppTextStyles.heading2(
                              context,
                            ).copyWith(fontSize: 18.ts(context), height: 1.1),
                          ),
                          6.height,
                          Text(
                            'Hyper Hitter combines impact audio and camera-based motion confirmation to count punches.',
                            style: AppTextStyles.bodyMedium(
                              context,
                            ).copyWith(fontSize: 11.ts(context)),
                          ),
                          12.height,
                          Wrap(
                            spacing: 6.w,
                            runSpacing: 6.h,
                            children: const [
                              _Badge(label: 'Works offline'),
                              _Badge(label: 'No external sensors'),
                              _Badge(label: 'iOS & Android'),
                            ],
                          ),
                          16.height,
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.panel,
                              side: const BorderSide(color: AppColors.border),
                              padding: EdgeInsets.symmetric(
                                vertical: 8.h,
                                horizontal: 16.w,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            onPressed: controller.openHistory,
                            icon: const Icon(
                              Icons.history,
                              color: AppColors.textPrimary,
                              size: 16,
                            ),
                            label: Text(
                              'Workout History',
                              style: AppTextStyles.buttonLabel(context)
                                  .copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 12.ts(context),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    16.width,

                    // Right Column: Session Mode Cards
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          _buildModeCard(
                            context: context,
                            title: 'PROMPT MODE',
                            description:
                                'Audio prompts callouts + live reaction speed scoring.',
                            icon: Icons.sports_kabaddi,
                            accentColor: AppColors.primary,
                            onTap: controller.startPromptMode,
                          ),
                          10.height,
                          _buildModeCard(
                            context: context,
                            title: 'FREE MODE',
                            description: 'Open punch counting without prompts.',
                            icon: Icons.timer_outlined,
                            accentColor: AppColors.secondary,
                            onTap: controller.startFreeMode,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 22.w),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      20.height,

                      // Brand Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const HyperHitterLogo(scale: 1.1),
                          IconButton(
                            icon: const Icon(
                              Icons.settings,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: controller.openSettings,
                          ),
                        ],
                      ),

                      24.height,

                      Text(
                        'PUNCH DETECTION',
                        style: AppTextStyles.tag(context),
                      ),
                      8.height,
                      Text(
                        'Turn your mounted phone into a real-time punch detector.',
                        style: AppTextStyles.heading2(
                          context,
                        ).copyWith(fontSize: 26.ts(context), height: 1.1),
                      ),
                      8.height,
                      Text(
                        'Hyper Hitter combines impact audio and camera-based motion confirmation to count punches and measure reaction time.',
                        style: AppTextStyles.bodyMedium(context),
                      ),

                      16.height,

                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: const [
                          _Badge(label: 'Works offline'),
                          _Badge(label: 'No external sensors'),
                          _Badge(label: 'iOS & Android'),
                        ],
                      ),

                      24.height,

                      _buildModeCard(
                        context: context,
                        title: 'PROMPT MODE',
                        description:
                            'Audio prompts callouts + live reaction speed scoring.',
                        icon: Icons.sports_kabaddi,
                        accentColor: AppColors.primary,
                        onTap: controller.startPromptMode,
                      ),
                      12.height,
                      _buildModeCard(
                        context: context,
                        title: 'FREE MODE',
                        description: 'Open punch counting without prompts.',
                        icon: Icons.timer_outlined,
                        accentColor: AppColors.secondary,
                        onTap: controller.startFreeMode,
                      ),

                      20.height,
                      const Spacer(),

                      // Action Buttons Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.panel,
                                side: const BorderSide(color: AppColors.border),
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                              onPressed: controller.openHistory,
                              icon: const Icon(
                                Icons.history,
                                color: AppColors.textPrimary,
                                size: 18,
                              ),
                              label: Text(
                                'History',
                                style: AppTextStyles.buttonLabel(context)
                                    .copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 13.ts(context),
                                    ),
                              ),
                            ),
                          ),
                          8.width,
                          Expanded(child: SizedBox()),
                        ],
                      ),

                      20.height,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.all(18.r),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46.r,
              height: 46.r,
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: Image.asset(
                  'assets/images/app_ic.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(icon, color: accentColor, size: 26.r),
                ),
              ),
            ),
            14.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading3(
                      context,
                    ).copyWith(fontSize: 16.ts(context)),
                  ),
                  3.height,
                  Text(description, style: AppTextStyles.bodyMedium(context)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 22.r),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.ts(context),
          fontWeight: FontWeight.w800,
          color: const Color(0xFFD5DAE2),
        ),
      ),
    );
  }
}
