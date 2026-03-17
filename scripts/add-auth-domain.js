/**
 * Script para agregar un dominio autorizado a Firebase Auth.
 * Usa las credenciales almacenadas de Firebase CLI.
 *
 * Uso: node scripts/add-auth-domain.js <domain>
 */
const https = require('https');
const path = require('path');

const PROJECT_ID = 'astro-b97c2';
const FIREBASE_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const FIREBASE_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

function getStoredRefreshToken() {
  const npmGlobal = path.join(process.env.APPDATA, 'npm', 'node_modules', 'firebase-tools', 'lib', 'configstore');
  const cs = require(npmGlobal);
  const tokens = cs.configstore.get('tokens');
  if (!tokens?.refresh_token) throw new Error('No refresh token found');
  return tokens.refresh_token;
}

function refreshAccessToken(refreshToken) {
  return new Promise((resolve, reject) => {
    const body = new URLSearchParams({
      client_id: FIREBASE_CLIENT_ID,
      client_secret: FIREBASE_CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }).toString();

    const req = https.request(
      {
        hostname: 'oauth2.googleapis.com',
        path: '/token',
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': Buffer.byteLength(body),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          if (res.statusCode === 200) resolve(JSON.parse(data).access_token);
          else reject(new Error(`Token refresh failed: ${res.statusCode} ${data}`));
        });
      }
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function apiCall(method, apiPath, accessToken, body) {
  return new Promise((resolve, reject) => {
    const bodyStr = body ? JSON.stringify(body) : null;
    const headers = {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    };
    if (bodyStr) headers['Content-Length'] = Buffer.byteLength(bodyStr);

    const req = https.request(
      {
        hostname: 'identitytoolkit.googleapis.com',
        path: apiPath,
        method,
        headers,
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(JSON.parse(data));
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${data}`));
          }
        });
      }
    );
    req.on('error', reject);
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

async function main() {
  const newDomain = process.argv[2];
  if (!newDomain) {
    console.error('Uso: node scripts/add-auth-domain.js <domain>');
    console.error('Ejemplo: node scripts/add-auth-domain.js astro-production-be6a.up.railway.app');
    process.exit(1);
  }

  console.log('Obteniendo token...');
  const refreshToken = getStoredRefreshToken();
  const accessToken = await refreshAccessToken(refreshToken);

  console.log('Obteniendo dominios autorizados actuales...');
  const config = await apiCall(
    'GET',
    `/admin/v2/projects/${PROJECT_ID}/config`,
    accessToken
  );

  const currentDomains = config.authorizedDomains || [];
  console.log('Dominios actuales:', currentDomains);

  if (currentDomains.includes(newDomain)) {
    console.log(`El dominio "${newDomain}" ya esta autorizado.`);
    return;
  }

  const updatedDomains = [...currentDomains, newDomain];
  console.log(`Agregando "${newDomain}"...`);

  const result = await apiCall(
    'PATCH',
    `/admin/v2/projects/${PROJECT_ID}/config?updateMask=authorizedDomains`,
    accessToken,
    { authorizedDomains: updatedDomains }
  );

  console.log('Dominios actualizados:', result.authorizedDomains);
  console.log('Dominio agregado exitosamente!');
}

main().catch((err) => {
  console.error('Error:', err.message);
  process.exit(1);
});
