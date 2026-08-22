// =====================
// API VERCEL — MEMOIRE DES RENSEIGNEMENTS CONNUS (Phase 1, 22 aout 2026)
// =====================
// renseignements_connus est volontairement inaccessible au role anon (RLS active, aucune
// policy -- voir migration_renseignements_connus.sql, execute en production le 22 aout 2026,
// confirme par un test direct : SELECT anon -> 200 [] ; INSERT anon -> 401 42501 "new row
// violates row-level security policy"). PJ et PNJ (ex. escorts de l'agence Roxanne Velours)
// n'ont pas tous de session propre -- seul un endpoint serveur, avec SUPABASE_SERVICE_ROLE_KEY
// (contourne RLS par nature, jamais exposee au client), peut lire/ecrire cette table. Meme
// patron que api/upload-org-avatar.js.
//
// Limite assumee (deja documentee dans upload-org-avatar.js et dans l'audit de securite dedie
// a ce chantier) : aucune authentification joueur reelle n'existe dans ce projet -- titulaire/
// source restent des declarations du client, non verifiees cryptographiquement. Ce que cet
// endpoint garantit reellement : la lecture/ecriture de renseignements_connus ne peut plus se
// faire par un appel direct trivial (SELECT * via la cle anon publique copiee du bundle JS).
// Refonte generale de l'authentification explicitement HORS PERIMETRE de ce lot.
//
// Phase 1 : UNE SEULE operation exposee -- 'enregistrer'. 'lister' et 'reactiver' ont ete
// retirees (revue de securite du 22 aout 2026, avant tout commit) : ce projet n'a AUCUNE
// authentification permettant de verifier que l'appelant est reellement le "titulaire" qu'il
// declare. Un endpoint 'lister(titulaire)' accessible depuis le navigateur aurait recree,
// via service_role, exactement le SELECT arbitraire que RLS etait cense empecher -- CORS ne
// protege en rien contre un appel direct curl/Postman. Meme raisonnement pour 'reactiver',
// qui aurait permis de designer arbitrairement une ligne appartenant a un autre titulaire.
// Elles reviendront dans un lot ulterieur, une fois un mecanisme de controle d'acces reel
// defini (hors perimetre de ce lot).
//
// 'enregistrer' reste seule exposee car elle ne permet AUCUNE lecture ni modification d'une
// ligne existante : id genere ici (jamais accepte du client), operation INSERT uniquement
// (aucun GET/PATCH dans ce fichier), la reponse ne contient que la ligne qui vient d'etre
// creee par CET appel -- aucun moyen de recuperer une ligne appartenant a quelqu'un d'autre
// via cette action. Limite globale assumee et non traitee ici (chantier securite separe) :
// sans authentification, un appelant determine peut toujours forger une ecriture au nom d'un
// titulaire arbitraire -- mais il ne peut RIEN lire en retour qu'il n'a pas lui-meme ecrit a
// l'instant, ce qui est l'objectif minimal de ce lot.
//
// id/jour_derniere_reactivation/jour_expiration sont TOUJOURS calcules ici, jamais acceptes
// du client (jour_expiration manipulable donnerait un souvenir immortel ou deja perime a
// volonte). DUREE_MEMOIRE_JOURS = 90 : seule valeur reellement validee par le game design
// (audit dedie, ~90 jours REELS, state.day avance de 1 par jour reel).

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jxpwoosmmhohoihxpbuc.supabase.co';
const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || null;

const TABLE = 'renseignements_connus';
const DUREE_MEMOIRE_JOURS = 90;

const MODES_ACQUISITION = [
  'action_personnelle', 'observation', 'document_consulte', 'confidence', 'transmission',
  'interrogatoire'
];

const ALLOWED_ORIGIN = 'https://res-publica.vercel.app';

function serviceHeaders() {
  return {
    'Content-Type': 'application/json',
    'apikey': SUPABASE_SERVICE_ROLE,
    'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE}`
  };
}

function texteValide(v, maxLen) {
  return typeof v === 'string' && v.trim().length > 0 && v.length <= maxLen;
}

function jourValide(v) {
  return Number.isInteger(v) && v >= 1 && v <= 100000;
}

async function enregistrer(body, res) {
  const { titulaire, contenu, cible, categorie, source, mode_acquisition, fait_objectif_ref, jour_acquisition } = body;
  if (!texteValide(titulaire, 200) || !texteValide(contenu, 2000) || !texteValide(source, 200)) {
    return res.status(400).json({ error: 'Champs obligatoires invalides.' });
  }
  if (cible !== undefined && cible !== null && !texteValide(cible, 200)) {
    return res.status(400).json({ error: 'cible invalide.' });
  }
  if (!texteValide(categorie, 100)) {
    return res.status(400).json({ error: 'categorie invalide.' });
  }
  if (!MODES_ACQUISITION.includes(mode_acquisition)) {
    return res.status(400).json({ error: 'mode_acquisition invalide.' });
  }
  if (fait_objectif_ref !== undefined && fait_objectif_ref !== null && !texteValide(fait_objectif_ref, 200)) {
    return res.status(400).json({ error: 'fait_objectif_ref invalide.' });
  }
  if (!jourValide(jour_acquisition)) {
    return res.status(400).json({ error: 'jour_acquisition invalide.' });
  }

  // id genere ici, jamais fourni par le client -- meme principe que le chemin Storage de
  // upload-org-avatar.js (namespace serveur, aucune collision possible).
  const row = {
    id: 'rc_' + Date.now() + '_' + Math.floor(Math.random() * 1000000),
    titulaire,
    contenu,
    cible: cible || null,
    categorie,
    source,
    mode_acquisition,
    fait_objectif_ref: fait_objectif_ref || null,
    jour_acquisition,
    jour_derniere_reactivation: jour_acquisition,
    jour_expiration: jour_acquisition + DUREE_MEMOIRE_JOURS
  };

  const r = await fetch(`${SUPABASE_URL}/rest/v1/${TABLE}`, {
    method: 'POST',
    headers: { ...serviceHeaders(), 'Prefer': 'return=representation' },
    body: JSON.stringify(row)
  }).catch(() => null);
  if (!r || !r.ok) return res.status(502).json({ error: "Le renseignement n'a pas pu être enregistré." });
  const rows = await r.json();
  return res.status(200).json({ ok: true, id: row.id, row: rows?.[0] || row });
}

export default async function handler(req, res) {
  const origin = req.headers.origin;
  if (origin === ALLOWED_ORIGIN) {
    res.setHeader('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  if (!SUPABASE_SERVICE_ROLE) {
    // Configuration Vercel pas encore terminee -- echec propre et explicite, jamais une
    // tentative d'ecriture avec une cle absente (meme discipline que upload-org-avatar.js).
    return res.status(503).json({ error: 'Mémoire indisponible : configuration serveur incomplète.' });
  }

  const body = req.body || {};
  if (body.action === 'enregistrer') return enregistrer(body, res);
  return res.status(400).json({ error: 'action invalide.' });
}
