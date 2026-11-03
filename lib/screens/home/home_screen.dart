import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/custom_button.dart';
import '../../providers/auth_provider.dart';
import '../../providers/distraction_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/native_usage_service.dart';
import '../../providers/notification_provider.dart';

import '../../providers/timer_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _subjectController = TextEditingController();
  /// Which permission gate we're waiting on after sending the user to Settings.
  /// Empty means nothing pending; 'usage' or 'overlay'.
  String _pendingPermissionType = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final timerProvider = Provider.of<TimerProvider>(context, listen: false);
      final distractionProvider = Provider.of<DistractionProvider>(context, listen: false);

      // Composition root: hand TimerProvider the monitoring lifecycle hooks so
      // it (the authoritative session owner) starts AND stops native
      // monitoring on every transition, even when no screen is mounted.
      timerProvider.bindMonitoring(
        onStart: (apps, subject, durationMinutes) {
          distractionProvider.startMonitoring(
            apps,
            subject: subject,
            durationMinutes: durationMinutes,
            onDistraction: (_) => timerProvider.incrementDistractionCount(),
          );
        },
        onStop: () => distractionProvider.stopMonitoring(),
      );

      if (authProvider.currentUser != null) {
        final uid = authProvider.currentUser!.uid;
        timerProvider.setUserId(uid);
        Provider.of<NotificationProvider>(context, listen: false).listenToNotifications(uid);
        // Pre-fetch sessions from Firestore so SessionProvider is populated
        Provider.of<SessionProvider>(context, listen: false).fetchSessions(uid);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subjectController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingPermissionType.isNotEmpty) {
      final pendingType = _pendingPermissionType;
      _pendingPermissionType = '';
      if (pendingType == 'overlay') {
        _recheckOverlayPermission();
      } else {
        _recheckUsagePermission();
      }
    }
  }

  Future<void> _recheckUsagePermission() async {
    if (!mounted) return;

    final granted = await NativeUsageService.hasUsagePermission();
    if (!mounted) return;

    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usage access enabled! Starting focus session...'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      _continueStartSession();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usage Access permission is required to detect and block distracting apps.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Future<void> _recheckOverlayPermission() async {
    if (!mounted) return;

    final granted = await NativeUsageService.hasOverlayPermission();
    if (!mounted) return;

    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Overlay permission enabled! Starting focus session...'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      _continueStartSession();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display-over-other-apps permission is required to block distracting apps.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _startSession() async {
    // Check Usage Access permission
    final hasPermission = await NativeUsageService.hasUsagePermission();
    if (!hasPermission) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.security, color: AppColors.roastOrange),
              SizedBox(width: 8),
              Text('Usage Access Required'),
            ],
          ),
          content: const Text(
            'FocusRoast requires Usage Access to detect and block distraction apps during your focus session.\n\nPlease find FocusRoast and enable "Permit usage access".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                Navigator.of(ctx).pop();
                _pendingPermissionType = 'usage';
                await NativeUsageService.openUsageSettings();
              },
              child: const Text('OPEN SETTINGS'),
            ),
          ],
        ),
      );
      return;
    }

    // Check Display Over Other Apps (SYSTEM_ALERT_WINDOW) permission
    final hasOverlay = await NativeUsageService.hasOverlayPermission();
    if (!hasOverlay) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.layers, color: AppColors.roastOrange),
              SizedBox(width: 8),
              Text('Overlay Permission Required'),
            ],
          ),
          content: const Text(
            'FocusRoast needs "Display over other apps" permission to show the block screen over distracting apps.\n\nPlease enable it in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                Navigator.of(ctx).pop();
                _pendingPermissionType = 'overlay';
                await NativeUsageService.openOverlaySettings();
              },
              child: const Text('OPEN SETTINGS'),
            ),
          ],
        ),
      );
      return;
    }

    _continueStartSession();
  }

  void _continueStartSession() {
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final user = authProvider.currentUser;
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to start a focus session.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final subjectText = _subjectController.text.trim();
    timerProvider.setSubject(subjectText.isEmpty ? 'General' : subjectText);

    final appsToMonitor = user?.distractionApps ?? [];
    print('[FocusRoast_Diag] HomeScreen: Starting focus session with user distraction apps: $appsToMonitor');

    // Single authoritative start. startFocusSession is idempotent and triggers
    // native monitoring through the bound hook, so we must not start monitoring
    // (or push the timer screen) again here if a session is already active.
    final started = timerProvider.startFocusSession(
      uid: uid,
      distractionApps: appsToMonitor,
    );
    if (!started) return;

    Navigator.pushNamed(context, AppRoutes.focusTimer);
  }
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final timerProvider = Provider.of<TimerProvider>(context);
    final notifProvider = Provider.of<NotificationProvider>(context);

    final user = authProvider.currentUser;
    String greeting = 'Hi there!';
    if (user != null) {
      String rawUsername = user.username.trim();
      if (rawUsername.isEmpty || rawUsername.contains('@')) {
        if (user.name.trim().isNotEmpty && !user.name.contains('@') && user.name.trim().toLowerCase() != 'user') {
          rawUsername = user.name.trim();
        }
      }

      if (rawUsername.isNotEmpty && !rawUsername.contains('@') && rawUsername.toLowerCase() != 'user') {
        final formattedName = rawUsername.length > 1
            ? '${rawUsername[0].toUpperCase()}${rawUsername.substring(1)}'
            : rawUsername.toUpperCase();
        greeting = 'Hi $formattedName!';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusRoast'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
              ),
              if (notifProvider.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${notifProvider.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Header
            Text(
              greeting,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.onBackground,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ready to roast your distractions today?',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Focus Session Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.timer_outlined, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Configure Focus Session',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Subject Field
                    const Text(
                      'What are you studying?',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Data Structures, Physics, GATE...',
                        prefixIcon: Icon(Icons.book_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Quick pick: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ActionChip(
                          label: const Text('General'),
                          onPressed: () {
                            setState(() {
                              _subjectController.text = 'General';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Timer Duration Selector (+/-)
                    const Text(
                      'Focus Duration',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.remove),
                          onPressed: timerProvider.decrementFocusDuration,
                        ),
                        const SizedBox(width: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${timerProvider.focusDurationMinutes} min',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add),
                          onPressed: timerProvider.incrementFocusDuration,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Number of Breaks Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Number of Breaks',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        DropdownButton<int>(
                          value: timerProvider.numberOfBreaks,
                          items: [0, 1, 2, 3, 4, 5]
                              .map((n) => DropdownMenuItem(
                                    value: n,
                                    child: Text('$n break${n == 1 ? '' : 's'}'),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) timerProvider.setNumberOfBreaks(val);
                          },
                        ),
                      ],
                    ),

                    // Break Duration Selector
                    if (timerProvider.numberOfBreaks > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Break Duration',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          DropdownButton<int>(
                            value: timerProvider.breakDurationMinutes,
                            items: [1, 5, 10, 15]
                                .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text('$m min'),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) timerProvider.setBreakDuration(val);
                            },
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'Start Focus Session',
                      icon: Icons.play_arrow,
                      onPressed: _startSession,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Feature Quick Shortcuts Grid
            const Text(
              'Student Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildDashboardTile(
                  context,
                  title: 'My Activities',
                  icon: Icons.history,
                  color: Colors.purple,
                  route: AppRoutes.myActivities,
                ),
                _buildDashboardTile(
                  context,
                  title: 'Streak',
                  icon: Icons.local_fire_department,
                  color: AppColors.roastOrange,
                  route: AppRoutes.streak,
                ),
                _buildDashboardTile(
                  context,
                  title: 'Analytics',
                  icon: Icons.analytics_outlined,
                  color: AppColors.analyticsBlue,
                  route: AppRoutes.analytics,
                ),
                _buildDashboardTile(
                  context,
                  title: 'Groups',
                  icon: Icons.groups_outlined,
                  color: Colors.indigo,
                  route: AppRoutes.groups,
                ),
                _buildDashboardTile(
                  context,
                  title: 'AI Quiz Bot',
                  icon: Icons.psychology_outlined,
                  color: Colors.teal,
                  route: AppRoutes.quizSetup,
                ),
                _buildDashboardTile(
                  context,
                  title: 'Leaderboard',
                  icon: Icons.emoji_events_outlined,
                  color: Colors.amber.shade800,
                  route: AppRoutes.leaderboard,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDashboardTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

