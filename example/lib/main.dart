import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:hyperpay_sdk/hyperpay_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'saved_cards_screen.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
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
  final _cardNumberController = TextEditingController(text: '4200000000000000');
  final _holderController = TextEditingController(text: 'John Doe');
  final _expiryMonthController = TextEditingController(text: '12');
  final _expiryYearController = TextEditingController(text: '2027');
  final _cvvController = TextEditingController(text: '123');
  final _amountController = TextEditingController(text: '10.00');

  String _status = 'Not initialized';
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _saveCard = false;

  static const shopperResultUrl = 'com.example.hyperpaysdk';

  String get _entityId => dotenv.env['HYPERPAY_ENTITY_ID'] ?? '';
  String get _accessToken => dotenv.env['HYPERPAY_ACCESS_TOKEN'] ?? '';

  @override
  void dispose() {
    _cardNumberController.dispose();
    _holderController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvvController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    if (_entityId.isEmpty || _accessToken.isEmpty) {
      setState(() => _status =
          'Missing HYPERPAY_ENTITY_ID or HYPERPAY_ACCESS_TOKEN in .env');
      return;
    }

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

  Future<String?> _getCheckoutId({
    bool tokenize = false,
    List<String> registrationIds = const [],
  }) async {
    setState(() {
      _isLoading = true;
      _status = 'Requesting checkout ID...';
    });

    try {
      final body = {
        'entityId': _entityId,
        'amount': _amountController.text.trim(),
        'currency': 'SAR',
        'paymentType': 'DB',
      };
      if (tokenize) body['createRegistration'] = 'true';
      for (var i = 0; i < registrationIds.length; i++) {
        body['registrations[$i].id'] = registrationIds[i];
      }

      print('[HyperPay] Checkout request body: $body');

      final response = await http.post(
        Uri.parse('https://eu-test.oppwa.com/v1/checkouts'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      print(
          '[HyperPay] Checkout response ${response.statusCode}: ${response.body}');

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['id'] != null) {
        final checkoutId = data['id'] as String;
        setState(() => _status = 'Checkout ID: $checkoutId');
        return checkoutId;
      } else {
        final msg = data['result']?['description'] ?? response.body;
        setState(() => _status = 'Failed to get checkout ID: $msg');
        return null;
      }
    } catch (e) {
      setState(() => _status = 'Network error: $e');
      return null;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _payReadyUI() async {
    final themeColor = Theme.of(context).colorScheme.primary.toARGB32();
    final prefs = await SharedPreferences.getInstance();
    final savedIds = prefs.getStringList('saved_registration_ids') ?? [];
    final checkoutId = await _getCheckoutId(registrationIds: savedIds);
    if (checkoutId == null) return;

    setState(() => _isLoading = true);
    try {
      final result = await HyperpaySdk.checkoutReadyUI(
        checkoutId: checkoutId,
        brands: ['VISA', 'MASTER', 'MADA'],
        shopperResultUrl: shopperResultUrl,
        themeColor: themeColor,
      );
      setState(() => _status = _formatResult(result));
      _showResultSnackBar(result);
    } catch (e) {
      setState(() => _status = 'ReadyUI error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _payCustomUI() async {
    final checkoutId = await _getCheckoutId(tokenize: _saveCard);
    if (checkoutId == null) return;

    setState(() => _isLoading = true);
    try {
      print('[HyperPay] CustomUI params: checkoutId=$checkoutId, '
          'brand=VISA, card=${_cardNumberController.text.trim()}, '
          'holder=${_holderController.text.trim()}, '
          'expiry=${_expiryMonthController.text.trim()}/${_expiryYearController.text.trim()}, '
          'shopperResultUrl=$shopperResultUrl, saveCard=$_saveCard');

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

      print('[HyperPay] CustomUI result: ${result.toMap()}');
      setState(() => _status = _formatResult(result));
      _showResultSnackBar(result);

      if (result.isSuccess && _saveCard) {
        await _extractAndSaveRegistration(checkoutId);
      }
    } catch (e) {
      setState(() => _status = 'CustomUI error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _extractAndSaveRegistration(String checkoutId) async {
    try {
      final uri = Uri.parse(
        'https://eu-test.oppwa.com/v1/checkouts/$checkoutId/payment'
        '?entityId=$_entityId',
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final registrationId = data['registrationId'] as String?;
      if (registrationId == null || registrationId.isEmpty) return;

      final brand = data['paymentBrand'] as String? ?? '';
      final last4 = data['card']?['last4Digits'] as String? ?? '';
      final cardKey = '$brand:$last4';

      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('saved_registration_ids') ?? [];
      final cardKeys = prefs.getStringList('saved_card_keys') ?? [];

      // Replace existing registration for the same card
      final existingIndex = cardKeys.indexOf(cardKey);
      if (existingIndex != -1 && existingIndex < ids.length) {
        ids[existingIndex] = registrationId;
      } else {
        ids.add(registrationId);
        cardKeys.add(cardKey);
      }
      await prefs.setStringList('saved_registration_ids', ids);
      await prefs.setStringList('saved_card_keys', cardKeys);

      if (mounted) {
        setState(() {
          _status = '$_status\nCard saved (ID: $registrationId)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = '$_status\nFailed to save card: $e');
      }
    }
  }

  Future<void> _payApplePay() async {
    final checkoutId = await _getCheckoutId();
    if (checkoutId == null) return;

    setState(() => _isLoading = true);
    try {
      final result = await HyperpaySdk.payApplePay(
        checkoutId: checkoutId,
        merchantId: 'merchant.com.example.app',
        countryCode: 'SA',
        currencyCode: 'SAR',
        amount: double.tryParse(_amountController.text.trim()) ?? 10.0,
        companyName: 'Example Company',
      );
      setState(() => _status = _formatResult(result));
      _showResultSnackBar(result);
    } catch (e) {
      setState(() => _status = 'Apple Pay error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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
      appBar: AppBar(
        title: const Text('HyperPay SDK Example'),
        actions: [
          TextButton.icon(
            onPressed: !_isInitialized
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SavedCardsScreen(),
                      ),
                    ),
            icon: const Icon(Icons.credit_card),
            label: const Text('Saved Cards'),
          ),
        ],
      ),
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
                    Text('Status',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SelectableText(_status),
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
            const SizedBox(height: 16),

            // Amount
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (SAR)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
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
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _holderController,
              decoration: const InputDecoration(
                labelText: 'Card Holder',
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
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _saveCard,
              onChanged: (v) => setState(() => _saveCard = v ?? false),
              title: const Text('Save card for future payments'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
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
