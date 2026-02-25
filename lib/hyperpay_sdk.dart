library hyperpay_sdk;

export 'src/models.dart';

import 'src/hyperpay_sdk_method_channel.dart';
import 'src/models.dart';

/// Main entry point for the HyperPay SDK Flutter plugin.
///
/// Wraps the official HyperPay (OPPWA) Mobile SDK v7.4.0
/// for both Android and iOS.
///
/// **Usage:**
/// ```dart
/// // 1. Initialize
/// await HyperpaySdk.setup(mode: PaymentMode.test);
///
/// // 2. Pay with ReadyUI
/// final result = await HyperpaySdk.checkoutReadyUI(
///   checkoutId: 'your-checkout-id',
///   brands: ['VISA', 'MASTER', 'MADA'],
///   shopperResultUrl: 'com.your.app.payments',
/// );
///
/// // 3. Check result
/// if (result.isSuccess) {
///   // Verify on server using result.resourcePath
/// }
/// ```
class HyperpaySdk {
  HyperpaySdk._();

  /// Initialize the HyperPay SDK with the given [mode].
  ///
  /// Must be called before any other method.
  static Future<void> setup({required PaymentMode mode}) {
    return HyperpaySdkMethodChannel.setup(mode: mode);
  }

  /// Launch the ReadyUI checkout (pre-built payment screen).
  ///
  /// - [checkoutId]: The checkout ID obtained from your server.
  /// - [brands]: List of payment brands (e.g. `['VISA', 'MASTER', 'MADA']`).
  /// - [shopperResultUrl]: URL scheme for async payment callbacks (e.g. `'com.your.app.payments'`).
  /// - [googlePayConfig]: Google Pay configuration (Android only).
  /// - [applePayConfig]: Apple Pay configuration (iOS only).
  /// - [lang]: Language code for the checkout UI (e.g. `'en'`, `'ar'`).
  ///
  /// Returns a [PaymentResult] with the transaction outcome.
  static Future<PaymentResult> checkoutReadyUI({
    required String checkoutId,
    required List<String> brands,
    String? shopperResultUrl,
    GooglePayConfig? googlePayConfig,
    ApplePayConfig? applePayConfig,
    String? lang,
  }) {
    return HyperpaySdkMethodChannel.checkoutReadyUI(
      checkoutId: checkoutId,
      brands: brands,
      shopperResultUrl: shopperResultUrl,
      googlePayConfig: googlePayConfig,
      applePayConfig: applePayConfig,
      lang: lang,
    );
  }

  /// Submit a card payment using CustomUI (your own payment form).
  ///
  /// - [checkoutId]: The checkout ID obtained from your server.
  /// - [brand]: Payment brand (e.g. `'VISA'`, `'MASTER'`, `'MADA'`).
  /// - [cardNumber]: Card number without spaces.
  /// - [holder]: Cardholder name.
  /// - [expiryMonth]: Two-digit expiry month (e.g. `'01'`).
  /// - [expiryYear]: Four-digit expiry year (e.g. `'2025'`).
  /// - [cvv]: Card verification value.
  /// - [shopperResultUrl]: URL scheme for async payment callbacks.
  /// - [tokenize]: Whether to tokenize the card for future payments.
  ///
  /// Returns a [PaymentResult] with the transaction outcome.
  static Future<PaymentResult> payCustomUI({
    required String checkoutId,
    required String brand,
    required String cardNumber,
    required String holder,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
    String? shopperResultUrl,
    bool tokenize = false,
  }) {
    return HyperpaySdkMethodChannel.payCustomUI(
      checkoutId: checkoutId,
      brand: brand,
      cardNumber: cardNumber,
      holder: holder,
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
      cvv: cvv,
      shopperResultUrl: shopperResultUrl,
      tokenize: tokenize,
    );
  }

  /// Submit a payment via Apple Pay (iOS only).
  ///
  /// - [checkoutId]: The checkout ID obtained from your server.
  /// - [merchantId]: Your Apple Pay merchant identifier.
  /// - [countryCode]: ISO 3166-1 alpha-2 country code.
  /// - [currencyCode]: ISO 4217 currency code.
  /// - [amount]: Payment amount.
  /// - [companyName]: Company name displayed on the Apple Pay sheet.
  ///
  /// Returns a [PaymentResult] with the transaction outcome.
  static Future<PaymentResult> payApplePay({
    required String checkoutId,
    required String merchantId,
    required String countryCode,
    required String currencyCode,
    required double amount,
    required String companyName,
  }) {
    return HyperpaySdkMethodChannel.payApplePay(
      checkoutId: checkoutId,
      merchantId: merchantId,
      countryCode: countryCode,
      currencyCode: currencyCode,
      amount: amount,
      companyName: companyName,
    );
  }

  /// Get the payment status for a completed checkout.
  ///
  /// - [checkoutId]: The checkout ID to check.
  /// - [resourcePath]: Optional resource path from a previous [PaymentResult].
  ///
  /// Returns a [CheckoutInfo] with the payment status.
  ///
  /// **Note:** For production, you should verify payment status on your
  /// backend server using the HyperPay server-to-server API.
  static Future<CheckoutInfo> getPaymentStatus({
    required String checkoutId,
    String? resourcePath,
  }) {
    return HyperpaySdkMethodChannel.getPaymentStatus(
      checkoutId: checkoutId,
      resourcePath: resourcePath,
    );
  }
}
