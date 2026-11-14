import { readFileSync, writeFileSync, renameSync } from 'node:fs';
import { resolve } from 'node:path';

const dir = resolve(import.meta.dirname, '..', 'dist-preview');
const out = resolve(dir, 'StackDock-Preview.html');
renameSync(resolve(dir, 'preview.html'), out);
const html = readFileSync(out, 'utf8');
const ext = html.match(/<script[^>]+src=["'](?!data:)[^"']+["']/g);
if (ext) {
  console.error('✗ Quedan scripts externos en la vista previa:', ext);
  process.exit(1);
}
writeFileSync(out, html);
console.log(`preview ✓ ${out} (${(html.length / 1024).toFixed(0)} KB)`);
