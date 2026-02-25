/// Result of a payment transaction.
class PaymentResult {
  /// Whether the payment was successful.
  final bool isSuccess;

  /// Whether the user canceled the payment.
  final bool isCanceled;

  /// The resource path for server-side payment status verification.
  final String? resourcePath;

  /// Error code from the payment SDK (null on success).
  final String? errorCode;

  /// Human-readable error message (null on success).
  final String? errorMessage;

  /// Transaction type: `"sync"` for synchronous or `"async"` for
  /// asynchronous (redirect-based) payments.
  final String? transactionType;

  const PaymentResult({
    required this.isSuccess,
    required this.isCanceled,
    this.resourcePath,
    this.errorCode,
    this.errorMessage,
    this.transactionType,
  });

  factory PaymentResult.fromMap(Map<String, dynamic> map) {
    return PaymentResult(
      isSuccess: map['isSuccess'] as bool? ?? false,
      isCanceled: map['isCanceled'] as bool? ?? false,
      resourcePath: map['resourcePath'] as String?,
      errorCode: map['errorCode'] as String?,
      errorMessage: map['errorMessage'] as String?,
      transactionType: map['transactionType'] as String?,
    );
  }

  factory PaymentResult.canceled() {
    return const PaymentResult(isSuccess: false, isCanceled: true);
  }

  factory PaymentResult.error({
    required String errorCode,
    required String errorMessage,
  }) {
    return PaymentResult(
      isSuccess: false,
      isCanceled: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isSuccess': isSuccess,
      'isCanceled': isCanceled,
      'resourcePath': resourcePath,
      'errorCode': errorCode,
      'errorMessage': errorMessage,
      'transactionType': transactionType,
    };
  }

  @override
  String toString() {
    return 'PaymentResult(isSuccess: $isSuccess, isCanceled: $isCanceled, '
        'resourcePath: $resourcePath, errorCode: $errorCode, '
        'errorMessage: $errorMessage, transactionType: $transactionType)';
  }
}
