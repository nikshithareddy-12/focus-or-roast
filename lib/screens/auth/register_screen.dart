import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../models/distraction_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/native_usage_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  List<DistractionModel> _installedApps = [];
  final Set<String> _selectedPackages = {};
  bool _loadingApps = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadInstalledApps() async {
    setState(() => _loadingApps = true);
    try {
      final apps = await NativeUsageService.getInstalledApps().timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(() {
          _installedApps = apps;
          _loadingApps = false;
        });
      }
    } catch (e) {
      print('[FocusRoast_Diag] RegisterScreen loadInstalledApps error: $e');
      if (mounted) {
        setState(() => _loadingApps = false);
      }
    }
  }

  void _handleRegister() async {
    // 1. Validate Form fields
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // 2. Perform registration
    final success = await authProvider.register(
      name: _nameController.text,
      username: _usernameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      distractionApps: _selectedPackages.toList(),
      context: context,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account registered successfully! Welcome to FocusRoast.'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
    } else if (!success && mounted) {
      final err = authProvider.errorMessage ?? 'Registration failed. Please try again.';
      if (err.toLowerCase().contains('already registered') || err.toLowerCase().contains('already in use')) {
        authProvider.clearError();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Account Already Exists'),
            content: Text('$err Would you like to log in instead?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (authProvider.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      authProvider.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                CustomTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  prefixIcon: Icons.person_outline,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your full name';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _usernameController,
                  label: 'Username',
                  hint: 'e.g. lasya123',
                  prefixIcon: Icons.alternate_email,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter a username';
                    if (v.trim().length < 3) return 'Username must be at least 3 characters';
                    if (v.contains(' ')) return 'Username cannot contain spaces';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'student@example.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your email';
                    final clean = v.trim();
                    if (!clean.contains('@') || !clean.contains('.')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter a password';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  prefixIcon: Icons.lock_clock_outlined,
                  obscureText: _obscurePassword,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm your password';
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                const Text(
                  'Select Distraction Apps (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'FocusRoast will roast you when you open these apps during focus sessions.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),

                if (_loadingApps)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_installedApps.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Usage access is required to detect installed distraction apps.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await NativeUsageService.openUsageSettings();
                            await _loadInstalledApps();
                          },
                          icon: const Icon(Icons.settings),
                          label: const Text('Enable Usage Access'),
                        )
                      ],
                    ),
                  )
                else
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      itemCount: _installedApps.length,
                      itemBuilder: (context, index) {
                        final app = _installedApps[index];
                        final isSelected = _selectedPackages.contains(app.packageName);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedPackages.add(app.packageName);
                              } else {
                                _selectedPackages.remove(app.packageName);
                              }
                            });
                          },
                          secondary: app.iconBytes != null
                              ? Image.memory(app.iconBytes!, width: 32, height: 32)
                              : const Icon(Icons.android),
                          title: Text(app.name),
                          subtitle: Text(
                            app.packageName,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 32),

                CustomButton(
                  text: 'Register & Complete Setup',
                  isLoading: authProvider.isLoading,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    GestureDetector(
                      onTap: () {
                        authProvider.clearError();
                        Navigator.pushReplacementNamed(context, AppRoutes.login);
                      },
                      child: const Text(
                        'Log in',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
