import 'package:flutter/material.dart';
import 'lib/screens/border_analytics_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enhanced Border Analytics Test',
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      home: BorderAnalyticsScreen(
        authorityId: 'test-authority-id',
        authorityName: 'Test Authority',
      ),
    );
  }
}

// Test the enhanced features:
// 1. Metric cards now have info icons that show detailed descriptions
// 2. Recent activity items are tappable and show detailed information
// 3. Activity descriptions are dynamic based on selected timeframe
// 4. Enhanced UI with better visual hierarchy and information density
