import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _inviteUsernameController = TextEditingController();

  bool _isPublic = true;
  final List<String> _invitedUsernames = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _inviteUsernameController.dispose();
    super.dispose();
  }

  void _addInviteUsername() {
    final text = _inviteUsernameController.text.trim().toLowerCase();
    if (text.isNotEmpty && !_invitedUsernames.contains(text)) {
      setState(() {
        _invitedUsernames.add(text);
        _inviteUsernameController.clear();
      });
    }
  }

  void _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    final success = await groupProvider.createGroup(
      name: _nameController.text,
      description: _descriptionController.text,
      isPublic: _isPublic,
      creatorUid: user.uid,
    );

    if (success && mounted) {
      // Send invitations to added usernames using the actual created group
      // (not myGroups stream which may not have updated yet)
      final createdGroup = groupProvider.lastCreatedGroup;
      if (createdGroup != null) {
        for (var username in _invitedUsernames) {
          groupProvider.inviteUser(
            targetUsername: username,
            group: createdGroup,
            senderUid: user.uid,
            senderUsername: user.username,
          );
        }
      }

      // Pop with success result so the GroupsScreen can show the SnackBar
      // on its own context (showing it here would be lost when the screen pops)
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = Provider.of<GroupProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Study Group'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (groupProvider.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(groupProvider.errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
                const SizedBox(height: 16),
              ],

              CustomTextField(
                controller: _nameController,
                label: 'Group Name',
                hint: 'e.g. DSA Preparation',
                prefixIcon: Icons.group,
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter group name' : null,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _descriptionController,
                label: 'Description (Optional)',
                hint: 'e.g. Daily focus sessions for GATE/LeetCode',
                prefixIcon: Icons.description_outlined,
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text('Public Group', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Anyone can search and join this group'),
                value: _isPublic,
                onChanged: (val) => setState(() => _isPublic = val),
              ),
              const Divider(height: 32),

              // Invite Participants Section
              const Text(
                'Invite Participants (By Username)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _inviteUsernameController,
                      label: 'Participant Username',
                      hint: 'e.g. lasya123',
                      prefixIcon: Icons.person_add_alt_1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    onPressed: _addInviteUsername,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                children: _invitedUsernames.map((username) {
                  return Chip(
                    label: Text('@$username'),
                    onDeleted: () {
                      setState(() => _invitedUsernames.remove(username));
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              CustomButton(
                text: 'Create Group',
                isLoading: groupProvider.isLoading,
                onPressed: _handleCreate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
