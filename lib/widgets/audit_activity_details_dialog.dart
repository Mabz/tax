import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/enhanced_border_service.dart';
import '../services/pass_service.dart';
import '../models/purchased_pass.dart';
import '../utils/date_utils.dart' as date_utils;
import '../widgets/owner_details_button.dart';

class AuditActivityDetailsDialog extends StatefulWidget {
  final PassMovement movement;

  const AuditActivityDetailsDialog({
    super.key,
    required this.movement,
  });

  @override
  State<AuditActivityDetailsDialog> createState() =>
      _AuditActivityDetailsDialogState();

  /// Static method to show the audit activity details dialog
  static void show(BuildContext context, PassMovement movement) {
    showDialog(
      context: context,
      builder: (context) => AuditActivityDetailsDialog(movement: movement),
    );
  }
}

class _AuditActivityDetailsDialogState
    extends State<AuditActivityDetailsDialog> {
  PurchasedPass? _passDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPassDetails();
  }

  Future<void> _loadPassDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get the full pass details using the movement's pass ID
      final passDetails =
          await PassService.getPassById(widget.movement.movementId);

      if (mounted) {
        setState(() {
          _passDetails = passDetails;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading pass details: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorState()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMovementInfo(context),
                              const SizedBox(height: 20),
                              _buildOfficialInfo(context),
                              const SizedBox(height: 20),
                              if (_passDetails != null) ...[
                                _buildPassInfo(context),
                                const SizedBox(height: 20),
                                _buildVehicleInfo(context),
                                const SizedBox(height: 20),
                                _buildOwnerInfo(context),
                                const SizedBox(height: 20),
                              ],
                              _buildLocationInfo(context),
                              const SizedBox(height: 20),
                              _buildAdditionalInfo(context),
                            ],
                          ),
                        ),
            ),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getMovementIcon(widget.movement.movementType),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audit Activity Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  _getMovementDescription(widget.movement.movementType),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Pass Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPassDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementInfo(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getMovementIcon(widget.movement.movementType),
                    color: _getMovementColor(widget.movement.movementType)),
                const SizedBox(width: 8),
                Text(
                  'Movement Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(context, 'Movement ID', widget.movement.movementId,
                copyable: true),
            _buildInfoRow(context, 'Type',
                _getMovementDescription(widget.movement.movementType)),
            _buildInfoRow(
                context, 'Status', widget.movement.newStatus.toUpperCase()),
            _buildInfoRow(context, 'Processed At',
                _formatDateTime(widget.movement.processedAt)),
            if (widget.movement.scanPurpose != null)
              _buildInfoRow(context, 'Purpose', widget.movement.scanPurpose!),
            if (widget.movement.notes != null)
              _buildInfoRow(context, 'Notes', widget.movement.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialInfo(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Border Official',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Official profile image
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue.shade300, width: 2),
                  ),
                  child: ClipOval(
                    child: widget.movement.officialProfileImageUrl != null
                        ? Image.network(
                            widget.movement.officialProfileImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                size: 25,
                                color: Colors.grey.shade400,
                              );
                            },
                          )
                        : Icon(
                            Icons.person,
                            size: 25,
                            color: Colors.grey.shade400,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.movement.officialName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.movement.borderName,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.movement.authorityType != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.movement.authorityType!
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassInfo(BuildContext context) {
    if (_passDetails == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.confirmation_number, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text(
                  'Pass Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(context, 'Pass ID', _passDetails!.passId,
                copyable: true),
            _buildInfoRow(context, 'Short Code', _passDetails!.displayShortCode,
                copyable: true),
            _buildInfoRow(context, 'Pass Type', _passDetails!.passDescription),
            _buildInfoRow(context, 'Status', _passDetails!.statusDisplay),
            _buildInfoRow(context, 'Amount',
                '${_getCurrencySymbol(_passDetails!.currency)}${_passDetails!.amount.toStringAsFixed(2)}'),
            _buildInfoRow(context, 'Entries', _passDetails!.entriesDisplay),
            _buildInfoRow(
                context,
                'Valid From',
                date_utils.DateUtils.formatFriendlyDateOnly(
                    _passDetails!.activationDate)),
            _buildInfoRow(
                context,
                'Valid Until',
                date_utils.DateUtils.formatFriendlyDateOnly(
                    _passDetails!.expiresAt)),
            if (_passDetails!.currentStatus != null)
              _buildInfoRow(context, 'Vehicle Status',
                  _passDetails!.vehicleStatusDisplay),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleInfo(BuildContext context) {
    if (_passDetails == null || !_passDetails!.hasVehicleInfo) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                Text(
                  'Vehicle Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(context, 'Description',
                _passDetails!.displayVehicleDescription),
            if (_passDetails!.vehicleRegistrationNumber != null)
              _buildInfoRow(context, 'Registration',
                  _passDetails!.vehicleRegistrationNumber!),
            if (_passDetails!.vehicleMake != null)
              _buildInfoRow(context, 'Make', _passDetails!.vehicleMake!),
            if (_passDetails!.vehicleModel != null)
              _buildInfoRow(context, 'Model', _passDetails!.vehicleModel!),
            if (_passDetails!.vehicleYear != null)
              _buildInfoRow(
                  context, 'Year', _passDetails!.vehicleYear.toString()),
            if (_passDetails!.vehicleColor != null)
              _buildInfoRow(context, 'Color', _passDetails!.vehicleColor!),
            if (_passDetails!.vehicleVin != null)
              _buildInfoRow(context, 'VIN', _passDetails!.vehicleVin!),
            if (_passDetails!.vehicleTypeLabel != null)
              _buildInfoRow(
                  context, 'Vehicle Type', _passDetails!.vehicleTypeLabel!),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerInfo(BuildContext context) {
    if (_passDetails == null || _passDetails!.profileId == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.purple.shade600),
                const SizedBox(width: 8),
                Text(
                  'Owner Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Owner Details Button - this will show the full owner popup like in local authority
            SizedBox(
              width: double.infinity,
              child: OwnerDetailsButton(
                ownerId: _passDetails!.profileId!,
                buttonText: 'View Complete Owner Details',
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.purple.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Click above to view complete owner details including passport, identity documents, and contact information.',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Text(
                  'Location Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                context, 'Border/Checkpoint', widget.movement.borderName),
            _buildInfoRow(context, 'Coordinates',
                '${widget.movement.latitude.toStringAsFixed(6)}, ${widget.movement.longitude.toStringAsFixed(6)}'),
            const SizedBox(height: 12),
            // Map preview (placeholder)
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 32, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'Location: ${widget.movement.borderName}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${widget.movement.latitude.toStringAsFixed(4)}, ${widget.movement.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfo(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Additional Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                context, 'Previous Status', widget.movement.previousStatus),
            _buildInfoRow(context, 'New Status', widget.movement.newStatus),
            if (widget.movement.entriesDeducted > 0)
              _buildInfoRow(context, 'Entries Deducted',
                  widget.movement.entriesDeducted.toString()),
            _buildInfoRow(context, 'Processed At',
                _formatDateTime(widget.movement.processedAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value,
      {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied $label to clipboard'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.copy,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getMovementIcon(String movementType) {
    switch (movementType.toLowerCase()) {
      case 'check_in':
      case 'entry':
        return Icons.login;
      case 'check_out':
      case 'exit':
        return Icons.logout;
      case 'verification_scan':
      case 'scan':
        return Icons.qr_code_scanner;
      case 'manual_verification':
        return Icons.verified_user;
      default:
        return Icons.timeline;
    }
  }

  Color _getMovementColor(String movementType) {
    switch (movementType.toLowerCase()) {
      case 'check_in':
      case 'entry':
        return Colors.green.shade600;
      case 'check_out':
      case 'exit':
        return Colors.orange.shade600;
      case 'verification_scan':
      case 'scan':
        return Colors.blue.shade600;
      case 'manual_verification':
        return Colors.purple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getMovementDescription(String movementType) {
    switch (movementType.toLowerCase()) {
      case 'check_in':
      case 'entry':
        return 'Vehicle Check-In';
      case 'check_out':
      case 'exit':
        return 'Vehicle Check-Out';
      case 'verification_scan':
      case 'scan':
        return 'Pass Verification Scan';
      case 'manual_verification':
        return 'Manual Document Verification';
      default:
        return 'Border Activity';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return date_utils.DateUtils.formatFriendlyDate(dateTime);
  }

  String _getCurrencySymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'ZAR':
        return 'R';
      default:
        return '$currencyCode ';
    }
  }
}
