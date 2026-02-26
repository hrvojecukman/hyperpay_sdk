import 'package:flutter/material.dart';
import 'package:hyperpay_sdk/hyperpay_sdk.dart';

import '../services/payment_service.dart';

class CustomUIBottomSheet extends StatefulWidget {
  const CustomUIBottomSheet({
    super.key,
    required this.amount,
    required this.onPaymentComplete,
  });

  final String amount;
  final void Function(PaymentResult result, String statusText)
      onPaymentComplete;

  @override
  State<CustomUIBottomSheet> createState() => _CustomUIBottomSheetState();

  static Future<void> show({
    required BuildContext context,
    required String amount,
    required void Function(PaymentResult result, String statusText)
        onPaymentComplete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomUIBottomSheet(
        amount: amount,
        onPaymentComplete: onPaymentComplete,
      ),
    );
  }
}

class _CustomUIBottomSheetState extends State<CustomUIBottomSheet> {
  final _cardNumberController =
      TextEditingController(text: '4200000000000000');
  final _holderController = TextEditingController(text: 'John Doe');
  final _expiryMonthController = TextEditingController(text: '12');
  final _expiryYearController = TextEditingController(text: '2027');
  final _cvvController = TextEditingController(text: '123');

  bool _saveCard = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _holderController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() => _isLoading = true);

    try {
      final checkoutId = await PaymentService.getCheckoutId(
        amount: widget.amount,
        tokenize: _saveCard,
      );
      if (checkoutId == null) return;

      print('[HyperPay] CustomUI params: checkoutId=$checkoutId, '
          'brand=VISA, card=${_cardNumberController.text.trim()}, '
          'holder=${_holderController.text.trim()}, '
          'expiry=${_expiryMonthController.text.trim()}/${_expiryYearController.text.trim()}, '
          'shopperResultUrl=${PaymentService.shopperResultUrl}, saveCard=$_saveCard');

      final result = await HyperpaySdk.payCustomUI(
        checkoutId: checkoutId,
        brand: 'VISA',
        cardNumber: _cardNumberController.text.trim(),
        holder: _holderController.text.trim(),
        expiryMonth: _expiryMonthController.text.trim(),
        expiryYear: _expiryYearController.text.trim(),
        cvv: _cvvController.text.trim(),
        shopperResultUrl: PaymentService.shopperResultUrl,
      );

      print('[HyperPay] CustomUI result: ${result.toMap()}');
      var statusText = PaymentService.formatResult(result);

      if (result.isSuccess && _saveCard) {
        final regId =
            await PaymentService.extractAndSaveRegistration(checkoutId);
        if (regId != null) {
          statusText = '$statusText\nCard saved (ID: $regId)';
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
          Text('Pay ${widget.amount} SAR',
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
                  controller: _expiryMonthController,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !_isLoading,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _expiryYearController,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
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
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  enabled: !_isLoading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                : const Text('Pay Now'),
          ),
        ],
      ),
    );
  }
}
