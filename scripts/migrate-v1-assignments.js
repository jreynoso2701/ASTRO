/**
 * Migración V1 → V2: proyectosAsignados → projectAssignments
 *
 * Lee los campos legacy de cada usuario (proyectosAsignados, deEmpresa, rolUsuario)
 * y crea documentos en la colección `projectAssignments`.
 *
 * Usa la REST API de Firestore con el token del Firebase CLI.
 *
 * Modo DRY-RUN por defecto. Pasar --execute para escribir en Firestore.
 *
 * Uso:
 *   node scripts/migrate-v1-assignments.js           # solo muestra lo que haría
 *   node scripts/migrate-v1-assignments.js --execute  # ejecuta la migración
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
  if (!data.access_token) throw new Error('Failed to get access_token: ' + JSON.stringify(data));
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

async function firestoreCreate(collectionId, fields) {
  const url = `${BASE_URL}/${collectionId}`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields }),
  });
  if (!resp.ok) {
    const err = await resp.text();
    throw new Error(`Create failed: ${resp.status} ${err}`);
  }
  return await resp.json();
}

// Parsear valor de la REST API de Firestore
function parseValue(val) {
  if (!val) return null;
  if ('stringValue' in val) return val.stringValue;
  if ('booleanValue' in val) return val.booleanValue;
  if ('integerValue' in val) return parseInt(val.integerValue);
  if ('timestampValue' in val) return val.timestampValue;
  if ('arrayValue' in val) {
    return (val.arrayValue.values || []).map(parseValue);
  }
  if ('mapValue' in val) {
    const obj = {};
    for (const [k, v] of Object.entries(val.mapValue.fields || {})) {
      obj[k] = parseValue(v);
    }
    return obj;
  }
  return null;
}

function docId(fullPath) {
  return fullPath.split('/').pop();
}

function parseDoc(doc) {
  const fields = {};
  for (const [k, v] of Object.entries(doc.fields || {})) {
    fields[k] = parseValue(v);
  }
  fields._id = docId(doc.name);
  return fields;
}

async function main() {
  TOKEN = await getAccessToken();

  if (DRY_RUN) {
    console.log('═══ MODO DRY-RUN ═══ (usa --execute para escribir en Firestore)\n');
  } else {
    console.log('═══ MODO EJECUCIÓN ═══ Escribiendo en Firestore...\n');
  }

  // 1. Cargar Empresas → mapa nombre → id
  const empresasDocs = await firestoreGet('Empresas');
  const empresaMap = {};
  empresasDocs.forEach(doc => {
    const d = parseDoc(doc);
    const name = (d.nombreEmpresa || '').trim().toUpperCase();
    empresaMap[name] = d._id;
  });
  console.log(`Empresas encontradas: ${Object.keys(empresaMap).length}`);
  Object.entries(empresaMap).forEach(([name, id]) => console.log(`  ${name} → ${id}`));

  // 2. Cargar Proyectos → mapa nombre → { id, empresaId }
  const proyectosDocs = await firestoreGet('Proyectos');
  const proyectoMap = {};
  proyectosDocs.forEach(doc => {
    const d = parseDoc(doc);
    const name = (d.nombreProyecto || '').trim().toUpperCase();
    const fkEmpresa = (d.fkEmpresa || '').trim().toUpperCase();
    proyectoMap[name] = { id: d._id, empresaId: empresaMap[fkEmpresa] || '', fkEmpresa };
  });
  console.log(`\nProyectos encontrados: ${Object.keys(proyectoMap).length}`);
  Object.entries(proyectoMap).forEach(([name, info]) =>
    console.log(`  ${name} → ${info.id} (empresa: ${info.fkEmpresa} → ${info.empresaId})`)
  );

  // 3. Cargar usuarios
  const usersDocs = await firestoreGet('users');
  const users = usersDocs.map(parseDoc);
  const usersWithProjects = users.filter(
    u => Array.isArray(u.proyectosAsignados) && u.proyectosAsignados.length > 0
  );
  console.log(`\nUsuarios con proyectosAsignados: ${usersWithProjects.length}`);

  // 4. Cargar asignaciones V2 existentes
  const existingDocs = await firestoreGet('projectAssignments');
  const existingSet = new Set();
  existingDocs.forEach(doc => {
    const d = parseDoc(doc);
    existingSet.add(`${d.userId}|${d.projectId}`);
  });
  console.log(`Asignaciones V2 existentes: ${existingSet.size}\n`);

  // 5. Migrar
  let created = 0, skipped = 0, notFound = 0;

  for (const user of usersWithProjects) {
    const displayName = user.displayName || user.display_name || user.email || user._id;
    const userEmpresa = (user.deEmpresa || '').trim().toUpperCase();
    const rolV1 = (user.rolUsuario || 'Usuario').trim();

    const roleLower = rolV1.toLowerCase();
    let role;
    if (roleLower === 'root') role = 'Root';
    else if (roleLower === 'supervisor') role = 'Supervisor';
    else if (roleLower === 'soporte') role = 'Soporte';
    else role = 'Usuario';

    console.log(`👤 ${displayName} (${user._id})`);
    console.log(`   Empresa: ${userEmpresa || '(sin empresa)'} | Rol V1: ${rolV1}`);

    for (const projName of user.proyectosAsignados) {
      const projKey = projName.trim().toUpperCase();
      const proj = proyectoMap[projKey];

      if (!proj) {
        console.log(`   ⚠️  Proyecto "${projName}" NO encontrado en colección Proyectos`);
        notFound++;
        continue;
      }

      const key = `${user._id}|${proj.id}`;
      if (existingSet.has(key)) {
        console.log(`   ⏭️  "${projName}" → ya existe asignación V2`);
        skipped++;
        continue;
      }

      const empresaId = proj.empresaId || empresaMap[userEmpresa] || '';

      console.log(`   ✅ "${projName}" → projectId: ${proj.id}, empresaId: ${empresaId}, rol: ${role}`);

      if (!DRY_RUN) {
        await firestoreCreate('projectAssignments', {
          userId: { stringValue: user._id },
          projectId: { stringValue: proj.id },
          empresaId: { stringValue: empresaId },
          role: { stringValue: role },
          assignedAt: { timestampValue: new Date().toISOString() },
          assignedBy: { stringValue: 'migration-v1' },
          isActive: { booleanValue: true },
        });
      }

      created++;
    }
    console.log('');
  }

  console.log('═══ RESUMEN ═══');
  console.log(`  Creados:        ${created}`);
  console.log(`  Skipped (dup):  ${skipped}`);
  console.log(`  No encontrados: ${notFound}`);
  if (DRY_RUN) {
    console.log('\n⚠️  DRY-RUN: no se escribió nada. Usa --execute para migrar.');
  } else {
    console.log('\n✅ Migración completada.');
  }
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
