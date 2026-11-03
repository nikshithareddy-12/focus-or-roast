import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'core/config/firebase_options.dart';
import 'core/constants/app_colors.dart';
import 'core/routes/app_routes.dart';

import 'providers/auth_provider.dart';
import 'providers/distraction_provider.dart';
import 'providers/group_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/quiz_provider.dart';
import 'providers/session_provider.dart';
import 'providers/timer_provider.dart';

import 'screens/activities/my_activities_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/break/break_activities_screen.dart';
import 'screens/break/break_timer_screen.dart';
import 'screens/distraction/distraction_roast_screen.dart';
import 'screens/groups/create_group_screen.dart';
import 'screens/groups/group_chat_screen.dart';
import 'screens/groups/group_detail_screen.dart';
import 'screens/groups/group_documents_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/home/home_screen.dart';
import 'models/group_model.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/quiz/quiz_result_screen.dart';
import 'screens/quiz/quiz_screen.dart';
import 'screens/quiz/quiz_setup_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/streak/streak_screen.dart';
import 'screens/timer/focus_timer_screen.dart';
import 'screens/timer/timer_completed_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const FocusRoastApp());
}

class FocusRoastApp extends StatelessWidget {
  const FocusRoastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TimerProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => DistractionProvider()),
      ],
      child: MaterialApp(
        title: 'FocusRoast',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            surface: AppColors.surface,
          ),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.onSurface,
            elevation: 0,
            centerTitle: true,
          ),
        ),
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (context) => const SplashScreen(),
          AppRoutes.login: (context) => const LoginScreen(),
          AppRoutes.register: (context) => const RegisterScreen(),
          AppRoutes.home: (context) => const HomeScreen(),
          AppRoutes.focusTimer: (context) => const FocusTimerScreen(),
          AppRoutes.timerCompleted: (context) => const TimerCompletedScreen(),
          AppRoutes.breakTimer: (context) => const BreakTimerScreen(),
          AppRoutes.breakActivities: (context) => const BreakActivitiesScreen(),
          AppRoutes.distractionRoast: (context) => const DistractionRoastScreen(),
          AppRoutes.myActivities: (context) => const MyActivitiesScreen(),
          AppRoutes.streak: (context) => const StreakScreen(),
          AppRoutes.analytics: (context) => const AnalyticsScreen(),
          AppRoutes.groups: (context) => const GroupsScreen(),
          AppRoutes.createGroup: (context) => const CreateGroupScreen(),
          AppRoutes.groupDetail: (context) {
            final group = ModalRoute.of(context)!.settings.arguments as GroupModel;
            return GroupDetailScreen(group: group);
          },
          AppRoutes.groupChat: (context) {
            final group = ModalRoute.of(context)!.settings.arguments as GroupModel;
            return GroupChatScreen(group: group);
          },
          AppRoutes.groupDocuments: (context) {
            final group = ModalRoute.of(context)!.settings.arguments as GroupModel;
            return GroupDocumentsScreen(group: group);
          },
          AppRoutes.quizSetup: (context) => const QuizSetupScreen(),
          AppRoutes.quiz: (context) => const QuizScreen(),
          AppRoutes.quizResult: (context) => const QuizResultScreen(),
          AppRoutes.notifications: (context) => const NotificationsScreen(),
          AppRoutes.leaderboard: (context) => const LeaderboardScreen(),
          AppRoutes.profile: (context) => const ProfileScreen(),
        },
      ),
    );
  }
}
