import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:hyperpay_sdk/hyperpay_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'saved_registration_ids';
const _shopperResultUrl = 'com.example.hyperpaysdk';

class SavedCardsScreen extends StatefulWidget {
  const SavedCardsScreen({super.key});

  @override
  State<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends State<SavedCardsScreen> {
  List<_SavedCard> _cards = [];
  bool _isLoading = true;
  String? _error;

  String get _entityId => dotenv.env['HYPERPAY_ENTITY_ID'] ?? '';
  String get _accessToken => dotenv.env['HYPERPAY_ACCESS_TOKEN'] ?? '';

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_prefsKey) ?? [];

      final cards = <_SavedCard>[];
      for (final id in ids) {
        final card = await _fetchRegistration(id);
        if (card != null) cards.add(card);
      }

      if (!mounted) return;
      setState(() {
        _cards = cards;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load cards: $e';
        _isLoading = false;
      });
    }
  }

  Future<_SavedCard?> _fetchRegistration(String registrationId) async {
    final uri = Uri.parse(
      'https://eu-test.oppwa.com/v1/registrations/$registrationId'
      '?entityId=$_entityId',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    final card = data['card'];
    if (card == null) return null;

    return _SavedCard(
      registrationId: registrationId,
      brand: (data['paymentBrand'] as String?) ?? 'CARD',
      last4: (card['last4Digits'] as String?) ?? '****',
      expiryMonth: (card['expiryMonth'] as String?) ?? '--',
      expiryYear: (card['expiryYear'] as String?) ?? '----',
      holder: (card['holder'] as String?) ?? '',
    );
  }

  Future<void> _payWithCard(_SavedCard card) async {
    setState(() => _isLoading = true);

    try {
      // Create a checkout with the stored registration
      final checkoutResponse = await http.post(
        Uri.parse('https://eu-test.oppwa.com/v1/checkouts'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'entityId': _entityId,
          'amount': '10.00',
          'currency': 'SAR',
          'paymentType': 'DB',
          'registrations[0].id': card.registrationId,
        },
      );

      final checkoutData = jsonDecode(checkoutResponse.body);
      if (checkoutResponse.statusCode != 200 ||
          checkoutData['id'] == null) {
        final msg =
            checkoutData['result']?['description'] ?? checkoutResponse.body;
        _showSnackBar('Checkout failed: $msg');
        return;
      }

      final checkoutId = checkoutData['id'] as String;

      final themeColor = Theme.of(context).colorScheme.primary.toARGB32();
      final result = await HyperpaySdk.checkoutReadyUI(
        checkoutId: checkoutId,
        brands: ['VISA', 'MASTER', 'MADA'],
        shopperResultUrl: _shopperResultUrl,
        themeColor: themeColor,
      );

      if (result.isSuccess) {
        _showSnackBar('Payment successful!');
      } else if (result.isCanceled) {
        _showSnackBar('Payment canceled');
      } else {
        _showSnackBar('Payment failed: ${result.errorMessage ?? result.errorCode}');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCard(_SavedCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text('Remove ${card.brand} ending in ${card.last4}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Delete from HyperPay
      final uri = Uri.parse(
        'https://eu-test.oppwa.com/v1/registrations/${card.registrationId}'
        '?entityId=$_entityId',
      );
      await http.delete(
        uri,
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      // Remove from local storage
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_prefsKey) ?? [];
      ids.remove(card.registrationId);
      await prefs.setStringList(_prefsKey, ids);

      if (!mounted) return;
      setState(() {
        _cards.removeWhere((c) => c.registrationId == card.registrationId);
        _isLoading = false;
      });
      _showSnackBar('Card deleted');
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar('Delete failed: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  IconData _brandIcon(String brand) {
    switch (brand.toUpperCase()) {
      case 'VISA':
        return Icons.credit_card;
      case 'MASTER':
      case 'MASTERCARD':
        return Icons.credit_card;
      case 'MADA':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Cards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadCards,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadCards, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_cards.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No saved cards.\n\nPay with CustomUI and check "Save card" to tokenize a card.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cards.length,
      itemBuilder: (context, index) {
        final card = _cards[index];
        return Card(
          child: ListTile(
            leading: Icon(_brandIcon(card.brand), size: 32),
            title: Text('${card.brand}  ****${card.last4}'),
            subtitle: Text(
              '${card.expiryMonth}/${card.expiryYear}'
              '${card.holder.isNotEmpty ? '  ${card.holder}' : ''}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonal(
                  onPressed: () => _payWithCard(card),
                  child: const Text('Pay'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteCard(card),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SavedCard {
  final String registrationId;
  final String brand;
  final String last4;
  final String expiryMonth;
  final String expiryYear;
  final String holder;

  const _SavedCard({
    required this.registrationId,
    required this.brand,
    required this.last4,
    required this.expiryMonth,
    required this.expiryYear,
    required this.holder,
  });
}
