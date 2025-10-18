import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/border_manager.dart';
import '../models/border.dart' as border_model;

class BorderManagerServiceTemp {
  static final _supabase = Supabase.instance.client;

  /// Get border assignments from the border's perspective (SIMPLE VERSION)
  static Future<List<BorderManagerAssignmentWithDetails>>
      getBorderManagerAssignmentsByAuthority(
    String authorityId,
  ) async {
    try {
      // Get all borders for this authority (simple query)
      final bordersResponse = await _supabase
          .from('borders')
          .select('id, name, description')
          .eq('authority_id', authorityId)
          .eq('is_active', true)
          .order('name');

      List<BorderManagerAssignmentWithDetails> assignments = [];

      for (var borderData in bordersResponse) {
        final borderId = borderData['id'] as String;

        // Get manager assignments for this border (no embedding)
        final assignmentsResponse = await _supabase
            .from('border_manager_borders')
            .select('profile_id, assigned_at')
            .eq('border_id', borderId)
            .eq('is_active', true);

        List<BorderManagerAssignment> assignedManagers = [];

        // Get profile details for each assigned manager separately
        for (var assignment in assignmentsResponse) {
          try {
            final profileResponse = await _supabase
                .from('profiles')
                .select('id, full_name, email, profile_image_url')
                .eq('id', assignment['profile_id'])
                .single();

            assignedManagers.add(BorderManagerAssignment(
              profileId: profileResponse['id'],
              fullName: profileResponse['full_name'],
              email: profileResponse['email'],
              profileImageUrl: profileResponse['profile_image_url'],
              assignedAt: DateTime.parse(assignment['assigned_at']),
            ));
          } catch (e) {
            // Skip if profile not found
            print(
                'Profile not found for assignment: ${assignment['profile_id']}');
          }
        }

        assignments.add(BorderManagerAssignmentWithDetails(
          borderId: borderId,
          borderName: borderData['name'],
          borderDescription: borderData['description'],
          borderType: null, // Simplified - no border type for now
          assignedManagers: assignedManagers,
        ));
      }

      return assignments;
    } catch (e) {
      throw Exception('Failed to get border manager assignments: $e');
    }
  }
}

/// Model for border manager assignment from border's perspective
class BorderManagerAssignmentWithDetails {
  final String borderId;
  final String borderName;
  final String? borderDescription;
  final String? borderType;
  final List<BorderManagerAssignment> assignedManagers;

  BorderManagerAssignmentWithDetails({
    required this.borderId,
    required this.borderName,
    this.borderDescription,
    this.borderType,
    required this.assignedManagers,
  });
}

/// Model for individual manager assignment
class BorderManagerAssignment {
  final String profileId;
  final String fullName;
  final String email;
  final String? profileImageUrl;
  final DateTime assignedAt;

  BorderManagerAssignment({
    required this.profileId,
    required this.fullName,
    required this.email,
    this.profileImageUrl,
    required this.assignedAt,
  });
}
