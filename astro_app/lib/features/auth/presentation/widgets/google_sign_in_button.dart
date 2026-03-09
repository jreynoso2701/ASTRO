import 'package:flutter/material.dart';

/// Botón de "Iniciar sesión con Google" estilizado.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    required this.onPressed,
    this.label = 'Continuar con Google',
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Image.network(
          'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
          height: 20,
          width: 20,
          errorBuilder: (_, __, ___) => Icon(
            Icons.g_mobiledata,
            size: 24,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        label: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
