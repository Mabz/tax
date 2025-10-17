import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/border_selection_service.dart';

/// Widget for selecting a border when an official has multiple assignments
class BorderSelectionWidget extends StatefulWidget {
  final Function(AssignedBorder) onBorderSelected;
  final Position? currentPosition;
  final String? preSelectedBorderId;

  const BorderSelectionWidget({
    super.key,
    required this.onBorderSelected,
    this.currentPosition,
    this.preSelectedBorderId,
  });

  @override
  State<BorderSelectionWidget> createState() => _BorderSelectionWidgetState();
}

class _BorderSelectionWidgetState extends State<BorderSelectionWidget> {
  List<AssignedBorder> _assignedBorders = [];
  AssignedBorder? _selectedBorder;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAssignedBorders();
  }

  Future<void> _loadAssignedBorders() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      List<AssignedBorder> borders;

      // If we have GPS coordinates, get borders sorted by distance
      if (widget.currentPosition != null) {
        borders = await BorderSelectionService.findNearestAssignedBorders(
          currentLat: widget.currentPosition!.latitude,
          currentLon: widget.currentPosition!.longitude,
        );
      } else {
        // Otherwise get all assigned borders
        borders = await BorderSelectionService.getOfficialAssignedBorders();
      }

      if (borders.isEmpty) {
        setState(() {
          _errorMessage =
              'No borders assigned to your account. Please contact your supervisor.';
          _isLoading = false;
        });
        return;
      }

      // Auto-select the pre-selected border or the nearest one
      AssignedBorder? defaultBorder;
      if (widget.preSelectedBorderId != null) {
        defaultBorder = borders.firstWhere(
          (b) => b.borderId == widget.preSelectedBorderId,
          orElse: () => borders.first,
        );
      } else {
        defaultBorder = borders.first; // Nearest if sorted by distance
      }

      setState(() {
        _assignedBorders = borders;
        _selectedBorder = defaultBorder;
        _isLoading = false;
      });

      // Notify parent of default selection
      if (defaultBorder != null) {
        widget.onBorderSelected(defaultBorder);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load assigned borders: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading assigned borders...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Select Border Crossing',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Border selection dropdown
            DropdownButtonFormField<AssignedBorder>(
              value: _selectedBorder,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: _assignedBorders.map((border) {
                return DropdownMenuItem<AssignedBorder>(
                  value: border,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        border.borderName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (border.distanceKm != null)
                        Text(
                          border.distanceDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (AssignedBorder? newBorder) {
                if (newBorder != null) {
                  setState(() {
                    _selectedBorder = newBorder;
                  });
                  widget.onBorderSelected(newBorder);
                }
              },
            ),

            const SizedBox(height: 12),

            // Selected border details
            if (_selectedBorder != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.blue.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Selected Border Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('Name', _selectedBorder!.borderName),
                    _buildDetailRow(
                        'Permissions', _selectedBorder!.permissionsDisplay),
                    if (_selectedBorder!.distanceKm != null)
                      _buildDetailRow(
                          'Distance', _selectedBorder!.distanceDisplay),
                    if (_selectedBorder!.hasCoordinates)
                      _buildDetailRow(
                        'Coordinates',
                        '${_selectedBorder!.latitude!.toStringAsFixed(4)}, ${_selectedBorder!.longitude!.toStringAsFixed(4)}',
                      ),
                  ],
                ),
              ),

              // GPS validation warning if distance is significant
              if (_selectedBorder!.distanceKm != null &&
                  _selectedBorder!.distanceKm! > 30) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Distance Warning',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This border is ${_selectedBorder!.distanceDisplay}. You may be prompted to confirm your location when processing passes.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for GPS validation warnings
class GpsValidationDialog extends StatelessWidget {
  final GpsValidationResult validation;
  final VoidCallback onProceed;
  final VoidCallback onCancel;

  const GpsValidationDialog({
    super.key,
    required this.validation,
    required this.onProceed,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange.shade600),
          const SizedBox(width: 8),
          const Text('Location Verification'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GPS Distance Warning',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(validation.violationMessage),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Details:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Border: ${validation.borderName}'),
                Text('Distance: ${validation.distanceDisplay}'),
                Text(
                    'Max Allowed: ${validation.maxAllowedKm.toStringAsFixed(0)}km'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This action will be logged for audit purposes. Do you want to proceed?',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: onProceed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Proceed Anyway'),
        ),
      ],
    );
  }
}
