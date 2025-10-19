import 'package:flutter/material.dart';
import 'lib/screens/official_schedule_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Official Schedule Test',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const OfficialScheduleScreen(),
    );
  }
}
