import 'package:flutter/material.dart';
import '../models/pass_movement.dart';

class PassMovementHistoryDialog extends StatelessWidget {
  final List<PassMovement> movements;
  final String? vehicleInfo;

  const PassMovementHistoryDialog({
    super.key,
    required this.movements,
    this.vehicleInfo,
  });

  static void show(
    BuildContext context,
    List<PassMovement> movements, {
    String? vehicleInfo,
  }) {
    showDialog(
      context: context,
      builder: (context) => PassMovementHistoryDialog(
        movements: movements,
        vehicleInfo: vehicleInfo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildMovementsList()),
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
          colors: [Colors.green.shade600, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.timeline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pass Movement History',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (vehicleInfo != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    vehicleInfo!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
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

  Widget _buildMovementsList() {
    if (movements.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Movements Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'No movement history available for this vehicle.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: movements.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final movement = movements[index];
        final isFirst = index == 0;

        return _buildMovementItem(movement, isFirst);
      },
    );
  }

  Widget _buildMovementItem(PassMovement movement, bool isCurrent) {
    return Container(
      decoration: BoxDecoration(
        color: isCurrent ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? Colors.blue.shade200 : Colors.grey.shade200,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Movement type icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getMovementTypeColor(movement.movementType)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                _getMovementTypeIcon(movement.movementType),
                color: _getMovementTypeColor(movement.movementType),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Movement details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          movement.movementTypeDisplay,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Current',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Official and border info
                  if (movement.officialName != null) ...[
                    Row(
                      children: [
                        // Show profile image if available, otherwise use person icon
                        if (movement.officialProfileImageUrl != null &&
                            movement.officialProfileImageUrl!.isNotEmpty)
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.grey.shade400, width: 0.5),
                            ),
                            child: ClipOval(
                              child: Image.network(
                                movement.officialProfileImageUrl!,
                                width: 20,
                                height: 20,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.person,
                                      size: 16, color: Colors.grey.shade600);
                                },
                              ),
                            ),
                          )
                        else
                          Icon(Icons.person,
                              size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          movement.officialName!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (movement.borderName != null) ...[
                          const SizedBox(width: 8),
                          Text('•',
                              style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(width: 8),
                          Icon(Icons.location_on,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            movement.borderName!,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Timestamp
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        _formatDetailedTimestamp(movement.timestamp),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                  // Notes if available
                  if (movement.notes != null && movement.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.yellow.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.note,
                              size: 16, color: Colors.yellow.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              movement.notes!,
                              style: TextStyle(
                                color: Colors.yellow.shade800,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMovementTypeColor(String type) {
    switch (type) {
      case 'check_in':
        return Colors.green;
      case 'check_out':
        return Colors.orange;
      case 'local_authority_scan':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getMovementTypeIcon(String type) {
    switch (type) {
      case 'check_in':
        return Icons.login;
      case 'check_out':
        return Icons.logout;
      case 'local_authority_scan':
        return Icons.qr_code_scanner;
      default:
        return Icons.timeline;
    }
  }

  String _formatDetailedTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    final dateStr = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    if (difference.inDays > 0) {
      return '$dateStr at $timeStr (${difference.inDays}d ago)';
    } else if (difference.inHours > 0) {
      return '$dateStr at $timeStr (${difference.inHours}h ago)';
    } else if (difference.inMinutes > 0) {
      return '$dateStr at $timeStr (${difference.inMinutes}m ago)';
    } else {
      return '$dateStr at $timeStr (Just now)';
    }
  }
}
