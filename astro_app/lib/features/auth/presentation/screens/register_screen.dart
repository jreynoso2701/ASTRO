import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de registro.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final credential = await repo.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Actualizar displayName
      final displayName = _nameController.text.trim();
      await credential.user?.updateDisplayName(displayName);

      // Crear documento en Firestore para que Root lo vea y el router funcione.
      final user = credential.user;
      if (user != null) {
        final userRepo = ref.read(userRepositoryProvider);
        await userRepo.ensureUserExists(
          uid: user.uid,
          displayName: displayName,
          email: user.email ?? '',
        );
      }
    } on Exception catch (e) {
      setState(() => _errorMessage = _mapAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final credential = await repo.signInWithGoogle();

      // Si es usuario nuevo, crear documento en Firestore.
      final user = credential.user;
      if (user != null) {
        final userRepo = ref.read(userRepositoryProvider);
        await userRepo.ensureUserExists(
          uid: user.uid,
          displayName: user.displayName ?? '',
          email: user.email ?? '',
          photoUrl: user.photoURL,
        );
      }
    } on Exception catch (e) {
      setState(() => _errorMessage = _mapAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthError(Exception e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('email-already-in-use')) {
      return 'Ya existe una cuenta con ese correo.';
    }
    if (msg.contains('weak-password')) return 'La contraseña es muy débil.';
    if (msg.contains('invalid-email')) return 'El correo no es válido.';
    if (msg.contains('network')) {
      return 'Error de conexión. Verifica tu internet.';
    }
    if (msg.contains('cancelled')) return 'Registro cancelado.';
    return 'Ocurrió un error. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppBreakpoints.compact;

    final formContent = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header
          Text('Crear cuenta', style: theme.textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(
            'Regístrate para comenzar',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 40),

          // ── Name
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa tu nombre';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa tu correo electrónico';
              }
              if (!RegExp(
                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
              ).hasMatch(value.trim())) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa una contraseña';
              }
              if (value.length < 6) {
                return 'La contraseña debe tener al menos 6 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Confirm password
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
            onFieldSubmitted: (_) => _registerWithEmail(),
          ),
          const SizedBox(height: 24),

          // ── Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Register button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _registerWithEmail,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear cuenta'),
            ),
          ),
          const SizedBox(height: 24),

          // ── Divider
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'o',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 24),

          // ── Google sign in
          GoogleSignInButton(
            onPressed: _isLoading ? null : _signInWithGoogle,
            label: 'Registrarse con Google',
          ),
          const SizedBox(height: 32),

          // ── Login link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '¿Ya tienes cuenta? ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: _isLoading ? null : () => context.pop(),
                child: const Text('Inicia sesión'),
              ),
            ],
          ),
        ],
      ),
    );

    // ── Layout adaptativo
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 0 : 24,
              vertical: 32,
            ),
            child: isWide
                ? SizedBox(
                    width: 420,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: formContent,
                      ),
                    ),
                  )
                : formContent,
          ),
        ),
      ),
    );
  }
}
