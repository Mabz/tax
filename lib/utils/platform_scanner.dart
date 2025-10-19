// Platform-aware scanner wrapper
// Export the platform-appropriate implementation
export 'mobile_scanner_impl.dart'
    if (dart.library.html) 'web_scanner_impl.dart';
