import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/border_officials_service_simple.dart';
import '../models/border.dart' as border_model;
import '../utils/date_utils.dart' as date_utils;
import 'scan_locations_data_table.dart';
import 'location_action_sheet.dart';

class EnhancedBorderOfficialsHeatMap extends StatefulWidget {
  final List<ScanLocationData> scanLocations;
  final border_model.Border? selectedBorder;
  final String? timeframe;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const EnhancedBorderOfficialsHeatMap({
    super.key,
    required this.scanLocations,
    this.selectedBorder,
    this.timeframe,
    this.customStartDate,
    this.customEndDate,
  });

  @override
  State<EnhancedBorderOfficialsHeatMap> createState() =>
      _EnhancedBorderOfficialsHeatMapState();
}

class _EnhancedBorderOfficialsHeatMapState
    extends State<EnhancedBorderOfficialsHeatMap> {
  GoogleMapController? _mapController;
  ScanLocationData? _selectedLocation;
  bool _showOutliersOnly = false;
  MapType _currentMapType = MapType.normal;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _createMarkersAndCircles();
  }

  @override
  void didUpdateWidget(EnhancedBorderOfficialsHeatMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scanLocations != widget.scanLocations) {
      _createMarkersAndCircles();
    }
  }

  void _createMarkersAndCircles() {
    final filteredLocations = _showOutliersOnly
        ? widget.scanLocations.where((loc) => loc.isOutlier).toList()
        : widget.scanLocations;

    _markers.clear();
    _circles.clear();

    for (int i = 0; i < filteredLocations.length; i++) {
      final location = filteredLocations[i];
      final markerId = MarkerId('scan_location_$i');

      // Create marker
      final marker = Marker(
        markerId: markerId,
        position: LatLng(location.latitude, location.longitude),
        infoWindow: InfoWindow(
          title: location.officialName.contains('(')
              ? location.officialName.split(' (').first
              : location.officialName,
          snippet:
              '${location.scanCount} scans - ${location.distanceFromBorderKm?.toStringAsFixed(1) ?? "Unknown"}km from border${location.officialName.contains('(') ? '\n${location.officialName.split('(').last}' : ''}',
        ),
        icon: location.isOutlier
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        onTap: () {
          _showLocationActionSheet(location);
        },
      );

      // Create circle to represent scan intensity
      final circle = Circle(
        circleId: CircleId('scan_circle_$i'),
        center: LatLng(location.latitude, location.longitude),
        radius: _getCircleRadius(location.scanCount),
        fillColor: (location.isOutlier ? Colors.red : Colors.blue)
            .withValues(alpha: 0.3),
        strokeColor: location.isOutlier ? Colors.red : Colors.blue,
        strokeWidth: 2,
      );

      _markers.add(marker);
      _circles.add(circle);
    }

    // Add border marker if available
    if (widget.selectedBorder != null &&
        widget.selectedBorder!.latitude != null &&
        widget.selectedBorder!.longitude != null) {
      final borderMarker = Marker(
        markerId: const MarkerId('border_location'),
        position: LatLng(widget.selectedBorder!.latitude!,
            widget.selectedBorder!.longitude!),
        infoWindow: InfoWindow(
          title: widget.selectedBorder!.name,
          snippet: 'Official Border Location',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
      _markers.add(borderMarker);

      // Add 5km radius circle around border
      final borderCircle = Circle(
        circleId: const CircleId('border_radius'),
        center: LatLng(widget.selectedBorder!.latitude!,
            widget.selectedBorder!.longitude!),
        radius: 5000, // 5km in meters
        fillColor: Colors.blue.withValues(alpha: 0.1),
        strokeColor: Colors.blue,
        strokeWidth: 2,
      );
      _circles.add(borderCircle);
    }

    if (mounted) {
      setState(() {});
    }
  }

  double _getCircleRadius(int scanCount) {
    // Scale radius based on scan count (50m to 500m)
    return (scanCount * 25.0).clamp(50.0, 500.0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildControls(),
        const SizedBox(height: 16),
        SizedBox(
          height: 500,
          child: _buildMapView(),
        ),
        if (_selectedLocation != null) ...[
          const SizedBox(height: 16),
          _buildLocationDetails(),
        ],
        const SizedBox(height: 24),
        _buildDataTableSection(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.map, color: Colors.indigo.shade700, size: 24),
        const SizedBox(width: 8),
        Text(
          'Scan Locations Heat Map',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.indigo.shade800,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.scanLocations.length} scan locations',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (widget.scanLocations
                          .where((loc) => loc.isOutlier)
                          .isNotEmpty) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.warning,
                            color: Colors.red.shade600, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.scanLocations.where((loc) => loc.isOutlier).length} outliers (>5km)',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Outliers Only'),
                      selected: _showOutliersOnly,
                      onSelected: (selected) {
                        setState(() {
                          _showOutliersOnly = selected;
                          _selectedLocation = null;
                        });
                        _createMarkersAndCircles();
                      },
                      selectedColor: Colors.red.shade100,
                      checkmarkColor: Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<MapType>(
                      value: _currentMapType,
                      icon: const Icon(Icons.layers),
                      underline: Container(),
                      items: const [
                        DropdownMenuItem(
                          value: MapType.normal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.map, size: 16),
                              SizedBox(width: 8),
                              Text('Normal'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: MapType.satellite,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.satellite_alt, size: 16),
                              SizedBox(width: 8),
                              Text('Satellite'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: MapType.hybrid,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.layers, size: 16),
                              SizedBox(width: 8),
                              Text('Hybrid'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (MapType? newType) {
                        if (newType != null) {
                          setState(() {
                            _currentMapType = newType;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Google Maps is fully configured for mobile platforms',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 13,
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
    );
  }

  Widget _buildMapView() {
    final filteredLocations = _showOutliersOnly
        ? widget.scanLocations.where((loc) => loc.isOutlier).toList()
        : widget.scanLocations;

    if (filteredLocations.isEmpty) {
      return _buildEmptyState();
    }

    // Calculate center point
    LatLng center;
    if (widget.selectedBorder?.latitude != null &&
        widget.selectedBorder?.longitude != null) {
      center = LatLng(
          widget.selectedBorder!.latitude!, widget.selectedBorder!.longitude!);
    } else if (filteredLocations.isNotEmpty) {
      final avgLat =
          filteredLocations.map((l) => l.latitude).reduce((a, b) => a + b) /
              filteredLocations.length;
      final avgLng =
          filteredLocations.map((l) => l.longitude).reduce((a, b) => a + b) /
              filteredLocations.length;
      center = LatLng(avgLat, avgLng);
    } else {
      center = const LatLng(0, 0);
    }

    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 500,
          child: GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            initialCameraPosition: CameraPosition(
              target: center,
              zoom: 12.0,
            ),
            markers: _markers,
            circles: _circles,
            mapType: _currentMapType,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Container(
        height: 500,
        child: Center(
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
        ),
      ),
    );
  }

  Widget _buildLocationDetails() {
    if (_selectedLocation == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Selected Location Details',
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
            width: 120,
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

  Widget _buildDataTableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.table_chart, color: Colors.indigo.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Detailed Scan Locations Data',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.indigo.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Sortable table view of all scan locations with detailed information',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.indigo.shade600,
              ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 400,
          child: ScanLocationsDataTable(
            scanLocations: widget.scanLocations,
            showOutliersOnly: _showOutliersOnly,
            onLocationSelected: (location) {
              _showLocationActionSheet(location);
            },
          ),
        ),
      ],
    );
  }

  void _showLocationActionSheet(ScanLocationData location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: LocationActionSheet(
          location: location,
          borderId: widget.selectedBorder?.id,
          borderName: widget.selectedBorder?.name,
          timeframe: widget.timeframe ?? '7d',
          showOutliersOnly: _showOutliersOnly,
          customStartDate: widget.customStartDate,
          customEndDate: widget.customEndDate,
        ),
      ),
    );
  }

  Color _getScanCountColor(int scanCount) {
    if (scanCount >= 20) return Colors.red.shade600;
    if (scanCount >= 10) return Colors.orange.shade600;
    if (scanCount >= 5) return Colors.blue.shade600;
    return Colors.green.shade600;
  }
}
