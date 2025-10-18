import 'package:flutter/material.dart';

/// Utility class for consistent role color coding across the app
class RoleColors {
  RoleColors._();

  /// Get role color information for consistent styling
  static RoleColorInfo getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'country admin':
      case 'country administrator':
        return RoleColorInfo(
          backgroundColor: Colors.orange.shade50,
          textColor: Colors.orange.shade700,
          borderColor: Colors.orange.shade200,
          icon: Icons.admin_panel_settings_rounded,
        );
      case 'border official':
        return RoleColorInfo(
          backgroundColor: Colors.red.shade50,
          textColor: Colors.red.shade700,
          borderColor: Colors.red.shade200,
          icon: Icons.security_rounded,
        );
      case 'local authority':
        return RoleColorInfo(
          backgroundColor: Colors.blue.shade50,
          textColor: Colors.blue.shade700,
          borderColor: Colors.blue.shade200,
          icon: Icons.location_city_rounded,
        );
      case 'country auditor':
        return RoleColorInfo(
          backgroundColor: Colors.purple.shade50,
          textColor: Colors.purple.shade700,
          borderColor: Colors.purple.shade200,
          icon: Icons.fact_check_rounded,
        );
      case 'business intelligence':
        return RoleColorInfo(
          backgroundColor: Colors.green.shade50,
          textColor: Colors.green.shade700,
          borderColor: Colors.green.shade200,
          icon: Icons.analytics_rounded,
        );
      case 'border manager':
        return RoleColorInfo(
          backgroundColor: Colors.orange.shade50,
          textColor: Colors.orange.shade700,
          borderColor: Colors.orange.shade200,
          icon: Icons.manage_accounts_rounded,
        );
      case 'compliance officer':
        return RoleColorInfo(
          backgroundColor: Colors.teal.shade50,
          textColor: Colors.teal.shade700,
          borderColor: Colors.teal.shade200,
          icon: Icons.verified_user_rounded,
        );
      default:
        return RoleColorInfo(
          backgroundColor: Colors.grey.shade50,
          textColor: Colors.grey.shade700,
          borderColor: Colors.grey.shade200,
          icon: Icons.person_rounded,
        );
    }
  }

  /// Build a role chip widget with consistent styling
  static Widget buildRoleChip(String role, {double fontSize = 11}) {
    final colorInfo = getRoleColor(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorInfo.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorInfo.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            colorInfo.icon,
            size: fontSize + 1,
            color: colorInfo.textColor,
          ),
          const SizedBox(width: 4),
          Text(
            role,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: colorInfo.textColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a compact role indicator for drawer/small spaces
  static Widget buildCompactRoleIndicator(String role) {
    final colorInfo = getRoleColor(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorInfo.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorInfo.borderColor, width: 0.5),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: colorInfo.textColor,
        ),
      ),
    );
  }
}

/// Role color information container
class RoleColorInfo {
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final IconData icon;

  const RoleColorInfo({
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.icon,
  });
}
