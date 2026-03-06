import 'package:cloud_functions/cloud_functions.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  ChatState({required this.messages, this.isLoading = false});
}

class ChatNotifier extends Notifier<ChatState> {
  final _welcomeMessage = ChatMessage(
    text: "Hi! 👋 I’m your Hostel AI Assistant. Ask me anything about rules, timings, fees, leave, etc. (Tap the mic to speak)",
    isUser: false,
  );

  @override
  ChatState build() {
    return ChatState(messages: [_welcomeMessage]);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    state = ChatState(
      messages: [...state.messages, ChatMessage(text: text, isUser: true)],
      isLoading: true,
    );

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('chatWithRules');
      final result = await callable.call({'question': text});

      final String reply = result.data['reply'] ?? "I couldn't process that.";
      state = ChatState(
        messages: [...state.messages, ChatMessage(text: reply, isUser: false)],
        isLoading: false,
      );
    } catch (e) {
      state = ChatState(
        messages: [
          ...state.messages,
          ChatMessage(text: "⚠️ Could not connect to the AI. Please ensure you are online.", isUser: false)
        ],
        isLoading: false,
      );
    }
  }

  void clearChat() {
    state = ChatState(messages: [_welcomeMessage]);
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(() => ChatNotifier());
