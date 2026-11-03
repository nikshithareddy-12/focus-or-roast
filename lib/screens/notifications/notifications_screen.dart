import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/loading_indicator.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).userProfile;
      if (user != null) {
        Provider.of<NotificationProvider>(context, listen: false).listenToNotifications(user.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifProvider = Provider.of<NotificationProvider>(context);
    final user = Provider.of<AuthProvider>(context, listen: false).userProfile;

    if (notifProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const LoadingIndicator(message: 'Loading notifications...'),
      );
    }

    if (notifProvider.notifications.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const EmptyStateWidget(
          message: 'No notifications yet.',
          icon: Icons.notifications_none_rounded,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifProvider.notifications.length,
        itemBuilder: (context, index) {
          final notif = notifProvider.notifications[index];
          final isPending = notif.status == 'pending';

          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '🔔 ',
                        style: TextStyle(fontSize: 20),
                      ),
                      const Text(
                        'New Group Invitation',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormatter.formatDateTime(notif.createdAt),
                        style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '@${notif.senderUsername} invited you to join:',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${notif.groupName}"',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isPending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () async {
                              if (user == null) return;
                              await notifProvider.acceptInvitation(
                                notif,
                                user.uid,
                                username: user.username,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Joined ${notif.groupName}!')),
                                );
                              }
                            },
                            child: const Text(
                              'JOIN',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () async {
                              if (user == null) return;
                              await notifProvider.declineInvitation(
                                notif,
                                user.uid,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invitation declined.')),
                                );
                              }
                            },
                            child: const Text(
                              'DECLINE',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: notif.status == 'accepted'
                              ? AppColors.successGreen.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          notif.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: notif.status == 'accepted'
                                ? AppColors.successGreen
                                : Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
