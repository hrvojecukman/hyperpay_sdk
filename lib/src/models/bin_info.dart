/// BIN (Bank Identification Number) lookup result returned by HyperPay's
/// authoritative BIN service.
///
/// Use [HyperpaySdk.requestBinInfo] to route MADA cards through the correct
/// entity (DB) and avoid PA-rail declines on Saudi-issued co-branded cards.
class HyperpayBinInfo {
  /// Payment brands matched for the BIN, e.g. `["MADA"]`, `["VISA"]`, or
  /// `["MADA", "VISA"]` for co-branded cards. Order is the SDK's order of
  /// preference.
  final List<String> brands;

  /// `PERSONAL` or `COMMERCIAL`.
  final String? binType;

  /// Funding type — `DEBIT`, `CREDIT`, or `CHARGE CARD`.
  final String? type;

  const HyperpayBinInfo({
    required this.brands,
    this.binType,
    this.type,
  });

  /// `true` if MADA is one of the matched brands. When this is true the card
  /// should be processed via the DB (direct debit) flow; PA is rejected by
  /// MADA issuers.
  bool get isMada => brands.contains('MADA');

  factory HyperpayBinInfo.fromMap(Map<String, dynamic> map) {
    final raw = map['brands'];
    final brands = raw is List
        ? raw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return HyperpayBinInfo(
      brands: brands,
      binType: map['binType'] as String?,
      type: map['type'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'brands': brands,
      'binType': binType,
      'type': type,
    };
  }

  @override
  String toString() =>
      'HyperpayBinInfo(brands: $brands, binType: $binType, type: $type)';
}
