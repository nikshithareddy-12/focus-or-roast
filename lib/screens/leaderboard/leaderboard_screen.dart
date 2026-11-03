import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../services/firestore_service.dart';

class LeaderboardUser {
  final String name;
  final String username;
  final int totalFocusMinutes;

  LeaderboardUser({
    required this.name,
    required this.username,
    required this.totalFocusMinutes,
  });
}

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  /// Reads the pre-aggregated public projection (single indexed query) instead of
  /// downloading every user's private profile and all of their sessions, which
  /// is both O(users x sessions) and blocked by the default-deny security rules.
  Future<List<LeaderboardUser>> _fetchLeaderboard() async {
    final profiles = await FirestoreService().getLeaderboard().first;
    final leaderboard = profiles
        .where((u) => u.totalFocusMinutes > 0)
        .map((u) => LeaderboardUser(
              name: u.name.isNotEmpty ? u.name : 'User',
              username: u.username.isNotEmpty ? u.username : 'user',
              totalFocusMinutes: u.totalFocusMinutes,
            ))
        .toList();
    leaderboard.sort((a, b) => b.totalFocusMinutes.compareTo(a.totalFocusMinutes));
    return leaderboard;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Leaderboard 🏆'),
      ),
      body: FutureBuilder<List<LeaderboardUser>>(
        future: _fetchLeaderboard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Calculating rankings...');
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const EmptyStateWidget(
              message: 'No ranking data yet.',
              icon: Icons.leaderboard_rounded,
            );
          }

          final list = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              final rank = index + 1;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: rank == 1
                        ? Colors.amber
                        : rank == 2
                            ? Colors.grey.shade400
                            : rank == 3
                                ? Colors.brown.shade300
                                : AppColors.primaryLight.withOpacity(0.3),
                    foregroundColor: rank <= 3 ? Colors.white : AppColors.primary,
                    child: Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('@${item.username}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item.totalFocusMinutes} mins',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
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
