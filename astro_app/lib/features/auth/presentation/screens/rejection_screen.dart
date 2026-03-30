import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/notifications/providers/notification_providers.dart';

/// Pantalla para usuarios cuyo registro fue rechazado.
///
/// Muestra la justificación del rechazo y opciones para
/// contactar soporte o darse de baja.
class RejectionScreen extends ConsumerStatefulWidget {
  const RejectionScreen({super.key});

  @override
  ConsumerState<RejectionScreen> createState() => _RejectionScreenState();
}

class _RejectionScreenState extends ConsumerState<RejectionScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentUserProfileProvider).value;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppBreakpoints.compact;

    final rejectionReason =
        profile?.rejectionReason ?? 'No se proporcionó una razón.';

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 48),

        // Ícono
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.block_rounded,
            size: 48,
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 32),

        Text(
          'SOLICITUD NO APROBADA',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        Text(
          'Tu solicitud de acceso a ASTRO no fue aprobada.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Card con justificación
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 32,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Motivo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  rejectionReason,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Si consideras que esto es un error, puedes contactar '
          'a soporte para más información.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 40),

        // Contactar soporte
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _contactSupport(),
            icon: const Icon(Icons.email_outlined),
            label: const Text('Contactar soporte'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Dar de baja
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isDeleting
                ? null
                : () => _confirmDeleteAccount(context),
            icon: _isDeleting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onError,
                    ),
                  )
                : const Icon(Icons.logout),
            label: Text(
              _isDeleting
                  ? 'Eliminando cuenta…'
                  : 'Entendido, dar de baja mi cuenta',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 0 : 32,
              vertical: 32,
            ),
            child: isWide ? SizedBox(width: 480, child: content) : content,
          ),
        ),
      ),
    );
  }

  void _contactSupport() {
    final uri = Uri(
      scheme: 'mailto',
      path: 'juan@constelacion-r.com',
      queryParameters: {'subject': 'ASTRO - Solicitud rechazada — consulta'},
    );
    launchUrl(uri);
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dar de baja'),
        content: const Text(
          'Se eliminará tu cuenta permanentemente. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAccount();
            },
            child: const Text('Eliminar cuenta'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final authRepo = ref.read(authRepositoryProvider);
    final notifService = ref.read(notificationServiceProvider);
    final uid = authRepo.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isDeleting = true);

    try {
      // Intentar remover token FCM (no bloquear si falla)
      try {
        await notifService.removeToken(uid);
      } catch (_) {}

      // Intentar llamar la Cloud Function para anonimizar/eliminar
      final callable = FirebaseFunctions.instance.httpsCallable(
        'anonymizeAndDeleteUser',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      await callable.call();
    } catch (_) {
      // Si la Cloud Function falla, al menos cerramos sesión.
      // Para un usuario rechazado, lo importante es sacarlo de la app.
    } finally {
      try {
        await authRepo.signOut();
      } catch (_) {}

      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}
