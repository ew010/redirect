import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:flutter/material.dart';
import '../services/root_service.dart';
import 'app_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RootService _rootService = RootService();
  bool _hasRoot = false;
  List<AppInfo> _apps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final hasRoot = await _rootService.requestRoot();
    if (mounted) {
      setState(() {
        _hasRoot = hasRoot;
      });
    }

    if (hasRoot) {
      await _loadApps();
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadApps() async {
    setState(() {
      _isLoading = true;
    });
    // Getting all apps can be slow, maybe filter system apps out initially or allow toggle
    final apps = await InstalledApps.getInstalledApps(
      true, // excludeSystemApps
      true, // withIcon
    );
    
    // Sort by name
    apps.sort((a, b) => (a.name ?? "").toLowerCase().compareTo((b.name ?? "").toLowerCase()));

    if (mounted) {
      setState(() {
        _apps = apps;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasRoot) {
      return Scaffold(
        appBar: AppBar(title: const Text('Data Redirector')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Root Access Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Please grant root access to use this app.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _init,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApps,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _apps.length,
              itemBuilder: (context, index) {
                final app = _apps[index];
                return ListTile(
                  leading: app.icon != null
                      ? Image.memory(app.icon!, width: 40)
                      : const Icon(Icons.android),
                  title: Text(app.name ?? app.packageName ?? "Unknown"),
                  subtitle: Text(app.packageName ?? ""),
                  onTap: () {
                    if (app.packageName == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppDetailsScreen(app: app),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
