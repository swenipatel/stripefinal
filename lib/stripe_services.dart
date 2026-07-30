import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class StripeService {
  StripeService._();

  static final StripeService instance = StripeService._();

  /// Simulates a backend request to create a Stripe PaymentIntent.
  ///
  /// WARNING: In production, this request must be made from your secure server,
  /// not directly from the mobile app, to protect your Secret Key.
  Future<Map<String, dynamic>?> createPaymentIntent({
    required String amount,
    required String currency,
    required String secretKey,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'amount': amount,
        'currency': currency.toLowerCase(),
        'payment_method_types[]': 'card',
      };

      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        body: body,
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['error']?['message'] ?? 'Unknown error';
        throw Exception('Stripe API error: $errorMessage');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Processes the Stripe payment flow by:
  /// 1. Initializing the Publishable Key
  /// 2. Requesting a PaymentIntent Client Secret
  /// 3. Initializing the Stripe Payment Sheet
  /// 4. Presenting the Stripe Payment Sheet to the user
  Future<void> makePayment({
    required String amountInCents,
    required String currency,
    required String publishableKey,
    required String secretKey,
    required String merchantDisplayName,
  }) async {
    try {
      // 1. Initialize Stripe Publishable Key
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();

      // 2. Create PaymentIntent
      final paymentIntent = await createPaymentIntent(
        amount: amountInCents,
        currency: currency,
        secretKey: secretKey,
      );

      if (paymentIntent == null || paymentIntent['client_secret'] == null) {
        throw Exception('Failed to initialize payment intent.');
      }

      final clientSecret = paymentIntent['client_secret'];

      // 3. Initialize the Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName,
          style: ThemeMode.system,
        ),
      );

      // 4. Present the Payment Sheet
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        throw Exception('Payment was cancelled.');
      } else {
        throw Exception(e.error.localizedMessage ?? 'Stripe payment failed.');
      }
    } catch (e) {
      rethrow;
    }
  }
}