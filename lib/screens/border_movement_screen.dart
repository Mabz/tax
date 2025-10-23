import 'package:flutter/material.dart';

import '../models/pass_movement.dart';
import '../services/border_movement_service_final.dart';
import '../widgets/pass_movement_history_dialog.dart';

class BorderMovementScreen extends StatefulWidget {
  final String borderId;
  final String borderName;

  const BorderMovementScreen({
    super.key,
    required this.borderId,
    required this.borderName,
  });

  @override
  State<BorderMovementScreen> createState() => _BorderMovementScreenState();
}

class _BorderMovementScreenState extends State<BorderMovementScreen> {
  bool _isLoading = true;
  String? _error;
  List<PassMovement> _movements = [];
  List<VehicleMovementSummary> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMovements() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final movements = await BorderMovementService.getBorderMovements(
        widget.borderId,
        limit: 50,
      );

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

  Future<void> _searchVehicles(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchQuery = '';
      });
      return;
    }

    try {
      setState(() {
        _isSearching = true;
        _searchQuery = query;
      });

      final results = await BorderMovementService.searchVehicles(
        widget.borderId,
        query,
      );

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSearching = false;
      });
    }
  }

  Future<void> _showVehicleMovements(VehicleMovementSummary vehicle) async {
    try {
      final movements = await BorderMovementService.getVehicleMovements(
        widget.borderId,
        vehicle.vehicleVin,
        vehicle.vehicleRegistrationNumber,
      );

      if (!mounted) return;

      PassMovementHistoryDialog.show(
        context,
        movements,
        vehicleInfo: vehicle.vehicleInfo,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load vehicle movements: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Movement - ${widget.borderName}'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMovements,
            tooltip: 'Refresh Movements',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchSection(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorWidget()
                    : _searchQuery.isNotEmpty
                        ? _buildSearchResults()
                        : _buildMovementsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.purple.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: Colors.purple.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                'Vehicle Search',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.purple.shade800,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Search by VIN, make, model, or registration number',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.purple.shade600,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Enter VIN, make, model, or registration number...',
              prefixIcon: Icon(Icons.search, color: Colors.purple.shade600),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchVehicles('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.purple.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
              ),
            ),
            onChanged: (value) {
              if (value.length >= 2) {
                _searchVehicles(value);
              } else if (value.isEmpty) {
                _searchVehicles('');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Failed to load movements',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadMovements,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching vehicles...'),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No vehicles found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'No vehicles match your search criteria: "$_searchQuery"',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Search Results (${_searchResults.length} vehicles)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _searchResults.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final vehicle = _searchResults[index];
              return _buildVehicleCard(vehicle);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard(VehicleMovementSummary vehicle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showVehicleMovements(vehicle),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.directions_car,
            color: Colors.blue.shade700,
            size: 24,
          ),
        ),
        title: Text(
          vehicle.vehicleInfo,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timeline, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${vehicle.totalMovements} movements',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                if (vehicle.lastMovement != null) ...[
                  Icon(Icons.access_time,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimestamp(vehicle.lastMovement!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
            if (vehicle.lastMovementType != null) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getMovementTypeColor(vehicle.lastMovementType!)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getMovementTypeLabel(vehicle.lastMovementType!),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getMovementTypeColor(vehicle.lastMovementType!),
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }

  Widget _buildMovementsList() {
    if (_movements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Movements Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'No vehicle movements recorded for this border yet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Recent Movements (${_movements.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _movements.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final movement = _movements[index];
              return _buildMovementCard(movement);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMovementCard(PassMovement movement) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                movement.movementTypeDisplay,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getMovementTypeColor(movement.movementType)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getMovementTypeLabel(movement.movementType),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getMovementTypeColor(movement.movementType),
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              movement.vehicleInfo,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(movement.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (movement.officialName != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    movement.officialName!,
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

  String _getMovementTypeLabel(String type) {
    switch (type) {
      case 'check_in':
        return 'Check-In';
      case 'check_out':
        return 'Check-Out';
      case 'local_authority_scan':
        return 'Scan';
      default:
        return 'Movement';
    }
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
