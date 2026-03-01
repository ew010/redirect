import 'package:device_apps/device_apps.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/root_service.dart';

class AppDetailsScreen extends StatefulWidget {
  final Application app;

  const AppDetailsScreen({super.key, required this.app});

  @override
  State<AppDetailsScreen> createState() => _AppDetailsScreenState();
}

class _AppDetailsScreenState extends State<AppDetailsScreen> {
  final RootService _rootService = RootService();
  final TextEditingController _pathController = TextEditingController();
  
  bool _isLoading = true;
  bool _isRedirected = false;
  String? _currentTarget;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    try {
      final isRedirected = await _rootService.isRedirected(widget.app.packageName);
      String? target;
      if (isRedirected) {
        target = await _rootService.getRedirectTarget(widget.app.packageName);
      }
      
      if (mounted) {
        setState(() {
          _isRedirected = isRedirected;
          _currentTarget = target;
          _isLoading = false;
          if (target != null) {
            _pathController.text = target; // Show where it is currently
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _pathController.text = selectedDirectory;
      });
    }
  }

  Future<void> _redirect() async {
    final targetPath = _pathController.text.trim();
    if (targetPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or select a target path')),
      );
      return;
    }

    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Redirection'),
        content: Text(
          'WARNING: This operation requires root access and modifies system files.\n\n'
          'We will move data from:\n/data/data/${widget.app.packageName}\n\n'
          'To:\n$targetPath/${widget.app.packageName}\n\n'
          'Ensure the target location supports Linux permissions (ext4/f2fs). '
          'Redirecting to FAT32/exFAT (standard SD cards) WILL likely break the app due to permission loss.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _rootService.redirectAppData(widget.app.packageName, targetPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Redirection successful!')),
        );
        await _checkStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restore() async {
     // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: Text(
          'This will move data back to original location:\n/data/data/${widget.app.packageName}\n\n'
          'And remove the data from the custom location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _rootService.restoreAppData(widget.app.packageName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restored successfully!')),
        );
        await _checkStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.app.appName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: widget.app is ApplicationWithIcon
                  ? Image.memory((widget.app as ApplicationWithIcon).icon, width: 80)
                  : const Icon(Icons.android, size: 80),
            ),
            const SizedBox(height: 16),
            Center(child: Text(widget.app.packageName, style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(height: 24),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.red.shade100,
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
                
              const SizedBox(height: 16),
              
              Text(
                'Current Status: ${_isRedirected ? "REDIRECTED" : "DEFAULT"}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isRedirected ? Colors.orange : Colors.green,
                  fontSize: 18,
                ),
              ),
              
              if (_isRedirected) ...[
                const SizedBox(height: 8),
                Text('Target: $_currentTarget'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _restore,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore to Default'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 24),
                const Text('Redirect Data To:'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pathController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '/sdcard/MyBackups',
                          labelText: 'Target Directory Path',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: _pickDirectory,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: The app folder will be created inside this directory.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _redirect,
                    icon: const Icon(Icons.directions),
                    label: const Text('Redirect Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
