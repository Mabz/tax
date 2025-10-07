import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/enhanced_border_service.dart';
import '../services/role_service.dart';
import '../utils/time_utils.dart';
import 'profile_image_widget.dart';

/// Widget to display pass movement history
class PassHistoryWidget extends StatefulWidget {
  final String passId;
  final String? shortCode;

  const PassHistoryWidget({
    super.key,
    required this.passId,
    this.shortCode,
  });

  @override
  State<PassHistoryWidget> createState() => _PassHistoryWidgetState();
}

class _PassHistoryWidgetState extends State<PassHistoryWidget> {
  List<PassMovement> _movements = [];
  bool _isLoading = false;
  String? _error;
  bool _hasNotesViewingRights = false;

  // Cache for location names to avoid repeated geocoding calls
  final Map<String, String> _locationCache = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _checkNotesViewingRights();
  }

  Future<void> _checkNotesViewingRights() async {
    try {
      // Check if user has any of the authorized roles for viewing notes
      final hasBusinessIntelligence =
          await RoleService.hasBusinessIntelligenceRole();
      final hasCountryAdmin = await RoleService.hasAdminRole();
      final hasBorderOfficial = await RoleService.hasBorderOfficialRole();
      final hasLocalAuthority = await RoleService.hasLocalAuthorityRole();
      final hasAuditor = await RoleService.hasAuditorRole();

      setState(() {
        _hasNotesViewingRights = hasBusinessIntelligence ||
            hasCountryAdmin ||
            hasBorderOfficial ||
            hasLocalAuthority ||
            hasAuditor;
      });
    } catch (e) {
      debugPrint('Error checking notes viewing rights: $e');
      // Default to false for security
      setState(() {
        _hasNotesViewingRights = false;
      });
    }
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
              widget.shortCode != null
                  ? 'Backup Code: ${widget.shortCode}'
                  : 'Pass ID: ${widget.passId.substring(0, 8)}...',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: LinearProgressIndicator(color: Colors.blue),
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
                                        // Profile Image
                                        ProfileImageWidget(
                                          currentImageUrl:
                                              movement.officialProfileImageUrl,
                                          size: 40,
                                          isEditable: false,
                                        ),
                                        const SizedBox(width: 12),
                                        // Status Icon
                                        Icon(
                                          _isLocalAuthorityMovement(movement)
                                              ? Icons.security
                                              : movement.movementType ==
                                                      'check_in'
                                                  ? Icons.login
                                                  : Icons.logout,
                                          color: _isLocalAuthorityMovement(
                                                  movement)
                                              ? Colors.orange
                                              : movement.movementType ==
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
                                            // Only show Entry/Exit labels for border movements, not local authority
                                            if (!_isLocalAuthorityMovement(
                                                movement))
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: movement
                                                              .movementType ==
                                                          'check_in'
                                                      ? Colors.green.withValues(
                                                          alpha: 0.1)
                                                      : Colors.blue.withValues(
                                                          alpha: 0.1),
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
                                            if (!_isLocalAuthorityMovement(
                                                movement))
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
                                    // Show different details based on movement type
                                    if (_isLocalAuthorityMovement(
                                        movement)) ...[
                                      // For local authority movements
                                      _buildDetailRow(
                                          Icons.business,
                                          'Local Authority',
                                          movement.officialName),
                                      _buildDetailRow(
                                          Icons.access_time,
                                          'Processed',
                                          TimeUtils.formatFullDateTime(
                                              movement.processedAt)),
                                      if (movement.entriesDeducted > 0)
                                        _buildDetailRow(
                                            Icons.remove_circle_outline,
                                            'Entries Deducted',
                                            movement.entriesDeducted
                                                .toString()),
                                      _buildLocationRow(movement),
                                      // Show notes for authorized users
                                      if (_hasNotesViewingRights &&
                                          movement.notes?.isNotEmpty == true)
                                        _buildDetailRow(Icons.note, 'Notes',
                                            movement.notes!),
                                    ] else ...[
                                      // For border movements
                                      _buildDetailRow(Icons.location_on,
                                          'Border', movement.borderName),
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
                                            movement.entriesDeducted
                                                .toString()),
                                      _buildLocationRow(movement),
                                      // Show notes for authorized users
                                      if (_hasNotesViewingRights &&
                                          movement.notes?.isNotEmpty == true)
                                        _buildDetailRow(Icons.note, 'Notes',
                                            movement.notes!),
                                    ],
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
        backgroundColor: Colors.blue,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  /// Helper method to identify local authority movements
  bool _isLocalAuthorityMovement(PassMovement movement) {
    return movement.movementType == 'local_authority_scan' ||
        movement.authorityType == 'local_authority' ||
        movement.scanPurpose != null;
  }

  /// Show map popup with navigation through all movements
  void _showMapPopup(PassMovement selectedMovement) {
    final currentIndex = _movements.indexOf(selectedMovement);

    showDialog(
      context: context,
      builder: (context) => MapNavigationPopup(
        movements: _movements,
        initialIndex: currentIndex,
        hasNotesViewingRights: _hasNotesViewingRights,
        locationCache: _locationCache,
        getLocationName: _getLocationName,
      ),
    );
  }

  /// Get location name from coordinates with caching
  Future<String> _getLocationName(double latitude, double longitude) async {
    final key =
        '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';

    // Return cached result if available
    if (_locationCache.containsKey(key)) {
      return _locationCache[key]!;
    }

    try {
      debugPrint('🌍 Getting location for: $latitude, $longitude');

      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      debugPrint('🌍 Geocoding returned ${placemarks.length} placemarks');

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;

        // Build location string with available information
        List<String> locationParts = [];

        if (placemark.locality?.isNotEmpty == true) {
          locationParts.add(placemark.locality!);
        }
        if (placemark.administrativeArea?.isNotEmpty == true) {
          locationParts.add(placemark.administrativeArea!);
        }
        if (placemark.country?.isNotEmpty == true) {
          locationParts.add(placemark.country!);
        }

        String locationName = locationParts.isNotEmpty
            ? locationParts.join(', ')
            : '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

        // Cache the result
        _locationCache[key] = locationName;
        debugPrint('🌍 Location resolved to: $locationName');

        return locationName;
      }
    } catch (e) {
      debugPrint('🌍 Geocoding error: $e');
    }

    // Fallback to coordinates
    final fallback =
        '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    _locationCache[key] = fallback;
    return fallback;
  }

  Widget _buildLocationRow(PassMovement movement) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.gps_fixed, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'Location: ',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              Expanded(
                child: FutureBuilder<String>(
                  future:
                      _getLocationName(movement.latitude, movement.longitude),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Loading location...',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      );
                    } else if (snapshot.hasError) {
                      return Text(
                        'Error - ${movement.latitude.toStringAsFixed(6)}, ${movement.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(color: Colors.black87),
                      );
                    } else {
                      return Text(
                        snapshot.data ??
                            '${movement.latitude.toStringAsFixed(6)}, ${movement.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(color: Colors.black87),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // Thin map banner
        Container(
          height: 80,
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(movement.latitude, movement.longitude),
                zoom: 14,
              ),
              markers: {
                Marker(
                  markerId: MarkerId('movement_${movement.movementId}'),
                  position: LatLng(movement.latitude, movement.longitude),
                  infoWindow: InfoWindow(
                    title: movement.actionDescription,
                    snippet:
                        '${movement.latitude.toStringAsFixed(6)}, ${movement.longitude.toStringAsFixed(6)}',
                  ),
                ),
              },
              onTap: (LatLng position) {
                _showMapPopup(movement);
              },
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              liteModeEnabled: true, // This makes it a static-like map
            ),
          ),
        ),
      ],
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

/// Popup widget for navigating through movement locations on a map
class MapNavigationPopup extends StatefulWidget {
  final List<PassMovement> movements;
  final int initialIndex;
  final bool hasNotesViewingRights;
  final Map<String, String> locationCache;
  final Future<String> Function(double, double) getLocationName;

  const MapNavigationPopup({
    super.key,
    required this.movements,
    required this.initialIndex,
    required this.hasNotesViewingRights,
    required this.locationCache,
    required this.getLocationName,
  });

  @override
  State<MapNavigationPopup> createState() => _MapNavigationPopupState();
}

class _MapNavigationPopupState extends State<MapNavigationPopup> {
  late int _currentIndex;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  PassMovement get _currentMovement => widget.movements[_currentIndex];

  void _navigateToMovement(int newIndex) {
    if (newIndex >= 0 && newIndex < widget.movements.length) {
      setState(() {
        _currentIndex = newIndex;
      });

      // Smooth animate to new location with better camera positioning
      final movement = widget.movements[newIndex];
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(movement.latitude, movement.longitude),
            zoom: 16,
            tilt: 0,
            bearing: 0,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              'Movement ${_currentIndex + 1} of ${widget.movements.length}'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: Stack(
          children: [
            // Full screen map
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                    _currentMovement.latitude, _currentMovement.longitude),
                zoom: 16,
              ),
              markers: {
                Marker(
                  markerId: MarkerId('current_movement'),
                  position: LatLng(
                      _currentMovement.latitude, _currentMovement.longitude),
                  infoWindow: InfoWindow(
                    title: _currentMovement.actionDescription,
                    snippet: TimeUtils.formatFullDateTime(
                        _currentMovement.processedAt),
                  ),
                ),
              },
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
            ),

            // Navigation arrows
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _currentIndex > 0
                    ? FloatingActionButton(
                        heroTag: "prev",
                        onPressed: () => _navigateToMovement(_currentIndex - 1),
                        backgroundColor: Colors.blue,
                        child:
                            const Icon(Icons.arrow_back, color: Colors.white),
                      )
                    : Container(),
              ),
            ),

            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _currentIndex < widget.movements.length - 1
                    ? FloatingActionButton(
                        heroTag: "next",
                        onPressed: () => _navigateToMovement(_currentIndex + 1),
                        backgroundColor: Colors.blue,
                        child: const Icon(Icons.arrow_forward,
                            color: Colors.white),
                      )
                    : Container(),
              ),
            ),

            // Movement details card at bottom
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isLocalAuthorityMovement(_currentMovement)
                                ? Icons.security
                                : _currentMovement.movementType == 'check_in'
                                    ? Icons.login
                                    : Icons.logout,
                            color: _isLocalAuthorityMovement(_currentMovement)
                                ? Colors.orange
                                : _currentMovement.movementType == 'check_in'
                                    ? Colors.green
                                    : Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentMovement.actionDescription,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (!_isLocalAuthorityMovement(_currentMovement))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    _currentMovement.movementType == 'check_in'
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _currentMovement.movementType == 'check_in'
                                    ? 'ENTRY'
                                    : 'EXIT',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _currentMovement.movementType ==
                                          'check_in'
                                      ? Colors.green
                                      : Colors.blue,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Movement details
                      if (_isLocalAuthorityMovement(_currentMovement)) ...[
                        _buildPopupDetailRow(Icons.business, 'Local Authority',
                            _currentMovement.officialName),
                      ] else ...[
                        _buildPopupDetailRow(Icons.location_on, 'Border',
                            _currentMovement.borderName),
                        _buildPopupDetailRow(Icons.person, 'Official',
                            _currentMovement.officialName),
                        _buildPopupDetailRow(Icons.swap_horiz, 'Status Change',
                            '${_currentMovement.previousStatus} → ${_currentMovement.newStatus}'),
                      ],

                      _buildPopupDetailRow(
                          Icons.access_time,
                          'Processed',
                          TimeUtils.formatFullDateTime(
                              _currentMovement.processedAt)),

                      if (_currentMovement.entriesDeducted > 0)
                        _buildPopupDetailRow(
                            Icons.remove_circle_outline,
                            'Entries Deducted',
                            _currentMovement.entriesDeducted.toString()),

                      // Location with geocoding
                      _buildPopupLocationRow(),

                      // Notes for authorized users
                      if (widget.hasNotesViewingRights &&
                          _currentMovement.notes?.isNotEmpty == true)
                        _buildPopupDetailRow(
                            Icons.note, 'Notes', _currentMovement.notes!),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isLocalAuthorityMovement(PassMovement movement) {
    return movement.movementType == 'local_authority_scan' ||
        movement.authorityType == 'local_authority' ||
        movement.scanPurpose != null;
  }

  Widget _buildPopupDetailRow(IconData icon, String label, String value) {
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

  Widget _buildPopupLocationRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gps_fixed, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            'Location: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: FutureBuilder<String>(
              future: widget.getLocationName(
                  _currentMovement.latitude, _currentMovement.longitude),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading location...',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  );
                } else if (snapshot.hasError) {
                  return Text(
                    'Error - ${_currentMovement.latitude.toStringAsFixed(6)}, ${_currentMovement.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: Colors.black87),
                  );
                } else {
                  return Text(
                    snapshot.data ??
                        '${_currentMovement.latitude.toStringAsFixed(6)}, ${_currentMovement.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: Colors.black87),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
