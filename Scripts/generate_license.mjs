#!/usr/bin/env node
/**
 * Genera licencias StackDock (SDOCK-...) firmadas con Ed25519.
 *
 * Uso:
 *   node Scripts/generate_license.mjs [--tier personal|pro] email@dominio.com
 *
 * Planes (payload exacto firmado):
 *   personal -> "email|stackdock-personal|1mac"  (Personal $9.99 USD · 1 Mac)
 *   pro      -> "email|stackdock-pro|3macs"      (Pro $19 USD · hasta 3 Macs)
 *
 * La clave privada se lee de:
 *   $STACKDOCK_LICENSE_PRIVATE_KEY_PEM  (ruta explícita)
 *   ~/.blackeye/secrets/stackdock/private_key.pem
 *   $HOME/Documents/VibeSystems/secrets.env (variable STACKDOCK_LICENSE_PRIVATE_KEY_B64)
 * Nunca se imprime la clave privada.
 */
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import os from 'os';

const TIERS = {
  personal: 'stackdock-personal|1mac',
  pro: 'stackdock-pro|3macs',
};

let args = process.argv.slice(2);
let tier = (process.env.STACKDOCK_LICENSE_TIER || 'pro').toLowerCase();

const tierFlagIndex = args.findIndex((a) => a === '--tier' || a.startsWith('--tier='));
if (tierFlagIndex !== -1) {
  if (args[tierFlagIndex].includes('=')) {
    tier = args[tierFlagIndex].split('=')[1].toLowerCase();
    args.splice(tierFlagIndex, 1);
  } else {
    tier = (args[tierFlagIndex + 1] || '').toLowerCase();
    args.splice(tierFlagIndex, 2);
  }
}

if (!TIERS[tier]) {
  console.error('Tier inválido. Usa --tier personal o --tier pro');
  process.exit(1);
}

const email = (args[0] || '').trim().toLowerCase();
if (!email || !email.includes('@')) {
  console.error('Uso: node Scripts/generate_license.mjs [--tier personal|pro] email@dominio.com');
  process.exit(1);
}

function readPrivateKeyPem() {
  const explicit = process.env.STACKDOCK_LICENSE_PRIVATE_KEY_PEM;
  const candidates = [
    explicit,
    path.join(os.homedir(), '.blackeye/secrets/stackdock/private_key.pem'),
    path.join(os.homedir(), 'Documents/VibeSystems/stackdock/private_key.pem'),
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) return fs.readFileSync(candidate, 'utf8');
  }

  // Fallback: secrets.env con la clave en Base64 (32 bytes) → PEM PKCS#8.
  const envPath = process.env.STACKDOCK_SECRETS ||
    path.join(os.homedir(), 'Documents/VibeSystems/secrets.env');
  if (fs.existsSync(envPath)) {
    const raw = fs.readFileSync(envPath, 'utf8');
    const line = raw.split(/\r?\n/).find((l) => /^\s*STACKDOCK_LICENSE_PRIVATE_KEY(B64)?\s*=/.test(l));
    if (line) {
      const value = line.split('=').slice(1).join('=').trim().replace(/^["']|["']$/g, '');
      const seed = Buffer.from(value, 'base64');
      if (seed.length === 32) {
        const der = Buffer.concat([
          Buffer.from('302e020100300506032b657004220420', 'hex'),
          seed,
        ]);
        const b64 = der.toString('base64').match(/.{1,64}/g).join('\n');
        return `-----BEGIN PRIVATE KEY-----\n${b64}\n-----END PRIVATE KEY-----\n`;
      }
    }
  }

  console.error('No se encontró la clave privada Ed25519 de StackDock (revisa STACKDOCK_LICENSE_PRIVATE_KEY_PEM).');
  process.exit(1);
}

const privateKeyPem = readPrivateKeyPem();
const payload = Buffer.from(`${email}|${TIERS[tier]}`, 'utf8');
const signature = crypto.sign(null, payload, privateKeyPem); // Ed25519
const b64url = signature
  .toString('base64')
  .replace(/\+/g, '-')
  .replace(/\//g, '_')
  .replace(/=+$/g, '');

console.log(`SDOCK-${b64url}`);
