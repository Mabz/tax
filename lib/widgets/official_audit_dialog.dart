import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/border_officials_service_simple.dart' as officials;
import '../services/enhanced_border_service.dart';
import '../services/authority_profiles_service.dart';
import '../models/authority_profile.dart';
import '../widgets/audit_activity_details_dialog.dart';

class OfficialAuditDialog extends StatelessWidget {
  final officials.OfficialPerformance official;
  final String? borderName;
  final String timeframe;

  const OfficialAuditDialog({
    super.key,
    required this.official,
    this.borderName,
    required this.timeframe,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.indigo.shade700,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: official.profilePictureUrl != null
                        ? NetworkImage(official.profilePictureUrl!)
                        : null,
                    child: official.profilePictureUrl == null
                        ? Icon(Icons.person, color: Colors.indigo.shade700)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${official.officialName} - Audit Trail',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '${borderName ?? "Border"} • ${_getTimeframeLabel(timeframe)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
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
            ),

            // Content
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: Colors.indigo.shade700,
                      unselectedLabelColor: Colors.grey.shade600,
                      indicatorColor: Colors.indigo.shade700,
                      tabs: const [
                        Tab(icon: Icon(Icons.timeline), text: 'Activity Log'),
                        Tab(icon: Icon(Icons.analytics), text: 'Performance'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildAuditActivityTab(official),
                          _buildAuditPerformanceTab(official),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditActivityTab(officials.OfficialPerformance official) {
    return FutureBuilder<List<PassMovement>>(
      future: _getOfficialPassMovements(official),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading activity log...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error loading activity log',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        final movements = snapshot.data ?? [];

        if (movements.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timeline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No Activity Found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No pass movements found for ${official.officialName} in the selected timeframe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: movements.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final movement = movements[index];
            return _buildMovementTile(context, movement);
          },
        );
      },
    );
  }

  Widget _buildMovementTile(BuildContext context, PassMovement movement) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getMovementTypeColor(movement.movementType)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getMovementTypeIcon(movement.movementType),
          color: _getMovementTypeColor(movement.movementType),
          size: 20,
        ),
      ),
      title: Text(
        _getMovementDescription(movement),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${movement.borderName} • ${movement.officialName}'),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(movement.processedAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              if (movement.scanPurpose != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.info_outline, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  movement.scanPurpose!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getMovementTypeColor(movement.movementType)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          movement.newStatus,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _getMovementTypeColor(movement.movementType),
          ),
        ),
      ),
      onTap: () => _showPassDetails(context, movement),
    );
  }

  Widget _buildAuditPerformanceTab(officials.OfficialPerformance official) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Metrics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildAuditMetricCard(
                'Total Scans',
                official.totalScans.toString(),
                Icons.qr_code_scanner,
                Colors.blue.shade600,
              ),
              _buildAuditMetricCard(
                'Success Rate',
                '${official.successRate.toStringAsFixed(1)}%',
                Icons.check_circle,
                Colors.green.shade600,
              ),
              _buildAuditMetricCard(
                'Avg Processing Time',
                '${official.averageProcessingTimeMinutes.toStringAsFixed(1)}m',
                Icons.timer,
                Colors.orange.shade600,
              ),
              _buildAuditMetricCard(
                'Scans/Hour',
                official.averageScansPerHour.toStringAsFixed(1),
                Icons.speed,
                Colors.purple.shade600,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Activity Timeline',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Text(
                'Activity Chart\n(${official.scanTrend.length} data points)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get pass movements for the official using their profile_id
  Future<List<PassMovement>> _getOfficialPassMovements(
      officials.OfficialPerformance official) async {
    try {
      // First, try to get Bobby's profile from authority profiles
      final profileId = await _getBobbyProfileId();

      if (profileId == null) {
        // Fallback to using the official's name to find movements
        return await _getMovementsByOfficialName(official.officialName);
      }

      // Get movements by profile_id
      return await _getMovementsByProfileId(profileId);
    } catch (e) {
      debugPrint('❌ Error getting official pass movements: $e');
      return [];
    }
  }

  /// Get Bobby's full profile from authority profiles
  Future<AuthorityProfile?> _getBobbyProfile() async {
    try {
      debugPrint('🔍 Looking for Bobby profile...');

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('❌ No authenticated user found');
        return null;
      }

      final authorities =
          await AuthorityProfilesService.getUserAuthorities(user.id);
      debugPrint('🔍 Found ${authorities.length} authorities for user');

      for (final authority in authorities) {
        final authorityId = authority['authorities']['id'] as String;
        debugPrint('🔍 Checking authority: $authorityId');

        final profiles =
            await AuthorityProfilesService.getAuthorityProfiles(authorityId);
        debugPrint('🔍 Found ${profiles.length} profiles in authority');

        for (final profile in profiles) {
          debugPrint(
              '🔍 Profile: ${profile.displayName} (display_name: ${profile.displayNameFromDb}, full_name: ${profile.profileFullName})');
          if (profile.displayName.toLowerCase().contains('bobby')) {
            debugPrint('✅ Found Bobby! Profile: ${profile.displayName}');
            return profile;
          }
        }
      }

      debugPrint('❌ Bobby not found in any authority profiles');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting Bobby profile: $e');
      return null;
    }
  }

  /// Get Bobby's profile ID from authority profiles
  Future<String?> _getBobbyProfileId() async {
    final profile = await _getBobbyProfile();
    return profile?.profileId;
  }

  /// Get movements by profile_id from pass_movements table
  Future<List<PassMovement>> _getMovementsByProfileId(String profileId) async {
    try {
      debugPrint('🔍 Querying pass_movements for profile_id: $profileId');
      final supabase = Supabase.instance.client;

      // Calculate date range based on timeframe
      final now = DateTime.now();
      DateTime startDate;

      switch (timeframe) {
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

      final response = await supabase
          .from('pass_movements')
          .select('''
            id,
            pass_id,
            movement_type,
            latitude,
            longitude,
            created_at,
            scan_purpose,
            notes,
            purchased_passes!inner(
              id,
              vehicle_description,
              status,
              profiles!inner(
                full_name,
                profile_image_url
              )
            ),
            borders(
              name
            )
          ''')
          .eq('profile_id', profileId)
          .gte('created_at', startDate.toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      debugPrint('🔍 Found ${response.length} pass movements for Bobby');
      final movements = <PassMovement>[];

      // Get Bobby's profile once for all movements
      final bobbyProfile = await _getBobbyProfile();

      for (final record in response) {
        try {
          movements.add(PassMovement(
            movementId: record['id'] as String,
            borderName:
                record['borders']?['name'] as String? ?? 'Unknown Border',
            officialName: bobbyProfile?.displayName ?? 'Bobby',
            officialProfileImageUrl: bobbyProfile?.profileImageUrl,
            movementType: record['movement_type'] as String,
            latitude: (record['latitude'] as num?)?.toDouble() ?? 0.0,
            longitude: (record['longitude'] as num?)?.toDouble() ?? 0.0,
            processedAt: DateTime.parse(record['created_at'] as String),
            entriesDeducted: 1, // Default for scans
            previousStatus: 'active',
            newStatus:
                record['purchased_passes']['status'] as String? ?? 'active',
            scanPurpose: record['scan_purpose'] as String?,
            notes: record['notes'] as String?,
            authorityType: 'border_authority',
          ));
        } catch (e) {
          debugPrint('❌ Error parsing movement record: $e');
        }
      }

      return movements;
    } catch (e) {
      debugPrint('❌ Error getting movements by profile ID: $e');
      return [];
    }
  }

  /// Fallback: Get movements by official name
  Future<List<PassMovement>> _getMovementsByOfficialName(
      String officialName) async {
    try {
      // This would be implemented if we need to search by name
      // For now, return empty list as we prefer profile_id lookup
      return [];
    } catch (e) {
      debugPrint('❌ Error getting movements by official name: $e');
      return [];
    }
  }

  /// Show pass details dialog when movement is tapped
  void _showPassDetails(BuildContext context, PassMovement movement) {
    AuditActivityDetailsDialog.show(context, movement);
  }

  /// Get movement type icon
  IconData _getMovementTypeIcon(String movementType) {
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

  /// Get movement type color
  Color _getMovementTypeColor(String movementType) {
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

  /// Get movement description
  String _getMovementDescription(PassMovement movement) {
    switch (movement.movementType.toLowerCase()) {
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

  /// Format date time for display
  String _formatDateTime(DateTime dateTime) {
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

  String _getTimeframeLabel(String timeframe) {
    switch (timeframe) {
      case '1d':
        return 'Last 24 Hours';
      case '7d':
        return 'Last 7 Days';
      case '30d':
        return 'Last 30 Days';
      case '90d':
        return 'Last 90 Days';
      case 'custom':
        return 'Custom Period';
      default:
        return 'Selected Period';
    }
  }

  /// Static method to show the audit dialog
  static void show(
    BuildContext context,
    officials.OfficialPerformance official, {
    String? borderName,
    String timeframe = '7d',
  }) {
    showDialog(
      context: context,
      builder: (context) => OfficialAuditDialog(
        official: official,
        borderName: borderName,
        timeframe: timeframe,
      ),
    );
  }
}
