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

  @override
  void dispose() {
    _cardNumberController.dispose();
    _holderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
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
      final checkoutId = await PaymentService.getCheckoutId(
        amount: widget.saveOnly ? '0.00' : widget.amount,
        paymentType: widget.saveOnly ? 'PA' : 'DB',
        tokenize: _saveCard,
      );
      if (checkoutId == null) return;

      print('[HyperPay] CustomUI params: checkoutId=$checkoutId, '
          'brand=VISA, card=${_cardNumberController.text.trim()}, '
          'holder=${_holderController.text.trim()}, '
          'expiry=${expiry.month}/${expiry.year}, '
          'shopperResultUrl=${PaymentService.shopperResultUrl}, saveCard=$_saveCard');

      final result = await HyperpaySdk.payCustomUI(
        checkoutId: checkoutId,
        brand: 'VISA',
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
