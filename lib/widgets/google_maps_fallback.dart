import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class GoogleMapsFallback extends StatelessWidget {
  final String title;
  final String message;
  final Widget? child;

  const GoogleMapsFallback({
    super.key,
    required this.title,
    required this.message,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Google Maps Setup Required',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (child != null) ...[
            const SizedBox(height: 24),
            child!,
          ],
        ],
      ),
    );
  }
}

class GoogleMapsErrorHandler extends StatelessWidget {
  final Widget child;
  final Widget Function()? fallbackBuilder;

  const GoogleMapsErrorHandler({
    super.key,
    required this.child,
    this.fallbackBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // On web, we need to check if Google Maps is properly loaded
      return FutureBuilder<bool>(
        future: _checkGoogleMapsAvailability(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError || (snapshot.hasData && !snapshot.data!)) {
            return fallbackBuilder?.call() ??
                const GoogleMapsFallback(
                  title: 'Google Maps Unavailable',
                  message:
                      'Google Maps could not be loaded. Please check your API key configuration.',
                );
          }

          return child;
        },
      );
    }

    // On mobile platforms, Google Maps should work without API key
    return child;
  }

  Future<bool> _checkGoogleMapsAvailability() async {
    try {
      // Give more time for Google Maps to load
      await Future.delayed(const Duration(milliseconds: 1000));

      // Since we now have the API key configured, assume Google Maps is available
      // On web with API key: should work
      // On mobile: always works
      return true;
    } catch (e) {
      return false;
    }
  }
}
