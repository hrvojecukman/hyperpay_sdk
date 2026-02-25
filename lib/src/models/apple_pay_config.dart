/// Configuration for Apple Pay payments (iOS only).
class ApplePayConfig {
  /// Apple Pay merchant identifier configured in your Apple Developer account.
  final String merchantId;

  /// ISO 3166-1 alpha-2 country code (e.g. `"SA"`, `"AE"`).
  final String countryCode;

  /// ISO 4217 currency code (e.g. `"SAR"`, `"AED"`, `"USD"`).
  final String currencyCode;

  /// Payment amount.
  final double amount;

  /// Company name displayed on the Apple Pay sheet.
  final String companyName;

  const ApplePayConfig({
    required this.merchantId,
    required this.countryCode,
    required this.currencyCode,
    required this.amount,
    required this.companyName,
  });

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'countryCode': countryCode,
      'currencyCode': currencyCode,
      'amount': amount,
      'companyName': companyName,
    };
  }
}
