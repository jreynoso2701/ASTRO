# Compilación de ASTRO

## Claves inyectadas en compilación

Algunas claves no viven en el repositorio y se pasan al compilador con
`--dart-define`. Se leen con `String.fromEnvironment`, que es una **constante de
compilación**: si el build no las pasa, la constante queda vacía y la función
correspondiente se desactiva en silencio.

| Clave | Usada por | Efecto si falta |
|---|---|---|
| `GOOGLE_MAPS_API_KEY` | Búsqueda de dirección en Minutas (`placesServiceProvider`) | El botón avisa que la búsqueda no está disponible; hay que escribir la dirección a mano |

### Obtener la llave de Google Places

1. En Google Cloud Console, sobre el proyecto `astro-b97c2`, habilitar
   **Places API**.
2. Crear una llave de API en *Credenciales*.
3. Restringirla a *Places API* y, en Android, a la huella SHA-1 y el
   `applicationId` de la app.
4. Confirmar que el proyecto tiene **facturación activa**: sin ella Places
   responde `REQUEST_DENIED`.

> La build de **web** no puede usar esta llave: `maps.googleapis.com` no envía
> cabeceras CORS para `place/autocomplete/json`, así que la petición la bloquea
> el navegador. La búsqueda de dirección es funcionalidad de móvil/escritorio.

## Comandos

```bash
# Android — release para Play Console
flutter build appbundle --release \
  --dart-define=GOOGLE_MAPS_API_KEY=AIza...

# Android — APK de pruebas
flutter build apk --release \
  --dart-define=GOOGLE_MAPS_API_KEY=AIza...

# Desarrollo
flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza...
```

Para no repetir las claves en cada comando se puede usar un archivo JSON fuera
del control de versiones:

```bash
flutter build appbundle --release --dart-define-from-file=secrets.json
```

```json
{ "GOOGLE_MAPS_API_KEY": "AIza..." }
```

`secrets.json` debe estar en `.gitignore`.

## Impresión térmica

Los detalles de Ticket, Requerimiento, Tarea y Minuta pueden imprimirse en una
impresora térmica ESC/POS, con el formato de 32 columnas del rollo de **58 mm**.

El descubrimiento es por **BLE y USB** (`flutter_thermal_printer`), no por
Bluetooth Classic SPP: no hace falta emparejar la impresora desde los ajustes
del sistema, la app la encuentra por sí misma con el botón «Buscar» de la hoja
de impresión.

Plataformas: **Android, iOS, macOS y Windows**. En web el navegador no puede
hablar con la impresora, así que la implementación real se elige con un import
condicional (`thermal_printer_service.dart`) y queda un stub; el botón de
imprimir no se muestra porque `ThermalPrinterService.isSupported` es `false`.

La última impresora usada se guarda en `SharedPreferences` y aparece primera en
la lista, marcada como «Última». El botón «Prueba» imprime una regla de 32
columnas para comprobar que el rollo puesto coincide con el ancho configurado.

Permisos declarados:

- Android: `BLUETOOTH` / `BLUETOOTH_ADMIN` y `ACCESS_FINE_LOCATION` hasta
  Android 11 (el escaneo BLE exigía ubicación), `BLUETOOTH_SCAN` con
  `neverForLocation` y `BLUETOOTH_CONNECT` desde Android 12.
- iOS: `NSBluetoothAlwaysUsageDescription` y
  `NSBluetoothPeripheralUsageDescription`.

El recibo termina avanzando papel en vez de cortar: el modelo en uso no lleva
cuchilla. Los acentos se transliteran a ASCII porque estas impresoras suelen
ignorar la tabla de códigos y los sustituyen por símbolos sueltos.
