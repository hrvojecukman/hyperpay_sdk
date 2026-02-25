# HyperPay SDK for Flutter

Flutter plugin wrapping the official **HyperPay (OPPWA) Mobile SDK v7.4.0** for Android and iOS.

## Features

- **ReadyUI** — Pre-built checkout screen with all payment brands
- **CustomUI** — Build your own payment form, submit via the SDK
- **Apple Pay** (iOS) and **Google Pay** (Android)
- **VISA, MasterCard, MADA, STC Pay** support
- **Tokenization** — Save cards for future payments
- **3DS2 authentication** — Handled automatically by the SDK
- **Async payment flows** — Redirect-based payments (e.g. 3DS, bank redirects)
- **Test and Live modes**

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 13.0           |
| Android  | API 24 (Android 7.0) |
| Flutter  | 3.0+           |
| Dart     | 3.0+           |

## Installation

### 1. Add the dependency

```yaml
# pubspec.yaml
dependencies:
  hyperpay_sdk:
    path: ../hyperpay_sdk  # or your local path
```

### 2. Place the SDK binary files

You must obtain the official HyperPay OPPWA SDK v7.4.0 files and place them in the correct directories.

#### Android

Copy the AAR files into `hyperpay_sdk/android/libs/`:

```
android/libs/
├── oppwa.mobile-7.4.0-release.aar
├── ipworks3ds_sdk_9374.aar          # 3DS debug
└── ipworks3ds_sdk_9374_deploy.aar   # 3DS release
```

#### iOS

Copy the XCFrameworks into `hyperpay_sdk/ios/Frameworks/`:

```
ios/Frameworks/
├── OPPWAMobile.xcframework/
└── ipworks3ds_sdk_deploy_9373.xcframework/
```

> For **debug builds** on iOS simulator, replace `ipworks3ds_sdk_deploy_9373.xcframework` with `ipworks3ds_sdk_9373.xcframework` and update the podspec `vendored_frameworks` accordingly.

---

## Platform Setup

### Android Setup

#### 1. Set minimum SDK and Java version

In your app's `android/app/build.gradle`:

```gradle
android {
    compileSdk 35

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = '17'
    }

    defaultConfig {
        minSdk 24
        targetSdk 35
    }
}
```

#### 2. Add AAR dependencies

In your app's `android/app/build.gradle`:

```gradle
dependencies {
    implementation(name: 'oppwa.mobile-7.4.0-release', ext: 'aar')
    debugImplementation(name: 'ipworks3ds_sdk_9374', ext: 'aar')
    releaseImplementation(name: 'ipworks3ds_sdk_9374_deploy', ext: 'aar')
}

repositories {
    flatDir {
        dirs project(':hyperpay_sdk').projectDir.toString() + '/libs'
    }
}
```

#### 3. Configure the shopper result URL scheme

Add an intent filter to your `MainActivity` in `android/app/src/main/AndroidManifest.xml`:

```xml
<activity android:name=".MainActivity"
    android:launchMode="singleTop"
    ...>

    <!-- HyperPay shopper result callback -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.your.app.payments" />
    </intent-filter>

    <!-- Main launcher (keep existing) -->
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>
</activity>
```

> **Important:** The scheme must be **lowercase only** (e.g. `com.your.app.payments`, not `com.your.App.Payments`). This must match the `shopperResultUrl` parameter you pass to the SDK.

#### 4. Google Pay (optional)

Add to your `AndroidManifest.xml` inside `<application>`:

```xml
<meta-data
    android:name="com.google.android.gms.wallet.api.enabled"
    android:value="true" />
```

---

### iOS Setup

#### 1. Set deployment target

In your app's `ios/Podfile`:

```ruby
platform :ios, '13.0'
```

#### 2. Configure static framework for HyperPay

Add this to your `ios/Podfile` inside the `target 'Runner'` block:

```ruby
target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  # HyperPay SDK requires static framework
  $static_framework = ['hyperpay_sdk']

  pre_install do |installer|
    Pod::Installer::Xcode::TargetValidator.send(
      :define_method,
      :verify_no_static_framework_transitive_dependencies
    ) {}
    installer.pod_targets.each do |pod|
      if $static_framework.include?(pod.name)
        def pod.build_type
          Pod::BuildType.static_library
        end
      end
    end
  end
end
```

#### 3. Configure URL scheme for shopper result callback

In Xcode, go to your target's **Info** tab → **URL Types**, and add:

| Field | Value |
|-------|-------|
| Identifier | `com.your.app.payments` |
| URL Schemes | `com.your.app.payments` |
| Role | Editor |

Or add directly to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.your.app.payments</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.your.app.payments</string>
        </array>
    </dict>
</array>
```

#### 4. Apple Pay (optional)

Enable the **Apple Pay** capability in Xcode and configure your merchant ID.

---

## Usage

### Initialize the SDK

```dart
import 'package:hyperpay_sdk/hyperpay_sdk.dart';

// Call once at app start
await HyperpaySdk.setup(mode: PaymentMode.test);
```

### ReadyUI (Pre-built checkout screen)

```dart
final result = await HyperpaySdk.checkoutReadyUI(
  checkoutId: checkoutId,  // from your server
  brands: ['VISA', 'MASTER', 'MADA'],
  shopperResultUrl: 'com.your.app.payments',
  // Optional: Google Pay config (Android)
  googlePayConfig: GooglePayConfig(
    gatewayMerchantId: 'your-merchant-id',
    merchantName: 'Your Company',
    countryCode: 'SA',
    totalPrice: 100.0,
    currencyCode: 'SAR',
  ),
  // Optional: Apple Pay config (iOS)
  applePayConfig: ApplePayConfig(
    merchantId: 'merchant.com.your.app',
    countryCode: 'SA',
    currencyCode: 'SAR',
    amount: 100.0,
    companyName: 'Your Company',
  ),
);

if (result.isSuccess) {
  // Verify payment on your server using result.resourcePath
  print('Resource path: ${result.resourcePath}');
} else if (result.isCanceled) {
  print('Payment canceled');
} else {
  print('Error: ${result.errorCode} - ${result.errorMessage}');
}
```

### CustomUI (Your own payment form)

```dart
final result = await HyperpaySdk.payCustomUI(
  checkoutId: checkoutId,  // from your server
  brand: 'VISA',
  cardNumber: '4111111111111111',
  holder: 'John Doe',
  expiryMonth: '12',
  expiryYear: '2025',
  cvv: '123',
  shopperResultUrl: 'com.your.app.payments',
  tokenize: true,  // save card for future payments
);

if (result.isSuccess) {
  if (result.transactionType == 'async') {
    // Redirect-based payment — wait for callback
    print('Async payment, redirecting...');
  } else {
    // Synchronous payment — verify on server
    print('Resource path: ${result.resourcePath}');
  }
}
```

### Apple Pay (iOS only)

```dart
final result = await HyperpaySdk.payApplePay(
  checkoutId: checkoutId,  // from your server
  merchantId: 'merchant.com.your.app',
  countryCode: 'SA',
  currencyCode: 'SAR',
  amount: 100.0,
  companyName: 'Your Company',
);
```

### Check payment status

```dart
final info = await HyperpaySdk.getPaymentStatus(
  checkoutId: checkoutId,
  resourcePath: result.resourcePath,
);
print('Status: ${info.status}');
```

> **Important:** Always verify the final payment status on your backend server using the HyperPay server-to-server API. Never rely solely on the client-side result.

---

## API Reference

### `HyperpaySdk`

| Method | Description |
|--------|-------------|
| `setup(mode:)` | Initialize the SDK. Call once before any payment. |
| `checkoutReadyUI(...)` | Launch the pre-built checkout UI. Returns `PaymentResult`. |
| `payCustomUI(...)` | Submit a card payment from your own form. Returns `PaymentResult`. |
| `payApplePay(...)` | Submit an Apple Pay payment (iOS only). Returns `PaymentResult`. |
| `getPaymentStatus(...)` | Get checkout info for status verification. Returns `CheckoutInfo`. |

### `PaymentResult`

| Field | Type | Description |
|-------|------|-------------|
| `isSuccess` | `bool` | Whether the payment was successful |
| `isCanceled` | `bool` | Whether the user canceled |
| `resourcePath` | `String?` | Resource path for server-side verification |
| `errorCode` | `String?` | Error code from the SDK |
| `errorMessage` | `String?` | Human-readable error message |
| `transactionType` | `String?` | `"sync"` or `"async"` |

### `CheckoutInfo`

| Field | Type | Description |
|-------|------|-------------|
| `status` | `String?` | Payment status (e.g. `"CHARGED"`) |
| `paymentBrand` | `String?` | Brand used (e.g. `"VISA"`) |
| `rawResponse` | `Map?` | Raw SDK response data |

### `PaymentMode`

| Value | Description |
|-------|-------------|
| `test` | Sandbox environment |
| `live` | Production environment |

---

## Payment Brands

| Brand | ReadyUI | CustomUI | Notes |
|-------|---------|----------|-------|
| `VISA` | Yes | Yes | |
| `MASTER` | Yes | Yes | |
| `MADA` | Yes | Yes | Saudi Arabia debit network |
| `STC_PAY` | Yes | No | |
| `APPLEPAY` | Yes (via config) | Via `payApplePay` | iOS only |
| `GOOGLEPAY` | Yes (via config) | N/A | Android only |

---

## Obtaining a Checkout ID

Before calling any payment method, you must obtain a checkout ID from your backend server by calling the HyperPay Preparation API:

```
POST https://eu-test.oppwa.com/v1/checkouts
```

With parameters like `entityId`, `amount`, `currency`, `paymentType`. See the [HyperPay documentation](https://wordpresshyperpay.docs.oppwa.com/) for details.

---

## Troubleshooting

### Android: `ClassNotFoundException` or missing SDK classes
Make sure all three AAR files are placed in `android/libs/` and the `flatDir` repository is configured in your app's `build.gradle`.

### iOS: Framework not found
1. Ensure XCFrameworks are in `ios/Frameworks/`
2. Run `cd ios && pod install --repo-update`
3. Clean build: `flutter clean && flutter pub get`

### iOS Simulator: 3DS crashes
The **deploy** (release) 3DS framework doesn't include simulator slices. For simulator testing, use the debug 3DS framework (`ipworks3ds_sdk_9373.xcframework`) and update the podspec.

### Async payments not returning
Ensure the URL scheme is correctly configured in both your native project and matches the `shopperResultUrl` parameter exactly (lowercase, no special characters).

### Google Pay not showing
1. Add the wallet meta-data to AndroidManifest.xml
2. Ensure `play-services-wallet` dependency is present
3. Google Pay requires a real device (not emulator) in most cases

---

## License

MIT
