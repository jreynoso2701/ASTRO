import 'package:flutter/material.dart';

/// Botón de "Iniciar sesión con Apple" estilizado.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    required this.onPressed,
    this.label = 'Continuar con Apple',
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
        icon: Icon(
          Icons.apple,
          size: 24,
          color: isDark ? Colors.white : Colors.black87,
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
