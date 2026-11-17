# KnockUp — Launch Setup Guide

How to switch on everything that needs outside accounts:

1. **Subscriptions** (RevenueCat + App Store + Google Play)
2. **Firebase**: Crashlytics, Analytics and events
3. **Connectivity** (online/offline)
4. **Privacy Policy & Terms** hosted on Firebase Hosting
5. **Release checklist** (the switches in `constants.dart`)

Each section says who does it:
- **[Console]**: you, in a website or dashboard.
- **[Code]**: changes in this repo. Ask Claude to "implement section N" once the console steps are done.

---

## 0. Before you start

| Item | Value | Notes |
|---|---|---|
| Android app id | `com.finalview.knockup` | Set in `android/app/build.gradle.kts`. |
| iOS bundle id | **Owner-managed** (currently `com.daman.punch-detection-demo` for testing) | **Set the final iOS bundle id in Xcode first.** App Store products, RevenueCat and Firebase are tied to it, and changing it later means redoing those steps. |
| Apple Developer account | Needed | With the **Paid Apps Agreement** active (App Store Connect → Business). |
| Google Play Console account | Needed | Payments profile set up. |
| RevenueCat account | Free tier is enough to start | https://app.revenuecat.com |
| Firebase / Google account | Needed | One Firebase project for the app and the website. |

Product ids used everywhere below (keep them exactly like this):

| Plan | App Store product id | Google Play product id | Type |
|---|---|---|---|
| Monthly | `knockup_pro_monthly` | `knockup_pro_monthly` (base plan `monthly`) | Auto-renewable subscription |
| Yearly + 7-day trial | `knockup_pro_yearly` | `knockup_pro_yearly` (base plan `yearly`, offer `free-trial-7d`) | Auto-renewable subscription |
| Lifetime | `knockup_pro_lifetime` | `knockup_pro_lifetime` | Non-consumable (Apple) / one-time product (Google) |

Entitlement: **`pro`**, already in code as `AppConstants.proEntitlementId`.

---

## 1. Subscriptions (full flow)

### How it will work
```
Paywall → RevenueCat SDK → App Store / Google Play payment sheet
       ← RevenueCat says "entitlement pro is active"
UsageService.isPro = true → no daily limit, PRO button hidden, "Unlimited" on Home
```
The app never handles card details: Apple and Google take the payment, and RevenueCat tells the app who is Pro.

### 1.1 App Store Connect [Console]
1. **Agreements, Tax, and Banking**: the *Paid Apps* agreement must say **Active**.
2. **Apps → KnockUp → Subscriptions**:
   1. Create a subscription group, e.g. **KnockUp Pro**.
   2. Add `knockup_pro_monthly` (1 month) and `knockup_pro_yearly` (1 year) to that group.
   3. For each: price, display name, description, and a review screenshot (a screenshot of the paywall is fine).
   4. On `knockup_pro_yearly`, add an **Introductory Offer**: *Free*, *1 week*, new subscribers.
3. **Apps → KnockUp → In-App Purchases**: add `knockup_pro_lifetime` as **Non-Consumable**, with a price and a review screenshot.
4. **Users and Access → Integrations → In-App Purchase**: generate an **In-App Purchase Key** (`.p8`). Note the Key ID and Issuer ID. RevenueCat needs them.
5. In Xcode (owner): Runner → *Signing & Capabilities* → **+ In-App Purchase**.
6. **Sandbox testers**: Users and Access → Sandbox → add a tester email. On the iPhone: Settings → App Store → Sandbox Account → sign in.

> Sandbox renewals are fast: a monthly subscription renews about every 5 minutes, a yearly one about every hour. This is normal.

### 1.2 Google Play Console [Console]
1. Upload a build to **Internal testing** first. Play only lets you create products after an app bundle with billing has been uploaded. The RevenueCat plugin adds the billing permission automatically.
2. **Monetize → Products → Subscriptions**:
   - `knockup_pro_monthly` → base plan `monthly`, auto-renewing, 1 month.
   - `knockup_pro_yearly` → base plan `yearly`, auto-renewing, 1 year. Add the offer `free-trial-7d`: free trial, 7 days, new customers only.
3. **Monetize → Products → In-app products**: `knockup_pro_lifetime`.
4. **Setup → License testing**: add the Google accounts of the testers, so they aren't charged.
5. **Service account for RevenueCat**: follow RevenueCat's "Google Play service credentials" guide.
   - Create the account in Google Cloud.
   - Invite it in Play Console → Users and permissions, with *View financial data* and *Manage orders and subscriptions*.
   - Download the JSON key.
   - It can take **up to 36 hours** before Google accepts these credentials.

### 1.3 RevenueCat dashboard [Console]
1. Create a project, **KnockUp**.
2. **Apps**:
   - Add an **App Store** app: the final iOS bundle id, plus the In-App Purchase Key (`.p8`, Key ID, Issuer ID).
   - Add a **Play Store** app: `com.finalview.knockup`, plus the service-account JSON.
3. **Products**: import all three products from each store. On Play, subscriptions appear as `knockup_pro_monthly:monthly` and `knockup_pro_yearly:yearly`.
4. **Entitlements**: create **`pro`** and attach **all** products, from both stores.
5. **Offerings**: create **`default`**, set it as *Current*, and add three packages:

   | Package | iOS product | Android product |
   |---|---|---|
   | Monthly (`$rc_monthly`) | `knockup_pro_monthly` | `knockup_pro_monthly:monthly` |
   | Annual (`$rc_annual`) | `knockup_pro_yearly` | `knockup_pro_yearly:yearly` |
   | Lifetime (`$rc_lifetime`) | `knockup_pro_lifetime` | `knockup_pro_lifetime` |
6. **API keys**: copy the **public** SDK keys, `appl_…` for iOS and `goog_…` for Android. Send them to the developer. They are safe to ship in the app. Never use the *secret* keys in the app.

### 1.4 App code [Code]
What gets added (about one day of work once 1.1–1.3 are done):

1. Add the package: `flutter pub add purchases_flutter`.
2. `lib/core/services/subscription_service.dart` (a GetxService):
   - `Purchases.configure(PurchasesConfiguration(<appl_ or goog_ key>))` at app start, in `main.dart`, before `runApp`.
   - Reads `Purchases.getCustomerInfo()` and listens with `Purchases.addCustomerInfoUpdateListener`.
   - `isPro = customerInfo.entitlements.active.containsKey('pro')`, written to `UsageService.isPro` (already built: it removes the limit, resumes counting mid-session, and hides the PRO button).
   - Keeps the last known `isPro` in storage, so Pro still works offline.
3. **Paywall**:
   - Load `Purchases.getOfferings()` and show the **store prices** (localised, with the right currency) instead of `fallback…Price`.
   - Buy: purchase the selected package. On success, close the paywall and show a "Welcome to Pro" message.
   - Restore: `Purchases.restorePurchases()`.
   - If the user cancels, show nothing. On other errors, a short message.
4. Settings → KnockUp Pro shows "Pro active" and a **Manage subscription** link to the store's subscription page.
5. Flip the switches in §5.

### 1.5 Testing checklist
- [ ] Prices on the paywall match the store, in the phone's currency.
- [ ] Yearly shows the 7-day trial, and buying it starts the trial (sandbox).
- [ ] After buying any plan: no daily limit, PRO button gone, Home shows "Unlimited".
- [ ] Buy during a session at the limit: counting resumes.
- [ ] Reinstall the app → **Restore purchases** brings Pro back.
- [ ] Airplane mode after buying: still Pro.
- [ ] RevenueCat dashboard → Customers shows the test purchase.
- [ ] Cancel in the store's subscription settings: Pro ends when the period ends.

### 1.6 Store review rules the paywall must meet (already built in)
- A **Restore purchases** button. ✅
- Price, period and auto-renew terms shown before buying. ✅ (the renewal text under the plans)
- **Terms of Use (EULA)** and **Privacy Policy** links on the paywall. They need real URLs: see §4.
- The same two links in App Store Connect (Privacy Policy URL; Terms in the app description, or use Apple's standard EULA).

---

## 2. Firebase: Crashlytics, Analytics, events

### 2.1 Create and connect [Console + Code]
1. https://console.firebase.google.com → **Add project** → *KnockUp*. Analytics: on.
2. Install the tools, once per computer:
   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   ```
3. In the project root:
   ```bash
   flutter pub add firebase_core firebase_crashlytics firebase_analytics
   flutterfire configure --project=<your-firebase-project-id>
   ```
   - Pick **android** and **ios**.
   - This registers both apps in Firebase and writes `lib/firebase_options.dart`, `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`.
   - Run it **after** the final iOS bundle id is set. Run it again if an id ever changes.
4. Check `android/settings.gradle.kts` now has the `com.google.gms.google-services` and `com.google.firebase.crashlytics` plugins. FlutterFire adds them; if not, add them as the FlutterFire docs show.
5. iOS without the advertising ID, so no App Tracking prompt is needed. At the top of `ios/Podfile`:
   ```ruby
   $FirebaseAnalyticsWithoutAdIdSupport = true
   ```
   Then `cd ios && pod install`.

### 2.2 Crashlytics [Code]
`main.dart` already filters a known harmless camera error. Crashlytics goes **after** that filter, so the noise isn't reported:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// No crash reports from debug builds.
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

FlutterError.onError = (details) {
  if (isCameraTeardownNoise(details)) return;   // existing filter
  FlutterError.presentError(details);
  FirebaseCrashlytics.instance.recordFlutterFatalError(details);
};
PlatformDispatcher.instance.onError = (error, stack) {
  if (isCameraTeardownNoise(error, stack)) return true; // existing filter
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

**Release builds are obfuscated**, so upload the symbols after every release build, or crash reports are unreadable:
```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
firebase crashlytics:symbols:upload --app=<FIREBASE_ANDROID_APP_ID> build/symbols
```
- The Firebase app ids are in `lib/firebase_options.dart` (`appId`).
- iOS dSYMs are uploaded by the build phase FlutterFire adds.

Test it: add a temporary button that calls `FirebaseCrashlytics.instance.crash()` in a **release** build. Reopen the app, and the crash appears in Firebase within a few minutes.

### 2.3 Analytics and events [Code]
One wrapper, `lib/core/services/analytics_service.dart`, so event names live in one place. Screen views are logged automatically by adding `FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)` to `navigatorObservers` in `GetMaterialApp`.

Recommended events (names: lowercase letters and `_`, at most 40 characters; values: text or numbers):

| Event | When | Parameters |
|---|---|---|
| `onboarding_complete` | Last onboarding step | — |
| `session_start` | Session screen opens | `mode` (free / drill), `difficulty` |
| `session_finish` | Results opens | `mode`, `punches`, `duration_s`, `best_streak` |
| `limit_reached` | Counting stops at the daily limit | `limit` |
| `paywall_view` | Paywall opens | `source` (home_pro_button / limit / settings / today_card) |
| `purchase_start` | Buy tapped | `plan` (monthly / yearly / lifetime) |
| `purchase_success` | Store confirms | `plan` |
| `purchase_cancel` | User closes the store sheet | `plan` |
| `restore_success` | Restore found Pro | — |
| `share_result` | Share card sent | `mode` |

Test it live:
- Android: `adb shell setprop debug.firebase.analytics.app com.finalview.knockup`.
- iOS: Xcode scheme → Run → Arguments → `-FIRDebugEnabled`.
- Then open Firebase → Analytics → **DebugView**.

### 2.4 Privacy labels [Console]
Analytics and Crashlytics collect usage and crash data. Declare them:
- **App Store Connect → App Privacy**:
  - *Usage Data → Product Interaction* (Analytics);
  - *Diagnostics → Crash Data, Performance Data* (Crashlytics);
  - *Identifiers → User ID* (RevenueCat's anonymous app user id);
  - **Purchases** (RevenueCat).
  - None of it is used for tracking.
- **Play Console → Data safety**: the same categories. Data is encrypted in transit; users can ask for deletion (see the privacy policy).

---

## 3. Connectivity [Code]
KnockUp detects punches fully **offline**; only purchases need the internet. Use `connectivity_plus`:

```bash
flutter pub add connectivity_plus
```
```dart
final results = await Connectivity().checkConnectivity();   // List<ConnectivityResult>
final offline = results.contains(ConnectivityResult.none);
Connectivity().onConnectivityChanged.listen((results) { /* update an RxBool */ });
```

Where to use it:
- **Paywall**: when offline, show "You're offline. Connect to see plans and buy." and disable Buy and Restore.
- Nowhere else: sessions, history and the daily limit all work offline.

Note: "connected to Wi-Fi" doesn't guarantee internet. RevenueCat calls still need their own error message.

---

## 4. Privacy Policy & Terms on Firebase Hosting

### 4.1 Create the site [Console]
Use the same Firebase project as §2. From the project root:
```bash
mkdir website && cd website
firebase init hosting
#   Use an existing project → KnockUp
#   Public directory → public
#   Single-page app → No
#   GitHub deploys → No (optional)
```
Edit `website/firebase.json` so pages work without `.html`:
```json
{
  "hosting": {
    "public": "public",
    "cleanUrls": true,
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
  }
}
```
Pages:
```
website/public/index.html     → https://<project-id>.web.app/
website/public/privacy.html   → https://<project-id>.web.app/privacy
website/public/terms.html     → https://<project-id>.web.app/terms
```
Publish:
```bash
cd website && firebase deploy --only hosting
```
Optional: Firebase Hosting → **Add custom domain** (e.g. `knockup.app`), then use those URLs instead.

### 4.2 What the Privacy Policy must say for KnockUp
Have the final text reviewed by someone qualified. It should cover:
- **Camera and microphone**:
  - used only to detect punches **on the device**;
  - video and audio are **not recorded, stored or uploaded**;
  - the reference photo stays in memory for the session.
- **Data stored on the device**: session history, daily punch count, settings, and technical session logs (used for the developer export). Deleted by uninstalling, or with *Clear history* in the app.
- **Purchases**: handled by Apple / Google. **RevenueCat** receives purchase receipts and an anonymous user id to unlock Pro.
- **Firebase Analytics**: app usage events and device information. **Firebase Crashlytics**: crash reports.
- No advertising, no selling of data, no tracking across other companies' apps.
- Children: the app isn't directed to children under 13 (or set the age your stores require).
- Contact email for questions and deletion requests.
- Date of the last update, and how changes are announced.

**Terms of Use:** for iOS you can link Apple's **Standard EULA** (https://www.apple.com/legal/internet-services/itunes/dev/stdeula/). Write your own if you need extra terms, e.g. "train safely, not medical advice". The same Terms page can serve Android.

### 4.3 Connect the links in the app [Code]
1. `flutter pub add url_launcher`.
2. In `lib/core/utils/constants.dart`:
   ```dart
   static const String termsUrl = 'https://<project-id>.web.app/terms';
   static const String privacyUrl = 'https://<project-id>.web.app/privacy';
   ```
3. `PaywallController.openLegal` opens them with `launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)`. Also add the two links to Settings.
4. Put the same URLs in **App Store Connect** (Privacy Policy URL) and **Play Console** (Store listing → Privacy policy).

---

## 5. Release checklist: switches in `lib/core/utils/constants.dart`

| Constant | While testing | For release |
|---|---|---|
| `freeDailyPunchLimit` | any | `300` (or your choice) |
| `enforceDailyLimit` | `true` | `true` |
| `alwaysShowUpgrade` | `true` | `false`: PRO button only after the free punches are used up |
| `showTestUsageReset` | `true` | **`false`**: hides "Reset to 0 (test)" on Home |
| `purchasesConnected` | `false` | `true` once §1 is done and tested |
| `termsUrl`, `privacyUrl` | `''` | the URLs from §4 |
| `fallback…Price` | display only | keep: shown only if the store prices can't load |

Then:
- [ ] Final iOS bundle id set by the owner, then `flutterfire configure` run.
- [ ] Release build with `--obfuscate --split-debug-info=build/symbols`, and symbols uploaded (§2.2).
- [ ] Privacy labels / Data safety filled in (§2.4).
- [ ] Sandbox purchase checklist passed (§1.5).
- [ ] Store listing text matches what the app does (see `ROADMAP.md` §3.1, "Learn boxing" lessons).
