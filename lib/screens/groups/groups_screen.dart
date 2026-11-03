import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../models/group_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);

      if (authProvider.currentUser != null) {
        groupProvider.listenToMyGroups(authProvider.currentUser!.uid);
        groupProvider.listenToPublicGroups();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = Provider.of<GroupProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Groups'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'MY GROUPS'),
            Tab(text: 'PUBLIC GROUPS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Groups Tab
          _buildMyGroupsTab(groupProvider, currentUser?.uid),

          // Public Groups Tab
          _buildPublicGroupsTab(groupProvider, currentUser?.uid),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Create Group'),
        onPressed: () async {
          final result = await Navigator.pushNamed(context, AppRoutes.createGroup);
          if (result == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Group created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildMyGroupsTab(GroupProvider provider, String? uid) {
    final groups = provider.myGroups;

    if (groups.isEmpty) {
      return const EmptyStateWidget(
        message: 'No groups yet.',
        icon: Icons.groups_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildGroupCard(group, isMember: true, currentUid: uid);
      },
    );
  }

  Widget _buildPublicGroupsTab(GroupProvider provider, String? uid) {
    final groups = provider.publicGroups;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search groups by name...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: provider.searchPublicGroups,
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? const EmptyStateWidget(
                  message: 'No groups found.',
                  icon: Icons.search_off,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final isMember = uid != null && group.members.contains(uid);
                    return _buildGroupCard(group, isMember: isMember, currentUid: uid);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGroupCard(GroupModel group, {required bool isMember, String? currentUid}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryContainer,
          child: Text(
            group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.description.isNotEmpty) Text(group.description),
            const SizedBox(height: 4),
            Text(
              '${group.members.length} member${group.members.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        trailing: isMember
            ? ElevatedButton(
                child: const Text('Open'),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.groupDetail,
                    arguments: group,
                  );
                },
              )
            : OutlinedButton(
                child: const Text('Join'),
                onPressed: () async {
                  if (currentUid != null) {
                    final success = await Provider.of<GroupProvider>(context, listen: false)
                        .joinGroup(group.groupId, currentUid);
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Joined ${group.name}!')),
                      );
                    }
                  }
                },
              ),
      ),
    );
  }
}
