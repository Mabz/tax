import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_details.dart';

class PaymentService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Remove a payment method for a user
  static Future<void> removePayment(String profileId) async {
    try {
      debugPrint('🔍 Removing payment method for profile: $profileId');

      // Update the profile to remove payment details
      await _supabase.from('profiles').update({
        'card_holder_name': null,
        'card_last4': null,
        'card_exp_month': null,
        'card_exp_year': null,
        'payment_provider_token': null,
        'payment_provider': null,
      }).eq('id', profileId);

      // Log the payment removal action
      await _logPaymentAction(
        profileId: profileId,
        action: 'payment_method_removed',
        metadata: {
          'timestamp': DateTime.now().toIso8601String(),
          'action_type': 'remove_payment',
        },
      );

      debugPrint('✅ Payment method removed successfully');
    } catch (e) {
      debugPrint('❌ Error removing payment method: $e');
      throw Exception('Failed to remove payment method: $e');
    }
  }

  /// Get payment details for a user
  static Future<PaymentDetails?> getPaymentDetails(String profileId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select(
              'card_holder_name, card_last4, card_exp_month, card_exp_year, payment_provider_token, payment_provider')
          .eq('id', profileId)
          .single();

      return PaymentDetails.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error getting payment details: $e');
      return null;
    }
  }

  /// Update payment method
  static Future<void> updatePaymentMethod({
    required String profileId,
    required String cardHolderName,
    required String cardLast4,
    required int cardExpMonth,
    required int cardExpYear,
    required String paymentProviderToken,
    required String paymentProvider,
  }) async {
    try {
      await _supabase.from('profiles').update({
        'card_holder_name': cardHolderName,
        'card_last4': cardLast4,
        'card_exp_month': cardExpMonth,
        'card_exp_year': cardExpYear,
        'payment_provider_token': paymentProviderToken,
        'payment_provider': paymentProvider,
      }).eq('id', profileId);

      // Log the payment update action
      await _logPaymentAction(
        profileId: profileId,
        action: 'payment_method_updated',
        metadata: {
          'timestamp': DateTime.now().toIso8601String(),
          'action_type': 'update_payment',
          'payment_provider': paymentProvider,
          'card_last4': cardLast4,
        },
      );
    } catch (e) {
      throw Exception('Failed to update payment method: $e');
    }
  }

  /// Get payment transaction history (simulated for now)
  static Future<List<Map<String, dynamic>>> getPaymentHistory(
      String profileId) async {
    try {
      // Get purchased passes as payment history
      final response = await _supabase
          .from('purchased_passes')
          .select(
              'pass_id, amount, currency, issued_at, pass_description, status')
          .eq('profile_id', profileId)
          .order('issued_at', ascending: false);

      return (response as List)
          .map((item) => {
                'id': item['pass_id'],
                'amount': item['amount'],
                'currency': item['currency'],
                'date': item['issued_at'],
                'description': item['pass_description'],
                'status': item['status'],
                'type': 'pass_purchase',
              })
          .toList();
    } catch (e) {
      throw Exception('Failed to get payment history: $e');
    }
  }

  /// Process refund for a pass
  static Future<void> processRefund({
    required String passId,
    required String profileId,
    required double amount,
    required String reason,
  }) async {
    try {
      // Update pass status to refunded
      await _supabase
          .from('purchased_passes')
          .update({
            'status': 'refunded',
            'refund_reason': reason,
            'refunded_at': DateTime.now().toIso8601String(),
          })
          .eq('pass_id', passId)
          .eq('profile_id', profileId);

      // Log the refund action
      await _logPaymentAction(
        profileId: profileId,
        action: 'refund_processed',
        metadata: {
          'pass_id': passId,
          'amount': amount,
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      throw Exception('Failed to process refund: $e');
    }
  }

  /// Log payment-related actions to audit trail
  static Future<void> _logPaymentAction({
    required String profileId,
    required String action,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      await _supabase.from('audit_logs').insert({
        'actor_profile_id': profileId,
        'target_profile_id': profileId,
        'action': action,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('⚠️ Failed to log payment action: $e');
      // Don't throw error for logging failures
    }
  }
}
