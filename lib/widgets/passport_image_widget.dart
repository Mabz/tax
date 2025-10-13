import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/image_picker_service.dart';

class PassportImageWidget extends StatefulWidget {
  final String? currentImageUrl;
  final Function(String?) onImageUpdated;
  final double? width;

  const PassportImageWidget({
    super.key,
    this.currentImageUrl,
    required this.onImageUpdated,
    this.width,
  });

  @override
  State<PassportImageWidget> createState() => _PassportImageWidgetState();
}

class _PassportImageWidgetState extends State<PassportImageWidget> {
  bool _isUploading = false;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.currentImageUrl;
  }

  @override
  void didUpdateWidget(PassportImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentImageUrl != widget.currentImageUrl) {
      setState(() {
        _currentImageUrl = widget.currentImageUrl;
      });
    }
  }

  Future<void> _takePassportPhoto() async {
    try {
      // Check if image picker is available
      final isAvailable = await ImagePickerService.isAvailable();
      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera is not available on this device'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show camera/gallery options
      final result = await ImagePickerService.showImageSourceDialog(context);

      if (!mounted) return;
      if (result == null) return;

      setState(() => _isUploading = true);

      String imageUrl;

      if (kIsWeb || result.file == null) {
        // For web or when file is not available, use bytes
        imageUrl = await StorageService.uploadPassportImageFromBytes(
            result.bytes, result.name);
      } else {
        // For mobile, use file
        imageUrl = await StorageService.uploadPassportImage(result.file!);
      }

      // Update local state immediately
      setState(() {
        _currentImageUrl = imageUrl;
        _isUploading = false;
      });

      // Notify parent
      widget.onImageUpdated(imageUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passport page uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload passport page: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removePassportPhoto() async {
    if (_currentImageUrl == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Passport Page'),
        content:
            const Text('Are you sure you want to remove your passport page?'),
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
      await StorageService.deleteFile(_currentImageUrl!);

      setState(() {
        _currentImageUrl = null;
        _isUploading = false;
      });

      // Notify parent
      widget.onImageUpdated(null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passport page removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove passport page: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewPassportPhoto() {
    if (_currentImageUrl != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Passport Page',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _currentImageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, size: 64, color: Colors.red),
                              SizedBox(height: 16),
                              Text('Error loading passport page'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showImageOptions() {
    if (_currentImageUrl != null) {
      // If image exists, show options including view and remove
      showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Passport Page Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Replace with New Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePassportPhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('View Page'),
                onTap: () {
                  Navigator.pop(context);
                  _viewPassportPhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Page',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removePassportPhoto();
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
    } else {
      // If no image, directly show camera/gallery picker
      _takePassportPhoto();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Passport aspect ratio: 4.9" × 3.4" = 1.44:1
    const double passportAspectRatio = 4.9 / 3.4;

    return GestureDetector(
      onTap: _showImageOptions,
      child: AspectRatio(
        aspectRatio: passportAspectRatio,
        child: Container(
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _isUploading
              ? Container(
                  color: Colors.grey.shade50,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Uploading...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                )
              : _currentImageUrl != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            _currentImageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade100,
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error,
                                        size: 32, color: Colors.red),
                                    SizedBox(height: 4),
                                    Text(
                                      'Error loading page',
                                      style: TextStyle(fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: _takePassportPhoto,
                                  icon: const Icon(Icons.edit,
                                      color: Colors.white, size: 16),
                                  constraints: const BoxConstraints(
                                      minWidth: 24, minHeight: 24),
                                  padding: const EdgeInsets.all(4),
                                ),
                                IconButton(
                                  onPressed: _viewPassportPhoto,
                                  icon: const Icon(Icons.visibility,
                                      color: Colors.white, size: 16),
                                  constraints: const BoxConstraints(
                                      minWidth: 24, minHeight: 24),
                                  padding: const EdgeInsets.all(4),
                                ),
                                IconButton(
                                  onPressed: _removePassportPhoto,
                                  icon: const Icon(Icons.delete,
                                      color: Colors.white, size: 16),
                                  constraints: const BoxConstraints(
                                      minWidth: 24, minHeight: 24),
                                  padding: const EdgeInsets.all(4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 32,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Passport Page',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '4.9" × 3.4"',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to add passport page',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
