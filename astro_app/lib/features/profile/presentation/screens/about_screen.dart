import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pantalla "Acerca de ASTRO".
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de ASTRO')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              // ── Encabezado ─────────────────────────
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.rocket_launch,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ASTRO',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (info != null)
                      Text(
                        'Versión ${info.version} · Build ${info.buildNumber}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Gestión y control de progreso de proyectos\nde desarrollo de software.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '© Constelación R',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Legal ──────────────────────────────
              _SectionLabel(label: 'LEGAL'),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Aviso de Privacidad'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const _PrivacyPolicyScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Términos y Condiciones'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const _TermsConditionsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Créditos ───────────────────────────
              _SectionLabel(label: 'CRÉDITOS'),
              const SizedBox(height: 8),
              _CreditGroup(
                title: 'Constelación R',
                members: const [
                  'Francisco Ramon Rios Santana',
                  'Juan Rafael Reynoso S',
                  'Victoria Daren Castañeda',
                  'Iván Alejandro Ramirez',
                  'Carlos Rios Santana',
                  'Pedro Rios Santana',
                ],
              ),
              const SizedBox(height: 12),
              _CreditGroup(
                title: 'Consultores en Tecnologías de la Información',
                members: const [
                  'Jonathan Iván Ramírez Partida',
                  'Javier Alejandro López Rangel',
                  'Alexis Emmanuel Ramírez Partida',
                  'Brandon Raúl Suárez Valencia',
                  'Emmanuel Aceves Martínez',
                ],
              ),
              const SizedBox(height: 12),
              _CreditGroup(
                title: 'Equipo de Testing',
                members: const [
                  'Leonardo Gabriel Reynoso Castañeda',
                  'Evan Miguel Reynoso Castañeda',
                  'Jose Rafael Reynoso Castañeda',
                ],
              ),

              const SizedBox(height: 28),

              // ── Contacto ───────────────────────────
              _SectionLabel(label: 'CONTACTO'),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('juan@constelacion-r.com'),
                      onTap: () => _launchUrl('mailto:juan@constelacion-r.com'),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: const Text('constelacion-r.com'),
                      onTap: () => _launchUrl('https://constelacion-r.com'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Widgets internos ────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
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

class _CreditGroup extends StatelessWidget {
  const _CreditGroup({required this.title, required this.members});
  final String title;
  final List<String> members;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...members.map(
              (name) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Aviso de Privacidad ─────────────────────────────────

class _PrivacyPolicyScreen extends StatelessWidget {
  const _PrivacyPolicyScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Aviso de Privacidad')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          Text(
            'Aviso de Privacidad',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Última actualización: marzo 2026',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _legalSection(
            theme,
            'Responsable del tratamiento de datos',
            'Constelación R es responsable del tratamiento de sus datos personales. '
                'Para cualquier asunto relacionado con el presente aviso de privacidad, '
                'puede contactarnos a través de:\n\n'
                '• Correo electrónico: juan@constelacion-r.com\n'
                '• Sitio web: https://constelacion-r.com',
          ),
          _legalSection(
            theme,
            'Datos personales que recopilamos',
            'Para brindar nuestros servicios a través de ASTRO, podemos recopilar '
                'los siguientes datos personales:\n\n'
                '• Nombre completo.\n'
                '• Dirección de correo electrónico.\n'
                '• Fotografía de perfil (opcional).\n'
                '• Información relacionada con los proyectos en los que participa '
                '(incidentes, requerimientos, minutas, documentos adjuntos, citas).',
          ),
          _legalSection(
            theme,
            'Finalidad del tratamiento',
            'Los datos personales recopilados serán utilizados exclusivamente para:\n\n'
                '• Gestionar su cuenta de usuario dentro de ASTRO.\n'
                '• Dar seguimiento al progreso de los proyectos de desarrollo de software asignados.\n'
                '• Facilitar la comunicación entre los participantes del proyecto.\n'
                '• Enviar notificaciones relacionadas con la actividad de sus proyectos.',
          ),
          _legalSection(
            theme,
            'Almacenamiento de información',
            'La información y archivos adjuntos generados dentro de ASTRO se '
                'almacenan en los repositorios de Constelación R, donde podrán ser '
                'gestionados por la empresa. Los documentos e información registrados '
                'en la plataforma son copias de documentos oficiales y se utilizan '
                'únicamente para dar seguimiento a los proyectos.',
          ),
          _legalSection(
            theme,
            'Derechos ARCO',
            'Usted tiene derecho a acceder, rectificar, cancelar u oponerse al '
                'tratamiento de sus datos personales (derechos ARCO). Para ejercer '
                'cualquiera de estos derechos, incluyendo la baja directa de su cuenta '
                'y la eliminación de su información, favor de comunicarse con nosotros '
                'a través de nuestros medios de contacto:\n\n'
                '• Correo electrónico: juan@constelacion-r.com\n'
                '• Sitio web: https://constelacion-r.com',
          ),
          _legalSection(
            theme,
            'Modificaciones al aviso de privacidad',
            'Constelación R se reserva el derecho de modificar el presente aviso '
                'de privacidad. Cualquier cambio será notificado a través de la '
                'aplicación o por correo electrónico.',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Términos y Condiciones ──────────────────────────────

class _TermsConditionsScreen extends StatelessWidget {
  const _TermsConditionsScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Términos y Condiciones')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          Text(
            'Términos y Condiciones',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Última actualización: marzo 2026',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _legalSection(
            theme,
            '1. Aceptación de los términos',
            'Al utilizar la aplicación ASTRO, usted acepta los presentes términos '
                'y condiciones en su totalidad. Si no está de acuerdo con alguno de '
                'estos términos, le solicitamos no utilizar la plataforma.',
          ),
          _legalSection(
            theme,
            '2. Descripción del servicio',
            'ASTRO es una plataforma desarrollada por Constelación R para la '
                'gestión y control de progreso de proyectos de desarrollo de software. '
                'Permite a los usuarios registrar incidentes, dar seguimiento a '
                'requerimientos, documentar minutas de reunión, gestionar citas y '
                'adjuntar archivos relacionados con los proyectos.',
          ),
          _legalSection(
            theme,
            '3. Uso de la información',
            'La información y material registrados en ASTRO, incluyendo documentos '
                'adjuntos, son copias de documentos oficiales y se utilizan '
                'exclusivamente para dar seguimiento a los proyectos de desarrollo de '
                'software. Dicha información se almacena en los repositorios de '
                'Constelación R, donde podrá ser gestionada por la empresa.',
          ),
          _legalSection(
            theme,
            '4. Cuentas de usuario',
            'Cada usuario es responsable de mantener la confidencialidad de sus '
                'credenciales de acceso. El uso de la cuenta es personal e '
                'intransferible. En caso de detectar un uso no autorizado, favor de '
                'notificarnos de inmediato a través de nuestros medios de contacto.',
          ),
          _legalSection(
            theme,
            '5. Propiedad intelectual',
            'ASTRO, su diseño, código fuente, marca y contenido son propiedad de '
                'Constelación R. Queda prohibida la reproducción, distribución o '
                'modificación total o parcial sin autorización previa por escrito.',
          ),
          _legalSection(
            theme,
            '6. Limitación de responsabilidad',
            'Constelación R no será responsable por daños directos o indirectos '
                'derivados del uso o imposibilidad de uso de la plataforma, '
                'interrupciones del servicio o pérdida de información fuera de '
                'nuestro control.',
          ),
          _legalSection(
            theme,
            '7. Baja de cuenta',
            'Si desea dar de baja su cuenta y eliminar su información de ASTRO, '
                'favor de comunicarse con nosotros a través de nuestros medios de '
                'contacto. Procesaremos su solicitud en el menor tiempo posible.\n\n'
                '• Correo electrónico: juan@constelacion-r.com\n'
                '• Sitio web: https://constelacion-r.com',
          ),
          _legalSection(
            theme,
            '8. Modificaciones',
            'Constelación R se reserva el derecho de modificar los presentes '
                'términos y condiciones en cualquier momento. Los cambios serán '
                'notificados a los usuarios a través de la aplicación o por correo '
                'electrónico.',
          ),
          _legalSection(
            theme,
            '9. Contacto',
            'Para cualquier duda, aclaración o solicitud relacionada con estos '
                'términos y condiciones, favor de comunicarse con nosotros:\n\n'
                '• Correo electrónico: juan@constelacion-r.com\n'
                '• Sitio web: https://constelacion-r.com',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Helpers compartidos ─────────────────────────────────

Widget _legalSection(ThemeData theme, String title, String body) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
