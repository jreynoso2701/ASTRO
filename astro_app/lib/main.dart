import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:astro/firebase_options.dart';
import 'package:astro/core/theme/app_theme.dart';
import 'package:astro/core/theme/theme_provider.dart';
import 'package:astro/core/router/app_router.dart';
import 'package:astro/core/services/notification_service.dart';
import 'package:astro/core/services/fcm_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Registrar handler de mensajes en background/terminated.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: AstroApp()));
}

class AstroApp extends ConsumerWidget {
  const AstroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);

    return FcmInitializer(
      child: MaterialApp.router(
        title: 'ASTRO',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}
