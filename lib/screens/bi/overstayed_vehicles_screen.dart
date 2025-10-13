import 'package:flutter/material.dart';
import '../../models/authority.dart';
import '../../services/business_intelligence_service.dart';
import '../../widgets/pass_history_widget.dart';
import '../../widgets/owner_details_button.dart';

/// Overstayed Vehicles Detail Screen
/// Shows detailed list of vehicles that have overstayed their pass validity
class OverstayedVehiclesScreen extends StatefulWidget {
  final Authority authority;
  final String period;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String borderFilter;

  const OverstayedVehiclesScreen({
    super.key,
    required this.authority,
    this.period = 'all_time',
    this.customStartDate,
    this.customEndDate,
    this.borderFilter = 'any_border',
  });

  @override
  State<OverstayedVehiclesScreen> createState() =>
      _OverstayedVehiclesScreenState();
}

class _OverstayedVehiclesScreenState extends State<OverstayedVehiclesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _overstayedVehicles = [];
  String _sortBy = 'daysOverdue'; // daysOverdue, amount, vehicleReg
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadOverstayedVehicles();
  }

  Future<void> _loadOverstayedVehicles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vehicles =
          await BusinessIntelligenceService.getOverstayedVehiclesDetails(
        widget.authority.id,
        period: widget.period,
        customStartDate: widget.customStartDate,
        customEndDate: widget.customEndDate,
        borderFilter: widget.borderFilter,
      );

      if (mounted) {
        setState(() {
          _overstayedVehicles = vehicles;
          _isLoading = false;
        });
        _sortVehicles();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading overstayed vehicles: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _sortVehicles() {
    setState(() {
      _overstayedVehicles.sort((a, b) {
        dynamic aValue, bValue;

        switch (_sortBy) {
          case 'daysOverdue':
            aValue = a['daysOverdue'] as int;
            bValue = b['daysOverdue'] as int;
            break;
          case 'amount':
            aValue = a['amount'] as double;
            bValue = b['amount'] as double;
            break;
          case 'vehicleReg':
            aValue = a['vehicleRegistrationNumber'] as String;
            bValue = b['vehicleRegistrationNumber'] as String;
            break;
          case 'ownerName':
            aValue = a['ownerFullName'] as String;
            bValue = b['ownerFullName'] as String;
            break;
          default:
            aValue = a['daysOverdue'] as int;
            bValue = b['daysOverdue'] as int;
        }

        if (_sortAscending) {
          return Comparable.compare(aValue, bValue);
        } else {
          return Comparable.compare(bValue, aValue);
        }
      });
    });
  }

  void _changeSortOrder(String sortBy) {
    setState(() {
      if (_sortBy == sortBy) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = sortBy;
        _sortAscending = false;
      }
    });
    _sortVehicles();
  }

  String _getPeriodDisplayText() {
    switch (widget.period) {
      case 'current_month':
        return 'Current Month';
      case 'last_month':
        return 'Last Month';
      case 'last_3_months':
        return 'Last 3 Months';
      case 'last_6_months':
        return 'Last 6 Months';
      case 'custom':
        if (widget.customStartDate != null && widget.customEndDate != null) {
          return '${_formatDate(widget.customStartDate!)} - ${_formatDate(widget.customEndDate!)}';
        }
        return 'Custom Range';
      default:
        return 'All Time';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatFriendlyDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    }
  }

  String _formatDateWithFriendly(DateTime date) {
    return '${_formatDate(date)} (${_formatFriendlyDate(date)})';
  }

  Color _getSeverityColor(int daysOverdue) {
    if (daysOverdue <= 7) return Colors.green.shade500;
    if (daysOverdue <= 30) return Colors.red;
    return Colors.green.shade800;
  }

  String _getSeverityText(int daysOverdue) {
    if (daysOverdue <= 7) return 'Recent';
    if (daysOverdue <= 30) return 'Critical';
    return 'Severe';
  }

  void _showVehicleDetails(Map<String, dynamic> vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildVehicleDetailsSheet(vehicle),
    );
  }

  void _showPassHistory(String passId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: Colors.green.shade600,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pass Movement History',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Pass History Widget
                  Expanded(
                    child: PassHistoryWidget(passId: passId),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVehicleDetailsSheet(Map<String, dynamic> vehicle) {
    final daysOverdue = vehicle['daysOverdue'] as int;
    final amount = vehicle['amount'] as double;
    final currency = vehicle['authorityCurrency'] as String;
    final passId = vehicle['passId'] as String;

    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getSeverityColor(daysOverdue)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.warning,
                                color: _getSeverityColor(daysOverdue),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Vehicle Details',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                  Text(
                                    '${_getSeverityText(daysOverdue)} Violation',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _getSeverityColor(daysOverdue),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getSeverityColor(daysOverdue),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '$daysOverdue days overdue',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Vehicle Summary Card with Last Position
                        _buildEnhancedVehicleSummaryCard(
                            vehicle, currency, amount, daysOverdue, passId),

                        const SizedBox(height: 16),

                        // Owner Information (if available) - moved up
                        if (vehicle['ownerFullName'] !=
                            'Owner Information Unavailable')
                          _buildOwnerSection(vehicle),

                        if (vehicle['ownerFullName'] !=
                            'Owner Information Unavailable')
                          const SizedBox(height: 16),

                        // Pass Information Section
                        _buildStatusSection(vehicle, currency, amount),

                        const SizedBox(height: 24),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border(bottom: BorderSide(color: Colors.green.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'Sort by:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(width: 16),
            _buildSortButton('Days Overdue', 'daysOverdue'),
            const SizedBox(width: 8),
            _buildSortButton('Amount', 'amount'),
            const SizedBox(width: 8),
            _buildSortButton('Vehicle', 'vehicleReg'),
            const SizedBox(width: 8),
            _buildSortButton('Owner', 'ownerName'),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton(String label, String sortKey) {
    final isActive = _sortBy == sortKey;
    return GestureDetector(
      onTap: () => _changeSortOrder(sortKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.green.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? Colors.green.shade600 : Colors.green.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.white : Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overstayed Vehicles'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadOverstayedVehicles,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Authority and period info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border:
                    Border(bottom: BorderSide(color: Colors.green.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.authority.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Period: ${_getPeriodDisplayText()} • ${_overstayedVehicles.length} vehicles overstayed',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Sort header
            if (!_isLoading && _overstayedVehicles.isNotEmpty)
              _buildSortHeader(),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error Loading Data',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadOverstayedVehicles,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _overstayedVehicles.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 64,
                                      color: Colors.green.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Overstayed Vehicles',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'All vehicles are compliant for the selected period',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _overstayedVehicles.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final vehicle = _overstayedVehicles[index];
                                return _buildVehicleCard(vehicle);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    final daysOverdue = vehicle['daysOverdue'] as int;
    final amount = vehicle['amount'] as double;
    final currency = vehicle['authorityCurrency'] as String;
    final vehicleReg = vehicle['vehicleRegistrationNumber'] as String;
    final vehicleDesc = vehicle['vehicleDescription'] as String;
    final ownerName = vehicle['ownerFullName'] as String;
    final entryPoint = vehicle['entryPointName'] as String;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showVehicleDetails(vehicle),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicleDesc,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reg: $vehicleReg',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getSeverityColor(daysOverdue),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$daysOverdue days',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Details row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Owner: $ownerName',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Entry: $entryPoint',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$currency ${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      Text(
                        'Revenue at risk',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build vehicle summary card with key information
  Widget _buildVehicleSummaryCard(Map<String, dynamic> vehicle, String currency,
      double amount, int daysOverdue) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: Colors.green.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Vehicle Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle['vehicleDescription'] ?? 'Unknown Vehicle',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reg: ${vehicle['vehicleRegistrationNumber'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (vehicle['vehicleVin'] != null &&
                          vehicle['vehicleVin'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'VIN: ${vehicle['vehicleVin']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      if (vehicle['vehicleMake'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${vehicle['vehicleMake']} ${vehicle['vehicleModel'] ?? ''} ${vehicle['vehicleYear'] ?? ''}'
                              .trim(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      if (vehicle['vehicleColor'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color:
                                    _getColorFromName(vehicle['vehicleColor']),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              vehicle['vehicleColor'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$currency ${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Revenue at Risk',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build enhanced vehicle summary card with last recorded position
  Widget _buildEnhancedVehicleSummaryCard(Map<String, dynamic> vehicle,
      String currency, double amount, int daysOverdue, String passId) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: Colors.green.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Vehicle Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle['vehicleDescription'] ?? 'Unknown Vehicle',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reg: ${vehicle['vehicleRegistrationNumber'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (vehicle['vehicleVin'] != null &&
                          vehicle['vehicleVin'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'VIN: ${vehicle['vehicleVin']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      if (vehicle['vehicleMake'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${vehicle['vehicleMake']} ${vehicle['vehicleModel'] ?? ''} ${vehicle['vehicleYear'] ?? ''}'
                              .trim(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      if (vehicle['vehicleColor'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color:
                                    _getColorFromName(vehicle['vehicleColor']),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              vehicle['vehicleColor'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$currency ${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Revenue at Risk',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Get time ago string from timestamp
  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Build timeline section with pass dates
  Widget _buildTimelineSection(Map<String, dynamic> vehicle) {
    final issuedDate = DateTime.parse(vehicle['issuedAt']);
    final activatedDate = DateTime.parse(vehicle['activationDate']);
    final expiredDate = DateTime.parse(vehicle['expiresAt']);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timeline,
                  color: Colors.green.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pass Timeline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimelineItem(
              Icons.add_circle,
              'Pass Issued',
              _formatDateWithFriendly(issuedDate),
              Colors.green,
              true,
            ),
            _buildTimelineItem(
              Icons.play_circle,
              'Pass Activated',
              _formatDateWithFriendly(activatedDate),
              Colors.green,
              true,
            ),
            _buildTimelineItem(
              Icons.cancel,
              'Pass Expired',
              _formatDateWithFriendly(expiredDate),
              Colors.red,
              false,
            ),
          ],
        ),
      ),
    );
  }

  /// Build timeline item
  Widget _buildTimelineItem(
      IconData icon, String title, String date, Color color, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCompleted
                  ? color.withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isCompleted ? color : Colors.grey.shade400,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build status and usage section
  Widget _buildStatusSection(
      Map<String, dynamic> vehicle, String currency, double amount) {
    final entryLimit = vehicle['entryLimit'] ?? 0;
    final entriesUsed = entryLimit - (vehicle['entriesRemaining'] ?? 0);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info,
                  color: Colors.green.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pass Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Single column layout for mobile-friendly display
            _buildPassInfoItem(
              'Pass Type',
              _generateCleanPassType(vehicle),
              Icons.description,
            ),
            const SizedBox(height: 12),
            _buildPassInfoItem(
              'Status',
              '${vehicle['status'] ?? 'Unknown'} • ${_getVehicleStatusDisplay(vehicle['currentStatus'])}',
              Icons.flag,
            ),
            const SizedBox(height: 12),
            _buildPassInfoItem(
              'Usage',
              '$entriesUsed of $entryLimit entries used',
              Icons.confirmation_number,
            ),
            const SizedBox(height: 12),
            _buildPassInfoItem(
              'Amount Paid',
              '$currency ${vehicle['amount']?.toStringAsFixed(2) ?? '0.00'}',
              Icons.attach_money,
            ),
            const SizedBox(height: 12),
            _buildPassInfoItem(
              'Route',
              _buildRouteInfo(vehicle),
              Icons.location_on,
            ),

            const SizedBox(height: 16),
            // View Pass History Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showPassHistory(vehicle['passId']);
                },
                icon: const Icon(Icons.history),
                label: const Text('View Pass History'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build status item
  Widget _buildStatusItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Build owner section
  Widget _buildOwnerSection(Map<String, dynamic> vehicle) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: Colors.green.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Owner Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
                'Name', vehicle['ownerFullName'] ?? 'Unknown Owner'),
            if (vehicle['ownerEmail'] != null &&
                vehicle['ownerEmail'].toString().isNotEmpty)
              _buildDetailRow('Email', vehicle['ownerEmail']),
            if (vehicle['ownerPhone'] != null &&
                vehicle['ownerPhone'].toString().isNotEmpty)
              _buildDetailRow('Phone', vehicle['ownerPhone']),
            if (vehicle['ownerAddress'] != null &&
                vehicle['ownerAddress'].toString().isNotEmpty)
              _buildDetailRow('Address', vehicle['ownerAddress']),

            const SizedBox(height: 12),
            // Owner Details Button (only show if we have a valid profileId)
            if (vehicle['profileId'] != null &&
                vehicle['profileId'].toString().isNotEmpty &&
                vehicle['profileId'].toString() != 'null')
              SizedBox(
                width: double.infinity,
                child: OwnerDetailsButton(
                  ownerId: vehicle['profileId'].toString(),
                  ownerName: vehicle['ownerFullName']?.toString(),
                  buttonText: 'View Complete Owner Details',
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  'Owner details not available',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Get vehicle status display text
  String _getVehicleStatusDisplay(String? status) {
    switch (status?.toLowerCase()) {
      case 'checked_in':
        return 'In Country';
      case 'checked_out':
        return 'Departed';
      case 'unused':
        return 'Not Arrived';
      default:
        return 'Unknown';
    }
  }

  /// Generate pass type from individual columns instead of using pass_description
  String _generatePassType(Map<String, dynamic> vehicle) {
    final entryLimit = vehicle['entryLimit'] ?? 0;
    final authorityName = vehicle['authorityName'] ?? 'Unknown Authority';
    final countryName = vehicle['countryName'] ?? 'Unknown Country';
    final entryPoint = vehicle['entryPointName'] ?? 'Any Entry';
    final exitPoint = vehicle['exitPointName'];

    String passType = '$entryLimit-Entry Pass';

    // Add route information if available
    if (exitPoint != null && exitPoint.toString().isNotEmpty) {
      passType += ' ($entryPoint → $exitPoint)';
    } else {
      passType += ' via $entryPoint';
    }

    // Add authority/country context
    passType += ' - $authorityName, $countryName';

    return passType;
  }

  /// Generate clean pass type without duplicating information shown elsewhere
  String _generateCleanPassType(Map<String, dynamic> vehicle) {
    final entryLimit = vehicle['entryLimit'] ?? 0;
    return '$entryLimit-Entry Border Pass';
  }

  /// Build route information string
  String _buildRouteInfo(Map<String, dynamic> vehicle) {
    final entryPoint = vehicle['entryPointName'] ?? 'Unknown';
    final exitPoint = vehicle['exitPointName'];
    final authorityName = vehicle['authorityName'] ?? 'Unknown Authority';
    final countryName = vehicle['countryName'] ?? 'Unknown Country';

    String route = entryPoint;
    if (exitPoint != null && exitPoint.toString().isNotEmpty) {
      route += ' → $exitPoint';
    }
    route += ' ($authorityName, $countryName)';

    return route;
  }

  /// Build pass info item (single column layout)
  Widget _buildPassInfoItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get color from color name (basic implementation)
  Color _getColorFromName(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'grey':
      case 'gray':
        return Colors.grey;
      case 'brown':
        return Colors.brown;
      case 'silver':
        return Colors.grey.shade300;
      case 'gold':
        return Colors.amber;
      case 'pink':
        return Colors.pink;
      case 'cyan':
        return Colors.cyan;
      case 'lime':
        return Colors.lime;
      case 'indigo':
        return Colors.indigo;
      case 'teal':
        return Colors.teal;
      default:
        return Colors.grey.shade400;
    }
  }

  /// Format date of birth for display
  String _formatDateOfBirth(String dateOfBirth) {
    try {
      final date = DateTime.parse(dateOfBirth);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateOfBirth; // Return as-is if parsing fails
    }
  }
}
