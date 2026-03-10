# ASTRO — Roadmap de Desarrollo

> Documento de seguimiento del desarrollo del proyecto ASTRO por fases.
> Se actualiza conforme se avanza en la implementación.

---

## Fase 1 — MVP: Sistema Base de Gestión de Proyectos

**Estado:** � En progreso

### 1.1 Setup del Proyecto

- [x] Crear proyecto Flutter desde cero.
- [x] Configurar identificador `com.constelacionr.apps.astro`.
- [x] Conectar con Firebase (proyecto `astro-b97c2`).
- [x] Configurar Firebase Authentication (email + Google Sign-In).
- [x] Configurar Firestore Database.
- [x] Configurar Firebase Storage.
- [x] Configurar Firebase Cloud Messaging (notificaciones push).
- [x] Configurar Firebase Functions.
- [x] Configurar estructura de carpetas del proyecto.
- [x] Configurar plataforma iOS (`flutter create --platforms=ios`, bundle ID, Firebase iOS app registrada).
- [x] Configurar FCM para iOS (AppDelegate con APNs token forwarding, Background Modes, `FirebaseAppDelegateProxyEnabled`).
- [x] Configurar sistema de temas Dark (default) / Light inspirado en Nothing Phone.
- [x] Definir tipografías y paleta de colores.
- [ ] Configurar deploy web en Railway.

### 1.2 Autenticación y Onboarding

- [x] Pantalla de login (email + contraseña).
- [x] Registro con email y contraseña.
- [x] Registro / Login con cuenta de Google.
- [x] Flujo de onboarding para nuevos usuarios (asignación de proyecto y rol posterior).
- [x] Recuperación de contraseña.
- [x] Persistencia de sesión.

### 1.3 Gestión de Usuarios y Roles

- [x] Modelo de datos de Usuario en Firestore (V2 con compatibilidad V1).
- [x] Modelo de datos `projectAssignments` (roles por proyecto).
- [x] Modelos: Empresa, Proyecto (lectura de colecciones existentes).
- [x] Repositorios: UserRepository, ProjectAssignmentRepository, EmpresaRepository, ProyectoRepository.
- [x] Providers Riverpod: usuarios, asignaciones, empresas, proyectos, búsqueda.
- [x] Pantalla de listado de usuarios (Root) con búsqueda y grid adaptativo.
- [x] Pantalla de detalle de usuario con info + asignaciones.
- [x] Pantalla de asignación de proyecto/rol (Empresa → Proyecto → Rol).
- [x] Navegación: ruta `/users`, `/users/:uid`, `/users/:uid/assign`.
- [x] Destino "Usuarios" en el shell de navegación.
- [x] Guardia de acceso: solo Root ve la sección de usuarios.
- [x] Permisos diferenciados por rol en UI.
- [x] Edición inline de datos de usuario (nombre, teléfono).

### 1.4 Gestión de Proyectos

- [x] Modelo de datos de Proyecto en Firestore (V2 con campos adicionales).
- [x] CRUD de proyectos (Root: crear, editar, activar/desactivar).
- [x] Pantalla de listado de proyectos con búsqueda y grid adaptativo.
- [x] Pantalla de detalle de proyecto con info y miembros del equipo.
- [x] Pantalla de creación / edición de proyecto (Root).
- [x] Providers: proyectos filtrados, búsqueda, miembros de proyecto.
- [x] Navegación: `/projects`, `/projects/new`, `/projects/:id`, `/projects/:id/edit`.
- [x] Destino "Proyectos" en el shell de navegación (visible para todos los roles).
- [x] Dashboard principal con resumen de proyectos, tickets abiertos y progreso.
- [x] Asignación de módulos a proyectos (módulos se crean dentro de cada proyecto).
- [x] Asignación de equipos a proyectos (desde el detalle del proyecto, diálogo de agregar miembro con selector de rol).
- [x] Progreso del proyecto calculado desde módulos.
- [x] Botón "Ver módulos" en detalle de proyecto.

### 1.5 Gestión de Módulos

- [x] Modelo de datos de Módulo en Firestore (V2 con compatibilidad V1).
- [x] Repositorio: ModuloRepository con CRUD completo.
- [x] Providers: módulos por proyecto, búsqueda, filtrado, progreso.
- [x] Pantalla de listado de módulos con búsqueda, progreso del proyecto y grid adaptativo.
- [x] Pantalla de detalle de módulo con progreso, info y placeholder de funcionalidades.
- [x] Pantalla de creación / edición de módulo (Root).
- [x] Navegación: `/projects/:id/modules`, `modules/new`, `modules/:moduleId`, `modules/:moduleId/edit`.
- [x] Funcionalidades dentro de cada módulo (sub-colección, checklist con progreso).
- [x] Estado y progreso de módulos (auto-cálculo desde funcionalidades completadas).

### 1.6 Gestión de Incidentes / Tickets

- [x] Modelo de datos de Ticket en Firestore (colección `Incidentes/{docId}` — V1 compat).
- [x] Modelo de TicketComment (colección top-level `Comentarios/{docId}` con `refIncidente`).
- [x] Enums: TicketStatus (Abierto, En Progreso, Resuelto, Cerrado), TicketPriority (Baja, Media, Alta, Crítica).
- [x] Repositorio: TicketRepository con CRUD, comentarios, folio auto-incremental V1 (EMPRESA-PROYECTO-MÓDULO-NUM).
- [x] Providers: tickets por proyecto, por usuario, filtros (estado, prioridad, búsqueda), conteo de abiertos.
- [x] Creación de tickets (todos los roles) con proyecto + módulo obligatorio.
- [x] Pantalla de listado de tickets con búsqueda, chips de estado y prioridad, tarjetas informativas estilo V1.
- [x] Pantalla de detalle de ticket con info, acciones de cambio de estado, asignación a Soporte, hilo de comentarios.
- [x] Pantalla de creación / edición de ticket (título, descripción, módulo, prioridad).
- [x] Historial de cambios / comentarios con tipos (comment, statusChange, assignment, priorityChange).
- [x] Asignación de tickets a usuarios de Soporte (diálogo con miembros Soporte del proyecto).
- [x] Badge de tickets abiertos en botón "Ver tickets" de detalle de proyecto.
- [x] Navegación: `/projects/:id/tickets`, `tickets/new`, `tickets/:ticketId`, `tickets/:ticketId/edit`.
- [x] Visibilidad por rol: Usuario solo ve sus propios tickets; Root/Supervisor/Soporte ven todos.
- [x] Adjuntar evidencias (imágenes, videos, documentos) con Firebase Storage — upload múltiple desde galería, cámara o archivos.
- [x] Porcentaje de avance editable (slider 0-100%, solo Root/Soporte) con indicador de progreso con color.
- [x] Impacto del incidente (selector 1-10, solo Root/Soporte).
- [x] Cobertura del incidente (dropdown: Garantía, Póliza de Soporte, Presupuesto, Cortesía — solo Root/Soporte).
- [x] Fecha de solución programada (date picker, solo Root/Soporte).
- [x] Empresa auto-asignada desde el proyecto.
- [x] Galería de evidencias en detalle de ticket con vista ampliada (tap para zoom interactivo).
- [x] Tarjeta de "Progreso y Gestión" en detalle: avance circular + lineal, impacto, cobertura, solución programada, última actualización.
- [x] `StorageService` para gestión de archivos en Firebase Storage (upload, delete, content-type detection).
- [ ] Notificaciones push al asignar/cambiar estado (Fase 1.8).

### 1.7 Levantamiento de Requerimientos

- [x] Modelo de datos de Requerimiento en Firestore (colección `Requerimientos/{docId}`).
- [x] Enums: RequerimientoStatus (8 estados: Propuesto → En Revisión → Aprobado/Diferido/Rechazado → En Desarrollo → Implementado → Cerrado), RequerimientoTipo (Funcional, No Funcional), RequerimientoFase (Fase Actual, Próxima Fase).
- [x] Modelo con CriterioAceptacion (texto + checkbox completado), Participante (uid, nombre, rol).
- [x] Porcentaje de avance auto-calculado desde criterios de aceptación, con override manual por Root/Soporte.
- [x] Modelo de RequerimientoComment (colección separada `ComentariosRequerimientos/{docId}`).
- [x] Repositorio: RequerimientoRepository con CRUD, folio auto-incremental V1, comentarios, criterios, adjuntos, asignación.
- [x] Providers: requerimientos por proyecto, filtros (estado, tipo, búsqueda), conteo de pendientes, visibilidad por rol.
- [x] Creación y edición de requerimientos con asociación a proyecto y módulo (existente o propuesto).
- [x] Pantalla de listado con búsqueda, chips de estado y tipo, tarjetas informativas con progreso circular.
- [x] Pantalla de detalle con info, criterios de aceptación (checklist interactivo), participantes, adjuntos, observaciones internas (solo Root/Soporte), motivo de rechazo, acciones de cambio de estado, hilo de comentarios.
- [x] Pantalla de creación / edición con criterios dinámicos, adjuntos (galería + archivos), gestión manual de porcentaje y fase.
- [x] Root como gatekeeper: aprueba, rechaza, difiere. Soporte avanza estado operativo.
- [x] ObservacionesRoot visibles solo para Root y Soporte.
- [x] Badge de requerimientos pendientes en botón "Ver requerimientos" de detalle de proyecto.
- [x] Navegación: `/projects/:id/requirements`, `requirements/new`, `requirements/:reqId`, `requirements/:reqId/edit`.
- [x] `StorageService.uploadToPath` — método genérico para subir adjuntos a rutas arbitrarias en Firebase Storage.
- [x] Visibilidad por rol: Usuario solo ve sus propios requerimientos; Root/Supervisor/Soporte ven todos.
- [x] Vinculación bidireccional con minutas (modelo ya tenía `refMinutas`/`refCitas`).

### 1.8 Notificaciones Push

- [x] Configuración de Firebase Cloud Messaging (`firebase_messaging` ya en pubspec).
- [x] `NotificationService` — solicitar permiso, obtener/refrescar FCM token, guardar en Firestore (`users/{uid}.fcmTokens`).
- [x] Handler de mensajes en background (`firebaseMessagingBackgroundHandler` top-level).
- [x] `FcmInitializer` — widget wrapper que inicializa FCM al login y limpia token al logout.
- [x] `main.dart` actualizado — `FirebaseMessaging.onBackgroundMessage` + `FcmInitializer` envolviendo `MaterialApp`.
- [x] `AndroidManifest.xml` — ícono y canal de notificación por defecto (`astro_default`).
- [x] Campo `fcmTokens` (array) añadido al modelo `AppUser` (Firestore `users/{uid}`).
- [x] Modelo `NotificationType` — 10 tipos de notificación (5 tickets + 5 requerimientos).
- [x] Modelo `InAppNotification` — bandeja in-app (`Notificaciones/{docId}`).
- [x] Modelo `NotificationConfig` — configuración por usuario/proyecto (`NotificationConfig/{projectId_userId}`).
- [x] Enum `NotificationScope` — `participante`, `proyecto`, `todos` con defaults por rol.
- [x] `NotificationConfigRepository` — CRUD de configuraciones, watch por proyecto.
- [x] `NotificationRepository` — bandeja in-app: watch, markAsRead, markAllAsRead, delete.
- [x] Providers: `inboxNotificationsProvider`, `unreadNotificationsProvider`, `unreadCountProvider`, `projectNotifConfigsProvider`, `userNotifConfigProvider`.
- [x] Pantalla **Bandeja de Notificaciones** — historial in-app con iconos por tipo, marca leído/no leído, tiempo relativo, navegación a ticket/req, eliminar con long-press.
- [x] Pantalla **Notificaciones del Proyecto** (Root) — gestión granular por usuario: master toggle, recibir tickets on/off, recibir reqs on/off, selector de alcance (`SegmentedButton`), indicador de override vs defaults, restaurar defaults.
- [x] Destino "Notificaciones" en shell de navegación con badge de no leídas (todos los roles).
- [x] Botón "Configurar notificaciones" en detalle de proyecto (solo Root).
- [x] Navegación: `/notifications` (inbox), `/projects/:id/notification-settings` (Root config).
- [x] Reglas de notificación por defecto según rol: Usuario=participante, Supervisor=proyecto, Soporte=proyecto, Root=todos.
- [x] Cloud Functions v2 (TypeScript) — `functions/src/index.ts`:
  - [x] `onTicketCreated` — notifica al crear ticket.
  - [x] `onTicketUpdated` — notifica cambio de status, asignación, prioridad.
  - [x] `onTicketCommentCreated` — notifica comentarios (no system entries).
  - [x] `onReqCreated` — notifica al crear requerimiento.
  - [x] `onReqUpdated` — notifica cambio de status, asignación, fase.
  - [x] `onReqCommentCreated` — notifica comentarios de requerimiento.
  - [x] Limpieza automática de FCM tokens inválidos.
  - [x] Escritura dual: push FCM + entrada in-app (Notificaciones).
  - [x] Respeta `NotificationConfig` overrides por usuario/proyecto.
- [x] Índices Firestore para `Notificaciones` (userId+createdAt, userId+leida+createdAt).
- [x] Índices Firestore completos desplegados (37 índices: Notificaciones, Tickets, projectAssignments, Modulos, Requerimientos, ComentariosRequerimientos, users, Proyectos, NotificacionesGral, chatAI, chats, etc.).
- [x] `firebase.json` y `.firebaserc` en raíz del repo para deploy de functions.
- [x] Botón back en pantalla de Notificaciones del Proyecto (soporte iOS/tablet sin botón hardware).
- [x] Buscador de miembros en pantalla de Notificaciones del Proyecto (filtro por nombre, email, rol).
- [x] Deploy de Cloud Functions a Firebase (`firebase deploy --only functions`) — 6 triggers v2 en us-central1.
- [x] Configurar VAPID key para notificaciones push web — service worker `firebase-messaging-sw.js`, constante `fcmVapidKey` en `fcm_config.dart` (pendiente: pegar key real de Firebase Console).

### 1.9 Documentación del Proyecto

- [x] Diseño de esquema Firestore: 3 colecciones (`DocumentosProyecto`, `BitacoraDocumentos`, `CategoriasDocumento`).
- [x] Modelo `DocumentoProyecto` — documento formal con versionado, folio auto-incremental (EMP-PRJ-DOC-NUM), metadata completa.
- [x] Modelo `DocumentoVersion` — historial de versiones con url, nombre, tamaño, notas, usuario que subió.
- [x] Modelo `BitacoraDocumento` — registro de auditoría con 5 acciones (creado, editado, nuevaVersion, eliminado, restaurado).
- [x] Modelo `CategoriaCustom` — categorías personalizadas por proyecto (Root).
- [x] Modelo `AdjuntoCompartido` — modelo virtual para agregación de adjuntos de tickets/requerimientos (no almacenado en Firestore).
- [x] Enums: `DocumentoSeccion` (formal/compartido), `DocumentoCategoria` (7 categorías default), `BitacoraAccion`.
- [x] `DocumentoRepository` — CRUD de documentos, versionado, bitácora automática, categorías custom, folio auto-incremental.
- [x] Providers Riverpod: documentos por proyecto, por ID, bitácora por proyecto/documento, categorías (default + custom mergeadas), búsqueda, filtro por categoría, adjuntos compartidos agregados, conteo de formales, permisos por rol.
- [x] Pantalla **Listado de Documentos** — 2 tabs (Formales / Compartidos), búsqueda, chips de filtro por categoría, tarjetas con folio, versión, categoría, autor.
- [x] Pantalla **Detalle de Documento** — header con folio, info card, archivo actual con botón abrir, historial de versiones (timeline), sección de bitácora, acciones de edición/eliminación con confirmación.
- [x] Pantalla **Formulario de Documento** — crear/editar con título, categoría (dropdown defaults + custom), descripción, file picker, notas de versión en edición, upload a Storage (`documentacion/{projectId}/formales/`).
- [x] Pantalla **Bitácora** — log de auditoría del proyecto con íconos/colores por acción, usuario, rol, timestamp, folio del documento.
- [x] Pantalla **Categorías** — sección de categorías default (bloqueadas) + categorías custom con agregar/eliminar (solo Root).
- [x] Tab "Compartidos" — agregación en tiempo real de adjuntos de tickets (`evidenciasIncidente`) y requerimientos (`adjuntos`) como documentación automática.
  - [x] Modelo `AdjuntoCompartido` enriquecido: autor, módulo, status, prioridad, fecha de creación, `displayName` limpio (sin ruta Firebase Storage).
  - [x] Providers de filtrado: por origen (Ticket/Requerimiento), por tipo de archivo (imagen, pdf, video, word, excel).
  - [x] Provider de ordenamiento: más recientes, más antiguos, nombre A–Z, folio.
  - [x] UI rediseñada: tarjetas ricas con nombre limpio, fecha, badge de origen, folio + título, metadatos (autor, módulo, status, prioridad), chips de filtro y menú de orden.
- [x] Navegación: `/projects/:id/documents`, `documents/new`, `documents/:docId`, `documents/:docId/edit`, `documents/log`, `documents/categories`.
- [x] Botón "Ver documentación" en detalle de proyecto con badge de conteo de documentos formales.
- [x] Permisos por rol: Root/Soporte gestionan documentos; Supervisor solo consulta; Usuario no accede a formales.
- [x] Versionado formal: cada actualización de archivo crea nueva versión con historial completo.
- [x] Bitácora automática: toda acción sobre documentos formales queda registrada (quién, qué, cuándo).
- [x] `StorageService.contentType` — método hecho público para detección de tipo de archivo desde formulario de documentos.
- [x] Dependencias añadidas: `url_launcher: ^6.3.1`, `intl: ^0.20.2`.
- [x] **Visor Universal de Archivos** (`FileViewerScreen`) — pantalla full-screen reutilizable en todos los módulos:
  - [x] **Imágenes** (jpg, png, gif, webp): `InteractiveViewer` con pinch-to-zoom.
  - [x] **Videos** (mp4, mov): reproductor nativo con `video_player`, controles de play/pause/seek.
  - [x] **PDFs**: visor scrollable con zoom usando `pdfx`.
  - [x] **Otros formatos**: ícono + nombre + botones de descargar / abrir externo (`url_launcher`).
  - [x] **Descarga directa**: imágenes/videos a galería (álbum ASTRO) con `gal`, otros a carpeta de descargas con `dio`.
  - [x] `DownloadService` — servicio de descarga con detección de categoría de archivo y guardado según tipo.
  - [x] Integrado en **Tickets** (evidencias — reemplaza el diálogo inline anterior).
  - [x] Integrado en **Requerimientos** (adjuntos — implementa el TODO pendiente).
  - [x] Integrado en **Documentación** (documentos formales, historial de versiones, adjuntos compartidos).
  - [x] Dependencias añadidas: `video_player`, `pdfx`, `dio`, `path_provider`, `gal`, `http`.
  - [x] `AndroidManifest.xml` — queries para `url_launcher` en Android 11+ (ACTION_VIEW para http/https).

### 1.10 Interfaces Adaptativas

- [x] Layouts adaptativos: móvil, tablet/fold, web/desktop.
  - `AdaptiveBody` widget: max-width constraint (720px forms, 960px lists) en pantallas anchas.
  - `adaptiveGridColumns()` helper centralizado (1/2/3 columnas según breakpoint).
  - Formularios (5): ticket, project, requerimiento, documento, module — envueltos con AdaptiveBody.
  - Listas: ticket, requerimiento, documento (2 tabs), bitácora — envueltas con AdaptiveBody(960).
  - Grids: dashboard, project list, user list — usan adaptiveGridColumns().
  - Module list ya usaba maxCrossAxisExtent auto-adaptativo.
- [x] Navegación responsiva (bottom nav en móvil, sidebar en tablet/web).
  - AppShell: NavigationBar (< compact) / NavigationRail (≥ compact) / extended rail (≥ medium).
- [x] Componentes optimizados para touch y mouse/teclado.
  - Tooltips agregados a: FAB, botones send (chat), calendar picker, clear, remove, delete, play/pause.
  - AppBar actions ya tenían tooltips.
- [x] Breakpoints definidos y consistentes.
  - AppBreakpoints: compact=600, medium=840, expanded=1200, large=1600.
- [x] Refinamiento visual Nothing X: rojo solo para atención/crítico, paleta neutra blanca/gris.
  - Theme: NavigationBar/Rail indicadores blancos, ElevatedButton/FilledButton gris.
  - Folios, badges, avatares decorativos → onSurface neutral.
  - progressColor(): rojo <25%, interpolación amber 25-49%, verde 50-100%.
- [ ] Testing visual en múltiples tamaños de pantalla.

### 1.11 Testing y QA

- [ ] Tests unitarios de modelos y lógica de negocio.
- [ ] Tests de widgets de componentes clave.
- [ ] Tests de integración de flujos principales.

### 1.12 Publicación

- [ ] Build de release para Android.
- [ ] Actualización en Google Play (Closed Testing).
- [ ] Deploy web en Railway.
- [ ] Optimización ASO (App Store Optimization).

### 1.13 Gestión de Cuenta y Perfil

- [x] **Avatar de usuario** en el AppBar del Dashboard — ícono/foto que abre la pantalla de perfil.
- [x] Foto de perfil: se carga automáticamente desde Google al registrarse; si no viene de Google, se permite definirla manualmente. Siempre editable.
- [x] Pantalla **Perfil / Mi Cuenta** (`/profile`) con las siguientes secciones:
  - [x] **Ver perfil**: nombre, email, foto, rol actual.
  - [x] **Editar nombre y foto de perfil**: cambiar displayName y subir/cambiar foto (Firebase Storage).
  - [x] **Cambiar contraseña**: formulario de cambio de contraseña (solo usuarios con email/password, no Google).
  - [x] **Tema (Dark / Light)**: SegmentedButton para cambiar el tema de la app. Persistido en SharedPreferences.
  - [ ] **Configurar notificaciones generales**: activar/desactivar push, ajustes globales de notificaciones.
  - [x] **Información de la app**: versión, build, paquete, descripción y © Constelación R.
  - [x] **Cerrar sesión**: botón de logout con confirmación.

---

## Fase 2 — Funcionalidades Avanzadas

**Estado:** � En progreso

### 2.1 Citas y Videoconferencias

- [x] Modelo de datos `Cita` en Firestore (colección `Citas/{docId}`).
- [x] Sub-modelo `ParticipanteCita` (uid, nombre, rol, confirmado).
- [x] Enum `CitaStatus` (programada, enCurso, completada, cancelada).
- [x] `CitaRepository` — CRUD, folio auto-incremental (CITA-EMP-PRJ-NUM), updateStatus, deactivate/activate.
- [x] Providers: citas por proyecto, por ID, búsqueda, filtro por status, conteo de programadas.
- [x] Pantalla **Listado de Citas** — búsqueda, chips de filtro por status (colorizados), tarjetas con folio, status badge, título, fecha/hora, modalidad, participantes.
- [x] Pantalla **Detalle de Cita** — layout adaptativo (info + acciones), header con status, info card, descripción, participantes con confirmación, recordatorios como chips, notas, botones de cambio de estado.
- [x] Pantalla **Formulario de Cita** — crear/editar con título, descripción, fecha, horarios, modalidad (videoconferencia/presencial/llamada/híbrida), URL (Zoom/Teams/Meet), dirección física, participantes con diálogo, recordatorios selector (15min/30min/1h/2h/24h), notas.
- [x] Navegación: `/projects/:id/citas`, `citas/new`, `citas/:citaId`, `citas/:citaId/edit`.
- [x] Botón "Ver citas" en detalle de proyecto con badge de citas programadas.
- [x] Campo `participantUids` (List<String>) — UIDs desnormalizados de participantes + createdBy para consultas `array-contains` cross-proyecto.
- [x] `CitaRepository.watchByParticipantUid` — stream de citas por UID del usuario (cross-proyecto).
- [x] Providers globales: `myCitasProvider`, `upcomingCitasProvider`, `upcomingCitasCountProvider`.
- [x] **Calendario global** — pantalla `/calendar` en navegación principal, toggle entre vista mensual (TableCalendar) y agenda (secciones: Vencidas, Hoy, Mañana, Esta Semana, Próximamente, Pasadas).
- [x] Badge de citas próximas en ícono de Calendario en la navegación.
- [x] **Dashboard: indicador de citas** — StatCard "Próximas citas" + sección con hasta 3 citas próximas con enlace.
- [x] **Cloud Function `checkCitaReminders`** — cada 15 min revisa citas programadas y envía push + notificación in-app según `recordatorios` (ventana ±7.5 min).
- [ ] Integración con **Google Calendar** para programar eventos (Fase posterior).
- [ ] Generación automática de URL de videoconferencia (Fase posterior).

### 2.2 Módulo de Minutas

- [x] Modelo de datos `Minuta` en Firestore (colección `Minutas/{docId}`).
- [x] Sub-modelos: `AsistenteMinuta` (uid, nombre, puesto, asistencia, firmaMotivo), `AsuntoTratado` (numero, texto, subitems), `CompromisoMinuta` (numero, tarea, responsable, fechaEntrega, status).
- [x] Enum `CompromisoStatus` (pendiente, cumplido, vencido), `MinutaModalidad` (videoconferencia, presencial, llamada, híbrida).
- [x] Campo `participantUids` (List<String>) — UIDs desnormalizados para consultas `array-contains` de visibilidad por rol.
- [x] Campos `adjuntos` (List<String>), `refTickets` (List<String>), `refRequerimientos` (List<String>) en modelo Minuta.
- [x] Campo `sistema` eliminado del modelo (no aplica al contexto de minutas).
- [x] `MinutaRepository` — CRUD, folio auto-incremental (MIN-EMP-PRJ-NUM), deactivate/activate, `watchByParticipant` (array-contains en participantUids).
- [x] Providers: minutas por proyecto, por participante, visibilidad por rol (`visibleMinutasProvider`), permisos de creación (`canCreateMinutaProvider`), búsqueda, conteo.
- [x] **Visibilidad por rol**: Root/Supervisor/Soporte ven todas las minutas del proyecto; Usuario solo ve minutas donde participa como asistente o responsable de compromiso.
- [x] **Permisos de creación**: Solo Root y Soporte pueden crear minutas.
- [x] Pantalla **Listado de Minutas** — búsqueda, contador, tarjetas con folio, fecha, objetivo, modalidad, badges de compromisos (vencidos/pendientes), asistentes. FAB condicional según permisos.
- [x] Pantalla **Detalle de Minuta** — layout adaptativo (info izq + compromisos der), header con folio, info card (versión, fecha, hora, modalidad, lugar, empresa), objetivo, asistentes con asistencia, asuntos tratados numerados con sub-ítems, compromisos con toggle pendiente↔cumplido, observaciones, resumen IA, secciones de adjuntos / tickets vinculados / requerimientos vinculados.
- [x] **Generación de PDF** — `MinutaPdfService.generate(Minuta)` crea PDF profesional multi-página (header, info, asistentes, asuntos, compromisos con colores de status, observaciones, paginación).
- [x] **Imprimir PDF** — botón en detalle de minuta, usa `Printing.layoutPdf` del paquete `printing`.
- [x] **Compartir PDF** — botón en detalle de minuta, usa `Printing.sharePdf`.
- [x] Pantalla **Formulario de Minuta** — crear/editar con versión, objetivo, fecha, horarios, modalidad condicional:
  - [x] **Videoconferencia**: solo URL de videoconferencia.
  - [x] **Presencial**: dirección con autocompletado Google Places + lugar (referencia textual).
  - [x] **Llamada**: sin campos adicionales de ubicación.
  - [x] **Híbrida**: URL + dirección con autocompletado + lugar.
- [x] **Google Maps Places Autocomplete** — `PlacesService` con API HTTP de Google Places para autocompletado de direcciones en modalidad presencial/híbrida.
- [x] **Asistentes desde proyecto** — diálogo multi-select `_ProjectMembersDialog` que muestra miembros del proyecto con nombre y rol.
- [x] **Asistentes externos** — diálogo manual para agregar personas no registradas en el proyecto (sin UID).
- [x] **Adjuntos** — upload de archivos (FilePicker) e imágenes (ImagePicker) a Firebase Storage (`minutas/{projectId}/`). Se muestran en formulario y detalle.
- [x] **Tickets vinculados** — búsqueda de tickets existentes del proyecto + diálogo de creación rápida de ticket (título, descripción, módulo 'General').
- [x] **Requerimientos vinculados** — búsqueda de requerimientos existentes del proyecto + diálogo de creación rápida de requerimiento (título, descripción).
- [x] Navegación: `/projects/:id/minutas`, `minutas/new`, `minutas/:minutaId`, `minutas/:minutaId/edit`.
- [x] Botón "Ver minutas" en detalle de proyecto con badge de conteo.
- [x] Dependencias añadidas: `pdf: ^3.11.3`, `printing: ^5.14.2`, `share_plus: ^12.0.1`.
- [ ] **Resumen de minuta generado por IA** (Firebase AI Logic / Gemini — Fase posterior).

### 2.3 Vinculación Tickets ↔ Minutas ↔ Requerimientos

- [x] Campos `refMinutas` y `refCitas` añadidos al modelo `Ticket` (constructor, fromFirestore, toFirestore, copyWith).
- [x] Campos `refTickets` y `refRequerimientos` añadidos al modelo `Minuta` (vinculación bidireccional).
- [x] UI de búsqueda y vinculación de tickets desde formulario de minuta (picker con búsqueda).
- [x] UI de búsqueda y vinculación de requerimientos desde formulario de minuta (picker con búsqueda).
- [x] Creación de tickets desde formulario de minuta — navega al formulario completo con `returnId`, regresa con referencia vinculada.
- [x] Creación de requerimientos desde formulario de minuta — navega al formulario completo con `returnId`, regresa con referencia vinculada.
- [x] Visualización de tickets y requerimientos vinculados en detalle de minuta.
- [x] UI de selección/vinculación de minutas desde formulario de ticket (picker con búsqueda por folio/objetivo).
- [x] Visualización de minutas vinculadas en detalle de ticket.
- [x] UI de selección/vinculación de minutas desde formulario de requerimiento (picker con búsqueda por folio/objetivo).
- [x] Visualización de minutas vinculadas en detalle de requerimiento.
- [x] Sincronización bidireccional: al vincular minuta↔ticket o minuta↔requerimiento se actualizan ambos documentos (`FieldValue.arrayUnion`).
- [x] Métodos de repositorio: `TicketRepository.addRefMinuta/removeRefMinuta`, `MinutaRepository.addRefTicket/addRefRequerimiento`, `RequerimientoRepository.addRefMinuta`.
- [x] Router actualizado: rutas de ticket/new y requirements/new aceptan `extra: {'returnId': true}` para flujo de creación y retorno.
- [ ] UI de selección/vinculación de citas desde ticket (picker en formulario de ticket).
- [ ] Navegación cruzada entre tickets y minutas/citas vinculadas (tap para ir al detalle).

### 2.5 Auto-generación de PDF de Minuta como Documento Formal

- [x] Categoría `minuta` añadida a `DocumentoCategoria` enum.
- [x] `StorageService.uploadBytes` — método para subir bytes crudos (PDF) a Firebase Storage.
- [x] Al guardar minuta (crear o editar), se genera automáticamente el PDF, se sube a Storage y se crea un `DocumentoProyecto` formal con categoría "Minuta" y sección "Formal".
- [x] Generación best-effort: si falla el PDF no se bloquea el guardado de la minuta.

### 2.6 Módulo de Agente de IA

- [ ] Agente conversacional para consultar avances del proyecto asignado.
- [ ] Consultas sobre: minutas, tickets, incidentes, avances y todo lo relacionado.
- [ ] Disponible solo para roles: **Root**, **Supervisor** y **Soporte**.
- [ ] Integración con Firebase AI Logic (Gemini).

---

## Leyenda de Estados

| Símbolo | Significado        |
| ------- | ------------------ |
| 🔲      | Por iniciar        |
| 🔶      | En progreso        |
| ✅      | Completado         |
| ⏸️      | Pausado            |
| ❌      | Cancelado/Descartado |

---

*Última actualización: 10 de marzo de 2026 — Sección 1.13 Gestión de Cuenta y Perfil implementada: avatar en Dashboard, pantalla de perfil (/profile), editar nombre/foto, cambiar contraseña, tema Dark/Light persistido con SharedPreferences, info de la app (package_info_plus), cerrar sesión con confirmación. AuthRepository ampliado con updateAuthProfile, reauthenticate, updatePassword, isPasswordUser.*
