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
- [ ] Configurar Firebase Cloud Messaging (notificaciones push).
- [ ] Configurar Firebase Functions.
- [x] Configurar estructura de carpetas del proyecto.
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

- [ ] Modelo de datos de Requerimiento en Firestore.
- [ ] Creación y edición de requerimientos.
- [ ] Asociación de requerimientos a proyectos y módulos.
- [ ] Estados de requerimiento.
- [ ] Participación de Supervisor, Usuario, Soporte y Root.

### 1.8 Notificaciones Push

- [ ] Configuración de Firebase Cloud Messaging.
- [ ] Notificaciones en tiempo real para asignación de tickets.
- [ ] Notificaciones de cambios de estado en tickets.
- [ ] Notificaciones de nuevos requerimientos.
- [ ] Gestión de preferencias de notificaciones por usuario.

### 1.9 Documentación del Proyecto

- [ ] Modelo de datos de Documentación en Firestore.
- [ ] Sección de documentación por proyecto.
- [ ] Carga y visualización de archivos (Storage).

### 1.10 Interfaces Adaptativas

- [ ] Layouts adaptativos: móvil, tablet/fold, web/desktop.
- [ ] Navegación responsiva (bottom nav en móvil, sidebar en tablet/web).
- [ ] Componentes optimizados para touch y mouse/teclado.
- [ ] Breakpoints definidos y consistentes.
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

---

## Fase 2 — Funcionalidades Avanzadas

**Estado:** 🔲 Pendiente (se desarrollará posterior a Fase 1)

### 2.1 Citas y Videoconferencias

- [ ] Módulo de agendar citas/videoconferencias.
- [ ] Integración con **Google Calendar** para programar eventos.
- [ ] Generación automática de URL de videoconferencia.
- [ ] Asociación de citas a requerimientos, incidentes o desarrollo de funcionalidades.
- [ ] Notificaciones y recordatorios de citas.

### 2.2 Módulo de Minutas

- [ ] Formato de minuta (basado en formato existente del cliente).
- [ ] Creación y edición de minutas.
- [ ] Adjuntar archivos: imágenes, documentos, audios, videos.
- [ ] Campos de minuta: referencias, folio de tickets, participantes, prioridades.
- [ ] **Resumen de minuta generado por IA** (Firebase AI Logic / Gemini).
- [ ] Historial de minutas por proyecto.

### 2.3 Vinculación Tickets ↔ Minutas

- [ ] Adjuntar a los tickets la referencia de una o varias minutas.
- [ ] Navegación cruzada entre tickets y minutas vinculadas.
- [ ] Seguimiento preciso de decisiones tomadas en minutas reflejadas en tickets.

### 2.4 Módulo de Agente de IA

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

*Última actualización: 10 de julio de 2025 — Onboarding, Dashboard principal, asignación de equipo desde proyecto*
