// Mobile implementation - uses actual mobile_scanner package
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;

// Re-export mobile scanner classes with our own names
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
    return ms.MobileScanner(
      controller: controller?._controller,
      onDetect: (capture) {
        if (onDetect != null) {
          onDetect!(PlatformBarcodeCapture(capture));
        }
      },
    );
  }
}

class PlatformScannerController {
  final ms.MobileScannerController _controller = ms.MobileScannerController();

  void start() => _controller.start();
  void stop() => _controller.stop();
  void dispose() => _controller.dispose();
}

class PlatformBarcodeCapture {
  final ms.BarcodeCapture _capture;

  PlatformBarcodeCapture(this._capture);

  List<PlatformBarcode> get barcodes =>
      _capture.barcodes.map((b) => PlatformBarcode(b)).toList();
}

class PlatformBarcode {
  final ms.Barcode _barcode;

  PlatformBarcode(this._barcode);

  String? get rawValue => _barcode.rawValue;
}
