import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of schedule validation check
class ScheduleValidationResult {
  final bool allowed;
  final bool isWithinSchedule;
  final bool borderAllowsOutOfSchedule;
  final String? errorMessage;
  final List<Map<String, dynamic>>? todaySchedule;
  final String? borderId;
  final String? borderName;

  const ScheduleValidationResult({
    required this.allowed,
    required this.isWithinSchedule,
    required this.borderAllowsOutOfSchedule,
    this.errorMessage,
    this.todaySchedule,
    this.borderId,
    this.borderName,
  });

  /// Create a result for when scan is allowed
  factory ScheduleValidationResult.allowed({
    required bool isWithinSchedule,
    List<Map<String, dynamic>>? todaySchedule,
    String? borderId,
    String? borderName,
  }) {
    return ScheduleValidationResult(
      allowed: true,
      isWithinSchedule: isWithinSchedule,
      borderAllowsOutOfSchedule:
          !isWithinSchedule, // If not within schedule but allowed, border must allow it
      todaySchedule: todaySchedule,
      borderId: borderId,
      borderName: borderName,
    );
  }

  /// Create a result for when scan is blocked
  factory ScheduleValidationResult.blocked({
    required bool isWithinSchedule,
    required bool borderAllowsOutOfSchedule,
    required String errorMessage,
    List<Map<String, dynamic>>? todaySchedule,
    String? borderId,
    String? borderName,
  }) {
    return ScheduleValidationResult(
      allowed: false,
      isWithinSchedule: isWithinSchedule,
      borderAllowsOutOfSchedule: borderAllowsOutOfSchedule,
      errorMessage: errorMessage,
      todaySchedule: todaySchedule,
      borderId: borderId,
      borderName: borderName,
    );
  }
}

/// Service for validating border official schedules during pass scanning
class ScheduleValidationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Validate if a border official can scan at the current time
  static Future<ScheduleValidationResult> validateOfficialSchedule({
    required String officialId,
    String? borderId,
  }) async {
    try {
      debugPrint('🕐 Validating schedule for official: $officialId');
      debugPrint('🏢 Border ID: ${borderId ?? 'Not specified'}');

      final now = DateTime.now();
      final currentTime = TimeOfDay.fromDateTime(now);
      final currentDayOfWeek = now.weekday; // 1=Monday, 7=Sunday

      debugPrint(
          '🕐 Current time: ${currentTime.hour}:${currentTime.minute.toString().padLeft(2, '0')} on day $currentDayOfWeek');

      // Step 1: Get official's current schedule assignments for today
      final scheduleQuery = _supabase
          .from('official_schedule_assignments')
          .select('''
            *,
            schedule_time_slots!inner(
              *,
              border_schedule_templates!inner(
                *,
                borders!inner(id, name, allow_out_of_schedule_scans)
              )
            )
          ''')
          .eq('profile_id', officialId)
          .isFilter('effective_to', null) // Active assignments only
          .eq('schedule_time_slots.day_of_week', currentDayOfWeek)
          .eq('schedule_time_slots.is_active', true);

      // If specific border is provided, filter by it
      if (borderId != null) {
        scheduleQuery.eq(
            'schedule_time_slots.border_schedule_templates.borders.id',
            borderId);
      }

      final scheduleResponse = await scheduleQuery;
      final assignments = List<Map<String, dynamic>>.from(scheduleResponse);

      debugPrint(
          '📅 Found ${assignments.length} schedule assignments for today');

      if (assignments.isEmpty) {
        // No schedule for today - check if any border allows out-of-schedule scans
        if (borderId != null) {
          final borderInfo = await _getBorderInfo(borderId);
          if (borderInfo != null &&
              borderInfo['allow_out_of_schedule_scans'] == true) {
            debugPrint('✅ No schedule but border allows out-of-schedule scans');
            return ScheduleValidationResult.allowed(
              isWithinSchedule: false,
              borderId: borderId,
              borderName: borderInfo['name'],
            );
          }
        }

        debugPrint(
            '❌ No schedule for today and border does not allow out-of-schedule scans');
        return ScheduleValidationResult.blocked(
          isWithinSchedule: false,
          borderAllowsOutOfSchedule: false,
          errorMessage: 'You are not scheduled to work today.',
          borderId: borderId,
        );
      }

      // Step 2: Check if current time falls within any scheduled time slot
      bool isWithinSchedule = false;
      String? currentBorderId;
      String? currentBorderName;
      bool borderAllowsOutOfSchedule = false;

      for (final assignment in assignments) {
        final timeSlot = assignment['schedule_time_slots'];
        final template = timeSlot['border_schedule_templates'];
        final border = template['borders'];

        currentBorderId = border['id'];
        currentBorderName = border['name'];
        borderAllowsOutOfSchedule =
            border['allow_out_of_schedule_scans'] ?? false;

        final startTime = _parseTimeString(timeSlot['start_time']);
        final endTime = _parseTimeString(timeSlot['end_time']);

        if (_isTimeWithinRange(currentTime, startTime, endTime)) {
          isWithinSchedule = true;
          debugPrint(
              '✅ Current time is within scheduled slot: ${timeSlot['start_time']} - ${timeSlot['end_time']}');
          break;
        }
      }

      // Step 3: Prepare today's schedule for display
      final todaySchedule = assignments.map((assignment) {
        final timeSlot = assignment['schedule_time_slots'];
        final template = timeSlot['border_schedule_templates'];
        final border = template['borders'];

        return {
          'start_time': timeSlot['start_time'],
          'end_time': timeSlot['end_time'],
          'border_name': border['name'],
          'assignment_type': assignment['assignment_type'],
          'template_name': template['template_name'],
        };
      }).toList();

      // Step 4: Make decision based on schedule and border settings
      if (isWithinSchedule) {
        debugPrint('✅ Scan allowed - within scheduled time');
        return ScheduleValidationResult.allowed(
          isWithinSchedule: true,
          todaySchedule: todaySchedule,
          borderId: currentBorderId,
          borderName: currentBorderName,
        );
      } else if (borderAllowsOutOfSchedule) {
        debugPrint(
            '⚠️ Outside schedule but border allows out-of-schedule scans');
        return ScheduleValidationResult.allowed(
          isWithinSchedule: false,
          todaySchedule: todaySchedule,
          borderId: currentBorderId,
          borderName: currentBorderName,
        );
      } else {
        debugPrint(
            '❌ Outside schedule and border does not allow out-of-schedule scans');
        return ScheduleValidationResult.blocked(
          isWithinSchedule: false,
          borderAllowsOutOfSchedule: false,
          errorMessage:
              'You are outside your scheduled time and this border does not allow out-of-schedule scans.',
          todaySchedule: todaySchedule,
          borderId: currentBorderId,
          borderName: currentBorderName,
        );
      }
    } catch (e) {
      debugPrint('❌ Error validating schedule: $e');
      return ScheduleValidationResult.blocked(
        isWithinSchedule: false,
        borderAllowsOutOfSchedule: false,
        errorMessage: 'Unable to validate schedule: $e',
      );
    }
  }

  /// Get border information including out-of-schedule setting
  static Future<Map<String, dynamic>?> _getBorderInfo(String borderId) async {
    try {
      final response = await _supabase
          .from('borders')
          .select('id, name, allow_out_of_schedule_scans')
          .eq('id', borderId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('❌ Error getting border info: $e');
      return null;
    }
  }

  /// Parse time string (HH:MM:SS or HH:MM) to TimeOfDay
  static TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Check if current time is within the given time range
  static bool _isTimeWithinRange(
      TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    // Handle overnight shifts (e.g., 22:00 - 06:00)
    if (endMinutes < startMinutes) {
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    } else {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    }
  }

  /// Log out-of-schedule scan for audit purposes
  static Future<void> logOutOfScheduleScan({
    required String passId,
    required String officialId,
    required String borderId,
    required List<Map<String, dynamic>> todaySchedule,
    String? notes,
  }) async {
    try {
      debugPrint('📝 Logging out-of-schedule scan for audit');

      final metadata = {
        'pass_id': passId,
        'border_id': borderId,
        'scan_time': DateTime.now().toIso8601String(),
        'scheduled_slots': todaySchedule,
        'confirmation_given': true,
        'scan_type': 'out_of_schedule',
      };

      if (notes != null) {
        metadata['notes'] = notes;
      }

      // Use existing audit service to log the event
      await _supabase.from('audit_logs').insert({
        'actor_profile_id': officialId,
        'action': 'out_of_schedule_scan',
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Out-of-schedule scan logged for audit');
    } catch (e) {
      debugPrint('❌ Error logging out-of-schedule scan: $e');
      // Don't throw - logging failure shouldn't block the scan
    }
  }

  /// Get formatted schedule display for confirmation dialog
  static String formatScheduleForDisplay(List<Map<String, dynamic>> schedule) {
    if (schedule.isEmpty) return 'No schedule for today';

    final buffer = StringBuffer();
    buffer.writeln('Today\'s Schedule:');

    for (final slot in schedule) {
      buffer.writeln(
          '• ${slot['start_time']} - ${slot['end_time']} (${slot['assignment_type']?.toUpperCase()})');
      if (slot['border_name'] != null) {
        buffer.writeln('  at ${slot['border_name']}');
      }
    }

    return buffer.toString().trim();
  }
}
