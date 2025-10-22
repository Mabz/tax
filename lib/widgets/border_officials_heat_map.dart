import 'package:flutter/material.dart';
import '../services/border_officials_service_simple.dart';
import '../models/border.dart' as border_model;
import '../utils/date_utils.dart' as date_utils;

class BorderOfficialsHeatMap extends StatefulWidget {
  final List<ScanLocationData> scanLocations;
  final border_model.Border? selectedBorder;

  const BorderOfficialsHeatMap({
    super.key,
    required this.scanLocations,
    this.selectedBorder,
  });

  @override
  State<BorderOfficialsHeatMap> createState() => _BorderOfficialsHeatMapState();
}

class _BorderOfficialsHeatMapState extends State<BorderOfficialsHeatMap> {
  ScanLocationData? _selectedLocation;
  bool _showOutliersOnly = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildControls(),
        Flexible(
          child: Stack(
            children: [
              _buildMapPlaceholder(),
              if (_selectedLocation != null) _buildLocationDetails(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${widget.scanLocations.length} scan locations',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (widget.scanLocations
                    .where((loc) => loc.isOutlier)
                    .isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.warning, color: Colors.red.shade600, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.scanLocations.where((loc) => loc.isOutlier).length} outliers',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                ],
              ],
            ),
          ),
          FilterChip(
            label: const Text('Show Outliers Only'),
            selected: _showOutliersOnly,
            onSelected: (selected) {
              setState(() {
                _showOutliersOnly = selected;
                _selectedLocation = null;
              });
            },
            selectedColor: Colors.red.shade100,
            checkmarkColor: Colors.red.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    // This is a placeholder for the actual map implementation
    // In a real app, you would use Google Maps, OpenStreetMap, or similar
    return Container(
      height: 400, // Give it a fixed height to prevent unbounded constraints
      color: Colors.grey.shade100,
      child: Column(
        children: [
          Expanded(
            child: _buildLocationGrid(),
          ),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLocationGrid() {
    final filteredLocations = _showOutliersOnly
        ? widget.scanLocations.where((loc) => loc.isOutlier).toList()
        : widget.scanLocations;

    if (filteredLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _showOutliersOnly
                  ? 'No outlier locations found'
                  : 'No scan locations available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            if (_showOutliersOnly) ...[
              const SizedBox(height: 8),
              Text(
                'All scans appear to be within expected border areas',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredLocations.length,
      itemBuilder: (context, index) {
        final location = filteredLocations[index];
        return _buildLocationCard(location);
      },
    );
  }

  Widget _buildLocationCard(ScanLocationData location) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: location.isOutlier ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: location.isOutlier
            ? BorderSide(color: Colors.red.shade300, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedLocation = _selectedLocation == location ? null : location;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: location.isOutlier ? Colors.red : Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location.officialName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getScanCountColor(location.scanCount)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${location.scanCount} scans',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getScanCountColor(location.scanCount),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                  ),
                ],
              ),
              if (location.borderName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.flag, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Near: ${location.borderName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ],
              if (location.distanceFromBorderKm != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      location.isOutlier ? Icons.warning : Icons.near_me,
                      size: 16,
                      color: location.isOutlier
                          ? Colors.red.shade600
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${location.distanceFromBorderKm!.toStringAsFixed(1)}km from border',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: location.isOutlier
                                ? Colors.red.shade600
                                : Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ],
              if (location.isOutlier) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security,
                          color: Colors.red.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Potential security concern: Scans detected far from expected border location',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Last scan: ${date_utils.DateUtils.getRelativeTime(location.lastScanTime)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationDetails() {
    if (_selectedLocation == null) return const SizedBox.shrink();

    return Positioned(
      top: 16,
      right: 16,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Location Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedLocation = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                  ),
                ],
              ),
              const Divider(),
              _buildDetailRow('Official', _selectedLocation!.officialName),
              _buildDetailRow('Scans', _selectedLocation!.scanCount.toString()),
              _buildDetailRow(
                'Coordinates',
                '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
              ),
              if (_selectedLocation!.borderName != null)
                _buildDetailRow(
                    'Nearest Border', _selectedLocation!.borderName!),
              if (_selectedLocation!.distanceFromBorderKm != null)
                _buildDetailRow(
                  'Distance from Border',
                  '${_selectedLocation!.distanceFromBorderKm!.toStringAsFixed(2)} km',
                ),
              _buildDetailRow(
                'Last Scan',
                date_utils.DateUtils.formatFriendlyDateOnly(
                    _selectedLocation!.lastScanTime),
              ),
              if (_selectedLocation!.isOutlier) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Security Alert: Outlier Location',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem(Colors.green, 'Normal Location'),
          _buildLegendItem(Colors.red, 'Outlier (>5km from border)'),
          _buildLegendItem(Colors.blue, 'High Activity (>10 scans)'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Color _getScanCountColor(int scanCount) {
    if (scanCount >= 20) return Colors.red.shade600;
    if (scanCount >= 10) return Colors.orange.shade600;
    if (scanCount >= 5) return Colors.blue.shade600;
    return Colors.green.shade600;
  }
}
