import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:hyperpay_sdk/hyperpay_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentService {
  PaymentService._();

  static const shopperResultUrl = 'com.example.hyperpaysdk';

  static String get entityId => dotenv.env['HYPERPAY_ENTITY_ID'] ?? '';
  static String get accessToken => dotenv.env['HYPERPAY_ACCESS_TOKEN'] ?? '';

  static Future<String?> getCheckoutId({
    required String amount,
    bool tokenize = false,
    List<String> registrationIds = const [],
  }) async {
    final body = <String, String>{
      'entityId': entityId,
      'amount': amount,
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
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );

    print(
        '[HyperPay] Checkout response ${response.statusCode}: ${response.body}');

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['id'] != null) {
      return data['id'] as String;
    }

    final msg = data['result']?['description'] ?? response.body;
    throw Exception('Failed to get checkout ID: $msg');
  }

  static Future<String?> extractAndSaveRegistration(
      String checkoutId) async {
    final uri = Uri.parse(
      'https://eu-test.oppwa.com/v1/checkouts/$checkoutId/payment'
      '?entityId=$entityId',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    final registrationId = data['registrationId'] as String?;
    if (registrationId == null || registrationId.isEmpty) return null;

    final brand = data['paymentBrand'] as String? ?? '';
    final last4 = data['card']?['last4Digits'] as String? ?? '';
    final cardKey = '$brand:$last4';

    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('saved_registration_ids') ?? [];
    final cardKeys = prefs.getStringList('saved_card_keys') ?? [];

    final existingIndex = cardKeys.indexOf(cardKey);
    if (existingIndex != -1 && existingIndex < ids.length) {
      ids[existingIndex] = registrationId;
    } else {
      ids.add(registrationId);
      cardKeys.add(cardKey);
    }
    await prefs.setStringList('saved_registration_ids', ids);
    await prefs.setStringList('saved_card_keys', cardKeys);

    return registrationId;
  }

  static String formatResult(PaymentResult result) {
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
}
