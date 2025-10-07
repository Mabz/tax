import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class StorageService {
  static const String _bucketName = 'BorderTax';
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Upload a profile image for the current user
  static Future<String> uploadProfileImage(File imageFile) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate a unique filename with user ID prefix
      final fileExtension = path.extension(imageFile.path);
      final fileName =
          '${user.id}/profile_image_${DateTime.now().millisecondsSinceEpoch}$fileExtension';

      debugPrint('StorageService: Uploading file: $fileName');

      // Read file as bytes
      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase Storage
      await _supabase.storage.from(_bucketName).uploadBinary(fileName, bytes);
      debugPrint('StorageService: Upload successful');

      // Get the public URL
      final publicUrl =
          _supabase.storage.from(_bucketName).getPublicUrl(fileName);

      debugPrint('StorageService: Generated public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }

  /// Upload profile image from bytes (for web compatibility)
  static Future<String> uploadProfileImageFromBytes(
      Uint8List bytes, String originalFileName) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate a unique filename with user ID prefix
      final fileExtension = path.extension(originalFileName);
      final fileName =
          '${user.id}/profile_image_${DateTime.now().millisecondsSinceEpoch}$fileExtension';

      // Upload to Supabase Storage
      await _supabase.storage.from(_bucketName).uploadBinary(fileName, bytes);

      // Get the public URL
      final publicUrl =
          _supabase.storage.from(_bucketName).getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }

  /// Delete a profile image
  static Future<void> deleteProfileImage(String imageUrl) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Extract filename from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Find the filename in the path (should be after 'BorderTax')
      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex == -1 || bucketIndex >= pathSegments.length - 1) {
        throw Exception('Invalid image URL format');
      }

      // Get the file path (everything after the bucket name)
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      // Verify the file belongs to the current user
      if (!filePath.startsWith('${user.id}/')) {
        throw Exception('Unauthorized: Cannot delete another user\'s image');
      }

      // Delete from Supabase Storage
      await _supabase.storage.from(_bucketName).remove([filePath]);
    } catch (e) {
      throw Exception('Failed to delete profile image: $e');
    }
  }

  /// List all profile images for the current user
  static Future<List<String>> getUserProfileImages() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // List files in user's folder
      final response =
          await _supabase.storage.from(_bucketName).list(path: '${user.id}/');

      // Convert to public URLs
      final imageUrls = response
          .where((file) => file.name.startsWith('profile_image_'))
          .map((file) => _supabase.storage
              .from(_bucketName)
              .getPublicUrl('${user.id}/${file.name}'))
          .toList();

      return imageUrls;
    } catch (e) {
      throw Exception('Failed to list profile images: $e');
    }
  }
}
