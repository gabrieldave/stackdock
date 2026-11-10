#!/usr/bin/env node
/**
 * Genera licencia StackDock Pro (SDOCK-...) firmada con Ed25519.
 * Uso: node Scripts/generate_license.mjs email@dominio.com
 */
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import os from 'os';

const email = (process.argv[2] || '').trim().toLowerCase();
if (!email || !email.includes('@')) {
  console.error('Uso: node Scripts/generate_license.mjs email@dominio.com');
  process.exit(1);
}

const pemPath = path.join(os.homedir(), '.blackeye/secrets/stackdock/private_key.pem');
if (!fs.existsSync(pemPath)) {
  console.error('No existe', pemPath);
  process.exit(1);
}

const privateKeyPem = fs.readFileSync(pemPath, 'utf8');
const payload = Buffer.from(`${email}|stackdock-pro|3macs`, 'utf8');
const signature = crypto.sign(null, payload, privateKeyPem); // Ed25519
const b64url = signature
  .toString('base64')
  .replace(/\+/g, '-')
  .replace(/\//g, '_')
  .replace(/=+$/g, '');

console.log(`SDOCK-${b64url}`);
