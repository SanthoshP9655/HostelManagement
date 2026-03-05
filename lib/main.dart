// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/constants/app_theme.dart';
import 'core/services/supabase_service.dart';
import 'core/services/notification_service.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Env
  await dotenv.load(fileName: ".env");

  // 2. Initialize Supabase (for image storage)
  await SupabaseService.initialize();

  // 3. Initialize Firebase (all platforms — needed for Auth + Firestore)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    // 3. Register FCM background handler (mobile only)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 4. Initialize notification service (mobile only)
    await NotificationService.instance.initialize();
  }

  runApp(const ProviderScope(child: SmartHostelApp()));
}

class SmartHostelApp extends ConsumerWidget {
  const SmartHostelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final session = ref.watch(sessionProvider).valueOrNull;

    // Set notification navigation callback (mobile only)
    if (!kIsWeb) {
      NotificationService.instance.setNavigationCallback((route) {
        router.go(route);
      });
    }

    // Determine theme based on role
    ThemeData theme;
    switch (session?.role) {
      case 'warden':
        theme = AppTheme.wardenTheme;
      case 'student':
        theme = AppTheme.studentTheme;
      default:
        theme = AppTheme.adminTheme;
    }

    return MaterialApp.router(
      title: 'SmartHostel',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
    );
  }
}
