import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import '../models/payment_details.dart';

class PaymentManagementWidget extends StatefulWidget {
  final String profileId;

  const PaymentManagementWidget({
    super.key,
    required this.profileId,
  });

  @override
  State<PaymentManagementWidget> createState() =>
      _PaymentManagementWidgetState();
}

class _PaymentManagementWidgetState extends State<PaymentManagementWidget> {
  PaymentDetails? _paymentDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPaymentDetails();
  }

  Future<void> _loadPaymentDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final details = await PaymentService.getPaymentDetails(widget.profileId);

      setState(() {
        _paymentDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removePayment() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Payment Method'),
          content: const Text(
            'Are you sure you want to remove your payment method? '
            'You will need to add a new payment method to make future purchases.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        setState(() => _isLoading = true);

        await PaymentService.removePayment(widget.profileId);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment method removed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Reload payment details
        await _loadPaymentDetails();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove payment method: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Method',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _buildErrorWidget()
            else if (_paymentDetails?.hasPaymentMethod == true)
              _buildPaymentDetailsWidget()
            else
              _buildNoPaymentWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Column(
      children: [
        Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 8),
        Text(
          'Failed to load payment details',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _error!,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loadPaymentDetails,
          child: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildPaymentDetailsWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.credit_card, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _paymentDetails!.displayCardInfo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_paymentDetails!.displayExpiry.isNotEmpty)
                    Text(
                      'Expires: ${_paymentDetails!.displayExpiry}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (_paymentDetails!.cardHolderName != null)
                    Text(
                      _paymentDetails!.cardHolderName!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement update payment method
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Update payment method feature coming soon')),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Update'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _removePayment,
              icon: const Icon(Icons.delete),
              label: const Text('Remove'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoPaymentWidget() {
    return Column(
      children: [
        Icon(Icons.credit_card_off, color: Colors.grey, size: 48),
        const SizedBox(height: 8),
        Text(
          'No payment method saved',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Add a payment method to make purchases',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Implement add payment method
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Add payment method feature coming soon')),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Payment Method'),
        ),
      ],
    );
  }
}
