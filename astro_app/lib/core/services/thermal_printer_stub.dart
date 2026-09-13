import 'thermal_printer_types.dart';

/// Implementación vacía para web, donde el navegador no puede abrir un socket
/// con la impresora.
///
/// Con [isSupported] en `false` la interfaz nunca ofrece imprimir, así que
/// estos métodos solo existen para que el tipo compile.
class ThermalPrinterService {
  factory ThermalPrinterService() => _instance;

  ThermalPrinterService._();

  static final ThermalPrinterService _instance = ThermalPrinterService._();

  static bool get isSupported => false;

  ThermalPrinter? get connectedPrinter => null;

  String? get lastPrinterName => null;

  bool isLastUsed(ThermalPrinter printer) => false;

  Future<void> loadLastPrinter() async {}

  Future<List<ThermalPrinter>> scan({
    Duration timeout = const Duration(seconds: 6),
    void Function(List<ThermalPrinter>)? onFound,
  }) async => throw _unsupported;

  Future<void> stopScan() async {}

  Future<void> turnOnBluetooth() async => throw _unsupported;

  Future<void> connect(ThermalPrinter printer) async => throw _unsupported;

  Future<void> disconnect() async {}

  Future<void> printBytes(ThermalPrinter printer, List<int> bytes) async =>
      throw _unsupported;

  static const _unsupported = ThermalPrinterException(
    'La impresión térmica no está disponible en esta plataforma.',
  );
}
