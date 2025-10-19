import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BorderConfigurationScreen extends StatefulWidget {
  final String? authorityId;
  final String? authorityName;

  const BorderConfigurationScreen({
    super.key,
    this.authorityId,
    this.authorityName,
  });

  @override
  State<BorderConfigurationScreen> createState() =>
      _BorderConfigurationScreenState();
}

class _BorderConfigurationScreenState extends State<BorderConfigurationScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _borders = [];

  @override
  void initState() {
    super.initState();
    _loadBorders();
  }

  Future<void> _loadBorders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await Supabase.instance.client
          .from('borders')
          .select('id, name, description, allow_out_of_schedule_scans')
          .order('name');

      setState(() {
        _borders = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      debugPrint('✅ Loaded ${_borders.length} borders for configuration');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      debugPrint('❌ Error loading borders: $e');
    }
  }

  Future<void> _updateBorderSetting(
      String borderId, bool allowOutOfSchedule) async {
    try {
      await Supabase.instance.client
          .from('borders')
          .update({'allow_out_of_schedule_scans': allowOutOfSchedule}).eq(
              'id', borderId);

      // Update local state
      setState(() {
        final borderIndex = _borders.indexWhere((b) => b['id'] == borderId);
        if (borderIndex != -1) {
          _borders[borderIndex]['allow_out_of_schedule_scans'] =
              allowOutOfSchedule;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allowOutOfSchedule
                ? 'Out-of-schedule scans enabled'
                : 'Out-of-schedule scans disabled',
          ),
          backgroundColor: Colors.green,
        ),
      );

      debugPrint(
          '✅ Updated border $borderId out-of-schedule setting to $allowOutOfSchedule');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating setting: $e'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('❌ Error updating border setting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.authorityName != null
            ? 'Border Configuration - ${widget.authorityName}'
            : 'Border Configuration'),
        backgroundColor: Colors.purple.shade700,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBorders,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _buildConfigurationContent(),
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
            'Failed to load border configuration',
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
            onPressed: _loadBorders,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationContent() {
    if (_borders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Borders Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'No borders are available for configuration.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildBordersConfiguration(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
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
                  Icon(Icons.settings, color: Colors.purple.shade700, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Border Configuration',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.purple.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Configure border-specific settings and policies',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.purple.shade600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBordersConfiguration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Border Settings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ..._borders.map((border) => _buildBorderConfigCard(border)),
      ],
    );
  }

  Widget _buildBorderConfigCard(Map<String, dynamic> border) {
    final allowOutOfSchedule = border['allow_out_of_schedule_scans'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: Colors.purple.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        border['name'] ?? 'Unknown Border',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      if (border['description'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          border['description'],
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Out-of-schedule scanning setting
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Allow Out-of-Schedule Scans',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Allow border officials to scan passes outside their scheduled time slots',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Switch(
                  value: allowOutOfSchedule,
                  onChanged: (value) =>
                      _updateBorderSetting(border['id'], value),
                  activeColor: Colors.purple.shade600,
                ),
              ],
            ),

            // Status indicator
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: allowOutOfSchedule
                    ? Colors.orange.shade100
                    : Colors.green.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: allowOutOfSchedule
                      ? Colors.orange.shade300
                      : Colors.green.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    allowOutOfSchedule
                        ? Icons.warning_amber
                        : Icons.check_circle,
                    size: 16,
                    color: allowOutOfSchedule
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    allowOutOfSchedule
                        ? 'Out-of-schedule scans allowed'
                        : 'Schedule enforcement active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: allowOutOfSchedule
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
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
}
