import 'package:flutter/material.dart';

import 'package:astro/core/services/thermal_printer_service.dart';
import 'package:astro/core/services/thermal_receipts.dart';

/// Abre la hoja de impresión térmica y manda [buildBytes] a la impresora que
/// elija el usuario.
///
/// [buildBytes] se evalúa al pulsar imprimir y no antes, para que el recibo
/// lleve la hora real de impresión.
Future<void> showThermalPrintSheet(
  BuildContext context, {
  required String title,
  required Future<List<int>> Function() buildBytes,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ThermalPrintSheet(title: title, buildBytes: buildBytes),
  );
}

class _ThermalPrintSheet extends StatefulWidget {
  const _ThermalPrintSheet({required this.title, required this.buildBytes});

  final String title;
  final Future<List<int>> Function() buildBytes;

  @override
  State<_ThermalPrintSheet> createState() => _ThermalPrintSheetState();
}

class _ThermalPrintSheetState extends State<_ThermalPrintSheet> {
  final _service = ThermalPrinterService();

  List<ThermalPrinter> _printers = const [];
  ThermalPrinter? _selected;
  String? _error;
  bool _scanning = false;
  bool _busy = false;

  /// La última impresora usada primero: casi siempre es la que se busca.
  List<ThermalPrinter> get _sorted {
    final sorted = [..._printers];
    sorted.sort((a, b) {
      final aLast = _service.isLastUsed(a);
      final bLast = _service.isLastUsed(b);
      if (aLast != bLast) return aLast ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    // La conexión se mantiene a propósito (el servicio es un singleton), pero
    // un escaneo abierto sí consume radio y hay que cerrarlo.
    _service.stopScan();
    super.dispose();
  }

  Future<void> _init() async {
    await _service.loadLastPrinter();
    _selected = _service.connectedPrinter;
    await _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _printers = const [];
    });
    try {
      final printers = await _service.scan(
        onFound: (found) {
          if (mounted) setState(() => _printers = found);
        },
      );
      if (!mounted) return;
      setState(() {
        _printers = printers;
        _scanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = _message(e);
      });
    }
  }

  Future<void> _select(ThermalPrinter printer) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.connect(printer);
      if (!mounted) return;
      setState(() {
        _selected = printer;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(e);
      });
    }
  }

  Future<void> _print({required bool test}) async {
    final printer = _selected;
    if (printer == null) {
      setState(() => _error = 'Elige una impresora de la lista.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final bytes = test ? await buildTestReceipt() : await widget.buildBytes();
      await _service.printBytes(printer, bytes);
      if (!mounted) return;
      setState(() => _busy = false);
      if (test) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Prueba enviada a la impresora')),
        );
      } else {
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(content: Text('Enviado a ${printer.name}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(e);
      });
    }
  }

  String _message(Object e) =>
      e is ThermalPrinterException ? e.message : e.toString();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final printers = _sorted;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.print_outlined, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Imprimir en térmica',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _scanning || _busy ? null : _scan,
                  icon: _scanning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_scanning ? 'Buscando…' : 'Buscar'),
                ),
              ],
            ),
            Text(
              widget.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: printers.isEmpty
                  ? _EmptyState(scanning: _scanning)
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: printers.length,
                      itemBuilder: (_, i) {
                        final printer = printers[i];
                        final isSelected = _selected?.id == printer.id;
                        final isLast = _service.isLastUsed(printer);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            printer.connection == ThermalConnection.usb
                                ? Icons.usb
                                : Icons.bluetooth,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  printer.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: isSelected
                                      ? const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        )
                                      : null,
                                ),
                              ),
                              if (isLast) ...[
                                const SizedBox(width: 8),
                                _Badge(label: 'Última'),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${printer.connection.label} · ${printer.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          selected: isSelected,
                          onTap: _busy ? null : () => _select(printer),
                        );
                      },
                    ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selected == null || _busy
                        ? null
                        : () => _print(test: true),
                    icon: const Icon(Icons.science_outlined, size: 18),
                    label: const Text('Prueba'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _selected == null || _busy
                        ? null
                        : () => _print(test: false),
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print, size: 18),
                    label: Text(_busy ? 'Enviando…' : 'Imprimir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scanning});

  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (scanning)
            const CircularProgressIndicator()
          else
            Icon(
              Icons.print_disabled_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          const SizedBox(height: 12),
          Text(
            scanning ? 'Buscando impresoras…' : 'No se encontró ninguna',
            style: theme.textTheme.bodyMedium,
          ),
          if (!scanning) ...[
            const SizedBox(height: 4),
            Text(
              'Enciende la impresora y acércala al dispositivo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
