import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/purchased_pass.dart';
import '../models/pass_template.dart';
import '../models/country.dart';
import '../models/vehicle.dart';
import '../services/pass_service.dart';
import '../services/vehicle_service.dart';

class PassDashboardScreen extends StatefulWidget {
  const PassDashboardScreen({super.key});

  @override
  State<PassDashboardScreen> createState() => _PassDashboardScreenState();
}

class _PassDashboardScreenState extends State<PassDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  List<PurchasedPass> _passes = [];
  bool _isLoadingPasses = true;
  int _currentPassIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pageController = PageController();
    _loadPasses();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    PassService.unsubscribeFromPassUpdates();
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    PassService.subscribeToPassUpdates(
      onPassChanged: (pass, eventType) {
        if (mounted) {
          setState(() {
            switch (eventType) {
              case 'INSERT':
                // Add new pass to the list
                _passes.add(pass);
                // Sort passes by issued date (newest first)
                _passes.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
                break;

              case 'UPDATE':
                // Find and update existing pass
                final index =
                    _passes.indexWhere((p) => p.passId == pass.passId);
                if (index != -1) {
                  _passes[index] = pass;
                }
                break;

              case 'DELETE':
                // Remove pass from list
                _passes.removeWhere((p) => p.passId == pass.passId);
                // Reset page index if current index is out of bounds
                if (_currentPassIndex >= _passes.length && _passes.isNotEmpty) {
                  _currentPassIndex = 0;
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
                break;
            }
            _isLoadingPasses = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Realtime update error: $error'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
    );
  }

  Future<void> _loadPasses() async {
    try {
      setState(() => _isLoadingPasses = true);
      final passes = await PassService.getPassesForUser();
      setState(() {
        _passes = passes;
        _isLoadingPasses = false;
      });
    } catch (e) {
      setState(() => _isLoadingPasses = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading passes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPurchaseDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const PassPurchaseDialog(),
    );

    if (result == true) {
      _loadPasses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Passes'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Purchase Pass', icon: Icon(Icons.add_shopping_cart)),
            Tab(text: 'My Passes', icon: Icon(Icons.receipt_long)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildPurchaseTab(),
            _buildPassesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade50,
            Colors.white,
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.local_taxi,
                    size: 80,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Purchase a Border Pass',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Get instant access to border crossings with pre-paid passes for your vehicles',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showPurchaseDialog,
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Start Purchase'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildFeaturesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      {
        'icon': Icons.speed,
        'title': 'Fast Processing',
        'subtitle': 'Quick border crossings'
      },
      {
        'icon': Icons.security,
        'title': 'Secure Payment',
        'subtitle': 'Safe and encrypted transactions'
      },
      {
        'icon': Icons.access_time,
        'title': 'Valid Period',
        'subtitle': 'Passes valid for specified duration'
      },
      {
        'icon': Icons.qr_code,
        'title': 'QR Code Access',
        'subtitle': 'Easy scanning at borders'
      },
    ];

    return Column(
      children: features
          .map((feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        feature['icon'] as IconData,
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature['title'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            feature['subtitle'] as String,
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
              ))
          .toList(),
    );
  }

  Widget _buildPassesTab() {
    if (_isLoadingPasses) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_passes.isEmpty) {
      return _buildEmptyPassesState();
    }

    return RefreshIndicator(
      onRefresh: _loadPasses,
      child: Column(
        children: [
          // Pass indicator dots if multiple passes
          if (_passes.length > 1) _buildPassIndicator(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPassIndex = index;
                });
              },
              itemCount: _passes.length,
              itemBuilder: (context, index) {
                final pass = _passes[index];
                return _buildFullWidthPassCard(pass);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPassesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No passes yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Purchase your first pass to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _tabController.animateTo(0),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Purchase Pass'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _generateQrCodeForPass(PurchasedPass pass) {
    // Generate QR code data for existing passes that don't have one
    final qrData = {
      'passId': pass.passId,
      'passDescription': pass.passDescription,
      'vehicleDescription': pass.vehicleDescription,
      'borderName': pass.borderName ?? 'Any',
      'issuedAt': pass.issuedAt.toIso8601String(),
      'expiresAt': pass.expiresAt.toIso8601String(),
      'amount': pass.amount,
      'currency': pass.currency,
      'status': pass.status,
      'entries': '${pass.entriesRemaining}/${pass.entryLimit}',
    };
    return qrData.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  void _showQrCodeDialog(PurchasedPass pass) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pass QR Code',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                pass.passDescription,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: pass.qrCode ?? _generateQrCodeForPass(pass),
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // Short backup code
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      'Backup Code',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pass.displayShortCode,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Scan QR code or provide backup code for verification',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _passes.length,
          (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == _currentPassIndex
                  ? Colors.blue.shade600
                  : Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthPassCard(PurchasedPass pass) {
    final isExpired = pass.isExpired;
    final isActive = !isExpired && pass.hasEntriesRemaining;
    Color statusColor = Colors.green;
    if (isExpired) {
      statusColor = Colors.red;
    } else if (!pass.hasEntriesRemaining) {
      statusColor = Colors.orange;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // QR Code Section - Full Width
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              // Add green border for active passes
              border:
                  isActive ? Border.all(color: Colors.green, width: 3) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    // Pass Title
                    Text(
                      pass.passDescription,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // QR Code
                    GestureDetector(
                      onTap: () => _showQrCodeDialog(pass),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.grey.shade300, width: 2),
                        ),
                        child: QrImageView(
                          data: pass.qrCode ?? _generateQrCodeForPass(pass),
                          version: QrVersions.auto,
                          size: 200,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Short Code
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Backup Code',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pass.displayShortCode,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Red overlay for inactive passes
                if (!isActive)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isExpired ? 'EXPIRED' : 'NO ENTRIES',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Pass Details Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pass Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        pass.statusDisplay,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Vehicle Info
                _buildPassDetailRow(
                  Icons.directions_car,
                  'Vehicle',
                  pass.vehicleDescription,
                ),
                if (pass.borderName != null)
                  _buildPassDetailRow(
                    Icons.location_on,
                    'Border',
                    pass.borderName!,
                  ),
                _buildPassDetailRow(
                  Icons.confirmation_number,
                  'Entries',
                  '${pass.entriesRemaining}/${pass.entryLimit}',
                ),
                _buildPassDetailRow(
                  Icons.attach_money,
                  'Amount',
                  '${pass.currency} ${pass.amount.toStringAsFixed(2)}',
                ),
                _buildPassDetailRow(
                  Icons.calendar_today,
                  'Issued',
                  _formatDate(pass.issuedAt),
                ),
                _buildPassDetailRow(
                  Icons.event,
                  'Expires',
                  _formatDate(pass.expiresAt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.blue.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class PassPurchaseDialog extends StatefulWidget {
  const PassPurchaseDialog({super.key});

  @override
  State<PassPurchaseDialog> createState() => _PassPurchaseDialogState();
}

class _PassPurchaseDialogState extends State<PassPurchaseDialog> {
  int _currentStep = 0;
  List<Country> _countries = [];
  List<PassTemplate> _passTemplates = [];
  List<Vehicle> _vehicles = [];

  Country? _selectedCountry;
  PassTemplate? _selectedPassTemplate;
  Vehicle? _selectedVehicle;

  bool _isLoadingCountries = true;
  bool _isLoadingTemplates = false;
  bool _isLoadingVehicles = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadCountries(),
      _loadVehicles(),
    ]);
  }

  Future<void> _loadCountries() async {
    try {
      setState(() => _isLoadingCountries = true);
      final countries = await PassService.getActiveCountries();
      setState(() {
        _countries = countries;
        _isLoadingCountries = false;
      });
    } catch (e) {
      setState(() => _isLoadingCountries = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading countries: $e')),
        );
      }
    }
  }

  Future<void> _loadVehicles() async {
    try {
      setState(() => _isLoadingVehicles = true);
      final vehicles = await VehicleService.getVehiclesForUser();
      setState(() {
        _vehicles = vehicles;
        _isLoadingVehicles = false;
      });
    } catch (e) {
      setState(() => _isLoadingVehicles = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading vehicles: $e')),
        );
      }
    }
  }

  Future<void> _loadPassTemplates() async {
    if (_selectedCountry == null) return;

    try {
      setState(() => _isLoadingTemplates = true);
      final templates =
          await PassService.getPassTemplatesForCountry(_selectedCountry!.id);
      setState(() {
        _passTemplates = templates;
        _selectedPassTemplate = null;
        _isLoadingTemplates = false;
      });
    } catch (e) {
      setState(() => _isLoadingTemplates = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pass templates: $e')),
        );
      }
    }
  }

  Future<void> _purchasePass() async {
    if (_selectedPassTemplate == null) return;

    setState(() => _isPurchasing = true);

    try {
      await PassService.issuePassFromTemplate(
        vehicleId: _selectedVehicle?.id,
        passTemplateId: _selectedPassTemplate!.id,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pass purchased successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isPurchasing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error purchasing pass: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Stepper(
          physics: const ClampingScrollPhysics(),
          currentStep: _currentStep,
          onStepTapped: (step) {
            if (step <= _currentStep || _canNavigateToStep(step)) {
              setState(() => _currentStep = step);
            }
          },
          controlsBuilder: (context, details) {
            return Wrap(
              spacing: 8,
              children: [
                if (details.stepIndex > 0)
                  TextButton(
                    onPressed: () =>
                        setState(() => _currentStep = details.stepIndex - 1),
                    child: const Text('Back'),
                  ),
                if (details.stepIndex < 2)
                  ElevatedButton(
                    onPressed: _canProceedFromStep(details.stepIndex)
                        ? () {
                            if (details.stepIndex == 0 &&
                                _selectedCountry != null) {
                              _loadPassTemplates();
                            }
                            setState(
                                () => _currentStep = details.stepIndex + 1);
                          }
                        : null,
                    child: const Text('Next'),
                  ),
              ],
            );
          },
          steps: [
            Step(
              title: const Text('Select Country'),
              content: _buildCountrySelection(),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text('Select Pass'),
              content: _buildPassSelection(),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text('Confirm Purchase'),
              content: _buildPurchaseConfirmation(),
              isActive: _currentStep >= 2,
            ),
          ],
        ),
      ),
      actionsPadding: EdgeInsets.zero,
      actions: [
        if (_isPurchasing)
          Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  children: [
                    const LinearProgressIndicator(
                      backgroundColor: Colors.grey,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Processing purchase...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        if (_canPurchase())
          ElevatedButton(
            onPressed: _isPurchasing ? null : _purchasePass,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(_isPurchasing ? 'Purchasing...' : 'Purchase'),
          ),
        TextButton(
          onPressed:
              _isPurchasing ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildCountrySelection() {
    if (_isLoadingCountries) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_countries.isEmpty) {
      return const Text('No countries available for pass purchase.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose the country for your border pass:'),
        const SizedBox(height: 16),
        ...(_countries
            .map((country) => RadioListTile<Country>(
                  title: Text(country.name),
                  subtitle: Text(country.countryCode),
                  value: country,
                  groupValue: _selectedCountry,
                  onChanged: (value) {
                    setState(() {
                      _selectedCountry = value;
                      _selectedPassTemplate = null;
                      _passTemplates.clear();
                    });
                  },
                ))
            .toList()),
      ],
    );
  }

  Widget _buildPassSelection() {
    if (_selectedCountry == null) {
      return const Text('Please select a country first.');
    }

    if (_isLoadingTemplates) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_passTemplates.isEmpty) {
      return Text('No pass templates available for ${_selectedCountry!.name}.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose a pass for ${_selectedCountry!.name}:'),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () => _showPassSelectionDialog(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _selectedPassTemplate != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPassTemplate!.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_selectedPassTemplate!.currencyCode} ${_selectedPassTemplate!.taxAmount.toStringAsFixed(2)} • ${_selectedPassTemplate!.entryLimit} entries • ${_selectedPassTemplate!.expirationDays} days',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          )
                        : Text(
                            'Tap to select a pass template',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_selectedPassTemplate != null) ...[
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Pass Details:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_selectedPassTemplate!.borderName != null)
                    _buildDetailRow(
                        'Border', _selectedPassTemplate!.borderName!),
                  _buildDetailRow('Vehicle Type',
                      _selectedPassTemplate!.vehicleType ?? 'Any'),
                  _buildDetailRow(
                      'Entries', '${_selectedPassTemplate!.entryLimit}'),
                  _buildDetailRow('Valid for',
                      '${_selectedPassTemplate!.expirationDays} days'),
                  _buildDetailRow(
                    'Amount',
                    '${_selectedPassTemplate!.currencyCode} ${_selectedPassTemplate!.taxAmount.toStringAsFixed(2)}',
                    isAmount: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isAmount ? FontWeight.bold : FontWeight.w600,
              color: isAmount ? Colors.green.shade700 : Colors.grey.shade800,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Future<void> _showPassSelectionDialog() async {
    final result = await showDialog<PassTemplate>(
      context: context,
      builder: (context) => PassSelectionDialog(
        passTemplates: _passTemplates,
        selectedTemplate: _selectedPassTemplate,
      ),
    );

    if (result != null) {
      setState(() => _selectedPassTemplate = result);
    }
  }

  Widget _buildPurchaseConfirmation() {
    if (_isLoadingVehicles) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_vehicles.isEmpty) {
      return Column(
        children: [
          const Text('You need to register a vehicle first.'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              // Navigate to vehicle management
            },
            child: const Text('Register Vehicle'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select vehicle and confirm purchase:'),
        const SizedBox(height: 16),
        Text(
          'Vehicle (Optional):',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          'Tap to select, tap again to deselect',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        ...(_vehicles.map((vehicle) {
          final isSelected = _selectedVehicle?.id == vehicle.id;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: () => setState(() {
                // Toggle selection: deselect if already selected, select if not
                _selectedVehicle = isSelected ? null : vehicle;
              }),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.numberPlate,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isSelected
                                  ? Colors.blue.shade800
                                  : Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicle.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList()),
        if (_selectedPassTemplate != null) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Purchase Summary:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildSummaryRow('Country', _selectedCountry?.name ?? ''),
          _buildSummaryRow('Pass', _selectedPassTemplate?.description ?? ''),
          if (_selectedPassTemplate?.borderName != null)
            _buildSummaryRow('Border', _selectedPassTemplate!.borderName!),
          _buildSummaryRow(
              'Vehicle Type', _selectedPassTemplate?.vehicleType ?? ''),
          _buildSummaryRow(
              'Entries', '${_selectedPassTemplate?.entryLimit ?? 0}'),
          _buildSummaryRow('Valid for',
              '${_selectedPassTemplate?.expirationDays ?? 0} days'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Amount:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_selectedPassTemplate?.currencyCode ?? ''} ${_selectedPassTemplate?.taxAmount.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  bool _canNavigateToStep(int step) {
    switch (step) {
      case 0:
        return true;
      case 1:
        return _selectedCountry != null;
      case 2:
        return _selectedCountry != null && _selectedPassTemplate != null;
      default:
        return false;
    }
  }

  bool _canProceedFromStep(int step) {
    switch (step) {
      case 0:
        return _selectedCountry != null;
      case 1:
        return _selectedPassTemplate != null;
      case 2:
        return _canPurchase();
      default:
        return false;
    }
  }

  bool _canPurchase() {
    return _selectedCountry != null &&
        _selectedPassTemplate != null &&
        !_isPurchasing;
  }
}

class PassSelectionDialog extends StatefulWidget {
  final List<PassTemplate> passTemplates;
  final PassTemplate? selectedTemplate;

  const PassSelectionDialog({
    super.key,
    required this.passTemplates,
    this.selectedTemplate,
  });

  @override
  State<PassSelectionDialog> createState() => _PassSelectionDialogState();
}

class _PassSelectionDialogState extends State<PassSelectionDialog> {
  late List<PassTemplate> _filteredTemplates;
  final TextEditingController _searchController = TextEditingController();
  PassTemplate? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _filteredTemplates = widget.passTemplates;
    _selectedTemplate = widget.selectedTemplate;
    _searchController.addListener(_filterTemplates);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTemplates() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTemplates = widget.passTemplates.where((template) {
        return template.description.toLowerCase().contains(query) ||
            (template.borderName?.toLowerCase().contains(query) ?? false) ||
            (template.vehicleType?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Pass Template',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search passes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredTemplates.isEmpty
                  ? const Center(
                      child: Text(
                        'No pass templates found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredTemplates.length,
                      itemBuilder: (context, index) {
                        final template = _filteredTemplates[index];
                        final isSelected = _selectedTemplate?.id == template.id;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: isSelected ? 4 : 1,
                          color: isSelected ? Colors.blue.shade50 : null,
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedTemplate = template),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          template.description,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isSelected
                                                ? Colors.blue.shade800
                                                : null,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.blue.shade600,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (template.borderName != null)
                                    Text(
                                      'Border: ${template.borderName}',
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  Text(
                                    'Vehicle Type: ${template.vehicleType ?? 'Any'}',
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${template.entryLimit} entries • ${template.expirationDays} days',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        '${template.currencyCode} ${template.taxAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedTemplate != null
                      ? () => Navigator.of(context).pop(_selectedTemplate)
                      : null,
                  child: const Text('Select'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
