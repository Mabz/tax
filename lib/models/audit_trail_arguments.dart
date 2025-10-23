class LocationBounds {
  final double centerLat;
  final double centerLng;
  final double radiusKm;

  LocationBounds({
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
  });
}

class AuditTrailArguments {
  final String? selectedBorderId;
  final String? borderName;
  final String timeframe;
  final String? officialId;
  final String? officialName;
  final LocationBounds? coordinates;
  final bool showBorderEntriesOnly;
  final bool showOutliersOnly;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  AuditTrailArguments({
    this.selectedBorderId,
    this.borderName,
    required this.timeframe,
    this.officialId,
    this.officialName,
    this.coordinates,
    this.showBorderEntriesOnly = true,
    this.showOutliersOnly = false,
    this.customStartDate,
    this.customEndDate,
  });
}
