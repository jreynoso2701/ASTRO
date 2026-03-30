/**
 * ASTRO — Cloud Functions para notificaciones push.
 *
 * Triggers de Firestore que:
 * 1. Determinan los destinatarios según rol y NotificationConfig.
 * 2. Envían push notifications vía FCM.
 * 3. Crean entradas en la bandeja in-app (Notificaciones).
 */

import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {auth} from "firebase-functions/v1";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {getAuth} from "firebase-admin/auth";

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// ── Tipos ────────────────────────────────────────────────

interface NotificationConfig {
  projectId: string;
  userId: string;
  pushEnabled: boolean;
  recibirTickets: boolean;
  scopeTickets: "participante" | "proyecto" | "todos";
  recibirRequerimientos: boolean;
  scopeRequerimientos: "participante" | "proyecto" | "todos";
  recibirTareas: boolean;
  scopeTareas: "participante" | "proyecto" | "todos";
  recibirCitas: boolean;
  scopeCitas: "participante" | "proyecto" | "todos";
}

type UserRole = "Root" | "Supervisor" | "Soporte" | "Usuario";

function defaultScope(role: UserRole): "participante" | "proyecto" | "todos" {
  switch (role) {
  case "Root": return "todos";
  case "Supervisor": return "proyecto";
  case "Soporte": return "proyecto";
  case "Usuario": return "participante";
  }
}

// ── Helpers ──────────────────────────────────────────────

/**
 * Obtiene las asignaciones activas de un proyecto.
 */
async function getProjectAssignments(projectId: string) {
  const snap = await db
    .collection("projectAssignments")
    .where("projectId", "==", projectId)
    .where("isActive", "==", true)
    .get();
  return snap.docs.map((d) => ({
    userId: d.data().userId as string,
    role: d.data().role as UserRole,
  }));
}

/**
 * Obtiene la config de notificaciones de un usuario para un proyecto.
 * Si no hay override, retorna defaults según rol.
 */
async function getNotifConfig(
  projectId: string,
  userId: string,
  role: UserRole
): Promise<NotificationConfig> {
  const docId = `${projectId}_${userId}`;
  const doc = await db.collection("NotificationConfig").doc(docId).get();
  if (doc.exists) {
    return doc.data() as NotificationConfig;
  }
  const scope = defaultScope(role);
  return {
    projectId,
    userId,
    pushEnabled: true,
    recibirTickets: true,
    scopeTickets: scope,
    recibirRequerimientos: true,
    scopeRequerimientos: scope,
    recibirTareas: true,
    scopeTareas: scope,
    recibirCitas: true,
    scopeCitas: scope,
  };
}

/**
 * Obtiene los FCM tokens de un usuario.
 * Retorna vacío si el usuario tiene pushGlobalEnabled=false.
 */
async function getFcmTokens(userId: string): Promise<string[]> {
  const doc = await db.collection("users").doc(userId).get();
  if (!doc.exists) return [];
  const data = doc.data()!;
  if (data.pushGlobalEnabled === false) return [];
  return (data.fcmTokens as string[]) ?? [];
}

/**
 * Parsea un valor de Firestore (Timestamp, ISO string, "año/mes/día") a Date.
 * Retorna null si no se puede parsear.
 */
function parseDate(raw: unknown): Date | null {
  if (!raw) return null;
  if (typeof (raw as {toDate?: () => Date}).toDate === "function") {
    return (raw as {toDate: () => Date}).toDate();
  }
  if (typeof raw === "string" && raw.length > 0) {
    // ISO directo
    const iso = new Date(raw);
    if (!isNaN(iso.getTime()) && raw.includes("-")) return iso;
    // Formato "año/mes/día" o "año/mes/día hora:min"
    const dateTimeParts = raw.split(" ");
    const parts = dateTimeParts[0].split("/");
    if (parts.length === 3) {
      const y = parseInt(parts[0], 10);
      const m = parseInt(parts[1], 10);
      const d = parseInt(parts[2], 10);
      if (!isNaN(y) && !isNaN(m) && !isNaN(d)) return new Date(y, m - 1, d);
    }
  }
  return null;
}

/**
 * Obtiene el offset en milisegundos de America/Mexico_City para una fecha dada.
 * Devuelve el valor para restar a una hora local CDMX y obtener UTC.
 * Ejemplo: CDMX es UTC-6 → retorna -6*3600*1000 = -21600000.
 * En horario de verano (DST) → UTC-5 → retorna -18000000.
 *
 * Nota: México eliminó el horario de verano en 2022 (excepto franja fronteriza).
 * CDMX es fija en UTC-6. Se mantiene el cálculo dinámico por robustez.
 */
function getCdmxOffsetMs(date: Date): number {
  // Usar Intl para obtener el offset real de CDMX en la fecha dada
  const utcStr = date.toLocaleString("en-US", {timeZone: "UTC"});
  const cdmxStr = date.toLocaleString("en-US", {timeZone: "America/Mexico_City"});
  const utcDate = new Date(utcStr);
  const cdmxDate = new Date(cdmxStr);
  return cdmxDate.getTime() - utcDate.getTime();
}

/**
 * Determina los destinatarios de una notificación de tickets.
 *
 * @param projectId - ID del proyecto.
 * @param participantUids - UIDs directamente involucrados (creador, asignado).
 * @param excludeUid - UID del actor que generó el evento (no notificarse a sí mismo).
 */
async function getTicketRecipients(
  projectId: string,
  participantUids: string[],
  excludeUid?: string
): Promise<string[]> {
  const assignments = await getProjectAssignments(projectId);
  const recipients = new Set<string>();

  for (const a of assignments) {
    if (a.userId === excludeUid) continue;

    const config = await getNotifConfig(projectId, a.userId, a.role);
    if (!config.pushEnabled || !config.recibirTickets) continue;

    switch (config.scopeTickets) {
    case "todos":
      // Recibe todas las notificaciones.
      recipients.add(a.userId);
      break;
    case "proyecto":
      // Recibe todas las del proyecto.
      recipients.add(a.userId);
      break;
    case "participante":
      // Solo si es participante directo.
      if (participantUids.includes(a.userId)) {
        recipients.add(a.userId);
      }
      break;
    }
  }

  // Root global (isRoot=true) que no están en el proyecto:
  // ya cubiertos por sus assignments con scope=todos.

  return Array.from(recipients);
}

/**
 * Determina los destinatarios de una notificación de requerimientos.
 */
async function getReqRecipients(
  projectId: string,
  participantUids: string[],
  excludeUid?: string
): Promise<string[]> {
  const assignments = await getProjectAssignments(projectId);
  const recipients = new Set<string>();

  for (const a of assignments) {
    if (a.userId === excludeUid) continue;

    const config = await getNotifConfig(projectId, a.userId, a.role);
    if (!config.pushEnabled || !config.recibirRequerimientos) continue;

    switch (config.scopeRequerimientos) {
    case "todos":
      recipients.add(a.userId);
      break;
    case "proyecto":
      recipients.add(a.userId);
      break;
    case "participante":
      if (participantUids.includes(a.userId)) {
        recipients.add(a.userId);
      }
      break;
    }
  }

  return Array.from(recipients);
}

/**
 * Envía push y crea notificación in-app para cada destinatario.
 */
async function sendNotifications(
  recipientUids: string[],
  payload: {
    titulo: string;
    cuerpo: string;
    tipo: string;
    refType: "ticket" | "requerimiento" | "cita" | "minuta" | "tarea" | "proyecto" | "user";
    refId: string;
    projectId: string;
    projectName: string;
  }
) {
  const promises: Promise<void>[] = [];

  for (const uid of recipientUids) {
    promises.push(
      (async () => {
        // 1. Crear notificación in-app
        await db.collection("Notificaciones").add({
          userId: uid,
          titulo: payload.titulo,
          cuerpo: payload.cuerpo,
          tipo: payload.tipo,
          refType: payload.refType,
          refId: payload.refId,
          projectId: payload.projectId,
          projectName: payload.projectName,
          leida: false,
          createdAt: FieldValue.serverTimestamp(),
        });

        // 2. Enviar push notification
        const tokens = await getFcmTokens(uid);
        if (tokens.length === 0) return;

        const response = await messaging.sendEachForMulticast({
          tokens,
          notification: {
            title: payload.titulo,
            body: payload.cuerpo,
          },
          data: {
            tipo: payload.tipo,
            refType: payload.refType,
            refId: payload.refId,
            projectId: payload.projectId,
          },
          android: {
            priority: "high",
            notification: {channelId: "astro_default"},
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                sound: "default",
                "content-available": 1,
              },
            },
          },
        });

        // Limpiar tokens inválidos
        const tokensToRemove: string[] = [];
        response.responses.forEach((resp, i) => {
          if (!resp.success) {
            const code = resp.error?.code;
            if (
              code === "messaging/invalid-registration-token" ||
              code === "messaging/registration-token-not-registered"
            ) {
              tokensToRemove.push(tokens[i]);
            }
          }
        });
        if (tokensToRemove.length > 0) {
          await db
            .collection("users")
            .doc(uid)
            .update({
              fcmTokens: FieldValue.arrayRemove(tokensToRemove),
            });
        }
      })()
    );
  }

  await Promise.all(promises);
}

// ── Triggers: TICKETS ────────────────────────────────────

/**
 * Ticket creado → notificar a todos los destinatarios elegibles.
 */
export const onTicketCreated = onDocumentCreated(
  "Incidentes/{ticketId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const projectId = data.projectId as string | undefined;
    const projectName = data.projectName as string ?? "";
    const createdBy = data.createdBy as string | undefined;
    const titulo = data.tituloIncidente as string ?? data.titulo ?? "Nuevo ticket";
    const folio = data.folioIncidente as string ?? data.folio ?? "";

    if (!projectId) return;

    const participantUids = [createdBy].filter(Boolean) as string[];
    const recipients = await getTicketRecipients(
      projectId,
      participantUids,
      createdBy
    );

    await sendNotifications(recipients, {
      titulo: `Nuevo ticket: ${folio}`,
      cuerpo: titulo,
      tipo: "ticket_creado",
      refType: "ticket",
      refId: event.params.ticketId,
      projectId,
      projectName,
    });
  }
);

/**
 * Ticket actualizado → detectar cambios de status, asignación, prioridad.
 */
export const onTicketUpdated = onDocumentUpdated(
  "Incidentes/{ticketId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const projectId = after.projectId as string | undefined;
    if (!projectId) return;

    const projectName = after.projectName as string ?? "";
    const folio = after.folioIncidente as string ?? after.folio ?? "";
    const ticketId = event.params.ticketId;
    const createdBy = after.createdBy as string | undefined;
    const assignedTo = after.assignedTo as string | undefined;
    const participantUids = [createdBy, assignedTo].filter(Boolean) as string[];

    // Cambio de status
    if (before.status !== after.status) {
      const updatedBy = after.updatedBy as string | undefined;
      const recipients = await getTicketRecipients(
        projectId,
        participantUids,
        updatedBy
      );
      await sendNotifications(recipients, {
        titulo: `${folio} → ${after.status}`,
        cuerpo: `El estado del ticket cambió a "${after.status}"`,
        tipo: "ticket_status",
        refType: "ticket",
        refId: ticketId,
        projectId,
        projectName,
      });
    }

    // Cambio de asignación
    if (before.assignedTo !== after.assignedTo && after.assignedTo) {
      const updatedBy = after.updatedBy as string | undefined;
      const recipients = await getTicketRecipients(
        projectId,
        participantUids,
        updatedBy
      );
      await sendNotifications(recipients, {
        titulo: `${folio} asignado`,
        cuerpo: `Ticket asignado a ${after.assignedToName ?? "alguien"}`,
        tipo: "ticket_asignado",
        refType: "ticket",
        refId: ticketId,
        projectId,
        projectName,
      });
    }

    // Cambio de prioridad
    if (before.priority !== after.priority) {
      const updatedBy = after.updatedBy as string | undefined;
      const recipients = await getTicketRecipients(
        projectId,
        participantUids,
        updatedBy
      );
      await sendNotifications(recipients, {
        titulo: `${folio} — prioridad cambiada`,
        cuerpo: `Nueva prioridad: ${after.priority}`,
        tipo: "ticket_prioridad",
        refType: "ticket",
        refId: ticketId,
        projectId,
        projectName,
      });
    }

    // Cambio de fecha compromiso de solución
    const beforeFh = before.fhCompromisoSol;
    const afterFh = after.fhCompromisoSol;
    const beforeFhStr = beforeFh?.toMillis?.() ?? (typeof beforeFh === "string" ? beforeFh : null);
    const afterFhStr = afterFh?.toMillis?.() ?? (typeof afterFh === "string" ? afterFh : null);
    if (beforeFhStr !== afterFhStr && afterFhStr !== null) {
      const updatedBy = after.updatedBy as string | undefined;
      let updatedByName = "Alguien";
      if (updatedBy) {
        const userDoc = await db.collection("users").doc(updatedBy).get();
        if (userDoc.exists) {
          const ud = userDoc.data()!;
          updatedByName = (ud.displayName as string) ??
            (ud.nombre as string) ?? "Alguien";
        }
      }

      // Formatear la fecha para el mensaje
      let fechaStr = "";
      if (afterFh?.toDate) {
        const d = afterFh.toDate() as Date;
        fechaStr = `${d.getDate().toString().padStart(2, "0")}/${(d.getMonth() + 1).toString().padStart(2, "0")}/${d.getFullYear()}`;
      } else if (typeof afterFh === "string") {
        fechaStr = afterFh;
      }

      const assignments = await getProjectAssignments(projectId);
      const rootUids = assignments
        .filter((a) => a.role === "Root" && a.userId !== updatedBy)
        .map((a) => a.userId);

      if (rootUids.length > 0) {
        const esNueva = beforeFhStr === null;
        const accion = esNueva ? "estableció" : "modificó";
        await sendNotifications(rootUids, {
          titulo: `📅 ${folio} — fecha compromiso`,
          cuerpo: `${updatedByName} ${accion} la fecha compromiso al ${fechaStr}.`,
          tipo: "ticket_fecha_compromiso",
          refType: "ticket",
          refId: ticketId,
          projectId,
          projectName,
        });
      }
    }
  }
);

/**
 * Comentario de ticket creado → notificar participantes.
 */
export const onTicketCommentCreated = onDocumentCreated(
  "Comentarios/{commentId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const ticketId = data.refIncidente as string | undefined;
    if (!ticketId) return;

    const authorId = data.authorId as string ?? data.userId as string | undefined;
    const authorName = data.authorName as string ?? data.userName as string ?? "Alguien";

    // Si es un system comment (statusChange, etc.) no duplicar notificación
    const commentType = data.type as string | undefined;
    if (commentType && commentType !== "comment") return;

    // Obtener datos del ticket padre
    const ticketDoc = await db.collection("Incidentes").doc(ticketId).get();
    if (!ticketDoc.exists) return;
    const ticket = ticketDoc.data()!;
    const projectId = ticket.projectId as string | undefined;
    if (!projectId) return;

    const projectName = ticket.projectName as string ?? "";
    const folio = ticket.folioIncidente as string ?? ticket.folio ?? "";
    const createdBy = ticket.createdBy as string | undefined;
    const assignedTo = ticket.assignedTo as string | undefined;
    const participantUids = [createdBy, assignedTo].filter(Boolean) as string[];

    const recipients = await getTicketRecipients(
      projectId,
      participantUids,
      authorId
    );

    const commentText = data.comentario as string ?? data.text as string ?? "";
    const preview = commentText.length > 80
      ? commentText.substring(0, 80) + "..."
      : commentText;

    await sendNotifications(recipients, {
      titulo: `Comentario en ${folio}`,
      cuerpo: `${authorName}: ${preview}`,
      tipo: "ticket_comentario",
      refType: "ticket",
      refId: ticketId,
      projectId,
      projectName,
    });
  }
);

// ── Triggers: REQUERIMIENTOS ─────────────────────────────

/**
 * Requerimiento creado → notificar.
 */
export const onReqCreated = onDocumentCreated(
  "Requerimientos/{reqId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const projectId = data.projectId as string | undefined;
    const projectName = data.projectName as string ?? "";
    const createdBy = data.createdBy as string | undefined;
    const titulo = data.titulo as string ?? "Nuevo requerimiento";
    const folio = data.folio as string ?? "";

    if (!projectId) return;

    const participantes = (data.participantes as Array<{uid: string}>) ?? [];
    const participantUids = [
      createdBy,
      data.assignedTo as string | undefined,
      ...participantes.map((p) => p.uid),
    ].filter(Boolean) as string[];

    const recipients = await getReqRecipients(
      projectId,
      participantUids,
      createdBy
    );

    await sendNotifications(recipients, {
      titulo: `Nuevo requerimiento: ${folio}`,
      cuerpo: titulo,
      tipo: "req_creado",
      refType: "requerimiento",
      refId: event.params.reqId,
      projectId,
      projectName,
    });
  }
);

/**
 * Requerimiento actualizado → detectar cambios de status, asignación, fase.
 */
export const onReqUpdated = onDocumentUpdated(
  "Requerimientos/{reqId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const projectId = after.projectId as string | undefined;
    if (!projectId) return;

    const projectName = after.projectName as string ?? "";
    const folio = after.folio as string ?? "";
    const reqId = event.params.reqId;
    const createdBy = after.createdBy as string | undefined;
    const assignedTo = after.assignedTo as string | undefined;
    const participantes = (after.participantes as Array<{uid: string}>) ?? [];
    const participantUids = [
      createdBy,
      assignedTo,
      ...participantes.map((p: {uid: string}) => p.uid),
    ].filter(Boolean) as string[];

    // Cambio de status
    if (before.status !== after.status) {
      const updatedBy = after.updatedBy as string | undefined;
      const recipients = await getReqRecipients(
        projectId,
        participantUids,
        updatedBy
      );
      await sendNotifications(recipients, {
        titulo: `${folio} → ${after.status}`,
        cuerpo: `El estado del requerimiento cambió a "${after.status}"`,
        tipo: "req_status",
        refType: "requerimiento",
        refId: reqId,
        projectId,
        projectName,
      });
    }

    // Cambio de asignación
    if (before.assignedTo !== after.assignedTo && after.assignedTo) {
      const updatedBy = after.updatedBy as string | undefined;
      const recipients = await getReqRecipients(
        projectId,
        participantUids,
        updatedBy
      );
      await sendNotifications(recipients, {
        titulo: `${folio} asignado`,
        cuerpo: `Requerimiento asignado a ${after.assignedToName ?? "alguien"}`,
        tipo: "req_asignado",
        refType: "requerimiento",
        refId: reqId,
        projectId,
        projectName,
      });
    }

    // Cambio de fase
    if (before.faseAsignada !== after.faseAsignada && after.faseAsignada) {
      const updatedBy = after.updatedBy as string | undefined;
      const recipients = await getReqRecipients(
        projectId,
        participantUids,
        updatedBy
      );
      await sendNotifications(recipients, {
        titulo: `${folio} — fase asignada`,
        cuerpo: `Fase: ${after.faseAsignada}`,
        tipo: "req_fase",
        refType: "requerimiento",
        refId: reqId,
        projectId,
        projectName,
      });
    }

    // Cambio de prioridad
    if (before.prioridad !== after.prioridad && after.prioridad) {
      const updatedBy = after.updatedBy as string | undefined;
      const recipients = await getReqRecipients(
        projectId,
        participantUids,
        updatedBy
      );
      await sendNotifications(recipients, {
        titulo: `${folio} — prioridad cambiada`,
        cuerpo: `Nueva prioridad: ${after.prioridad}`,
        tipo: "req_prioridad",
        refType: "requerimiento",
        refId: reqId,
        projectId,
        projectName,
      });
    }

    // Cambio de fecha compromiso
    const beforeFecha = before.fechaCompromiso?.toMillis?.() ?? null;
    const afterFecha = after.fechaCompromiso?.toMillis?.() ?? null;
    if (beforeFecha !== afterFecha && afterFecha !== null) {
      const updatedBy = after.updatedBy as string | undefined;
      let updatedByName = "Alguien";
      if (updatedBy) {
        const userDoc = await db.collection("users").doc(updatedBy).get();
        if (userDoc.exists) {
          const ud = userDoc.data()!;
          updatedByName = (ud.displayName as string) ??
            (ud.nombre as string) ?? "Alguien";
        }
      }

      const fechaDate = after.fechaCompromiso.toDate() as Date;
      const fechaStr = `${fechaDate.getDate().toString().padStart(2, "0")}/${(fechaDate.getMonth() + 1).toString().padStart(2, "0")}/${fechaDate.getFullYear()}`;

      const assignments = await getProjectAssignments(projectId);
      const rootUids = assignments
        .filter((a) => a.role === "Root" && a.userId !== updatedBy)
        .map((a) => a.userId);

      if (rootUids.length > 0) {
        const esNueva = beforeFecha === null;
        const accion = esNueva ? "estableció" : "modificó";
        await sendNotifications(rootUids, {
          titulo: `📅 ${folio} — fecha compromiso`,
          cuerpo: `${updatedByName} ${accion} la fecha compromiso al ${fechaStr}.`,
          tipo: "req_fecha_compromiso",
          refType: "requerimiento",
          refId: reqId,
          projectId,
          projectName,
        });
      }
    }
  }
);

/**
 * Comentario de requerimiento creado → notificar participantes.
 */
export const onReqCommentCreated = onDocumentCreated(
  "ComentariosRequerimientos/{commentId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const reqId = data.refRequerimiento as string | undefined;
    if (!reqId) return;

    const authorId = data.authorId as string | undefined;
    const authorName = data.authorName as string ?? "Alguien";

    // No duplicar notificación para system comments
    const commentType = data.type as string | undefined;
    if (commentType && commentType !== "comment") return;

    // Obtener datos del requerimiento padre
    const reqDoc = await db.collection("Requerimientos").doc(reqId).get();
    if (!reqDoc.exists) return;
    const req = reqDoc.data()!;
    const projectId = req.projectId as string | undefined;
    if (!projectId) return;

    const projectName = req.projectName as string ?? "";
    const folio = req.folio as string ?? "";
    const createdBy = req.createdBy as string | undefined;
    const assignedTo = req.assignedTo as string | undefined;
    const participantes = (req.participantes as Array<{uid: string}>) ?? [];
    const participantUids = [
      createdBy,
      assignedTo,
      ...participantes.map((p: {uid: string}) => p.uid),
    ].filter(Boolean) as string[];

    const recipients = await getReqRecipients(
      projectId,
      participantUids,
      authorId
    );

    const text = data.text as string ?? "";
    const preview = text.length > 80 ? text.substring(0, 80) + "..." : text;

    await sendNotifications(recipients, {
      titulo: `Comentario en ${folio}`,
      cuerpo: `${authorName}: ${preview}`,
      tipo: "req_comentario",
      refType: "requerimiento",
      refId: reqId,
      projectId,
      projectName,
    });
  }
);

// ── Triggers: CITAS ──────────────────────────────────────

/**
 * Cita creada → notificar a los participantes y destinatarios elegibles.
 */
export const onCitaCreated = onDocumentCreated(
  "Citas/{citaId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const projectId = data.projectId as string | undefined;
    const projectName = data.projectName as string ?? "";
    const createdBy = data.createdBy as string | undefined;
    const titulo = data.titulo as string ?? "Nueva cita";
    const folio = data.folio as string ?? "";

    if (!projectId) return;

    const participantUids = (data.participantUids as string[]) ?? [];
    const recipients = await getCitaRecipients(
      projectId,
      participantUids,
      createdBy
    );

    await sendNotifications(recipients, {
      titulo: `Nueva cita: ${folio}`,
      cuerpo: titulo,
      tipo: "cita_creada",
      refType: "cita",
      refId: event.params.citaId,
      projectId,
      projectName,
    });
  }
);

/**
 * Cita actualizada → detectar cambios de status, fecha, cancelación.
 */
export const onCitaUpdated = onDocumentUpdated(
  "Citas/{citaId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const projectId = after.projectId as string | undefined;
    if (!projectId) return;

    const projectName = after.projectName as string ?? "";
    const folio = after.folio as string ?? "";
    const citaId = event.params.citaId;
    const participantUids = (after.participantUids as string[]) ?? [];
    const updatedBy = after.updatedBy as string | undefined;

    // Cambio de status
    if (before.status !== after.status) {
      const newStatus = after.status as string ?? "";
      const isCancelled = newStatus.toLowerCase() === "cancelada";
      const isCompleted = newStatus.toLowerCase() === "completada";

      const recipients = await getCitaRecipients(
        projectId,
        participantUids,
        updatedBy
      );

      if (isCancelled) {
        await sendNotifications(recipients, {
          titulo: `${folio} cancelada`,
          cuerpo: `La cita "${after.titulo ?? ""}" ha sido cancelada`,
          tipo: "cita_cancelada",
          refType: "cita",
          refId: citaId,
          projectId,
          projectName,
        });
      } else if (isCompleted) {
        await sendNotifications(recipients, {
          titulo: `${folio} completada`,
          cuerpo: `La cita "${after.titulo ?? ""}" ha sido completada`,
          tipo: "cita_completada",
          refType: "cita",
          refId: citaId,
          projectId,
          projectName,
        });
      } else {
        await sendNotifications(recipients, {
          titulo: `${folio} → ${newStatus}`,
          cuerpo: `El estado de la cita cambió a "${newStatus}"`,
          tipo: "cita_actualizada",
          refType: "cita",
          refId: citaId,
          projectId,
          projectName,
        });
      }
    }

    // Cambio de fecha u hora
    const fechaChanged = JSON.stringify(before.fecha) !== JSON.stringify(after.fecha);
    const horaChanged = before.horaInicio !== after.horaInicio || before.horaFin !== after.horaFin;

    if ((fechaChanged || horaChanged) && before.status === after.status) {
      const recipients = await getCitaRecipients(
        projectId,
        participantUids,
        updatedBy
      );
      await sendNotifications(recipients, {
        titulo: `${folio} — horario actualizado`,
        cuerpo: `La cita "${after.titulo ?? ""}" cambió de fecha/hora`,
        tipo: "cita_actualizada",
        refType: "cita",
        refId: citaId,
        projectId,
        projectName,
      });
    }
  }
);

// ── Trigger: MÓDULOS — Progreso actualizado ──────────────

/**
 * Cuando se actualiza un módulo y su porcentaje de progreso cambia,
 * notifica a los usuarios Root del proyecto.
 */
export const onModuloUpdated = onDocumentUpdated(
  "Modulos/{moduloId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // Solo disparar si cambió porcentCompletaModulo
    const oldPercent = (before.porcentCompletaModulo as number) ?? 0;
    const newPercent = (after.porcentCompletaModulo as number) ?? 0;
    if (oldPercent === newPercent) return;

    const projectId = after.projectId as string | undefined;
    const projectName = (after.fkProyecto as string) ?? "";
    const moduleName = (after.nombreModulo as string) ?? "Módulo";
    const updatedBy = after.updatedBy as string | undefined;

    if (!projectId) return;

    // Buscar el nombre de quien actualizó
    let updatedByName = "Alguien";
    if (updatedBy) {
      const userDoc = await db.collection("users").doc(updatedBy).get();
      if (userDoc.exists) {
        const userData = userDoc.data()!;
        updatedByName = (userData.displayName as string) ??
          (userData.nombre as string) ?? "Alguien";
      }
    }

    // Obtener los Root y Soporte del proyecto
    const assignments = await getProjectAssignments(projectId);
    const recipientUids: string[] = [];
    for (const a of assignments) {
      if ((a.role === "Root" || a.role === "Soporte") && a.userId !== updatedBy) {
        recipientUids.push(a.userId);
      }
    }

    if (recipientUids.length === 0) return;

    const roundedPercent = Math.round(newPercent);

    await sendNotifications(recipientUids, {
      titulo: `📊 ${moduleName} — ${roundedPercent}%`,
      cuerpo: `${updatedByName} actualizó el progreso del módulo "${moduleName}" a ${roundedPercent}% en ${projectName}.`,
      tipo: "modulo_progreso_actualizado",
      refType: "proyecto",
      refId: projectId,
      projectId,
      projectName,
    });
  }
);

// ── Scheduled: RECORDATORIO DE CITAS ─────────────────────

/**
 * Cada 15 minutos revisa las citas programadas próximas.
 * Si una cita tiene un recordatorio que cae dentro de la ventana actual
 * (±7.5 min de algún valor de recordatorios[]), envía push + notificación in-app
 * a los participantes.
 *
 * Ejemplo: cita a las 15:00, recordatorios: [15, 60].
 *  - A las 14:45 (15 min antes) → se envía recordatorio de 15 min.
 *  - A las 14:00 (60 min antes) → se envía recordatorio de 60 min.
 */
export const checkCitaReminders = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "America/Mexico_City",
  },
  async () => {
    const now = Date.now();
    const windowMs = 7.5 * 60 * 1000; // 7.5 minutos en ms

    // Consultar citas programadas activas (sin filtro de fecha para cubrir
    // tanto el campo "fecha" como "fechaHora" de citas legadas).
    const snap = await db
      .collection("Citas")
      .where("status", "==", "programada")
      .where("isActive", "==", true)
      .get();

    if (snap.empty) return;

    const promises: Promise<void>[] = [];

    for (const doc of snap.docs) {
      const data = doc.data();
      const citaId = doc.id;

      // Parsear fecha + horaInicio → timestamp exacto en CDMX
      const fechaRaw = data.fecha ?? data.fechaHora;
      if (!fechaRaw) continue;

      const citaDate = parseDate(fechaRaw);
      if (!citaDate) continue;

      const horaInicio = data.horaInicio as string | undefined;
      if (horaInicio) {
        const parts = horaInicio.split(":");
        if (parts.length >= 2) {
          citaDate.setHours(parseInt(parts[0], 10), parseInt(parts[1], 10), 0, 0);
        }
      }

      // horaInicio es hora local de México (CDMX).
      // Cloud Functions corre en UTC, así que setHours puso la hora como UTC.
      // Restamos el offset de CDMX para obtener la hora UTC real.
      // Ej: 09:00 CDMX (UTC-6) → setHours puso 09:00 UTC →
      //     restamos -6h = 09:00 - (-6h) = 15:00 UTC ✓
      const cdmxOffset = getCdmxOffsetMs(citaDate);
      const citaTimestamp = citaDate.getTime() - cdmxOffset;
      // Solo citas futuras
      if (citaTimestamp <= now) continue;

      const recordatorios = (data.recordatorios as number[]) ?? [15, 60];
      const participantUids = (data.participantUids as string[]) ?? [];
      if (participantUids.length === 0) continue;

      const projectId = data.projectId as string ?? "";
      const projectName = data.projectName as string ?? "";
      const titulo = data.titulo as string ?? "Cita";

      for (const minAntes of recordatorios) {
        const reminderTime = citaTimestamp - minAntes * 60 * 1000;
        const diff = Math.abs(reminderTime - now);

        // Si el recordatorio cae dentro de la ventana actual (±7.5 min)
        if (diff <= windowMs) {
          let label: string;
          if (minAntes < 60) {
            label = `${minAntes} min`;
          } else {
            const h = Math.floor(minAntes / 60);
            const m = minAntes % 60;
            label = m > 0 ? `${h}h ${m}min` : `${h}h`;
          }

          promises.push(
            sendNotifications(participantUids, {
              titulo: `Recordatorio: ${titulo}`,
              cuerpo: `En ${label} — ${projectName}`,
              tipo: "cita_recordatorio",
              refType: "cita",
              refId: citaId,
              projectId,
              projectName,
            })
          );
        }
      }
    }

    await Promise.all(promises);
  }
);

// ── Scheduled: SEMÁFORO DE DEADLINE DE TICKETS ───────────

/**
 * Cada día a las 08:00 (América/México_City) revisa todos los tickets activos
 * que tienen `fhCompromisoSol` (fecha de solución programada).
 *
 * Envía notificaciones a los usuarios ROOT del proyecto cuando:
 *  - 🟡 Ámbar: faltan entre 2 y 5 días para el vencimiento.
 *  - 🟠 Naranja: vence hoy o mañana (0‑1 días).
 *  - 🔴 Rojo: ya venció (overdue).
 *
 * Para evitar spam, se usa un campo `_lastDeadlineAlert` en el ticket
 * que almacena la última "zona" alertada ("amber" | "orange" | "red").
 * Solo se notifica cuando el ticket entra a una **nueva** zona.
 */
export const checkTicketDeadlines = onSchedule(
  {
    schedule: "every day 08:00",
    timeZone: "America/Mexico_City",
  },
  async () => {
    // Obtener todos los tickets activos con fecha de solución programada.
    const snap = await db
      .collection("Incidentes")
      .where("isActive", "==", true)
      .get();

    if (snap.empty) return;

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const promises: Promise<void>[] = [];

    for (const doc of snap.docs) {
      const data = doc.data();
      const ticketId = doc.id;

      // Solo tickets con fecha de solución programada
      const fhRaw = data.fhCompromisoSol;
      if (!fhRaw) continue;

      // Parsear fecha — soporta: Timestamp, ISO, "año/mes/día", "año/mes/día hora:min"
      let target: Date | null = null;
      if (fhRaw.toDate) {
        target = fhRaw.toDate();
      } else if (typeof fhRaw === "string" && fhRaw.length > 0) {
        // Intentar ISO directo
        const iso = new Date(fhRaw);
        if (!isNaN(iso.getTime()) && fhRaw.includes("-")) {
          target = iso;
        } else {
          // Formato "año/mes/día" o "año/mes/día hora:min"
          const dateTimeParts = fhRaw.split(" ");
          const parts = dateTimeParts[0].split("/");
          if (parts.length === 3) {
            const y = parseInt(parts[0], 10);
            const m = parseInt(parts[1], 10);
            const d = parseInt(parts[2], 10);
            if (!isNaN(y) && !isNaN(m) && !isNaN(d)) {
              target = new Date(y, m - 1, d);
            }
          }
        }
      }

      if (!target) continue;

      const deadline = new Date(target.getFullYear(), target.getMonth(), target.getDate());
      const diffMs = deadline.getTime() - today.getTime();
      const days = Math.round(diffMs / (1000 * 60 * 60 * 24));

      // Determinar zona del semáforo
      let zone: "amber" | "orange" | "red" | null = null;
      let emoji = "";
      let label = "";

      if (days < 0) {
        zone = "red";
        emoji = "🔴";
        label = `Vencido hace ${-days} día(s)`;
      } else if (days <= 1) {
        zone = "orange";
        emoji = "🟠";
        label = days === 0 ? "Vence HOY" : "Vence MAÑANA";
      } else if (days <= 5) {
        zone = "amber";
        emoji = "🟡";
        label = `Vence en ${days} días`;
      }

      // Si no cae en ninguna zona de alerta, no enviar nada
      if (!zone) continue;

      // Anti-spam: solo notificar si la zona cambió
      const lastAlert = data._lastDeadlineAlert as string | undefined;
      if (lastAlert === zone) continue;

      // Actualizar la zona alertada
      promises.push(
        db.collection("Incidentes").doc(ticketId).update({
          _lastDeadlineAlert: zone,
        }).then(() => {/* ok */})
      );

      const projectId = data.projectId as string | undefined;
      if (!projectId) continue;

      const projectName = data.projectName as string ?? "";
      const folio = data.folioIncidente as string ?? data.folio ?? "";
      const titulo = data.tituloIncidente as string ?? data.titulo ?? "";

      // Obtener solo usuarios Root del proyecto
      const assignments = await getProjectAssignments(projectId);
      const rootUids = assignments
        .filter((a) => a.role === "Root")
        .map((a) => a.userId);

      if (rootUids.length === 0) continue;

      promises.push(
        sendNotifications(rootUids, {
          titulo: `${emoji} ${folio} — ${label}`,
          cuerpo: titulo,
          tipo: `ticket_deadline_${zone}`,
          refType: "ticket",
          refId: ticketId,
          projectId,
          projectName,
        })
      );
    }

    await Promise.all(promises);
  }
);

// ── Callable: ANONIMIZAR Y ELIMINAR CUENTA ───────────────

/**
 * Helper interno que anonimiza todas las referencias de un usuario
 * en las colecciones de Firestore y luego elimina el documento del
 * usuario y su cuenta de Firebase Auth.
 *
 * Reemplaza displayName con "Usuario eliminado - [nombre original]"
 * y limpia datos personales. Los archivos/adjuntos se conservan
 * pues pertenecen al proyecto.
 */
async function performAnonymizeAndDelete(uid: string): Promise<{success: boolean; message: string}> {
    // Obtener datos del usuario antes de anonimizar
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "Usuario no encontrado.");
    }

    const userData = userDoc.data()!;
    const originalName = userData.displayName || userData.email || "Usuario";
    const anonymizedName = `Usuario eliminado - ${originalName}`;

    // Acumular operaciones para ejecutar en batches de 490
    type Op =
      | {type: "update"; ref: FirebaseFirestore.DocumentReference; data: Record<string, unknown>}
      | {type: "delete"; ref: FirebaseFirestore.DocumentReference};
    const ops: Op[] = [];

    // ─── 1. Incidentes: createdByName, assignedToName
    const incidentesCreated = await db
      .collection("Incidentes")
      .where("createdBy", "==", uid)
      .get();
    for (const doc of incidentesCreated.docs) {
      ops.push({type: "update", ref: doc.ref, data: {createdByName: anonymizedName}});
    }

    const incidentesAssigned = await db
      .collection("Incidentes")
      .where("assignedTo", "==", uid)
      .get();
    for (const doc of incidentesAssigned.docs) {
      ops.push({type: "update", ref: doc.ref, data: {assignedToName: anonymizedName}});
    }

    // ─── 2. Comentarios de Incidentes (subcollection)
    // Buscar en todos los incidentes (no solo los creados por este usuario)
    const allIncidentesSnap = await db.collection("Incidentes").get();
    for (const incDoc of allIncidentesSnap.docs) {
      const comentarios = await incDoc.ref
        .collection("Comentarios")
        .where("authorId", "==", uid)
        .get();
      for (const cDoc of comentarios.docs) {
        ops.push({type: "update", ref: cDoc.ref, data: {authorName: anonymizedName}});
      }
    }

    // ─── 3. Requerimientos: createdByName, assignedToName, participantes[]
    const reqCreated = await db
      .collection("Requerimientos")
      .where("createdBy", "==", uid)
      .get();
    for (const doc of reqCreated.docs) {
      ops.push({type: "update", ref: doc.ref, data: {createdByName: anonymizedName}});
    }

    const reqAssigned = await db
      .collection("Requerimientos")
      .where("assignedTo", "==", uid)
      .get();
    for (const doc of reqAssigned.docs) {
      ops.push({type: "update", ref: doc.ref, data: {assignedToName: anonymizedName}});
    }

    // Comentarios de Requerimientos
    const allReqSnap = await db.collection("Requerimientos").get();
    for (const rDoc of allReqSnap.docs) {
      const comentarios = await rDoc.ref
        .collection("ComentariosRequerimientos")
        .where("authorId", "==", uid)
        .get();
      for (const cDoc of comentarios.docs) {
        ops.push({type: "update", ref: cDoc.ref, data: {authorName: anonymizedName}});
      }
    }

    // Participantes y compromisos en Requerimientos (arrays dentro del doc)
    const allReqsWithParticipant = await db
      .collection("Requerimientos")
      .where("participantUids", "array-contains", uid)
      .get();
    for (const doc of allReqsWithParticipant.docs) {
      const data = doc.data();
      let updated = false;
      const participantes = (data.participantes || []).map(
        (p: {uid: string; nombre: string}) => {
          if (p.uid === uid) {
            updated = true;
            return {...p, nombre: anonymizedName};
          }
          return p;
        }
      );
      const compromisos = (data.compromisos || []).map(
        (c: {responsableUid: string; responsable: string}) => {
          if (c.responsableUid === uid) {
            updated = true;
            return {...c, responsable: anonymizedName};
          }
          return c;
        }
      );
      if (updated) {
        ops.push({type: "update", ref: doc.ref, data: {participantes, compromisos}});
      }
    }

    // ─── 4. Minutas: createdByName, participantes[], compromisos[]
    const minutasCreated = await db
      .collection("Minutas")
      .where("createdBy", "==", uid)
      .get();
    for (const doc of minutasCreated.docs) {
      ops.push({type: "update", ref: doc.ref, data: {createdByName: anonymizedName}});
    }

    const allMinutasWithParticipant = await db
      .collection("Minutas")
      .where("participantUids", "array-contains", uid)
      .get();
    for (const doc of allMinutasWithParticipant.docs) {
      const data = doc.data();
      let updated = false;
      const participantes = (data.participantes || []).map(
        (p: {uid: string; nombre: string}) => {
          if (p.uid === uid) {
            updated = true;
            return {...p, nombre: anonymizedName};
          }
          return p;
        }
      );
      const compromisos = (data.compromisos || []).map(
        (c: {responsableUid: string; responsable: string}) => {
          if (c.responsableUid === uid) {
            updated = true;
            return {...c, responsable: anonymizedName};
          }
          return c;
        }
      );
      if (updated) {
        ops.push({type: "update", ref: doc.ref, data: {participantes, compromisos}});
      }
    }

    // ─── 5. Citas: createdByName, participantes[]
    const citasCreated = await db
      .collection("Citas")
      .where("createdBy", "==", uid)
      .get();
    for (const doc of citasCreated.docs) {
      ops.push({type: "update", ref: doc.ref, data: {createdByName: anonymizedName}});
    }

    // Comentarios de Citas
    const allCitasSnap = await db.collection("Citas").get();
    for (const cDoc of allCitasSnap.docs) {
      const comentarios = await cDoc.ref
        .collection("ComentariosCitas")
        .where("authorId", "==", uid)
        .get();
      for (const comDoc of comentarios.docs) {
        ops.push({type: "update", ref: comDoc.ref, data: {authorName: anonymizedName}});
      }
    }

    const allCitasWithParticipant = await db
      .collection("Citas")
      .where("participantUids", "array-contains", uid)
      .get();
    for (const doc of allCitasWithParticipant.docs) {
      const data = doc.data();
      let updated = false;
      const participantes = (data.participantes || []).map(
        (p: {uid: string; nombre: string}) => {
          if (p.uid === uid) {
            updated = true;
            return {...p, nombre: anonymizedName};
          }
          return p;
        }
      );
      if (updated) {
        ops.push({type: "update", ref: doc.ref, data: {participantes}});
      }
    }

    // ─── 6. Tareas: createdByName, assignedToName
    const tareasCreated = await db
      .collection("Tareas")
      .where("createdByUid", "==", uid)
      .get();
    for (const doc of tareasCreated.docs) {
      ops.push({type: "update", ref: doc.ref, data: {createdByName: anonymizedName}});
    }

    const tareasAssigned = await db
      .collection("Tareas")
      .where("assignedToUid", "==", uid)
      .get();
    for (const doc of tareasAssigned.docs) {
      ops.push({type: "update", ref: doc.ref, data: {assignedToName: anonymizedName}});
    }

    // ─── 7. DocumentosProyecto: createdByName, versiones[]
    const docsCreated = await db
      .collection("DocumentosProyecto")
      .where("createdBy", "==", uid)
      .get();
    for (const doc of docsCreated.docs) {
      const data = doc.data();
      const versiones = (data.versiones || []).map(
        (v: {subidoPor: string; subidoPorNombre: string}) => {
          if (v.subidoPor === uid) {
            return {...v, subidoPorNombre: anonymizedName};
          }
          return v;
        }
      );
      ops.push({type: "update", ref: doc.ref, data: {createdByName: anonymizedName, versiones}});
    }

    // ─── 8. CategoriasDocumento: createdByName
    const catsCreated = await db
      .collection("CategoriasDocumento")
      .where("createdBy", "==", uid)
      .get();
    for (const doc of catsCreated.docs) {
      ops.push({type: "update", ref: doc.ref, data: {createdByName: anonymizedName}});
    }

    // ─── 9. Eliminar registros propios del usuario
    const collectionsToDelete = [
      {name: "Notificaciones", field: "userId"},
      {name: "NotificationConfig", field: "userId"},
      {name: "projectAssignments", field: "userId"},
      {name: "BitacoraDocumentos", field: "userId"},
      {name: "chatAI", field: "userId"},
    ];

    for (const col of collectionsToDelete) {
      const snap = await db
        .collection(col.name)
        .where(col.field, "==", uid)
        .get();
      for (const doc of snap.docs) {
        ops.push({type: "delete", ref: doc.ref});
      }
    }

    // ─── 10. Eliminar documento del usuario
    ops.push({type: "delete", ref: db.collection("users").doc(uid)});

    // Ejecutar operaciones en batches de 490
    const BATCH_SIZE = 490;
    for (let i = 0; i < ops.length; i += BATCH_SIZE) {
      const batch = db.batch();
      const chunk = ops.slice(i, i + BATCH_SIZE);
      for (const op of chunk) {
        if (op.type === "update") {
          batch.update(op.ref, op.data);
        } else {
          batch.delete(op.ref);
        }
      }
      await batch.commit();
    }

    // ─── 11. Eliminar cuenta de Firebase Auth
    const adminAuth = getAuth();
    await adminAuth.deleteUser(uid);

    return {success: true, message: "Cuenta eliminada y datos anonimizados."};
}

/**
 * Función invocable: el usuario elimina su PROPIA cuenta.
 * Anonimiza todas las referencias y elimina Auth + Firestore doc.
 */
export const anonymizeAndDeleteUser = onCall(
  {maxInstances: 10, timeoutSeconds: 120},
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "Se requiere autenticación.");
    }
    return performAnonymizeAndDelete(callerUid);
  }
);

/**
 * Función invocable: un Root elimina OTRA cuenta de usuario.
 * Verifica que el caller sea Root y que el target no sea Root.
 * Anonimiza todas las referencias y elimina Auth + Firestore doc.
 */
export const adminAnonymizeAndDeleteUser = onCall(
  {maxInstances: 10, timeoutSeconds: 120},
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "Se requiere autenticación.");
    }

    // Verificar que el caller es Root
    const callerDoc = await db.collection("users").doc(callerUid).get();
    if (!callerDoc.exists || callerDoc.data()?.isRoot !== true) {
      throw new HttpsError("permission-denied", "Solo usuarios Root pueden eliminar otras cuentas.");
    }

    const targetUid = request.data?.targetUid;
    if (!targetUid || typeof targetUid !== "string") {
      throw new HttpsError("invalid-argument", "Se requiere targetUid.");
    }

    // No permitir eliminar cuentas Root
    const targetDoc = await db.collection("users").doc(targetUid).get();
    if (!targetDoc.exists) {
      throw new HttpsError("not-found", "Usuario objetivo no encontrado.");
    }
    if (targetDoc.data()?.isRoot === true) {
      throw new HttpsError("permission-denied", "No se puede eliminar una cuenta Root.");
    }

    return performAnonymizeAndDelete(targetUid);
  }
);

// ── Trigger: NUEVO USUARIO REGISTRADO ────────────────────

/**
 * Se dispara cuando un usuario se registra en Firebase Auth.
 * 1. Crea el documento `users/{uid}` si no existe (respaldo del cliente).
 * 2. Notifica a todos los usuarios Root vía push + bandeja in-app.
 */
export const onNewUserCreated = auth.user().onCreate(
  async (userRecord) => {
    const uid = userRecord.uid;

    // 1. Crear documento de usuario si el cliente no lo creó aún.
    const userRef = db.collection("users").doc(uid);
    const existingDoc = await userRef.get();

    if (!existingDoc.exists) {
      await userRef.set({
        uid,
        displayName: userRecord.displayName || "",
        email: userRecord.email || "",
        photoUrl: userRecord.photoURL || null,
        isActive: true,
        isRoot: false,
        registrationStatus: "pending",
        fcmTokens: [],
        pushGlobalEnabled: true,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      // Si el documento ya existe (creado por el cliente), asegurar
      // que tenga registrationStatus: pending si no lo tiene.
      const data = existingDoc.data();
      if (!data?.registrationStatus) {
        await userRef.update({
          registrationStatus: "pending",
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }

    // 2. Notificar a todos los Root activos.
    const rootSnap = await db
      .collection("users")
      .where("isRoot", "==", true)
      .where("isActive", "==", true)
      .get();

    if (rootSnap.empty) return;

    const displayName =
      userRecord.displayName || userRecord.email || "Nuevo usuario";

    const recipientUids = rootSnap.docs
      .map((doc) => doc.id)
      .filter((id) => id !== uid);

    if (recipientUids.length === 0) return;

    await sendNotifications(recipientUids, {
      titulo: "📋 Nueva solicitud de registro",
      cuerpo: `${displayName} solicita acceso a ASTRO. Revisa las solicitudes pendientes.`,
      tipo: "solicitud_registro",
      refType: "user",
      refId: uid,
      projectId: "",
      projectName: "",
    });
  }
);

// ── Trigger: CAMBIO DE ESTADO DE REGISTRO DE USUARIO ─────

/**
 * Se dispara cuando se actualiza un documento en `users/{uid}`.
 * Detecta cambios en `registrationStatus` y envía notificaciones:
 * - approved → push al usuario aprobado + notifica a otros Root.
 * - rejected → push al usuario rechazado + notifica a otros Root.
 */
export const onUserStatusChanged = onDocumentUpdated(
  "users/{uid}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const oldStatus = before.registrationStatus;
    const newStatus = after.registrationStatus;

    // Solo actuar si el status cambió desde "pending"
    if (oldStatus !== "pending" || oldStatus === newStatus) return;

    const uid = event.params.uid;
    const displayName = after.displayName || after.email || "Usuario";

    if (newStatus === "approved") {
      // Notificar al usuario aprobado
      await sendNotifications([uid], {
        titulo: "🎉 ¡Bienvenido a ASTRO!",
        cuerpo: "Tu solicitud ha sido aprobada. Ya puedes acceder a la plataforma.",
        tipo: "registro_aprobado",
        refType: "user",
        refId: uid,
        projectId: "",
        projectName: "",
      });

      // Notificar a otros Root
      const rootSnap = await db
        .collection("users")
        .where("isRoot", "==", true)
        .where("isActive", "==", true)
        .get();

      const approvedByUid = after.approvedBy || "";
      const otherRoots = rootSnap.docs
        .map((doc) => doc.id)
        .filter((id) => id !== uid && id !== approvedByUid);

      if (otherRoots.length > 0) {
        await sendNotifications(otherRoots, {
          titulo: "✅ Solicitud aprobada",
          cuerpo: `${displayName} fue aprobado por un administrador.`,
          tipo: "registro_aprobado_admin",
          refType: "user",
          refId: uid,
          projectId: "",
          projectName: "",
        });
      }
    } else if (newStatus === "rejected") {
      const reason = after.rejectionReason || "No se proporcionó motivo.";

      // Notificar al usuario rechazado
      await sendNotifications([uid], {
        titulo: "Solicitud no aprobada",
        cuerpo: `Tu solicitud fue revisada. Motivo: ${reason}`,
        tipo: "registro_rechazado",
        refType: "user",
        refId: uid,
        projectId: "",
        projectName: "",
      });

      // Notificar a otros Root
      const rootSnap = await db
        .collection("users")
        .where("isRoot", "==", true)
        .where("isActive", "==", true)
        .get();

      const otherRoots = rootSnap.docs
        .map((doc) => doc.id)
        .filter((id) => id !== uid);

      if (otherRoots.length > 0) {
        await sendNotifications(otherRoots, {
          titulo: "❌ Solicitud rechazada",
          cuerpo: `La solicitud de ${displayName} fue rechazada.`,
          tipo: "registro_rechazado_admin",
          refType: "user",
          refId: uid,
          projectId: "",
          projectName: "",
        });
      }
    }
  }
);

// ── Scheduled: SOLICITUDES DE REGISTRO PENDIENTES ────────

/**
 * Se ejecuta diariamente a las 09:00 AM (CDMX).
 * Revisa si hay solicitudes de registro pendientes con más de
 * 24 horas y envía un recordatorio a los usuarios Root.
 */
export const checkPendingRegistrations = onSchedule(
  {
    schedule: "every day 09:00",
    timeZone: "America/Mexico_City",
  },
  async () => {
    const pendingSnap = await db
      .collection("users")
      .where("registrationStatus", "==", "pending")
      .get();

    if (pendingSnap.empty) return;

    // Filtrar los que tienen más de 24 horas
    const now = Date.now();
    const twentyFourHours = 24 * 60 * 60 * 1000;
    let overdue = 0;

    for (const doc of pendingSnap.docs) {
      const data = doc.data();
      const createdAt = data.createdAt?.toMillis?.() || 0;
      if (now - createdAt > twentyFourHours) {
        overdue++;
      }
    }

    if (overdue === 0) return;

    // Obtener usuarios Root activos
    const rootSnap = await db
      .collection("users")
      .where("isRoot", "==", true)
      .where("isActive", "==", true)
      .get();

    if (rootSnap.empty) return;

    const rootUids = rootSnap.docs.map((doc) => doc.id);

    await sendNotifications(rootUids, {
      titulo: "⏳ Solicitudes pendientes de revisión",
      cuerpo: `Hay ${overdue} solicitud(es) de registro con más de 24 horas sin revisar.`,
      tipo: "recordatorio_solicitudes",
      refType: "user",
      refId: "",
      projectId: "",
      projectName: "",
    });
  }
);

// ── Scheduled: COMPROMISOS DE MINUTAS — DEADLINES ────────

/**
 * Se ejecuta diariamente a las 08:00 AM (CDMX).
 * Revisa todos los compromisos de minutas activas y envía
 * notificaciones push al responsable cuando la fecha de entrega
 * está próxima o ya venció.
 */
export const checkCompromisoDeadlines = onSchedule(
  {
    schedule: "every day 08:00",
    timeZone: "America/Mexico_City",
  },
  async () => {
    const snap = await db
      .collection("Minutas")
      .where("isActive", "==", true)
      .get();

    if (snap.empty) return;

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const promises: Promise<void>[] = [];

    for (const doc of snap.docs) {
      const data = doc.data();
      const minutaId = doc.id;
      const projectId = data.projectId as string | undefined;
      const projectName = (data.projectName as string) ?? "";
      const folio = (data.folio as string) ?? "";

      if (!projectId) continue;

      const compromisos = data.compromisos as Array<Record<string, unknown>> | undefined;
      if (!compromisos || compromisos.length === 0) continue;

      for (const c of compromisos) {
        const status = c.status as string | undefined;
        // Solo compromisos pendientes
        if (status !== "pendiente") continue;

        const responsableUid = c.responsableUid as string | undefined;
        if (!responsableUid) continue;

        // Parsear fechaEntrega
        const fhRaw = c.fechaEntrega;
        let target: Date | null = null;
        if (fhRaw && typeof (fhRaw as {toDate?: () => Date}).toDate === "function") {
          target = (fhRaw as {toDate: () => Date}).toDate();
        } else if (typeof fhRaw === "string" && fhRaw.length > 0) {
          const iso = new Date(fhRaw);
          if (!isNaN(iso.getTime())) target = iso;
        }
        if (!target) continue;

        const deadline = new Date(target.getFullYear(), target.getMonth(), target.getDate());
        const diffMs = deadline.getTime() - today.getTime();
        const days = Math.round(diffMs / (1000 * 60 * 60 * 24));

        let emoji = "";
        let label = "";
        let shouldNotify = false;

        if (days < 0) {
          emoji = "\u{1F534}"; // red circle
          label = `Vencido hace ${-days} día(s)`;
          shouldNotify = true;
        } else if (days <= 1) {
          emoji = "\u{1F7E0}"; // orange circle
          label = days === 0 ? "Vence HOY" : "Vence MAÑANA";
          shouldNotify = true;
        } else if (days <= 3) {
          emoji = "\u{1F7E1}"; // yellow circle
          label = `Vence en ${days} días`;
          shouldNotify = true;
        }

        if (!shouldNotify) continue;

        const tarea = (c.tarea as string) ?? "";
        const responsable = (c.responsable as string) ?? "";

        promises.push(
          sendNotifications([responsableUid], {
            titulo: `${emoji} Compromiso — ${label}`,
            cuerpo: `${tarea} (${responsable}) — Minuta ${folio}`,
            tipo: "compromiso_deadline",
            refType: "minuta",
            refId: minutaId,
            projectId,
            projectName,
          })
        );
      }
    }

    await Promise.all(promises);
  }
);

// ── Helpers: TAREAS ──────────────────────────────────────

/**
 * Determina los destinatarios de una notificación de tareas.
 * Usa NotificationConfig (recibirTareas / scopeTareas).
 */
async function getTareaRecipients(
  projectId: string,
  participantUids: string[],
  excludeUid?: string
): Promise<string[]> {
  const assignments = await getProjectAssignments(projectId);
  const recipients = new Set<string>();

  for (const a of assignments) {
    if (a.userId === excludeUid) continue;

    const config = await getNotifConfig(projectId, a.userId, a.role);
    if (!config.pushEnabled || !config.recibirTareas) continue;

    switch (config.scopeTareas) {
    case "todos":
      recipients.add(a.userId);
      break;
    case "proyecto":
      recipients.add(a.userId);
      break;
    case "participante":
      if (participantUids.includes(a.userId)) {
        recipients.add(a.userId);
      }
      break;
    }
  }

  return Array.from(recipients);
}

/**
 * Determina los destinatarios de una notificación de citas.
 * Usa NotificationConfig (recibirCitas / scopeCitas).
 */
async function getCitaRecipients(
  projectId: string,
  participantUids: string[],
  excludeUid?: string
): Promise<string[]> {
  const assignments = await getProjectAssignments(projectId);
  const recipients = new Set<string>();

  for (const a of assignments) {
    if (a.userId === excludeUid) continue;

    const config = await getNotifConfig(projectId, a.userId, a.role);
    if (!config.pushEnabled || !config.recibirCitas) continue;

    switch (config.scopeCitas) {
    case "todos":
      recipients.add(a.userId);
      break;
    case "proyecto":
      recipients.add(a.userId);
      break;
    case "participante":
      if (participantUids.includes(a.userId)) {
        recipients.add(a.userId);
      }
      break;
    }
  }

  return Array.from(recipients);
}

// ── Triggers: TAREAS ─────────────────────────────────────

/**
 * Tarea creada → notificar a los destinatarios elegibles.
 */
export const onTareaCreated = onDocumentCreated(
  "Tareas/{tareaId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const projectId = data.projectId as string | undefined;
    const projectName = data.projectName as string ?? "";
    const createdBy = data.createdByUid as string | undefined;
    const titulo = data.titulo as string ?? "Nueva tarea";
    const folio = data.folio as string ?? "";
    const assignedTo = data.assignedToUid as string | undefined;

    if (!projectId) return;

    const participantUids = [createdBy, assignedTo].filter(Boolean) as string[];
    const recipients = await getTareaRecipients(
      projectId,
      participantUids,
      createdBy
    );

    await sendNotifications(recipients, {
      titulo: `Nueva tarea: ${folio}`,
      cuerpo: titulo,
      tipo: "tarea_creada",
      refType: "tarea",
      refId: event.params.tareaId,
      projectId,
      projectName,
    });
  }
);

/**
 * Tarea actualizada → detectar cambios de status y asignación.
 */
export const onTareaUpdated = onDocumentUpdated(
  "Tareas/{tareaId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const projectId = after.projectId as string | undefined;
    if (!projectId) return;

    const projectName = after.projectName as string ?? "";
    const folio = after.folio as string ?? "";
    const tareaId = event.params.tareaId;
    const createdBy = after.createdByUid as string | undefined;
    const assignedTo = after.assignedToUid as string | undefined;
    const participantUids = [createdBy, assignedTo].filter(Boolean) as string[];

    // Cambio de status
    if (before.status !== after.status) {
      const updatedBy = after.updatedBy as string | undefined;
      const recipients = await getTareaRecipients(
        projectId,
        participantUids,
        updatedBy
      );
      await sendNotifications(recipients, {
        titulo: `${folio} → ${after.status}`,
        cuerpo: `El estado de la tarea cambió a "${after.status}"`,
        tipo: "tarea_status",
        refType: "tarea",
        refId: tareaId,
        projectId,
        projectName,
      });
    }

    // Cambio de asignación
    if (before.assignedToUid !== after.assignedToUid && after.assignedToUid) {
      const updatedBy = after.updatedBy as string | undefined;
      const recipients = await getTareaRecipients(
        projectId,
        participantUids,
        updatedBy
      );
      await sendNotifications(recipients, {
        titulo: `${folio} asignada`,
        cuerpo: `Tarea asignada a ${after.assignedToName ?? "alguien"}`,
        tipo: "tarea_asignada",
        refType: "tarea",
        refId: tareaId,
        projectId,
        projectName,
      });
    }
  }
);

// ── Scheduled: TAREAS — DEADLINES ────────────────────────

/**
 * Cada día a las 08:00 (CDMX) revisa tareas activas con fechaEntrega.
 * Envía notificaciones al asignado + Root cuando la deadline está próxima o venció.
 */
export const checkTareaDeadlines = onSchedule(
  {
    schedule: "every day 08:00",
    timeZone: "America/Mexico_City",
  },
  async () => {
    const snap = await db
      .collection("Tareas")
      .where("isActive", "==", true)
      .get();

    if (snap.empty) return;

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const promises: Promise<void>[] = [];

    for (const doc of snap.docs) {
      const data = doc.data();
      const tareaId = doc.id;

      // Solo tareas pendientes o en progreso
      const status = data.status as string | undefined;
      if (status === "completada" || status === "cancelada") continue;

      const fhRaw = data.fechaEntrega;
      if (!fhRaw) continue;

      let target: Date | null = null;
      if (fhRaw.toDate) {
        target = fhRaw.toDate();
      } else if (typeof fhRaw === "string" && fhRaw.length > 0) {
        const iso = new Date(fhRaw);
        if (!isNaN(iso.getTime())) target = iso;
      }
      if (!target) continue;

      const deadline = new Date(target.getFullYear(), target.getMonth(), target.getDate());
      const diffMs = deadline.getTime() - today.getTime();
      const days = Math.round(diffMs / (1000 * 60 * 60 * 24));

      let zone: "amber" | "orange" | "red" | null = null;
      let emoji = "";
      let label = "";

      if (days < 0) {
        zone = "red";
        emoji = "\u{1F534}";
        label = `Vencida hace ${-days} día(s)`;
      } else if (days <= 1) {
        zone = "orange";
        emoji = "\u{1F7E0}";
        label = days === 0 ? "Vence HOY" : "Vence MAÑANA";
      } else if (days <= 5) {
        zone = "amber";
        emoji = "\u{1F7E1}";
        label = `Vence en ${days} días`;
      }

      if (!zone) continue;

      // Anti-spam: solo notificar si la zona cambió
      const lastAlert = data._lastDeadlineAlert as string | undefined;
      if (lastAlert === zone) continue;

      promises.push(
        db.collection("Tareas").doc(tareaId).update({
          _lastDeadlineAlert: zone,
        }).then(() => {/* ok */})
      );

      const projectId = data.projectId as string | undefined;
      if (!projectId) continue;

      const projectName = data.projectName as string ?? "";
      const folio = data.folio as string ?? "";
      const titulo = data.titulo as string ?? "";
      const assignedToUid = data.assignedToUid as string | undefined;

      // Notificar al asignado + Root del proyecto
      const recipientUids: string[] = [];
      if (assignedToUid) recipientUids.push(assignedToUid);

      const assignments = await getProjectAssignments(projectId);
      for (const a of assignments) {
        if (a.role === "Root" && !recipientUids.includes(a.userId)) {
          recipientUids.push(a.userId);
        }
      }

      if (recipientUids.length === 0) continue;

      promises.push(
        sendNotifications(recipientUids, {
          titulo: `${emoji} ${folio} — ${label}`,
          cuerpo: titulo,
          tipo: `tarea_deadline_${zone}`,
          refType: "tarea",
          refId: tareaId,
          projectId,
          projectName,
        })
      );
    }

    await Promise.all(promises);
  }
);

// ── Scheduled: CHECK REQUERIMIENTO DEADLINES ─────────────

/**
 * Lunes a Viernes a las 09:30 y 16:00 (CDMX).
 * Revisa requerimientos activos con fechaCompromiso y envía alertas
 * de semáforo (amber ≤5d, orange ≤1d, red vencido) al responsable + Root.
 */
async function _checkReqDeadlinesLogic(runTag: string): Promise<void> {
  const snap = await db
    .collection("Requerimientos")
    .where("isActive", "==", true)
    .get();

  if (snap.empty) return;

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  const promises: Promise<void>[] = [];

  for (const doc of snap.docs) {
    const data = doc.data();
    const reqId = doc.id;

    // Solo requerimientos con fecha compromiso
    const fhRaw = data.fechaCompromiso;
    if (!fhRaw) continue;

    // Omitir estados terminales
    const status = (data.status as string ?? "").toLowerCase();
    if (status === "completado" || status === "descartado") continue;

    const target = parseDate(fhRaw);
    if (!target) continue;

    const deadline = new Date(
      target.getFullYear(),
      target.getMonth(),
      target.getDate()
    );
    const diffMs = deadline.getTime() - today.getTime();
    const days = Math.round(diffMs / (1000 * 60 * 60 * 24));

    // Determinar zona del semáforo
    let zone: "amber" | "orange" | "red" | null = null;
    let emoji = "";
    let label = "";

    if (days < 0) {
      zone = "red";
      emoji = "\u{1F534}";
      label = `Vencido hace ${-days} día(s)`;
    } else if (days <= 1) {
      zone = "orange";
      emoji = "\u{1F7E0}";
      label = days === 0 ? "Vence HOY" : "Vence MAÑANA";
    } else if (days <= 5) {
      zone = "amber";
      emoji = "\u{1F7E1}";
      label = `Vence en ${days} días`;
    }

    if (!zone) continue;

    // Anti-spam: zona + tag de corrida (am/pm) para permitir 2 alertas/día
    const alertKey = `${zone}_${runTag}`;
    const lastAlert = data._lastDeadlineAlert as string | undefined;
    if (lastAlert === alertKey) continue;

    promises.push(
      db
        .collection("Requerimientos")
        .doc(reqId)
        .update({_lastDeadlineAlert: alertKey})
        .then(() => {
          /* ok */
        })
    );

    const projectId = data.projectId as string | undefined;
    if (!projectId) continue;

    const projectName = (data.projectName as string) ?? "";
    const folio = (data.folio as string) ?? "";
    const titulo = (data.titulo as string) ?? "";
    const assignedToUid = data.assignedToUid as string | undefined;

    // Notificar al asignado + Root del proyecto
    const recipientUids: string[] = [];
    if (assignedToUid) recipientUids.push(assignedToUid);

    const assignments = await getProjectAssignments(projectId);
    for (const a of assignments) {
      if (a.role === "Root" && !recipientUids.includes(a.userId)) {
        recipientUids.push(a.userId);
      }
    }

    if (recipientUids.length === 0) continue;

    promises.push(
      sendNotifications(recipientUids, {
        titulo: `${emoji} ${folio} — ${label}`,
        cuerpo: titulo,
        tipo: `req_deadline_${zone}`,
        refType: "requerimiento",
        refId: reqId,
        projectId,
        projectName,
      })
    );
  }

  await Promise.all(promises);
}

/** Lunes a Viernes 09:30 CDMX */
export const checkReqDeadlinesMorning = onSchedule(
  {
    schedule: "30 9 * * 1-5",
    timeZone: "America/Mexico_City",
  },
  async () => _checkReqDeadlinesLogic("am")
);

/** Lunes a Viernes 16:00 CDMX */
export const checkReqDeadlinesAfternoon = onSchedule(
  {
    schedule: "0 16 * * 1-5",
    timeZone: "America/Mexico_City",
  },
  async () => _checkReqDeadlinesLogic("pm")
);

// ── Scheduled: RESUMEN DIARIO ────────────────────────────

/**
 * Lunes a Sábado a las 09:00 (CDMX).
 * Envía un resumen diario por proyecto a cada miembro con push habilitado.
 *
 * Incluye por proyecto:
 *  - Tickets pendientes (con conteo de vencidos).
 *  - Tareas pendientes / en progreso.
 *  - Citas programadas para hoy.
 */
export const dailyMorningSummary = onSchedule(
  {
    schedule: "0 9 * * 1-6",
    timeZone: "America/Mexico_City",
  },
  async () => {
    // 1. Obtener todos los projectAssignments activos → agrupar por proyecto.
    const assignSnap = await db
      .collection("projectAssignments")
      .where("isActive", "==", true)
      .get();

    if (assignSnap.empty) return;

    const projectMap = new Map<string, Array<{userId: string; role: UserRole}>>();
    for (const doc of assignSnap.docs) {
      const d = doc.data();
      const pid = d.projectId as string;
      const uid = d.userId as string;
      const role = d.role as UserRole;
      if (!pid || !uid) continue;
      if (!projectMap.has(pid)) projectMap.set(pid, []);
      projectMap.get(pid)!.push({userId: uid, role});
    }

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const closedStatuses = ["RESUELTO", "CERRADO", "ARCHIVADO"];
    const promises: Promise<void>[] = [];

    for (const [projectId, members] of projectMap) {
      // --- Tickets pendientes ---
      const ticketsSnap = await db
        .collection("Incidentes")
        .where("projectId", "==", projectId)
        .where("isActive", "==", true)
        .get();

      let ticketsPendientes = 0;
      let ticketsVencidos = 0;

      for (const t of ticketsSnap.docs) {
        const d = t.data();
        const status = (
          (d.status as string) ?? (d.estatusIncidente as string) ?? ""
        ).toUpperCase().trim();
        if (closedStatuses.includes(status)) continue;
        ticketsPendientes++;

        // ¿Vencido?
        const target = parseDate(d.fhCompromisoSol);
        if (target && target < today) ticketsVencidos++;
      }

      // --- Tareas pendientes ---
      const tareasSnap = await db
        .collection("Tareas")
        .where("projectId", "==", projectId)
        .where("isActive", "==", true)
        .get();

      let tareasPendientes = 0;
      for (const t of tareasSnap.docs) {
        const st = (t.data().status as string ?? "").toLowerCase();
        if (st !== "completada" && st !== "cancelada") tareasPendientes++;
      }

      // --- Citas hoy ---
      const citasSnap = await db
        .collection("Citas")
        .where("projectId", "==", projectId)
        .where("isActive", "==", true)
        .where("status", "==", "programada")
        .get();

      let citasHoy = 0;
      for (const c of citasSnap.docs) {
        const d = c.data();
        const citaDate = parseDate(d.fecha ?? d.fechaHora);
        if (!citaDate) continue;
        const citaDay = new Date(
          citaDate.getFullYear(), citaDate.getMonth(), citaDate.getDate()
        );
        if (citaDay.getTime() === today.getTime()) citasHoy++;
      }

      // ¿Nada que reportar?
      if (ticketsPendientes === 0 && tareasPendientes === 0 && citasHoy === 0) {
        continue;
      }

      // Obtener nombre del proyecto
      const projDoc = await db.collection("Proyectos").doc(projectId).get();
      const projectName = projDoc.exists
        ? ((projDoc.data()!.nombreProyecto as string) ?? projectId)
        : projectId;

      // Construir mensaje
      const lines: string[] = [];
      if (ticketsPendientes > 0) {
        let line = `\u{2022} ${ticketsPendientes} ticket(s) pendiente(s)`;
        if (ticketsVencidos > 0) {
          line += ` (${ticketsVencidos} vencido(s) \u{1F534})`;
        }
        lines.push(line);
      }
      if (tareasPendientes > 0) {
        lines.push(`\u{2022} ${tareasPendientes} tarea(s) pendiente(s)`);
      }
      if (citasHoy > 0) {
        lines.push(`\u{2022} ${citasHoy} cita(s) programada(s) hoy`);
      }
      const cuerpo = lines.join("\n");

      // Enviar a cada miembro del proyecto con push habilitado
      for (const m of members) {
        const config = await getNotifConfig(projectId, m.userId, m.role);
        if (!config.pushEnabled) continue;

        promises.push(
          sendNotifications([m.userId], {
            titulo: `\u{1F4CA} Resumen del d\u{00ED}a \u{2014} ${projectName}`,
            cuerpo,
            tipo: "resumen_diario",
            refType: "proyecto",
            refId: projectId,
            projectId,
            projectName,
          })
        );
      }
    }

    await Promise.all(promises);
  }
);

// ── Scheduled: TICKETS SIN FECHA COMPROMISO ──────────────

/**
 * Lunes, Miércoles y Viernes a las 10:00 (CDMX).
 * Notifica a Root y Soporte de cada proyecto sobre tickets activos
 * que no tienen fecha de solución programada (fhCompromisoSol).
 */
export const ticketsWithoutDeadlineReminder = onSchedule(
  {
    schedule: "0 10 * * 1,3,5",
    timeZone: "America/Mexico_City",
  },
  async () => {
    const assignSnap = await db
      .collection("projectAssignments")
      .where("isActive", "==", true)
      .get();

    if (assignSnap.empty) return;

    const projectMap = new Map<string, Array<{userId: string; role: UserRole}>>();
    for (const doc of assignSnap.docs) {
      const d = doc.data();
      const pid = d.projectId as string;
      const uid = d.userId as string;
      const role = d.role as UserRole;
      if (!pid || !uid) continue;
      if (!projectMap.has(pid)) projectMap.set(pid, []);
      projectMap.get(pid)!.push({userId: uid, role});
    }

    const closedStatuses = ["RESUELTO", "CERRADO", "ARCHIVADO"];
    const promises: Promise<void>[] = [];

    for (const [projectId, members] of projectMap) {
      const ticketsSnap = await db
        .collection("Incidentes")
        .where("projectId", "==", projectId)
        .where("isActive", "==", true)
        .get();

      let sinFecha = 0;
      for (const t of ticketsSnap.docs) {
        const d = t.data();
        const status = (
          (d.status as string) ?? (d.estatusIncidente as string) ?? ""
        ).toUpperCase().trim();
        if (closedStatuses.includes(status)) continue;
        if (!d.fhCompromisoSol) sinFecha++;
      }

      if (sinFecha === 0) continue;

      // Obtener nombre del proyecto
      const projDoc = await db.collection("Proyectos").doc(projectId).get();
      const projectName = projDoc.exists
        ? ((projDoc.data()!.nombreProyecto as string) ?? projectId)
        : projectId;

      // Solo notificar a Root y Soporte con push habilitado
      const enabledRecipients: string[] = [];
      for (const m of members) {
        if (m.role !== "Root" && m.role !== "Soporte") continue;
        const config = await getNotifConfig(projectId, m.userId, m.role);
        if (config.pushEnabled) enabledRecipients.push(m.userId);
      }

      if (enabledRecipients.length === 0) continue;

      promises.push(
        sendNotifications(enabledRecipients, {
          titulo: `\u{26A0}\u{FE0F} ${sinFecha} ticket(s) sin fecha compromiso`,
          cuerpo: `Proyecto: ${projectName}`,
          tipo: "tickets_sin_fecha",
          refType: "proyecto",
          refId: projectId,
          projectId,
          projectName,
        })
      );
    }

    await Promise.all(promises);
  }
);
