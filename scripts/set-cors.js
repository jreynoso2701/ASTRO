/**
 * Script para configurar CORS en Firebase Storage bucket.
 * Usa las credenciales almacenadas de Firebase CLI.
 *
 * Uso: node scripts/set-cors.js
 */
const https = require('https');
const path = require('path');

const BUCKET = 'astro-b97c2.appspot.com';
const FIREBASE_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const FIREBASE_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

const corsConfig = [
  {
    origin: [
      'https://astro-production-be6a.up.railway.app',
      'https://astro-b97c2.firebaseapp.com',
      'http://localhost:8080'
    ],
    method: ['GET', 'HEAD'],
    maxAgeSeconds: 3600,
    responseHeader: ['Content-Type', 'Content-Length', 'Content-Range']
  }
];

function getStoredRefreshToken() {
  const npmGlobal = process.env.APPDATA
    ? path.join(process.env.APPDATA, 'npm', 'node_modules', 'firebase-tools', 'lib', 'configstore')
    : null;
  if (!npmGlobal) throw new Error('No APPDATA found');
  const cs = require(npmGlobal);
  const tokens = cs.configstore.get('tokens');
  if (!tokens?.refresh_token) throw new Error('No refresh token found in Firebase CLI config');
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
          if (res.statusCode === 200) {
            resolve(JSON.parse(data).access_token);
          } else {
            reject(new Error(`Token refresh failed: ${res.statusCode} ${data}`));
          }
        });
      }
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function setCors(accessToken) {
  const body = JSON.stringify({ cors: corsConfig });

  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: 'storage.googleapis.com',
        path: `/storage/v1/b/${BUCKET}?fields=cors`,
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            console.log('CORS configurado exitosamente!');
            console.log(JSON.parse(data));
            resolve();
          } else {
            console.error(`Error ${res.statusCode}:`, data);
            reject(new Error(`HTTP ${res.statusCode}`));
          }
        });
      }
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function main() {
  console.log('Obteniendo refresh token de Firebase CLI...');
  const refreshToken = getStoredRefreshToken();
  console.log('Refresh token encontrado. Obteniendo access token...');
  const accessToken = await refreshAccessToken(refreshToken);
  console.log('Access token obtenido. Configurando CORS...');
  await setCors(accessToken);
}

main().catch((err) => {
  console.error('Error:', err.message);
  process.exit(1);
});
