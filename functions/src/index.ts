/**
 * ASTRO — Cloud Functions para notificaciones push.
 *
 * Triggers de Firestore que:
 * 1. Determinan los destinatarios según rol y NotificationConfig.
 * 2. Envían push notifications vía FCM.
 * 3. Crean entradas en la bandeja in-app (Notificaciones).
 */

import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";

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
  };
}

/**
 * Obtiene los FCM tokens de un usuario.
 */
async function getFcmTokens(userId: string): Promise<string[]> {
  const doc = await db.collection("users").doc(userId).get();
  if (!doc.exists) return [];
  return (doc.data()?.fcmTokens as string[]) ?? [];
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
    refType: "ticket" | "requerimiento";
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
