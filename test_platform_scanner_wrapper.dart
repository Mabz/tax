import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'lib/utils/platform_scanner.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Platform Scanner Wrapper Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TestHomeScreen(),
    );
  }
}

class TestHomeScreen extends StatefulWidget {
  const TestHomeScreen({super.key});

  @override
  State<TestHomeScreen> createState() => _TestHomeScreenState();
}

class _TestHomeScreenState extends State<TestHomeScreen> {
  PlatformScannerController? controller;

  @override
  void initState() {
    super.initState();
    controller = PlatformScannerController();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Scanner Wrapper Test'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform Detection Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          kIsWeb ? Icons.web : Icons.phone_android,
                          color: kIsWeb
                              ? Colors.blue.shade700
                              : Colors.green.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Platform Scanner Wrapper',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kIsWeb
                                ? Colors.blue.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            kIsWeb ? Colors.blue.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: kIsWeb
                              ? Colors.blue.shade200
                              : Colors.green.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kIsWeb
                                ? '🌐 Web Platform Detected'
                                : '📱 Mobile Platform Detected',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: kIsWeb
                                  ? Colors.blue.shade800
                                  : Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            kIsWeb
                                ? 'Using web_scanner_impl.dart - Shows fallback UI'
                                : 'Using mobile_scanner_impl.dart - Full scanner functionality',
                            style: TextStyle(
                              fontSize: 12,
                              color: kIsWeb
                                  ? Colors.blue.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scanner Test Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scanner Test:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: PlatformScanner(
                          controller: controller,
                          onDetect: (capture) {
                            // Handle barcode detection
                            for (final barcode in capture.barcodes) {
                              if (barcode.rawValue != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Detected: ${barcode.rawValue}'),
                                  ),
                                );
                                break;
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Implementation Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.architecture,
                            color: Colors.purple.shade700, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Implementation Details',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('✅ Platform-specific conditional exports'),
                    const Text('✅ Unified API across platforms'),
                    const Text('✅ No mobile_scanner import on web'),
                    const Text('✅ Prevents dart:html compilation errors'),
                    const Text('✅ Maintains full mobile functionality'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'export \'mobile_scanner_impl.dart\' if (dart.library.html) \'web_scanner_impl.dart\';',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Test controller operations
          try {
            controller?.start();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Scanner started')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        },
        child: const Icon(Icons.play_arrow),
      ),
    );
  }
}
