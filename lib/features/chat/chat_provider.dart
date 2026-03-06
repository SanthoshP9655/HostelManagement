import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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
      // 1. Fetch latest rules PDF URL from Firestore
      final doc = await FirebaseFirestore.instance.collection('hostel_rules').doc('latest').get();
      if (!doc.exists) {
        throw Exception("Internal Error: Warden has not uploaded rules yet.");
      }
      
      final pdfUrl = doc.data()?['fileUrl'];
      final updatedAt = (doc.data()?['updatedAt'] as Timestamp?)?.toDate().toString() ?? '';

      // 2. Fetch and Parse PDF Context
      final response = await Dio().get(
        pdfUrl, 
        options: Options(responseType: ResponseType.bytes)
      );
      final document = PdfDocument(inputBytes: response.data);
      final String fullExtractedText = PdfTextExtractor(document).extractText();
      document.dispose();

      // 3. Orchestrate with OpenRouter AI directly
      final systemPrompt = '''You are a helpful, polite Hostel Assistant for our College students.
Answer ONLY using the official hostel rules below. Never invent information.
If the answer is not in the rules, reply: "According to the current hostel rules, I don't have that information. Please contact the warden."
Rules (last updated: $updatedAt):
$fullExtractedText

Keep answers short, clear, and student-friendly. Use markdown where helpful for lists/bold text.''';

      final openRouterResponse = await Dio().post(
        "https://openrouter.ai/api/v1/chat/completions",
        data: {
          "model": "openrouter/auto", // Uses best available free/auto model
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": text}
          ]
        },
        options: Options(
          validateStatus: (status) => true,
          headers: {
            // Using the key provided. Note: For production, store this in flutter_dotenv
            "Authorization": "Bearer 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",
            "HTTP-Referer": "https://hostelapp.com",
            "X-Title": "Hostel Management App",
            "Content-Type": "application/json"
          }
        )
      );

      if (openRouterResponse.statusCode != 200) {
        throw Exception("Server replied with code ${openRouterResponse.statusCode}: ${openRouterResponse.data}");
      }
      
      String reply = "";
      if (openRouterResponse.data is Map && openRouterResponse.data['choices'] != null) {
        reply = openRouterResponse.data['choices'][0]['message']['content'];
      } else if (openRouterResponse.data is String) {
        throw Exception("Unexpected String response (Invalid Token?): ${openRouterResponse.data}");
      } else {
        throw Exception("Invalid OpenRouter Response format");
      }
      
      state = ChatState(
        messages: [...state.messages, ChatMessage(text: reply, isUser: false)],
        isLoading: false,
      );
    } catch (e) {
      String errMsg = "⚠️ Could not connect to the AI.";
      if (e is DioException) {
        errMsg += "\nStatus: ${e.response?.statusCode}\nDetails: ${e.response?.data ?? e.message}";
      } else {
        errMsg += "\nError: ${e.toString()}";
      }
      
      state = ChatState(
        messages: [
          ...state.messages,
          ChatMessage(text: errMsg, isUser: false)
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
