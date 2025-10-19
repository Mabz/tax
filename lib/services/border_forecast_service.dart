import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchased_pass.dart';

/// Forecast Data Model
class ForecastData {
  // Vehicle Flow Forecast
  final int expectedCheckIns;
  final int expectedCheckOuts;

  // Vehicle Types Forecast
  final Map<String, VehicleTypeForecast> vehicleTypeBreakdown;
  final String topVehicleType;

  // Pass Forecast
  final List<PassForecast> upcomingPasses;
  final int totalUpcomingPasses;

  // Revenue Forecast
  final double expectedRevenue;
  final List<DailyRevenueForecast> dailyRevenueForecast;

  // Comparison Data
  final double revenueGrowth;
  final double passVolumeGrowth;
  final double checkInGrowth;
  final double checkOutGrowth;

  ForecastData({
    required this.expectedCheckIns,
    required this.expectedCheckOuts,
    required this.vehicleTypeBreakdown,
    required this.topVehicleType,
    required this.upcomingPasses,
    required this.totalUpcomingPasses,
    required this.expectedRevenue,
    required this.dailyRevenueForecast,
    required this.revenueGrowth,
    required this.passVolumeGrowth,
    required this.checkInGrowth,
    required this.checkOutGrowth,
  });
}

/// Vehicle Type Forecast Model
class VehicleTypeForecast {
  final String vehicleType;
  final int expectedCheckIns;
  final int expectedCheckOuts;
  final double expectedRevenue;
  final int passCount;

  VehicleTypeForecast({
    required this.vehicleType,
    required this.expectedCheckIns,
    required this.expectedCheckOuts,
    required this.expectedRevenue,
    required this.passCount,
  });
}

/// Pass Forecast Model
class PassForecast {
  final String passId;
  final String passType;
  final String vehicleDescription;
  final DateTime activationDate;
  final DateTime expirationDate;
  final double amount;
  final String currency;
  final String status;
  final bool willCheckIn;
  final bool willCheckOut;
  final String? profileId; // Owner ID for showing owner details

  PassForecast({
    required this.passId,
    required this.passType,
    required this.vehicleDescription,
    required this.activationDate,
    required this.expirationDate,
    required this.amount,
    required this.currency,
    required this.status,
    required this.willCheckIn,
    required this.willCheckOut,
    this.profileId,
  });
}

/// Daily Revenue Forecast Model
class DailyRevenueForecast {
  final DateTime date;
  final double expectedRevenue;
  final int expectedCheckIns;
  final int expectedCheckOuts;
  final int passCount;

  DailyRevenueForecast({
    required this.date,
    required this.expectedRevenue,
    required this.expectedCheckIns,
    required this.expectedCheckOuts,
    required this.passCount,
  });
}

/// Border Forecast Service
class BorderForecastService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get forecast data for a specific border
  static Future<ForecastData> getForecastData(
    String borderId,
    String dateFilter, {
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    try {
      debugPrint(
          '🔍 Fetching forecast data for border: $borderId, filter: $dateFilter');

      final dateRange =
          _getDateRange(dateFilter, customStartDate, customEndDate);

      // Get all passes for the border that are relevant to the forecast period
      // This includes passes that activate OR expire within the date range
      final passesResponse = await _supabase
          .from('purchased_passes')
          .select('''
            *,
            vehicles!inner(
              id,
              vehicle_types!inner(
                id,
                label,
                description
              )
            )
          ''')
          .or('entry_point_id.eq.$borderId,exit_point_id.eq.$borderId')
          .order('activation_date');

      final allPasses =
          passesResponse.map((json) => PurchasedPass.fromJson(json)).toList();

      debugPrint('📊 Total passes found: ${allPasses.length}');

      // Filter passes to only include those relevant to the forecast period
      final passes = _filterPassesForForecast(allPasses, dateRange);
      debugPrint('📊 Filtered passes for forecast: ${passes.length}');

      // Calculate forecast metrics
      final vehicleFlowForecast =
          _calculateVehicleFlowForecast(passes, dateRange);
      final vehicleTypeForecast = _calculateVehicleTypeForecast(passes);
      final passForecast = _calculatePassForecast(passes, dateRange);
      final revenueForecast = _calculateRevenueForecast(passes, dateRange);

      final forecastData = ForecastData(
        expectedCheckIns: vehicleFlowForecast['expectedCheckIns'] ?? 0,
        expectedCheckOuts: vehicleFlowForecast['expectedCheckOuts'] ?? 0,
        vehicleTypeBreakdown: vehicleTypeForecast,
        topVehicleType: _getTopVehicleType(vehicleTypeForecast),
        upcomingPasses: passForecast['upcomingPasses'] ?? [],
        totalUpcomingPasses: passForecast['totalCount'] ?? 0,
        expectedRevenue: revenueForecast['expectedRevenue'] ?? 0.0,
        dailyRevenueForecast: revenueForecast['dailyForecast'] ?? [],
        revenueGrowth: 0.0, // Will be calculated in comparison
        passVolumeGrowth: 0.0,
        checkInGrowth: 0.0,
        checkOutGrowth: 0.0,
      );

      debugPrint('✅ Forecast data generated successfully');
      return forecastData;
    } catch (e) {
      debugPrint('❌ Error fetching forecast data: $e');
      throw Exception('Failed to fetch forecast data: $e');
    }
  }

  /// Get comparison forecast data
  static Future<ForecastData> getComparisonForecastData(
    String borderId,
    String dateFilter,
    String comparisonType, {
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    try {
      final currentDateRange =
          _getDateRange(dateFilter, customStartDate, customEndDate);
      final comparisonDateRange = _getComparisonDateRange(
        currentDateRange,
        comparisonType,
      );

      return await getForecastData(
        borderId,
        'custom',
        customStartDate: comparisonDateRange.start,
        customEndDate: comparisonDateRange.end,
      );
    } catch (e) {
      debugPrint('❌ Error fetching comparison forecast data: $e');
      throw Exception('Failed to fetch comparison forecast data: $e');
    }
  }

  /// Calculate vehicle flow forecast
  static Map<String, int> _calculateVehicleFlowForecast(
    List<PurchasedPass> passes,
    ForecastDateRange dateRange,
  ) {
    if (passes.isEmpty) {
      debugPrint('🚗 No passes found for forecast calculation');
      return {
        'expectedCheckIns': 0,
        'expectedCheckOuts': 0,
      };
    }

    int expectedCheckIns = 0;
    int expectedCheckOuts = 0;

    for (final pass in passes) {
      // Expected check-ins: passes that activate within the date range
      if (pass.activationDate.isAfter(dateRange.start) &&
          pass.activationDate
              .isBefore(dateRange.end.add(const Duration(days: 1)))) {
        expectedCheckIns++;
      }

      // Expected check-outs: passes that expire within the date range
      if (pass.expiresAt.isAfter(dateRange.start) &&
          pass.expiresAt.isBefore(dateRange.end.add(const Duration(days: 1)))) {
        expectedCheckOuts++;
      }
    }

    debugPrint(
        '🚗 Expected check-ins: $expectedCheckIns, check-outs: $expectedCheckOuts');

    return {
      'expectedCheckIns': expectedCheckIns,
      'expectedCheckOuts': expectedCheckOuts,
    };
  }

  /// Calculate vehicle type forecast
  static Map<String, VehicleTypeForecast> _calculateVehicleTypeForecast(
    List<PurchasedPass> passes,
  ) {
    if (passes.isEmpty) {
      debugPrint('🚙 No passes found for vehicle type forecast');
      return {};
    }

    final Map<String, List<PurchasedPass>> groupedByType = {};

    for (final pass in passes) {
      final vehicleType = _getVehicleTypeFromPass(pass);
      groupedByType.putIfAbsent(vehicleType, () => []).add(pass);
    }

    final Map<String, VehicleTypeForecast> forecast = {};

    for (final entry in groupedByType.entries) {
      final vehicleType = entry.key;
      final typePasses = entry.value;

      final expectedCheckIns = typePasses.length;
      final expectedCheckOuts = typePasses.length;
      final expectedRevenue =
          typePasses.fold<double>(0.0, (sum, p) => sum + p.amount);

      forecast[vehicleType] = VehicleTypeForecast(
        vehicleType: vehicleType,
        expectedCheckIns: expectedCheckIns,
        expectedCheckOuts: expectedCheckOuts,
        expectedRevenue: expectedRevenue,
        passCount: typePasses.length,
      );
    }

    debugPrint('🚙 Vehicle type forecast: ${forecast.keys.join(', ')}');
    return forecast;
  }

  /// Calculate pass forecast
  static Map<String, dynamic> _calculatePassForecast(
    List<PurchasedPass> passes,
    ForecastDateRange dateRange,
  ) {
    final List<PassForecast> upcomingPasses = [];

    for (final pass in passes) {
      final passType = _getPassTypeFromDescription(pass.passDescription);
      final willCheckIn = pass.activationDate.isAfter(dateRange.start) &&
          pass.activationDate
              .isBefore(dateRange.end.add(const Duration(days: 1)));
      final willCheckOut = pass.expiresAt.isAfter(dateRange.start) &&
          pass.expiresAt.isBefore(dateRange.end.add(const Duration(days: 1)));

      if (willCheckIn || willCheckOut) {
        upcomingPasses.add(PassForecast(
          passId: pass.passId,
          passType: passType,
          vehicleDescription: pass.displayVehicleDescription,
          activationDate: pass.activationDate,
          expirationDate: pass.expiresAt,
          amount: pass.amount,
          currency: pass.currency,
          status: pass.status,
          willCheckIn: willCheckIn,
          willCheckOut: willCheckOut,
          profileId: pass.profileId,
        ));
      }
    }

    // Sort by activation date
    upcomingPasses.sort((a, b) => a.activationDate.compareTo(b.activationDate));

    return {
      'upcomingPasses': upcomingPasses,
      'totalCount': upcomingPasses.length,
    };
  }

  /// Calculate revenue forecast
  static Map<String, dynamic> _calculateRevenueForecast(
    List<PurchasedPass> passes,
    ForecastDateRange dateRange,
  ) {
    final expectedRevenue =
        passes.fold<double>(0.0, (sum, p) => sum + p.amount);

    // Calculate daily revenue forecast
    final List<DailyRevenueForecast> dailyForecast = [];
    final currentDate = DateTime(
        dateRange.start.year, dateRange.start.month, dateRange.start.day);
    final endDate =
        DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day);

    DateTime iterDate = currentDate;
    while (iterDate.isBefore(endDate) || iterDate.isAtSameMomentAs(endDate)) {
      final nextDay = iterDate.add(const Duration(days: 1));
      final dayPasses = passes
          .where((p) =>
              p.activationDate.isAfter(iterDate) &&
              p.activationDate.isBefore(nextDay))
          .toList();

      final checkInPasses = passes
          .where((p) =>
              p.activationDate.isAfter(iterDate) &&
              p.activationDate.isBefore(nextDay))
          .length;

      final checkOutPasses = passes
          .where((p) =>
              p.expiresAt.isAfter(iterDate) && p.expiresAt.isBefore(nextDay))
          .length;

      dailyForecast.add(DailyRevenueForecast(
        date: iterDate,
        expectedRevenue:
            dayPasses.fold<double>(0.0, (sum, p) => sum + p.amount),
        expectedCheckIns: checkInPasses,
        expectedCheckOuts: checkOutPasses,
        passCount: dayPasses.length,
      ));

      iterDate = nextDay;
    }

    return {
      'expectedRevenue': expectedRevenue,
      'dailyForecast': dailyForecast,
    };
  }

  /// Get date range based on filter
  static ForecastDateRange _getDateRange(
    String dateFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (dateFilter) {
      case 'today':
        return ForecastDateRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        );
      case 'tomorrow':
        final tomorrow = today.add(const Duration(days: 1));
        return ForecastDateRange(
          start: tomorrow,
          end: tomorrow.add(const Duration(days: 1)),
        );
      case 'next_week':
        final nextWeekStart = today.add(Duration(days: 7 - now.weekday + 1));
        return ForecastDateRange(
          start: nextWeekStart,
          end: nextWeekStart.add(const Duration(days: 7)),
        );
      case 'next_month':
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        final nextMonthEnd = DateTime(now.year, now.month + 2, 0);
        return ForecastDateRange(
          start: nextMonth,
          end: nextMonthEnd,
        );
      case 'custom':
        return ForecastDateRange(
          start: customStartDate ?? today,
          end: customEndDate ?? today.add(const Duration(days: 1)),
        );
      default:
        return ForecastDateRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        );
    }
  }

  /// Get comparison date range
  static ForecastDateRange _getComparisonDateRange(
    ForecastDateRange currentRange,
    String comparisonType,
  ) {
    final duration = currentRange.end.difference(currentRange.start);

    switch (comparisonType) {
      case 'previous_period':
        return ForecastDateRange(
          start: currentRange.start.subtract(duration),
          end: currentRange.start,
        );
      case 'same_period_last_year':
        return ForecastDateRange(
          start: DateTime(
            currentRange.start.year - 1,
            currentRange.start.month,
            currentRange.start.day,
          ),
          end: DateTime(
            currentRange.end.year - 1,
            currentRange.end.month,
            currentRange.end.day,
          ),
        );
      default:
        return ForecastDateRange(
          start: currentRange.start.subtract(duration),
          end: currentRange.start,
        );
    }
  }

  /// Filter passes to include only those relevant to the forecast period
  static List<PurchasedPass> _filterPassesForForecast(
    List<PurchasedPass> passes,
    ForecastDateRange dateRange,
  ) {
    return passes.where((pass) {
      // Include passes that activate within the forecast period (check-ins)
      final activatesInPeriod = pass.activationDate.isAfter(dateRange.start) &&
          pass.activationDate
              .isBefore(dateRange.end.add(const Duration(days: 1)));

      // Include passes that expire within the forecast period (check-outs)
      final expiresInPeriod = pass.expiresAt.isAfter(dateRange.start) &&
          pass.expiresAt.isBefore(dateRange.end.add(const Duration(days: 1)));

      return activatesInPeriod || expiresInPeriod;
    }).toList();
  }

  /// Helper methods
  static String _getVehicleTypeFromPass(PurchasedPass pass) {
    // Debug logging to understand what we're working with
    debugPrint('🚗 Vehicle Type Detection:');
    debugPrint('  - vehicleTypeLabel: "${pass.vehicleTypeLabel}"');
    debugPrint('  - vehicleTypeDescription: "${pass.vehicleTypeDescription}"');
    debugPrint('  - vehicleDescription: "${pass.vehicleDescription}"');
    debugPrint('  - vehicleMake: "${pass.vehicleMake}"');
    debugPrint('  - vehicleModel: "${pass.vehicleModel}"');

    // First priority: Use the actual vehicle type from the database relationship
    if (pass.vehicleTypeLabel != null && pass.vehicleTypeLabel!.isNotEmpty) {
      debugPrint('  → Using database vehicle type: ${pass.vehicleTypeLabel}');
      return pass.vehicleTypeLabel!;
    }

    // Fallback: Try to infer from vehicle make/model/description (legacy logic)
    final description = pass.vehicleDescription.toLowerCase();
    final displayDescription = pass.displayVehicleDescription.toLowerCase();
    final fullDescription = '$description $displayDescription';
    final passDescription = pass.passDescription.toLowerCase();

    // Check vehicle make if available
    if (pass.vehicleMake != null && pass.vehicleMake!.isNotEmpty) {
      final make = pass.vehicleMake!.toLowerCase();
      if ([
        'toyota',
        'honda',
        'ford',
        'bmw',
        'mercedes',
        'audi',
        'volkswagen',
        'nissan',
        'tesla'
      ].contains(make)) {
        debugPrint('  → Detected as Car (from make: $make)');
        return 'Car';
      }
      if (['scania', 'volvo', 'man', 'daf', 'iveco'].contains(make)) {
        debugPrint('  → Detected as Truck (from make: $make)');
        return 'Truck';
      }
      if (['yamaha', 'kawasaki', 'suzuki', 'harley'].contains(make)) {
        debugPrint('  → Detected as Motorcycle (from make: $make)');
        return 'Motorcycle';
      }
    }

    // Check descriptions
    if (fullDescription.contains('car') ||
        fullDescription.contains('sedan') ||
        fullDescription.contains('suv')) {
      debugPrint('  → Detected as Car (from description)');
      return 'Car';
    }
    if (fullDescription.contains('truck') ||
        fullDescription.contains('lorry')) {
      debugPrint('  → Detected as Truck (from description)');
      return 'Truck';
    }
    if (fullDescription.contains('bus') || fullDescription.contains('coach')) {
      debugPrint('  → Detected as Bus (from description)');
      return 'Bus';
    }
    if (fullDescription.contains('motorcycle') ||
        fullDescription.contains('bike')) {
      debugPrint('  → Detected as Motorcycle (from description)');
      return 'Motorcycle';
    }
    if (fullDescription.contains('van')) {
      debugPrint('  → Detected as Van (from description)');
      return 'Van';
    }

    // Infer from pass type - this should be the most common case for tourist passes
    if (passDescription.contains('tourist') ||
        passDescription.contains('visitor') ||
        passDescription.contains('personal')) {
      debugPrint(
          '  → Detected as Car (from pass type: tourist/visitor/personal)');
      return 'Car';
    }
    if (passDescription.contains('commercial') ||
        passDescription.contains('business')) {
      debugPrint('  → Detected as Van (from pass type: commercial/business)');
      return 'Van';
    }

    // Default to Car for most general passes (tourists typically use cars)
    if (displayDescription.contains('general pass') || description.isEmpty) {
      debugPrint('  → Defaulting to Car (general pass or empty description)');
      return 'Car';
    }

    debugPrint('  → Defaulting to Other (no matches found)');
    return 'Other';
  }

  static String _getPassTypeFromDescription(String description) {
    final lowerDesc = description.toLowerCase();
    if (lowerDesc.contains('tourist')) return 'Tourist';
    if (lowerDesc.contains('business')) return 'Business';
    if (lowerDesc.contains('transit')) return 'Transit';
    if (lowerDesc.contains('commercial')) return 'Commercial';
    if (lowerDesc.contains('diplomatic')) return 'Diplomatic';
    return 'General';
  }

  static String _getTopVehicleType(Map<String, VehicleTypeForecast> breakdown) {
    if (breakdown.isEmpty) return 'N/A';

    String topType = 'N/A';
    int maxCount = 0;

    for (final entry in breakdown.entries) {
      final totalCount =
          entry.value.expectedCheckIns + entry.value.expectedCheckOuts;
      if (totalCount > maxCount) {
        maxCount = totalCount;
        topType = entry.key;
      }
    }

    return topType;
  }
}

/// Forecast Date Range helper class
class ForecastDateRange {
  final DateTime start;
  final DateTime end;

  ForecastDateRange({required this.start, required this.end});
}
