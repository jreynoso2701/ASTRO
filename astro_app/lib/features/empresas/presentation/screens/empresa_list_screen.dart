import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/empresa.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de gestión de empresas — accesible solo para Root.
class EmpresaListScreen extends ConsumerStatefulWidget {
  const EmpresaListScreen({super.key});

  @override
  ConsumerState<EmpresaListScreen> createState() => _EmpresaListScreenState();
}

class _EmpresaListScreenState extends ConsumerState<EmpresaListScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empresasAsync = ref.watch(allEmpresasProvider);

    return SafeArea(
      child: Column(
        children: [
          // ── Header + Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'EMPRESAS',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nueva'),
                      onPressed: () => context.push('/empresas/new'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, RFC o contacto...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _search = ''),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ],
            ),
          ),

          // ── Count ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: empresasAsync.when(
                data: (all) {
                  final filtered = _filter(all);
                  return Text(
                    '${filtered.length} de ${all.length} empresas',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── List / Grid ──
          Expanded(
            child: empresasAsync.when(
              data: (all) {
                final filtered = _filter(all);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron empresas'),
                  );
                }
                return _EmpresaGrid(empresas: filtered);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error al cargar empresas: $e')),
            ),
          ),
        ],
      ),
    );
  }

  List<Empresa> _filter(List<Empresa> all) {
    if (_search.isEmpty) return all;
    final q = _search.toUpperCase();
    return all.where((e) {
      return e.nombreEmpresa.toUpperCase().contains(q) ||
          (e.rfc?.toUpperCase().contains(q) ?? false) ||
          (e.contacto?.toUpperCase().contains(q) ?? false) ||
          (e.email?.toUpperCase().contains(q) ?? false);
    }).toList();
  }
}

class _EmpresaGrid extends StatelessWidget {
  const _EmpresaGrid({required this.empresas});
  final List<Empresa> empresas;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= AppBreakpoints.medium) {
      final cols = adaptiveGridColumns(width);
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 120,
        ),
        itemCount: empresas.length,
        itemBuilder: (context, i) => _EmpresaCard(empresa: empresas[i]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: empresas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _EmpresaCard(empresa: empresas[i]),
    );
  }
}

class _EmpresaCard extends StatelessWidget {
  const _EmpresaCard({required this.empresa});
  final Empresa empresa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactive = !empresa.isActive;

    return Opacity(
      opacity: inactive ? 0.5 : 1.0,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/empresas/${empresa.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Logo / avatar
                CircleAvatar(
                  radius: 24,
                  backgroundImage: empresa.logoUrl != null
                      ? NetworkImage(empresa.logoUrl!)
                      : null,
                  child: empresa.logoUrl == null
                      ? Text(
                          empresa.nombreEmpresa.isNotEmpty
                              ? empresa.nombreEmpresa[0].toUpperCase()
                              : '?',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        empresa.nombreEmpresa,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (empresa.rfc != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          empresa.rfc!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (empresa.isActive
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFFD32F2F))
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              empresa.isActive ? 'Activa' : 'Inactiva',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: empresa.isActive
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFD32F2F),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (empresa.contacto != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                empresa.contacto!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
