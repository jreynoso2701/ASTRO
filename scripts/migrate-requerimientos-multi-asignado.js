/**
 * Migración: Requerimientos con un solo responsable → múltiples responsables.
 *
 * Copia `assignedTo` / `assignedToName` a las listas `assignedToUids` /
 * `assignedToNames`. Es idempotente: omite los requerimientos que ya tienen
 * la lista.
 *
 * Sin esta migración, los requerimientos antiguos no aparecen en las consultas
 * y notificaciones que ahora usan `array-contains` sobre `assignedToUids`.
 *
 * Usa la REST API de Firestore con el token del Firebase CLI.
 *
 * Modo DRY-RUN por defecto. Pasar --execute para escribir en Firestore.
 *
 * Uso:
 *   node scripts/migrate-requerimientos-multi-asignado.js            # solo muestra lo que haría
 *   node scripts/migrate-requerimientos-multi-asignado.js --execute  # ejecuta la migración
 */

const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'astro-b97c2';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const DRY_RUN = !process.argv.includes('--execute');

// ── Auth: obtener access_token del refresh_token del Firebase CLI ──
async function getAccessToken() {
  const configPath = path.join(
    process.env.USERPROFILE || process.env.HOME,
    '.config', 'configstore', 'firebase-tools.json'
  );
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const refreshToken = config.tokens?.refresh_token;
  if (!refreshToken) throw new Error('No refresh_token found');

  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
      client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }),
  });
  const data = await resp.json();
  if (!data.access_token) {
    throw new Error('Failed to get access_token: ' + JSON.stringify(data));
  }
  return data.access_token;
}

// ── Firestore REST helpers ──
let TOKEN = '';

async function firestoreGet(collectionId) {
  const docs = [];
  let pageToken = '';
  do {
    const url = `${BASE_URL}/${collectionId}?pageSize=300${pageToken ? '&pageToken=' + pageToken : ''}`;
    const resp = await fetch(url, { headers: { Authorization: `Bearer ${TOKEN}` } });
    const data = await resp.json();
    if (data.documents) docs.push(...data.documents);
    pageToken = data.nextPageToken || '';
  } while (pageToken);
  return docs;
}

/// Actualiza solo los campos indicados (updateMask), sin tocar el resto.
async function firestorePatch(docPath, fields) {
  const mask = Object.keys(fields)
    .map((f) => `updateMask.fieldPaths=${f}`)
    .join('&');
  const url = `${BASE_URL}/${docPath}?${mask}`;
  const resp = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields }),
  });
  if (!resp.ok) {
    const err = await resp.text();
    throw new Error(`Patch failed: ${resp.status} ${err}`);
  }
  return await resp.json();
}

function docId(fullPath) {
  return fullPath.split('/').pop();
}

function strArray(values) {
  return { arrayValue: { values: values.map((v) => ({ stringValue: v })) } };
}

async function main() {
  TOKEN = await getAccessToken();

  console.log(
    DRY_RUN
      ? '═══ MODO DRY-RUN ═══ (usa --execute para escribir en Firestore)\n'
      : '═══ EJECUTANDO MIGRACIÓN ═══\n'
  );

  const docs = await firestoreGet('Requerimientos');
  console.log(`Requerimientos encontrados: ${docs.length}\n`);

  let migrated = 0;
  let skipped = 0;
  let unassigned = 0;

  for (const doc of docs) {
    const id = docId(doc.name);
    const f = doc.fields || {};

    // Ya migrado: tiene la lista con al menos un elemento.
    const existing = f.assignedToUids?.arrayValue?.values || [];
    if (existing.length > 0) {
      skipped++;
      continue;
    }

    const uid = f.assignedTo?.stringValue;
    if (!uid) {
      // Sin responsable: nada que copiar.
      unassigned++;
      continue;
    }

    const name = f.assignedToName?.stringValue || '';
    const update = {
      assignedToUids: strArray([uid]),
      assignedToNames: strArray([name]),
    };

    console.log(`  ${id}: ${uid} (${name || 'sin nombre'})`);

    if (!DRY_RUN) {
      await firestorePatch(`Requerimientos/${id}`, update);
    }
    migrated++;
  }

  console.log('\n─── Resumen ───');
  console.log(`  Migradas:        ${migrated}`);
  console.log(`  Ya migradas:     ${skipped}`);
  console.log(`  Sin responsable: ${unassigned}`);
  if (DRY_RUN) {
    console.log('\n(DRY-RUN: no se escribió nada. Usa --execute para aplicar.)');
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
