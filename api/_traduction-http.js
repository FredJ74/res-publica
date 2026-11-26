/* Route HTTP de la traduction des textes de joueurs (décision n° 10 de Fred, 26/11/2026 : le forum d'abord, puis les rumeurs
 * de la chronique). Greffée sur /api/chat?mode=traduction (vercel.json : /api/traduction) pour rester à 12 fonctions.
 * Le client n'envoie JAMAIS le texte : seulement { type, id, field, langue }. L'original est relu sous le JWT du lecteur et
 * les politiques RLS (_traduction-lecture-rls.js), puis le cache et le quota persistants (migration 20261126300000) sont
 * consultés avant tout appel payant (_traduction-contenu.js). Le quota d'IA des dialogues n'est pas entamé : la traduction
 * a son propre quota quotidien par compte (rp_i18n_configuration).
 */
import { traduireContenu } from './_traduction-contenu.js';
import { creerDependancesTraduction } from './_traduction-dependances.js';
import { joueurAuthentifie } from './_deepseek.js';

const ORIGINES = new Set(['https://res-publica.vercel.app', 'https://human-gambit.com', 'https://www.human-gambit.com']);

function envoyer(res, statut, corps) {
  res.statusCode = statut;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.end(JSON.stringify(corps));
}

async function lireCorps(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  if (typeof req.body === 'string') { try { return JSON.parse(req.body); } catch { return null; } }
  let brut = '';
  for await (const morceau of req) { brut += morceau; if (brut.length > 4096) return null; }
  try { return JSON.parse(brut || '{}'); } catch { return null; }
}

async function handlerTraduction(req, res, { traduire = traduireContenu, dependances = creerDependancesTraduction } = {}) {
  const origine = req.headers.origin;
  if (origine && ORIGINES.has(origine)) { res.setHeader('Access-Control-Allow-Origin', origine); res.setHeader('Vary', 'Origin'); }
  if (req.method === 'OPTIONS') {
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    return envoyer(res, 204, {});
  }
  if (req.method !== 'POST') return envoyer(res, 405, { ok: false, raison: 'methode' });
  const corps = await lireCorps(req);
  if (!corps || typeof corps !== 'object') return envoyer(res, 400, { ok: false, raison: 'requete_invalide' });
  const { type, id, field, langue } = corps;
  const deps = dependances(req, { authentifier: (r) => joueurAuthentifie(r, { sansQuota: true }) });
  if (!deps) return envoyer(res, 503, { ok: false, raison: 'non_configure' });
  let r;
  try { r = await traduire({ type, id, field, langueCible: langue }, deps); }
  catch { return envoyer(res, 503, { ok: false, raison: 'indisponible' }); }
  // L'original n'est jamais renvoyé (le client l'a déjà, lu sous les mêmes droits) : seulement la traduction.
  if (!r || r.ok !== true) return envoyer(res, 200, { ok: false, raison: (r && r.raison) || 'indisponible' });
  return envoyer(res, 200, { ok: true, traduit: r.traduit, depuisCache: r.fromCache === true });
}

export { handlerTraduction };
