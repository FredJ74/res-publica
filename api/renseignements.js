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
//
// Phase 2 (22 aout 2026) : ajoute UNE operation metier supplementaire, 'tirer_confidence_escort'
// -- PAS un 'lister' generique reintroduit par la bande. Difference essentielle : la liste des
// renseignements eligibles du client est chargee ICI, cote serveur, pour executer le tirage
// pondere, mais n'est JAMAIS renvoyee a l'appelant HTTP -- la reponse ne contient au maximum
// que {confidenceObtenue:true|false}, jamais le contenu tire ni aucune metadonnee dessus (pas
// meme la categorie). Consequence directe : meme un appelant qui forge client/escort/chaEscort
// ne peut RIEN lire en retour au-dela d'un booleen -- il peut au pire forcer une ECRITURE
// (limite globale deja acceptee ailleurs dans ce projet, non un nouveau probleme), jamais une
// LECTURE. Le roll (Math.random()) est TOUJOURS execute ici. Correctif du 22 aout 2026 (revue
// avant GO) : le TAUX COMPLET est desormais calcule ici, jamais accepte du client. CHA_client/
// pays/ville/jour sont lus directement dans personnages (colonnes stats/country/current_city/
// day, jamais dans le corps de la requete) ; la piete passe par indices_villes (Republia) avec
// repli neutre pour les autres empires (voir tirerConfidenceEscort). Seul chaEscort reste
// transmis par le client -- aucune source serveur pour les stats des PNJ (escorts sans ligne
// personnages, PNJ_STATS_PAR_JOB/PNJ_STATS_NOMMES vivent uniquement dans data.js, cote client,
// jamais charge par cette fonction Vercel) ; c'est une donnee PUBLIQUE et non secrete (visible
// de tous dans le bundle JS), et le taux final reste de toute facon reborne [5,90] quelle que
// soit la valeur recue -- dupliquer ici la table PNJ_STATS_PAR_JOB introduirait une deuxieme
// source de verite pour une constante de design (risque de derive silencieuse si data.js
// change), sans reduire le plafond de securite deja garanti par le bornage final.

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

// Poids d'importance par categorie -- deterministe, pas une estimation IA. Table volontairement
// courte (8 valeurs), coherente avec les categories deja cadrees par le game design (audit
// dedie). Toute categorie non listee (taxonomie ouverte, voir migration_renseignements_
// connus.sql -- "categorie" n'a pas de CHECK) retombe sur le poids minimal 'autre', jamais 0.
const POIDS_IMPORTANCE_CATEGORIE = {
  acte_illegal: 5,
  escort_frequentation: 4,
  achat_arme: 3,
  achat_terrain: 3,
  achat_commerce: 3,
  gros_achat: 3,
  recrutement_pnj: 2,
  autre: 1
};
function poidsImportance(categorie) {
  return POIDS_IMPORTANCE_CATEGORIE[categorie] ?? POIDS_IMPORTANCE_CATEGORIE.autre;
}

// Poids de recence -- lineaire sur jour_derniere_reactivation, jamais nul meme au bord de
// l'expiration (0.2 minimum a age=DUREE_MEMOIRE_JOURS, 1.0 a age=0) : "un renseignement encore
// vivant dans les 90 jours ne doit jamais avoir un poids nul" (regle de design validee).
function poidsRecence(jourDerniereReactivation, jourActuel) {
  const age = Math.max(0, Math.min(DUREE_MEMOIRE_JOURS, jourActuel - (jourDerniereReactivation || jourActuel)));
  return 1 - 0.8 * (age / DUREE_MEMOIRE_JOURS);
}

async function tirerConfidenceEscort(body, res) {
  const { client, escort, chaEscort } = body;
  if (!texteValide(client, 200) || !texteValide(escort, 200)) {
    return res.status(400).json({ error: 'Paramètres invalides.' });
  }
  // Borne large mais reelle (echelle CHA confirmee 1-20, voir audit dedie) -- valeur publique
  // et non secrete (data.js), simple garde-fou contre NaN/Infinity/valeurs absurdes.
  const chaEscortSur = Math.max(1, Math.min(20, Number.isFinite(chaEscort) ? chaEscort : 10));

  // Etat REELLEMENT persiste du client, lu ici, jamais accepte du corps de la requete --
  // seul le nom "client" reste une declaration non authentifiee (limite globale acceptee,
  // voir en-tete de fichier). Tout ce qui suit vient de personnages, jamais du client HTTP.
  const rPerso = await fetch(
    `${SUPABASE_URL}/rest/v1/personnages?name=eq.${encodeURIComponent(client)}&select=stats,country,current_city,day`,
    { headers: serviceHeaders() }
  ).catch(() => null);
  if (!rPerso || !rPerso.ok) return res.status(200).json({ ok: true, confidenceObtenue: false });
  const lignesPerso = await rPerso.json();
  const perso = Array.isArray(lignesPerso) ? lignesPerso[0] : null;
  if (!perso) return res.status(200).json({ ok: true, confidenceObtenue: false });

  const chaClient = (perso.stats && Number.isFinite(perso.stats.CHA)) ? perso.stats.CHA : 8;
  const pays = perso.country || 'republic';
  const ville = perso.current_city || 'capitale';
  const jourActuel = Number.isInteger(perso.day) ? perso.day : 1;

  // Piete : Republia -> indices_villes (Supabase, source reelle, meme table que le client
  // utilise deja via getIndiceVille). Autres empires -> INDICES_NATIONAUX n'existe que cote
  // client (data.js, constante statique) -- repli neutre (40, meme valeur par defaut que
  // INDICE_VILLE_DEFAUT.piete cote client) plutot que dupliquer cette table ici. Le Bar/
  // Roxanne Velours n'existant aujourd'hui qu'a Republia, ce repli n'affecte aucun cas reel.
  let pieteVille = 40;
  if (pays === 'republic') {
    const rIndices = await fetch(
      `${SUPABASE_URL}/rest/v1/indices_villes?id=eq.${encodeURIComponent('republic_' + ville)}&select=data`,
      { headers: serviceHeaders() }
    ).catch(() => null);
    if (rIndices && rIndices.ok) {
      const lignesIndices = await rIndices.json();
      const d = Array.isArray(lignesIndices) && lignesIndices[0] ? lignesIndices[0].data : null;
      if (d && Number.isFinite(d.piete)) pieteVille = d.piete;
    }
  }

  const modPiete = Math.max(-5, Math.min(5, (pieteVille - 50) / 10));
  const taux = Math.max(5, Math.min(90, Math.round(40 + 3 * (chaEscortSur - chaClient) + modPiete)));

  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll > taux) {
    return res.status(200).json({ ok: true, confidenceObtenue: false });
  }

  // Renseignements ENCORE valides du client -- charges ICI uniquement pour le tirage, jamais
  // renvoyes a l'appelant (voir commentaire d'en-tete du fichier). jourActuel vient de
  // personnages.day (ci-dessus), jamais du corps de la requete.
  const filtre = `titulaire=eq.${encodeURIComponent(client)}&jour_expiration=gte.${jourActuel}&limit=200`;
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${TABLE}?${filtre}`, { headers: serviceHeaders() }).catch(() => null);
  if (!r || !r.ok) return res.status(200).json({ ok: true, confidenceObtenue: false });
  const eligibles = await r.json();
  if (!Array.isArray(eligibles) || eligibles.length === 0) {
    return res.status(200).json({ ok: true, confidenceObtenue: false });
  }

  const poids = eligibles.map(row => poidsRecence(row.jour_derniere_reactivation, jourActuel) * poidsImportance(row.categorie));
  const total = poids.reduce((s, p) => s + p, 0);
  let tirage = Math.random() * total;
  let choisi = eligibles[eligibles.length - 1];
  for (let i = 0; i < eligibles.length; i++) {
    tirage -= poids[i];
    if (tirage <= 0) { choisi = eligibles[i]; break; }
  }

  // Provenance : Rita ne memorise jamais "Bernard a achete une arme" comme verite objective --
  // uniquement "<client> a confie : « ... »", source = client (transmetteur immediat), jamais
  // la chaine complete si le client lui-meme le tenait d'un tiers (regle de design validee,
  // meme doctrine que le reste de ce chantier). fait_objectif_ref est copiee telle quelle
  // (simple pointeur optionnel deja non-probant, voir migration) -- jamais transformee en
  // preuve pour l'escort.
  const nouvelleLigne = {
    id: 'rc_' + Date.now() + '_' + Math.floor(Math.random() * 1000000),
    titulaire: escort,
    contenu: client + ' a confié : « ' + choisi.contenu + ' »',
    cible: choisi.cible || null,
    categorie: choisi.categorie,
    source: client,
    mode_acquisition: 'confidence',
    fait_objectif_ref: choisi.fait_objectif_ref || null,
    jour_acquisition: jourActuel,
    jour_derniere_reactivation: jourActuel,
    jour_expiration: jourActuel + DUREE_MEMOIRE_JOURS
  };

  const rInsert = await fetch(`${SUPABASE_URL}/rest/v1/${TABLE}`, {
    method: 'POST',
    headers: { ...serviceHeaders(), 'Prefer': 'return=representation' },
    body: JSON.stringify(nouvelleLigne)
  }).catch(() => null);
  if (!rInsert || !rInsert.ok) return res.status(200).json({ ok: true, confidenceObtenue: false });

  return res.status(200).json({ ok: true, confidenceObtenue: true });
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
  if (body.action === 'tirer_confidence_escort') return tirerConfidenceEscort(body, res);
  return res.status(400).json({ error: 'action invalide.' });
}
