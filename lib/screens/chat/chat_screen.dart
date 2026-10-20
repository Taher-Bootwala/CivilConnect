// CivilHand In-App Masked Chat Screen
// Private, phone-masked communication between customer and assigned tradesperson

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String bookingCode;
  final String recipientName;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.bookingCode,
    required this.recipientName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    // Baseline simulated conversation
    _messages.addAll([
      {
        'id': '1',
        'sender_role': 'worker',
        'message_text': 'Namaste! I am on my way to your location. ETA ~15 mins.',
        'time': '10:14 AM',
        'is_me': false,
      },
      {
        'id': '2',
        'sender_role': 'customer',
        'message_text': 'Thanks Ramesh. Please ring flat 402 on the intercom when you reach the lobby.',
        'time': '10:16 AM',
        'is_me': true,
      },
    ]);
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() {
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'sender_role': 'customer',
        'message_text': text,
        'time': 'Just now',
        'is_me': true,
      });
    });

    final service = ref.read(supabaseServiceProvider);
    final userId = service.currentUser?.id ?? 'demo-user-id';
    service.sendChatMessage(
      bookingId: widget.bookingId,
      senderId: userId,
      messageText: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.slate50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.recipientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
              'Booking #${widget.bookingCode} • Identity Protected',
              style: const TextStyle(fontSize: 11, color: AppTheme.slate500, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined, color: AppTheme.primaryIndigo),
            tooltip: 'Masked VoIP Call',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Starting masked VoIP call (Personal phone numbers kept private)'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Security disclaimer pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.primaryIndigo.withOpacity(0.08),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: AppTheme.primaryIndigo),
                SizedBox(width: 6),
                Text(
                  'Calls & messages are masked for your privacy and safety.',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryIndigo),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (ctx, index) {
                final msg = _messages[index];
                final isMe = msg['is_me'] as bool;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? AppTheme.primaryIndigo : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                        bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['message_text'],
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isMe ? Colors.white : AppTheme.slate900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['time'],
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe ? Colors.white70 : AppTheme.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Message input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.slate200, width: 1)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: AppTheme.slate500),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Attaching receipt or work photograph...')),
                      );
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.slate400),
                        filled: true,
                        fillColor: AppTheme.slate100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryIndigo,
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
