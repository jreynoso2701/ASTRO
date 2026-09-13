/// Fallo de impresión con un motivo legible para el usuario.
class ThermalPrinterException implements Exception {
  const ThermalPrinterException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Vía por la que se habla con la impresora.
enum ThermalConnection {
  ble('Bluetooth'),
  usb('USB'),
  network('Red');

  const ThermalConnection(this.label);

  final String label;
}

/// Una impresora encontrada durante el escaneo.
///
/// Es un tipo propio y no el `Printer` del paquete para que la interfaz y los
/// recibos no dependan de una librería que solo existe fuera de web.
class ThermalPrinter {
  const ThermalPrinter({
    required this.id,
    required this.name,
    required this.connection,
    this.isConnected = false,
  });

  /// Dirección del dispositivo; identifica a la impresora entre escaneos y es
  /// lo que se guarda como "última usada".
  final String id;

  final String name;
  final ThermalConnection connection;
  final bool isConnected;

  @override
  bool operator ==(Object other) =>
      other is ThermalPrinter && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
