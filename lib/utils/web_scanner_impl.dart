// Web implementation - provides stub classes
import 'package:flutter/material.dart';

class PlatformScanner extends StatelessWidget {
  final PlatformScannerController? controller;
  final Function(PlatformBarcodeCapture)? onDetect;

  const PlatformScanner({
    super.key,
    this.controller,
    this.onDetect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_android,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'QR Scanning Not Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'QR code scanning is only available on mobile devices.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlatformScannerController {
  void start() {}
  void stop() {}
  void dispose() {}
}

class PlatformBarcodeCapture {
  final List<PlatformBarcode> barcodes = [];
}

class PlatformBarcode {
  final String? rawValue;
  PlatformBarcode(this.rawValue);
}
