import 'package:flutter/material.dart';
import '../models/audit_log.dart';
import '../services/audit_service.dart';

/// Screen for viewing audit logs (Country Admins and Country Auditors)
class AuditManagementScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedCountry;

  const AuditManagementScreen({super.key, this.selectedCountry});

  @override
  State<AuditManagementScreen> createState() => _AuditManagementScreenState();
}

class _AuditManagementScreenState extends State<AuditManagementScreen> {
  bool _isLoading = true;
  bool _isLoadingLogs = false;
  bool _isLoadingMore = false;
  List<AuditLog> _auditLogs = [];
  List<Map<String, dynamic>> _auditableCountries = [];
  Map<String, dynamic>? _selectedCountry;
  String? _selectedAction;
  List<String> _availableActions = [];

  // Pagination
  int _currentPage = 0;
  final int _pageSize = 50;
  int _totalCount = 0;
  bool _hasMore = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String? _searchQuery;
  bool _showAdvancedSearch = false;
  final TextEditingController _jsonPathController = TextEditingController();
  final TextEditingController _jsonValueController = TextEditingController();
  String _jsonOperator = '=';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _checkPermissionsAndLoadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _jsonPathController.dispose();
    _jsonValueController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore) {
        _loadMoreLogs();
      }
    }
  }

  Future<void> _checkPermissionsAndLoadData() async {
    try {
      debugPrint('🔍 Checking audit permissions...');

      // Check if user can view audit logs
      final canView = await AuditService.canViewAuditLogs();
      debugPrint('🔍 Can view audit logs: $canView');

      if (!canView) {
        debugPrint('❌ Access denied for audit logs');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Access denied. Country admin or auditor role required.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      debugPrint('✅ Loading auditable countries...');
      await _loadAuditableCountries();
      await _loadAvailableActions();

      // Auto-select country (use passed country if available and valid, otherwise first)
      if (_auditableCountries.isNotEmpty) {
        if (widget.selectedCountry != null) {
          // Find the matching country object from the loaded countries list
          final matchingCountry = _auditableCountries.firstWhere(
            (c) => c['id'] == widget.selectedCountry!['id'],
            orElse: () => _auditableCountries.first,
          );
          _selectedCountry = matchingCountry;
        } else {
          _selectedCountry = _auditableCountries.first;
        }
        await _loadAuditLogs();
      }
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAuditableCountries() async {
    try {
      debugPrint('🔍 Calling AuditService.getAuditableCountries()...');
      final countries = await AuditService.getAuditableCountries();
      debugPrint(
          '✅ Got ${countries.length} auditable countries: ${countries.map((c) => c['name']).join(', ')}');

      if (mounted) {
        setState(() {
          _auditableCountries = countries;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading auditable countries: $e');
    }
  }

  Future<void> _loadAvailableActions() async {
    try {
      final actions = await AuditService.getAvailableActions();
      if (mounted) {
        setState(() {
          _availableActions = actions;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading available actions: $e');
    }
  }

  Future<void> _loadAuditLogs({bool reset = true}) async {
    if (_selectedCountry == null) return;

    if (reset) {
      setState(() {
        _isLoadingLogs = true;
        _currentPage = 0;
        _auditLogs.clear();
      });
    }

    try {
      final countryId = _selectedCountry!['id'] as String == 'global'
          ? null
          : _selectedCountry!['id'] as String;

      debugPrint('🔍 Loading audit logs for country ID: $countryId');
      debugPrint('🔍 Selected country: ${_selectedCountry!['name']}');

      AuditLogsResponse response;

      if (_showAdvancedSearch &&
          (_jsonPathController.text.isNotEmpty ||
              _dateFrom != null ||
              _dateTo != null)) {
        response = await AuditService.searchAuditLogsAdvanced(
          jsonbPath: _jsonPathController.text.isEmpty
              ? null
              : _jsonPathController.text,
          jsonbValue: _jsonValueController.text.isEmpty
              ? null
              : _jsonValueController.text,
          jsonbOperator: _jsonOperator,
          countryId: countryId,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
          limit: _pageSize,
          offset: _currentPage * _pageSize,
        );
      } else {
        Map<String, dynamic>? searchMetadata;
        if (_searchQuery != null && _searchQuery!.isNotEmpty) {
          // Simple search - look for the query in common metadata fields
          searchMetadata = {};
        }

        // Try paginated first, fall back to basic function if needed
        if (reset &&
            countryId != null &&
            _selectedAction == null &&
            searchMetadata == null) {
          // For initial load with no filters, try the basic function first
          try {
            final basicLogs =
                await AuditService.getAuditLogsByCountry(countryId);
            response = AuditLogsResponse(
              logs: basicLogs.take(_pageSize).toList(),
              totalCount: basicLogs.length,
              hasMore: basicLogs.length > _pageSize,
            );
            debugPrint('✅ Used basic function, got ${basicLogs.length} logs');
          } catch (e) {
            debugPrint('⚠️ Basic function failed, trying paginated: $e');
            response = await AuditService.getAuditLogsPaginated(
              countryId: countryId,
              searchAction: _selectedAction,
              searchMetadata: searchMetadata,
              limit: _pageSize,
              offset: _currentPage * _pageSize,
            );
          }
        } else {
          response = await AuditService.getAuditLogsPaginated(
            countryId: countryId,
            searchAction: _selectedAction,
            searchMetadata: searchMetadata,
            limit: _pageSize,
            offset: _currentPage * _pageSize,
          );
        }
      }

      if (mounted) {
        setState(() {
          if (reset) {
            _auditLogs = response.logs;
          } else {
            _auditLogs.addAll(response.logs);
          }
          _totalCount = response.totalCount;
          _hasMore = response.hasMore;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading audit logs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audit logs: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLogs = false;
        });
      }
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    try {
      await _loadAuditLogs(reset: false);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onActionFilterChanged(String? action) {
    if (action != _selectedAction) {
      setState(() {
        _selectedAction = action;
      });
      _loadAuditLogs();
    }
  }

  Widget _buildFilters() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              // First row: Country and total count
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey.shade50,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.public,
                              size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedCountry != null
                                  ? '${_selectedCountry!['name']} (${_selectedCountry!['country_code']})'
                                  : 'No country selected',
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Total: $_totalCount',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Second row: Action filter and buttons
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedAction,
                      decoration: const InputDecoration(
                        labelText: 'Action Filter',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        isDense: true,
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Actions',
                              style: TextStyle(fontSize: 12)),
                        ),
                        ..._availableActions.map((action) {
                          return DropdownMenuItem<String>(
                            value: action,
                            child: Text(
                              action.replaceAll('_', ' ').toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }),
                      ],
                      onChanged: _onActionFilterChanged,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Advanced Search Toggle
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                        color:
                            _showAdvancedSearch ? Colors.orange.shade50 : null,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _showAdvancedSearch = !_showAdvancedSearch;
                          });
                        },
                        icon: Icon(
                          _showAdvancedSearch ? Icons.search_off : Icons.search,
                          color: _showAdvancedSearch
                              ? Colors.orange.shade700
                              : Colors.grey.shade600,
                          size: 18,
                        ),
                        tooltip: 'Advanced Search',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Refresh Button
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: _isLoadingLogs
                            ? null
                            : () {
                                _loadAuditLogs();
                              },
                        icon: _isLoadingLogs
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : Icon(Icons.refresh,
                                color: Colors.grey.shade600, size: 18),
                        tooltip: 'Refresh',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_showAdvancedSearch) _buildAdvancedSearchPanel(),
      ],
    );
  }

  Widget _buildAdvancedSearchPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced Search',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          // First row: JSON Path and Operator
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _jsonPathController,
                  decoration: const InputDecoration(
                    labelText: 'JSON Path',
                    border: OutlineInputBorder(),
                    hintText: 'role_name, country_name, etc.',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: _jsonOperator,
                  decoration: const InputDecoration(
                    labelText: 'Operator',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: '=', child: Text('=')),
                    DropdownMenuItem(value: '!=', child: Text('!=')),
                    DropdownMenuItem(value: 'like', child: Text('LIKE')),
                    DropdownMenuItem(value: 'exists', child: Text('EXISTS')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _jsonOperator = value ?? '=';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second row: Value
          TextField(
            controller: _jsonValueController,
            decoration: const InputDecoration(
              labelText: 'Search Value',
              border: OutlineInputBorder(),
              hintText: 'Enter search value',
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          // Date selection row
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateFrom ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _dateFrom = date;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'From Date',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(
                      _dateFrom != null
                          ? '${_dateFrom!.day}/${_dateFrom!.month}/${_dateFrom!.year}'
                          : 'Select date',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateTo ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _dateTo = date;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'To Date',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(
                      _dateTo != null
                          ? '${_dateTo!.day}/${_dateTo!.month}/${_dateTo!.year}'
                          : 'Select date',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _loadAuditLogs();
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _jsonPathController.clear();
                      _jsonValueController.clear();
                      _jsonOperator = '=';
                      _dateFrom = null;
                      _dateTo = null;
                    });
                    _loadAuditLogs();
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsList() {
    if (_isLoadingLogs && _auditLogs.isEmpty) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_auditLogs.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No audit logs found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedAction != null || _showAdvancedSearch
                    ? 'Try adjusting your search filters'
                    : 'No audit activity recorded yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _auditLogs.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _auditLogs.length) {
            // Loading indicator for pagination
            return Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink(),
            );
          }

          final log = _auditLogs[index];
          return _buildAuditLogCard(log);
        },
      ),
    );
  }

  Widget _buildAuditLogCard(AuditLog log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showAuditLogDetails(log),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getActionIcon(log.action),
                    color: _getActionColor(log.action),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      log.actionDescription,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Text(
                    _formatDateTime(log.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Actor and Target info - use flexible layout
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Actor: ${log.actorDescription}',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (log.targetProfileId != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Target: ${log.targetDescription}',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (log.metadata != null && log.metadata!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Details: ${_formatMetadata(log.metadata!)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Tap for more',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.blue[600],
                              fontSize: 11,
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

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'role_assigned':
      case 'role_updated':
        return Icons.person_add;
      case 'role_removed':
        return Icons.person_remove;
      case 'profile_status_changed':
        return Icons.toggle_on;
      case 'border_created':
        return Icons.add_location;
      case 'border_updated':
        return Icons.edit_location;
      case 'border_deleted':
        return Icons.delete_forever;
      case 'border_status_changed':
        return Icons.toggle_off;
      case 'country_created':
      case 'country_updated':
        return Icons.flag;
      case 'country_deleted':
        return Icons.flag_outlined;
      case 'border_type_created':
      case 'border_type_updated':
        return Icons.category;
      case 'border_type_deleted':
        return Icons.category_outlined;
      default:
        return Icons.history;
    }
  }

  Color _getActionColor(String action) {
    if (action.contains('created') || action.contains('assigned')) {
      return Colors.green;
    } else if (action.contains('deleted') || action.contains('removed')) {
      return Colors.red;
    } else if (action.contains('updated') ||
        action.contains('status_changed')) {
      return Colors.orange;
    }
    return Colors.blue;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showAuditLogDetails(AuditLog log) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _getActionColor(log.action).withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getActionIcon(log.action),
                        color: _getActionColor(log.action),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Audit Log Details',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              _formatDateTime(log.createdAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Action
                        _buildDetailRow('Action', log.actionDescription),
                        const SizedBox(height: 16),

                        // Actor
                        _buildDetailRow('Actor', log.actorDescription),
                        const SizedBox(height: 16),

                        // Target (if exists)
                        if (log.targetProfileId != null) ...[
                          _buildDetailRow('Target', log.targetDescription),
                          const SizedBox(height: 16),
                        ],

                        // IDs section
                        Text(
                          'Technical Details',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Log ID', log.id),
                        _buildDetailRow('Actor ID', log.actorProfileId),
                        if (log.targetProfileId != null)
                          _buildDetailRow('Target ID', log.targetProfileId!),
                        _buildDetailRow('Raw Action', log.action),

                        // Metadata section
                        if (log.metadata != null &&
                            log.metadata!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Metadata',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: SelectableText(
                              _formatMetadataForDisplay(log.metadata!),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  String _formatMetadataForDisplay(Map<String, dynamic> metadata) {
    final buffer = StringBuffer();
    metadata.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    return buffer.toString().trim();
  }

  String _formatMetadata(Map<String, dynamic> metadata) {
    final relevant = <String>[];

    if (metadata['role_name'] != null) {
      relevant.add('Role: ${metadata['role_name']}');
    }
    if (metadata['country_name'] != null) {
      relevant.add('Country: ${metadata['country_name']}');
    }
    if (metadata['border_name'] != null) {
      relevant.add('Border: ${metadata['border_name']}');
    }
    if (metadata['border_type_name'] != null) {
      relevant.add('Type: ${metadata['border_type_name']}');
    }
    if (metadata['new_status'] != null) {
      relevant.add('Status: ${metadata['new_status']}');
    }

    return relevant.isNotEmpty ? relevant.join(', ') : 'No additional details';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Audit Logs'),
          backgroundColor: Colors.orange.shade100,
          foregroundColor: Colors.orange.shade800,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_auditableCountries.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Audit Logs'),
          backgroundColor: Colors.orange.shade100,
          foregroundColor: Colors.orange.shade800,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.security,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No Countries Assigned',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need to be assigned as a country admin or auditor\nto view audit logs.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        backgroundColor: Colors.orange.shade100,
        foregroundColor: Colors.orange.shade800,
        actions: [
          IconButton(
            onPressed: () {
              _loadAuditLogs();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh All Data',
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          _buildFilters(),
          const SizedBox(height: 16),
          const Divider(height: 1),
          _buildAuditLogsList(),
        ],
      ),
    );
  }
}
