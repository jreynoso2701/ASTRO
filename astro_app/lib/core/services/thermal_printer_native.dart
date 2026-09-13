import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform;
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'thermal_printer_types.dart';

/// Acceso a la impresora térmica (ESC/POS por BLE o USB).
///
/// Es un singleton porque la conexión con la impresora sobrevive a la hoja que
/// la abrió: al imprimir un segundo documento seguido no hay que volver a
/// escanear ni reconectar.
class ThermalPrinterService {
  factory ThermalPrinterService() => _instance;

  ThermalPrinterService._();

  static final ThermalPrinterService _instance = ThermalPrinterService._();

  static const _lastPrinterIdKey = 'thermal_last_printer_id';
  static const _lastPrinterNameKey = 'thermal_last_printer_name';

  final FlutterThermalPrinter _printer = FlutterThermalPrinter.instance;

  /// Dispositivos del último escaneo, por id.
  ///
  /// La interfaz trabaja con [ThermalPrinter], que no sabe conectarse; aquí se
  /// recupera el objeto del paquete que sí sabe.
  final Map<String, Printer> _devices = {};

  Printer? _connected;
  String? _lastPrinterId;
  String? _lastPrinterName;

  /// `true` si la plataforma actual puede hablar con la impresora.
  ///
  /// El escaneo es BLE, que sí existe en iOS, a diferencia del Bluetooth
  /// Classic SPP.
  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows;

  static const _unsupported = ThermalPrinterException(
    'La impresión térmica no está disponible en esta plataforma.',
  );

  ThermalPrinter? get connectedPrinter =>
      _connected == null ? null : _toThermalPrinter(_connected!);

  String? get lastPrinterName => _lastPrinterName;

  /// `true` si [printer] es la impresora que se usó la última vez.
  bool isLastUsed(ThermalPrinter printer) =>
      _lastPrinterId != null && printer.id == _lastPrinterId;

  /// Recupera del disco cuál fue la última impresora usada.
  ///
  /// Se guarda para poder marcarla y ofrecerla primero: en la práctica siempre
  /// se imprime en la misma y así no hay que reconocerla entre varios equipos
  /// Bluetooth cercanos.
  Future<void> loadLastPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastPrinterId = prefs.getString(_lastPrinterIdKey);
      _lastPrinterName = prefs.getString(_lastPrinterNameKey);
    } catch (e) {
      // Perder la preferencia solo cuesta un toque más, no es motivo de error.
      debugPrint('[Thermal] No se pudo leer la última impresora: $e');
    }
  }

  Future<void> _saveLastPrinter(Printer printer) async {
    _lastPrinterId = printer.address;
    _lastPrinterName = printer.name;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (printer.address != null) {
        await prefs.setString(_lastPrinterIdKey, printer.address!);
      }
      if (printer.name != null) {
        await prefs.setString(_lastPrinterNameKey, printer.name!);
      }
    } catch (e) {
      debugPrint('[Thermal] No se pudo guardar la última impresora: $e');
    }
  }

  /// Busca impresoras y va reportando por [onFound] lo que encuentra.
  ///
  /// Reporta en caliente en vez de solo al final porque un escaneo BLE tarda
  /// varios segundos y la primera impresora suele aparecer enseguida.
  Future<List<ThermalPrinter>> scan({
    Duration timeout = const Duration(seconds: 6),
    void Function(List<ThermalPrinter>)? onFound,
  }) async {
    if (!isSupported) throw _unsupported;

    if (!await _printer.isBleTurnedOn()) {
      throw const ThermalPrinterException(
        'El Bluetooth está apagado. Enciéndelo para buscar impresoras.',
      );
    }

    _devices.clear();
    var found = <ThermalPrinter>[];

    try {
      await _printer.getPrinters(
        connectionTypes: [ConnectionType.BLE, ConnectionType.USB],
      );

      await for (final printers in _printer.devicesStream.timeout(
        timeout,
        onTimeout: (sink) => sink.close(),
      )) {
        for (final p in printers) {
          final id = p.address;
          if (id == null || id.isEmpty) continue;
          _devices[id] = p;
        }
        found = _devices.values.map(_toThermalPrinter).toList();
        if (found.isNotEmpty) onFound?.call(found);
      }
    } catch (e) {
      // Un fallo a mitad del escaneo no invalida lo ya encontrado.
      debugPrint('[Thermal] Escaneo interrumpido: $e');
    } finally {
      await stopScan();
    }

    return _devices.values.map(_toThermalPrinter).toList();
  }

  Future<void> stopScan() async {
    try {
      await _printer.stopScan();
    } catch (e) {
      debugPrint('[Thermal] No se pudo detener el escaneo: $e');
    }
  }

  /// Pide al sistema que encienda el Bluetooth.
  Future<void> turnOnBluetooth() async {
    if (!isSupported) throw _unsupported;
    await _printer.turnOnBluetooth();
  }

  /// Conecta con [printer] y la recuerda como última usada.
  Future<void> connect(ThermalPrinter printer) async {
    if (!isSupported) throw _unsupported;

    final device = _devices[printer.id];
    if (device == null) {
      throw const ThermalPrinterException(
        'La impresora ya no está en el último escaneo. Vuelve a buscar.',
      );
    }

    if (_connected != null && _connected!.address != device.address) {
      await disconnect();
    }

    final ok = await _printer.connect(device);
    if (!ok) {
      throw const ThermalPrinterException(
        'No se pudo conectar con la impresora. Comprueba que esté encendida '
        'y dentro de alcance.',
      );
    }
    _connected = device;
    await _saveLastPrinter(device);
  }

  Future<void> disconnect() async {
    final device = _connected;
    _connected = null;
    if (device == null) return;
    try {
      await _printer.disconnect(device);
    } catch (e) {
      debugPrint('[Thermal] No se pudo desconectar: $e');
    }
  }

  /// Manda [bytes] a la impresora, conectando antes si hace falta.
  ///
  /// `longData` trocea el envío: por BLE un recibo largo no cabe en una sola
  /// escritura y la impresora se queda a medias.
  Future<void> printBytes(ThermalPrinter printer, List<int> bytes) async {
    if (!isSupported) throw _unsupported;

    if (_connected == null || _connected!.address != printer.id) {
      await connect(printer);
    }

    try {
      await _printer.printData(_connected!, bytes, longData: true);
    } catch (e) {
      // Si la impresora se apagó o se alejó, la conexión guardada ya no sirve.
      _connected = null;
      throw ThermalPrinterException('No se pudo imprimir: $e');
    }
  }

  ThermalPrinter _toThermalPrinter(Printer p) => ThermalPrinter(
    id: p.address ?? '',
    name: (p.name ?? '').trim().isEmpty ? 'Impresora sin nombre' : p.name!,
    connection: switch (p.connectionType) {
      ConnectionType.USB => ThermalConnection.usb,
      ConnectionType.NETWORK => ThermalConnection.network,
      _ => ThermalConnection.ble,
    },
    isConnected: p.isConnected ?? false,
  );
}
