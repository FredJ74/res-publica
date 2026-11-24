// =================================================================================================
// PNJ GUIDE DES NOUVEAUX JOUEURS (Fred, 24/11/2026, purge A.10) — /api/chat?mode=guide (aucune nouvelle fonction Vercel)
// =================================================================================================
// LE SERVEUR SQL DÉCIDE DE TOUT (migration 20261124106000_pnj_guide) : qui écrit (la journaliste du pays ou l'habitant de
// la ville), quand (calendrier, plafonds, délais), quelle piste (type d'activité, PNJ référent lu dans pnj_referents, lieu
// tenu par un PNJ, commerce actif tiré au hasard). Ce module ne fait que :
//   1. demander la piste réservée (guide_reserver, sous le JETON du joueur) ;
//   2. la faire mettre en mots par DeepSeek dans la voix du PNJ (2 ou 3 phrases, une seule piste) ;
//   3. FILTRER : un texte qui cite un nom de parti ou de joueur est refusé (liste lue par la clé de service,
//      guide_noms_interdits) ; une seconde tentative, puis un texte de secours construit sans IA ;
//   4. publier (guide_publier_service, clé de service seulement) dans le chat, auteur « pnj:<nom> ».
// Réponses : action « repondre » — le nouveau écrit au PNJ ; guide_reponse_autoriser (jeton du joueur) pose son message et
// tient le plafond (5 par jour et par PNJ) ; la réponse suit le même cadre et le même filtre.
// Sans clé de service, rien n'est publié (refus nommé) : jamais un message non filtré.
import { appelDeepSeek, joueurAuthentifie } from './_deepseek.js';
import { sbTransportRpc, identiteServeurDisponible } from './_supabase.js';
import { TOUS_PROFILS } from './_pnj-profils.js';

const VILLES = { republic: { capitale: 'Luthécia', ville_a: 'Port-Sainte-Marie', ville_b: 'Montrouge' },
                 soviet: { capitale: 'Novomirsk', ville_a: 'Starovka', ville_b: 'Krasnov' } };
const PAYS = { republic: 'Républia', soviet: 'Sovarka' };
const MAX_MESSAGE = 1000;

const sansAccents = s => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
const echapperRegex = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// Un nom (parti ou joueur) apparaît-il dans le texte ? Comparaison sans accents ni casse, sur mots entiers.
export function nomInterditCite(texte, noms, autorises) {
  const t = ' ' + sansAccents(texte).replace(/[^a-z0-9]+/g, ' ') + ' ';
  const permis = new Set((autorises || []).map(sansAccents));
  for (const brut of noms || []) {
    const n = sansAccents(brut).replace(/[^a-z0-9]+/g, ' ').trim();
    if (n.length < 3 || permis.has(sansAccents(brut))) continue;
    if (new RegExp(' ' + echapperRegex(n) + ' ').test(t)) return brut;
  }
  return null;
}

// Au plus trois phrases (le PNJ écrit court).
export function troisPhrases(texte) {
  const propre = String(texte || '').replace(/\s+/g, ' ').replace(/^["«\s]+|["»\s]+$/g, '').trim();
  const phrases = propre.match(/[^.!?…]+[.!?…]+["»]?|[^.!?…]+$/g) || [propre];
  return phrases.slice(0, 3).join(' ').replace(/\s+/g, ' ').trim().slice(0, 600);
}

// La piste en clair, telle que le serveur l'a choisie (référent et commerce résolus).
export function decrirePiste(piste) {
  const p = piste || {};
  const ref = p.referent && TOUS_PROFILS[p.referent];
  let ou;
  if (p.type === 'referent' && ref) ou = `aller voir ${ref.nom}, PNJ référent${ref.lieu ? ' (' + ref.lieu + ')' : ''}`;
  else if (p.type === 'commerce' && p.commerce && p.commerce.enseigne) ou = `passer au commerce « ${p.commerce.enseigne} »`;
  else ou = `aller à ${p.lieu || 'la mairie'}`;
  return { activite: p.activite || '', ou, referentNom: ref ? ref.nom : null, enseigne: p.commerce ? p.commerce.enseigne : null };
}

// Texte de secours, sans IA (même piste) : utilisé si DeepSeek échoue ou si son texte est refusé par le filtre.
export function texteSecours(piste) {
  const d = decrirePiste(piste);
  const ou = d.ou.charAt(0).toUpperCase() + d.ou.slice(1);
  return troisPhrases(`${d.activite} ${ou} : on t'y expliquera tout.`);
}

function cadre(profil, ctx) {
  const p = TOUS_PROFILS[profil] || {};
  const ville = (VILLES[ctx.pays] || {})[ctx.ville] || '';
  return [
    p.identite || `Tu es ${p.nom || 'un habitant'}.`,
    p.caractere || '',
    `TU ES UN PNJ (personnage non joueur) et tu écris un court message de chat à ${ctx.personnage}, un nouveau venu arrivé depuis peu${ville ? ' à ' + ville : ''}${PAYS[ctx.pays] ? ', en ' + PAYS[ctx.pays] : ''}.`,
    `RÈGLES ABSOLUES : 2 ou 3 phrases, pas plus. UNE SEULE piste, celle qu'on te donne : n'en ajoute aucune autre. Tu orientes vers un TYPE d'activité, un lieu ou un PNJ référent. Tu ne nommes JAMAIS un parti politique, ni aucun autre joueur, et tu ne recommandes aucun parti. Tu n'inventes ni règle, ni prix, ni chiffre. Pas de liste, pas de titre, pas de guillemets : seulement ton message.`
  ].filter(Boolean).join('\n');
}

function consignePiste(r) {
  const d = decrirePiste(r.piste);
  const n = r.nouveau || {};
  const lignes = [`LA PISTE À DONNER : ${d.activite} Concrètement : ${d.ou}.`];
  if (n.chemin) lignes.push(`À l'interview, il a dit vouloir suivre ce chemin : ${n.chemin}${n.mot ? ` (ses mots : « ${String(n.mot).slice(0, 200)} »)` : ''}.`);
  if (n.carriere) lignes.push(`Sa carrière : ${n.carriere}.`);
  const m = r.monde || {};
  if (m.elections_en_cours > 0) lignes.push(`Des élections sont en cours dans le pays.`);
  if (typeof m.partis === 'number') lignes.push(m.partis > 0 ? `Il existe ${m.partis} parti(s) dans le pays (ne les nomme pas).` : `Aucun parti n'existe encore dans le pays.`);
  if (r.voix === 'journaliste') lignes.push(`Tu l'as interviewé à son arrivée : tu reprends contact, comme une connaissance.`);
  lignes.push(`Écris maintenant ton message (2 ou 3 phrases).`);
  return lignes.join('\n');
}

export function creerHandlerGuide(deps = {}) {
  const rpc = deps.rpc || ((fn, params, options) => sbTransportRpc(fn, params, options));
  const ia = deps.ia || appelDeepSeek;
  const auth = deps.auth || (req => joueurAuthentifie(req, { signal: AbortSignal.timeout(4000) }));
  const serviceDispo = deps.serviceDispo || identiteServeurDisponible;
  const un = env => (env && env.etat === 'ok') ? (Array.isArray(env.donnees) ? env.donnees[0] : env.donnees) : null;

  async function nomsInterdits() {
    const v = un(await rpc('guide_noms_interdits', {}, { service: true }));
    if (!v) return null;
    return [].concat(v.partis || [], v.joueurs || []);
  }
  // Met en mots, filtre, et retombe sur le secours si besoin. Rend toujours un texte sûr (ou null si même le secours échoue).
  async function rediger(systeme, messages, noms, autorises, secours) {
    for (let essai = 0; essai < 2; essai++) {
      const r = await ia({ systeme: systeme + (essai ? '\nATTENTION : ton message précédent citait un nom interdit. Aucun nom de parti ni de joueur.' : ''),
        messages, maxTokens: 180, timeoutMs: 12000 }).catch(() => null);
      if (!r || !r.ok || !r.texte) break;
      const t = troisPhrases(r.texte);
      if (t && !nomInterditCite(t, noms, autorises)) return { texte: t, source: 'ia' };
    }
    const s = troisPhrases(secours || '');
    if (s && !nomInterditCite(s, noms, autorises)) return { texte: s, source: 'secours' };
    return null;
  }

  return async function handlerGuide(req, res) {
    if (req.method === 'OPTIONS') return res.status(200).end();
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
    const b = req.body && typeof req.body === 'object' ? req.body : {};
    if (!['prochain', 'repondre'].includes(b.action)) return res.status(400).json({ error: 'Action inconnue.' });
    const u = await auth(req);
    if (!u) return res.status(401).json({ error: 'Authentification requise.' });
    if (!serviceDispo()) return res.status(503).json({ ok: false, raison: 'service_indisponible' });

    if (b.action === 'prochain') {
      const r = un(await rpc('guide_reserver', {}, { jeton: u.jeton }));
      if (!r || r.ok !== true) return res.status(200).json({ ok: false, raison: (r && r.raison) || 'indisponible' });
      const noms = await nomsInterdits();
      if (!noms) return res.status(503).json({ ok: false, raison: 'filtre_indisponible' });
      const d = decrirePiste(r.piste);
      const autorises = [r.pnj, r.personnage, d.referentNom].filter(Boolean);
      const texte = await rediger(cadre(r.profil, r), [{ role: 'user', content: consignePiste(r) }], noms, autorises, texteSecours(r.piste));
      if (!texte) return res.status(200).json({ ok: false, raison: 'texte_refuse' });
      const p = un(await rpc('guide_publier_service', { p_id: r.id, p_texte: texte.texte }, { service: true }));
      if (!p || p.ok !== true) return res.status(200).json({ ok: false, raison: (p && p.raison) || 'publication_refusee' });
      return res.status(200).json({ ok: true, pnj: r.pnj, voix: r.voix, conversation: p.conversation, source: texte.source });
    }

    // Réponse du PNJ au nouveau.
    const pnj = typeof b.pnj === 'string' ? b.pnj.slice(0, 80) : '';
    const message = typeof b.message === 'string' ? b.message.trim() : '';
    if (!pnj || !message || message.length > MAX_MESSAGE) return res.status(400).json({ error: 'Message invalide.' });
    const r = un(await rpc('guide_reponse_autoriser', { p_pnj: pnj, p_message: message }, { jeton: u.jeton }));
    if (!r || r.ok !== true) return res.status(200).json({ ok: false, raison: (r && r.raison) || 'indisponible' });
    const noms = await nomsInterdits();
    if (!noms) return res.status(503).json({ ok: false, raison: 'filtre_indisponible' });
    const d = decrirePiste(r.piste);
    const autorises = [r.pnj, r.personnage, d.referentNom].filter(Boolean);
    const historique = (r.historique || []).slice(-8).map(x => ({ role: x.pnj ? 'assistant' : 'user', content: String(x.texte || '').slice(0, 1000) }));
    const systeme = cadre(r.profil, r) + `\nIL T'A RÉPONDU : tu lui réponds, dans le même cadre (2 ou 3 phrases, jamais de parti ni de joueur). La piste que tu lui avais donnée : ${d.activite} (${d.ou}).`;
    const secours = d.referentNom ? `Là-dessus, ${d.referentNom} t'en dira bien plus que moi.` : `Là-dessus, les référents de la ville t'en diront bien plus que moi.`;
    const texte = await rediger(systeme, historique.length ? historique : [{ role: 'user', content: message }], noms, autorises, secours);
    if (!texte) return res.status(200).json({ ok: false, raison: 'texte_refuse' });
    const p = un(await rpc('guide_reponse_publier_service', { p_personnage: r.personnage, p_pnj: r.pnj, p_texte: texte.texte }, { service: true }));
    if (!p || p.ok !== true) return res.status(200).json({ ok: false, raison: 'publication_refusee' });
    return res.status(200).json({ ok: true, source: texte.source });
  };
}

export const handlerGuide = creerHandlerGuide();
