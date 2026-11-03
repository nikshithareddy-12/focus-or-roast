import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/group_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/empty_state_widget.dart';

class GroupChatScreen extends StatefulWidget {
  final GroupModel group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupProvider>(context, listen: false).listenToChatMessages(widget.group.groupId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'ppt', 'pptx',
          'txt', 'xls', 'xlsx', 'csv',
          'jpg', 'jpeg', 'png',
        ],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;

    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedFile == null) return;

    final user = Provider.of<AuthProvider>(context, listen: false).userProfile;
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);

    if (user == null) return;

    setState(() => _isSending = true);

    try {
      if (_selectedFile != null) {
        final success = await groupProvider.sendFileMessage(
          groupId: widget.group.groupId,
          senderId: user.uid,
          senderName: user.name,
          senderUsername: user.username.isNotEmpty ? user.username : user.name,
          pickedFile: _selectedFile!,
          caption: text.isNotEmpty ? text : null,
        );

        if (success) {
          _messageController.clear();
          setState(() {
            _selectedFile = null;
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(groupProvider.errorMessage ?? 'Failed to send file. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        await groupProvider.sendMessage(
          groupId: widget.group.groupId,
          senderId: user.uid,
          senderName: user.name,
          senderUsername: user.username.isNotEmpty ? user.username : user.name,
          content: text,
        );
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Widget _buildMessageContent(MessageModel msg, bool isMe) {
    if (msg.isFile) {
      final ext = msg.fileType ?? msg.fileName?.split('.').last ?? '';
      final sizeStr = _formatFileSize(msg.fileSize);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              if (msg.fileUrl != null && msg.fileUrl!.isNotEmpty) {
                final uri = Uri.tryParse(msg.fileUrl!);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open file'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withOpacity(0.15) : AppColors.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMe ? Colors.white30 : AppColors.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isMe ? Colors.white24 : AppColors.primaryLight,
                    child: Icon(
                      _getFileIcon(ext),
                      color: isMe ? Colors.white : AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.fileName ?? 'Shared File',
                          style: TextStyle(
                            color: isMe ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (sizeStr.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            sizeStr,
                            style: TextStyle(
                              color: isMe ? Colors.white70 : AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.file_present_rounded,
                    color: isMe ? Colors.white70 : AppColors.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (msg.content.isNotEmpty && msg.content != msg.fileName) ...[
            const SizedBox(height: 6),
            Text(
              msg.content,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      );
    }

    return Text(
      msg.content,
      style: TextStyle(
        color: isMe ? Colors.white : AppColors.textPrimary,
        fontSize: 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = Provider.of<GroupProvider>(context);
    final currentUser = Provider.of<AuthProvider>(context).userProfile;
    final messages = groupProvider.activeChatMessages;

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const EmptyStateWidget(
                  message: 'No chat messages yet. Start the conversation!',
                  icon: Icons.chat_outlined,
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = currentUser != null && msg.senderId == currentUser.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                          ),
                          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 4)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe) ...[
                              Text(
                                '@${msg.senderUsername}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            _buildMessageContent(msg, isMe),
                            const SizedBox(height: 4),
                            Text(
                              DateFormatter.formatTimeOnly(msg.timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe ? Colors.white70 : AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Attachment Preview Banner
        if (_selectedFile != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Icon(
                  _getFileIcon(_selectedFile!.extension),
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedFile!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        _formatFileSize(_selectedFile!.size),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: _isSending ? null : () => setState(() => _selectedFile = null),
                ),
              ],
            ),
          ),

        // Message Input Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, -2))],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file_rounded, color: AppColors.primary),
                  tooltip: 'Attach file',
                  onPressed: _isSending ? null : _pickFile,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isSending,
                    decoration: InputDecoration(
                      hintText: _selectedFile != null ? 'Add caption (optional)...' : 'Type a message...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
