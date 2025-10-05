import 'package:flutter/material.dart';
import '../models/pass_template.dart';
import '../models/vehicle_tax_rate.dart';
import '../models/vehicle_type.dart';
import '../models/border.dart' as border_model;
import '../models/currency.dart';
import '../services/pass_template_service.dart';
import '../services/role_service.dart';
import 'pass_template_form_screen.dart';

class PassTemplateManagementScreen extends StatefulWidget {
  final String authorityId;
  final String authorityName;

  const PassTemplateManagementScreen({
    super.key,
    required this.authorityId,
    required this.authorityName,
  });

  @override
  State<PassTemplateManagementScreen> createState() =>
      _PassTemplateManagementScreenState();
}

class _PassTemplateManagementScreenState
    extends State<PassTemplateManagementScreen> {
  List<PassTemplate> _passTemplates = [];
  List<VehicleTaxRate> _taxRates = [];
  List<VehicleType> _vehicleTypes = [];
  List<border_model.Border> _borders = [];
  List<Currency> _currencies = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadData();
  }

  Future<void> _checkPermissionsAndLoadData() async {
    try {
      // Check if user has permission (superuser or country admin)
      final isSuperuser = await RoleService.isSuperuser();
      final hasAdminRole = await RoleService.hasAdminRole();

      if (!isSuperuser && !hasAdminRole) {
        setState(() {
          _error =
              'You do not have permission to manage pass templates. Superuser or country administrator role required.';
          _isLoading = false;
        });
        return;
      }

      await _loadData();
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load all required data using authority-based methods
      final results = await Future.wait([
        PassTemplateService.getPassTemplatesForAuthority(widget.authorityId),
        PassTemplateService.getTaxRatesForAuthority(widget.authorityId),
        PassTemplateService.getVehicleTypes(),
        PassTemplateService.getBordersForAuthority(widget.authorityId),
        PassTemplateService.getActiveCurrencies(),
      ]);

      setState(() {
        _passTemplates = results[0] as List<PassTemplate>;
        _taxRates = results[1] as List<VehicleTaxRate>;
        _vehicleTypes = results[2] as List<VehicleType>;
        _borders = results[3] as List<border_model.Border>;
        _currencies = results[4] as List<Currency>;
        _isLoading = false;
      });

      debugPrint('✅ Pass template data loaded successfully:');
      debugPrint('  - Authority ID: ${widget.authorityId}');
      debugPrint('  - Authority Name: ${widget.authorityName}');
      debugPrint('  - Pass Templates: ${_passTemplates.length}');
      debugPrint('  - Tax Rates: ${_taxRates.length}');
      debugPrint('  - Vehicle Types: ${_vehicleTypes.length}');
      debugPrint('  - Borders: ${_borders.length}');
      debugPrint('  - Currencies: ${_currencies.length}');
    } catch (e) {
      debugPrint('❌ Error loading pass template data: $e');
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        (Colors.orange, Colors.orange.shade100, Colors.orange.shade800);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pass Templates'),
        backgroundColor: theme.$2,
        foregroundColor: theme.$3,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Authority header - fixed below app bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.orange.shade200),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.authorityName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        Text(
                          'Pass Templates Management',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error,
                                  size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _checkPermissionsAndLoadData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _buildTemplatesList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPassTemplateForm(),
        backgroundColor: Colors.orange.shade600,
        tooltip: 'Add Template',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTemplatesList() {
    if (_passTemplates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No pass templates found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first pass template to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _passTemplates.length,
      itemBuilder: (context, index) {
        final template = _passTemplates[index];
        return _buildTemplateCard(template);
      },
    );
  }

  Widget _buildTemplateCard(PassTemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPassTemplateForm(template: template),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with status and menu
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: template.isActive
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt,
                      color: template.isActive
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.description,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: template.isActive
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            template.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: template.isActive
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showPassTemplateForm(template: template);
                          break;
                        case 'delete':
                          _deleteTemplate(template);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Template details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildTemplateDetailRow(
                      Icons.attach_money,
                      'Tax Amount',
                      '${template.taxAmount} ${template.currencyCode}',
                    ),
                    const SizedBox(height: 8),
                    _buildTemplateDetailRow(
                      Icons.directions_car,
                      'Vehicle Type',
                      _getVehicleTypeName(template.vehicleTypeId),
                    ),
                    const SizedBox(height: 8),
                    _buildTemplateDetailRow(
                      Icons.schedule,
                      'Validity',
                      '${template.expirationDays} days',
                    ),
                    const SizedBox(height: 8),
                    _buildTemplateDetailRow(
                      Icons.calendar_today,
                      'Advance Days',
                      '${template.passAdvanceDays} days',
                    ),
                    if (template.entryLimit > 0) ...[
                      const SizedBox(height: 8),
                      _buildTemplateDetailRow(
                        Icons.numbers,
                        'Entry Limit',
                        '${template.entryLimit} entries',
                      ),
                    ],
                    if (template.entryPointName != null) ...[
                      const SizedBox(height: 8),
                      _buildTemplateDetailRow(
                        Icons.location_on,
                        'Entry Point',
                        template.entryPointName!,
                      ),
                    ],
                    if (template.exitPointName != null) ...[
                      const SizedBox(height: 8),
                      _buildTemplateDetailRow(
                        Icons.location_off,
                        'Exit Point',
                        template.exitPointName!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  String _getVehicleTypeName(String vehicleTypeId) {
    final vehicleType = _vehicleTypes.firstWhere(
      (vt) => vt.id == vehicleTypeId,
      orElse: () => VehicleType(
        id: vehicleTypeId,
        label: 'Unknown Vehicle Type',
        description: 'Vehicle type not found',
        isActive: true,
      ),
    );
    return vehicleType.label;
  }

  void _showPassTemplateForm({PassTemplate? template}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PassTemplateFormScreen(
          authorityId: widget.authorityId,
          authorityName: widget.authorityName,
          template: template,
        ),
      ),
    );

    // Refresh the list if template was saved
    if (result == true) {
      _loadData();
    }
  }

  void _deleteTemplate(PassTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text(
          'Are you sure you want to delete the template "${template.description}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              navigator.pop();
              try {
                await PassTemplateService.deletePassTemplate(template.id);
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Template deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadData(); // Refresh the list
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete template: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
