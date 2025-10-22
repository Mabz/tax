import 'package:flutter/material.dart';
import 'lib/screens/border_analytics_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Border Analytics Officials Test',
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
