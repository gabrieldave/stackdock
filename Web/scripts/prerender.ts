import { mkdirSync, writeFileSync, existsSync, readFileSync } from 'node:fs';
import { resolve, extname } from 'node:path';
import { render } from '../src/render';
import { funnel } from '../src/config/funnel';

const root = resolve(import.meta.dirname, '..');
const pub = (p: string) => resolve(root, 'public', p.replace(/^\//, ''));
const MIME: Record<string, string> = { '.webp': 'image/webp', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.ico': 'image/x-icon' };

const siteAsset = (p: string) => p;
const previewAsset = (p: string) => {
  const f = pub(p);
  if (!existsSync(f)) return p; // p. ej. capturas del Panel 4.0.6 aún no copiadas → wireframe
  return `data:${MIME[extname(f)] ?? 'application/octet-stream'};base64,${readFileSync(f).toString('base64')}`;
};

mkdirSync(resolve(root, 'es'), { recursive: true });
writeFileSync(resolve(root, 'index.html'), render({ locale: 'en', mode: 'site', asset: siteAsset }));
writeFileSync(resolve(root, 'es/index.html'), render({ locale: 'es', mode: 'site', asset: siteAsset }));
writeFileSync(resolve(root, 'preview.html'), render({ locale: 'en', mode: 'preview', asset: previewAsset }));

const b = funnel.siteUrl;
const today = new Date().toISOString().slice(0, 10);
const url = (loc: string) => `  <url>
    <loc>${loc}</loc>
    <lastmod>${today}</lastmod>
    <xhtml:link rel="alternate" hreflang="en" href="${b}/"/>
    <xhtml:link rel="alternate" hreflang="es" href="${b}/es/"/>
    <xhtml:link rel="alternate" hreflang="x-default" href="${b}/"/>
  </url>`;
writeFileSync(
  pub('sitemap.xml'),
  `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${url(`${b}/`)}\n${url(`${b}/es/`)}\n</urlset>\n`,
);
writeFileSync(pub('robots.txt'), `User-agent: *\nAllow: /\nDisallow: /api/\n\nSitemap: ${b}/sitemap.xml\n`);
console.log('prerender ✓ index.html · es/index.html · preview.html · sitemap.xml · robots.txt');
