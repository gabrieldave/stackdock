/**
 * Servido de estáticos del dist de Vite + descargas del .dmg desde STORAGE_DIR.
 * Soporta ETag/Last-Modified/304, cache immutable para assets con hash y Range para el DMG.
 */
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import { config } from './config.js';
import { sendJson } from './http.js';

export const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
  '.webmanifest': 'application/manifest+json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.avif': 'image/avif',
  '.gif': 'image/gif',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.mp4': 'video/mp4',
  '.webm': 'video/webm',
  '.mp3': 'audio/mpeg',
  '.pdf': 'application/pdf',
  '.dmg': 'application/octet-stream',
  '.sig': 'text/plain; charset=utf-8',
  '.zip': 'application/zip',
};

export function contentTypeFor(filePath) {
  return MIME_TYPES[path.extname(filePath).toLowerCase()] || 'application/octet-stream';
}

/** Resuelve una ruta URL dentro de un directorio base, sin permitir traversal. */
export function safeJoin(baseDir, urlPath) {
  let decoded;
  try {
    decoded = decodeURIComponent(urlPath);
  } catch {
    return null;
  }
  if (decoded.includes('\0')) return null;
  const base = path.resolve(baseDir);
  const target = path.resolve(base, `.${path.posix.normalize(`/${decoded}`)}`);
  if (target !== base && !target.startsWith(base + path.sep)) return null;
  return target;
}

export function cacheControlFor(urlPath) {
  if (/^\/assets\//.test(urlPath)) return 'public, max-age=31536000, immutable';
  if (/\.html?$/.test(urlPath)) return 'no-cache, must-revalidate';
  return 'public, max-age=3600';
}

function etagFor(stat) {
  return `"${stat.size.toString(16)}-${Math.floor(stat.mtimeMs).toString(16)}"`;
}

function ifNoneMatch(req, etag) {
  const header = String(req.headers['if-none-match'] || '');
  if (!header) return false;
  return header.split(',').some((token) => token.trim() === etag || token.trim() === '*');
}

function ifModifiedSince(req, stat) {
  const header = String(req.headers['if-modified-since'] || '');
  if (!header) return false;
  const since = Date.parse(header);
  if (!Number.isFinite(since)) return false;
  return Math.floor(stat.mtimeMs / 1000) * 1000 <= since;
}

/**
 * Sirve un archivo con validación condicional.
 * @returns {Promise<boolean>} true si respondió.
 */
export async function serveFile(req, res, filePath, { cacheControl, contentType, download = false, extraHeaders = {} } = {}) {
  let stat;
  try {
    stat = await fsp.stat(filePath);
  } catch {
    return false;
  }
  if (!stat.isFile()) return false;

  const etag = etagFor(stat);
  const type = contentType || contentTypeFor(filePath);
  const headers = {
    'Content-Type': type,
    ETag: etag,
    'Last-Modified': stat.mtime.toUTCString(),
    'Cache-Control': cacheControl || 'public, max-age=3600',
    'Accept-Ranges': 'bytes',
    ...extraHeaders,
  };
  if (download) {
    headers['Content-Disposition'] = `attachment; filename="${path.basename(filePath).replace(/"/g, '')}"`;
  }

  if (ifNoneMatch(req, etag) || ifModifiedSince(req, stat)) {
    delete headers['Content-Type'];
    res.writeHead(304, headers);
    res.end();
    return true;
  }

  headers['Content-Length'] = stat.size;
  if (req.method === 'HEAD') {
    res.writeHead(200, headers);
    res.end();
    return true;
  }

  res.writeHead(200, headers);
  await new Promise((resolve) => {
    const stream = fs.createReadStream(filePath);
    stream.on('error', () => {
      res.destroy();
      resolve();
    });
    res.on('close', resolve);
    stream.pipe(res);
  });
  return true;
}

/** Archivo de PUBLIC_DIR. Devuelve false si no existe (el llamador decide el 404). */
export async function servePublic(req, res, urlPath, options = {}) {
  const target = safeJoin(config.publicDir, urlPath);
  if (!target) return false;

  let stat;
  try {
    stat = await fsp.stat(target);
  } catch {
    return false;
  }

  if (stat.isDirectory()) {
    const indexPath = path.join(target, 'index.html');
    try {
      const indexStat = await fsp.stat(indexPath);
      if (!indexStat.isFile()) return false;
    } catch {
      return false;
    }
    return serveFile(req, res, indexPath, {
      ...options,
      cacheControl: options.cacheControl || 'no-cache, must-revalidate',
      contentType: MIME_TYPES['.html'],
    });
  }

  return serveFile(req, res, target, {
    ...options,
    cacheControl: options.cacheControl || cacheControlFor(urlPath),
  });
}

/** Sirve un archivo de STORAGE_DIR (dmg, update feed). */
export async function serveStorage(req, res, relativePath, { download = false } = {}) {
  const target = safeJoin(config.storageDir, relativePath);
  if (!target) return false;
  return serveFile(req, res, target, {
    cacheControl: 'public, max-age=300',
    contentType: contentTypeFor(target),
    download,
  });
}

/**
 * DMG con soporte Range. 404 JSON si no existe.
 */
export async function serveDmg(req, res, fileName) {
  if (!/^[A-Za-z0-9._-]+\.dmg$/.test(fileName)) {
    sendJson(res, 404, { error: 'Archivo no encontrado' });
    return;
  }
  // Acepta el .dmg en la raíz del volumen y en storage/download/ (ambas disposiciones).
  let filePath = null;
  let stat = null;
  for (const candidate of [
    safeJoin(config.storageDir, fileName),
    safeJoin(config.storageDir, `/download/${fileName}`),
  ]) {
    if (!candidate) continue;
    try {
      const info = await fsp.stat(candidate);
      if (info.isFile()) {
        filePath = candidate;
        stat = info;
        break;
      }
    } catch {
      // siguiente candidato
    }
  }
  if (!filePath || !stat || !stat.isFile()) {
    sendJson(res, 404, { error: 'Archivo no encontrado' });
    return;
  }

  const total = stat.size;
  const baseHeaders = {
    'Content-Type': 'application/octet-stream',
    'Content-Disposition': `attachment; filename="${fileName}"`,
    'Accept-Ranges': 'bytes',
    'Cache-Control': 'public, max-age=300',
    ETag: etagFor(stat),
    'Last-Modified': stat.mtime.toUTCString(),
  };

  if (req.method === 'HEAD') {
    res.writeHead(200, { ...baseHeaders, 'Content-Length': total });
    res.end();
    return;
  }

  const rangeHeader = String(req.headers.range || '').trim();
  if (rangeHeader) {
    const match = /^bytes=(\d*)-(\d*)$/.exec(rangeHeader);
    if (match) {
      let start = match[1] === '' ? null : Number(match[1]);
      let end = match[2] === '' ? null : Number(match[2]);
      if (start === null && end !== null) {
        // sufijo: últimos N bytes
        start = Math.max(0, total - end);
        end = total - 1;
      } else if (start !== null && end === null) {
        end = total - 1;
      }
      if (start !== null && end !== null && start <= end && start < total) {
        end = Math.min(end, total - 1);
        const length = end - start + 1;
        res.writeHead(206, {
          ...baseHeaders,
          'Content-Range': `bytes ${start}-${end}/${total}`,
          'Content-Length': length,
        });
        if (req.method === 'HEAD') {
          res.end();
          return;
        }
        await new Promise((resolve) => {
          const stream = fs.createReadStream(filePath, { start, end });
          stream.on('error', () => {
            res.destroy();
            resolve();
          });
          res.on('close', resolve);
          stream.pipe(res);
        });
        return;
      }
      res.writeHead(416, { ...baseHeaders, 'Content-Range': `bytes */${total}` });
      res.end();
      return;
    }
  }

  res.writeHead(200, { ...baseHeaders, 'Content-Length': total });
  await new Promise((resolve) => {
    const stream = fs.createReadStream(filePath);
    stream.on('error', () => {
      res.destroy();
      resolve();
    });
    res.on('close', resolve);
    stream.pipe(res);
  });
}
