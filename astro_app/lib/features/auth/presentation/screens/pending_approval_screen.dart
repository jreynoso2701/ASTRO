import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/notifications/providers/notification_providers.dart';

/// Pantalla para usuarios con registro pendiente de aprobación.
///
/// Muestra mensaje de agradecimiento, tiempo estimado (24h hábiles),
/// y acciones: cerrar sesión, eliminar solicitud, contactar soporte.
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentUserProfileProvider).value;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppBreakpoints.compact;

    // Calcular si han pasado 24 horas desde el registro.
    final createdAt = profile?.createdAt ?? DateTime.now();
    final hoursSinceRegistration = DateTime.now().difference(createdAt).inHours;
    final canContactSupport = hoursSinceRegistration >= 24;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 48),
        // Logo / ícono
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.hourglass_top_rounded,
            size: 48,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 32),

        Text(
          '¡GRACIAS POR REGISTRARTE!',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        Text(
          'Tu solicitud de acceso está siendo revisada.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Info card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 36,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Aprobación pendiente',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Un administrador revisará tu solicitud en un máximo '
                  'de 24 horas hábiles. Recibirás una notificación '
                  'cuando tu acceso sea aprobado.',
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

        // Pasos de progreso
        _StepTile(
          icon: Icons.check_circle,
          color: const Color(0xFF4CAF50),
          title: 'Cuenta creada',
          subtitle: 'Tu registro fue exitoso.',
        ),
        const SizedBox(height: 8),
        _StepTile(
          icon: Icons.pending,
          color: const Color(0xFFFFC107),
          title: 'Revisión en proceso',
          subtitle: 'Un administrador evaluará tu solicitud.',
        ),
        const SizedBox(height: 8),
        _StepTile(
          icon: Icons.radio_button_unchecked,
          color: theme.colorScheme.onSurfaceVariant,
          title: 'Acceso al sistema',
          subtitle: 'Podrás usar ASTRO una vez aprobado.',
        ),

        const SizedBox(height: 40),

        // Contactar soporte (habilitado después de 24h)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: canContactSupport
                ? () => _contactSupport(context)
                : null,
            icon: const Icon(Icons.email_outlined),
            label: Text(
              canContactSupport
                  ? 'Contactar soporte'
                  : 'Contactar soporte (disponible en ${24 - hoursSinceRegistration}h)',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Eliminar solicitud / cuenta
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmDeleteRequest(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar solicitud'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Cerrar sesión
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
            style: OutlinedButton.styleFrom(
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

  void _contactSupport(BuildContext context) {
    final uri = Uri(
      scheme: 'mailto',
      path: 'juan@constelacion-r.com',
      queryParameters: {
        'subject': 'ASTRO - Solicitud de soporte (registro pendiente)',
      },
    );
    launchUrl(uri);
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Si cierras sesión, no recibirás notificaciones push '
          'sobre el estado de tu solicitud hasta que vuelvas a '
          'iniciar sesión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authRepositoryProvider).signOut();
            },
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRequest(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar solicitud'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar tu solicitud y '
          'dar de baja tu cuenta? Esta acción es permanente y '
          'no se puede deshacer.',
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
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteAccountAndRequest(ref);
            },
            child: const Text('Eliminar cuenta'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccountAndRequest(WidgetRef ref) async {
    final authRepo = ref.read(authRepositoryProvider);
    final notifService = ref.read(notificationServiceProvider);
    final uid = authRepo.currentUser?.uid;
    if (uid == null) return;

    try {
      // 1. Remover FCM token.
      await notifService.removeToken(uid);
      // 2. Llamar Cloud Function que anonimiza y elimina cuenta.
      final callable = FirebaseFunctions.instance.httpsCallable(
        'anonymizeAndDeleteUser',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      await callable.call();
    } catch (_) {
      // Si falla la eliminación, al menos cerrar sesión.
      try {
        await authRepo.signOut();
      } catch (_) {}
    }
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
