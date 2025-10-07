import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/profile_management_service.dart';
import '../services/image_picker_service.dart';

class ProfileImageWidget extends StatefulWidget {
  final String? currentImageUrl;
  final double size;
  final bool isEditable;
  final VoidCallback? onImageUpdated;

  const ProfileImageWidget({
    super.key,
    this.currentImageUrl,
    this.size = 80,
    this.isEditable = true,
    this.onImageUpdated,
  });

  @override
  State<ProfileImageWidget> createState() => _ProfileImageWidgetState();
}

class _ProfileImageWidgetState extends State<ProfileImageWidget> {
  bool _isUploading = false;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.currentImageUrl;
  }

  @override
  void didUpdateWidget(ProfileImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentImageUrl != widget.currentImageUrl) {
      debugPrint(
          'ProfileImageWidget: URL changed from ${oldWidget.currentImageUrl} to ${widget.currentImageUrl}');
      setState(() {
        _currentImageUrl = widget.currentImageUrl;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (!widget.isEditable) return;

    try {
      // Check if image picker is available
      final isAvailable = await ImagePickerService.isAvailable();
      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image picker is not available on this device'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Use the robust image picker service
      final result = await ImagePickerService.showImageSourceDialog(context);

      if (!mounted) return;

      if (result == null) return;

      setState(() => _isUploading = true);

      String imageUrl;

      if (kIsWeb || result.file == null) {
        // For web or when file is not available, use bytes
        imageUrl = await StorageService.uploadProfileImageFromBytes(
            result.bytes, result.name);
      } else {
        // For mobile, use file
        imageUrl = await StorageService.uploadProfileImage(result.file!);
      }

      debugPrint('Generated image URL: $imageUrl');

      // Update the profile with the new image URL
      await ProfileManagementService.updateProfileImageUrl(imageUrl);
      debugPrint('Profile updated with image URL');

      // Update local state immediately
      setState(() {
        _currentImageUrl = imageUrl;
        _isUploading = false;
      });

      debugPrint('Local state updated with image URL: $_currentImageUrl');

      // Notify parent to refresh data
      if (widget.onImageUpdated != null) {
        widget.onImageUpdated!();
      }

      // Small delay to ensure database is updated, then refresh again
      await Future.delayed(const Duration(milliseconds: 500));
      if (widget.onImageUpdated != null && mounted) {
        widget.onImageUpdated!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeImage() async {
    if (!widget.isEditable || _currentImageUrl == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Profile Image'),
        content:
            const Text('Are you sure you want to remove your profile image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isUploading = true);

      // Delete from storage
      await StorageService.deleteProfileImage(_currentImageUrl!);

      // Remove from profile
      await ProfileManagementService.removeProfileImageUrl();

      setState(() {
        _currentImageUrl = null;
        _isUploading = false;
      });

      if (widget.onImageUpdated != null) {
        widget.onImageUpdated!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage();
              },
            ),
            if (_currentImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Image',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeImage();
                },
              ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Print the current image URL
    debugPrint('ProfileImageWidget: currentImageUrl = $_currentImageUrl');

    return GestureDetector(
      onTap: widget.isEditable ? _showImageOptions : null,
      child: Stack(
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _isUploading
                  ? Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _currentImageUrl != null
                      ? Image.network(
                          _currentImageUrl!,
                          key: ValueKey(
                              _currentImageUrl), // Force rebuild when URL changes
                          fit: BoxFit.cover,
                          // Add cache busting to ensure fresh image loads
                          headers: {
                            'Cache-Control': 'no-cache',
                          },
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Error loading profile image: $error');
                            return Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.person,
                                size: widget.size * 0.6,
                                color: Colors.grey.shade400,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              debugPrint(
                                  'Profile image loaded successfully: $_currentImageUrl');
                              return child;
                            }
                            return Container(
                              color: Colors.grey.shade100,
                              child: const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: Icon(
                            Icons.person,
                            size: widget.size * 0.6,
                            color: Colors.grey.shade400,
                          ),
                        ),
            ),
          ),
          if (widget.isEditable && !_isUploading)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  _currentImageUrl != null ? Icons.edit : Icons.add,
                  color: Colors.white,
                  size: widget.size * 0.25,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
