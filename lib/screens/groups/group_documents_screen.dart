import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/group_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/empty_state_widget.dart';

class GroupDocumentsScreen extends StatefulWidget {
  final GroupModel group;

  const GroupDocumentsScreen({super.key, required this.group});

  @override
  State<GroupDocumentsScreen> createState() => _GroupDocumentsScreenState();
}

class _GroupDocumentsScreenState extends State<GroupDocumentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupProvider>(context, listen: false).listenToGroupDocuments(widget.group.groupId);
    });
  }

  Future<void> _uploadDocument() async {
    final user = Provider.of<AuthProvider>(context, listen: false).userProfile;
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);

    if (user == null) return;

    final success = await groupProvider.uploadDocument(
      groupId: widget.group.groupId,
      uploaderId: user.uid,
      uploaderName: user.username.isNotEmpty ? user.username : user.name,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document uploaded successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } else if (!success && groupProvider.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(groupProvider.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = Provider.of<GroupProvider>(context);
    final documents = groupProvider.activeGroupDocuments;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: groupProvider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(groupProvider.isLoading ? 'Uploading...' : 'Upload Document / File'),
            onPressed: groupProvider.isLoading ? null : _uploadDocument,
          ),
        ),
        Expanded(
          child: documents.isEmpty
              ? const EmptyStateWidget(
                  message: 'No documents shared yet in this group.',
                  icon: Icons.folder_off_rounded,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final doc = documents[index];
                    final sizeKb = (doc.fileSize / 1024).toStringAsFixed(1);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryLight.withOpacity(0.3),
                          child: const Icon(Icons.description_rounded, color: AppColors.primary),
                        ),
                        title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Uploaded by ${doc.uploaderName} • $sizeKb KB\n${DateFormatter.formatDateShort(doc.uploadedAt)}'),
                        trailing: const Icon(Icons.open_in_new_rounded, color: AppColors.primary),
                        onTap: () async {
                          if (doc.fileUrl.isNotEmpty) {
                            final uri = Uri.tryParse(doc.fileUrl);
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not open ${doc.title}'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
