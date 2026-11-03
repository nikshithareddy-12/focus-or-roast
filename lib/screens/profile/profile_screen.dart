import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../models/distraction_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/account_storage_service.dart';
import '../../services/native_usage_service.dart';
import '../../providers/distraction_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Cache of packageName -> app label for profile display
  Map<String, String> _packageLabels = {};
  bool _labelsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPackageLabels();
  }

  Future<void> _loadPackageLabels() async {
    if (_labelsLoaded) return;
    try {
      final apps = await NativeUsageService.getInstalledApps();
      final map = <String, String>{};
      for (final app in apps) {
        map[app.packageName] = app.name;
      }
      if (mounted) {
        setState(() {
          _packageLabels = map;
          _labelsLoaded = true;
        });
      }
    } catch (_) {
      _labelsLoaded = true;
    }
  }
  void _showAddAccountDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Account'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Sign in to add another Firebase account to this device.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        errorMsg!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  CustomTextField(
                    controller: emailController,
                    label: 'Email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => val == null || !val.contains('@')
                        ? 'Enter valid email'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: passwordController,
                    label: 'Password',
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    validator: (val) => val == null || val.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogCtx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() {
                        isLoading = true;
                        errorMsg = null;
                      });

                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final navigator = Navigator.of(dialogCtx);
                      final messenger = ScaffoldMessenger.of(context);
                      final success = await authProvider.login(
                        emailController.text.trim(),
                        passwordController.text,
                        context: context,
                      );

                      if (success && mounted) {
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Account added & switched successfully!')),
                        );
                      } else {
                        setState(() {
                          isLoading = false;
                          errorMsg = authProvider.errorMessage ?? 'Failed to authenticate account.';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('SIGN IN'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSwitchAccountDialog(SavedAccountModel targetAccount) {
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Switch to @${targetAccount.username}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter password for ${targetAccount.email} to switch accounts:',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (errorMsg != null) ...[
                Text(
                  errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
                const SizedBox(height: 8),
              ],
              CustomTextField(
                controller: passwordController,
                label: 'Password',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) return;
                      setState(() {
                        isLoading = true;
                        errorMsg = null;
                      });

                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final navigator = Navigator.of(dialogCtx);
                      final messenger = ScaffoldMessenger.of(context);
                      final username = targetAccount.username;
                      final success = await authProvider.switchAccount(
                        email: targetAccount.email,
                        password: passwordController.text,
                        context: context,
                      );

                      if (success && mounted) {
                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(content: Text('Switched to @$username')),
                        );
                      } else {
                        setState(() {
                          isLoading = false;
                          errorMsg = authProvider.errorMessage ?? 'Authentication failed.';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('SWITCH'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveAccount(SavedAccountModel account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Account'),
        content: Text('Remove this account (@${account.username}) from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.removeAccountFromDevice(account.uid, context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed @${account.username} from this device.')),
                );
              }
            },
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }

  void _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout(context: context);

    if (mounted) {
      final saved = authProvider.savedAccounts;
      if (saved.isNotEmpty) {
        _showPostLogoutAccountPicker();
      } else {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
      }
    }
  }

  void _showPostLogoutAccountPicker() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose an account to continue.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...authProvider.savedAccounts.map((acc) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(acc.name.isNotEmpty ? acc.name : '@${acc.username}'),
                    subtitle: Text('@${acc.username} • ${acc.email}'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showSwitchAccountDialog(acc);
                    },
                  )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add, color: AppColors.primary),
                title: const Text('Sign in with another account', style: TextStyle(color: AppColors.primary)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDistractionAppsModal() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    final Set<String> selectedPackages = Set.from(user.distractionApps);
    print('[FocusRoast_Diag] Initial selected packages from profile: $selectedPackages');
    List<DistractionModel> installedApps = [];
    bool loading = true;
    bool hasFetched = false;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          if (!hasFetched) {
            hasFetched = true;
            NativeUsageService.getInstalledApps().then((apps) {
              if (ctx.mounted) {
                setModalState(() {
                  installedApps = apps;
                  loading = false;
                });
              }
            });
          }

          final filteredApps = searchQuery.isEmpty
              ? installedApps
              : installedApps
                  .where((a) =>
                      a.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                      a.packageName.toLowerCase().contains(searchQuery.toLowerCase()))
                  .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Distraction Apps',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const Text(
                  'Select apps you want FocusRoast to block during focus sessions.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),

                // Search Box
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search installed apps...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      searchQuery = val.trim();
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Apps List
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredApps.isEmpty
                          ? const Center(child: Text('No apps found.'))
                          : ListView.builder(
                              itemCount: filteredApps.length,
                              itemBuilder: (context, index) {
                                final app = filteredApps[index];
                                final isSelected = selectedPackages.contains(app.packageName);
                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        selectedPackages.add(app.packageName);
                                      } else {
                                        selectedPackages.remove(app.packageName);
                                      }
                                      print('[FocusRoast_Diag] Selected packages in Edit Distraction Apps: $selectedPackages');
                                    });
                                  },
                                  secondary: app.iconBytes != null
                                      ? Image.memory(app.iconBytes!, width: 36, height: 36)
                                      : const Icon(Icons.android),
                                  title: Text(app.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    app.packageName,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                );
                              },
                            ),
                ),
                const SizedBox(height: 12),

                CustomButton(
                  text: 'Save Distraction Apps (${selectedPackages.length})',
                  icon: Icons.check,
                  onPressed: () async {
                    final navigator = Navigator.of(sheetCtx);
                    final messenger = ScaffoldMessenger.of(context);
                    final distractionProvider = Provider.of<DistractionProvider>(context, listen: false);
                    await authProvider.updateDistractionApps(selectedPackages.toList());
                    distractionProvider.updateBlockedPackages(selectedPackages);
                    if (mounted) {
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Updated distraction apps (${selectedPackages.length} selected).'),
                          backgroundColor: AppColors.successGreen,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Accounts'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Account Card
            const Text(
              'Profile',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(
                            user != null && user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'User',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '@${user?.username ?? 'username'}',
                                style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                user?.email ?? '',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Privacy Settings
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Allow others to add me to groups',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Controls whether other users can send group invitations to your account.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      value: user?.allowGroupInvites ?? true,
                      onChanged: (val) async {
                        await authProvider.updatePrivacySetting(val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Distraction Apps Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Distraction Apps',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                TextButton.icon(
                  onPressed: _showEditDistractionAppsModal,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Apps'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user == null || user.distractionApps.isEmpty)
                      const Text(
                        'No distraction apps configured yet. Tap "Edit Apps" to select apps you want FocusRoast to block.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      )
                    else ...[
                      Text(
                        '${user.distractionApps.length} app${user.distractionApps.length == 1 ? '' : 's'} monitored during focus sessions:',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: user.distractionApps.map((pkg) {
                          // Show resolved app label, fall back to cleaned package name
                          final label = _packageLabels[pkg] ??
                              pkg.split('.').where((p) =>
                                p.isNotEmpty && p.toLowerCase() != 'android' && p.toLowerCase() != 'com'
                              ).map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
                          return Chip(
                            avatar: const Icon(Icons.block, size: 16, color: AppColors.roastOrange),
                            label: Text(label, style: const TextStyle(fontSize: 12)),
                            backgroundColor: AppColors.surfaceVariant,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Accounts List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Accounts',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                TextButton.icon(
                  onPressed: _showAddAccountDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('+ Add Account'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Accounts List
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  if (authProvider.savedAccounts.isEmpty && user != null)
                    ListTile(
                      leading: const Text('✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                      title: Text('@${user.username}'),
                      subtitle: Text(user.email),
                    ),
                  ...authProvider.savedAccounts.map((acc) {
                    final isCurrent = user != null && user.uid == acc.uid;
                    return ListTile(
                      leading: isCurrent
                          ? const Text('✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18))
                          : const SizedBox(width: 18),
                      title: Text('@${acc.username}'),
                      subtitle: Text(acc.email),
                      trailing: PopupMenuButton<String>(
                        onSelected: (val) {
                          if (val == 'switch' && !isCurrent) {
                            _showSwitchAccountDialog(acc);
                          } else if (val == 'remove') {
                            _confirmRemoveAccount(acc);
                          }
                        },
                        itemBuilder: (ctx) => [
                          if (!isCurrent)
                            const PopupMenuItem(value: 'switch', child: Text('Switch Account')),
                          const PopupMenuItem(value: 'remove', child: Text('Remove from device', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                      onTap: isCurrent ? null : () => _showSwitchAccountDialog(acc),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions Buttons
            CustomButton(
              text: 'Switch Account',
              icon: Icons.swap_horiz,
              isOutlined: true,
              onPressed: () {
                final otherAccounts = authProvider.savedAccounts.where((a) => user == null || a.uid != user.uid).toList();
                if (otherAccounts.isEmpty) {
                  _showAddAccountDialog();
                } else {
                  _showSwitchAccountDialog(otherAccounts.first);
                }
              },
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Logout',
              icon: Icons.logout,
              backgroundColor: Colors.red,
              onPressed: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String replaceFirstChar(String Function(String) match) {
    if (isEmpty) return this;
    return match(this[0]) + substring(1);
  }
}
