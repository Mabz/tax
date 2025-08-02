import 'package:flutter/material.dart';
import '../models/border_type.dart';
import '../services/border_type_service.dart';
import '../services/role_service.dart';

class BorderTypeManagementScreen extends StatefulWidget {
  const BorderTypeManagementScreen({super.key});

  @override
  State<BorderTypeManagementScreen> createState() =>
      _BorderTypeManagementScreenState();
}

class _BorderTypeManagementScreenState
    extends State<BorderTypeManagementScreen> {
  List<BorderType> _borderTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadData();
  }

  Future<void> _checkPermissionsAndLoadData() async {
    try {
      final isSuperuser = await RoleService.isSuperuser();

      if (!isSuperuser) {
        if (mounted) {
          final navigator = Navigator.of(context);
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          navigator.pop();
          scaffoldMessenger.showSnackBar(
            const SnackBar(
                content: Text('Access denied: Superuser role required')),
          );
        }
        return;
      }

      await _loadBorderTypes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking permissions: $e')),
        );
      }
    }
  }

  Future<void> _loadBorderTypes() async {
    try {
      setState(() => _isLoading = true);
      final borderTypes = await BorderTypeService.getAllBorderTypes();
      setState(() {
        _borderTypes = borderTypes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading border types: $e')),
        );
      }
    }
  }

  void _showBorderTypeDialog({BorderType? borderType}) {
    showDialog(
      context: context,
      builder: (context) => _BorderTypeFormDialog(
        borderType: borderType,
        onSave: _loadBorderTypes,
      ),
    );
  }

  void _deleteBorderType(BorderType borderType) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Border Type'),
        content: Text(
          'Are you sure you want to delete "${borderType.label}"?\n\n'
          'This action cannot be undone and may affect existing borders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Capture contexts before async operation
              final navigator = Navigator.of(dialogContext);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              try {
                await BorderTypeService.deleteBorderType(borderType.id);
                if (mounted) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                        content: Text('Border type deleted successfully')),
                  );
                  _loadBorderTypes();
                }
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Error deleting border type: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Border Types'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBorderTypeDialog(),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBorderTypes,
              child: _borderTypes.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.border_all,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No border types found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap the + button to add a border type',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _borderTypes.length,
                      itemBuilder: (context, index) {
                        final borderType = _borderTypes[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.shade100,
                              child: Icon(
                                Icons.border_all,
                                color: Colors.red.shade700,
                              ),
                            ),
                            title: Text(borderType.label),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Code: ${borderType.code}'),
                                if (borderType.description != null)
                                  Text(borderType.description!),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () => _showBorderTypeDialog(
                                      borderType: borderType),
                                  tooltip: 'Edit Border Type',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _deleteBorderType(borderType),
                                  tooltip: 'Delete Border Type',
                                ),
                              ],
                            ),
                            isThreeLine: borderType.description != null,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _BorderTypeFormDialog extends StatefulWidget {
  final BorderType? borderType;
  final VoidCallback onSave;

  const _BorderTypeFormDialog({
    this.borderType,
    required this.onSave,
  });

  @override
  State<_BorderTypeFormDialog> createState() => _BorderTypeFormDialogState();
}

class _BorderTypeFormDialogState extends State<_BorderTypeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _labelController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.borderType != null) {
      _codeController.text = widget.borderType!.code;
      _labelController.text = widget.borderType!.label;
      _descriptionController.text = widget.borderType!.description ?? '';
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _labelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveBorderType() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final code = _codeController.text.trim().toLowerCase();
      final label = _labelController.text.trim();
      final description = _descriptionController.text.trim();

      if (widget.borderType == null) {
        // Create new border type
        await BorderTypeService.createBorderType(
          code: code,
          label: label,
          description: description.isEmpty ? null : description,
        );
      } else {
        // Update existing border type
        await BorderTypeService.updateBorderType(
          id: widget.borderType!.id,
          code: code,
          label: label,
          description: description.isEmpty ? null : description,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.borderType == null
                  ? 'Border type created successfully'
                  : 'Border type updated successfully',
            ),
          ),
        );
        widget.onSave();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving border type: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.borderType == null ? 'Add Border Type' : 'Edit Border Type'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Code *',
                hintText: 'e.g., road, rail, air',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Code is required';
                }
                if (!BorderTypeService.isValidCode(
                    value.trim().toLowerCase())) {
                  return 'Code must be lowercase letters, numbers, and underscores only';
                }
                return null;
              },
              onChanged: (value) {
                // Auto-convert to lowercase
                final selection = _codeController.selection;
                _codeController.value = _codeController.value.copyWith(
                  text: value.toLowerCase(),
                  selection: selection,
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label *',
                hintText: 'e.g., Road Border, Rail Border',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Label is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveBorderType,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.borderType == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}
