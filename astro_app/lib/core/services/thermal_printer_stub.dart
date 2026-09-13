import 'thermal_printer_types.dart';

/// Implementación vacía para las plataformas sin Bluetooth Classic (web).
///
/// Con [isSupported] en `false` la interfaz nunca ofrece imprimir, así que
/// estos métodos solo existen para que el tipo compile.
class ThermalPrinterService {
  const ThermalPrinterService();

  static bool get isSupported => false;

  Future<List<BluetoothPrinter>> pairedPrinters() async =>
      throw const ThermalPrinterException(
        'La impresión térmica no está disponible en esta plataforma.',
      );

  Future<void> printBytes(String macAddress, List<int> bytes) async =>
      throw const ThermalPrinterException(
        'La impresión térmica no está disponible en esta plataforma.',
      );
}
