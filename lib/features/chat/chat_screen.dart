import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'chat_provider.dart';

class ChatScreen extends HookConsumerWidget {
  final ScrollController scrollController;

  const ChatScreen({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    final textController = useTextEditingController();
    final sttInstance = useMemoized(() => stt.SpeechToText(), []);
    final isListening = useState(false);
    final focusNode = useFocusNode();

    useEffect(() {
      sttInstance.initialize();
      return null;
    }, []);

    void listen() async {
      if (!isListening.value) {
        var status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Microphone permission required')),
            );
          }
          return;
        }

        bool available = await sttInstance.initialize();
        if (available) {
          isListening.value = true;
          sttInstance.listen(
            onResult: (result) => textController.text = result.recognizedWords,
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 3),
          );
        }
      } else {
        isListening.value = false;
        sttInstance.stop();
        // Insert text to textfield and focus
        focusNode.requestFocus();
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414), // Pure dark mode
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle & Toolbar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(4)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hostel Assistant', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white70),
                      onPressed: () => ref.read(chatProvider.notifier).clearChat(),
                      tooltip: 'Clear Chat',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Messages
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chatState.messages.length,
              itemBuilder: (context, index) {
                final message = chatState.messages[index];
                return _ChatBubble(message: message);
              },
            ),
          ),
          
          if (chatState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('AI thinking...', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
            ),
            
          // Input Area
          Container(
            padding: EdgeInsets.only(left: 12, right: 12, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
            decoration: const BoxDecoration(
              color: Color(0xFF222222),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: listen,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isListening.value ? Colors.redAccent.withOpacity(0.2) : Colors.transparent,
                    ),
                    child: Icon(
                      isListening.value ? Icons.mic : Icons.mic_none,
                      color: isListening.value ? Colors.redAccent : Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: textController,
                      focusNode: focusNode,
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: isListening.value ? 'Listening...' : 'Type a message...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (text) {
                        ref.read(chatProvider.notifier).sendMessage(text);
                        textController.clear();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.blueAccent),
                  onPressed: chatState.isLoading
                      ? null
                      : () {
                          ref.read(chatProvider.notifier).sendMessage(textController.text);
                          textController.clear();
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blueAccent.withOpacity(0.9) : const Color(0xFF333333),
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: message.isUser ? const Radius.circular(4) : null,
            bottomLeft: !message.isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            message.isUser
                ? Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 15))
                : MarkdownBody(
                    data: message.text,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Colors.white, fontSize: 15),
                      strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
            if (!message.isUser) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.text));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
                },
                child: const Icon(Icons.copy, size: 16, color: Colors.white54),
              )
            ]
          ],
        ),
      ),
    );
  }
}
