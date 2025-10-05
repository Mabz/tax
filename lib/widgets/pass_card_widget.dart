import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/purchased_pass.dart';
import 'pass_history_widget.dart';

class PassCardWidget extends StatelessWidget {
  final PurchasedPass pass;
  final bool showQrCode;
  final bool showDetails;
  final VoidCallback? onQrCodeTap;
  final bool isCompact;
  final bool showSecureCode;

  const PassCardWidget({
    super.key,
    required this.pass,
    this.showQrCode = true,
    this.showDetails = true,
    this.onQrCodeTap,
    this.isCompact = false,
    this.showSecureCode = true,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = pass.isActive;
    final statusDisplay = pass.statusDisplay;

    Color statusColor;
    Color statusBackgroundColor;
    switch (pass.statusColorName) {
      case 'red':
        statusColor = Colors.red.shade600;
        statusBackgroundColor = Colors.red.shade50;
        break;
      case 'yellow':
        statusColor = Colors.orange.shade600;
        statusBackgroundColor = Colors.orange.shade50;
        break;
      case 'green':
        statusColor = Colors.green.shade600;
        statusBackgroundColor = Colors.green.shade50;
        break;
      default:
        statusColor = Colors.grey.shade600;
        statusBackgroundColor = Colors.grey.shade50;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      child: Column(
        children: [
          // QR Code Section
          if (showQrCode) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isCompact ? 16 : 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                // Dynamic border based on status
                border: Border.all(
                  color: statusColor,
                  width: isActive ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Pass Title (only show in validation screens, not in My Passes)
                      if (!showQrCode) ...[
                        Text(
                          pass.passDescription,
                          style: TextStyle(
                            fontSize: isCompact ? 18 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isCompact ? 12 : 16),
                      ],
                      // QR Code
                      Center(
                        child: GestureDetector(
                          onTap: onQrCodeTap,
                          child: Container(
                            padding: EdgeInsets.all(isCompact ? 12 : 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.grey.shade300, width: 2),
                            ),
                            child: QrImageView(
                              data: pass.qrCode ?? _generateQrCodeForPass(pass),
                              version: QrVersions.auto,
                              size: isCompact ? 150 : 200,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isCompact ? 12 : 16),
                      // Short Code with long-press to copy
                      GestureDetector(
                        onLongPress: showQrCode
                            ? () => _copyBackupCodeToClipboard(
                                context, pass.displayShortCode)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Backup Code',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (showQrCode) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.content_copy,
                                      size: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pass.displayShortCode,
                                style: TextStyle(
                                  fontSize: isCompact ? 16 : 18,
                                  fontWeight:
                                      FontWeight.w900, // Extra bold for clarity
                                  color: Colors.grey.shade800,
                                  fontFamily:
                                      'Courier', // More distinctive monospace font
                                  letterSpacing:
                                      3, // Increased spacing for clarity
                                  height: 1.2, // Better line height
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Status overlay for inactive passes
                  if (!isActive)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor, width: 2),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getStatusOverlayText(statusDisplay),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: isCompact ? 16 : 24),
          ],

          // Prominent Secure Code Section (if present and allowed)
          if (showDetails &&
              showSecureCode &&
              pass.secureCode != null &&
              pass.secureCode!.isNotEmpty) ...[
            _buildProminentSecureCodeSection(isCompact),
            SizedBox(height: isCompact ? 16 : 24),
          ],

          // Vehicle Details Section (if vehicle info is available)
          if (showDetails && _hasVehicleDetails(pass)) ...[
            _buildVehicleDetailsSection(isCompact),
            SizedBox(height: isCompact ? 16 : 24),
          ],

          // Pass Details Section
          if (showDetails) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isCompact ? 16 : 20),
              decoration: BoxDecoration(
                color: statusBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pass Details',
                          style: TextStyle(
                            fontSize: isCompact ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          pass.statusDisplay,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 12 : 16),

                  // Vehicle Status Section
                  _buildVehicleStatusSection(isCompact),
                  SizedBox(height: isCompact ? 12 : 16),

                  // Authority Information
                  _buildDetailRow(
                    Icons.account_balance,
                    'Authority',
                    pass.authorityName ?? 'Unknown Authority',
                    isCompact: isCompact,
                  ),
                  // Country Information (if available)
                  if (pass.countryName != null && pass.countryName!.isNotEmpty)
                    _buildDetailRow(
                      Icons.flag,
                      'Country',
                      pass.countryName!,
                      isCompact: isCompact,
                    ),

                  // Vehicle info moved to Vehicle Details section
                  _buildDetailRow(
                    Icons.location_on,
                    'Entry Point',
                    pass.entryPointName ?? 'Any Entry Point',
                    isCompact: isCompact,
                  ),
                  // Exit Point (if available)
                  if (pass.exitPointName != null)
                    _buildDetailRow(
                      Icons.logout,
                      'Exit Point',
                      pass.exitPointName!,
                      isCompact: isCompact,
                    ),
                  _buildDetailRow(
                    Icons.confirmation_number,
                    'Entries',
                    pass.entriesDisplay,
                    valueColor:
                        pass.hasEntriesRemaining ? Colors.black87 : Colors.red,
                    isCompact: isCompact,
                  ),
                  _buildDetailRow(
                    Icons.attach_money,
                    'Amount',
                    pass.amount == 0.0 && pass.currency.isEmpty
                        ? 'Loading...'
                        : '${pass.currency} ${pass.amount.toStringAsFixed(2)}',
                    isCompact: isCompact,
                  ),
                  _buildDetailRow(
                    Icons.calendar_today,
                    'Issued',
                    _formatFriendlyDate(
                        pass.issuedAt), // Always use friendly dates
                    isCompact: isCompact,
                  ),
                  _buildDetailRow(
                    Icons.play_arrow,
                    'Activates',
                    _formatFriendlyDate(
                        pass.activationDate), // Always use friendly dates
                    valueColor: _isPendingActivation(pass)
                        ? Colors.orange
                        : Colors.black87,
                    isCompact: isCompact,
                  ),
                  _buildDetailRow(
                    Icons.event,
                    'Expires',
                    _formatFriendlyDate(
                        pass.expiresAt), // Always use friendly dates
                    valueColor: pass.isExpired ? Colors.red : Colors.black87,
                    isCompact: isCompact,
                  ),

                  // Pass History Button
                  SizedBox(height: isCompact ? 12 : 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showPassHistory(context),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('View Pass History'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isCompact ? 12 : 14,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProminentSecureCodeSection(bool isCompact) {
    debugPrint('🔍 Building secure code section for pass: ${pass.passId}');
    debugPrint('📋 Secure code: ${pass.secureCode}');
    debugPrint('📋 Expires at: ${pass.secureCodeExpiresAt}');
    debugPrint('📋 Has valid: ${pass.hasValidSecureCode}');
    debugPrint('📋 Has expired: ${pass.hasExpiredSecureCode}');

    final isValid = pass.hasValidSecureCode;
    final isExpired = pass.hasExpiredSecureCode;

    Color codeColor;
    Color backgroundColor;
    Color borderColor;
    String statusText;
    String instructionText;
    IconData icon;

    if (isValid) {
      codeColor = Colors.green.shade800;
      backgroundColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
      statusText = 'Valid for ${pass.secureCodeMinutesRemaining} minutes';
      instructionText = 'Show this code to the border official when asked';
      icon = Icons.verified_user;
    } else if (isExpired) {
      codeColor = Colors.red.shade700;
      backgroundColor = Colors.red.shade50;
      borderColor = Colors.red.shade300;
      statusText = 'Code Expired';
      instructionText =
          'Ask the border official to scan your pass again to generate a new code';
      icon = Icons.error_outline;
    } else {
      codeColor = Colors.grey.shade600;
      backgroundColor = Colors.grey.shade50;
      borderColor = Colors.grey.shade300;
      statusText = 'Code not available';
      instructionText =
          'Code will appear here when generated by border official';
      icon = Icons.info_outline;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: codeColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with icon and title
          Row(
            children: [
              Icon(icon, color: codeColor, size: isCompact ? 24 : 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Border Verification Code',
                      style: TextStyle(
                        fontSize: isCompact ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: codeColor,
                      ),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: isCompact ? 12 : 14,
                        color: codeColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: isCompact ? 16 : 20),

          // Code display
          if (isValid) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 20 : 32,
                vertical: isCompact ? 16 : 24,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: codeColor.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    pass.secureCode!,
                    style: TextStyle(
                      fontSize: isCompact ? 48 : 64,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                      fontFamily: 'Courier',
                      color: codeColor,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: isCompact ? 8 : 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: codeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Expires in ${pass.secureCodeMinutesRemaining} min',
                      style: TextStyle(
                        fontSize: isCompact ? 11 : 12,
                        fontWeight: FontWeight.bold,
                        color: codeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isExpired) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 20 : 32,
                vertical: isCompact ? 16 : 24,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: codeColor.withValues(alpha: 0.3), width: 2),
              ),
              child: Text(
                pass.secureCode!,
                style: TextStyle(
                  fontSize: isCompact ? 48 : 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 12,
                  fontFamily: 'Courier',
                  color: Colors.grey.shade400,
                  decoration: TextDecoration.lineThrough,
                  decorationThickness: 3,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 20 : 32,
                vertical: isCompact ? 24 : 32,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: codeColor.withValues(alpha: 0.3), width: 2),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: isCompact ? 32 : 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Waiting for code...',
                    style: TextStyle(
                      fontSize: isCompact ? 16 : 18,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: isCompact ? 12 : 16),

          // Instruction text
          Container(
            padding: EdgeInsets.all(isCompact ? 12 : 16),
            decoration: BoxDecoration(
              color: codeColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: codeColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: isCompact ? 16 : 18,
                  color: codeColor.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    instructionText,
                    style: TextStyle(
                      fontSize: isCompact ? 12 : 14,
                      color: codeColor.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusOverlayText(String statusDisplay) {
    switch (statusDisplay) {
      case 'Consumed':
        return 'CONSUMED';
      case 'Expired':
        return 'EXPIRED';
      case 'Pending Activation':
        return 'PENDING';
      default:
        return statusDisplay.toUpperCase();
    }
  }

  String _getVehicleDisplayText(PurchasedPass pass) {
    if (pass.vehicleRegistrationNumber != null &&
        pass.vehicleRegistrationNumber!.isNotEmpty) {
      return pass.vehicleDescription;
    } else {
      return pass.vehicleDescription.isNotEmpty
          ? pass.vehicleDescription
          : 'General Pass';
    }
  }

  bool _isPendingActivation(PurchasedPass pass) {
    return pass.activationDate.isAfter(DateTime.now());
  }

  String _generateQrCodeForPass(PurchasedPass pass) {
    // Generate QR code data for existing passes that don't have one
    final qrData = {
      'passId': pass.passId,
      'passDescription': pass.passDescription,
      'vehicleDescription': pass.vehicleDescription,
      'entryPointName': pass.entryPointName ?? 'Any Entry Point',
      'exitPointName': pass.exitPointName ?? 'Any Exit Point',
      'issuedAt':
          DateTime(pass.issuedAt.year, pass.issuedAt.month, pass.issuedAt.day)
              .toIso8601String(),
      'expiresAt': DateTime(
              pass.expiresAt.year, pass.expiresAt.month, pass.expiresAt.day)
          .toIso8601String(),
      'amount': pass.amount,
      'currency': pass.currency,
      'status': pass.status,
      'entries': '${pass.entriesRemaining}/${pass.entryLimit}',
    };
    return qrData.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  String _formatFriendlyDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    final difference = dateOnly.difference(today).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference == -1) {
      return 'Yesterday';
    } else if (difference > 1 && difference <= 7) {
      return 'In $difference days';
    } else if (difference < -1 && difference >= -7) {
      return '${-difference} days ago';
    } else {
      // For dates more than a week away, show the actual date
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    bool isCompact = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 8 : 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: isCompact ? 18 : 20,
            color: Colors.blue.shade600,
          ),
          SizedBox(width: isCompact ? 8 : 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isCompact ? 12 : 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isCompact ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _copyBackupCodeToClipboard(
      BuildContext context, String backupCode) async {
    try {
      await Clipboard.setData(ClipboardData(text: backupCode));

      // Show a snackbar to confirm the copy action
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text('Backup code "$backupCode" copied'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      // Handle clipboard error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text('Failed to copy backup code'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _showPassHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PassHistoryWidget(
          passId: pass.passId,
          shortCode: pass.shortCode,
        ),
      ),
    );
  }

  Widget _buildVehicleStatusSection(bool isCompact) {
    // Get status colors
    Color statusColor;
    IconData statusIcon;

    switch (pass.vehicleStatusColorName) {
      case 'green':
        statusColor = Colors.green.shade600;
        statusIcon = Icons.location_on;
        break;
      case 'blue':
        statusColor = Colors.blue.shade600;
        statusIcon = Icons.flight_takeoff;
        break;
      case 'grey':
      default:
        statusColor = Colors.grey.shade600;
        statusIcon =
            pass.currentStatus == null ? Icons.help_outline : Icons.schedule;
        break;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                statusIcon,
                color: statusColor,
                size: isCompact ? 20 : 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vehicle Status',
                  style: TextStyle(
                    fontSize: isCompact ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  pass.vehicleStatusDisplay,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pass.vehicleStatusDescription,
            style: TextStyle(
              fontSize: isCompact ? 12 : 14,
              color: statusColor.withValues(alpha: 0.8),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasVehicleDetails(PurchasedPass pass) {
    return (pass.vehicleRegistrationNumber != null &&
            pass.vehicleRegistrationNumber!.isNotEmpty) ||
        (pass.vehicleVin != null && pass.vehicleVin!.isNotEmpty) ||
        (pass.vehicleMake != null && pass.vehicleMake!.isNotEmpty) ||
        (pass.vehicleModel != null && pass.vehicleModel!.isNotEmpty) ||
        (pass.vehicleColor != null && pass.vehicleColor!.isNotEmpty) ||
        pass.vehicleDescription.isNotEmpty;
  }

  Widget _buildVehicleDetailsSection(bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_car,
                color: Colors.blue.shade600,
                size: isCompact ? 20 : 24,
              ),
              SizedBox(width: isCompact ? 8 : 12),
              Text(
                'Vehicle Details',
                style: TextStyle(
                  fontSize: isCompact ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 12 : 16),

          // Vehicle Make, Model, Year
          if ((pass.vehicleMake != null && pass.vehicleMake!.isNotEmpty) ||
              (pass.vehicleModel != null && pass.vehicleModel!.isNotEmpty) ||
              pass.vehicleDescription.isNotEmpty) ...[
            _buildVehicleDetailRow(
              'Vehicle',
              _getVehicleDisplayName(pass),
              Icons.directions_car,
              isCompact: isCompact,
            ),
            SizedBox(height: isCompact ? 8 : 12),
          ],

          // Registration Number
          if (pass.vehicleRegistrationNumber != null &&
              pass.vehicleRegistrationNumber!.isNotEmpty) ...[
            _buildVehicleDetailRow(
              'Registration Number',
              pass.vehicleRegistrationNumber!,
              Icons.confirmation_num,
              isCompact: isCompact,
            ),
            SizedBox(height: isCompact ? 8 : 12),
          ],

          // VIN
          if (pass.vehicleVin != null && pass.vehicleVin!.isNotEmpty) ...[
            _buildVehicleDetailRow(
              'VIN',
              pass.vehicleVin!,
              Icons.fingerprint,
              isCompact: isCompact,
            ),
            SizedBox(height: isCompact ? 8 : 12),
          ],

          // Color
          if (pass.vehicleColor != null && pass.vehicleColor!.isNotEmpty) ...[
            _buildVehicleDetailRow(
              'Color',
              pass.vehicleColor!,
              Icons.palette,
              isCompact: isCompact,
            ),
            SizedBox(height: isCompact ? 8 : 12),
          ],

          // Year (if not already shown in vehicle name)
          if (pass.vehicleYear != null &&
              (pass.vehicleMake == null || pass.vehicleMake!.isEmpty) &&
              (pass.vehicleModel == null || pass.vehicleModel!.isEmpty)) ...[
            _buildVehicleDetailRow(
              'Year',
              pass.vehicleYear.toString(),
              Icons.calendar_today,
              isCompact: isCompact,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleDetailRow(
    String label,
    String value,
    IconData icon, {
    bool isCompact = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: isCompact ? 16 : 18,
          color: Colors.blue.shade600,
        ),
        SizedBox(width: isCompact ? 8 : 12),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade700,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontSize: isCompact ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _getVehicleDisplayName(PurchasedPass pass) {
    // Prioritize make/model/year combination
    if (pass.vehicleMake != null &&
        pass.vehicleMake!.isNotEmpty &&
        pass.vehicleModel != null &&
        pass.vehicleModel!.isNotEmpty) {
      String result = '${pass.vehicleMake} ${pass.vehicleModel}';
      if (pass.vehicleYear != null) {
        result += ' (${pass.vehicleYear})';
      }
      return result;
    }

    // Fall back to vehicle description
    if (pass.vehicleDescription.isNotEmpty) {
      return pass.vehicleDescription;
    }

    // Last resort
    return 'Vehicle';
  }
}
