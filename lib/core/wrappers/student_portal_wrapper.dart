import 'package:flutter/material.dart';
import '../../features/chat/chat_screen.dart';

class StudentPortalWrapper extends StatelessWidget {
  final Widget child;

  const StudentPortalWrapper({super.key, required this.child});

  void _openChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Ensures rounded corners of chat screen are visible
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ChatScreen(scrollController: scrollController);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openChat(context),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 4,
        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
      ),
    );
  }
}
