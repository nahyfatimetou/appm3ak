#!/usr/bin/env node
/**
 * Proxy CORS pour le backoffice Flutter.
 * Reçoit les requêtes sur le port 3001 et les transmet au backend (port 3000)
 * en ajoutant les en-têtes CORS nécessaires.
 *
 * Usage : node proxy.js
 * Puis définir VITE_API_URL=http://localhost:3001 dans .env
 */

const http = require('http');
const url = require('url');

const PROXY_PORT = 3001;
const BACKEND_URL = 'http://localhost:3000';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept',
  'Access-Control-Max-Age': '86400',
};

const server = http.createServer((clientReq, clientRes) => {
  if (clientReq.method === 'OPTIONS') {
    clientRes.writeHead(204, CORS_HEADERS);
    clientRes.end();
    return;
  }

  const path = clientReq.url;
  const backendUrl = BACKEND_URL + path;
  const parsed = url.parse(backendUrl);

  const proxyReq = http.request(
    {
      hostname: parsed.hostname,
      port: parsed.port || 80,
      path: parsed.path,
      method: clientReq.method,
      headers: {
        ...clientReq.headers,
        host: parsed.host,
      },
    },
    (proxyRes) => {
      const headers = { ...proxyRes.headers, ...CORS_HEADERS };
      clientRes.writeHead(proxyRes.statusCode, headers);
      proxyRes.pipe(clientRes);
    }
  );

  proxyReq.on('error', (err) => {
    console.error('Proxy error:', err.message);
    clientRes.writeHead(502, { ...CORS_HEADERS, 'Content-Type': 'application/json' });
    clientRes.end(JSON.stringify({ error: 'Backend unreachable: ' + err.message }));
  });

  clientReq.pipe(proxyReq);
});

server.listen(PROXY_PORT, () => {
  console.log(`Proxy CORS actif : http://localhost:${PROXY_PORT} -> ${BACKEND_URL}`);
  console.log(`Définissez VITE_API_URL=http://localhost:${PROXY_PORT} dans .env`);
});
