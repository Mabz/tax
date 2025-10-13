import 'package:flutter/material.dart';
import '../../models/authority.dart';
import '../../services/business_intelligence_service.dart';

/// Pass Analytics Screen
/// Shows detailed pass analytics - simplified to show only overview content
class PassAnalyticsScreen extends StatefulWidget {
  final Authority authority;

  const PassAnalyticsScreen({
    super.key,
    required this.authority,
  });

  @override
  State<PassAnalyticsScreen> createState() => _PassAnalyticsScreenState();
}

class _PassAnalyticsScreenState extends State<PassAnalyticsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _analyticsData = {};
  String _selectedPeriod = 'all_time';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _selectedBorder = 'any_border';

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
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
                color: Colors.green.shade600,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.green.shade800,
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
                  color: Colors.green.shade600,
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
          color: isSelected ? Colors.green.shade800 : Colors.black87,
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
          _loadAnalyticsData();
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
        color: isSelected ? Colors.green.shade600 : Colors.grey.shade400,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.green.shade800 : Colors.black87,
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
        _loadAnalyticsData();
      },
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
              primary: Colors.green.shade600,
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
      _loadAnalyticsData();
    }
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRowWithExplanation({
    required String label,
    required String value,
    required String explanation,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showMetricDescription(label, explanation),
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  String _getTotalPassesExplanation() {
    final totalPasses = _analyticsData['totalPasses'] ?? 0;
    final borderText = _getBorderDisplayText();
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
    final borderText = _getBorderDisplayText();
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
    final borderText = _getBorderDisplayText();
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
    final borderText = _getBorderDisplayText();
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

  String _getPassDurationExplanation() {
    final quickStats = _analyticsData['quickStats'] as Map<String, dynamic>?;
    final borderText = _getBorderDisplayText();
    final periodText = _getPeriodDisplayText();
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
    final borderText = _getBorderDisplayText();
    final periodText = _getPeriodDisplayText();
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
    final borderText = _getBorderDisplayText();
    final periodText = _getPeriodDisplayText();
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

  Widget _buildTopPassItem(int rank, Map<String, dynamic> pass) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedBorder == 'any_border') ...[
                  Text(
                    borderName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
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

  Widget _buildOverviewContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade300,
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
                onPressed: _loadAnalyticsData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters section
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _showPeriodSelector,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getPeriodDisplayText(),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down,
                            color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () {
                    final availableBorders = (_analyticsData['availableBorders']
                            as List<dynamic>?) ??
                        [];
                    if (availableBorders.isNotEmpty) {
                      _showBorderSelector(availableBorders);
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getBorderDisplayText(),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down,
                            color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Key metrics grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildMetricCard(
                title: 'Total Passes',
                value: (_analyticsData['totalPasses'] ?? 0).toString(),
                icon: Icons.confirmation_number,
                color: Colors.green.shade600,
                onTap: () => _showMetricDescription(
                  'Total Passes',
                  _getTotalPassesExplanation(),
                ),
              ),
              _buildMetricCard(
                title: 'Active Passes',
                value: (_analyticsData['activePasses'] ?? 0).toString(),
                icon: Icons.check_circle,
                color: Colors.green.shade600,
                onTap: () => _showMetricDescription(
                  'Active Passes',
                  _getActivePassesExplanation(),
                ),
              ),
              _buildMetricCard(
                title: 'Expired Passes',
                value: (_analyticsData['expiredPasses'] ?? 0).toString(),
                icon: Icons.schedule,
                color: Colors.green.shade600,
                onTap: () => _showMetricDescription(
                  'Expired Passes',
                  _getExpiredPassesExplanation(),
                ),
              ),
              _buildMetricCard(
                title: 'Compliance Rate',
                value:
                    '${(_analyticsData['complianceRate'] ?? 0.0).toStringAsFixed(1)}%',
                icon: Icons.security,
                color: Colors.green.shade600,
                onTap: () => _showMetricDescription(
                  'Compliance Rate',
                  _getComplianceRateExplanation(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quick statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.speed, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Quick Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatRowWithExplanation(
                    label: 'Average Pass Duration',
                    value: (_analyticsData['quickStats']?['avgPassDuration'] ??
                            'N/A')
                        .toString(),
                    explanation: _getPassDurationExplanation(),
                  ),
                  _buildStatRowWithExplanation(
                    label: 'Peak Usage Day',
                    value:
                        (_analyticsData['quickStats']?['peakUsageDay'] ?? 'N/A')
                            .toString(),
                    explanation: _getPeakUsageDayExplanation(),
                  ),
                  _buildStatRowWithExplanation(
                    label: 'Avg Processing Time',
                    value: (_analyticsData['quickStats']
                                ?['avgProcessingTime'] ??
                            'N/A')
                        .toString(),
                    explanation: _getProcessingTimeExplanation(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Popular passes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Popular Passes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if ((_analyticsData['popularPasses'] as List<dynamic>?)
                          ?.isEmpty ??
                      true)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No pass data available for the selected period',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else
                    ...(_analyticsData['popularPasses'] as List<dynamic>)
                        .asMap()
                        .entries
                        .map((entry) => _buildTopPassItem(
                              entry.key + 1,
                              entry.value as Map<String, dynamic>,
                            )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pass Analytics'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadAnalyticsData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
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
                bottom: BorderSide(
                  color: Colors.green.shade200,
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
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.authority.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
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
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Main content - directly show overview without tabs
          Expanded(
            child: _buildOverviewContent(),
          ),
        ],
      ),
    );
  }
}
