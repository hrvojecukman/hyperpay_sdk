/// Configuration for Google Pay payments (Android only).
class GooglePayConfig {
  /// Your gateway merchant ID from HyperPay.
  final String gatewayMerchantId;

  /// Display name shown on the Google Pay sheet.
  final String merchantName;

  /// ISO 3166-1 alpha-2 country code (e.g. `"SA"`, `"AE"`).
  final String countryCode;

  /// Total price to charge.
  final double totalPrice;

  /// ISO 4217 currency code (e.g. `"SAR"`, `"AED"`, `"USD"`).
  final String currencyCode;

  const GooglePayConfig({
    required this.gatewayMerchantId,
    required this.merchantName,
    required this.countryCode,
    required this.totalPrice,
    required this.currencyCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'gatewayMerchantId': gatewayMerchantId,
      'merchantName': merchantName,
      'countryCode': countryCode,
      'totalPrice': totalPrice,
      'currencyCode': currencyCode,
    };
  }
}
