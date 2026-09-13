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
