import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hyperpay_sdk/hyperpay_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HyperPay SDK Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const PaymentScreen(),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _checkoutIdController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _holderController = TextEditingController();
  final _expiryMonthController = TextEditingController();
  final _expiryYearController = TextEditingController();
  final _cvvController = TextEditingController();

  String _status = 'Not initialized';
  bool _isLoading = false;
  bool _isInitialized = false;

  // TODO: Replace with your shopper result URL scheme
  static const shopperResultUrl = 'com.example.hyperpaysdk';

  @override
  void dispose() {
    _checkoutIdController.dispose();
    _cardNumberController.dispose();
    _holderController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    setState(() => _isLoading = true);
    try {
      await HyperpaySdk.setup(mode: PaymentMode.test);
      setState(() {
        _isInitialized = true;
        _status = 'SDK initialized (test mode)';
      });
    } catch (e) {
      setState(() => _status = 'Setup failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _payReadyUI() async {
    final checkoutId = _checkoutIdController.text.trim();
    if (checkoutId.isEmpty) {
      setState(() => _status = 'Please enter a checkout ID');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await HyperpaySdk.checkoutReadyUI(
        checkoutId: checkoutId,
        brands: ['VISA', 'MASTER', 'MADA'],
        shopperResultUrl: shopperResultUrl,
      );
      setState(() => _status = _formatResult(result));
    } catch (e) {
      setState(() => _status = 'ReadyUI error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _payCustomUI() async {
    final checkoutId = _checkoutIdController.text.trim();
    if (checkoutId.isEmpty) {
      setState(() => _status = 'Please enter a checkout ID');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await HyperpaySdk.payCustomUI(
        checkoutId: checkoutId,
        brand: 'VISA',
        cardNumber: _cardNumberController.text.trim(),
        holder: _holderController.text.trim(),
        expiryMonth: _expiryMonthController.text.trim(),
        expiryYear: _expiryYearController.text.trim(),
        cvv: _cvvController.text.trim(),
        shopperResultUrl: shopperResultUrl,
      );
      setState(() => _status = _formatResult(result));
    } catch (e) {
      setState(() => _status = 'CustomUI error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _payApplePay() async {
    final checkoutId = _checkoutIdController.text.trim();
    if (checkoutId.isEmpty) {
      setState(() => _status = 'Please enter a checkout ID');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await HyperpaySdk.payApplePay(
        checkoutId: checkoutId,
        merchantId: 'merchant.com.example.app',
        countryCode: 'SA',
        currencyCode: 'SAR',
        amount: 100.0,
        companyName: 'Example Company',
      );
      setState(() => _status = _formatResult(result));
    } catch (e) {
      setState(() => _status = 'Apple Pay error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatResult(PaymentResult result) {
    final buf = StringBuffer();
    if (result.isSuccess) {
      buf.writeln('Payment successful!');
      buf.writeln('Type: ${result.transactionType}');
      if (result.resourcePath != null) {
        buf.writeln('Resource: ${result.resourcePath}');
      }
    } else if (result.isCanceled) {
      buf.writeln('Payment canceled by user');
    } else {
      buf.writeln('Payment failed');
      if (result.errorCode != null) buf.writeln('Code: ${result.errorCode}');
      if (result.errorMessage != null) {
        buf.writeln('Message: ${result.errorMessage}');
      }
    }
    return buf.toString().trimRight();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HyperPay SDK Example')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(_status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Setup
            FilledButton(
              onPressed: _isLoading ? null : _setup,
              child: const Text('Initialize SDK (Test Mode)'),
            ),
            const SizedBox(height: 24),

            // Checkout ID
            TextField(
              controller: _checkoutIdController,
              decoration: const InputDecoration(
                labelText: 'Checkout ID',
                hintText: 'Enter checkout ID from your server',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // ReadyUI
            Text('ReadyUI', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _isLoading || !_isInitialized ? null : _payReadyUI,
              child: const Text('Pay with ReadyUI'),
            ),
            const SizedBox(height: 24),

            // CustomUI
            Text('CustomUI', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _cardNumberController,
              decoration: const InputDecoration(
                labelText: 'Card Number',
                hintText: '4111111111111111',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _holderController,
              decoration: const InputDecoration(
                labelText: 'Card Holder',
                hintText: 'John Doe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expiryMonthController,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      hintText: '12',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _expiryYearController,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      hintText: '2025',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _cvvController,
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      hintText: '123',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _isLoading || !_isInitialized ? null : _payCustomUI,
              child: const Text('Pay with CustomUI'),
            ),
            const SizedBox(height: 24),

            // Apple Pay (iOS only)
            if (Platform.isIOS) ...[
              Text('Apple Pay', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _isLoading || !_isInitialized ? null : _payApplePay,
                child: const Text('Pay with Apple Pay'),
              ),
            ],

            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
