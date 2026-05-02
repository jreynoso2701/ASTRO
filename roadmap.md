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
- [x] Configurar Firebase Authentication (email + contraseña — único método).
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
- [x] ~~Registro / Login con cuenta de Google.~~ Removido — solo email/contraseña.
- [x] Flujo de onboarding para nuevos usuarios (asignación de proyecto y rol posterior).
- [x] Recuperación de contraseña.
- [x] Persistencia de sesión.
- [x] ~~Sign in with Apple.~~ Removido — solo email/contraseña.
- [x] Eliminación de cuenta con **anonimización de datos** (Cloud Function `anonymizeAndDeleteUser` — reemplaza referencias con "Usuario eliminado - [nombre]", conserva archivos del proyecto, elimina datos personales, notificaciones y configuraciones).
- [x] **Flujo de Aprobación de Registro:**
  - [x] Enum `RegistrationStatus` (pending/approved/rejected).
  - [x] Campos en `AppUser`: `registrationStatus`, `rejectionReason`, `approvedBy`, `approvedAt`, `rejectedAt`.
  - [x] Nuevo registro crea usuario con status `pending` (Cloud Function + cliente).
  - [x] Pantalla de espera (`PendingApprovalScreen`) — muestra pasos, opción de eliminar cuenta, contactar soporte después de 24h.
  - [x] Pantalla de rechazo (`RejectionScreen`) — muestra motivo, contactar soporte, eliminar cuenta.
  - [x] Pantalla de gestión de solicitudes (`RegistrationRequestsScreen`) — lista pendientes con tiempo de espera, aprobar con asignación de proyecto/rol, rechazar con justificación.
  - [x] Tile "Solicitudes" en Gestión con badge de conteo (solo Root).
  - [x] Guards en router: pending→PendingApproval, rejected→Rejection.
  - [x] Cloud Function `onUserStatusChanged` — notifica al usuario aprobado/rechazado + otros Root.
  - [x] Cloud Function `checkPendingRegistrations` — recordatorio diario a Root si hay solicitudes >24h.
  - [x] Cloud Function `onNewUserCreated` actualizada — establece `registrationStatus: pending`, notifica Root sobre nueva solicitud.

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
- [x] **Nuevo rol "Lider Proyecto"** — rol híbrido entre Root, Supervisor y Soporte para liderar proyectos asignados.
  - [x] Enum `UserRole.liderProyecto` con label "Lider Proyecto".
  - [x] Permisos: gestionar tickets, requerimientos, documentación y módulos de proyectos asignados. Archivar/descartar requerimientos. Asignar Soporte a tickets.
  - [x] Restricciones: NO puede gestionar Proyectos, Empresas, Usuarios, Solicitudes de registro. NO tiene acceso a Agente IA ni Avisos.
  - [x] Scope de notificaciones por defecto: `proyecto`.
  - [x] Color de badge en UI: Púrpura (#9C27B0).
  - [x] Disponible en todos los dropdowns de asignación de rol (assign, approval, edit role, add member).
  - [x] Cloud Functions actualizadas: notificaciones de fecha compromiso, progreso de módulos, deadlines de tickets/reqs/tareas, tickets sin fecha.
  - [x] Visibilidad: ve todos los tickets, requerimientos, minutas y documentación del proyecto (no limitado como Usuario).

### 1.4 Gestión de Proyectos

- [x] Modelo de datos de Proyecto en Firestore (V2 con campos adicionales).
- [x] CRUD de proyectos (Root: crear, editar, activar/desactivar).
- [x] Pantalla de listado de proyectos con búsqueda y grid adaptativo.
- [x] Pantalla de detalle de proyecto con info y miembros del equipo.
- [x] Pantalla de creación / edición de proyecto (Root).
- [x] Providers: proyectos filtrados, búsqueda, miembros de proyecto.
- [x] Navegación: `/projects`, `/projects/new`, `/projects/:id`, `/projects/:id/edit`.
- [x] Destino "Proyectos" en el shell de navegación (visible para todos los roles).
- [x] Dashboard principal con resumen de proyectos, progreso y citas.
- [x] **Dashboard: Resumen de Incidentes** — 6 cards de conteo por estado (Pendiente, En Desarrollo, Pruebas Internas, Pruebas Cliente, Bugs, Resuelto) con íconos y colores + gráfico donut de distribución (`CustomPainter`). Conteo global sumando todos los proyectos del usuario. Layout adaptativo: 2 columnas + donut abajo en móvil, 3 columnas + donut lateral en tablet/web.
- [x] **Dashboard: Sección tabulada Tickets / Requerimientos** — `_IncidentsTabbedSection` con `TabBar` para alternar entre vista de Tickets y Requerimientos.
  - [x] **Tab Requerimientos — Status Overview** (`_ReqStatusOverview`): 6 cards por estado (Propuesto, En Revisión, En Desarrollo, Implementado, Completado, Descartado) con `_ReqStatusCard` + gráfico donut (`_ReqDonutChart`, `_ReqDonutChartPainter`). Layout adaptativo: 2 col + donut abajo en móvil, 3 col + donut lateral en pantallas anchas.
  - [x] **Tab Requerimientos — Semáforo de Deadlines** (`_ReqDeadlineOverview`): cards tipo semáforo (🔴 Vencido, 🟠 Hoy/Mañana, 🟡 2-5 días, ⚪ Sin Fecha) usando `_GenericDeadlineCard`. Solo visible para Root.
  - [x] **Bottom sheets de requerimientos**: `_showReqsByStatusSheet`, `_showReqsByDeadlineSheet`, `_showReqsWithoutDeadlineSheet` — listas agrupadas por proyecto con navegación al detalle.
  - [x] **Providers globales de requerimientos para dashboard**: `globalReqCountsByStatusProvider`, `globalReqsByStatusProvider`, `globalReqsByDeadlineProvider`, `globalReqsWithoutDeadlineProvider`, `allRequerimientosByProjectProvider`.
  - [x] **`reqStatusColor()`** — función centralizada en `ticket_colors.dart` para mapeo de colores por `RequerimientoStatus`.
- [x] **Dashboard: Ordenamiento de proyectos** — `ProjectSortOption` enum (nombre ↑↓, progreso ↑↓), `projectSortProvider`, botón `_ProjectSortButton` en header "MIS PROYECTOS" (visible cuando hay >1 proyecto).
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
- [x] Enums: TicketStatus (Pendiente, En Desarrollo, Pruebas Internas, Pruebas Cliente, Bugs, Resuelto, Archivado), TicketPriority (Baja, Media, Alta, Crítica).
- [x] Repositorio: TicketRepository con CRUD, comentarios, folio auto-incremental V1 (EMPRESA-PROYECTO-MÓDULO-NUM).
- [x] Providers: tickets por proyecto, por usuario, filtros (estado, prioridad, búsqueda), conteo de activos (excluye Resuelto/Archivado).
- [x] Creación de tickets (todos los roles) con proyecto + módulo obligatorio.
- [x] Pantalla de listado de tickets con búsqueda, chips de estado y prioridad, tarjetas informativas estilo V1.
- [x] Vista Kanban (tablero de 6 columnas por estado, sin Archivado) con drag & drop — toggle lista/kanban en AppBar, responsive (lista en móvil, kanban en pantallas anchas ≥840px).
- [x] Pantalla de detalle de ticket con info, acciones de cambio de estado (Archivado solo Root), asignación a Soporte, hilo de comentarios.
- [x] Pantalla de creación / edición de ticket (título, descripción, módulo, prioridad).
- [x] Historial de cambios / comentarios con tipos (comment, statusChange, assignment, priorityChange).
- [x] Asignación de tickets a usuarios de Soporte (diálogo con miembros Soporte del proyecto).
- [x] Badge de tickets abiertos en botón "Ver tickets" de detalle de proyecto.
- [x] Navegación: `/projects/:id/tickets`, `tickets/new`, `tickets/:ticketId`, `tickets/:ticketId/edit`.
- [x] Visibilidad por rol: Usuario solo ve sus propios tickets; Root/Supervisor/Soporte ven todos.
- [x] **Kanban enriquecido**: tarjetas con folio, badge de prioridad, título, módulo, reportó, soporte, fecha, barra de progreso con porcentaje.
- [x] **Archivado masivo desde Kanban** — botón "Archivar todos" en la columna Resuelto del tablero Kanban. Solo Root/Soporte. Diálogo de confirmación con conteo. Archiva todos los tickets resueltos en lote.
- [x] **Ordenamiento Kanban**: barra global de FilterChips con 7 criterios (reciente, antiguo, prioridad ↑↓, reportó, soporte, % avance) aplicados a todas las columnas.
- [x] **Bugfix — Kanban drag & drop desde Bugs**: el filtro de estado persistía al cambiar de vista lista → kanban, causando que tickets desaparecieran al ser movidos. Fix: `filteredTicketsProvider` ahora acepta `skipStatusFilter` (true en kanban). UX: menú contextual de cambio de estado (clic derecho web, botón "Mover a…" en tarjeta).
- [x] **Gestión de archivados (Root + Soporte)**: botón en AppBar → bottom sheet con búsqueda por folio/título/descripción/nombre, filtros de prioridad, listado de tickets archivados con detalle y acción rápida de desarchivar.
- [x] **Archivado con justificación**: Root y Soporte pueden archivar desde el detalle del ticket con justificación obligatoria (mín. 10 chars). Campos `archiveReason` y `archivedByName` en modelo. Razón visible en detalle y en bottom sheet de archivados.
- [x] **Indicadores en tarjetas**: ícono de adjuntos (clip + cantidad) cuando el ticket tiene evidencias, ícono de comentarios (burbuja + cantidad) con contador desnormalizado `commentCount`. Visible en vista lista (móvil) y Kanban (tablet/web/fold).
- [x] **Auto-progreso por estado**: al cambiar a Resuelto se fija `porcentajeAvance` a 100%, al cambiar a Pendiente se fija a 0%. Aplica también al drag & drop en Kanban.
- [x] **Bitácora de movimientos**: todos los cambios de estado (incluido drag & drop en Kanban), asignaciones y cambios de prioridad quedan registrados como entradas de historial. Sección dedicada "BITÁCORA" en detalle de ticket con timeline visual (ícono por tipo, color, autor, fecha, descripción), expandible (5 recientes, ver todos).
- [x] Adjuntar evidencias (imágenes, videos, documentos) con Firebase Storage — upload múltiple desde galería, cámara o archivos.
- [x] Porcentaje de avance editable (slider 0-100%, solo Root/Soporte) con indicador de progreso con color.
- [x] Impacto del incidente (selector 1-10, solo Root/Soporte).
- [x] Cobertura del incidente (dropdown: Garantía, Póliza de Soporte, Presupuesto, Cortesía — solo Root/Soporte).
- [x] Fecha de solución programada (date picker, solo Root/Soporte).
- [x] Empresa auto-asignada desde el proyecto.
- [x] Galería de evidencias en detalle de ticket con vista ampliada (tap para zoom interactivo).
- [x] Tarjeta de "Progreso y Gestión" en detalle: avance circular + lineal, impacto, cobertura, solución programada, última actualización.
- [x] `StorageService` para gestión de archivos en Firebase Storage (upload, delete, content-type detection).
- [x] **Sistema de penalización por impacto de tickets en progreso de módulo/proyecto**:
  - [x] Fórmula combinada: `penalización = prioridad.penaltyWeight × (impacto/10) × (1 - avance/100)`.
  - [x] `penaltyWeight` en `TicketPriority` (Baja=1.0, Media=3.0, Alta=5.0, Crítica=8.0).
  - [x] `modulePenaltyProvider` y `modulePenaltyDetailsProvider` — cálculo y desglose de penalización por módulo.
  - [x] `adjustedModuleProgressProvider` — progreso de módulo menos penalización, piso en 0.
  - [x] `projectProgressProvider` actualizado a usar progreso ajustado; `projectBaseProgressProvider` para comparar.
  - [x] `ImpactLevel` enum (Bajo 1-3, Medio 4-6, Alto 7-9, Crítico 10) con filtro en listado y Kanban.
  - [x] `_ImpactIndicator` en detalle del ticket: barra de color, nivel, penalización calculada.
  - [x] Impacto visible en tarjetas de lista y Kanban con color por nivel.
  - [x] Criterio de ordenamiento "Impacto" en Kanban.
  - [x] Dashboard: stat card "Progreso general" muestra base vs ajustado cuando hay penalización.
  - [x] Dashboard: `_ProjectCard` con indicador naranja de penalización por tickets.
  - [x] Migración Cloud Function: 78 tickets Resuelto actualizados de 0% a 100%.
  - [x] Auto-progreso: Resuelto → 100%, Pendiente → 0% (aplica en cambio de status y drag & drop Kanban).
- [x] **Estadísticas de tickets** — botón en AppBar (solo Root/Soporte) que abre bottom sheet con rankings: módulos con más incidentes y usuarios que más reportan. Incluye **todos** los tickets (activos + archivados + desactivados). Barras visuales proporcionales con conteo. Provider `allTicketsByProjectProvider` sin filtro `isActive`.
- [x] **Filtrado por etiquetas en listado y Kanban de tickets** — `TicketEtiquetaFilterNotifier` (Set<String>) con lógica OR. Botón `EtiquetaFilterButton` en la fila del contador (visible solo si el proyecto tiene etiquetas). Abre Bottom Sheet con chips de selección múltiple (`Wrap`) y aplicación instantánea. Kanban recibe la lista ya filtrada. Etiquetas visibles en tarjetas Kanban (`EtiquetasRow` compacto, máx 3 + "+N").
- [x] **Adjuntos en comentarios de tickets** — botón de adjuntar (bottom sheet: cámara, galería, archivos) en la barra de comentarios. Máximo 10 archivos por comentario. Imágenes como thumbnails clickeables, archivos como chips con ícono por tipo y nombre legible. Permite comentarios sin texto (solo adjuntos). Upload a Storage (`comentarios_tickets/{ticketId}/`).
- [x] **Eliminación suave de comentarios de tickets** — soft-delete: marca `deleted: true`, reemplaza texto con "Comentario eliminado", limpia adjuntos. Solo el autor puede eliminar. Etiqueta visual en el hilo de comentarios.
- [x] Notificaciones push al asignar/cambiar estado (implementado en Fase 1.8).

### 1.7 Levantamiento de Requerimientos

- [x] Modelo de datos de Requerimiento en Firestore (colección `Requerimientos/{docId}`).
- [x] Enums: RequerimientoStatus (6 estados: Propuesto, En Revisión, En Desarrollo, Implementado, Completado, Descartado), RequerimientoTipo (Funcional, No Funcional), RequerimientoFase (Fase Actual, Próxima Fase).
  - Overhaul: eliminados Aprobado, Diferido, Rechazado, Cerrado. Backward compat vía `fromString()` (aprobado→enDesarrollo, diferido→propuesto, rechazado→descartado, cerrado→completado).
  - Transiciones no lineales por rol: Root/Supervisor (completas + descarte), Soporte (limitadas, sin descarte/archivado/eliminación).
- [x] Modelo con CriterioAceptacion (texto + checkbox completado), Participante (uid, nombre, rol).
- [x] Porcentaje de avance auto-calculado desde criterios de aceptación, con override manual por Root/Soporte.
- [x] Modelo de RequerimientoComment (colección separada `ComentariosRequerimientos/{docId}`).
- [x] Repositorio: RequerimientoRepository con CRUD, folio auto-incremental V1, comentarios, criterios, adjuntos, asignación, `delete()` (hard delete), `watchArchivedByProject()`.
- [x] Providers: requerimientos por proyecto, filtros (estado, tipo, búsqueda), conteo de pendientes, visibilidad por rol, `archivedReqsByProjectProvider`, `canArchiveReqProvider` (Root + Supervisor).
- [x] Creación y edición de requerimientos con asociación a proyecto y módulo (existente o propuesto).
- [x] Pantalla de listado con búsqueda, chips de estado y tipo, tarjetas informativas con progreso circular.
- [x] **Vista Kanban** (tablero de 6 columnas por estado) con drag & drop — toggle lista/kanban en AppBar, responsive (lista en móvil, kanban en pantallas anchas ≥840px).
  - Tarjetas enriquecidas: folio, badge de prioridad, título, tipo, módulo, solicitante, responsable, fecha, fase, criterios, adjuntos, barra de progreso.
  - Ordenamiento global con 7 criterios (reciente, antiguo, prioridad ↑↓, solicitante, responsable, % avance).
  - Cambio de estado vía drag & drop genera comentario automático de tipo `statusChange`.
- [x] **Sección Archivados**: sheet deslizable con búsqueda, tarjetas con unarchive y vista, accesible solo para Root y Supervisor.
- [x] Pantalla de detalle con info, criterios de aceptación (checklist interactivo), participantes, adjuntos, observaciones internas (solo Root/Soporte), motivo de descarte, acciones de cambio de estado, archivado, eliminación, hilo de comentarios.
- [x] Pantalla de creación / edición con criterios dinámicos, adjuntos (galería + archivos), gestión manual de porcentaje y fase.
- [x] Permisos de requerimientos: Root/Supervisor = full actions (descarte, archivado, eliminación), Soporte = avance operativo sin descarte/archivado/eliminación.
- [x] ObservacionesRoot visibles solo para Root y Soporte.
- [x] Badge de requerimientos pendientes en botón "Ver requerimientos" de detalle de proyecto.
- [x] Navegación: `/projects/:id/requirements`, `requirements/new`, `requirements/:reqId`, `requirements/:reqId/edit`.
- [x] `StorageService.uploadToPath` — método genérico para subir adjuntos a rutas arbitrarias en Firebase Storage.
- [x] Visibilidad por rol: Usuario solo ve sus propios requerimientos; Root/Supervisor/Soporte ven todos.
- [x] **Adjuntos en comentarios de requerimientos** — misma funcionalidad que tickets: bottom sheet (cámara/galería/archivos), max 10 archivos, thumbnails + chips, comentarios solo-adjuntos. Upload a Storage (`comentarios_requerimientos/{reqId}/`).
- [x] **Eliminación suave de comentarios de requerimientos** — soft-delete con etiqueta "Comentario eliminado", solo por el autor.
- [x] Vinculación bidireccional con minutas (modelo ya tenía `refMinutas`/`refCitas`).
- [x] Gemini AI: status descriptions y `pendingStatuses` actualizados a nuevos 6 estados, filtro `isActive == false` para excluir archivados.
- [x] AI Agent Sheet: colores de status actualizados a nuevos 6 estados.
- [x] **Auto-completar criterios de aceptación** — al cambiar status a "Completado" (desde detalle o drag & drop en Kanban), todos los criterios se marcan automáticamente como completados (`completado: true`) vía `repo.updateCriterios()`.
- [x] **Filtrado por etiquetas en listado y Kanban de requerimientos** — `ReqEtiquetaFilterNotifier` (Set<String>) con lógica OR. Mismo patrón que tickets: `EtiquetaFilterButton` compartido, Bottom Sheet instantáneo. Etiquetas visibles en tarjetas Kanban.
- [x] **`EtiquetaFilterButton`** — widget reutilizable (`etiqueta_filter_button.dart`) con botón compacto + `_EtiquetaFilterSheet` (Bottom Sheet, Wrap de chips, toggle instantáneo, botón Limpiar). Sin conflicto con scroll horizontal del Kanban. Escala a cualquier cantidad de etiquetas.

### 1.8 Notificaciones Push

- [x] Configuración de Firebase Cloud Messaging (`firebase_messaging` ya en pubspec).
- [x] `NotificationService` — solicitar permiso, obtener/refrescar FCM token, guardar en Firestore (`users/{uid}.fcmTokens`).
- [x] Handler de mensajes en background (`firebaseMessagingBackgroundHandler` top-level).
- [x] `FcmInitializer` — widget wrapper que inicializa FCM al login y limpia token al logout.
- [x] `main.dart` actualizado — `FirebaseMessaging.onBackgroundMessage` + `FcmInitializer` envolviendo `MaterialApp`.
- [x] `AndroidManifest.xml` — ícono y canal de notificación por defecto (`astro_default`).
- [x] Campo `fcmTokens` (array) añadido al modelo `AppUser` (Firestore `users/{uid}`).
- [x] Modelo `NotificationType` — 15 tipos de notificación (5 tickets + 6 requerimientos + 4 citas).
- [x] Modelo `InAppNotification` — bandeja in-app (`Notificaciones/{docId}`).
- [x] Modelo `NotificationConfig` — configuración por usuario/proyecto (`NotificationConfig/{projectId_userId}`).
- [x] Enum `NotificationScope` — `participante`, `proyecto`, `todos` con defaults por rol.
- [x] `NotificationConfigRepository` — CRUD de configuraciones, watch por proyecto.
- [x] `NotificationRepository` — bandeja in-app: watch, markAsRead, markAllAsRead, delete.
- [x] Providers: `inboxNotificationsProvider`, `unreadNotificationsProvider`, `unreadCountProvider`, `projectNotifConfigsProvider`, `userNotifConfigProvider`.
- [x] Pantalla **Bandeja de Notificaciones** — historial in-app con iconos por tipo, marca leído/no leído, tiempo relativo, navegación a ticket/req, eliminar con long-press.
- [x] Pantalla **Notificaciones del Proyecto** (Root) — gestión granular por usuario: master toggle, recibir tickets on/off, recibir reqs on/off, recibir tareas on/off, recibir citas on/off, selector de alcance por tipo (`SegmentedButton`), indicador de override vs defaults, restaurar defaults.
- [x] Destino "Notificaciones" en shell de navegación con badge de no leídas (todos los roles).
- [x] Botón "Configurar notificaciones" en detalle de proyecto (solo Root).
- [x] Navegación: `/notifications` (inbox), `/projects/:id/notification-settings` (Root config).
- [x] Reglas de notificación por defecto según rol: Usuario=participante, Supervisor=proyecto, Soporte=proyecto, Root=todos.
- [x] Cloud Functions v2 (TypeScript) — `functions/src/index.ts`:
  - [x] `onTicketCreated` — notifica al crear ticket.
  - [x] `onTicketUpdated` — notifica cambio de status, asignación, prioridad.
  - [x] `onTicketCommentCreated` — notifica comentarios (no system entries).
  - [x] `onReqCreated` — notifica al crear requerimiento.
  - [x] `onReqUpdated` — notifica cambio de status, asignación, fase, prioridad.
  - [x] `onReqCommentCreated` — notifica comentarios de requerimiento.
  - [x] `onCitaCreated` — notifica al crear cita.
  - [x] `onCitaUpdated` — notifica cambio de status, cancelación, cambio de fecha/hora.
  - [x] `getTareaRecipients` — helper refactorizado para usar `NotificationConfig` (recibirTareas/scopeTareas) en vez de roles hardcodeados.
  - [x] `getCitaRecipients` — nuevo helper para destinatarios de citas usando `recibirCitas`/`scopeCitas`.
  - [x] Limpieza automática de FCM tokens inválidos.
  - [x] Escritura dual: push FCM + entrada in-app (Notificaciones).
  - [x] Respeta `NotificationConfig` overrides por usuario/proyecto.
- [x] Índices Firestore para `Notificaciones` (userId+createdAt, userId+leida+createdAt).
- [x] Índices Firestore completos desplegados (45+ índices: Notificaciones, Tickets, projectAssignments, Modulos, Requerimientos, ComentariosRequerimientos, users, Proyectos, NotificacionesGral, chatAI, Citas, Tareas, Minutas, DocumentosProyecto, etc.).
- [x] **Auditoría de índices Firestore** — revisión completa de todas las queries del proyecto vs índices desplegados. 2 índices faltantes añadidos: `Proyectos` (`fkEmpresa + estatusProyecto`) y `Proyectos` (`empresaId + estatusProyecto`) para cascade deactivation de empresas. Deploy exitoso.
- [x] **`updatedBy` en actualizaciones de tickets** — `updateStatus`, `archiveTicket` y `assign` del `TicketRepository` ahora envían `updatedBy` con el UID del usuario que ejecutó la acción. La Cloud Function `onTicketUpdated` usa este campo para excluir al autor de las notificaciones de su propia acción.
- [x] **`updatedBy` en actualizaciones de requerimientos** — `update`, `updateStatus` y `assign` del `RequerimientoRepository` envían `updatedBy`. Screens actualizadas: detail, list/kanban, form.
- [x] **`updatedBy` en actualizaciones de tareas** — `update`, `updateStatus` y `restore` del `TareaRepository` envían `updatedBy`. Screens actualizadas: detail, form, list, global, minuta sync.
- [x] **`updatedBy` en actualizaciones de citas** — `update` y `updateStatus` del `CitaRepository` envían `updatedBy`. Screens actualizadas: detail, form.
- [x] **NotificationConfig expandido** — 4 nuevos campos: `recibirTareas`, `scopeTareas`, `recibirCitas`, `scopeCitas`. Defaults por rol. Pantalla de configuración con secciones Tareas y Citas.
- [x] **NotificationType expandido** — tipos añadidos: `reqPrioridadCambiada`, `citaCreada`, `citaActualizada`, `citaCancelada`, `citaRecordatorio`.
- [x] **Bandeja de notificaciones actualizada** — íconos y navegación para los nuevos tipos de notificación (citas, prioridad de reqs).
- [x] Deploy de Cloud Functions a Firebase — **15 triggers v2** en us-central1 (6 tickets/reqs + 3 tareas + 3 citas + 3 schedulers).
- [x] `firebase.json` y `.firebaserc` en raíz del repo para deploy de functions.
- [x] Botón back en pantalla de Notificaciones del Proyecto (soporte iOS/tablet sin botón hardware).
- [x] Buscador de miembros en pantalla de Notificaciones del Proyecto (filtro por nombre, email, rol).
- [x] Deploy de Cloud Functions a Firebase (`firebase deploy --only functions`) — 15 triggers v2 en us-central1.
- [x] Configurar VAPID key para notificaciones push web — service worker `firebase-messaging-sw.js`, constante `fcmVapidKey` en `fcm_config.dart` (pendiente: pegar key real de Firebase Console).
- [x] Notificaciones push al asignar/cambiar estado en tickets, requerimientos, tareas y citas (completo).
- [x] **Notificaciones programadas (scheduled):**
  - [x] `checkCitaReminders` — cada 15 min, recordatorios de citas según campo `recordatorios[]` (±7.5 min window). Fix: soporte de `fecha` y `fechaHora` (compat FlutterFlow).
  - [x] `checkTicketDeadlines` — diario 08:00 CDMX, semáforo (🟡 2-5d / 🟠 hoy-mañana / 🔴 vencido) con anti-spam (`_lastDeadlineAlert`).
  - [x] `checkTareaDeadlines` — diario 08:00 CDMX, semáforo de tareas con anti-spam.
  - [x] `checkCompromisoDeadlines` — diario 08:00 CDMX, compromisos de minutas pendientes.
  - [x] `dailyMorningSummary` — L-S 09:00 CDMX, resumen diario por proyecto: tickets pendientes (con vencidos), tareas pendientes, citas hoy. Se envía a todos los miembros con push habilitado.
  - [x] `ticketsWithoutDeadlineReminder` — L/Mi/V 10:00 CDMX, alerta de tickets activos sin fecha compromiso. Se envía solo a Root y Soporte.
  - [x] `checkReqDeadlinesMorning` — L-V 09:30 CDMX, semáforo de requerimientos (🟡 ≤5d / 🟠 ≤1d / 🔴 vencido) con anti-spam (`_lastDeadlineAlert` con zone+tag key). Se envía a `assignedToUid` + Root.
  - [x] `checkReqDeadlinesAfternoon` — L-V 16:00 CDMX, segunda revisión diaria de deadlines de requerimientos (misma lógica compartida `_checkReqDeadlinesLogic`).
- [x] **Payload APNs para iOS** — bloque `apns` añadido a `sendEachForMulticast` en Cloud Functions: `apns-priority: "10"`, `sound: "default"`, `content-available: 1`. Garantiza entrega confiable y sonido en dispositivos Apple.
- [x] **Notificaciones foreground en iOS** — `setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true)` en `NotificationService`. Muestra banners push incluso con la app en primer plano en iOS.
- [x] **Configuración APNs en Firebase Console** — clave de autenticación APNs (.p8) subida para entorno de desarrollo y producción. Key ID: `UXKRH6PW76`, Team ID: `VM8NP3C8VD`.
- [x] Deploy de Cloud Functions a Firebase — **20 funciones** (12 triggers + 8 schedulers) en us-central1.
- [x] **Notificación push al modificar progreso de módulo** — Cloud Function `onModuloUpdated` (trigger `onDocumentUpdated("Modulos/{moduloId}")`). Detecta cambio en `porcentCompletaModulo`, consulta `updatedBy` para nombre del usuario que modificó, envía push + notificación in-app a todos los Root del proyecto (excluyendo al autor). Título: `📊 {módulo} — {percent}%`. Campo `updatedBy` añadido a `ModuloRepository.updateProgress`. `module_detail_screen.dart` pasa UID del usuario autenticado.
- [x] Deploy Cloud Functions — **20 funciones** (12 triggers + 8 schedulers) en us-central1.

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
  - **Hub "Gestión"** — Proyectos, Usuarios y Empresas agrupados en un solo destino de navegación. Pantalla hub (`GestionScreen`) con tiles de navegación, condicional por rol (Usuarios y Empresas solo Root). Menú reducido de 6 a 4 destinos.
- [x] Componentes optimizados para touch y mouse/teclado.
  - Tooltips agregados a: FAB, botones send (chat), calendar picker, clear, remove, delete, play/pause.
  - AppBar actions ya tenían tooltips.
- [x] Breakpoints definidos y consistentes.
  - AppBreakpoints: compact=600, medium=840, expanded=1200, large=1600.
- [x] Refinamiento visual Nothing X: rojo solo para atención/crítico, paleta neutra blanca/gris.
  - Theme: NavigationBar/Rail indicadores blancos, ElevatedButton/FilledButton gris.
  - Folios, badges, avatares decorativos → onSurface neutral.
  - progressColor(): rojo <25%, interpolación amber 25-49%, verde 50-100%.
- [x] **Compatibilidad web del Visor de Archivos** — `FileViewerScreen` adaptado para web:
  - Descarga: en web abre la URL en nueva pestaña (navegador maneja la descarga), ya manejado con `kIsWeb`.
  - Visor de PDF (`_PdfViewer`): intenta renderizar con `pdfx` (tiene soporte web vía pdfjs); si falla, muestra fallback con botón "Abrir PDF" que abre el visor nativo del navegador vía `url_launcher`. Sin cambios en móvil.
  - Galería (`gal`): en web retorna `null`, fallback a descarga vía navegador.
- [ ] Testing visual en múltiples tamaños de pantalla.

### 1.11 Testing y QA

- [ ] Tests unitarios de modelos y lógica de negocio.
- [ ] Tests de widgets de componentes clave.
- [ ] Tests de integración de flujos principales.

### 1.12 Publicación y Deploy

- [x] Logotipo oficial integrado como ícono de app y splash screen.
- [x] `flutter_launcher_icons` configurado — genera íconos Android (adaptive), iOS y Web (PWA + favicon).
- [x] `flutter_native_splash` configurado — splash nativo negro con logo centrado (Android, iOS, Web, Android 12+).
- [x] Nombre de app unificado: **ASTRO** en Android (`android:label`), iOS (`CFBundleDisplayName`, `CFBundleName`) y Web (`<title>`, `manifest.json`).
- [x] Metadata web actualizada: `manifest.json` con colores `#000000`, descripción profesional, nombre ASTRO.
- [x] `index.html` actualizado: título, descripción, apple-mobile-web-app-title.
- [x] Splash Android: fondo negro en `launch_background.xml` (values + drawable-v21).
- [x] Versión bumped a `2.3.25+16`.
- [x] Versión bumped a `2.5.1+20`.
- [x] Versión bumped a `2.5.2+21`.
- [x] Versión bumped a `2.5.3+22`.
- [x] Versión bumped a `2.5.4+23`.
- [x] Configurar firma de release para Android (keystore) — `key.properties` + signing config en `build.gradle.kts`.
- [x] Build de release para Android (`flutter build appbundle`) — AAB 54.6MB.
- [x] Actualización en Google Play (Closed Testing) — versiones: v7 (1.4.1), v8 (2.0.0+9), v9 (2.1.0+10), v10 (2.1.2+11), v11-v14 (intermedias), v15 (2.2.22+15).
- [x] **Hardening de Firestore Security Rules**: eliminada regla catch-all abierta (`request.time < 2044`), reemplazadas todas las reglas `if true` por `request.auth != null`, reglas explícitas para las 28+ colecciones y sub-colecciones del proyecto, denegación por defecto para colecciones no listadas. Cloud Functions no afectadas (Admin SDK). Archivo fuente: `firestore.rules`.
- [x] **Preparación Deploy Web (Railway)**: Dockerfile multi-stage (Flutter build + Nginx Alpine), `nginx.conf` con SPA routing + gzip + security headers + `$PORT` dinámico, `.dockerignore` optimizado. CORS configurado en Firebase Storage para dominio Railway. Dominio `astro-production-be6a.up.railway.app` agregado a Firebase Auth Authorized Domains.
- [ ] Deploy web en Railway.
- [ ] Build para iOS / TestFlight.

### 1.13 Gestión de Cuenta y Perfil

- [x] **Avatar de usuario** en el AppBar del Dashboard — ícono/foto que abre la pantalla de perfil.
- [x] Foto de perfil: se carga automáticamente desde Google al registrarse; si no viene de Google, se permite definirla manualmente. Siempre editable.
- [x] Pantalla **Perfil / Mi Cuenta** (`/profile`) con las siguientes secciones:
  - [x] **Ver perfil**: nombre, email, foto, rol actual.
  - [x] **Editar nombre y foto de perfil**: cambiar displayName y subir/cambiar foto (Firebase Storage).
  - [x] **Cambiar contraseña**: formulario de cambio de contraseña (solo usuarios con email/password, no Google).
  - [x] **Tema (Dark / Light)**: SegmentedButton para cambiar el tema de la app. Persistido en SharedPreferences.
  - [x] **Configurar notificaciones generales**: master toggle push ON/OFF global (`pushGlobalEnabled` en `AppUser`). Cloud Functions respeta el flag — si está desactivado no envía push pero sí crea notificación in-app.
  - [x] **Información de la app**: versión, build, paquete, descripción y © Constelación R.
  - [x] **Cerrar sesión**: botón de logout con confirmación.

### 1.14 Gestión de Empresas

- [x] Modelo `Empresa` ampliado con campos V2: logoUrl, dirección, teléfono, contacto, RFC, email, createdAt, updatedAt, copyWith.
- [x] `EmpresaRepository` — CRUD completo: crear, actualizar, desactivar (soft delete), reactivar, watchAllEmpresas, watchEmpresa.
- [x] Providers: `allEmpresasProvider` (activas + inactivas), `empresaByIdProvider` (stream por ID).
- [x] Pestaña **Empresas** en navegación principal — solo visible para Root (como Usuarios).
- [x] Guardia de rol: `/empresas` protegida para Root.
- [x] Pantalla **Listado de Empresas** — búsqueda por nombre/RFC/contacto, grid adaptativo, badge activa/inactiva, botón "Nueva".
- [x] Pantalla **Detalle de Empresa** — header con logo, info (RFC, contacto, email, teléfono, dirección), proyectos asociados con navegación, botón desactivar/reactivar con confirmación.
- [x] Pantalla **Formulario de Empresa** — crear/editar con logo (upload a Firebase Storage), nombre, RFC, contacto, email, teléfono, dirección.
- [x] Rutas: `/empresas`, `/empresas/new`, `/empresas/:empresaId`, `/empresas/:empresaId/edit`.
- [x] **Desactivación en cascada**: al desactivar empresa se desactivan automáticamente proyectos activos + asignaciones asociadas (batch write).
- [x] **Reactivación en cascada**: al reactivar empresa se ofrece reactivar también proyectos y asignaciones (“Solo empresa” o “Empresa + proyectos”).
- [x] Detalle de empresa muestra **todos** los proyectos (activos e inactivos con distinción visual).
- [x] **Protección de proyecto inactivo**: botones de navegación a módulos, tickets, requerimientos, documentación, minutas y citas deshabilitados cuando el proyecto está inactivo, con banner informativo.

---

### 1.12 Tareas Post-Release — CRÍTICAS

- [ ] **🔴 CRÍTICO — Endurecimiento de Firestore Security Rules** — Las reglas actuales otorgan acceso amplio a usuarios autenticados. Se deben restringir por rol y pertenencia a proyecto siguiendo el principio de mínimo privilegio. Incluye: validar que el usuario pertenezca al proyecto antes de leer/escribir, restringir escritura de campos sensibles (isRoot, roles) a Root, limitar operaciones de borrado lógico/físico por rol, y agregar validación de esquema en reglas de escritura. Impacto: seguridad de datos de todos los proyectos y usuarios.

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
- [x] **Campos de referencias cruzadas en Cita** — `refTickets`, `refRequerimientos`, `refMinutas` (List<String>) y `refMinuta` (String?) para minuta generada al completar.
- [x] **Métodos de vinculación en CitaRepository** — `addRefTicket(citaId, ticketId)`, `addRefRequerimiento(citaId, reqId)`, `setRefMinuta(citaId, minutaId)` con `FieldValue.arrayUnion`.
- [x] **Diálogo de Completar Cita** (`_CompletionDialog`) — modal al cambiar estado a `completada`:
  - [x] Campo de comentario de cierre.
  - [x] Botón "Crear ticket" — navega a formulario con `returnId: true, refCitaId`, vincula ticket creado.
  - [x] Botón "Crear requerimiento" — misma dinámica, vincula requerimiento creado.
  - [x] Botón "Completar y generar minuta" — guarda status y navega a `/minutas/new?refCitaId=` con datos pre-cargados.
  - [x] Botón "Completar" — solo guarda status y comentario.
  - [x] Tracking de items creados durante el diálogo (`_CompletionResult`).
- [x] **Visualización de items vinculados en detalle de cita** — secciones de tickets y requerimientos referenciados con chips de navegación al detalle.
- [x] **Agenda de cita** — modelo `AgendaItem` (id, texto, tratado) embebido como lista en `Cita`. Sección "AGENDA" en formulario de cita: agregar, editar, eliminar y reordenar ítems con `ReorderableListView`. En detalle de cita: checklist interactivo con toggle en vivo (`citaRepository.updateAgenda`), permisos `canManage`. IDs generados con `DateTime.now().microsecondsSinceEpoch`.
- [x] **Agenda → Asuntos tratados en minuta** — al crear minuta desde cita, los ítems de la agenda se pre-populan como `AsuntoTratado` en el formulario de minuta (solo si la cita tiene agenda y los asuntos están vacíos).

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
- [x] UI de selección/vinculación de citas desde ticket (picker en formulario de ticket con búsqueda por folio/titulo).
- [x] Métodos `TicketRepository.addRefCita/removeRefCita` para sincronización de citas vinculadas.
- [x] Navegación cruzada entre tickets ↔ minutas/citas (tap desde detalle de ticket navega a minuta o cita).
- [x] Navegación cruzada entre minutas ↔ tickets/requerimientos (tap desde detalle de minuta navega a ticket o requerimiento).
- [x] Navegación cruzada entre requerimientos ↔ minutas (tap desde detalle de requerimiento navega a minuta).
- [x] **Vinculación bidireccional Citas ↔ Tickets/Requerimientos:**
  - [x] Campo `refCitas` (List<String>) añadido al modelo `Requerimiento` (constructor, fromFirestore, toFirestore, copyWith).
  - [x] Parámetro `refCitaId` en rutas de creación: `ticketNew`, `reqNew` y `minutaNew` del router extraen `refCitaId` desde `extra` o query param.
  - [x] `TicketFormScreen` — constructor param `refCitaId`; al iniciar, agrega a lista de citas referenciadas.
  - [x] `RequerimientoFormScreen` — constructor param `refCitaId`; al iniciar, agrega a lista de citas referenciadas.
  - [x] `MinutaFormScreen` — constructor param `citaId`; pre-carga datos de la cita (participantes, fecha, modalidad, URL, dirección); al guardar llama `citaRepo.setRefMinuta(citaId, docId)`.
  - [x] Navegación cruzada entre citas ↔ tickets/requerimientos (tap desde detalle de cita navega a ticket o requerimiento vinculado).
- [x] **Widget `ResolvedRefText`** — widget reutilizable para mostrar referencias cruzadas resueltas (folio + nombre) en pantallas de detalle de tickets, requerimientos, minutas, citas y tareas. Reemplaza IDs crudos por texto legible consultando Firestore. Implementado en 8 pantallas.

### 2.4 Módulo de Tareas

- [x] Modelo de datos `Tarea` en Firestore (colección `Tareas/{docId}`).
- [x] Campos: id, folio (TAR-ABBR-NUM), titulo, descripcion, projectId, projectName, status, prioridad, createdByUid, createdByName, moduleId/Name, assignedToUid/Name, fechaEntrega, adjuntos, refTickets, refRequerimientos, refMinutas, refCitas (List<String>), refCompromisoNumero, isActive, createdAt, updatedAt.
- [x] **Migración de referencias de tarea** — campos `refTicketId`, `refRequerimientoId`, `refMinutaId` (String?) migrados a `refTickets`, `refRequerimientos`, `refMinutas`, `refCitas` (List<String>). Helper `parseRefList(listVal, singleVal)` para compatibilidad retroactiva con documentos existentes.
- [x] Enums: `TareaStatus` (pendiente, enProgreso, completada, cancelada), `TareaPrioridad` (baja, media, alta, urgente).
- [x] `TareaRepository` — CRUD, folio auto-incremental (TAR-ABBR-NUM), watchByProject, watchByAssignee, archive.
- [x] Providers Riverpod: tareas por proyecto, por ID, por asignado (cross-project), filtros (búsqueda, status, prioridad), visibilidad por rol, contadores, `myPendingTareasProvider`.
- [x] Pantalla **Listado de Tareas por proyecto** — búsqueda, chips de filtro por status y prioridad, tarjetas con folio, status bar, prioridad badge, asignado, fecha.
- [x] Pantalla **Detalle de Tarea** — info completa, referencias cruzadas (minuta, ticket, requerimiento).
- [x] Pantalla **Formulario de Tarea** — crear/editar con título, descripción, módulo, prioridad, asignado (miembros del proyecto), fecha de entrega, referencias.
- [x] Navegación: `/projects/:id/tareas`, `tareas/new`, `tareas/:tareaId`, `tareas/:tareaId/edit`.
- [x] Cloud Functions: `onTareaCreated`, `onTareaUpdated`, `checkTareaDeadlines` — notificaciones push + in-app al crear, actualizar, y alerta de vencimiento.
- [x] **Pantalla global de Tareas** (`/tareas`) — vista cross-proyecto en navegación principal. Muestra tareas pendientes/en progreso del usuario con filtros de status, prioridad y búsqueda. FAB para crear nueva tarea (selector de proyecto).
- [x] **Destino "Tareas" en navegación principal** — insertado después de Dashboard con badge de tareas pendientes. Visible en NavigationBar (móvil) y NavigationRail (tablet/web).
- [x] **Auto-generación de tareas desde compromisos de minuta** — al guardar una minuta (crear o editar), se crean automáticamente tareas para cada compromiso que tenga `responsableUid` definido. Verificación de duplicados por `refMinutaId` + `refCompromisoNumero`. Best-effort (no bloquea guardado).
- [x] **Eliminación del botón manual "Crear Tarea"** en detalle de minuta — reemplazado por auto-generación automática.
- [x] **Eliminación de sección "Actividades" del Dashboard** — las tareas ahora se gestionan desde la pantalla global `/tareas` en la navegación principal. Imports y código muerto eliminados del dashboard.
- [x] **Subtareas (checklist)** — modelo `Subtarea` embebido en `Tarea` (id, titulo, completada, orden). CRUD desde formulario de tarea: agregar, editar inline, reordenar con drag handle, eliminar. Detalle de tarea muestra checklist interactivo con toggle de completado. Progreso visual (barra + porcentaje) basado en subtareas completadas.
- [x] **Zona drag & drop de adjuntos en formulario de tarea** — `DropRegion` para arrastrar archivos (desktop/web). Preview de archivos pendientes con thumbnails (imágenes) o chips con ícono por tipo. Eliminar archivos pendientes con botón X.
- [x] **Rediseño UX del detalle de tarea** — Hero section con anillo de progreso animado, gradiente por status, urgencia de deadline, texto motivacional. Layout dos columnas en tablet/desktop. Secciones colapsables.
- [x] **Acciones rápidas en detalle de tarea** — botones de cambio de estado según estado actual: Iniciar, Completar, Cancelar, Pendiente, Reabrir. Permisos: `canInteract` (Root, asignado o creador) para cambios de estado; `canArchive` (Root + Supervisor) para archivar/restaurar/reabrir completadas o canceladas.
- [x] **Archivado (soft-delete) de tareas** — solo Root y Supervisor pueden archivar tareas completadas o canceladas. Confirmación con diálogo. Campo `isActive: false` en Firestore.
- [x] **Restauración de tareas archivadas** — diálogo de selección de estado (pendiente / en progreso) al restaurar. Solo Root y Supervisor.
- [x] **Sección de archivadas en listado por proyecto** — botón en AppBar (solo Root/Supervisor) abre DraggableScrollableSheet con búsqueda por folio/título, listado de tareas archivadas con acciones de restaurar y ver detalle.
- [x] **Visibilidad por rol en pantalla global** — `myPendingTareasProvider` corregido: Root ve todas; Supervisor/Soporte ven todas las tareas de sus proyectos asignados; Usuario solo ve sus tareas asignadas.
- [x] `canArchiveTareaProvider` — Provider de permisos: `true` si es Root o tiene rol Supervisor en el proyecto de la tarea.
- [x] `TareaRepository.updateStatus` — actualización rápida de solo status (sin pasar por form completo).
- [x] `TareaRepository.restore` — restaura tarea archivada (`isActive: true` + nuevo status).
- [x] `TareaRepository.watchArchivedByProject` — stream de tareas archivadas por proyecto.

### 2.4.1 Sincronización Bidireccional Compromisos ↔ Tareas

- [x] **Sync compromiso → tarea** — al marcar/desmarcar un compromiso en el detalle de minuta, se actualiza automáticamente el status de la tarea vinculada (cumplido → completada, pendiente → pendiente). Best-effort.
- [x] **Sync tarea → compromiso** — al cambiar el status de una tarea (acciones rápidas), se actualiza el compromiso vinculado en la minuta (completada → cumplido, otros → pendiente). Best-effort.
- [x] **Sync al restaurar tarea** — al restaurar una tarea archivada vinculada a minuta, el compromiso se marca como pendiente.
- [x] `MinutaRepository.updateCompromisoStatus` — método que actualiza el estado de un compromiso específico dentro de una minuta por su número.
- [x] `TareaRepository.watchByMinuta` — stream de todas las tareas (activas + archivadas) vinculadas a una minuta, ordenadas por `refCompromisoNumero`.
- [x] `tareasByMinutaProvider` — StreamProvider.family para consulta reactiva de tareas por minuta.
- [x] **Vista enriquecida de compromisos** — cada compromiso en el detalle de minuta muestra inline la tarea vinculada: folio, badge de status, enlace de navegación al detalle de la tarea.
- [x] **Flag visual de tarea archivada en minuta** — si la tarea vinculada a un compromiso está archivada, el compromiso se muestra con estilo atenuado, icono de archivado, texto tachado y badge "Archivada". El toggle queda deshabilitado.
- [x] **Diálogo de archivado consciente de minuta** — al archivar una tarea vinculada a minuta, el diálogo advierte que el compromiso en la minuta se mostrará como archivado. No bloquea el archivado.

### 2.4.2 UX Mejorada — Pantalla Global de Tareas

- [x] **Agrupación por tiempo** — las tareas se agrupan automáticamente en secciones: Vencidas, Hoy, Mañana, Esta semana, Próximamente, Sin fecha. Cada sección con icono, color y contador.
- [x] **Identificación visual de proyecto** — cada tarea muestra un dot de color determinista según `projectId` (paleta de 10 colores). El nombre del proyecto se resalta con el color correspondiente.
- [x] **Indicador de urgencia de deadline** — las tareas vencidas, con vencimiento hoy o mañana muestran etiqueta de urgencia con color (rojo/naranja/amarillo) en lugar de la fecha cruda.
- [x] **Archivado masivo de completadas y canceladas** — botones "Archivar N completadas" y "Archivar N canceladas" visibles en sus respectivas secciones cuando hay tareas con status Completada o Cancelada (solo Root/Supervisor). Diálogo de confirmación. Archiva todas en lote.
- [x] Helpers reutilizables: `_TimeGroup` enum, `_GroupedTareaList`, `_SectionHeader`, `_BulkArchiveButton`, `_projectColor`, `_deadlineLabel`.

### 2.4.3 Pestañas "Mis tareas" / "Compañeros" + Agrupación por Proyecto

- [x] **Pestañas condicionales** — TabBar con "Mis tareas" y "Compañeros" visible solo para roles Root, Supervisor y Soporte (`canSeeOthersTasksProvider`). Usuarios con rol Usuario solo ven la vista de sus tareas sin tabs.
- [x] **Separación de tareas** — "Mis tareas" muestra solo tareas donde `assignedToUid == uid`. "Compañeros" muestra tareas asignadas a otros usuarios.
- [x] **Agrupación por proyecto** — dentro de cada pestaña, las tareas se agrupan primero por proyecto (header con dot de color + nombre + conteo) y dentro de cada proyecto por sub-grupos temporales (Vencidas, Hoy, Mañana, Esta semana, Próximamente, Sin fecha, Completadas, Canceladas).
- [x] **Widgets nuevos** — `_ProjectGroupedTareaList` (lista con agrupación proyecto → tiempo), `_ProjectSectionHeader` (header de proyecto con color determinista).
- [x] **Archivado masivo preservado** — botones de archivar completadas/canceladas dentro de cada sub-grupo temporal, por proyecto.
- [x] Filtros de búsqueda, status y prioridad compartidos entre ambas pestañas.

### 2.5 Auto-generación de PDF de Minuta como Documento Formal

- [x] Categoría `minuta` añadida a `DocumentoCategoria` enum.
- [x] `StorageService.uploadBytes` — método para subir bytes crudos (PDF) a Firebase Storage.
- [x] Al guardar minuta (crear o editar), se genera automáticamente el PDF, se sube a Storage y se crea un `DocumentoProyecto` formal con categoría "Minuta" y sección "Formal".
- [x] Generación best-effort: si falla el PDF no se bloquea el guardado de la minuta.

### 2.6 Módulo de Agente de IA

- [x] **Modelo de datos** — `AiChatMessage` con bloques de contenido tipados (`AiContentBlock`): text, tickets, minutas, requerimientos, citas, progress, actionConfirm. Colección Firestore `chatAI`.
- [x] **Repositorio** — `AiChatRepository`: stream de mensajes, agregar mensaje, borrar historial por usuario.
- [x] **Servicio Gemini** — `GeminiService` con Gemini 2.0 Flash via Firebase AI Logic. System prompt en español. Loop iterativo de function calling.
- [x] **Function calling** (6 funciones): `buscarTickets`, `obtenerProgresoProyecto`, `buscarMinutas`, `buscarRequerimientos`, `buscarCitas`, `obtenerResumenProyecto`. Cada función consulta Firestore directamente.
- [x] **Servicio de voz** — `VoiceService`: TTS (`flutter_tts`, es-MX) + STT (`speech_to_text`, es_MX, dictation mode).
- [x] **Providers Riverpod** — `AiChatNotifier` con estado (isLoading, isListening, isSpeaking, autoSpeak), envío de mensajes, voz automática, borrado de historial.
- [x] **Chat UI** — Bottom sheet modal (`AiAgentSheet`): drag handle, header con toggle auto-voz, lista de mensajes con burbujas (usuario/asistente), bloques de datos interactivos (cards tapeables), indicador de escritura animado, barra de entrada con campo de texto + micrófono + enviar, sugerencias rápidas en estado vacío.
- [x] **FAB en Dashboard** — Botón flotante `Icons.auto_awesome` que abre el bottom sheet del agente. Visible solo para Root, Supervisor y Soporte (excluye rol Usuario).
- [x] **Borrar historial en Perfil** — Sección "ASISTENTE IA" en la pantalla de perfil con opción para borrar historial con diálogo de confirmación.
- [x] **Permiso RECORD_AUDIO** — Agregado en AndroidManifest.xml para speech-to-text.
- [x] **Fix StateError en dispose()** — `AiAgentSheet` guardaba referencia `AiChatNotifier` en `late final _chatNotifier` durante `initState()` para evitar `ref.read()` en `dispose()` (patrón seguro de Riverpod cuando widget se desmonta).
- [x] **TTS mejorado** — detener TTS al cerrar el bottom sheet o enviar nuevo mensaje. Botón mute para desactivar auto-speak. Disclaimer informativo sobre el asistente.
- [ ] Pruebas en dispositivo físico y ajustes de UX.
- [ ] Integración con navegación a detalle de items (tickets, minutas, requerimientos, citas).

### 2.6.1 Integración de Tareas con el Agente de IA

- [x] **`AiContentType.tareas`** — Nuevo tipo de contenido en el enum para renderizar tarjetas de tareas en el chat.
- [x] **`buscarTareas` function calling** — Nueva función Gemini para buscar/filtrar tareas por proyecto, status, prioridad, asignado y texto libre. Consulta colección `Tareas` en Firestore.
- [x] **System prompt actualizado** — Incluir tareas en las capacidades descritas al modelo. Gemini sabrá buscar tareas pendientes, filtrar por prioridad/status, y reportar tareas vencidas.
- [x] **Tarjeta de tarea en el chat** — Renderizado de mini-cards de tareas con folio, título, status badge, prioridad badge, asignado y fecha de entrega.
- [x] **Navegación a detalle de tarea** — Al tapear una tarjeta de tarea en el chat, navegar a `/projects/{projectId}/tareas/{tareaId}`.
- [x] **Colores de status/prioridad para tareas** — Helpers `_tareaStatusColor` y `_tareaPrioridadColor` en el sheet del agente.
- [x] **Sugerencia rápida "Mis tareas pendientes"** — Chip de sugerencia en el estado vacío del chat.
- [x] **Texto del empty state actualizado** — Incluir "tareas" en la descripción de capacidades del asistente.
- [x] Validación con `dart analyze`.

### 2.7 Módulo de Avisos

- [x] Modelo de datos `Aviso` en Firestore (colección `Avisos/{docId}`).
- [x] Sub-modelo `AvisoLectura` (uid, leido, leidoAt) — sistema de read receipts estilo WhatsApp.
- [x] Enum `AvisoPrioridad` (informativo, importante, urgente) con color y label.
- [x] Campos: id, titulo, mensaje, prioridad, projectId, projectName, createdBy, createdByName, destinatarios (List<String>), todosLosUsuarios (bool), lecturas (Map<String, AvisoLectura>), isActive, expiresAt, createdAt, updatedAt.
- [x] Computed: `leidoCount`, `totalDestinatarios`, `todosLeyeron`, `isExpired`.
- [x] `AvisoRepository` — CRUD, `watchByProject` (Root), `watchByRecipient` (filtrado), `watchAviso`, `markAsRead`, `initializeLecturas`, `deactivate`.
- [x] Providers Riverpod: `avisoRepositoryProvider`, `avisosByProjectProvider`, `avisosByRecipientProvider`, `visibleAvisosProvider` (rol-based), `avisoByIdProvider`, `avisoCountProvider`, `unreadAvisoCountProvider`, `avisoSearchProvider`, `filteredAvisosProvider`.
- [x] Pantalla **Listado de Avisos** — búsqueda, contador, tarjetas con franja de prioridad, ícono, punto azul de no leído, preview de mensaje, chips de audiencia y prioridad, indicador de read receipts (Root: done_all + conteo), fecha.
- [x] Pantalla **Detalle de Aviso** — banner de prioridad, título, meta (autor, fecha, expiración), mensaje completo, audience info, sección de read receipts (Root): barra de progreso, lista de usuarios con estado leído/no leído y timestamp. Auto-marca como leído al abrir.
- [x] Pantalla **Formulario de Aviso** — título (max 120), mensaje (max 1000, multiline), selector de prioridad (SegmentedButton), toggle "Enviar a todos" con switch o selección individual de miembros del proyecto, fecha de expiración opcional. Modo edición para avisos existentes.
- [x] Acceso **solo Root** — botón "Ver avisos" en detalle de proyecto (con badge de conteo), visible solo para usuarios Root.
- [x] Rutas: `/projects/:id/avisos`, `avisos/new`, `avisos/:avisoId`, `avisos/:avisoId/edit`.
- [x] `NotificationType` expandido — `avisoCreado`, `avisoUrgente`.
- [x] `NotificationRefType` expandido — `aviso`.
- [x] Bandeja de notificaciones actualizada — navegación a detalle de aviso + íconos (campaign_outlined / campaign).
- [x] Cloud Function `onAvisoCreated` — trigger `onDocumentCreated("Avisos/{avisoId}")`: determina destinatarios (todos los miembros o lista específica), excluye al creador, envía push + notificación in-app con emoji por prioridad (📢/⚠️/🚨).
- [x] Índice Firestore compuesto: `Avisos` → `projectId` ASC + `isActive` ASC + `createdAt` DESC.

### 2.8 Notificaciones In-App (Toasts en tiempo real)

- [x] **`NotificationSoundService`** — Genera tono de notificación WAV en memoria (880 Hz → 660 Hz, ding-dong de 300 ms) y lo reproduce con `audioplayers`. Incluye haptic feedback en mobile.
- [x] **`InAppToastWidget`** — Banner overlay animado (slide-in desde arriba + fade). Diseño Nothing Phone: barra lateral de color por `refType`, icono por `NotificationType`, nombre del proyecto, título y cuerpo. Auto-dismiss 5 s, swipe-up para cerrar, tap para navegar al elemento.
- [x] **`InAppNotificationListener`** — Widget wrapper dentro de `MaterialApp.router(builder:)`. Escucha `unreadNotificationsProvider` en tiempo real. Primera emisión: seed de IDs sin toast. Emisiones siguientes: detecta IDs nuevos y muestra toasts. Cola de máximo 3 simultáneos.
- [x] Navegación desde toast — tap marca como leída y navega: ticket, requerimiento, minuta, tarea, cita, aviso (mismas rutas que inbox).
- [x] **Campo `inAppNotificationsEnabled`** en `AppUser` (bool, default `true`) — toggle global para activar/desactivar banners y sonido.
- [x] **Toggle en "Mi cuenta"** — `_InAppNotificationToggleTile` con switch, icono adaptativo, subtítulo "modo concentración" cuando está desactivado.
- [x] Mismo filtrado que push — las Cloud Functions ya crean `Notificaciones/{docId}` solo para usuarios elegibles (según `NotificationConfig` por proyecto y categoría). El toggle in-app solo controla la presentación visual/sonora, no la creación del doc.
- [x] Dependencia `audioplayers: ^6.1.0` añadida a `pubspec.yaml`.
- [x] Carpeta `assets/sounds/` registrada en pubspec (preparada para sonidos personalizados futuros).
- [x] Sin nuevos índices Firestore necesarios — reutiliza los queries existentes de `Notificaciones` (userId + createdAt).
- [x] Sin cambios en Cloud Functions — el sistema aprovecha los docs `Notificaciones` que ya se crean.
- [x] Sin cambios en Firestore Security Rules — la colección `Notificaciones` ya tiene reglas de acceso.

### 2.9 Editor de Texto Enriquecido (Rich Text)

- [x] **Dependencias** — `flutter_quill: ^11.5.0`, `markdown_quill: ^4.3.0`, `dart_quill_delta`, `markdown`, `flutter_localizations: sdk: flutter`.
- [x] **Widget `RichTextEditor`** — editor WYSIWYG reutilizable (`lib/core/widgets/rich_text_editor.dart`). GlobalKey-accessible vía `RichTextEditorState`. Getter `markdown` retorna Delta JSON (`jsonEncode(delta.toJson())`). Getter `isEmpty` usa `plainText.isEmpty`. `setMarkdown(text)` auto-detecta formato (Delta JSON → Markdown → texto plano). `clear()`. Parámetros: `placeholder`, `toolbarLevel` (full/mini), `minHeight`, `maxHeight`, `initialMarkdown`, `onChanged`, `focusNode`, `autoFocus`.
- [x] **Widget `RichTextViewer`** — visor de solo lectura (`lib/core/widgets/rich_text_viewer.dart`). Acepta `markdown:` que puede ser Delta JSON, Markdown legado o texto plano. Auto-detección en `_markdownToDelta`. Compatible con web nativamente (flutter_quill).
- [x] **Formato de almacenamiento** — Delta JSON (`[{"insert":"..."}]`). Backward compatibility con contenido Markdown legado vía `MarkdownToDelta` de `markdown_quill`.
- [x] **Delegados de localización** — `localizationsDelegates`, `supportedLocales`, `locale: Locale('es')` en `main.dart` para internacionalización de flutter_quill.
- [x] **Integración Tickets** — `ticket_form_screen.dart`: campo Descripción reemplazado por `RichTextEditor` (toolbar completo). `ticket_detail_screen.dart`: descripción y comentarios renderizados con `RichTextViewer`; campo de comentario con `RichTextEditor` (toolbar mini).
- [x] **Integración Requerimientos** — `requerimiento_form_screen.dart`: campos Descripción y Observaciones con `RichTextEditor` (toolbar completo y mini respectivamente). `requerimiento_detail_screen.dart`: descripción, observaciones Root y comentarios con `RichTextViewer`; campo de comentario con `RichTextEditor` mini.
- [x] **Integración Tareas** — `tarea_form_screen.dart`: campo Descripción reemplazado por `RichTextEditor` (toolbar completo); pre-llenado desde `initialDescripcion` (compromisos de minuta). `tarea_detail_screen.dart`: `_DescriptionCard` muestra descripción con `RichTextViewer`.
- [x] Compatible con web (flutter_quill soporta web nativamente sin configuración adicional).

### 2.10 Sistema de Etiquetas (Labels)

- [x] **Modelo `Etiqueta`** (`lib/core/models/etiqueta.dart`) — campos: `id, nombre, colorHex, icono?, esGlobal, projectId?, projectName?, createdByUid, createdByName, isActive, createdAt?, updatedAt?`. Computed: `Color get color`. Constantes: `kEtiquetaPresetColors` (20 colores), `kEtiquetaPresetIcons` (20 iconos). Colección Firestore: `Etiquetas`.
- [x] **`EtiquetaRepository`** (`lib/features/etiquetas/data/etiqueta_repository.dart`) — métodos: `getById`, `watchGlobal`, `watchByProject`, `watchAvailableForProject`, `watchByIds`, `create`, `update`, `deactivate`, `activate`, `importGlobal`.
- [x] **Providers** (`lib/features/etiquetas/providers/etiqueta_providers.dart`) — `etiquetaRepositoryProvider`, `globalEtiquetasProvider`, `projectEtiquetasProvider`, `availableEtiquetasProvider`, `etiquetasByIdsProvider`, `canManageGlobalEtiquetasProvider`, `canManageProjectEtiquetasProvider`.
- [x] **Widget `EtiquetaChip`** — chip individual con color de fondo, ícono opcional, nombre. Variante `compact`. Soporte `onDelete`. Método público estático `resolveIcon(String?)` para resolver nombre de ícono a `IconData`.
- [x] **Widget `EtiquetasRow`** — fila de chips con overflow "+N". Parámetros: `etiquetas, compact, maxVisible`.
- [x] **Widget `EtiquetaPicker`** — selector modal (`DraggableScrollableSheet`). Búsqueda, checkmarks. API: `EtiquetaPicker.show(context, ref, projectId:, selectedIds:)` → `List<String>?`. Header con botón de configuración `⚙️` (redirige a gestión de etiquetas). Empty state con CTA "Gestionar etiquetas".
- [x] **`EtiquetaFormScreen`** — CRUD de etiquetas. Soporta `etiqueta?` (objeto), `etiquetaId?` (carga por ID desde router), `projectId?`, `projectName?`. Grid de 20 colores preset, grid de 20 íconos + "ninguno", preview en vivo, validación de nombre.
- [x] **`EtiquetasScreen`** — pantalla de gestión por proyecto. Muestra etiquetas activas del proyecto. Botón "Nueva etiqueta".
- [x] **Integración en modelos** — campo `etiquetaIds: List<String>` añadido a: `Ticket`, `Requerimiento`, `Tarea`, `Cita`. Incluye: constructor default, `fromFirestore`, `toFirestore` (siempre incluye el campo, lista vacía incluida — corrige bug de persistencia), `copyWith`.
- [x] **Integración en formularios** — sección "ETIQUETAS" con picker y chips de borrado individual en: `ticket_form_screen`, `requerimiento_form_screen`, `tarea_form_screen`, `cita_form_screen`.
- [x] **Integración en detalle** — sección/card de etiquetas asignadas (no vacía) en: `ticket_detail_screen`, `requerimiento_detail_screen`, `tarea_detail_screen`, `cita_detail_screen`. Botón "Gestionar etiquetas" visible para roles con permiso (`canManageProjectEtiquetasProvider`).
- [x] **Rutas GoRouter** — 3 rutas de proyecto: `projectEtiquetas`, `projectEtiquetaNew`, `projectEtiquetaEdit`. (Rutas globales eliminadas — concepto global removido).
- [x] **GestionScreen** — tile "Etiquetas" eliminado (etiquetas son por proyecto, no globales).
- [x] **ProjectDetailScreen** — botón "Etiquetas del proyecto" visible para Root, Lider Proyecto y Soporte. Navega a `/projects/:id/etiquetas`.
- [x] **Firestore Security Rules** — reglas para colección `Etiquetas` simplificadas a `allow read, write: if request.auth != null` (autenticación suficiente para todas las operaciones de etiquetas). Desplegadas.
- [x] **Bugfix — `etiquetasByIdsProvider` con parámetro por valor** — parámetro del provider cambiado de `List<String>` (igualdad por referencia) a `String` (IDs sorted+joined, igualdad por valor). Corrige bug donde agregar/quitar etiquetas en formularios no se reflejaba visualmente (Riverpod devolvía caché por ver la misma referencia de lista).
- [x] **Bugfix — Etiquetas no se guardaban al editar** — `toFirestore()` en `Ticket`, `Tarea`, `Cita` y `Requerimiento` tenía `if (etiquetaIds.isNotEmpty) 'etiquetaIds': etiquetaIds` — con `merge: true` en Firestore, el campo se omitía cuando la lista era vacía o reducida, dejando el valor viejo. Corregido a `'etiquetaIds': etiquetaIds` (siempre incluido).
- [x] **Bugfix — `watchAvailableForProject`** — query ahora filtra por `projectId + isActive` (antes hacía scan completo sin filtro de proyecto, causaba `permission-denied`).
- [x] **Filtro de etiquetas en Tickets** (`TicketEtiquetaFilterNotifier`, `ticketEtiquetaFilterProvider`) — `EtiquetaFilterButton` en `ticket_list_screen.dart`. Lógica OR: si el ticket tiene al menos una de las etiquetas seleccionadas, se muestra. Sin selección = sin filtro. Chips visibles en `_TicketTile`.
- [x] **Filtro de etiquetas en Requerimientos** (`ReqEtiquetaFilterNotifier`, `reqEtiquetaFilterProvider`) — `EtiquetaFilterButton` en `requerimiento_list_screen.dart`. Mismo patrón OR. Chips visibles en `_ReqCard`.
- [x] **Filtro de etiquetas en Tareas** (`TareaEtiquetaFilterNotifier`, `tareaEtiquetaFilterProvider`) — `EtiquetaFilterButton` en `tareas_list_screen.dart`. Chips visibles en `_TareaTile`.
- [x] **Filtro de etiquetas en Citas** (`CitaEtiquetaFilterNotifier`, `citaEtiquetaFilterProvider`) — `EtiquetaFilterButton` en `cita_list_screen.dart`. Chips visibles en `_CitaCard`.
- [x] **Filtro + gestión de etiquetas en Documentos** — campo `etiquetaIds: List<String>` añadido al modelo `DocumentoProyecto` (constructor, `fromFirestore`, `toFirestore`, `copyWith`). Sección ETIQUETAS con `EtiquetaPicker` en `documento_form_screen.dart`. Card de etiquetas en `documento_detail_screen.dart` con botón "Gestionar etiquetas". `DocEtiquetaFilterNotifier` + `docEtiquetaFilterProvider` + filtro OR en `filteredDocumentosProvider`. `EtiquetaFilterButton` en `documento_list_screen.dart` (`_FormalesTab`). Chips visibles en `_DocumentCard`.

### 2.10.1 Correcciones y Estabilidad de Formularios

- [x] **Bugfix — Descripción se borraba al hacer scroll** — `RichTextEditorState` ahora implementa `AutomaticKeepAliveClientMixin` con `wantKeepAlive: true`. Corrige que Flutter desmontara el editor Quill al salir del caché del `ListView`, borrando el contenido del usuario. Fix aplica a todos los formularios (tickets, tareas, requerimientos, citas) de una sola vez al estar en el widget compartido.
- [x] **Bugfix — Crash al guardar ticket sin módulo seleccionado** — `_save()` en `ticket_form_screen.dart` tenía `moduleId: _selectedModuleId!` sin guard. Añadida validación explícita antes del operador `!`: si `_selectedModuleId == null` muestra snackbar y retorna. El dropdown de módulos ahora tiene 3 estados: cargando (spinner), vacío (mensaje de advertencia naranja), con módulos (dropdown normal con `value` en lugar del deprecado `initialValue`).

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

*Última actualización: v2.5.3+22 — Filtro de etiquetas extendido a Tareas, Citas y Documentos. `DocumentoProyecto` actualizado con `etiquetaIds`. Formulario, detalle y lista de documentos con gestión completa de etiquetas. `EtiquetaFilterButton` en todas las pantallas de lista. Chips de etiquetas visibles en tarjetas/tiles de todas las entidades.*
