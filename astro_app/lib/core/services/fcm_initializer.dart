import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/notifications/providers/notification_providers.dart';

/// Widget invisible que inicializa FCM cuando el usuario se autentica
/// y limpia el token cuando cierra sesión.
class FcmInitializer extends ConsumerStatefulWidget {
  const FcmInitializer({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<FcmInitializer> createState() => _FcmInitializerState();
}

class _FcmInitializerState extends ConsumerState<FcmInitializer> {
  String? _lastUid;

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (prev, next) {
      final uid = next.value?.uid;
      if (uid != null && uid != _lastUid) {
        // Usuario recién logueado — inicializar FCM
        _lastUid = uid;
        ref.read(notificationServiceProvider).initialize(uid);
      } else if (uid == null && _lastUid != null) {
        // Cerró sesión — limpiar token
        ref.read(notificationServiceProvider).removeToken(_lastUid!);
        _lastUid = null;
      }
    });

    return widget.child;
  }
}
