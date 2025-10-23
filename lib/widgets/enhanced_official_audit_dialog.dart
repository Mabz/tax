import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/border_officials_service_simple.dart' as officials;
import '../services/enhanced_border_service.dart';
import '../models/audit_trail_arguments.dart';
import '../widgets/audit_activity_details_dialog.dart';

class EnhancedOfficialAuditDialog extends StatefulWidget {
  final officials.OfficialPerformance official;
  final String? borderName;
  final String timeframe;
  final String? filteredBorderId;
  final LocationBounds? coordinates;
  final bool showBorderEntriesOnly;
  final bool showOutliersOnly;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const EnhancedOfficialAuditDialog({
    super.key,
    required this.official,
    this.borderName,
    required this.timeframe,
    this.filteredBorderId,
    this.coordinates,
    this.showBorderEntriesOnly = true,
    this.showOutliersOnly = false,
    this.customStartDate,
    this.customEndDate,
  });

  @override
  State<EnhancedOfficialAuditDialog> createState() =>
      _EnhancedOfficialAuditDialogState();

  /// Static method to show the enhanced audit dialog
  static void show(
    BuildContext context,
    officials.OfficialPerformance official, {
    String? borderName,
    String timeframe = '7d',
    String? filteredBorderId,
    LocationBounds? coordinates,
    bool showBorderEntriesOnly = true,
    bool showOutliersOnly = false,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) {
    showDialog(
      context: context,
      builder: (context) => EnhancedOfficialAuditDialog(
        official: official,
        borderName: borderName,
        timeframe: timeframe,
        filteredBorderId: filteredBorderId,
        coordinates: coordinates,
        showBorderEntriesOnly: showBorderEntriesOnly,
        showOutliersOnly: showOutliersOnly,
        customStartDate: customStartDate,
        customEndDate: customEndDate,
      ),
    );
  }
}

class _EnhancedOfficialAuditDialogState
    extends State<EnhancedOfficialAuditDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _auditActivities = [];
  bool _showBorderEntriesOnly = true;
  bool _showOutliersOnly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _showBorderEntriesOnly = widget.showBorderEntriesOnly;
    _showOutliersOnly = widget.showOutliersOnly;
    _loadAuditData();
  }

  Future<void> _loadAuditData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final activities = await _fetchFilteredActivities();
      setState(() {
        _auditActivities = activities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFilteredActivities() async {
    final supabase = Supabase.instance.client;

    // Calculate date range
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    if (widget.customStartDate != null && widget.customEndDate != null) {
      startDate = widget.customStartDate!;
      endDate = widget.customEndDate!;
    } else {
      switch (widget.timeframe) {
        case '1d':
          startDate = now.subtract(const Duration(days: 1));
          break;
        case '7d':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case '30d':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case '90d':
          startDate = now.subtract(const Duration(days: 90));
          break;
        default:
          startDate = now.subtract(const Duration(days: 7));
      }
    }

    // Base query
    var query = supabase
        .from('pass_movements')
        .select('*')
        .eq('profile_id', widget.official.officialId)
        .gte('created_at', startDate.toIso8601String())
        .lte('created_at', endDate.toIso8601String());

    // Filter by border if checkbox enabled
    if (_showBorderEntriesOnly && widget.filteredBorderId != null) {
      query = query.eq('border_id', widget.filteredBorderId!);
    }

    // Filter by geographic area if coordinates provided
    if (widget.coordinates != null) {
      final coords = widget.coordinates!;
      final latRadius = coords.radiusKm / 111; // Approximate degrees per km
      final lngRadius = coords.radiusKm / 111;

      query = query
          .gte('latitude', coords.centerLat - latRadius)
          .lte('latitude', coords.centerLat + latRadius)
          .gte('longitude', coords.centerLng - lngRadius)
          .lte('longitude', coords.centerLng + lngRadius);
    }

    final response = await query.order('created_at', ascending: false);
    List<Map<String, dynamic>> activities =
        List<Map<String, dynamic>>.from(response);

    // Filter by outliers if enabled (client-side filtering for distance calculation)
    if (_showOutliersOnly && widget.filteredBorderId != null) {
      // Get border coordinates for distance calculation
      final borderResponse = await supabase
          .from('borders')
          .select('latitude, longitude')
          .eq('id', widget.filteredBorderId!)
          .single();

      // borderResponse is guaranteed to be non-null from .single() call
      final borderLat = borderResponse['latitude'] as double;
      final borderLng = borderResponse['longitude'] as double;

      activities = activities.where((activity) {
        final activityLat = activity['latitude'] as double?;
        final activityLng = activity['longitude'] as double?;

        if (activityLat == null || activityLng == null) return false;

        final distance = _calculateDistance(
          activityLat,
          activityLng,
          borderLat,
          borderLng,
        );

        return distance > 5.0; // Only outliers
      }).toList();
    }

    return activities;
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterControls(),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.indigo.shade700,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            backgroundImage: widget.official.profilePictureUrl != null
                ? NetworkImage(widget.official.profilePictureUrl!)
                : null,
            child: widget.official.profilePictureUrl == null
                ? Icon(Icons.person, color: Colors.indigo.shade700)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.official.effectiveDisplayName} - Audit Trail',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '${widget.borderName ?? "All Borders"} • ${_getTimeframeLabel()}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                if (widget.coordinates != null)
                  Text(
                    'Area: ${widget.coordinates!.centerLat.toStringAsFixed(4)}, ${widget.coordinates!.centerLng.toStringAsFixed(4)} (±${widget.coordinates!.radiusKm}km)',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
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

  Widget _buildFilterControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _showBorderEntriesOnly,
                    onChanged: widget.filteredBorderId != null
                        ? (value) {
                            setState(() {
                              _showBorderEntriesOnly = value ?? true;
                            });
                            _loadAuditData();
                          }
                        : null,
                  ),
                  Text(
                    'Border Entries Only',
                    style: TextStyle(
                      color: widget.filteredBorderId != null
                          ? Colors.black
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _showOutliersOnly,
                    onChanged: (value) {
                      setState(() {
                        _showOutliersOnly = value ?? false;
                      });
                      _loadAuditData();
                    },
                  ),
                  const Text('Outliers Only'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading audit activities...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Failed to load audit data',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAuditData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_auditActivities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Activities Found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptyStateMessage(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _auditActivities.length,
      itemBuilder: (context, index) {
        final activity = _auditActivities[index];
        return _buildActivityTile(activity);
      },
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> activity) {
    final movementType = activity['movement_type'] ?? 'unknown';
    final timestamp = DateTime.parse(activity['created_at']);
    final isOutlier = _isActivityOutlier(activity);
    final entriesDeducted = activity['entries_deducted'] ?? 0;

    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Card(
          elevation: 1,
          child: InkWell(
            onTap: () => _showActivityDetails(activity),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getActivityColor(movementType)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getActivityIcon(movementType),
                      color: _getActivityColor(movementType),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Main content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          _getActivityTitle(activity),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Authority context
                        Text(
                          _getAuthorityContext(activity),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Time and status row
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              _formatRelativeTime(timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (_getActivityStatus(activity) != null) ...[
                              Icon(Icons.info_outline,
                                  size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                _getActivityStatus(activity)!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Vehicle info
                        if (_getVehicleInfo(activity) != null) ...[
                          Row(
                            children: [
                              Icon(Icons.directions_car,
                                  size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                _getVehicleInfo(activity)!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],

                        // Pass info
                        if (activity['pass_id'] != null) ...[
                          Row(
                            children: [
                              Icon(Icons.confirmation_number,
                                  size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                'Pass: ${activity['pass_id'].toString().substring(0, 8)}...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Outlier warning
                        if (isOutlier) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning,
                                    size: 12, color: Colors.red.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  'OUTLIER: ${_getActivityDistance(activity).toStringAsFixed(1)}km from border',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Right side - Entries deducted badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: entriesDeducted > 0
                          ? Colors.red.shade100
                          : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Entries Deducted: $entriesDeducted',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: entriesDeducted > 0
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  bool _isActivityOutlier(Map<String, dynamic> activity) {
    if (widget.filteredBorderId == null) return false;
    return _getActivityDistance(activity) > 5.0;
  }

  double _getActivityDistance(Map<String, dynamic> activity) {
    // This would need border coordinates - simplified for now
    return 0.0; // Placeholder
  }

  Color _getActivityColor(String movementType) {
    switch (movementType) {
      case 'check_in':
        return Colors.green;
      case 'check_out':
        return Colors.orange;
      case 'scan_initiated':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(String movementType) {
    switch (movementType) {
      case 'check_in':
        return Icons.login; // Green arrow pointing right
      case 'check_out':
        return Icons.logout; // Orange arrow pointing left
      case 'scan_initiated':
        return Icons.trending_up; // Zigzag line like in screenshot
      case 'roadblock':
        return Icons.trending_up; // Zigzag line for roadblock too
      case 'verification_scan':
        return Icons.qr_code_scanner;
      case 'border_scan':
        return Icons.qr_code_scanner;
      default:
        return Icons.info;
    }
  }

  String _getActivityTitle(Map<String, dynamic> activity) {
    // First check if there's a scan_purpose field
    final scanPurpose = activity['scan_purpose'];
    if (scanPurpose != null && scanPurpose.toString().isNotEmpty) {
      return _formatScanPurpose(scanPurpose.toString());
    }

    // Fall back to movement type mapping
    final movementType = activity['movement_type'] ?? 'unknown';
    switch (movementType.toLowerCase()) {
      case 'check_in':
      case 'entry':
        return 'Vehicle Check-In';
      case 'check_out':
      case 'exit':
        return 'Vehicle Check-Out';
      case 'scan_initiated':
        return 'Scan Initiated';
      case 'roadblock':
        return 'Roadblock';
      case 'verification_scan':
      case 'scan':
        return 'Pass Verification Scan';
      case 'border_scan':
        return 'Border Scan';
      case 'manual_verification':
        return 'Manual Document Verification';
      case 'local_authority_scan':
        return 'Local Authority Scan';
      default:
        return 'Border Activity';
    }
  }

  String _formatScanPurpose(String scanPurpose) {
    // Convert snake_case to Title Case
    return scanPurpose
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  void _showActivityDetails(Map<String, dynamic> activity) {
    // Convert the activity data to a PassMovement object for the existing dialog
    final movement = PassMovement(
      movementId: activity['id'] ?? '',
      passId: activity['pass_id'],
      borderName: widget.borderName ?? 'Border',
      officialName: widget.official.officialName,
      movementType: activity['movement_type'] ?? 'unknown',
      latitude: activity['latitude']?.toDouble() ?? 0.0,
      longitude: activity['longitude']?.toDouble() ?? 0.0,
      processedAt: DateTime.parse(activity['created_at']),
      entriesDeducted: activity['entries_deducted'] ?? 0,
      previousStatus: activity['previous_status'] ?? '',
      newStatus: activity['new_status'] ?? '',
      scanPurpose: activity['scan_purpose'],
      notes: activity['notes'],
      authorityType: activity['authority_type'],
    );

    // Show the proper audit activity details dialog
    AuditActivityDetailsDialog.show(context, movement);
  }

  String _getTimeframeLabel() {
    switch (widget.timeframe) {
      case '1d':
        return 'Last 24 Hours';
      case '7d':
        return 'Last 7 Days';
      case '30d':
        return 'Last 30 Days';
      case '90d':
        return 'Last 3 Months';
      case 'custom':
        if (widget.customStartDate != null && widget.customEndDate != null) {
          return 'Custom Range';
        }
        return 'Custom Period';
      default:
        return 'Last 7 Days';
    }
  }

  String _getAuthorityContext(Map<String, dynamic> activity) {
    // Check if this is a border activity
    final borderId = activity['border_id'];
    if (borderId != null && widget.borderName != null) {
      return '${widget.borderName} • ${widget.official.officialName}';
    } else {
      return 'Local Authority • ${widget.official.officialName}';
    }
  }

  String? _getActivityStatus(Map<String, dynamic> activity) {
    final metadata = activity['metadata'] as Map<String, dynamic>?;
    final movementType = activity['movement_type'] ?? 'unknown';

    // Check for status in metadata
    if (metadata?['status'] != null) {
      return metadata!['status'].toString();
    }
    if (metadata?['new_status'] != null) {
      return metadata!['new_status'].toString().replaceAll('_', ' ');
    }

    // Default status based on movement type
    switch (movementType) {
      case 'scan_initiated':
        return 'Scan in progress';
      case 'roadblock':
        return 'Checking stuff out';
      case 'check_in':
        return 'Entry processed';
      case 'check_out':
        return 'Exit processed';
      default:
        return null;
    }
  }

  String? _getVehicleInfo(Map<String, dynamic> activity) {
    // For now, return a placeholder - in real implementation,
    // you'd join with vehicle/pass data to get actual vehicle info
    if (activity['pass_id'] != null) {
      return 'LX25TLGT • Cherry Omoda'; // Placeholder - would come from pass/vehicle lookup
    }

    return null;
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

  String _getEmptyStateMessage() {
    if (_showBorderEntriesOnly && _showOutliersOnly) {
      return 'No border entry outliers found for this official in the selected area and time period.';
    } else if (_showBorderEntriesOnly) {
      return 'No border entries found for this official in the selected area and time period.';
    } else if (_showOutliersOnly) {
      return 'No outlier activities found for this official in the selected area and time period.';
    } else {
      return 'No activities found for this official in the selected area and time period.';
    }
  }
}
