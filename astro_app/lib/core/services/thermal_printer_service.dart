/// Punto de entrada de la impresión térmica.
///
/// La implementación real depende de `print_bluetooth_thermal`, que importa
/// `dart:io` y por tanto rompería la compilación de web: se elige por import
/// condicional y en web queda el stub, que reporta `isSupported == false`.
library;

export 'thermal_printer_types.dart';
export 'thermal_printer_stub.dart'
    if (dart.library.io) 'thermal_printer_native.dart';
