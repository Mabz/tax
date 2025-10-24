import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:url_launcher/url_launcher.dart';

/// Platform-aware location picker that works on mobile, web, and desktop
class PlatformLocationPicker extends StatefulWidget {
  final LatLng? initialLocation;
  final Function(LatLng, String?) onLocationSelected;
  final String title;

  const PlatformLocationPicker({
    super.key,
    this.initialLocation,
    required this.onLocationSelected,
    this.title = 'Select Location',
  });

  @override
  State<PlatformLocationPicker> createState() => _PlatformLocationPickerState();
}

class _PlatformLocationPickerState extends State<PlatformLocationPicker> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoading = false;
  Set<Marker> _markers = {};

  // Text controllers for manual coordinate input
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  // Default location (center of Africa for border context)
  static const LatLng _defaultLocation =
      LatLng(-1.2921, 36.8219); // Nairobi, Kenya

  MapType _currentMapType = MapType.normal;

  // Check if Google Maps is supported on this platform
  bool get _isGoogleMapsSupported {
    // Google Maps is now supported on web with the API key configured
    if (kIsWeb) return true;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
      return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    if (_selectedLocation != null) {
      _updateMarker(_selectedLocation!);
      _getAddressFromCoordinates(_selectedLocation!);
      // Pre-fill text controllers if we have an initial location
      _latController.text = _selectedLocation!.latitude.toStringAsFixed(6);
      _lngController.text = _selectedLocation!.longitude.toStringAsFixed(6);
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_isGoogleMapsSupported) ...[
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _getCurrentLocation,
              tooltip: 'Use current location',
            ),
          ],
          TextButton(
            onPressed: _selectedLocation != null ? _confirmSelection : null,
            child: const Text('CONFIRM'),
          ),
        ],
      ),
      body: _isGoogleMapsSupported
          ? _buildGoogleMapsView()
          : _buildWebFallbackView(),
    );
  }

  Widget _buildGoogleMapsView() {
    return Column(
      children: [
        // Instructions banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.orange.shade50,
          child: Row(
            children: [
              Icon(Icons.touch_app, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap on the map to select a location, or drag the marker to adjust position',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Selected location info
        if (_selectedLocation != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Selected Location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_selectedAddress != null)
                  Text(
                    _selectedAddress!,
                    style: const TextStyle(fontSize: 14),
                  ),
                Text(
                  'Coordinates: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

        // Map view
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation ?? _defaultLocation,
                  zoom: _selectedLocation != null ? 15 : 6,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                onTap: _onMapTapped,
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                mapType: _currentMapType,
                compassEnabled: true,
                mapToolbarEnabled: false,
                zoomControlsEnabled: true,
              ),

              // Loading overlay
              if (_isLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                ),

              // Map type toggle
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: "mapType",
                      onPressed: _toggleMapType,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.layers, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: "currentLocation",
                      onPressed: _getCurrentLocation,
                      backgroundColor: Colors.orange,
                      child: const Icon(Icons.my_location, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebFallbackView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Manual coordinate entry
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_location,
                          color: Colors.orange, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Enter Coordinates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the exact latitude and longitude for the border location.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., -26.2041',
                            prefixIcon: Icon(Icons.north),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          onChanged: (value) => _updateCoordinatesFromInput(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _lngController,
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 28.0473',
                            prefixIcon: Icon(Icons.east),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          onChanged: (value) => _updateCoordinatesFromInput(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _validateAndSetCoordinates,
                      icon: const Icon(Icons.check),
                      label: const Text('Set Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Open in external map
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.map, color: Colors.green, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Use Google Maps',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Open Google Maps to visually find the location, then copy the coordinates back here.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openGoogleMapsInBrowser,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open Google Maps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Current selection display
          if (_selectedLocation != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green.shade700, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Location Selected',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text('Coordinates:',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 16),
                        ),
                        if (_selectedAddress != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.place,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              const Text('Address:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(_selectedAddress!,
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _updateMarker(location);
      // Update text controllers
      _latController.text = location.latitude.toStringAsFixed(6);
      _lngController.text = location.longitude.toStringAsFixed(6);
    });
    _getAddressFromCoordinates(location);
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType =
          _currentMapType == MapType.normal ? MapType.terrain : MapType.normal;
    });
  }

  void _updateMarker(LatLng location) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: location,
          draggable: true,
          onDragEnd: (LatLng newLocation) {
            setState(() {
              _selectedLocation = newLocation;
              // Update text controllers when marker is dragged
              _latController.text = newLocation.latitude.toStringAsFixed(6);
              _lngController.text = newLocation.longitude.toStringAsFixed(6);
            });
            _getAddressFromCoordinates(newLocation);
          },
          infoWindow: InfoWindow(
            title: 'Border Location',
            snippet:
                'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      };
    });
  }

  void _updateCoordinatesFromInput() {
    // Real-time validation as user types
    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();

    if (latText.isNotEmpty && lngText.isNotEmpty) {
      final lat = double.tryParse(latText);
      final lng = double.tryParse(lngText);

      if (lat != null && lng != null && _isValidCoordinate(lat, lng)) {
        // Valid coordinates - could show a preview or validation indicator
        setState(() {
          // Update UI to show coordinates are valid
        });
      }
    }
  }

  void _validateAndSetCoordinates() {
    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();

    if (latText.isEmpty || lngText.isEmpty) {
      _showError('Please enter both latitude and longitude');
      return;
    }

    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);

    if (lat == null || lng == null) {
      _showError('Please enter valid numeric coordinates');
      return;
    }

    if (!_isValidCoordinate(lat, lng)) {
      _showError(
          'Coordinates must be valid (latitude: -90 to 90, longitude: -180 to 180)');
      return;
    }

    final location = LatLng(lat, lng);
    setState(() {
      _selectedLocation = location;
      if (_isGoogleMapsSupported) {
        _updateMarker(location);
      }
    });

    _getAddressFromCoordinates(location);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location set successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  Future<void> _openGoogleMapsInBrowser() async {
    final lat = _selectedLocation?.latitude ?? _defaultLocation.latitude;
    final lng = _selectedLocation?.longitude ?? _defaultLocation.longitude;

    final url = Uri.parse('https://www.google.com/maps/@$lat,$lng,15z');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Google Maps'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getAddressFromCoordinates(LatLng location) async {
    try {
      setState(() {
        _isLoading = true;
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = [
          placemark.name,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');

        setState(() {
          _selectedAddress = address.isNotEmpty ? address : null;
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = null; // Don't show error message, just no address
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!_isGoogleMapsSupported) return;

    try {
      setState(() {
        _isLoading = true;
      });

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permissions are permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final currentLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = currentLocation;
        _updateMarker(currentLocation);
        // Update text controllers
        _latController.text = currentLocation.latitude.toStringAsFixed(6);
        _lngController.text = currentLocation.longitude.toStringAsFixed(6);
      });

      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(currentLocation, 15),
        );
      }

      _getAddressFromCoordinates(currentLocation);
    } catch (e) {
      _showError('Failed to get current location: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      widget.onLocationSelected(_selectedLocation!, _selectedAddress);
      Navigator.of(context).pop();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
