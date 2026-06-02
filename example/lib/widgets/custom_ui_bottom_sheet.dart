import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hyperpay_sdk/hyperpay_sdk.dart';

import '../services/payment_service.dart';

class CustomUIBottomSheet extends StatefulWidget {
  const CustomUIBottomSheet({
    super.key,
    required this.amount,
    required this.onPaymentComplete,
    this.saveOnly = false,
  });

  final String amount;
  final bool saveOnly;
  final void Function(PaymentResult result, String statusText)
      onPaymentComplete;

  @override
  State<CustomUIBottomSheet> createState() => _CustomUIBottomSheetState();

  static Future<void> show({
    required BuildContext context,
    required String amount,
    required void Function(PaymentResult result, String statusText)
        onPaymentComplete,
    bool saveOnly = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomUIBottomSheet(
        amount: amount,
        saveOnly: saveOnly,
        onPaymentComplete: onPaymentComplete,
      ),
    );
  }
}

class _CustomUIBottomSheetState extends State<CustomUIBottomSheet> {
  final _cardNumberController =
      TextEditingController(text: '4200000000000000');
  final _holderController = TextEditingController(text: 'John Doe');
  final _expiryController = TextEditingController(text: '12/27');
  final _cvvController = TextEditingController(text: '123');

  late bool _saveCard = widget.saveOnly;
  bool _isLoading = false;

  // Live BIN-lookup state (demonstrates HyperpaySdk.requestBinInfo).
  HyperpayBinInfo? _binInfo;
  bool _binLookupInFlight = false;
  String? _binLookupError;
  String? _lastQueriedBin;
  String? _binCheckoutId;
  Timer? _binDebounce;

  @override
  void initState() {
    super.initState();
    _cardNumberController.addListener(_onCardNumberChanged);
    // Kick off an initial lookup for the pre-filled test card.
    _scheduleBinLookup();
  }

  @override
  void dispose() {
    _binDebounce?.cancel();
    _cardNumberController.removeListener(_onCardNumberChanged);
    _cardNumberController.dispose();
    _holderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _onCardNumberChanged() => _scheduleBinLookup();

  void _scheduleBinLookup() {
    _binDebounce?.cancel();
    _binDebounce = Timer(const Duration(milliseconds: 350), _runBinLookup);
  }

  Future<void> _runBinLookup() async {
    final digits = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) {
      if (mounted) {
        setState(() {
          _binInfo = null;
          _binLookupError = null;
          _lastQueriedBin = null;
        });
      }
      return;
    }
    final bin = digits.substring(0, 6);
    if (bin == _lastQueriedBin) return;
    _lastQueriedBin = bin;

    setState(() {
      _binLookupInFlight = true;
      _binLookupError = null;
    });

    try {
      // BIN lookup requires an active checkout. HyperPay rejects 0.00 checkouts
      // for BIN info; use a 1.00 PA checkout we'll never submit. Reuse one per
      // bottom-sheet session.
      _binCheckoutId ??= await PaymentService.getCheckoutId(
        amount: '1.00',
        paymentType: 'PA',
        tokenize: false,
      );
      if (_binCheckoutId == null) {
        throw Exception('Could not create checkout for BIN lookup');
      }

      final info = await HyperpaySdk.requestBinInfo(
        checkoutId: _binCheckoutId!,
        bin: bin,
      );

      if (!mounted || _lastQueriedBin != bin) return;
      setState(() {
        _binInfo = info;
        _binLookupInFlight = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _binInfo = null;
        _binLookupError = e.toString();
        _binLookupInFlight = false;
      });
    }
  }

  String _brandForSubmission() {
    final info = _binInfo;
    if (info != null && info.brands.isNotEmpty) {
      // MADA takes priority for co-branded cards so we route to DB.
      if (info.isMada) return 'MADA';
      return info.brands.first.toUpperCase();
    }
    // Fallback when BIN lookup hasn't returned yet.
    final digits = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('5') || digits.startsWith('2')) return 'MASTER';
    return 'VISA';
  }

  ({String month, String year}) _parseExpiry() {
    final parts = _expiryController.text.trim().split('/');
    final month = parts.isNotEmpty ? parts[0].padLeft(2, '0') : '';
    final yearRaw = parts.length > 1 ? parts[1] : '';
    final year = yearRaw.length == 2 ? '20$yearRaw' : yearRaw;
    return (month: month, year: year);
  }

  Future<void> _pay() async {
    setState(() => _isLoading = true);

    try {
      final expiry = _parseExpiry();
      final brand = _brandForSubmission();
      // MADA must go through a DB checkout; PA/DB choice for others follows saveOnly.
      final paymentType = brand == 'MADA' ? 'DB' : (widget.saveOnly ? 'PA' : 'DB');
      final checkoutId = await PaymentService.getCheckoutId(
        amount: widget.saveOnly ? '0.00' : widget.amount,
        paymentType: paymentType,
        tokenize: _saveCard,
      );
      if (checkoutId == null) return;

      print('[HyperPay] CustomUI params: checkoutId=$checkoutId, '
          'brand=$brand, card=${_cardNumberController.text.trim()}, '
          'holder=${_holderController.text.trim()}, '
          'expiry=${expiry.month}/${expiry.year}, '
          'shopperResultUrl=${PaymentService.shopperResultUrl}, saveCard=$_saveCard');

      final result = await HyperpaySdk.payCustomUI(
        checkoutId: checkoutId,
        brand: brand,
        cardNumber: _cardNumberController.text.trim(),
        holder: _holderController.text.trim(),
        expiryMonth: expiry.month,
        expiryYear: expiry.year,
        cvv: _cvvController.text.trim(),
        shopperResultUrl: PaymentService.shopperResultUrl,
      );

      print('[HyperPay] CustomUI result: ${result.toMap()}');
      String statusText;

      if (widget.saveOnly && result.isSuccess) {
        final regId =
            await PaymentService.extractAndSaveRegistration(checkoutId);
        statusText = regId != null
            ? 'Card saved successfully (ID: $regId)'
            : 'Card authorization succeeded but registration not found';
      } else {
        statusText = PaymentService.formatResult(result);
        if (result.isSuccess && _saveCard) {
          final regId =
              await PaymentService.extractAndSaveRegistration(checkoutId);
          if (regId != null) {
            statusText = '$statusText\nCard saved (ID: $regId)';
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onPaymentComplete(result, statusText);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        final errorResult = PaymentResult.error(
          errorCode: 'CLIENT_ERROR',
          errorMessage: e.toString(),
        );
        widget.onPaymentComplete(errorResult, 'CustomUI error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              widget.saveOnly
                  ? 'Add Card'
                  : 'Pay ${widget.amount} SAR',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _cardNumberController,
            decoration: const InputDecoration(
              labelText: 'Card Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.credit_card),
            ),
            keyboardType: TextInputType.number,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 6),
          _BinInfoBadge(
            inFlight: _binLookupInFlight,
            info: _binInfo,
            error: _binLookupError,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _holderController,
            decoration: const InputDecoration(
              labelText: 'Card Holder',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _expiryController,
                  decoration: const InputDecoration(
                    labelText: 'MM/YY',
                    hintText: '12/27',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [_ExpiryInputFormatter()],
                  enabled: !_isLoading,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _cvvController,
                  decoration: const InputDecoration(
                    labelText: 'CVV',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  enabled: !_isLoading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!widget.saveOnly)
            CheckboxListTile(
              value: _saveCard,
              onChanged:
                  _isLoading ? null : (v) => setState(() => _saveCard = v ?? false),
              title: const Text('Save card for future payments'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _isLoading ? null : _pay,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(widget.saveOnly ? 'Save Card' : 'Pay Now'),
          ),
        ],
      ),
    );
  }
}

class _BinInfoBadge extends StatelessWidget {
  const _BinInfoBadge({
    required this.inFlight,
    required this.info,
    required this.error,
  });

  final bool inFlight;
  final HyperpayBinInfo? info;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (inFlight) {
      return Row(
        children: const [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Looking up BIN…', style: TextStyle(fontSize: 12)),
        ],
      );
    }
    if (error != null) {
      return Text(
        'BIN lookup failed: $error',
        style: const TextStyle(fontSize: 12, color: Colors.red),
      );
    }
    if (info == null || info!.brands.isEmpty) {
      return const Text(
        'Type 6+ digits to detect the brand via HyperPay',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    final brands = info!.brands.join(' / ');
    final type = info!.type ?? '—';
    final binType = info!.binType ?? '—';
    final mada = info!.isMada;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          avatar: Icon(mada ? Icons.verified : Icons.credit_card,
              size: 16, color: mada ? Colors.green : null),
          label: Text(brands, style: const TextStyle(fontSize: 12)),
          backgroundColor: mada ? Colors.green.shade50 : null,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        Chip(
          label: Text(type, style: const TextStyle(fontSize: 12)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        Chip(
          label: Text(binType, style: const TextStyle(fontSize: 12)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        if (mada)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '→ will route as DB',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}

class _ExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buf.write('/');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
