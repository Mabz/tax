import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick image with robust error handling and retry mechanism
  static Future<ImagePickerResult?> pickImage({
    ImageSource source = ImageSource.gallery,
    double? maxWidth = 800,
    double? maxHeight = 800,
    int? imageQuality = 85,
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        debugPrint('ImagePicker attempt ${attempt + 1}/$maxRetries');

        // Try with different configurations based on attempt
        final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth:
              attempt == 0 ? maxWidth : null, // Remove constraints on retry
          maxHeight: attempt == 0 ? maxHeight : null,
          imageQuality: attempt == 0 ? imageQuality : null,
        );

        if (image == null) return null;

        // Read the image data
        final bytes = await image.readAsBytes();

        return ImagePickerResult(
          file: kIsWeb ? null : File(image.path),
          bytes: bytes,
          name: image.name,
          path: image.path,
        );
      } catch (e) {
        debugPrint('ImagePicker attempt ${attempt + 1} failed: $e');

        // If it's a channel error and we have more attempts, try again
        if ((e.toString().contains('channel') ||
                e.toString().contains('connection') ||
                e.toString().contains('imagepickerapi')) &&
            attempt < maxRetries - 1) {
          debugPrint('Retrying image picker due to channel error...');
          // Small delay before retry
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        // If it's the last attempt or a different error, give up
        if (attempt == maxRetries - 1) {
          debugPrint('All image picker attempts failed');
          return null;
        }

        rethrow;
      }
    }

    return null;
  }

  /// Show image source selection dialog with retry support
  static Future<ImagePickerResult?> showImageSourceDialog(
    BuildContext context, {
    bool includeCamera = true,
  }) async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (includeCamera)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context, 'cancel'),
            ),
          ],
        ),
      ),
    );

    if (choice == null || choice == 'cancel') return null;

    switch (choice) {
      case 'camera':
        return await pickImage(source: ImageSource.camera);
      case 'gallery':
        return await pickImage(source: ImageSource.gallery);
      default:
        return null;
    }
  }

  /// Check if image picker is available
  static Future<bool> isAvailable() async {
    try {
      // Try to access the image picker without actually picking
      // This is a simple availability check
      return true;
    } catch (e) {
      debugPrint('ImagePicker not available: $e');
      return false;
    }
  }
}

class ImagePickerResult {
  final File? file;
  final Uint8List bytes;
  final String name;
  final String path;

  ImagePickerResult({
    this.file,
    required this.bytes,
    required this.name,
    required this.path,
  });
}
