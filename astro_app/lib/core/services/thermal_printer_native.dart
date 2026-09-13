import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'thermal_printer_types.dart';

/// Acceso a la impresora térmica Bluetooth (ESC/POS sobre SPP).
///
/// Solo Android: el perfil Bluetooth Classic SPP que usan estas impresoras no
/// está disponible para apps de iOS sin certificación MFi, así que en el resto
/// de plataformas la opción de imprimir ni siquiera se ofrece.
class ThermalPrinterService {
  const ThermalPrinterService();

  /// `true` si la plataforma actual puede hablar con la impresora.
  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  static const _unsupported = ThermalPrinterException(
    'La impresión térmica solo está disponible en Android.',
  );

  /// Impresoras ya emparejadas en los ajustes de Bluetooth del teléfono.
  ///
  /// El emparejamiento se hace desde Android, no desde la app: así la clave de
  /// la impresora se gestiona una sola vez y aquí solo se elige.
  Future<List<BluetoothPrinter>> pairedPrinters() async {
    if (!isSupported) throw _unsupported;

    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      throw const ThermalPrinterException(
        'Falta el permiso de Bluetooth. Concédelo en los ajustes de la app.',
      );
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const ThermalPrinterException('El Bluetooth está apagado.');
    }

    final devices = await PrintBluetoothThermal.pairedBluetooths;
    if (devices.isEmpty) {
      throw const ThermalPrinterException(
        'No hay dispositivos emparejados. Empareja la impresora desde los '
        'ajustes de Bluetooth del teléfono y vuelve a intentarlo.',
      );
    }
    return devices
        .map((d) => BluetoothPrinter(name: d.name, macAddress: d.macAdress))
        .toList();
  }

  /// Conecta con [macAddress] e imprime [bytes].
  ///
  /// Siempre desconecta al terminar: la impresora acepta una sola conexión y
  /// dejarla abierta impide imprimir desde cualquier otro sitio.
  Future<void> printBytes(String macAddress, List<int> bytes) async {
    if (!isSupported) throw _unsupported;

    final connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: macAddress,
    );
    if (!connected) {
      throw const ThermalPrinterException(
        'No se pudo conectar con la impresora. Comprueba que esté encendida '
        'y dentro de alcance.',
      );
    }

    try {
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      if (!ok) {
        throw const ThermalPrinterException(
          'La impresora rechazó el trabajo de impresión.',
        );
      }
    } finally {
      await PrintBluetoothThermal.disconnect;
    }
  }
}
