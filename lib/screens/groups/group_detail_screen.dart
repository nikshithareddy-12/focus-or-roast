import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../models/group_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import 'package:provider/provider.dart';
import 'group_chat_screen.dart';
import 'group_documents_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final GroupModel group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showInviteDialog() {
    final usernameController = TextEditingController();
    bool isLoading = false;
    String? statusMsg;
    bool isError = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Invite Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite a user to join "${widget.group.name}" by their username.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (statusMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isError ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isError ? Icons.error_outline : Icons.check_circle_outline,
                        size: 16,
                        color: isError ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusMsg!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isError ? Colors.red : Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: usernameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'e.g. lasya123',
                  prefixIcon: Icon(Icons.alternate_email),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendInvite(ctx, setState, usernameController, isLoading, (l, m, e) {
                  setState(() {
                    isLoading = l;
                    statusMsg = m;
                    isError = e;
                  });
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('CLOSE'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isLoading
                  ? null
                  : () => _sendInvite(ctx, setState, usernameController, isLoading, (l, m, e) {
                        setState(() {
                          isLoading = l;
                          statusMsg = m;
                          isError = e;
                        });
                      }),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('SEND INVITE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendInvite(
    BuildContext ctx,
    StateSetter setState,
    TextEditingController controller,
    bool isLoading,
    void Function(bool loading, String? message, bool isError) update,
  ) async {
    final username = controller.text.trim().toLowerCase();
    if (username.isEmpty) return;

    update(true, null, false);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    final success = await groupProvider.inviteUser(
      targetUsername: username,
      group: widget.group,
      senderUid: user.uid,
      senderUsername: user.username,
    );

    if (success) {
      update(false, 'Invitation sent to @$username successfully!', false);
      controller.clear();
    } else {
      update(false, groupProvider.errorMessage ?? 'Failed to send invitation.', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Invite Member',
            onPressed: _showInviteDialog,
          ),
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'Group Quiz',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.quizSetup);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'CHAT'),
            Tab(icon: Icon(Icons.folder_outlined), text: 'DOCUMENTS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          GroupChatScreen(group: widget.group),
          GroupDocumentsScreen(group: widget.group),
        ],
      ),
    );
  }
}
