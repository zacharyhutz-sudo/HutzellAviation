import type { APIRoute } from 'astro';
export const GET: APIRoute = ({ site }) => {
  const root = new URL(import.meta.env.BASE_URL, site!);
  const routes = ['', 'aircraft/', 'pricing/', 'about/', 'availability/'];
  const escapeXml = (value: string) => value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&apos;');
  const urls = routes.map(route => `<url><loc>${escapeXml(new URL(route, root).href)}</loc></url>`).join('');
  return new Response(`<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls}</urlset>`, { headers: { 'Content-Type': 'application/xml; charset=utf-8' } });
};
