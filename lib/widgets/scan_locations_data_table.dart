import 'package:flutter/material.dart';
import '../services/border_officials_service_simple.dart';
import '../utils/date_utils.dart' as date_utils;

class ScanLocationsDataTable extends StatefulWidget {
  final List<ScanLocationData> scanLocations;
  final bool showOutliersOnly;
  final Function(ScanLocationData)? onLocationSelected;

  const ScanLocationsDataTable({
    super.key,
    required this.scanLocations,
    this.showOutliersOnly = false,
    this.onLocationSelected,
  });

  @override
  State<ScanLocationsDataTable> createState() => _ScanLocationsDataTableState();
}

class _ScanLocationsDataTableState extends State<ScanLocationsDataTable> {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  List<ScanLocationData> _sortedLocations = [];

  @override
  void initState() {
    super.initState();
    _updateSortedLocations();
  }

  @override
  void didUpdateWidget(ScanLocationsDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scanLocations != widget.scanLocations ||
        oldWidget.showOutliersOnly != widget.showOutliersOnly) {
      _updateSortedLocations();
    }
  }

  void _updateSortedLocations() {
    _sortedLocations = widget.showOutliersOnly
        ? widget.scanLocations.where((loc) => loc.isOutlier).toList()
        : List.from(widget.scanLocations);
    _sortData();
  }

  void _sortData() {
    _sortedLocations.sort((a, b) {
      int comparison = 0;

      switch (_sortColumnIndex) {
        case 0: // Official Name
          comparison = a.officialName.compareTo(b.officialName);
          break;
        case 1: // Scan Count
          comparison = a.scanCount.compareTo(b.scanCount);
          break;
        case 2: // Distance from Border
          final aDistance = a.distanceFromBorderKm ?? 0;
          final bDistance = b.distanceFromBorderKm ?? 0;
          comparison = aDistance.compareTo(bDistance);
          break;
        case 3: // Last Scan Time
          comparison = a.lastScanTime.compareTo(b.lastScanTime);
          break;
        case 4: // Status (Outlier)
          comparison = a.isOutlier.toString().compareTo(b.isOutlier.toString());
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sortData();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sortedLocations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.table_chart,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                widget.showOutliersOnly
                    ? 'No outlier locations found'
                    : 'No scan locations available',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.showOutliersOnly
                    ? 'All scans appear to be within expected border areas'
                    : 'No scan data available for the selected time period',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.table_chart,
                    color: Colors.indigo.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Scan Locations Data Table',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.indigo.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Text(
                    '${_sortedLocations.length} locations',
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 32,
                ),
                child: DataTable(
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  showCheckboxColumn: false,
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                  dataRowMaxHeight: 72,
                  columns: [
                    DataColumn(
                      label: const Text(
                        'Official Name',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onSort: _onSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Scan Count',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                      onSort: _onSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Distance (km)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                      onSort: _onSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Last Scan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onSort: _onSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onSort: _onSort,
                    ),
                    const DataColumn(
                      label: Text(
                        'Coordinates',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: _sortedLocations.map((location) {
                    return DataRow(
                      onSelectChanged: (selected) {
                        if (selected == true &&
                            widget.onLocationSelected != null) {
                          widget.onLocationSelected!(location);
                        }
                      },
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              // Profile image
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: location.isOutlier
                                        ? Colors.red.shade300
                                        : Colors.green.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: location.profileImageUrl != null
                                      ? Image.network(
                                          location.profileImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Icon(
                                              Icons.person,
                                              size: 16,
                                              color: Colors.grey.shade400,
                                            );
                                          },
                                        )
                                      : Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Colors.grey.shade400,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Status indicator
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: location.isOutlier
                                      ? Colors.red
                                      : Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  location.effectiveDisplayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getScanCountColor(location.scanCount)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              location.scanCount.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _getScanCountColor(location.scanCount),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (location.isOutlier)
                                Icon(
                                  Icons.warning,
                                  size: 16,
                                  color: Colors.red.shade600,
                                ),
                              const SizedBox(width: 4),
                              Text(
                                location.distanceFromBorderKm
                                        ?.toStringAsFixed(1) ??
                                    'Unknown',
                                style: TextStyle(
                                  color: location.isOutlier
                                      ? Colors.red.shade600
                                      : null,
                                  fontWeight: location.isOutlier
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                date_utils.DateUtils.getRelativeTime(
                                    location.lastScanTime),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              Text(
                                date_utils.DateUtils.formatFriendlyDateOnly(
                                    location.lastScanTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: location.isOutlier
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: location.isOutlier
                                    ? Colors.red.shade200
                                    : Colors.green.shade200,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  location.isOutlier
                                      ? Icons.security
                                      : Icons.check_circle,
                                  size: 14,
                                  color: location.isOutlier
                                      ? Colors.red.shade600
                                      : Colors.green.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  location.isOutlier ? 'Outlier' : 'Normal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: location.isOutlier
                                        ? Colors.red.shade600
                                        : Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          if (_sortedLocations.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Click on any row to view detailed location information. Red indicators show outlier locations that may require investigation.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
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

  Color _getScanCountColor(int scanCount) {
    if (scanCount >= 20) return Colors.red.shade600;
    if (scanCount >= 10) return Colors.orange.shade600;
    if (scanCount >= 5) return Colors.blue.shade600;
    return Colors.green.shade600;
  }
}
