import 'package:flutter/material.dart';
import '../models/border.dart' as border_model;
import '../models/pass_movement.dart';
import '../services/border_movement_service_optimized.dart';
import '../services/border_manager_service.dart';
import '../widgets/pass_movement_history_dialog.dart';

class BorderMovementScreen extends StatefulWidget {
  final String? authorityId;
  final String? authorityName;

  const BorderMovementScreen({
    super.key,
    this.authorityId,
    this.authorityName,
  });

  @override
  State<BorderMovementScreen> createState() => _BorderMovementScreenState();
}

class _BorderMovementScreenState extends State<BorderMovementScreen> {
  bool _isLoading = true;
  String? _error;
  List<border_model.Border> _availableBorders = [];
  border_model.Border? _selectedBorder;
  List<PassMovement> _movements = [];
  List<VehicleMovementSummary> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Time period controls
  String _selectedTimeframe = '7d'; // 1d, 7d, 30d, 90d, custom
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _loadAvailableBorders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableBorders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      List<border_model.Border> borders;

      // If authorityId is provided, get borders for that authority
      // Otherwise, get borders assigned to current user (for border managers)
      if (widget.authorityId != null) {
        borders = await _getBordersForAuthority(widget.authorityId!);
      } else {
        borders =
            await BorderManagerService.getAssignedBordersForCurrentManager();
      }

      setState(() {
        _availableBorders = borders;
        _selectedBorder = borders.isNotEmpty ? borders.first : null;
        _isLoading = false;
      });

      // Load data for the first border
      if (_selectedBorder != null) {
        await _loadMovements();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<border_model.Border>> _getBordersForAuthority(
      String authorityId) async {
    // Get borders for the specified authority
    final response = await BorderManagerService.supabase
        .from('borders')
        .select(
            'id, name, description, authority_id, border_type_id, is_active, latitude, longitude, created_at, updated_at')
        .eq('authority_id', authorityId)
        .eq('is_active', true)
        .order('name');

    return (response as List)
        .map((item) => border_model.Border.fromJson(item))
        .toList();
  }

  Future<void> _loadMovements() async {
    if (_selectedBorder == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final movements = await BorderMovementService.getBorderMovements(
        _selectedBorder!.id,
        limit: 50,
        timeframe: _selectedTimeframe,
        customStartDate: _customStartDate,
        customEndDate: _customEndDate,
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

    if (_selectedBorder == null) return;

    try {
      setState(() {
        _isSearching = true;
        _searchQuery = query;
      });

      final results = await BorderMovementService.searchVehicles(
        _selectedBorder!.id,
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
    if (_selectedBorder == null) return;

    try {
      final movements = await BorderMovementService.getVehicleMovements(
        _selectedBorder!.id,
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

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _selectedTimeframe = 'custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _loadMovements();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : Column(
                  children: [
                    _buildControlsSection(),
                    Expanded(
                      child: _searchQuery.isNotEmpty
                          ? _buildSearchResults()
                          : _buildMovementsList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      color: Colors.purple.shade50,
      child: Column(
        children: [
          _buildBorderSelector(),
          _buildTimeframeSelector(),
          _buildSearchSection(),
        ],
      ),
    );
  }

  Widget _buildBorderSelector() {
    if (_availableBorders.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Border for Movement Analysis',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<border_model.Border>(
              value: _selectedBorder,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _availableBorders.map((border) {
                return DropdownMenuItem(
                  value: border,
                  child: Text(border.name),
                );
              }).toList(),
              onChanged: (border) {
                setState(() {
                  _selectedBorder = border;
                  _searchResults = [];
                  _searchQuery = '';
                  _searchController.clear();
                });
                if (border != null) {
                  _loadMovements();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.purple.shade50, Colors.purple.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.purple.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Movement Time Period',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.purple.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTimeframeChip('1d', 'Last 24 Hours'),
                  _buildTimeframeChip('7d', 'Last 7 Days'),
                  _buildTimeframeChip('30d', 'Last 30 Days'),
                  _buildTimeframeChip('90d', 'Last 3 Months'),
                  _buildTimeframeChip('custom', 'Custom Range'),
                ],
              ),
              if (_selectedTimeframe == 'custom' &&
                  _customStartDate != null &&
                  _customEndDate != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: Colors.purple.shade700, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatDate(_customStartDate!)} - ${_formatDate(_customEndDate!)}',
                        style: TextStyle(
                          color: Colors.purple.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_customEndDate!.difference(_customStartDate!).inDays + 1} days',
                        style: TextStyle(
                          color: Colors.purple.shade600,
                          fontSize: 12,
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

  Widget _buildTimeframeChip(String value, String label) {
    final isSelected = _selectedTimeframe == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          if (value == 'custom') {
            _showDateRangePicker();
          } else {
            setState(() {
              _selectedTimeframe = value;
            });
            _loadMovements();
          }
        }
      },
      selectedColor: Colors.purple.shade100,
      checkmarkColor: Colors.purple.shade700,
      backgroundColor: Colors.purple.shade50,
      labelStyle: TextStyle(
        color: isSelected ? Colors.purple.shade800 : Colors.purple.shade600,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: Colors.purple.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Vehicle Search',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.purple.shade800,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Search by VIN, make, model, or registration number',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
    if (_selectedBorder == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.border_clear, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Border Selected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Please select a border to view vehicle movements.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

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
              'No vehicle movements recorded for this border in the selected time period.',
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
        onTap: () => _showMovementHistory(movement),
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
                  // Show profile image if available, otherwise use person icon
                  if (movement.officialProfileImageUrl != null &&
                      movement.officialProfileImageUrl!.isNotEmpty)
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.grey.shade400, width: 0.5),
                      ),
                      child: ClipOval(
                        child: Image.network(
                          movement.officialProfileImageUrl!,
                          width: 16,
                          height: 16,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.person,
                                size: 14, color: Colors.grey.shade600);
                          },
                        ),
                      ),
                    )
                  else
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
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _showMovementHistory(PassMovement movement) async {
    if (_selectedBorder == null) return;

    try {
      final movements = await BorderMovementService.getVehicleMovements(
        _selectedBorder!.id,
        movement.vehicleVin,
        movement.vehicleRegistrationNumber,
      );

      if (!mounted) return;

      PassMovementHistoryDialog.show(
        context,
        movements,
        vehicleInfo: movement.vehicleInfo,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load movement history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
