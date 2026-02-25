/// Information about a completed checkout, used for payment status verification.
class CheckoutInfo {
  /// Payment status string (e.g. `"CHARGED"`, `"PENDING"`, `"FAILED"`).
  final String? status;

  /// The payment brand used (e.g. `"VISA"`, `"MASTER"`, `"MADA"`).
  final String? paymentBrand;

  /// Raw response data from the SDK for additional inspection.
  final Map<String, dynamic>? rawResponse;

  const CheckoutInfo({
    this.status,
    this.paymentBrand,
    this.rawResponse,
  });

  factory CheckoutInfo.fromMap(Map<String, dynamic> map) {
    return CheckoutInfo(
      status: map['status'] as String?,
      paymentBrand: map['paymentBrand'] as String?,
      rawResponse: map['rawResponse'] != null
          ? Map<String, dynamic>.from(map['rawResponse'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'paymentBrand': paymentBrand,
      'rawResponse': rawResponse,
    };
  }

  @override
  String toString() {
    return 'CheckoutInfo(status: $status, paymentBrand: $paymentBrand)';
  }
}
