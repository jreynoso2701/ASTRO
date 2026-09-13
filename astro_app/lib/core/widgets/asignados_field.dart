import 'package:flutter/material.dart';

import 'package:astro/core/models/app_user.dart';
import 'package:astro/core/models/project_assignment.dart';

/// Miembro de proyecto tal como lo entrega `projectMembersProvider`.
typedef ProjectMemberEntry = ({ProjectAssignment assignment, AppUser? user});

/// Resultado de [showAsignadosDialog]: uids y nombres en el mismo orden,
/// con el responsable principal en la primera posición.
typedef AsignadosSelection = ({List<String> uids, List<String> names});

/// Diálogo de selección múltiple de responsables.
///
/// Conserva el orden en que se marcan: el primero es el principal. Devuelve
/// `null` si se cancela.
Future<AsignadosSelection?> showAsignadosDialog({
  required BuildContext context,
  required List<ProjectMemberEntry> members,
  required List<String> initialUids,
  String title = 'Asignar responsables',
  String emptyMessage = 'No hay miembros disponibles en este proyecto',
  IconData avatarIcon = Icons.person_outline,
}) {
  // Selección ordenada: se respeta el orden actual y luego el de marcado.
  final selected = <String>[
    ...initialUids.where(
      (uid) => members.any((m) => m.assignment.userId == uid),
    ),
  ];

  String nameOf(String uid) {
    final m = members.firstWhere((m) => m.assignment.userId == uid);
    return m.user?.displayName ?? uid;
  }

  return showDialog<AsignadosSelection>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 380,
          child: members.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(emptyMessage),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    if (selected.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'El primero en marcarse es el responsable principal.',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ),
                    for (final m in members)
                      Builder(
                        builder: (_) {
                          final uid = m.assignment.userId;
                          final index = selected.indexOf(uid);
                          return CheckboxListTile(
                            value: index >= 0,
                            onChanged: (checked) => setState(() {
                              if (checked ?? false) {
                                if (index < 0) selected.add(uid);
                              } else {
                                selected.remove(uid);
                              }
                            }),
                            secondary: CircleAvatar(
                              child: Icon(
                                index == 0 ? Icons.star : avatarIcon,
                                size: 18,
                              ),
                            ),
                            title: Text(m.user?.displayName ?? uid),
                            subtitle: Text(m.user?.email ?? ''),
                          );
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
            onPressed: () => Navigator.pop(ctx, (
              uids: List<String>.from(selected),
              names: selected.map(nameOf).toList(),
            )),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

/// Campo de asignación que admite varios responsables.
///
/// Muestra los responsables seleccionados como chips eliminables y un menú
/// para agregar a los miembros del proyecto que aún no están asignados.
/// El primero de la lista se considera el responsable principal.
class AsignadosField extends StatelessWidget {
  const AsignadosField({
    super.key,
    required this.assignedUids,
    required this.assignedNames,
    required this.available,
    required this.onAdd,
    required this.onRemove,
    this.labelText = 'Asignar a',
  });

  final List<String> assignedUids;
  final List<String> assignedNames;
  final List<ProjectMemberEntry> available;
  final void Function(String userId, String name) onAdd;
  final void Function(int index) onRemove;
  final String labelText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: const Icon(Icons.people_outline),
        helperText: assignedUids.length > 1
            ? 'El primero es el responsable principal'
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: assignedUids.isEmpty
                ? Text(
                    'Sin asignar',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < assignedUids.length; i++)
                        InputChip(
                          key: ValueKey(assignedUids[i]),
                          label: Text(
                            i < assignedNames.length &&
                                    assignedNames[i].isNotEmpty
                                ? assignedNames[i]
                                : assignedUids[i],
                          ),
                          avatar: i == 0
                              ? const Icon(Icons.star, size: 16)
                              : const Icon(Icons.person_outline, size: 16),
                          onDeleted: () => onRemove(i),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
          ),
          PopupMenuButton<ProjectMemberEntry>(
            enabled: available.isNotEmpty,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: available.isEmpty
                ? 'No hay más miembros disponibles'
                : 'Agregar responsable',
            onSelected: (m) => onAdd(
              m.assignment.userId,
              m.user?.displayName ?? m.assignment.userId,
            ),
            itemBuilder: (context) => [
              for (final m in available)
                PopupMenuItem<ProjectMemberEntry>(
                  value: m,
                  child: Text(m.user?.displayName ?? m.assignment.userId),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
