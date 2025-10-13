import 'package:flutter/material.dart';
import 'owner_details_popup.dart';

class OwnerDetailsButton extends StatelessWidget {
  final String ownerId;
  final String? ownerName;
  final ButtonStyle? style;
  final bool isIconButton;
  final String? buttonText;

  const OwnerDetailsButton({
    super.key,
    required this.ownerId,
    this.ownerName,
    this.style,
    this.isIconButton = false,
    this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    if (isIconButton) {
      return IconButton(
        onPressed: () => _showOwnerDetails(context),
        icon: const Icon(Icons.person_search),
        tooltip: 'View Owner Details',
        style: style,
      );
    }

    return ElevatedButton.icon(
      onPressed: () => _showOwnerDetails(context),
      icon: const Icon(Icons.person_search, size: 18),
      label: Text(buttonText ?? 'Owner Details'),
      style: style ??
          ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
    );
  }

  void _showOwnerDetails(BuildContext context) {
    // Validate UUID before showing popup
    if (!_isValidUUID(ownerId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Owner information is not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => OwnerDetailsPopup(
        ownerId: ownerId,
        ownerName: ownerName,
      ),
    );
  }

  bool _isValidUUID(String uuid) {
    if (uuid.isEmpty) return false;

    // UUID regex pattern
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

    return uuidRegex.hasMatch(uuid);
  }
}

// Compact version for use in lists
class CompactOwnerDetailsButton extends StatelessWidget {
  final String ownerId;
  final String? ownerName;

  const CompactOwnerDetailsButton({
    super.key,
    required this.ownerId,
    this.ownerName,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showOwnerDetails(context),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue.shade200),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person,
              size: 14,
              color: Colors.blue.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              'View Details',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOwnerDetails(BuildContext context) {
    // Validate UUID before showing popup
    if (!_isValidUUID(ownerId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Owner information is not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => OwnerDetailsPopup(
        ownerId: ownerId,
        ownerName: ownerName,
      ),
    );
  }

  bool _isValidUUID(String uuid) {
    if (uuid.isEmpty) return false;

    // UUID regex pattern
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

    return uuidRegex.hasMatch(uuid);
  }
}
