import 'package:flutter/material.dart';
import '../../models/authority.dart';
import '../../services/business_intelligence_service.dart';
import 'overstayed_vehicles_screen.dart';

/// Pass Analytics Screen
/// Shows detailed pass analytics including non-compliance detection
class PassAnalyticsScreen extends StatefulWidget {
  final Authority authority;

  const PassAnalyticsScreen({
    super.key,
    required this.authority,
  });

  @override
  State<PassAnalyticsScreen> createState() => _PassAnalyticsScreenState();
}

class _PassAnalyticsScreenState extends State<PassAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;
  Map<String, dynamic> _analyticsData = {};
  String _selectedPeriod = 'all_time';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _selectedBorder = 'any_border';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load real analytics data from BI service
      final data = await BusinessIntelligenceService.getPassAnalyticsData(
          widget.authority.id,
          period: _selectedPeriod,
          customStartDate: _customStartDate,
          customEndDate: _customEndDate,
          borderFilter: _selectedBorder);

      if (mounted) {
        setState(() {
          _analyticsData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading analytics data: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showMetricDescription(String title, String description) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue.shade600,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            description,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Got it',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
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
                    color: Colors.blue.shade800,
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
        color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blue.shade800 : Colors.black87,
        ),
      ),
      subtitle: Text(
        description,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
        ),
      ),
      onTap: () async {
        if (value == 'custom') {
          Navigator.pop(context);
          await _showCustomDateRangePicker();
        } else {
          setState(() {
            _selectedPeriod = value;
            _customStartDate = null;
            _customEndDate = null;
          });
          Navigator.pop(context);
          _loadAnalyticsData(); // Reload data with new period
        }
      },
    );
  }

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
    // For analytics, keep the simple format for date ranges
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showStatisticExplanation(String title, String explanation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.analytics,
                color: Colors.blue.shade600,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              explanation,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Got it',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getPassDurationExplanation() {
    final quickStats = _analyticsData['quickStats'] as Map<String, dynamic>?;
    final borderText = _getBorderFilterText(quickStats?['borderFilter']);
    final periodText = _getPeriodText(quickStats?['period']);
    final passCount = quickStats?['passCount'] ?? 0;

    return '''How this is calculated:
• Takes the difference between pass expiration date and activation date for each pass
• Averages across all passes in the selected criteria
• Formula: Average of (expiresAt - activationDate) for all passes

Current filters:
• Border: $borderText
• Time Period: $periodText
• Passes analyzed: $passCount

This metric helps you understand:
• How long passes are typically valid for
• Whether customers prefer shorter or longer duration passes
• Pricing strategy effectiveness for different validity periods''';
  }

  String _getPeakUsageDayExplanation() {
    final quickStats = _analyticsData['quickStats'] as Map<String, dynamic>?;
    final borderText = _getBorderFilterText(quickStats?['borderFilter']);
    final periodText = _getPeriodText(quickStats?['period']);
    final passCount = quickStats?['passCount'] ?? 0;

    return '''How this is calculated:
• Groups all passes by the day of the week they were purchased (issuedAt date)
• Counts how many passes were bought on each day (Monday through Sunday)
• Identifies the day with the highest number of purchases

Current filters:
• Border: $borderText
• Time Period: $periodText
• Passes analyzed: $passCount

This metric helps you understand:
• When customers are most likely to purchase passes
• Optimal staffing and system capacity planning
• Best timing for marketing campaigns and promotions
• Customer behavior patterns throughout the week''';
  }

  String _getProcessingTimeExplanation() {
    final quickStats = _analyticsData['quickStats'] as Map<String, dynamic>?;
    final borderText = _getBorderFilterText(quickStats?['borderFilter']);
    final periodText = _getPeriodText(quickStats?['period']);
    final passCount = quickStats?['passCount'] ?? 0;

    return '''How this is calculated:
• Measures the time between pass purchase (issuedAt) and when it becomes active (activationDate)
• Averages across all passes in the selected criteria
• Formula: Average of |activationDate - issuedAt| for all passes

Current filters:
• Border: $borderText
• Time Period: $periodText
• Passes analyzed: $passCount

This metric helps you understand:
• System efficiency and performance
• User experience quality
• Processing bottlenecks or delays
• Whether passes are activated immediately or scheduled for later''';
  }

  String _getBorderFilterText(String? borderFilter) {
    if (borderFilter == 'any_border') return 'Any Border';
    final availableBorders =
        (_analyticsData['availableBorders'] as List<dynamic>?) ?? [];
    final border = availableBorders.firstWhere(
      (b) => b['id'] == borderFilter,
      orElse: () => {'name': 'Any Border'},
    );
    return border['name'] ?? 'Any Border';
  }

  String _getPeriodText(String? period) {
    switch (period) {
      case 'current_month':
        return 'Current Month';
      case 'last_month':
        return 'Last Month';
      case 'last_3_months':
        return 'Last 3 Months';
      case 'last_6_months':
        return 'Last 6 Months';
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          return '${_formatDate(_customStartDate!)} - ${_formatDate(_customEndDate!)}';
        }
        return 'Custom Range';
      default:
        return 'All Time';
    }
  }

  String _getTotalPassesExplanation() {
    final totalPasses = _analyticsData['totalPasses'] ?? 0;
    final borderText = _getBorderFilterText(_selectedBorder);
    final periodText = _getPeriodDisplayText();

    return '''What this shows:
• Total number of passes issued by this authority
• Includes all pass statuses: active, expired, consumed, pending
• Represents the complete volume of pass transactions

Current filters:
• Border: $borderText
• Time Period: $periodText
• Total count: $totalPasses passes

How it's calculated:
• Counts all records in the purchased_passes table
• Filters by authority_id, selected border, and time period
• No status restrictions - includes all passes regardless of current state

Business insights:
• Overall demand for border passes
• Authority performance and market reach
• Seasonal trends and growth patterns
• Revenue potential and market size''';
  }

  String _getActivePassesExplanation() {
    final activePasses = _analyticsData['activePasses'] ?? 0;
    final totalPasses = _analyticsData['totalPasses'] ?? 1;
    final percentage = ((activePasses / totalPasses) * 100).toStringAsFixed(1);
    final borderText = _getBorderFilterText(_selectedBorder);
    final periodText = _getPeriodDisplayText();

    return '''What this shows:
• Passes that are currently valid and can be used
• Represents active revenue-generating passes
• Shows current operational capacity

Current filters:
• Border: $borderText
• Time Period: $periodText
• Active count: $activePasses passes ($percentage% of total)

How it's calculated:
• Pass status = 'active'
• Pass has not expired (expiresAt > current date)
• Pass is activated (activationDate ≤ current date)
• Pass has remaining entries (entriesRemaining > 0)

Business insights:
• Current service utilization
• Revenue stream health
• Customer satisfaction (active usage)
• System capacity and demand''';
  }

  String _getExpiredPassesExplanation() {
    final expiredPasses = _analyticsData['expiredPasses'] ?? 0;
    final totalPasses = _analyticsData['totalPasses'] ?? 1;
    final percentage = ((expiredPasses / totalPasses) * 100).toStringAsFixed(1);
    final borderText = _getBorderFilterText(_selectedBorder);
    final periodText = _getPeriodDisplayText();

    return '''What this shows:
• Passes that have exceeded their validity period
• Natural lifecycle completion of pass services
• Historical usage patterns

Current filters:
• Border: $borderText
• Time Period: $periodText
• Expired count: $expiredPasses passes ($percentage% of total)

How it's calculated:
• Pass expiration date (expiresAt) is before current date
• Includes both compliant and non-compliant expired passes
• Based on calendar date comparison, not usage status

Business insights:
• Pass lifecycle completion rates
• Customer renewal opportunities
• Historical demand patterns
• Service delivery effectiveness''';
  }

  String _getComplianceRateExplanation() {
    final complianceRate =
        (_analyticsData['complianceRate'] ?? 0.0).toStringAsFixed(1);
    final expiredButActive = _analyticsData['expiredButActive'] ?? 0;
    final totalPasses = _analyticsData['totalPasses'] ?? 1;
    final borderText = _getBorderFilterText(_selectedBorder);
    final periodText = _getPeriodDisplayText();

    return '''What this shows:
• Percentage of passes being used correctly without violations
• Key performance indicator for border control effectiveness
• Measure of system integrity and enforcement

Current filters:
• Border: $borderText
• Time Period: $periodText
• Compliance rate: $complianceRate%
• Non-compliant passes: $expiredButActive

How it's calculated:
• Total active or expired passes = baseline
• Compliant passes = baseline - expired passes still in use
• Compliance rate = (compliant passes ÷ baseline) × 100

Non-compliance factors:
• Expired passes with vehicles still checked in
• Overstayed vehicles beyond pass validity
• Fraudulent or suspicious pass usage

Business insights:
• Border security effectiveness
• Enforcement quality and gaps
• Revenue protection success
• System integrity and trust''';
  }

  String _getExpiredButActiveExplanation() {
    final expiredButActive = _analyticsData['expiredButActive'] ?? 0;
    final borderText = _getBorderFilterText(_selectedBorder);
    final periodText = _getPeriodDisplayText();

    return '''What this detects:
• Passes that have expired but vehicles are still checked into the country
• Critical compliance violation requiring immediate attention
• Potential revenue loss and security risk

Current filters:
• Border: $borderText
• Time Period: $periodText
• Violations detected: $expiredButActive

How it's determined:
• Pass expiration date (expiresAt) < current date
• Vehicle status (currentStatus) = 'checked_in'
• Pass was issued within the selected time period

Detection logic:
1. Check if pass.isExpired = true (expiresAt has passed)
2. Verify pass.currentStatus = 'checked_in' (vehicle still in country)
3. Cross-reference with border and time filters

Why this matters:
• Vehicles using expired authorization
• Lost revenue from unpaid extensions
• Border security and compliance gaps
• Enforcement action required

Recommended actions:
• Contact vehicle owners for pass renewal
• Issue penalties or fines as per policy
• Update vehicle status if departed
• Review border exit procedures''';
  }

  String _getOverstayedVehiclesExplanation() {
    final overstayedVehicles = _analyticsData['overstayedVehicles'] ?? 0;
    final borderText = _getBorderFilterText(_selectedBorder);
    final periodText = _getPeriodDisplayText();

    return '''What this detects:
• Vehicles that have exceeded their authorized stay duration
• Similar to expired passes but focuses on duration violations
• Critical for border control and immigration compliance

Current filters:
• Border: $borderText
• Time Period: $periodText
• Overstayed vehicles: $overstayedVehicles

How it's determined:
• Pass expiration date has passed
• Vehicle is still checked into the country
• Duration calculation: current date - pass expiration date

Detection criteria:
1. Pass validity period has ended (isExpired = true)
2. Vehicle status shows 'checked_in' (still in country)
3. Days overstayed = current date - expiresAt

Why this is critical:
• Immigration and customs violations
• Unauthorized presence in country
• Potential security and legal issues
• Revenue loss from extended stays

Enforcement implications:
• Legal action may be required
• Fines and penalties applicable
• Vehicle detention possible
• Border security protocols activated

Note: Currently calculated the same as "Expired Passes Still Active" - this could be enhanced to show additional duration-based metrics.''';
  }

  String _getFraudAlertsExplanation() {
    final fraudAlerts = _analyticsData['fraudAlerts'] ?? 0;
    final borderText = _getBorderFilterText(_selectedBorder);
    final periodText = _getPeriodDisplayText();

    return '''What this detects:
• Suspicious patterns or anomalies in pass usage
• Potential fraudulent activities or system abuse
• Data inconsistencies requiring investigation

Current filters:
• Border: $borderText
• Time Period: $periodText
• Fraud alerts: $fraudAlerts

Detection methods (planned):
• Duplicate pass usage across multiple borders
• Impossible travel times between checkpoints
• Mismatched vehicle information
• Unusual payment patterns
• Suspicious user behavior

Potential fraud indicators:
• Same vehicle using multiple active passes
• Pass used at different borders simultaneously
• Vehicle details don't match registration
• Rapid succession of pass purchases
• Unusual entry/exit patterns

Current status:
• Fraud detection is currently a placeholder (returns 0)
• Advanced fraud detection algorithms are planned
• Will integrate with AI/ML pattern recognition
• Real-time monitoring capabilities planned

Future enhancements:
• Machine learning fraud detection
• Real-time alert system
• Integration with law enforcement databases
• Automated suspicious activity reporting
• Risk scoring for pass applications

Note: This feature is under development and currently shows 0 alerts.''';
  }

  String _getBorderDisplayText() {
    if (_selectedBorder == 'any_border') {
      return 'Any Border';
    }
    // Find the border name from analytics data
    final availableBorders =
        (_analyticsData['availableBorders'] as List<dynamic>?) ?? [];
    final border = availableBorders.firstWhere(
      (b) => b['id'] == _selectedBorder,
      orElse: () => {'name': 'Any Border'},
    );
    return border['name'] ?? 'Any Border';
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
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                _buildBorderOption(
                    'any_border', 'Any Border', 'Show passes from all borders'),
                ...availableBorders.map((border) => _buildBorderOption(
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
        color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blue.shade800 : Colors.black87,
        ),
      ),
      subtitle: Text(
        description,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
        ),
      ),
      onTap: () {
        setState(() {
          _selectedBorder = value;
        });
        Navigator.pop(context);
        _loadAnalyticsData(); // Reload data with new border filter
      },
    );
  }

  Widget _buildTopPassItem(int rank, Map<String, dynamic> pass) {
    final passDescription = pass['passDescription'] ?? 'Unknown Pass';
    final borderName = pass['borderName'] ?? 'Any Border';
    final count = pass['count'] ?? 0;
    final amount = pass['amount'] ?? 0.0;
    final currency = pass['currency'] ?? 'USD';
    final entryLimit = pass['entryLimit'] ?? 0;
    final validityDays = pass['validityDays'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rank <= 3 ? Colors.amber.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: rank <= 3 ? Colors.amber.shade300 : Colors.grey.shade300,
              ),
            ),
            child: Center(
              child: Text(
                rank.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color:
                      rank <= 3 ? Colors.amber.shade700 : Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Pass details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Border name (if not "Any Border")
                if (_selectedBorder == 'any_border') ...[
                  Text(
                    borderName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],

                // Pass description in the format: "5 entries • 30 days"
                Text(
                  '$entryLimit entries • $validityDays days',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Count and price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$currency ${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count issued',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade600,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = 'custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _loadAnalyticsData(); // Reload data with custom range
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pass Analytics'),
        backgroundColor: Colors.blue.shade100,
        foregroundColor: Colors.blue.shade800,
        actions: [
          IconButton(
            onPressed: _loadAnalyticsData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade800,
          unselectedLabelColor: Colors.blue.shade400,
          indicatorColor: Colors.blue.shade600,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.analytics, size: 20)),
            Tab(text: 'Non-Compliance', icon: Icon(Icons.warning, size: 20)),
            Tab(text: 'Trends', icon: Icon(Icons.trending_up, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Authority header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(
                  color: Colors.blue.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.analytics,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.authority.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Pass Analytics • ${widget.authority.countryName ?? 'Unknown Country'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: SafeArea(
              top: false, // Don't add safe area at top since we have the header
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Colors.red.shade700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadAnalyticsData,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOverviewTab(),
                            _buildNonComplianceTab(),
                            _buildTrendsTab(),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Key Metrics
            _buildOverviewMetrics(),
            const SizedBox(height: 24),

            // Top Passes by Entry and Exit Points
            _buildTopPassesByEntryAndExit(),
            const SizedBox(height: 24),

            // Quick Stats
            _buildQuickStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildNonComplianceTab() {
    return RefreshIndicator(
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

            // Revenue at Risk (with authority currency)
            _buildRevenueAtRisk(),
            const SizedBox(height: 24),

            // Top 5 Borders Analysis
            _buildTop5BordersAnalysis(),
            const SizedBox(height: 24),

            // Detailed Non-Compliant Passes List
            _buildNonCompliantPassesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsTab() {
    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Trends',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 16),

            // Placeholder for charts
            Card(
              child: Container(
                height: 200,
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.show_chart,
                        size: 48,
                        color: Colors.blue.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Charts Coming Soon',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pass trends and analytics charts will be displayed here',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pass Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            GestureDetector(
              onTap: _showPeriodSelector,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getPeriodDisplayText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Show loading state if data is empty
        if (_analyticsData.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('Loading metrics...'),
            ),
          )
        else
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6, // Adjusted for better text visibility
            children: [
              _buildMetricCard(
                'Total Passes',
                (_analyticsData['totalPasses'] ?? 0).toString(),
                Icons.confirmation_number,
                Colors.blue,
                _getTotalPassesExplanation(),
              ),
              _buildMetricCard(
                'Active Passes',
                (_analyticsData['activePasses'] ?? 0).toString(),
                Icons.check_circle,
                Colors.green,
                _getActivePassesExplanation(),
              ),
              _buildMetricCard(
                'Expired Passes',
                (_analyticsData['expiredPasses'] ?? 0).toString(),
                Icons.schedule,
                Colors.orange,
                _getExpiredPassesExplanation(),
              ),
              _buildMetricCard(
                'Compliance Rate',
                '${(_analyticsData['complianceRate'] ?? 0.0).toStringAsFixed(1)}%',
                Icons.verified,
                Colors.purple,
                _getComplianceRateExplanation(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTopPassesByEntryAndExit() {
    final topEntryPasses =
        (_analyticsData['topEntryPasses'] as List<dynamic>?) ?? [];
    final topExitPasses =
        (_analyticsData['topExitPasses'] as List<dynamic>?) ?? [];
    final availableEntryBorders =
        (_analyticsData['availableEntryBorders'] as List<dynamic>?) ?? [];
    final availableExitBorders =
        (_analyticsData['availableExitBorders'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Passes by Entry and Exit Points',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Most popular pass types for ${_getPeriodDisplayText()}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (topEntryPasses.isNotEmpty) ...[
              Expanded(
                child: _buildPassTypeCard(
                  'Entry Points',
                  topEntryPasses,
                  availableEntryBorders,
                  Icons.login,
                  Colors.green,
                ),
              ),
              if (topExitPasses.isNotEmpty) const SizedBox(width: 16),
            ],
            if (topExitPasses.isNotEmpty)
              Expanded(
                child: _buildPassTypeCard(
                  'Exit Points',
                  topExitPasses,
                  availableExitBorders,
                  Icons.logout,
                  Colors.blue,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPassTypeCard(String title, List<dynamic> passes,
      List<dynamic> availableBorders, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showBorderSelector(availableBorders),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Icon(
                      Icons.filter_list,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (passes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No passes found',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              ...passes.take(5).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final pass = entry.value as Map<String, dynamic>;
                return _buildCompactPassItem(index + 1, pass, color);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPassItem(
      int rank, Map<String, dynamic> pass, Color color) {
    final passDescription = pass['passDescription'] ?? 'Unknown Pass';
    final borderName = pass['borderName'] ?? 'Unknown Border';
    final count = pass['count'] ?? 0;
    final amount = pass['amount'] ?? 0.0;
    final currency = pass['currency'] ?? 'USD';
    final entryLimit = pass['entryLimit'] ?? 0;
    final validityDays = pass['validityDays'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                rank.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Pass details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$entryLimit entries • $validityDays days',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  borderName,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Count and price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '$currency ${amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Statistics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatRowWithExplanation(
                  'Average Pass Duration',
                  (_analyticsData['quickStats']
                          as Map<String, dynamic>?)?['averagePassDuration'] ??
                      '0 days',
                  'Average Pass Duration',
                  _getPassDurationExplanation(),
                ),
                _buildStatRowWithExplanation(
                  'Peak Usage Day',
                  (_analyticsData['quickStats']
                          as Map<String, dynamic>?)?['peakUsageDay'] ??
                      'No data',
                  'Peak Usage Day',
                  _getPeakUsageDayExplanation(),
                ),
                _buildStatRowWithExplanation(
                  'Average Processing Time',
                  (_analyticsData['quickStats']
                          as Map<String, dynamic>?)?['averageProcessingTime'] ??
                      '0 minutes',
                  'Average Processing Time',
                  _getProcessingTimeExplanation(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNonComplianceBanner() {
    final nonCompliantCount = (_analyticsData['overstayedVehicles'] ?? 0) +
        (_analyticsData['fraudAlerts'] ?? 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
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
                  '$nonCompliantCount violations detected requiring immediate attention',
                  style: TextStyle(
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
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 16),
        _buildNonComplianceCardWithExplanation(
          'Overstayed Vehicles',
          _analyticsData['overstayedVehicles'].toString(),
          'Vehicles that have exceeded their pass validity period',
          Icons.timer_off,
          Colors.red,
          _getOverstayedVehiclesExplanation(),
          onTap: () => _showOverstayedVehiclesDetails(),
        ),
        const SizedBox(height: 12),
        _buildNonComplianceCardWithExplanation(
          'Fraud Alerts',
          _analyticsData['fraudAlerts'].toString(),
          'Suspicious patterns or mismatched data detected',
          Icons.security,
          Colors.purple,
          _getFraudAlertsExplanation(),
        ),
      ],
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
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.attach_money,
                    color: Colors.red.shade600,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_analyticsData['authorityCurrency'] ?? 'USD'} ${((_analyticsData['revenueAtRisk'] as double?) ?? 0.0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      Text(
                        'Potential revenue loss from non-compliant passes',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNonComplianceCard(String title, String count, String description,
      IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
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
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          count,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNonComplianceCardWithExplanation(String title, String count,
      String description, IconData icon, Color color, String explanation,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? (() => _showStatisticExplanation(title, explanation)),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            count,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon,
      Color color, String description) {
    return GestureDetector(
      onTap: () => _showMetricDescription(title, description),
      child: Card(
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row with icon and info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 20),
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey.shade400,
                    size: 14,
                  ),
                ],
              ),

              // Spacer
              const Spacer(),

              // Value text
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),

              const SizedBox(height: 4),

              // Title text
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRowWithExplanation(
      String label, String value, String title, String explanation) {
    return GestureDetector(
      onTap: () => _showStatisticExplanation(title, explanation),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Navigate to detailed overstayed vehicles screen
  void _showOverstayedVehiclesDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OverstayedVehiclesScreen(
          authority: widget.authority,
          period: _selectedPeriod,
          customStartDate: _customStartDate,
          customEndDate: _customEndDate,
          borderFilter: _selectedBorder,
        ),
      ),
    );
  }

  /// Build time period and border filters for Non-Compliance tab
  Widget _buildNonComplianceFilters() {
    final availableBorders =
        (_analyticsData['availableBorders'] as List<dynamic>?) ?? [];

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _showPeriodSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range,
                    size: 20,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getPeriodDisplayText(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colors.blue.shade700,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _showBorderSelector(availableBorders),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 20,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getBorderDisplayText(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colors.blue.shade700,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build detailed list of non-compliant passes
  Widget _buildNonCompliantPassesList() {
    final nonCompliantPasses =
        (_analyticsData['nonCompliantPasses'] as List<dynamic>?) ?? [];

    if (nonCompliantPasses.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Non-Compliant Passes Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 48,
                      color: Colors.green.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Non-Compliant Passes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All passes in the selected period are compliant',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Non-Compliant Passes Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${nonCompliantPasses.length} violations found in ${_getPeriodDisplayText()}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Critical Violations Requiring Action',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              // List of non-compliant passes
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: nonCompliantPasses.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                itemBuilder: (context, index) {
                  final pass =
                      nonCompliantPasses[index] as Map<String, dynamic>;
                  return _buildNonCompliantPassItem(pass);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build top 5 borders analysis for non-compliance
  Widget _buildTop5BordersAnalysis() {
    final top5EntryBorders =
        (_analyticsData['top5EntryBorders'] as List<dynamic>?) ?? [];
    final top5ExitBorders =
        (_analyticsData['top5ExitBorders'] as List<dynamic>?) ?? [];

    if (top5EntryBorders.isEmpty && top5ExitBorders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Borders for Non-Compliance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Borders with the highest number of violations in ${_getPeriodDisplayText()}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (top5EntryBorders.isNotEmpty) ...[
              Expanded(
                child: _buildBorderAnalysisCard(
                    'Entry Points', top5EntryBorders, Icons.login),
              ),
              if (top5ExitBorders.isNotEmpty) const SizedBox(width: 16),
            ],
            if (top5ExitBorders.isNotEmpty)
              Expanded(
                child: _buildBorderAnalysisCard(
                    'Exit Points', top5ExitBorders, Icons.logout),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBorderAnalysisCard(
      String title, List<dynamic> borders, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.red.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (borders.isEmpty)
              Text(
                'No violations found',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...borders.toList().asMap().entries.map((entry) {
                final index = entry.key;
                final border = entry.value as Map<String, dynamic>;
                final name = border['name'] as String;
                final count = border['count'] as int;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  /// Build individual non-compliant pass item
  Widget _buildNonCompliantPassItem(Map<String, dynamic> pass) {
    final daysOverdue = pass['daysOverdue'] as int? ?? 0;
    final amount = pass['amount'] as double? ?? 0.0;
    final currency = pass['currency'] as String? ?? 'USD';
    final vehicleReg = pass['vehicleRegistrationNumber'] as String? ?? 'N/A';
    final vehicleDesc =
        pass['vehicleDescription'] as String? ?? 'Unknown Vehicle';
    final passDesc = pass['passDescription'] as String? ?? 'Unknown Pass';
    final borderName = pass['borderName'] as String? ?? 'Unknown Border';

    Color severityColor;
    String severityText;
    if (daysOverdue <= 7) {
      severityColor = Colors.orange;
      severityText = 'Recent';
    } else if (daysOverdue <= 30) {
      severityColor = Colors.red;
      severityText = 'Critical';
    } else {
      severityColor = Colors.purple;
      severityText = 'Severe';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      'Registration: $vehicleReg',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pass: $passDesc',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Border: $borderName',
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
    );
  }
}
