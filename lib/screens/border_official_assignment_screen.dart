import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/border.dart' as border_model;

class BorderOfficialAssignmentScreen extends StatefulWidget {
  final border_model.Border border;
  final String authorityId;

  const BorderOfficialAssignmentScreen({
    super.key,
    required this.border,
    required this.authorityId,
  });

  @override
  State<BorderOfficialAssignmentScreen> createState() =>
      _BorderOfficialAssignmentScreenState();
}

class _BorderOfficialAssignmentScreenState
    extends State<BorderOfficialAssignmentScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _officials = [];
  Set<String> _assignedOfficialIds = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadOfficials();
  }

  Future<void> _loadOfficials() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get all border officials for this authority
      final officialsResponse = await _supabase
          .from('profiles')
          .select('''
            id,
            full_name,
            email,
            profile_image_url,
            profile_roles!inner(
              role_name
            )
          ''')
          .eq('profile_roles.role_name', 'border_official')
          .eq('country_id', widget.authorityId);

      // Get current assignments for this border
      final assignmentsResponse = await _supabase
          .from('border_official_borders')
          .select('profile_id')
          .eq('border_id', widget.border.id)
          .eq('is_active', true);

      final assignedIds = assignmentsResponse
          .map((assignment) => assignment['profile_id'] as String)
          .toSet();

      setState(() {
        _officials = List<Map<String, dynamic>>.from(officialsResponse);
        _assignedOfficialIds = assignedIds;
        _isLoading = false;
      });

      debugPrint(
          '✅ Loaded ${_officials.length} officials, ${_assignedOfficialIds.length} assigned');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      debugPrint('❌ Error loading officials: $e');
    }
  }

  Future<void> _toggleAssignment(String officialId, bool isAssigned) async {
    try {
      setState(() {
        _isSaving = true;
      });

      if (isAssigned) {
        // Add assignment
        await _supabase.from('border_official_borders').insert({
          'profile_id': officialId,
          'border_id': widget.border.id,
          'is_active': true,
          'can_check_in': true,
          'can_check_out': true,
          'created_at': DateTime.now().toIso8601String(),
        });

        setState(() {
          _assignedOfficialIds.add(officialId);
        });

        debugPrint(
            '✅ Assigned official $officialId to border ${widget.border.id}');
      } else {
        // Remove assignment (set inactive)
        await _supabase
            .from('border_official_borders')
            .update({
              'is_active': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('profile_id', officialId)
            .eq('border_id', widget.border.id);

        setState(() {
          _assignedOfficialIds.remove(officialId);
        });

        debugPrint(
            '✅ Unassigned official $officialId from border ${widget.border.id}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAssigned
                ? 'Official assigned to ${widget.border.name}'
                : 'Official unassigned from ${widget.border.name}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating assignment: $e'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('❌ Error toggling assignment: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<List<String>> _getOfficialBorders(String officialId) async {
    try {
      final response =
          await _supabase.from('border_official_borders').select('''
            borders!inner(
              name
            )
          ''').eq('profile_id', officialId).eq('is_active', true);

      return response.map((item) => item['borders']['name'] as String).toList();
    } catch (e) {
      debugPrint('❌ Error getting official borders: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Officials - ${widget.border.name}'),
        backgroundColor: Colors.purple.shade700,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _buildOfficialsList(),
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
            'Failed to load border officials',
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
            onPressed: _loadOfficials,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialsList() {
    if (_officials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Border Officials Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'No border officials are available for assignment.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildHeaderCard(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _officials.length,
            itemBuilder: (context, index) {
              final official = _officials[index];
              return _buildOfficialCard(official);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    final assignedCount = _assignedOfficialIds.length;
    final totalCount = _officials.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.purple.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.purple.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                'Border Official Assignments',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.purple.shade800,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Assign border officials to ${widget.border.name}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.purple.shade600,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$assignedCount of $totalCount assigned',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialCard(Map<String, dynamic> official) {
    final officialId = official['id'] as String;
    final isAssigned = _assignedOfficialIds.contains(officialId);
    final fullName = official['full_name'] as String? ?? 'Unknown';
    final email = official['email'] as String? ?? '';
    final profileImageUrl = official['profile_image_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Profile Image
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.purple.shade100,
              backgroundImage:
                  profileImageUrl != null && profileImageUrl.isNotEmpty
                      ? NetworkImage(profileImageUrl)
                      : null,
              child: profileImageUrl == null || profileImageUrl.isEmpty
                  ? Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // Official Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Current Assignments
                  FutureBuilder<List<String>>(
                    future: _getOfficialBorders(officialId),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        final borders = snapshot.data!;
                        return Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: borders.map((borderName) {
                            final isCurrentBorder =
                                borderName == widget.border.name;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isCurrentBorder
                                    ? Colors.purple.shade100
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: isCurrentBorder
                                    ? Border.all(color: Colors.purple.shade300)
                                    : null,
                              ),
                              child: Text(
                                borderName,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isCurrentBorder
                                      ? Colors.purple.shade700
                                      : Colors.grey.shade600,
                                  fontWeight: isCurrentBorder
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      } else if (snapshot.hasData && snapshot.data!.isEmpty) {
                        return Text(
                          'No border assignments',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),

            // Assignment Toggle
            Switch(
              value: isAssigned,
              onChanged: _isSaving
                  ? null
                  : (value) => _toggleAssignment(officialId, value),
              activeColor: Colors.purple.shade600,
            ),
          ],
        ),
      ),
    );
  }
}
