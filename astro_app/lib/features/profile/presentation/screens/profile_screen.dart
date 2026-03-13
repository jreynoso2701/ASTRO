import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:astro/core/theme/theme_provider.dart';
import 'package:astro/core/services/storage_service.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/ai_agent/providers/ai_agent_providers.dart';

/// Pantalla de perfil y configuración de cuenta.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingPhoto = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentUserProfileProvider).value;
    final authRepo = ref.read(authRepositoryProvider);
    final isPasswordUser = authRepo.isPasswordUser;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                // ── Avatar + info ──────────────────────
                _ProfileHeader(
                  photoUrl: profile.photoUrl,
                  displayName: profile.displayName,
                  email: profile.email,
                  isRoot: profile.isRoot,
                  isUploading: _isUploadingPhoto,
                  onChangePhoto: () => _pickAndUploadPhoto(profile.uid),
                ),

                const SizedBox(height: 32),

                // ── Sección: Cuenta ────────────────────
                _SectionTitle(label: 'CUENTA'),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: 'Editar nombre',
                  subtitle: profile.displayName,
                  onTap: () =>
                      _showEditNameDialog(profile.uid, profile.displayName),
                ),
                if (isPasswordUser)
                  _SettingsTile(
                    icon: Icons.lock_outline,
                    title: 'Cambiar contraseña',
                    subtitle: '••••••••',
                    onTap: () => _showChangePasswordDialog(),
                  ),

                const SizedBox(height: 24),

                // ── Sección: Apariencia ────────────────
                _SectionTitle(label: 'APARIENCIA'),
                const SizedBox(height: 8),
                _ThemeTile(
                  themeMode: themeMode,
                  onChanged: (mode) =>
                      ref.read(themeModeProvider.notifier).setThemeMode(mode),
                ),

                const SizedBox(height: 24),

                // ── Sección: Notificaciones ────────────
                _SectionTitle(label: 'NOTIFICACIONES'),
                const SizedBox(height: 8),
                _NotificationToggleTile(
                  enabled: profile.pushGlobalEnabled,
                  onChanged: (value) async {
                    await ref.read(userRepositoryProvider).updateUserFields(
                      profile.uid,
                      {'pushGlobalEnabled': value},
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ── Sección: Asistente IA ──────────────
                _SectionTitle(label: 'ASISTENTE IA'),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Borrar historial del agente',
                  subtitle: 'Elimina todas las conversaciones con ASTRO AI',
                  onTap: () => _confirmClearAiHistory(),
                ),

                const SizedBox(height: 24),

                // ── Sección: Información ───────────────
                _SectionTitle(label: 'INFORMACIÓN'),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'Acerca de ASTRO',
                  onTap: () => context.push('/about'),
                ),

                const SizedBox(height: 32),

                // ── Cerrar sesión ──────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _confirmLogout(),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // ── Acciones ─────────────────────────────────────────

  void _confirmClearAiHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar historial'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar todo el historial de conversaciones con ASTRO AI? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(aiChatNotifierProvider.notifier).clearHistory();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Historial del agente eliminado'),
                  ),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(String uid) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final storageService = StorageService();
      final url = await storageService.uploadToPath(
        'users/$uid/profile',
        image,
      );

      // Actualizar Firestore
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.updateProfile(uid, photoUrl: url);

      // Actualizar Firebase Auth
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.updateAuthProfile(photoURL: url);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Foto actualizada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al subir foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showEditNameDialog(String uid, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre completo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == currentName) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx);
              try {
                final userRepo = ref.read(userRepositoryProvider);
                await userRepo.updateProfile(uid, displayName: newName);

                final authRepo = ref.read(authRepositoryProvider);
                await authRepo.updateAuthProfile(displayName: newName);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nombre actualizado')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña',
                ),
                validator: (v) {
                  if (v != newPassCtrl.text) return 'No coinciden';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
                final authRepo = ref.read(authRepositoryProvider);
                final email = authRepo.currentUser?.email ?? '';

                await authRepo.reauthenticateWithEmail(
                  email: email,
                  password: currentPassCtrl.text,
                );
                await authRepo.updatePassword(newPassCtrl.text);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contraseña actualizada')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().contains('wrong-password')
                            ? 'Contraseña actual incorrecta'
                            : 'Error: $e',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
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
              final authRepo = ref.read(authRepositoryProvider);
              await authRepo.signOut();
            },
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

// ── Widgets internos ───────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.photoUrl,
    required this.displayName,
    required this.email,
    required this.isRoot,
    required this.isUploading,
    required this.onChangePhoto,
  });

  final String? photoUrl;
  final String displayName;
  final String email;
  final bool isRoot;
  final bool isUploading;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        GestureDetector(
          onTap: isUploading ? null : onChangePhoto,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl!)
                    : null,
                child: photoUrl == null
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: theme.textTheme.headlineLarge,
                      )
                    : null,
              ),
              if (isUploading)
                const Positioned.fill(
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(displayName, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          email,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (isRoot) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD71921).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'ROOT',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFFD71921),
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        letterSpacing: 1,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        title: Text(title),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              )
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.themeMode, required this.onChanged});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              themeMode == ThemeMode.dark
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(child: Text('Tema', style: theme.textTheme.bodyLarge)),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode, size: 18),
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode, size: 18),
                  label: Text('Light'),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (set) => onChanged(set.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationToggleTile extends StatelessWidget {
  const _NotificationToggleTile({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: SwitchListTile(
        secondary: Icon(
          enabled
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: const Text('Notificaciones push'),
        subtitle: Text(
          enabled ? 'Activadas' : 'Desactivadas',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        value: enabled,
        onChanged: onChanged,
      ),
    );
  }
}
