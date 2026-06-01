import 'package:flutter/services.dart';
import 'models.dart';

/// Internal MethodChannel communication layer.
/// Not intended for direct use — use [HyperpaySdk] instead.
class HyperpaySdkMethodChannel {
  static const MethodChannel _channel =
      MethodChannel('com.hyperpay.sdk/channel');

  /// Resolver active for the duration of a single [payApplePayDynamic] call.
  /// The native side invokes `resolveApplePayCheckout` with the detected
  /// card network once Apple Pay authorisation succeeds.
  static Future<String> Function(String network)? _pendingApplePayResolver;
  static bool _nativeHandlerInstalled = false;

  static void _ensureNativeHandler() {
    if (_nativeHandlerInstalled) return;
    _nativeHandlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'resolveApplePayCheckout') {
        return null;
      }
      final resolver = _pendingApplePayResolver;
      if (resolver == null) {
        return <String, dynamic>{'error': 'No pending Apple Pay resolver'};
      }
      final args = call.arguments is Map
          ? Map<String, dynamic>.from(call.arguments as Map)
          : <String, dynamic>{};
      final network = (args['network'] as String?) ?? '';
      try {
        final checkoutId = await resolver(network);
        return <String, dynamic>{'checkoutId': checkoutId};
      } catch (e) {
        return <String, dynamic>{'error': e.toString()};
      }
    });
  }

  static Future<void> setup({required PaymentMode mode}) async {
    await _channel.invokeMethod('setup', {
      'mode': mode == PaymentMode.test ? 'test' : 'live',
    });
  }

  static Future<PaymentResult> checkoutReadyUI({
    required String checkoutId,
    required List<String> brands,
    String? shopperResultUrl,
    GooglePayConfig? googlePayConfig,
    ApplePayConfig? applePayConfig,
    String? lang,
    int? themeColor,
  }) async {
    try {
      final result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('checkoutReadyUI', {
        'checkoutId': checkoutId,
        'brands': brands,
        if (shopperResultUrl != null) 'shopperResultUrl': shopperResultUrl,
        if (googlePayConfig != null) 'googlePayConfig': googlePayConfig.toMap(),
        if (applePayConfig != null) 'applePayConfig': applePayConfig.toMap(),
        if (lang != null) 'lang': lang,
        if (themeColor != null) 'themeColor': themeColor,
      });
      if (result == null) {
        return PaymentResult.canceled();
      }
      return PaymentResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      return PaymentResult.error(
        errorCode: e.code,
        errorMessage: e.message ?? 'Unknown error',
      );
    }
  }

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
  }) async {
    try {
      final result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('payCustomUI', {
        'checkoutId': checkoutId,
        'brand': brand,
        'cardNumber': cardNumber,
        'holder': holder,
        'expiryMonth': expiryMonth,
        'expiryYear': expiryYear,
        'cvv': cvv,
        'tokenize': tokenize,
        if (shopperResultUrl != null) 'shopperResultUrl': shopperResultUrl,
      });
      if (result == null) {
        return PaymentResult.canceled();
      }
      return PaymentResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      return PaymentResult.error(
        errorCode: e.code,
        errorMessage: e.message ?? 'Unknown error',
      );
    }
  }

  static Future<PaymentResult> payApplePay({
    required String checkoutId,
    required String merchantId,
    required String countryCode,
    required String currencyCode,
    required double amount,
    required String companyName,
    required String shopperResultUrl,
  }) async {
    try {
      final result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('payApplePay', {
        'checkoutId': checkoutId,
        'merchantId': merchantId,
        'countryCode': countryCode,
        'currencyCode': currencyCode,
        'amount': amount,
        'companyName': companyName,
        'shopperResultUrl': shopperResultUrl,
      });
      if (result == null) {
        return PaymentResult.canceled();
      }
      return PaymentResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      return PaymentResult.error(
        errorCode: e.code,
        errorMessage: e.message ?? 'Unknown error',
      );
    }
  }

  static Future<PaymentResult> payApplePayDynamic({
    required Future<String> Function(String network) resolveCheckout,
    required String merchantId,
    required String countryCode,
    required String currencyCode,
    required double amount,
    required String companyName,
    required String shopperResultUrl,
  }) async {
    _ensureNativeHandler();
    _pendingApplePayResolver = resolveCheckout;
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('payApplePayDynamic', {
        'merchantId': merchantId,
        'countryCode': countryCode,
        'currencyCode': currencyCode,
        'amount': amount,
        'companyName': companyName,
        'shopperResultUrl': shopperResultUrl,
      });
      if (result == null) {
        return PaymentResult.canceled();
      }
      return PaymentResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      return PaymentResult.error(
        errorCode: e.code,
        errorMessage: e.message ?? 'Unknown error',
      );
    } finally {
      _pendingApplePayResolver = null;
    }
  }

  static Future<HyperpayBinInfo> requestBinInfo({
    required String checkoutId,
    required String bin,
  }) async {
    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('requestBinInfo', {
      'checkoutId': checkoutId,
      'bin': bin,
    });
    if (result == null) {
      return const HyperpayBinInfo(brands: <String>[]);
    }
    return HyperpayBinInfo.fromMap(Map<String, dynamic>.from(result));
  }

  static Future<CheckoutInfo> getPaymentStatus({
    required String checkoutId,
    String? resourcePath,
  }) async {
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getPaymentStatus', {
        'checkoutId': checkoutId,
        if (resourcePath != null) 'resourcePath': resourcePath,
      });
      if (result == null) {
        return const CheckoutInfo();
      }
      return CheckoutInfo.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw Exception('Failed to get payment status: ${e.message}');
    }
  }
}
