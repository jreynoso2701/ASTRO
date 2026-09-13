import 'package:flutter/material.dart';

import 'package:astro/core/services/thermal_printer_service.dart';

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
  final _service = const ThermalPrinterService();

  List<BluetoothPrinter> _printers = const [];
  String? _error;
  bool _loading = true;
  String? _printing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final printers = await _service.pairedPrinters();
      if (!mounted) return;
      setState(() {
        _printers = printers;
        _loading = false;
      });
    } on ThermalPrinterException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo listar las impresoras: $e';
        _loading = false;
      });
    }
  }

  Future<void> _print(BluetoothPrinter printer) async {
    setState(() => _printing = printer.macAddress);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final bytes = await widget.buildBytes();
      await _service.printBytes(printer.macAddress, bytes);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Enviado a ${printer.name}')),
      );
    } on ThermalPrinterException catch (e) {
      if (!mounted) return;
      setState(() {
        _printing = null;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _printing = null;
        _error = 'No se pudo imprimir: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_error != null) ...[
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
                const SizedBox(height: 12),
              ],
              for (final printer in _printers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.point_of_sale_outlined),
                  title: Text(printer.name),
                  subtitle: Text(printer.macAddress),
                  trailing: _printing == printer.macAddress
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _printing == null ? () => _print(printer) : null,
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _printing == null ? _load : null,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Volver a buscar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
