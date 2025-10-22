import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/purchased_pass.dart';
import '../models/pass_template.dart';
import '../models/vehicle.dart';
import '../services/pass_service.dart';
import '../services/vehicle_service.dart';
import '../services/profile_management_service.dart';
import '../enums/pass_verification_method.dart';
import '../widgets/pass_card_widget.dart';

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

    // Set up real-time subscription after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupRealtimeSubscription();
      }
    });
  }

  @override
  void dispose() {
    // Unsubscribe from real-time updates
    try {
      PassService.unsubscribeFromPassUpdates();
      debugPrint('✅ Unsubscribed from pass updates');
    } catch (e) {
      debugPrint('🔄 Error unsubscribing from pass updates: $e');
    }

    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    debugPrint('🔄 Setting up realtime subscriptions for pass updates');

    try {
      PassService.subscribeToPassUpdates(
        onPassChanged: (pass, eventType) {
          if (!mounted) return;

          debugPrint('🔄 Pass $eventType received: ${pass.passId}');
          debugPrint('🔄 Pass status: ${pass.status}');
          debugPrint('🔄 Entries remaining: ${pass.entriesRemaining}');
          debugPrint('🔄 Secure code in update: ${pass.secureCode}');

          setState(() {
            switch (eventType) {
              case 'INSERT':
                _passes.add(pass);
                _passes.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
                debugPrint('🔄 Added new pass: ${pass.passId}');

                // Show notification for new pass
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('New pass added: ${pass.passDescription}'),
                    backgroundColor: Colors.blue,
                    duration: const Duration(seconds: 3),
                  ),
                );
                break;

              case 'UPDATE':
                final index =
                    _passes.indexWhere((p) => p.passId == pass.passId);
                if (index != -1) {
                  final oldPass = _passes[index];
                  _passes[index] = pass;
                  debugPrint('🔄 Updated pass: ${pass.passId}');

                  // Check for different types of updates and show appropriate notifications
                  if (oldPass.secureCode != pass.secureCode &&
                      pass.secureCode != null) {
                    debugPrint(
                        '🔄 Secure code changed: ${oldPass.secureCode} -> ${pass.secureCode}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '🔐 Secure code updated for ${pass.passDescription}'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }

                  if (oldPass.entriesRemaining != pass.entriesRemaining) {
                    debugPrint(
                        '🔄 Entries changed: ${oldPass.entriesRemaining} -> ${pass.entriesRemaining}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '📱 Pass scanned! ${pass.entriesRemaining} entries remaining'),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }

                  if (oldPass.status != pass.status) {
                    debugPrint(
                        '🔄 Status changed: ${oldPass.status} -> ${pass.status}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('📋 Pass status updated: ${pass.status}'),
                        backgroundColor:
                            pass.status == 'active' ? Colors.green : Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } else {
                  // Pass not found in list, add it
                  _passes.add(pass);
                  _passes.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
                  debugPrint('🔄 Added missing pass: ${pass.passId}');
                }
                break;

              case 'DELETE':
                final removedPass = _passes.firstWhere(
                    (p) => p.passId == pass.passId,
                    orElse: () => pass);
                _passes.removeWhere((p) => p.passId == pass.passId);

                if (_currentPassIndex >= _passes.length && _passes.isNotEmpty) {
                  _currentPassIndex = 0;
                  _pageController.animateToPage(0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                }

                debugPrint('🔄 Removed pass: ${pass.passId}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Pass removed: ${removedPass.passDescription}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
                break;
            }
          });
        },
        onError: (error) {
          debugPrint('🔄 Realtime error: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Real-time updates error: $error'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        },
      );

      debugPrint('✅ Real-time subscription setup completed');
    } catch (e) {
      debugPrint('❌ Failed to setup realtime subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to setup real-time updates: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadPasses() async {
    try {
      setState(() => _isLoadingPasses = true);

      // Add timeout to prevent infinite loading
      final passes = await PassService.getPassesForUser().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Loading passes timed out. Please try again.');
        },
      );

      // Debug: Log the loaded passes to verify data integrity
      for (final pass in passes) {
        debugPrint('🔍 Loaded pass: ${pass.passId}');
        debugPrint('   Entry limit: ${pass.entryLimit}');
        debugPrint('   Amount: ${pass.amount}');
        debugPrint('   Currency: ${pass.currency}');
        debugPrint('   Entries display: ${pass.entriesDisplay}');
      }

      if (mounted) {
        setState(() {
          _passes = passes;
          _isLoadingPasses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPasses = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading passes: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
      // Reload passes after successful purchase
      await _loadPasses();
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
        actions: [
          IconButton(
            onPressed: _isLoadingPasses
                ? null
                : () async {
                    await _loadPasses();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🔄 Passes refreshed'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
            icon: _isLoadingPasses
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh passes',
          ),
        ],
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LinearProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading your passes...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
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
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                },
              ),
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
            onPressed: _showPurchaseDialog,
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
    try {
      // Minimal, phone-friendly QR payload for maximum scan reliability
      // Format: Simple pass ID only
      final qrData = pass.passId;

      // Validate the QR data before returning
      if (qrData.isEmpty) {
        debugPrint('⚠️ Warning: Empty pass ID, using fallback');
        return 'INVALID_PASS';
      }

      // Ensure it's a valid UUID format
      final uuidRegex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (!uuidRegex.hasMatch(qrData)) {
        debugPrint('⚠️ Warning: Invalid UUID format: $qrData');
        return 'INVALID_UUID_FORMAT';
      }

      debugPrint('🔍 Generated QR data: $qrData (${qrData.length} characters)');
      return qrData;
    } catch (e) {
      debugPrint('❌ Error generating QR code: $e');
      return 'QR_GENERATION_ERROR';
    }
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

              const SizedBox(height: 12),
              // Verification section based on preference
              FutureBuilder<PassVerificationMethod>(
                future:
                    ProfileManagementService.getPassOwnerVerificationPreference(
                        pass.passId),
                builder: (context, snapshot) {
                  final method = snapshot.data ?? PassVerificationMethod.none;
                  return _buildVerificationSection(pass, method);
                },
              ),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Builder(
                  builder: (context) {
                    try {
                      final qrData =
                          pass.qrCode ?? _generateQrCodeForPass(pass);
                      return QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      );
                    } catch (e) {
                      debugPrint('❌ QR generation error: $e');
                      return Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade600, size: 48),
                            const SizedBox(height: 8),
                            Text('QR Error',
                                style: TextStyle(color: Colors.red.shade600)),
                          ],
                        ),
                      );
                    }
                  },
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
                        fontSize: 20,
                        fontWeight: FontWeight.w900, // Extra bold for clarity
                        color: Colors.grey.shade800,
                        fontFamily:
                            'Courier', // More distinctive monospace font
                        letterSpacing: 3, // Increased spacing for clarity
                        height: 1.2, // Better line height
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

  Widget _buildVerificationSection(
      PurchasedPass pass, PassVerificationMethod method) {
    switch (method) {
      case PassVerificationMethod.secureCode:
        // Show secure code logic with enhanced status indication
        if (pass.hasValidSecureCode) {
          // Check if pass has been recently processed (checked in/out)
          final bool isRecentlyProcessed = pass.currentStatus == 'checked_in' ||
              pass.currentStatus == 'checked_out';
          final bool isCheckedIn = pass.currentStatus == 'checked_in';

          return Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isRecentlyProcessed
                      ? Colors.blue.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isRecentlyProcessed
                          ? Colors.blue.shade200
                          : Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isRecentlyProcessed) ...[
                      // Show scan status for recently processed passes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isCheckedIn ? Icons.login : Icons.logout,
                            color: Colors.blue.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCheckedIn ? 'Checked In' : 'Checked Out',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Border Verification Code',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else ...[
                      // Show normal secure code header for unused passes
                      Text(
                        'Border Verification Code',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      pass.secureCode ?? '',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isRecentlyProcessed
                            ? Colors.blue.shade900
                            : Colors.green.shade900,
                        fontFamily: 'Courier',
                        letterSpacing: 3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expires in ${pass.secureCodeMinutesRemaining} min',
                      style: TextStyle(
                        color: isRecentlyProcessed
                            ? Colors.blue.shade700
                            : Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                    if (isRecentlyProcessed) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Scanned by border official',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 12,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Show this code to the border official when asked',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        } else if (pass.hasExpiredSecureCode) {
          return Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      'Secure code expired',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ask the border official to scan the QR Code or enter the Backup Code.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        } else {
          return Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      'No secure code yet',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ask the border official to scan the QR Code or enter the Backup Code.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        }

      case PassVerificationMethod.pin:
        // Show PIN verification message
        return Column(
          children: [
            FutureBuilder<String?>(
              future:
                  ProfileManagementService.getPassOwnerStoredPin(pass.passId),
              builder: (context, snapshot) {
                final pin = snapshot.data;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Personal PIN Verification',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (pin != null && pin.isNotEmpty) ...[
                        Text(
                          'Your PIN: $pin',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.blue.shade900,
                            fontFamily: 'Courier',
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Provide this PIN to the border official when requested.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'PIN not set. Please update your profile settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        );

      case PassVerificationMethod.none:
        // Show no verification message
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'No Additional Verification',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Simply present the QR Code or Backup Code to the border official.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
    }
  }

  Widget _buildFullWidthPassCard(PurchasedPass pass) {
    // Only show secure code if the pass owner's preference is dynamic secure code
    return FutureBuilder<PassVerificationMethod>(
      future: ProfileManagementService.getPassOwnerVerificationPreference(
          pass.passId),
      builder: (context, snapshot) {
        final method = snapshot.data;
        final showSecure = method == PassVerificationMethod.secureCode;
        return PassCardWidget(
          pass: pass,
          showQrCode: true,
          showDetails: true,
          showSecureCode: showSecure,
          onQrCodeTap: () => _showQrCodeDialog(pass),
        );
      },
    );
  }
}

class PassPurchaseDialog extends StatefulWidget {
  const PassPurchaseDialog({super.key});

  @override
  State<PassPurchaseDialog> createState() => _PassPurchaseDialogState();
}

class _PassPurchaseDialogState extends State<PassPurchaseDialog> {
  int _currentStep = 0;
  List<Map<String, dynamic>> _countries = [];
  List<PassTemplate> _passTemplates = [];
  List<Vehicle> _vehicles = [];

  Map<String, dynamic>? _selectedCountry;
  PassTemplate? _selectedPassTemplate;
  Vehicle? _selectedVehicle;
  DateTime? _selectedActivationDate;

  // User-selected entry/exit points for templates that allow selection
  Map<String, dynamic>? _selectedEntryPoint;
  Map<String, dynamic>? _selectedExitPoint;
  List<Map<String, dynamic>> _availableBorders = [];

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
        // Default to first registered vehicle if available
        if (vehicles.isNotEmpty && _selectedVehicle == null) {
          _selectedVehicle = vehicles.first;
        }
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
          await PassService.getPassTemplatesForCountry(_selectedCountry!['id']);
      setState(() {
        _passTemplates = templates;
        _selectedPassTemplate = null;
        _selectedEntryPoint = null;
        _selectedExitPoint = null;
        _availableBorders = [];
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
    if (_selectedPassTemplate == null || _selectedActivationDate == null) {
      return;
    }

    // Show confirmation dialog if no vehicle is selected (but make it more positive)
    if (_selectedVehicle == null) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.directions_walk, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Text('Pedestrian/General Pass'),
            ],
          ),
          content: const Text(
            'This pass will be issued without a specific vehicle and can be used for:\n\n• Pedestrian border crossings\n• General border passes\n• Any vehicle (if allowed by the authority)\n\nProceed with purchase?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue Purchase'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) {
        return; // User cancelled, don't proceed with purchase
      }
    }

    setState(() => _isPurchasing = true);

    try {
      await PassService.issuePassFromTemplate(
        vehicleId: _selectedVehicle?.id,
        passTemplateId: _selectedPassTemplate!.id,
        activationDate: _selectedActivationDate!,
        userSelectedEntryPointId: _selectedEntryPoint?['id'],
        userSelectedExitPointId: _selectedExitPoint?['id'],
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
        // Handle specific vehicle assignment errors
        if (e.toString().contains('vehicle assignment') ||
            e.toString().contains('tuple structure')) {
          // Show a more helpful error dialog for vehicle issues
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Purchase Failed'),
              content: const Text(
                'There was an issue processing your pass purchase. This may be due to a vehicle assignment problem.\n\nPlease try:\n1. Selecting a specific vehicle\n2. Refreshing the page\n3. Contacting support if the issue persists',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navigate back to vehicle selection step
                    setState(() => _currentStep = 2);
                  },
                  child: const Text('Select Vehicle'),
                ),
              ],
            ),
          );
        } else {
          // Show regular error message for other errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error purchasing pass: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stepper Section
              Stepper(
                physics: const NeverScrollableScrollPhysics(),
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
                          onPressed: () => setState(
                              () => _currentStep = details.stepIndex - 1),
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
                                  setState(() =>
                                      _currentStep = details.stepIndex + 1);
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
                    title: const Text('Select Vehicle'),
                    content: _buildVehicleSelection(),
                    isActive: _currentStep >= 2,
                  ),
                ],
              ),

              // Activation Date and Purchase Summary Section (visible after step 2)
              if (_currentStep >= 1 && _selectedPassTemplate != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildActivationDateSection(),
                      const SizedBox(height: 16),
                      _buildPurchaseSummarySection(),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
            child: Text(_isPurchasing
                ? 'Purchasing...'
                : 'Purchase ${_selectedPassTemplate?.currencyCode ?? ''} ${_selectedPassTemplate?.taxAmount.toStringAsFixed(2) ?? '0.00'}'),
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
      return const Center(child: LinearProgressIndicator());
    }

    if (_countries.isEmpty) {
      return const Text('No countries available for pass purchase.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose the country for your border pass:'),
        const SizedBox(height: 16),
        ...(_countries.map((country) {
          final isSelected = _selectedCountry?['id'] == country['id'];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade100 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue.shade400 : Colors.transparent,
                width: 2,
              ),
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedCountry = country;
                  _selectedPassTemplate = null;
                  _passTemplates.clear();
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            country['name'] ?? 'Unknown Country',
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
                            country['country_code'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList()),
      ],
    );
  }

  Widget _buildPassSelection() {
    if (_selectedCountry == null) {
      return const Text('Please select a country first.');
    }

    if (_isLoadingTemplates) {
      return const Center(child: LinearProgressIndicator());
    }

    if (_passTemplates.isEmpty) {
      return Text(
          'No pass templates available for ${_selectedCountry!['name']}.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose a pass for ${_selectedCountry!['name']}:'),
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
                                _selectedPassTemplate!.authorityName ??
                                    'Unknown Authority',
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
                  // Entry/Exit Point display (selection now happens in dialog)
                  if (_selectedPassTemplate!.allowUserSelectableEntryPoint ||
                      _selectedPassTemplate!.allowUserSelectableExitPoint) ...[
                    // Show user-selected entry/exit points
                    _buildDetailRow(
                        'Entry Point',
                        _selectedPassTemplate!.allowUserSelectableEntryPoint
                            ? (_selectedEntryPoint?['name'] ?? 'Not selected')
                            : (_selectedPassTemplate!.entryPointName ??
                                'Any Entry Point')),
                    _buildDetailRow(
                        'Exit Point',
                        _selectedPassTemplate!.allowUserSelectableExitPoint
                            ? (_selectedExitPoint?['name'] ?? 'Not selected')
                            : (_selectedPassTemplate!.exitPointName ??
                                'Any Exit Point')),
                  ] else ...[
                    // Show fixed entry/exit points from template
                    _buildDetailRow(
                        'Entry Point',
                        _selectedPassTemplate!.entryPointName ??
                            'Any Entry Point'),
                    _buildDetailRow(
                        'Exit Point',
                        _selectedPassTemplate!.exitPointName ??
                            'Any Exit Point'),
                  ],
                  _buildDetailRow('Vehicle Type',
                      _selectedPassTemplate!.vehicleType ?? 'Any'),
                  _buildDetailRow(
                      'Entries', '${_selectedPassTemplate!.entryLimit}'),
                  _buildDetailRow('Valid for',
                      '${_selectedPassTemplate!.expirationDays} days'),
                  if (_selectedPassTemplate!.passAdvanceDays > 0)
                    _buildDetailRow('Advance Purchase',
                        '${_selectedPassTemplate!.passAdvanceDays} days required'),
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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PassSelectionDialog(
        passTemplates: _passTemplates,
        selectedTemplate: _selectedPassTemplate,
      ),
    );

    if (result != null) {
      final template = result['template'] as PassTemplate;
      final userSelectedEntryPoint =
          result['userSelectedEntryPoint'] as Map<String, dynamic>?;
      final userSelectedExitPoint =
          result['userSelectedExitPoint'] as Map<String, dynamic>?;

      setState(() {
        _selectedPassTemplate = template;
        _selectedEntryPoint = userSelectedEntryPoint;
        _selectedExitPoint = userSelectedExitPoint;
        // Set activation date to today by default
        // The date picker will show the allowed range based on advance days
        _selectedActivationDate = DateTime.now();

        // Auto-advance to step 3 (vehicle selection) when pass template is selected
        if (_currentStep == 1) {
          _currentStep = 2;
        }
      });

      // Load borders if the template allows user-selectable points (they should already be loaded from the dialog)
      if ((template.allowUserSelectableEntryPoint ||
              template.allowUserSelectableExitPoint) &&
          userSelectedEntryPoint != null &&
          userSelectedExitPoint != null) {
        // Borders are already selected, no need to load again
        setState(() {
          _availableBorders =
              []; // Clear since we already have the selected ones
        });
      }
    }
  }

  Widget _buildVehicleSelection() {
    if (_isLoadingVehicles) {
      return const Center(child: LinearProgressIndicator());
    }

    if (_vehicles.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'No Vehicle Required',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This pass can be used without a specific vehicle (e.g., for pedestrians or general border crossings).',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'If you have a vehicle you\'d like to register for future passes:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    // Navigate to vehicle management
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Register Vehicle (Optional)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a vehicle (optional) - you can also proceed without a vehicle',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),

        // "No Vehicle" option
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _selectedVehicle == null
                ? Colors.green.shade50
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _selectedVehicle == null
                  ? Colors.green.shade300
                  : Colors.grey.shade300,
              width: _selectedVehicle == null ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => setState(() {
              _selectedVehicle = null;
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
                          'Pedestrian Pass',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _selectedVehicle == null
                                ? Colors.green.shade800
                                : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedVehicle == null)
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        ),

        // Divider
        if (_vehicles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR SELECT A VEHICLE',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 8),
        ],
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
                            vehicle.displayName,
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
                            vehicle.displayRegistration != 'No Registration'
                                ? vehicle.displayRegistration
                                : (vehicle.vinNumber?.isNotEmpty == true
                                    ? 'VIN: ${vehicle.vinNumber}'
                                    : 'No registration info'),
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
      ],
    );
  }

  Widget _buildActivationDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule, color: Colors.blue.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              'Activation Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () => _selectActivationDate(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedActivationDate != null
                              ? _formatDate(_selectedActivationDate!)
                              : 'Select activation date',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
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
      ],
    );
  }

  Widget _buildPurchaseSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt, color: Colors.green.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              'Purchase Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Responsive layout for Pass Details and Vehicle Details
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            if (isMobile) {
              // Single column layout for mobile
              return Column(
                children: [
                  _buildPassDetailsCard(),
                  const SizedBox(height: 12),
                  _buildVehicleDetailsCard(),
                ],
              );
            } else {
              // Two-column layout for desktop
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 1, child: _buildPassDetailsCard()),
                  const SizedBox(width: 12),
                  Expanded(flex: 1, child: _buildVehicleDetailsCard()),
                ],
              );
            }
          },
        ),

        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
                  fontSize: 14,
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_selectedPassTemplate?.currencyCode ?? ''} ${_selectedPassTemplate?.taxAmount.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),

        // Space for purchase button
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildPassDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.blue.shade600, size: 16),
              const SizedBox(width: 6),
              Text(
                'Pass Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCompactSummaryRow('Country', _selectedCountry?['name'] ?? ''),
          _buildCompactSummaryRow(
              'Authority', _selectedPassTemplate?.authorityName ?? ''),
          // Entry/Exit Point summary
          if (_selectedPassTemplate?.allowUserSelectableEntryPoint == true ||
              _selectedPassTemplate?.allowUserSelectableExitPoint == true) ...[
            _buildCompactSummaryRow(
                'Entry Point',
                _selectedPassTemplate?.allowUserSelectableEntryPoint == true
                    ? (_selectedEntryPoint?['name'] ?? 'Not selected')
                    : (_selectedPassTemplate?.entryPointName ??
                        'Any Entry Point')),
            _buildCompactSummaryRow(
                'Exit Point',
                _selectedPassTemplate?.allowUserSelectableExitPoint == true
                    ? (_selectedExitPoint?['name'] ?? 'Not selected')
                    : (_selectedPassTemplate?.exitPointName ??
                        'Any Exit Point')),
          ] else ...[
            _buildCompactSummaryRow('Entry Point',
                _selectedPassTemplate?.entryPointName ?? 'Any Entry Point'),
            _buildCompactSummaryRow('Exit Point',
                _selectedPassTemplate?.exitPointName ?? 'Any Exit Point'),
          ],
          _buildCompactSummaryRow('Vehicle Type',
              _selectedPassTemplate?.vehicleType ?? 'Any Vehicle Type'),
          _buildCompactSummaryRow(
              'Entries', '${_selectedPassTemplate?.entryLimit ?? 0}'),
          _buildCompactSummaryRow('Valid for',
              '${_selectedPassTemplate?.expirationDays ?? 0} days'),
          if (_selectedActivationDate != null) ...[
            _buildCompactSummaryRow(
                'Activation Date', _formatDate(_selectedActivationDate!)),
            _buildCompactSummaryRow(
                'Expiration Date', _formatDate(_calculateExpirationDate())),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _selectedVehicle != null
            ? Colors.orange.shade50
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _selectedVehicle != null
              ? Colors.orange.shade200
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _selectedVehicle != null
                    ? Icons.directions_car
                    : Icons.directions_walk,
                color: _selectedVehicle != null
                    ? Colors.orange.shade600
                    : Colors.grey.shade600,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Vehicle Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _selectedVehicle != null
                      ? Colors.orange.shade800
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedVehicle != null) ...[
            _buildCompactSummaryRow('Make & Model',
                '${_selectedVehicle!.make} ${_selectedVehicle!.model}'),
            _buildCompactSummaryRow('Year', '${_selectedVehicle!.year}'),
            _buildCompactSummaryRow(
                'Color', _selectedVehicle!.color ?? 'Not specified'),
            if (_selectedVehicle!.registrationNumber?.isNotEmpty == true)
              _buildCompactSummaryRow(
                  'Number Plate', _selectedVehicle!.registrationNumber!),
            if (_selectedVehicle!.vinNumber?.isNotEmpty == true)
              _buildCompactSummaryRow('VIN', _selectedVehicle!.vinNumber!),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Icon(Icons.directions_walk,
                      color: Colors.green.shade600, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    'Pedestrian Pass',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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

  Widget _buildCompactSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.right,
            ),
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
        return true; // Vehicle selection is optional
      default:
        return false;
    }
  }

  bool _canPurchase() {
    if (_selectedCountry == null ||
        _selectedPassTemplate == null ||
        _selectedActivationDate == null ||
        _isPurchasing) {
      return false;
    }

    // If template allows user-selectable points, check that required points are selected
    // (This should already be validated in the dialog, but double-check here)
    if (_selectedPassTemplate!.allowUserSelectableEntryPoint &&
        _selectedEntryPoint == null) {
      return false;
    }
    if (_selectedPassTemplate!.allowUserSelectableExitPoint &&
        _selectedExitPoint == null) {
      return false;
    }

    return true;
  }

  Future<void> _selectActivationDate() async {
    if (_selectedPassTemplate == null) return;

    final now = DateTime.now();
    final templateAdvanceDays = _selectedPassTemplate!.passAdvanceDays;

    // Determine the date range: always start from now, extend up to passAdvanceDays in the future
    final DateTime minDate = now; // Always allow activation from now
    final DateTime maxDate = templateAdvanceDays > 0
        ? now.add(Duration(
            days: templateAdvanceDays)) // Allow up to advance days in future
        : now.add(const Duration(
            days: 1)); // If no advance days, allow only today and tomorrow

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now, // Always default to today
      firstDate: minDate,
      lastDate: maxDate,
      helpText: templateAdvanceDays > 0
          ? 'Select Activation Date (Can be purchased up to $templateAdvanceDays days in advance)'
          : 'Select Activation Date',
      confirmText: 'SELECT',
      cancelText: 'CANCEL',
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

    if (selectedDate != null) {
      setState(() {
        // Set activation date to start of day
        _selectedActivationDate =
            DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      });
    }
  }

  DateTime _calculateExpirationDate() {
    if (_selectedActivationDate == null || _selectedPassTemplate == null) {
      return DateTime.now();
    }

    // Calculate expiration date: activation date + expiration days
    final expirationDate = _selectedActivationDate!
        .add(Duration(days: _selectedPassTemplate!.expirationDays));

    return DateTime(
        expirationDate.year, expirationDate.month, expirationDate.day);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final compareDate = DateTime(date.year, date.month, date.day);
    final difference = nowDate.difference(compareDate);

    // If it's today
    if (difference.inDays == 0) {
      return 'Today';
    }

    // If it's yesterday
    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    // If it's tomorrow
    if (difference.inDays == -1) {
      return 'Tomorrow';
    }

    // If it's within this week
    if (difference.inDays.abs() <= 7) {
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      return weekdays[date.weekday - 1];
    }

    // If it's this year
    if (date.year == now.year) {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${date.day} ${months[date.month - 1]}';
    }

    // Default format for older dates
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
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

  // Active filters
  String? _selectedEntryPoint;
  String? _selectedVehicleType;

  // Available filter values
  List<String> _availableEntryPoints = [];
  List<String> _availableVehicleTypes = [];

  // User-selected entry/exit points for templates that allow selection
  Map<String, dynamic>? _userSelectedEntryPoint;
  Map<String, dynamic>? _userSelectedExitPoint;
  List<Map<String, dynamic>> _availableBorders = [];
  bool _isLoadingBorders = false;

  @override
  void initState() {
    super.initState();
    _filteredTemplates = widget.passTemplates;
    _selectedTemplate = widget.selectedTemplate;
    _searchController.addListener(_filterTemplates);
    _extractFilterValues();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _extractFilterValues() {
    // Extract unique entry points and vehicle types from templates
    final entryPoints = widget.passTemplates
        .where((t) => t.entryPointName != null)
        .map((t) => t.entryPointName!)
        .toSet()
        .toList();
    entryPoints.sort();

    final vehicleTypes = widget.passTemplates
        .where((t) => t.vehicleType != null)
        .map((t) => t.vehicleType!)
        .toSet()
        .toList();
    vehicleTypes.sort();

    setState(() {
      _availableEntryPoints = entryPoints;
      _availableVehicleTypes = vehicleTypes;
    });
  }

  void _filterTemplates() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTemplates = widget.passTemplates.where((template) {
        // Apply entry point filter
        if (_selectedEntryPoint != null &&
            template.entryPointName != _selectedEntryPoint) {
          return false;
        }

        // Apply vehicle type filter
        if (_selectedVehicleType != null &&
            template.vehicleType != _selectedVehicleType) {
          return false;
        }

        // Apply text search
        if (query.isNotEmpty) {
          return (template.authorityName?.toLowerCase().contains(query) ??
                  false) ||
              (template.entryPointName?.toLowerCase().contains(query) ??
                  false) ||
              (template.exitPointName?.toLowerCase().contains(query) ??
                  false) ||
              (template.vehicleType?.toLowerCase().contains(query) ?? false);
        }

        return true;
      }).toList();
    });
  }

  void _addEntryPointFilter(String entryPoint) {
    setState(() {
      _selectedEntryPoint = entryPoint;
    });
    _filterTemplates();
  }

  void _addVehicleTypeFilter(String vehicleType) {
    setState(() {
      _selectedVehicleType = vehicleType;
    });
    _filterTemplates();
  }

  void _removeEntryPointFilter() {
    setState(() {
      _selectedEntryPoint = null;
    });
    _filterTemplates();
  }

  void _removeVehicleTypeFilter() {
    setState(() {
      _selectedVehicleType = null;
    });
    _filterTemplates();
  }

  void _clearAllFilters() {
    setState(() {
      _selectedEntryPoint = null;
      _selectedVehicleType = null;
      _searchController.clear();
    });
    _filterTemplates();
  }

  Future<void> _loadBordersForTemplate(PassTemplate template) async {
    if (!template.allowUserSelectableEntryPoint &&
        !template.allowUserSelectableExitPoint) {
      setState(() {
        _availableBorders = [];
        _userSelectedEntryPoint = null;
        _userSelectedExitPoint = null;
      });
      return;
    }

    setState(() {
      _isLoadingBorders = true;
      _userSelectedEntryPoint = null;
      _userSelectedExitPoint = null;
    });

    try {
      debugPrint('Loading borders for authority: "${template.authorityId}"');
      debugPrint(
          'Template details: id=${template.id}, description=${template.description}');
      debugPrint('Authority ID length: ${template.authorityId.length}');

      if (template.authorityId.isEmpty) {
        throw Exception('Authority ID is empty for template ${template.id}');
      }

      final borders =
          await PassService.getBordersForAuthority(template.authorityId);
      debugPrint('Loaded ${borders.length} borders');

      setState(() {
        _availableBorders = borders
            .map((border) => {
                  'id': border['border_id'],
                  'name': border['border_name'],
                })
            .toList();
        _isLoadingBorders = false;
      });
    } catch (e) {
      debugPrint('Error loading borders: $e');
      setState(() {
        _isLoadingBorders = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading borders: $e')),
        );
      }
    }
  }

  void _selectTemplate(PassTemplate template) {
    setState(() {
      _selectedTemplate = template;
    });
    _loadBordersForTemplate(template);
  }

  bool _canSelectTemplate() {
    if (_selectedTemplate == null) return false;

    // If template allows user-selectable points, check that required points are selected
    if (_selectedTemplate!.allowUserSelectableEntryPoint &&
        _userSelectedEntryPoint == null) {
      return false;
    }
    if (_selectedTemplate!.allowUserSelectableExitPoint &&
        _userSelectedExitPoint == null) {
      return false;
    }

    return true;
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
                    'Select Pass',
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
            // Search with integrated filters
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Active filter chips inside the search box
                  if (_selectedEntryPoint != null ||
                      _selectedVehicleType != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (_selectedEntryPoint != null)
                            Chip(
                              label: Text(
                                'Entry Point: $_selectedEntryPoint',
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: Colors.blue.shade100,
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: _removeEntryPointFilter,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          if (_selectedVehicleType != null)
                            Chip(
                              label: Text(
                                'Vehicle: $_selectedVehicleType',
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: Colors.green.shade100,
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: _removeVehicleTypeFilter,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),
                  // Search text field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search passes...',
                      prefixIcon: const Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      suffixIcon: (_searchController.text.isNotEmpty ||
                              _selectedEntryPoint != null ||
                              _selectedVehicleType != null)
                          ? IconButton(
                              onPressed: _clearAllFilters,
                              icon: const Icon(Icons.clear),
                              tooltip: 'Clear all filters',
                            )
                          : PopupMenuButton<String>(
                              icon: const Icon(Icons.filter_list),
                              tooltip: 'Add filters',
                              onSelected: (value) {
                                if (value.startsWith('entry:') &&
                                    value.length > 6) {
                                  _addEntryPointFilter(value.substring(6));
                                } else if (value.startsWith('vehicle:') &&
                                    value.length > 8) {
                                  _addVehicleTypeFilter(value.substring(8));
                                }
                              },
                              itemBuilder: (context) => [
                                if (_availableEntryPoints.isNotEmpty) ...[
                                  const PopupMenuItem<String>(
                                    enabled: false,
                                    child: Text(
                                      'Filter by Entry Point:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  ..._availableEntryPoints.map(
                                      (entryPoint) => PopupMenuItem<String>(
                                            value: 'entry:$entryPoint',
                                            enabled: _selectedEntryPoint !=
                                                entryPoint,
                                            child: Text(entryPoint),
                                          )),
                                  const PopupMenuDivider(),
                                ],
                                if (_availableVehicleTypes.isNotEmpty) ...[
                                  const PopupMenuItem<String>(
                                    enabled: false,
                                    child: Text(
                                      'Filter by Vehicle Type:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  ..._availableVehicleTypes.map(
                                      (vehicleType) => PopupMenuItem<String>(
                                            value: 'vehicle:$vehicleType',
                                            enabled: _selectedVehicleType !=
                                                vehicleType,
                                            child: Text(vehicleType),
                                          )),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
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

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue.shade100
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue.shade400
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _selectTemplate(template),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          template.authorityName ??
                                              'Unknown Authority',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isSelected
                                                ? Colors.blue.shade800
                                                : Colors.grey.shade800,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade600,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Entry/Exit Point display or selection
                                  _buildEntryPointDisplay(template, isSelected),
                                  const SizedBox(height: 8),
                                  _buildExitPointDisplay(template, isSelected),

                                  Text(
                                    'Vehicle Type: ${template.vehicleType ?? 'Any'}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected
                                          ? Colors.blue.shade700
                                          : Colors.grey.shade600,
                                    ),
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
                                          color: isSelected
                                              ? Colors.blue.shade600
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.blue.shade600
                                              : Colors.green.shade600,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${template.currencyCode} ${template.taxAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
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
                  onPressed: _canSelectTemplate()
                      ? () {
                          // Pass the selected template along with user-selected entry/exit points
                          final result = {
                            'template': _selectedTemplate,
                            'userSelectedEntryPoint': _userSelectedEntryPoint,
                            'userSelectedExitPoint': _userSelectedExitPoint,
                          };
                          Navigator.of(context).pop(result);
                        }
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

  Widget _buildEntryPointDisplay(PassTemplate template, bool isSelected) {
    // Priority: Fixed Border > User Selectable > Any Entry Point
    if (template.entryPointId != null) {
      // Fixed border - show the specific border name
      final entryPointName = template.entryPointName ?? 'Fixed Entry Point';
      debugPrint(
          '🔍 Entry Point - ID: ${template.entryPointId}, Name: $entryPointName');

      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.green.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                entryPointName,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else if (template.allowUserSelectableEntryPoint) {
      // User selectable entry point
      if (isSelected) {
        if (_isLoadingBorders) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Loading entry points...',
                          style: TextStyle(fontSize: 12)),
                      SizedBox(height: 4),
                      LinearProgressIndicator(minHeight: 2),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return DropdownButtonFormField<Map<String, dynamic>>(
          value: _userSelectedEntryPoint,
          decoration: const InputDecoration(
            labelText: 'Select Entry Point',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            isDense: true,
          ),
          items: _availableBorders
              .map((border) => DropdownMenuItem<Map<String, dynamic>>(
                    value: border,
                    child: Text(border['name'],
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _userSelectedEntryPoint = value;
            });
          },
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.person_pin_circle,
                  size: 16, color: Colors.blue.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'You will select entry point during purchase',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // Any entry point (null entry_point_id and not user selectable)
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              'Entry: Any Entry Point',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildExitPointDisplay(PassTemplate template, bool isSelected) {
    // Priority: Fixed Border > User Selectable > Any Exit Point
    if (template.exitPointId != null) {
      // Fixed border - show the specific border name
      final exitPointName = template.exitPointName ?? 'Fixed Exit Point';
      debugPrint(
          '🔍 Exit Point - ID: ${template.exitPointId}, Name: $exitPointName');

      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off, size: 16, color: Colors.red.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                exitPointName,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else if (template.allowUserSelectableExitPoint) {
      // User selectable exit point
      if (isSelected) {
        if (_isLoadingBorders) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Loading exit points...',
                          style: TextStyle(fontSize: 12)),
                      SizedBox(height: 4),
                      LinearProgressIndicator(minHeight: 2),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return DropdownButtonFormField<Map<String, dynamic>>(
          value: _userSelectedExitPoint,
          decoration: const InputDecoration(
            labelText: 'Select Exit Point',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            isDense: true,
          ),
          items: _availableBorders
              .map((border) => DropdownMenuItem<Map<String, dynamic>>(
                    value: border,
                    child: Text(border['name'],
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _userSelectedExitPoint = value;
            });
          },
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.person_pin_circle,
                  size: 16, color: Colors.blue.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'You will select exit point during purchase',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // Any exit point (null exit_point_id and not user selectable)
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              'Exit: Any Exit Point',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }
  }
}
