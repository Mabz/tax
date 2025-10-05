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

  // Default location (center of Africa for border context)
  static const LatLng _defaultLocation =
      LatLng(-1.2921, 36.8219); // Nairobi, Kenya

  // Check if Google Maps is supported on this platform
  bool get _isGoogleMapsSupported {
    if (kIsWeb) return false;
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
    }
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
        if (_selectedAddress != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Location:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedAddress!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_selectedLocation != null)
                  Text(
                    'Coordinates: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation ?? _defaultLocation,
                  zoom: 10,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                onTap: _onMapTapped,
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                mapType: MapType.hybrid,
              ),
              if (_isLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(),
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
          // Platform notice
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Web/Desktop Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Interactive maps are not available on this platform. Use the options below to select a location.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Manual coordinate entry
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_location, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text(
                        'Enter Coordinates Manually',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., -26.2041',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (value) => _updateCoordinatesFromInput(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 28.0473',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (value) => _updateCoordinatesFromInput(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Open in external map
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.open_in_new, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Use External Map Service',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Open Google Maps in your browser to find the exact location, then copy the coordinates back here.',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openGoogleMapsInBrowser,
                      icon: const Icon(Icons.map),
                      label: const Text('Open Google Maps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Current selection display
          if (_selectedLocation != null) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
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
                  Text(
                    'Coordinates: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                  ),
                  if (_selectedAddress != null)
                    Text('Address: $_selectedAddress'),
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
    });
    _getAddressFromCoordinates(location);
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
            });
            _getAddressFromCoordinates(newLocation);
          },
          infoWindow: const InfoWindow(
            title: 'Selected Location',
            snippet: 'Drag to adjust position',
          ),
        ),
      };
    });
  }

  void _updateCoordinatesFromInput() {
    // This would be implemented to read from text controllers
    // For now, it's a placeholder for the manual input functionality
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
          _selectedAddress = address.isNotEmpty ? address : 'Unknown location';
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = 'Address lookup failed';
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
