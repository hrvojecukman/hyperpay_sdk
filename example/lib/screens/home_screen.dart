import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hyperpay_sdk/hyperpay_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../saved_cards_screen.dart';
import '../services/payment_service.dart';
import '../widgets/custom_ui_bottom_sheet.dart';
import '../widgets/payment_tile.dart';
import '../widgets/status_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _amountController = TextEditingController(text: '10.00');
  String _status = 'SDK initialized (test mode)';
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showResultSnackBar(PaymentResult result) {
    if (!mounted) return;
    final isSuccess = result.isSuccess;
    final isCanceled = result.isCanceled;
    final message = isSuccess
        ? 'Payment successful! (${result.transactionType})'
        : isCanceled
            ? 'Payment canceled'
            : 'Payment failed: ${result.errorMessage ?? result.errorCode}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? Colors.green
            : isCanceled
                ? null
                : Colors.red,
      ),
    );
  }

  Future<void> _payReadyUI() async {
    final themeColor = Theme.of(context).colorScheme.primary.toARGB32();

    setState(() {
      _isLoading = true;
      _status = 'Requesting checkout ID...';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList('saved_registration_ids') ?? [];
      final checkoutId = await PaymentService.getCheckoutId(
        amount: _amountController.text.trim(),
        registrationIds: savedIds,
      );
      if (checkoutId == null) return;

      setState(() => _status = 'Checkout ID: $checkoutId');
      final result = await HyperpaySdk.checkoutReadyUI(
        checkoutId: checkoutId,
        brands: ['VISA', 'MASTER', 'MADA'],
        shopperResultUrl: PaymentService.shopperResultUrl,
        themeColor: themeColor,
      );
      setState(() => _status = PaymentService.formatResult(result));
      _showResultSnackBar(result);
    } catch (e) {
      setState(() => _status = 'ReadyUI error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openCustomUI() {
    CustomUIBottomSheet.show(
      context: context,
      amount: _amountController.text.trim(),
      onPaymentComplete: (result, statusText) {
        setState(() => _status = statusText);
        _showResultSnackBar(result);
      },
    );
  }

  Future<void> _payApplePay() async {
    setState(() {
      _isLoading = true;
      _status = 'Requesting checkout ID...';
    });

    try {
      final checkoutId = await PaymentService.getCheckoutId(
        amount: _amountController.text.trim(),
      );
      if (checkoutId == null) return;

      setState(() => _status = 'Checkout ID: $checkoutId');

      final result = await HyperpaySdk.payApplePay(
        checkoutId: checkoutId,
        merchantId: 'merchant.com.example.app',
        countryCode: 'SA',
        currencyCode: 'SAR',
        amount:
            double.tryParse(_amountController.text.trim()) ?? 10.0,
        companyName: 'Example Company',
      );
      setState(() => _status = PaymentService.formatResult(result));
      _showResultSnackBar(result);
    } catch (e) {
      setState(() => _status = 'Apple Pay error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HyperPay SDK Example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount (SAR)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          PaymentTile(
            icon: Icons.storefront,
            title: 'ReadyUI Checkout',
            subtitle: 'Pre-built payment screen',
            onTap: _isLoading ? null : _payReadyUI,
          ),
          PaymentTile(
            icon: Icons.credit_card,
            title: 'Custom Card Payment',
            subtitle: 'Enter card details manually',
            onTap: _isLoading ? null : _openCustomUI,
          ),
          if (Platform.isIOS)
            PaymentTile(
              icon: Icons.apple,
              title: 'Apple Pay',
              subtitle: 'Pay with Apple Pay',
              onTap: _isLoading ? null : _payApplePay,
            ),
          PaymentTile(
            icon: Icons.wallet,
            title: 'Saved Cards',
            subtitle: 'Manage tokenized cards',
            onTap: _isLoading
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SavedCardsScreen()),
                    ),
          ),
          const SizedBox(height: 16),
          StatusCard(
            status: _status,
            isLoading: _isLoading,
            isSuccess: _status.startsWith('SDK initialized'),
          ),
        ],
      ),
    );
  }
}
