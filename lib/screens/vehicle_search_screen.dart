import 'package:flutter/material.dart';
import '../models/purchased_pass.dart';
import '../widgets/improved_vehicle_search_widget.dart';

class VehicleSearchScreen extends StatelessWidget {
  final String title;
  final String? initialSearchTerm;
  final bool showAsModal;

  const VehicleSearchScreen({
    super.key,
    this.title = 'Search Vehicle Passes',
    this.initialSearchTerm,
    this.showAsModal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Don't resize when keyboard appears - let it cover the watermark
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: showAsModal
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: ImprovedVehicleSearchWidget(
          initialSearchTerm: initialSearchTerm,
          onPassSelected: (pass) {
            // Return the selected pass to the previous screen
            Navigator.of(context).pop(pass);
          },
        ),
      ),
    );
  }

  /// Show as a modal bottom sheet
  static Future<PurchasedPass?> showModal(
    BuildContext context, {
    String title = 'Search Vehicle Passes',
    String? initialSearchTerm,
  }) async {
    return await showModalBottomSheet<PurchasedPass>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: VehicleSearchScreen(
          title: title,
          initialSearchTerm: initialSearchTerm,
          showAsModal: true,
        ),
      ),
    );
  }

  /// Show as a full screen
  static Future<PurchasedPass?> showFullScreen(
    BuildContext context, {
    String title = 'Search Vehicle Passes',
    String? initialSearchTerm,
  }) async {
    return await Navigator.of(context).push<PurchasedPass>(
      MaterialPageRoute(
        builder: (context) => VehicleSearchScreen(
          title: title,
          initialSearchTerm: initialSearchTerm,
        ),
      ),
    );
  }
}
