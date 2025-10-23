import 'package:flutter/material.dart';
import '../services/border_officials_service_simple.dart' as officials;
import '../models/audit_trail_arguments.dart';
import 'enhanced_official_audit_dialog.dart';

class LocationActionSheet extends StatelessWidget {
  final officials.ScanLocationData location;
  final String? borderId;
  final String? borderName;
  final String timeframe;
  final bool showOutliersOnly;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const LocationActionSheet({
    super.key,
    required this.location,
    this.borderId,
    this.borderName,
    required this.timeframe,
    this.showOutliersOnly = false,
    this.customStartDate,
    this.customEndDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              // Profile image
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: location.isOutlier
                        ? Colors.red.shade300
                        : Colors.green.shade300,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: location.profileImageUrl != null
                      ? Image.network(
                          location.profileImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: 24,
                              color: Colors.grey.shade400,
                            );
                          },
                        )
                      : Icon(
                          Icons.person,
                          size: 24,
                          color: Colors.grey.shade400,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Status indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: location.isOutlier ? Colors.red : Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.effectiveDisplayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '2 locations',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Location Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildDetailRow(
                  Icons.qr_code_scanner,
                  'Total Scans',
                  '${location.scanCount}',
                  Colors.blue,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.location_on,
                  'Coordinates',
                  '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                  Colors.grey.shade700,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  location.isOutlier ? Icons.warning : Icons.near_me,
                  'Distance from Border',
                  '${location.distanceFromBorderKm?.toStringAsFixed(1) ?? "Unknown"} km',
                  location.isOutlier ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.access_time,
                  'Last Activity',
                  _formatRelativeTime(location.lastScanTime),
                  Colors.grey.shade700,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Column(
            children: [
              _buildActionButton(
                context,
                icon: Icons.history,
                title: 'View Audit Trail',
                subtitle: 'See detailed activity history',
                color: Colors.blue,
                onTap: () => _navigateToAuditTrail(context),
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                context,
                icon: Icons.map,
                title: 'Focus on Map',
                subtitle: 'Zoom to this location',
                color: Colors.green,
                onTap: () => _focusOnMap(context),
              ),
              if (location.isOutlier) ...[
                const SizedBox(height: 12),
                _buildActionButton(
                  context,
                  icon: Icons.security,
                  title: 'Security Report',
                  subtitle: 'Generate outlier analysis',
                  color: Colors.red,
                  onTap: () => _generateSecurityReport(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _navigateToAuditTrail(BuildContext context) {
    Navigator.of(context).pop(); // Close bottom sheet

    // Create a mock OfficialPerformance object for the existing dialog
    final mockOfficial = officials.OfficialPerformance(
      officialId: location.officialId,
      officialName: location.officialName,
      displayName: location.displayName,
      profilePictureUrl: location.profileImageUrl,
      isCurrentlyActive: true,
      totalScans: location.scanCount,
      successfulScans: location.scanCount,
      failedScans: 0,
      successRate: 100.0,
      averageScansPerHour: 1.0,
      averageProcessingTimeMinutes: 2.0,
      lastScanTime: location.lastScanTime,
      lastBorderLocation: location.borderName,
      hourlyBreakdown: [],
      scanTrend: [],
    );

    // Show the enhanced audit dialog
    EnhancedOfficialAuditDialog.show(
      context,
      mockOfficial,
      borderName: borderName,
      timeframe: timeframe,
      filteredBorderId: borderId,
      coordinates: LocationBounds(
        centerLat: location.latitude,
        centerLng: location.longitude,
        radiusKm: 1.0,
      ),
      showBorderEntriesOnly: true,
      showOutliersOnly: showOutliersOnly,
      customStartDate: customStartDate,
      customEndDate: customEndDate,
    );
  }

  void _focusOnMap(BuildContext context) {
    Navigator.of(context).pop(); // Close bottom sheet
    // The parent widget should handle map focusing
    // This could be implemented via a callback if needed
  }

  void _generateSecurityReport(BuildContext context) {
    Navigator.of(context).pop(); // Close bottom sheet

    // Show security report dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Security Alert'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Outlier Location Detected',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text('Official: ${location.officialName}'),
            Text(
                'Distance: ${location.distanceFromBorderKm?.toStringAsFixed(1)} km from border'),
            Text('Scans: ${location.scanCount}'),
            Text(
                'Last Activity: ${_formatRelativeTime(location.lastScanTime)}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'This location is flagged as an outlier (>5km from border). Consider investigating the circumstances of these scans.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToAuditTrail(context);
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
