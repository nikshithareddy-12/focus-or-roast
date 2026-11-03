import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../models/focus_session.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class MyActivitiesScreen extends StatelessWidget {
  const MyActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Activities')),
        body: const EmptyStateWidget(message: 'No user logged in.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Activities'),
      ),
      body: StreamBuilder<List<FocusSession>>(
        stream: FirestoreService().getUserSessions(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snapshot.data ?? [];

          if (sessions.isEmpty) {
            return const EmptyStateWidget(
              message: 'No activities yet.',
              icon: Icons.history,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.book, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                session.subject,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: session.completed
                                  ? AppColors.successGreen.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              session.completed ? 'Completed' : 'Interrupted',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: session.completed ? AppColors.successGreen : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Duration: ${session.actualDuration} / ${session.plannedDuration} min',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          Text(
                            DateFormat('MMM d, h:mm a').format(session.startTime),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Icon(Icons.notifications_active_outlined, size: 16, color: AppColors.roastOrange),
                          const SizedBox(width: 4),
                          Text(
                            'Distractions: ${session.distractionCount}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.coffee_outlined, size: 16, color: AppColors.breakCalm),
                          const SizedBox(width: 4),
                          Text(
                            'Breaks: ${session.breaksCompleted}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
