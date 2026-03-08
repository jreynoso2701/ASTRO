# ASTRO — Roadmap de Desarrollo

> Documento de seguimiento del desarrollo del proyecto ASTRO por fases.
> Se actualiza conforme se avanza en la implementación.

---

## Fase 1 — MVP: Sistema Base de Gestión de Proyectos

**Estado:** 🔲 Por iniciar

### 1.1 Setup del Proyecto

- [ ] Crear proyecto Flutter desde cero.
- [ ] Configurar identificador `com.constelacionr.apps.astro`.
- [ ] Conectar con Firebase (proyecto `astro-b97c2`).
- [ ] Configurar Firebase Authentication (email + Google Sign-In).
- [ ] Configurar Firestore Database.
- [ ] Configurar Firebase Storage.
- [ ] Configurar Firebase Cloud Messaging (notificaciones push).
- [ ] Configurar Firebase Functions.
- [ ] Configurar estructura de carpetas del proyecto.
- [ ] Configurar sistema de temas Dark (default) / Light inspirado en Nothing Phone.
- [ ] Definir tipografías y paleta de colores.
- [ ] Configurar deploy web en Railway.

### 1.2 Autenticación y Onboarding

- [ ] Pantalla de login (email + contraseña).
- [ ] Registro con email y contraseña.
- [ ] Registro / Login con cuenta de Google.
- [ ] Flujo de onboarding para nuevos usuarios (asignación de proyecto y rol posterior).
- [ ] Recuperación de contraseña.
- [ ] Persistencia de sesión.

### 1.3 Gestión de Usuarios y Roles

- [ ] Modelo de datos de Usuario en Firestore.
- [ ] CRUD de usuarios (Root).
- [ ] Asignación de roles: Root, Supervisor, Usuario, Soporte.
- [ ] Asignación de usuarios a proyectos.
- [ ] Permisos diferenciados por rol.
- [ ] Listado y búsqueda de usuarios.

### 1.4 Gestión de Proyectos

- [ ] Modelo de datos de Proyecto en Firestore.
- [ ] CRUD de proyectos (Root / Soporte limitado).
- [ ] Dashboard de proyecto con progreso general.
- [ ] Asignación de módulos a proyectos.
- [ ] Asignación de equipos a proyectos.

### 1.5 Gestión de Módulos

- [ ] Modelo de datos de Módulo en Firestore.
- [ ] CRUD de módulos dentro de un proyecto.
- [ ] Funcionalidades dentro de cada módulo.
- [ ] Estado y progreso de módulos.

### 1.6 Gestión de Incidentes / Tickets

- [ ] Modelo de datos de Ticket en Firestore.
- [ ] Creación de tickets (todos los roles según permisos).
- [ ] Asignación de tickets a usuarios de Soporte.
- [ ] Estados de ticket (abierto, en progreso, resuelto, cerrado, etc.).
- [ ] Prioridades de tickets.
- [ ] Historial de cambios / comentarios en tickets.
- [ ] Filtros y búsqueda de tickets.
- [ ] Vista de tickets por proyecto, módulo, usuario.

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

*Última actualización: 8 de marzo de 2026*
