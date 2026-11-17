import 'package:get/get.dart';
import '../../../../core/utils/constants.dart';

enum PaywallPlanId { yearly, monthly, lifetime }

/// One option on the paywall. Prices are display fallbacks until the store
/// offerings load through RevenueCat.
class PaywallPlan {
  final PaywallPlanId id;
  final String title;
  final String price;
  final String period; // "per year", "per month", "one time"

  /// Fits inside the plan tile: "7 days free", "Cancel anytime".
  final String tileNote;

  /// Optional price comparison in the tile, e.g. "$2.50 / mo".
  final String? equivalent;

  /// One line under the tiles, saying exactly what the user pays.
  final String summary;
  final String? badge;
  final String cta;

  const PaywallPlan({
    required this.id,
    required this.title,
    required this.price,
    required this.period,
    required this.tileNote,
    required this.summary,
    required this.cta,
    this.badge,
    this.equivalent,
  });
}

class PaywallController extends GetxController {
  /// Opened because today's free punches are used up.
  final bool fromLimit =
      Get.arguments is Map && (Get.arguments as Map)['fromLimit'] == true;

  final Rx<PaywallPlanId> selected = PaywallPlanId.yearly.obs;
  final RxBool busy = false.obs;

  static double _amount(String price) =>
      double.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

  /// "$" from "$4.99", so derived amounts use the same currency sign.
  static String get _currency =>
      AppConstants.fallbackMonthlyPrice.replaceAll(RegExp(r'[0-9.,\s]'), '');

  /// Shown left to right: Monthly, Yearly (middle, preselected), Lifetime.
  late final List<PaywallPlan> plans = () {
    final monthly = _amount(AppConstants.fallbackMonthlyPrice);
    final yearly = _amount(AppConstants.fallbackYearlyPrice);
    final saving = monthly <= 0 ? 0 : (1 - yearly / (monthly * 12)) * 100;
    final perMonth = '$_currency${(yearly / 12).toStringAsFixed(2)}';
    const trial = AppConstants.yearlyTrialDays;
    return [
      const PaywallPlan(
        id: PaywallPlanId.monthly,
        title: 'Monthly',
        price: AppConstants.fallbackMonthlyPrice,
        period: 'per month',
        tileNote: 'Cancel anytime',
        summary: '${AppConstants.fallbackMonthlyPrice} every month',
        cta: 'Subscribe monthly',
      ),
      PaywallPlan(
        id: PaywallPlanId.yearly,
        title: 'Yearly',
        price: AppConstants.fallbackYearlyPrice,
        period: 'per year',
        tileNote: '$trial days free',
        equivalent: '$perMonth / mo',
        summary:
            '$trial days free, then ${AppConstants.fallbackYearlyPrice} a year',
        badge: saving >= 5 ? 'SAVE ${saving.round()}%' : 'BEST VALUE',
        cta: 'Start $trial-day free trial',
      ),
      const PaywallPlan(
        id: PaywallPlanId.lifetime,
        title: 'Lifetime',
        price: AppConstants.fallbackLifetimePrice,
        period: 'one time',
        tileNote: 'Pay once',
        summary:
            'Pay ${AppConstants.fallbackLifetimePrice} once, yours forever',
        cta: 'Buy lifetime access',
      ),
    ];
  }();

  PaywallPlan get selectedPlan =>
      plans.firstWhere((p) => p.id == selected.value);

  /// Store renewal terms for the selected plan (shown under the plans).
  String get finePrint {
    const manage =
        'Manage or cancel anytime in your App Store or Google Play settings.';
    switch (selected.value) {
      case PaywallPlanId.yearly:
        return 'No charge during the ${AppConstants.yearlyTrialDays}-day '
            'trial. Then the subscription renews every year unless cancelled '
            'at least 24 hours before the period ends. $manage';
      case PaywallPlanId.monthly:
        return 'Renews every month unless cancelled at least 24 hours before '
            'the period ends. $manage';
      case PaywallPlanId.lifetime:
        return 'One-time purchase. Nothing renews and there is no '
            'subscription to cancel.';
    }
  }

  void select(PaywallPlanId id) => selected.value = id;

  Future<void> purchase() async {
    if (!AppConstants.purchasesConnected) {
      _notConnected();
      return;
    }
    // RevenueCat purchase goes here (Phase 5).
  }

  Future<void> restore() async {
    if (!AppConstants.purchasesConnected) {
      _notConnected();
      return;
    }
    // RevenueCat restore goes here (Phase 5).
  }

  void _notConnected() {
    Get.snackbar(
      'Preview only',
      'Purchases are not connected yet. They work once RevenueCat and the '
          'store products are set up.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void openLegal(String title, String url) {
    if (url.isEmpty) {
      Get.snackbar(
        title,
        'Link not published yet.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
    // Opening the URL needs url_launcher (added with the real links).
  }
}
