import 'package:flutter/material.dart';
import '../services/enhanced_border_service.dart';
import '../utils/time_utils.dart';

/// Widget to display pass movement history
class PassHistoryWidget extends StatefulWidget {
  final String passId;

  const PassHistoryWidget({
    super.key,
    required this.passId,
  });

  @override
  State<PassHistoryWidget> createState() => _PassHistoryWidgetState();
}

class _PassHistoryWidgetState extends State<PassHistoryWidget> {
  List<PassMovement> _movements = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final movements =
          await EnhancedBorderService.getPassMovementHistory(widget.passId);
      setState(() {
        _movements = movements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pass Movement History'),
            Text(
              'Pass ID: ${widget.passId.substring(0, 8)}...',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error: $_error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadHistory,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _movements.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No movement history found',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _movements.length,
                          itemBuilder: (context, index) {
                            final movement = _movements[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          movement.movementType == 'check_in'
                                              ? Icons.login
                                              : Icons.logout,
                                          color: movement.movementType ==
                                                  'check_in'
                                              ? Colors.green
                                              : Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            movement.actionDescription,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: movement.movementType ==
                                                        'check_in'
                                                    ? Colors.green
                                                        .withValues(alpha: 0.1)
                                                    : Colors.blue
                                                        .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                movement.movementType ==
                                                        'check_in'
                                                    ? 'ENTRY'
                                                    : 'EXIT',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      movement.movementType ==
                                                              'check_in'
                                                          ? Colors.green
                                                          : Colors.blue,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              TimeUtils.formatFriendlyTime(
                                                  movement.processedAt),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildDetailRow(Icons.location_on, 'Border',
                                        movement.borderName),
                                    _buildDetailRow(Icons.person, 'Official',
                                        movement.officialName),
                                    _buildDetailRow(
                                        Icons.access_time,
                                        'Processed',
                                        TimeUtils.formatFullDateTime(
                                            movement.processedAt)),
                                    _buildDetailRow(
                                        Icons.swap_horiz,
                                        'Status Change',
                                        '${movement.previousStatus} → ${movement.newStatus}'),
                                    if (movement.entriesDeducted > 0)
                                      _buildDetailRow(
                                          Icons.remove_circle_outline,
                                          'Entries Deducted',
                                          movement.entriesDeducted.toString()),
                                    _buildDetailRow(Icons.gps_fixed, 'Location',
                                        '${movement.latitude.toStringAsFixed(6)}, ${movement.longitude.toStringAsFixed(6)}'),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadHistory,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
