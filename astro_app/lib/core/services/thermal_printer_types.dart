/// Fallo de impresión con un motivo legible para el usuario.
class ThermalPrinterException implements Exception {
  const ThermalPrinterException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Impresora Bluetooth emparejada.
///
/// Es un tipo propio en vez del `BluetoothInfo` del paquete para que la interfaz
/// no dependa de una librería que solo existe en móvil.
class BluetoothPrinter {
  const BluetoothPrinter({required this.name, required this.macAddress});

  final String name;
  final String macAddress;
}
