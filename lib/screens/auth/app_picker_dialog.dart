import 'package:flutter/material.dart';
import '../../services/usage_stats_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';

class AppPickerDialog extends StatefulWidget {
  final List<String> initialSelectedPackages;

  const AppPickerDialog({
    super.key,
    required this.initialSelectedPackages,
  });

  @override
  State<AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends State<AppPickerDialog> {
  final UsageStatsService _usageService = UsageStatsService();
  List<InstalledApp> _installedApps = [];
  late List<String> _selectedPackages;
  bool _isLoading = true;
  bool _hasPermission = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedPackages = List<String>.from(widget.initialSelectedPackages);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _hasPermission = await _usageService.hasUsagePermission();
    _installedApps = await _usageService.getInstalledApps();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = _installedApps.where((app) {
      return app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 450),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.apps_rounded, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Select Distraction Apps',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, _selectedPackages),
                ),
              ],
            ),
            if (!_hasPermission) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.roastBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.roastOrange.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.roastOrange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Usage Access permission required to detect distraction apps.',
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _usageService.openUsageSettings();
                        await Future.delayed(const Duration(seconds: 2));
                        _loadData();
                      },
                      child: const Text('ENABLE'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search installed apps...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredApps.isEmpty
                      ? const Center(
                          child: Text(
                            'No installed apps found.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredApps.length,
                          itemBuilder: (context, index) {
                            final app = filteredApps[index];
                            final isSelected = _selectedPackages.contains(app.packageName);

                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: AppColors.primary,
                              secondary: app.iconBytes != null
                                  ? Image.memory(
                                      app.iconBytes!,
                                      width: 36,
                                      height: 36,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.android),
                                    )
                                  : const Icon(Icons.android, size: 36),
                              title: Text(
                                app.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                app.packageName,
                                style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                              ),
                              onChanged: (bool? val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedPackages.add(app.packageName);
                                  } else {
                                    _selectedPackages.remove(app.packageName);
                                  }
                                });
                              },
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Done (${_selectedPackages.length} selected)',
              onPressed: () => Navigator.pop(context, _selectedPackages),
            ),
          ],
        ),
      ),
    );
  }
}
