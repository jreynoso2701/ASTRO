import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';

/// Pantalla de onboarding para usuarios nuevos sin proyectos asignados.
///
/// Se muestra cuando el usuario se ha registrado pero aún no
/// tiene ningún proyecto/rol asignado por un administrador.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo / ícono
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFD71921).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rocket_launch_outlined,
                  size: 48,
                  color: Color(0xFFD71921),
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'BIENVENIDO A ASTRO',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                'Tu cuenta ha sido creada exitosamente.',
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
                        Icons.hourglass_top_outlined,
                        size: 36,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Esperando asignación',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Un administrador te asignará a un proyecto y '
                        'rol próximamente. Una vez asignado, podrás '
                        'acceder al sistema completo.',
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

              // Pasos
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
                title: 'Asignación pendiente',
                subtitle: 'El administrador asignará tu proyecto y rol.',
              ),
              const SizedBox(height: 8),
              _StepTile(
                icon: Icons.radio_button_unchecked,
                color: theme.colorScheme.onSurfaceVariant,
                title: 'Acceso al sistema',
                subtitle: 'Podrás usar ASTRO una vez asignado.',
              ),

              const Spacer(flex: 3),

              // Cerrar sesión
              OutlinedButton.icon(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
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
