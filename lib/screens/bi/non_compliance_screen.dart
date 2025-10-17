import 'package:flutter/material.dart';
import '../../models/authority.dart';
import '../../services/business_intelligence_service.dart';
import 'overstayed_vehicles_screen.dart';

/// Non-Compliance Analytics Screen
/// Shows detailed non-compliance detection and analysis
class NonComplianceScreen extends StatefulWidget {
  final Authority authority;

  const NonComplianceScreen({
    super.key,
    required this.authority,
  });

  @override
  State<NonComplianceScreen> createState() => _NonComplianceScreenState();
}

class _NonComplianceScreenState extends State<NonComplianceScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _analyticsData = {};
  String _selectedPeriod = 'all_time';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _selectedBorder = 'any_border';
  String _selectedEntryBorder = 'any_entry';
  String _selectedExitBorder = 'any_exit';

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final data = await BusinessIntelligenceService.getNonComplianceAnalytics(
        widget.authority.id,
        period: _selectedPeriod,
        customStartDate: _customStartDate,
        customEndDate: _customEndDate,
        borderFilter: _selectedBorder,
        entryBorderFilter: _selectedEntryBorder,
        exitBorderFilter: _selectedExitBorder,
      );

      if (mounted) {
        setState(() {
          _analyticsData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Non-Compliance Analytics'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Authority header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.green.shade200),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.authority.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Non-Compliance Analytics • ${widget.authority.countryName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SafeArea(
              top: false, // Don't add safe area at top since we have AppBar
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.green),
                          SizedBox(height: 16),
                          Text('Loading non-compliance data...'),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
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
                                'Error loading data',
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
                                style: TextStyle(color: Colors.red.shade600),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadAnalyticsData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAnalyticsData,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Time Period Filter for Non-Compliance
                                _buildNonComplianceFilters(),
                                const SizedBox(height: 16),

                                // Non-Compliance Alert Banner
                                _buildNonComplianceBanner(),
                                const SizedBox(height: 24),

                                // Non-Compliance Categories
                                _buildNonComplianceCategories(),
                                const SizedBox(height: 24),

                                // Revenue at Risk
                                _buildRevenueAtRisk(),
                                const SizedBox(height: 24),

                                // Top 5 Borders Analysis
                                _buildTop5BordersAnalysis(),
                                const SizedBox(height: 24),

                                // Removed Non-Compliant Passes List - using clickable categories instead
                              ],
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonComplianceFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filters',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 12),

        // Time Period Filter
        GestureDetector(
          onTap: _showPeriodSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.green.shade50,
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 20, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getPeriodDisplayText(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.green.shade600),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Border Filters Row
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showEntryBorderSelector(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.green.shade50,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.login, size: 20, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getEntryBorderDisplayText(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.green.shade600),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _showExitBorderSelector(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.green.shade50,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.logout,
                          size: 20, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getExitBorderDisplayText(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.green.shade600),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNonComplianceBanner() {
    final nonCompliantCount = (_analyticsData['overstayedVehicles'] ?? 0) +
        (_analyticsData['illegalVehicles'] ?? 0) +
        (_analyticsData['fraudAlerts'] ?? 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning,
            color: Colors.red.shade600,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Non-Compliance Alert',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$nonCompliantCount vehicles require immediate attention',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonComplianceCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Non-Compliance Categories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 16),
        _buildClickableNonComplianceCard(
          'Overstayed Vehicles',
          (_analyticsData['overstayedVehicles'] ?? 0).toString(),
          'Vehicles that have exceeded their pass validity period',
          Icons.schedule,
          Colors.red,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OverstayedVehiclesScreen(
                  authority: widget.authority,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildClickableNonComplianceCard(
          'Illegal Vehicles In-Country',
          (_analyticsData['illegalVehicles'] ?? 0).toString(),
          'Vehicles found in-country but showing as departed (never checked in)',
          Icons.warning,
          Colors.orange,
          () {
            _showIllegalVehiclesDetails();
          },
        ),
        const SizedBox(height: 12),
        _buildNonComplianceCard(
          'Fraud Alerts',
          (_analyticsData['fraudAlerts'] ?? 0).toString(),
          'Suspicious activities detected in the system',
          Icons.security,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildNonComplianceCard(String title, String count, String description,
      IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              count,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClickableNonComplianceCard(String title, String count,
      String description, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to view details',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                count,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueAtRisk() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue at Risk',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.attach_money,
                        color: Colors.red.shade600, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Potential Revenue Loss',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'ZAR ${(_analyticsData['revenueAtRisk'] ?? 0.0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'From non-compliant vehicles and expired passes',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTop5BordersAnalysis() {
    final top5EntryBorders =
        (_analyticsData['top5EntryBorders'] as List<dynamic>?) ?? [];
    final top5ExitBorders =
        (_analyticsData['top5ExitBorders'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Borders for Non-Compliance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 16),

        // Entry Borders
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.login, color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Top Entry Borders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Entry borders with highest non-compliance rates',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                if (top5EntryBorders.isEmpty)
                  Center(
                    child: Text(
                      'No entry border violations found',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ...top5EntryBorders.asMap().entries.map((entry) {
                    final index = entry.key;
                    final border = entry.value as Map<String, dynamic>;
                    return _buildBorderAnalysisItem(
                      index + 1,
                      border['name'] as String,
                      border['count'] as int,
                      'entry',
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Exit Borders
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.logout, color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Top Exit Borders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Exit borders with highest non-compliance rates',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                if (top5ExitBorders.isEmpty)
                  Center(
                    child: Text(
                      'No exit border violations found',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ...top5ExitBorders.asMap().entries.map((entry) {
                    final index = entry.key;
                    final border = entry.value as Map<String, dynamic>;
                    return _buildBorderAnalysisItem(
                      index + 1,
                      border['name'] as String,
                      border['count'] as int,
                      'exit',
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBorderAnalysisItem(
      int rank, String borderName, int count, String type) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rank <= 3 ? Colors.red.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: rank <= 3 ? Colors.red.shade300 : Colors.grey.shade300,
              ),
            ),
            child: Center(
              child: Text(
                rank.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Colors.red.shade700 : Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              borderName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count violations',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Removed _buildNonCompliantPassesList - using clickable categories instead

  // Helper methods
  String _getPeriodDisplayText() {
    switch (_selectedPeriod) {
      case 'current_month':
        return 'Current Month';
      case 'last_month':
        return 'Last Month';
      case 'last_3_months':
        return 'Last 3 Months';
      case 'last_6_months':
        return 'Last 6 Months';
      case 'current_year':
        return 'Current Year';
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          return '${_formatDate(_customStartDate!)} - ${_formatDate(_customEndDate!)}';
        }
        return 'Custom Range';
      default:
        return 'All Time';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getBorderDisplayText() {
    if (_selectedBorder == 'any_border') {
      return 'Any Border';
    }
    final availableBorders =
        (_analyticsData['availableBorders'] as List<dynamic>?) ?? [];
    final border = availableBorders.firstWhere(
      (b) => b['id'] == _selectedBorder,
      orElse: () => {'name': 'Any Border'},
    );
    return border['name'] ?? 'Any Border';
  }

  String _getEntryBorderDisplayText() {
    if (_selectedEntryBorder == 'any_entry') {
      return 'Any Entry';
    }
    final availableEntryBorders =
        (_analyticsData['availableEntryBorders'] as List<dynamic>?) ?? [];
    final border = availableEntryBorders.firstWhere(
      (b) => b['id'] == _selectedEntryBorder,
      orElse: () => {'name': 'Any Entry'},
    );
    return border['name'] ?? 'Any Entry';
  }

  String _getExitBorderDisplayText() {
    if (_selectedExitBorder == 'any_exit') {
      return 'Any Exit';
    }
    final availableExitBorders =
        (_analyticsData['availableExitBorders'] as List<dynamic>?) ?? [];
    final border = availableExitBorders.firstWhere(
      (b) => b['id'] == _selectedExitBorder,
      orElse: () => {'name': 'Any Exit'},
    );
    return border['name'] ?? 'Any Exit';
  }

  void _showPeriodSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Time Period',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPeriodOption(
                    'all_time', 'All Time', 'Show all passes ever issued'),
                _buildPeriodOption('current_month', 'Current Month',
                    'Show passes from this month'),
                _buildPeriodOption(
                    'last_month', 'Last Month', 'Show passes from last month'),
                _buildPeriodOption('last_3_months', 'Last 3 Months',
                    'Show passes from last 3 months'),
                _buildPeriodOption('last_6_months', 'Last 6 Months',
                    'Show passes from last 6 months'),
                const Divider(),
                _buildPeriodOption('custom', 'Custom Range',
                    'Select specific start and end dates'),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPeriodOption(String value, String title, String description) {
    final isSelected = _selectedPeriod == value;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Colors.green.shade600 : Colors.grey.shade400,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.green.shade800 : Colors.grey.shade700,
        ),
      ),
      subtitle: Text(description),
      onTap: () {
        if (value == 'custom') {
          Navigator.pop(context);
          _showCustomDateRangePicker();
        } else {
          setState(() {
            _selectedPeriod = value;
            _customStartDate = null;
            _customEndDate = null;
          });
          Navigator.pop(context);
          _loadAnalyticsData();
        }
      },
    );
  }

  void _showBorderSelector(List<dynamic> availableBorders) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Border',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                _buildBorderOption(
                    'any_border', 'Any Border', 'Show passes from all borders'),
                ...availableBorders
                    .where((border) =>
                        !_isGenericBorderName(border['name'].toString()))
                    .map((border) => _buildBorderOption(
                          border['id'].toString(),
                          border['name'].toString(),
                          'Show passes from this border only',
                        )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBorderOption(String value, String title, String description) {
    final isSelected = _selectedBorder == value;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Colors.green.shade600 : Colors.grey.shade400,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.green.shade800 : Colors.grey.shade700,
        ),
      ),
      subtitle: Text(description),
      onTap: () {
        setState(() {
          _selectedBorder = value;
        });
        Navigator.pop(context);
        _loadAnalyticsData();
      },
    );
  }

  void _showEntryBorderSelector() {
    final availableEntryBorders =
        (_analyticsData['availableEntryBorders'] as List<dynamic>?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.login, color: Colors.green.shade600, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Select Entry Border',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildEntryBorderOption('any_entry', 'Any Entry Border',
                    'Show passes from all entry borders'),
                ...availableEntryBorders
                    .where((border) =>
                        !_isGenericBorderName(border['name'].toString()))
                    .map((border) => _buildEntryBorderOption(
                          border['id'].toString(),
                          border['name'].toString(),
                          'Show passes from this entry border only',
                        )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExitBorderSelector() {
    final availableExitBorders =
        (_analyticsData['availableExitBorders'] as List<dynamic>?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.logout, color: Colors.green.shade600, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Select Exit Border',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildExitBorderOption('any_exit', 'Any Exit Border',
                    'Show passes from all exit borders'),
                ...availableExitBorders
                    .where((border) =>
                        !_isGenericBorderName(border['name'].toString()))
                    .map((border) => _buildExitBorderOption(
                          border['id'].toString(),
                          border['name'].toString(),
                          'Show passes from this exit border only',
                        )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEntryBorderOption(
      String value, String title, String description) {
    final isSelected = _selectedEntryBorder == value;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Colors.green.shade600 : Colors.grey.shade400,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.green.shade800 : Colors.grey.shade700,
        ),
      ),
      subtitle: Text(description),
      onTap: () {
        setState(() {
          _selectedEntryBorder = value;
        });
        Navigator.pop(context);
        _loadAnalyticsData();
      },
    );
  }

  Widget _buildExitBorderOption(
      String value, String title, String description) {
    final isSelected = _selectedExitBorder == value;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Colors.green.shade600 : Colors.grey.shade400,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.green.shade800 : Colors.grey.shade700,
        ),
      ),
      subtitle: Text(description),
      onTap: () {
        setState(() {
          _selectedExitBorder = value;
        });
        Navigator.pop(context);
        _loadAnalyticsData();
      },
    );
  }

  /// Check if a border name is a generic placeholder that should be filtered out
  bool _isGenericBorderName(String borderName) {
    final genericNames = [
      'Any Entry Point',
      'Any Exit Point',
      'Any Border',
      'Unknown',
      'N/A',
      'null',
    ];

    return genericNames.any(
        (generic) => borderName.toLowerCase().contains(generic.toLowerCase()));
  }

  Future<void> _showCustomDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = 'custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _loadAnalyticsData();
    }
  }

  /// Show illegal vehicles details dialog
  void _showIllegalVehiclesDetails() {
    final illegalVehicles =
        (_analyticsData['illegalVehiclesList'] as List<dynamic>?) ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Illegal Vehicles In-Country'),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: illegalVehicles.isEmpty
              ? const Center(
                  child: Text(
                    'No illegal vehicles detected.\n\nThis is good news - all vehicles found in-country have properly checked in through border control.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: illegalVehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = illegalVehicles[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade100,
                          child: Icon(
                            Icons.warning,
                            color: Colors.red.shade600,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          vehicle['vehicle_description'] ?? 'Unknown Vehicle',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Owner: ${vehicle['owner_name'] ?? 'Unknown'}'),
                            Text(
                                'Last Scan: ${vehicle['last_scan_date'] ?? 'Unknown'}'),
                            Text(
                                'Location: ${vehicle['scan_location'] ?? 'Unknown'}'),
                            if (vehicle['days_since_departure'] != null)
                              Text(
                                'Days since departure: ${vehicle['days_since_departure']}',
                                style: TextStyle(
                                  color: Colors.red.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            vehicle['risk_level'] ?? 'HIGH',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (illegalVehicles.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Navigate to detailed illegal vehicles screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Detailed illegal vehicles screen coming soon'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('View Details'),
            ),
        ],
      ),
    );
  }
}
