# astro_app

Aplicación Flutter de **ASTRO** (Android, iOS y web). La descripción del sistema,
el stack y el despliegue están en el [README del repositorio](../README.md); el
seguimiento del desarrollo, en [`roadmap.md`](../roadmap.md).

## Arranque

```bash
flutter pub get
flutter run --dart-define-from-file=secrets.json
```

`secrets.json` no se versiona. Las claves que lleva, y por qué la app se degrada
en silencio si faltan, están en [`docs/BUILD.md`](docs/BUILD.md).

## Estructura de `lib/`

| Ruta | Contenido |
|---|---|
| `core/theme/` | `app_colors`, `app_typography`, `app_theme` — temas Dark/Light. |
| `core/widgets/` | Widgets compartidos: `AdaptiveBody`, `AdaptiveCardList`, `AppFilterChip`, `CopyButton`, `FilledIconButton`, animaciones de progreso. |
| `core/services/` | Servicios transversales (impresión térmica, Places, notificaciones). |
| `features/<módulo>/` | Un directorio por módulo funcional, con `data/`, `domain/` y `presentation/`. |
| `routing/` | Rutas de `go_router` y guardias por rol. |

## Compilación

```bash
flutter build web --release --pwa-strategy none        # la build de Railway usa el Dockerfile de la raíz
flutter build appbundle --release --dart-define-from-file=secrets.json
```

El build web del CI corre sobre `ghcr.io/cirruslabs/flutter:3.44.0`, el mismo
minor que el Flutter local: `flutter analyze` no avisa de esa distancia y
`dart2js` se detiene en el primer error, así que conviene mantenerlos alineados.

## Pruebas

```bash
flutter analyze
flutter test
```

> Los tests que renderizan a imagen (`RenderRepaintBoundary.toImage`) tardan
> varios minutos; dales un timeout amplio.
