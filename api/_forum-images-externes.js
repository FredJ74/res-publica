// Forum, images extérieures (Fred, 22/11/2026, nuit, point 7) : les images extérieures déjà présentes dans les messages
// (dont celui de Peter Kropotkine du 21/11 à 03:33) sont recopiées dans le stockage « forum-images » (dossier externes/)
// et leurs liens remplacés. Seul le lien de l'image change : le texte des messages n'est pas touché.
// Appelé par le traitement de nuit (api/cron-minuit.js, clé de service). Idempotent : une image déjà recopiée garde
// le même nom (empreinte de son adresse) ; un message sans image extérieure n'est pas réécrit.
import { createHash } from 'node:crypto';
import { SUPABASE_URL, SUPABASE_SERVICE_ROLE, sbEnTetes } from './_supabase.js';

const SEAU = 'forum-images', MAX = 5 * 1024 * 1024;
const TYPES = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp', 'image/gif': 'gif' };
const PUBLIC = SUPABASE_URL + '/storage/v1/object/public/' + SEAU + '/';

const html = u => u.replace(/&/g, '&amp;');
const brut = u => u.replace(/&amp;/g, '&');

// Adresses d'images d'un message : <img src="…"> dans le texte, champs url/src des blocs et de la mise en page.
export function imagesExterieures(post) {
  const vues = new Set();
  const ajouter = u => { const v = brut(String(u || '').trim()); if (/^https?:\/\//i.test(v) && !v.startsWith(SUPABASE_URL)) vues.add(v); };
  for (const m of String(post.content || '').matchAll(/<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["']/gi)) ajouter(m[1]);
  const parcourir = o => {
    if (Array.isArray(o)) return o.forEach(parcourir);
    if (!o || typeof o !== 'object') return;
    for (const [k, v] of Object.entries(o)) {
      if ((k === 'url' || k === 'src') && typeof v === 'string' && (o.type === 'image' || /^image/i.test(String(o.type || 'image')))) ajouter(v);
      else if (typeof v === 'string' && k === 'html_fallback') for (const m of v.matchAll(/<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["']/gi)) ajouter(m[1]);
      else if (typeof v === 'object') parcourir(v);
    }
  };
  parcourir(post.content_blocks); parcourir(post.content_layout);
  return [...vues];
}

// Remplace une adresse (forme brute et forme HTML « &amp; ») dans le texte et dans le JSON, rien d'autre.
export function remplacerLiens(post, table) {
  let content = String(post.content ?? ''), blocs = post.content_blocks == null ? null : JSON.stringify(post.content_blocks),
      mise = post.content_layout == null ? null : JSON.stringify(post.content_layout);
  for (const [ancien, nouveau] of Object.entries(table)) {
    for (const forme of new Set([ancien, html(ancien)])) {
      content = content.split(forme).join(nouveau);
      const j = JSON.stringify(forme).slice(1, -1), jn = JSON.stringify(nouveau).slice(1, -1);
      if (blocs) blocs = blocs.split(j).join(jn);
      if (mise) mise = mise.split(j).join(jn);
    }
  }
  const maj = {};
  if (content !== String(post.content ?? '')) maj.content = content;
  if (blocs !== null && blocs !== JSON.stringify(post.content_blocks)) maj.content_blocks = JSON.parse(blocs);
  if (mise !== null && mise !== JSON.stringify(post.content_layout)) maj.content_layout = JSON.parse(mise);
  return maj;
}

async function telecharger(url, fetchImpl) {
  const ctrl = new AbortController(), minuterie = setTimeout(() => ctrl.abort(), 10000);
  try {
    const r = await fetchImpl(url, { signal: ctrl.signal, redirect: 'follow', headers: { 'User-Agent': 'HumanGambit-forum/1.0' } });
    if (!r.ok) return { raison: 'http_' + r.status };
    const type = String(r.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
    if (!TYPES[type]) return { raison: 'pas_une_image' };
    const corps = Buffer.from(await r.arrayBuffer());
    if (corps.length > MAX) return { raison: 'trop_lourde' };
    return { type, corps };
  } catch (e) { return { raison: 'telechargement_impossible' }; } finally { clearTimeout(minuterie); }
}

// Budget de temps : le traitement de nuit a 120 s en tout ; la recopie s'arrête après 20 s et reprend la nuit suivante.
export async function recopierImagesForumExterieures({ fetchImpl = fetch, limite = 20, budgetMs = 20000 } = {}) {
  const fin = Date.now() + budgetMs;
  if (!SUPABASE_SERVICE_ROLE) return { ok: false, raison: 'cle_service_absente' };
  const h = sbEnTetes({ service: true });
  const lr = await fetchImpl(SUPABASE_URL + '/rest/v1/forum_posts?select=id,content,content_blocks,content_layout&order=created_at.asc&limit=2000', { headers: h });
  if (!lr.ok) return { ok: false, raison: 'lecture_messages_' + lr.status };
  const posts = await lr.json();
  const table = {}, echecs = [];
  let images = 0, messages = 0;
  for (const post of posts) {
    const urls = imagesExterieures(post).filter(u => !(u in table));
    for (const u of urls) {
      if (images >= limite || Date.now() > fin) break;
      const t = await telecharger(u, fetchImpl);
      if (!t.corps) { echecs.push({ post: post.id, url: u, raison: t.raison }); continue; }
      const nom = 'externes/' + createHash('sha1').update(u).digest('hex') + '.' + TYPES[t.type];
      const env = await fetchImpl(SUPABASE_URL + '/storage/v1/object/' + SEAU + '/' + nom, {
        method: 'POST', body: t.corps,
        headers: { apikey: SUPABASE_SERVICE_ROLE, Authorization: 'Bearer ' + SUPABASE_SERVICE_ROLE, 'Content-Type': t.type, 'x-upsert': 'true' } });
      if (!env.ok) { echecs.push({ post: post.id, url: u, raison: 'stockage_' + env.status }); continue; }
      table[u] = PUBLIC + nom; images++;
    }
    const maj = remplacerLiens(post, table);
    if (Object.keys(maj).length) {
      const up = await fetchImpl(SUPABASE_URL + '/rest/v1/forum_posts?id=eq.' + encodeURIComponent(post.id), {
        method: 'PATCH', headers: { ...h, Prefer: 'return=minimal' }, body: JSON.stringify(maj) });
      if (up.ok) messages++; else echecs.push({ post: post.id, raison: 'mise_a_jour_' + up.status });
    }
  }
  return { ok: true, images, messages, echecs };
}
