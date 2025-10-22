// Example of how to integrate the audit dialog into your border analytics screen

import 'package:flutter/material.dart';
import '../services/border_officials_service_simple.dart' as officials;
import '../widgets/official_audit_dialog.dart';

class AuditIntegrationExample extends StatelessWidget {
  const AuditIntegrationExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Integration Example'),
      ),
      body: const Center(
        child: Text('This shows how to integrate the audit functionality'),
      ),
    );
  }

  // This is how you would modify your existing ExpansionTile in border_analytics_screen.dart
  Widget buildOfficialExpansionTileWithAudit(
    BuildContext context,
    officials.OfficialPerformance official,
    String? borderName,
    String timeframe,
  ) {
    return ExpansionTile(
      leading: CircleAvatar(
        backgroundImage: official.profilePictureUrl != null
            ? NetworkImage(official.profilePictureUrl!)
            : null,
        child: official.profilePictureUrl == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              official.officialName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // Performance indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.trending_up, size: 14, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  '95%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // AUDIT BUTTON - This is the key addition
          IconButton(
            onPressed: () => _showOfficialAudit(
              context,
              official,
              borderName,
              timeframe,
            ),
            icon: Icon(
              Icons.assignment,
              size: 20,
              color: Colors.indigo.shade600,
            ),
            tooltip: 'View Audit Trail',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${official.totalScans} scans • ${official.averageScansPerHour.toStringAsFixed(1)}/hr',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (official.position != null) ...[
                Icon(Icons.work, size: 14, color: Colors.blue.shade600),
                const SizedBox(width: 4),
                Text(
                  official.position!,
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                ),
                const SizedBox(width: 12),
              ],
              if (official.lastScanTime != null) ...[
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(official.lastScanTime!),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ],
      ),
      children: [
        // Your existing expansion content here
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Performance metrics, charts, etc.
              const Text('Performance details would go here...'),
              const SizedBox(height: 16),
              // Another audit button in the expanded content
              ElevatedButton.icon(
                onPressed: () => _showOfficialAudit(
                  context,
                  official,
                  borderName,
                  timeframe,
                ),
                icon: const Icon(Icons.assignment),
                label: const Text('View Full Audit Trail'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // This is the method that shows the audit dialog
  void _showOfficialAudit(
    BuildContext context,
    officials.OfficialPerformance official,
    String? borderName,
    String timeframe,
  ) {
    OfficialAuditDialog.show(
      context,
      official,
      borderName: borderName,
      timeframe: timeframe,
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

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
