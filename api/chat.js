// =====================
// API VERCEL — DIALOGUE DES PNJ (DeepSeek)
// =====================
// UNE SEULE FORME DE REQUETE : { profil, lang, message, historique? }
//
// Le prompt systeme, la personnalite et les connaissances sont construits ICI, cote serveur,
// a partir de api/_pnj-profils.js : le navigateur ne transmet qu'un IDENTIFIANT de profil,
// valide contre une table fermee de 177 entrees. Il ne peut donc pas faire dire n'importe quoi
// a un PNJ, ni se servir de l'endpoint comme d'un relais generique.
//
// AUTHENTIFICATION REELLE : le jeton Supabase du joueur est verifie aupres de Supabase AVANT
// tout appel paye. Un `authenticated: true` affirme par le client ne vaudrait rien, et n'est
// d'ailleurs jamais lu.
//
// LE RELAIS ANTHROPIC A ETE RETIRE (29 septembre 2026). Il acceptait encore
// {model, max_tokens, messages} sans la moindre authentification : c'etait le dernier chemin
// par lequel le jeu pouvait declencher une requete Anthropic, et le dernier ou le navigateur
// choisissait lui-meme le modele et le nombre de jetons. Les seize usages qui en dependaient
// sont passes a /api/redaction, ou l'usage est declare contre une table fermee et ou le serveur
// impose tout.
//
// LA CLE D'API N'EST JAMAIS TRANSMISE AU NAVIGATEUR, ni journalisee, ni renvoyee dans une erreur.

import { construirePromptSysteme, profilExiste, maxTokensProfil } from './_pnj-profils.js';
import { appelDeepSeek, joueurAuthentifie } from './_deepseek.js';

const ALLOWED_ORIGIN = 'https://res-publica.vercel.app';
const ALLOWED_ROLES = ['user', 'assistant'];

// Garde-fous minimaux mais reels : un message de joueur tient tres largement en 1000 caracteres,
// et six echanges suffisent a une conversation de PNJ. Borner ici, c'est borner le cout.
const MAX_MESSAGE_JOUEUR = 1000;
const MAX_HISTORIQUE = 6;
const MAX_CONTENU_HISTORIQUE = 1500;

function validerPayload(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return 'Corps de requête invalide.';

  const clesAutorisees = ['profil', 'lang', 'message', 'historique'];
  if (Object.keys(body).some(k => !clesAutorisees.includes(k))) return 'Champ non autorisé dans la requête.';

  if (typeof body.profil !== 'string' || !profilExiste(body.profil)) return 'Profil inconnu.';
  if (body.lang !== undefined && (typeof body.lang !== 'string' || body.lang.length > 8)) return 'Langue invalide.';

  if (typeof body.message !== 'string' || body.message.trim().length === 0) return 'Message invalide.';
  if (body.message.length > MAX_MESSAGE_JOUEUR) return 'Message trop long.';

  if (body.historique !== undefined) {
    if (!Array.isArray(body.historique) || body.historique.length > MAX_HISTORIQUE) return 'Historique invalide.';
    for (const m of body.historique) {
      if (!m || typeof m !== 'object' || Array.isArray(m)) return 'Historique invalide.';
      if (Object.keys(m).some(k => k !== 'role' && k !== 'content')) return 'Historique invalide.';
      if (!ALLOWED_ROLES.includes(m.role)) return 'Historique invalide.';
      if (typeof m.content !== 'string' || m.content.length === 0
          || m.content.length > MAX_CONTENU_HISTORIQUE) return 'Historique invalide.';
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// LA RELATION VIENT DU SERVEUR, JAMAIS DU NAVIGATEUR
// ---------------------------------------------------------------------------
// Un PNJ social se souvient du joueur. Si cette memoire transitait par le client, n'importe
// qui pourrait s'inventer une familiarite avec Jean-Lou. Elle est donc relue ICI, sous le
// jeton du joueur lui-meme -- pas sous une cle de service : la RPC ne rend que la relation
// du personnage connecte, et le serveur n'a aucun pouvoir supplementaire a lui preter.
//
// Elle echoue en silence : un PNJ sans memoire sociale -- la quasi-totalite -- rend
// simplement `null`, et son prompt est alors rigoureusement celui d'avant.
// Une seule porte de lecture, deux usages. Les deux memoires passent par la meme
// mecanique -- RPC sous le JETON DU JOUEUR, jamais sous une cle de service -- et
// echouent en silence : un PNJ qui n'a ni l'une ni l'autre rend `null`, et son
// prompt reste rigoureusement celui d'avant.
const CORPS_RPC = {
  pnj_social_contexte:          (profilId) => ({ p_pnj_id: profilId }),
  referent_pedagogie_contexte:  (profilId) => ({ p_referent_id: profilId }),
  pnj_contexte_public:          () => ({}),
  // La memoire des mandats ne prend AUCUN pays : la porte le relit en base. Lui passer un pays
  // laisserait un joueur lire la memoire presidentielle d'un empire voisin.
  presidence_memoire_mon_pays:  () => ({}),
  // Les regards de l'agente d'entretien ne prennent qu'une FENETRE en jours -- jamais un pays, ni
  // un batiment, ni un nom : la porte relit le pays de l'acteur en base et ne regarde que
  // l'Assemblee. Lui laisser choisir ferait de Renee une informatrice universelle.
  assemblee_regards:            () => ({ p_jours: 7 }),
  // L'etape de la visite d'accueil ne prend AUCUN parametre non plus : la porte relit la fiche
  // du joueur connecte. Lui passer un nom laisserait lire la visite de quelqu'un d'autre.
  quete_accueil_contexte:       () => ({})
};

async function lireMemoire(rpc, profilId, jeton) {
  const url = process.env.SUPABASE_URL || 'https://jxpwoosmmhohoihxpbuc.supabase.co';
  const anon = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw';
  try {
    const r = await fetch(url.replace(/\/$/, '') + '/rest/v1/rpc/' + rpc, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'apikey': anon, 'Authorization': 'Bearer ' + jeton },
      // CHAQUE CANAL A SA PROPRE SIGNATURE. Le contexte public n'en a AUCUNE : il ne porte pas
      // d'identifiant de PNJ, parce qu'il ne parle pas du PNJ mais de l'APPELANT, que le serveur
      // reconnait par son jeton. Un `?:` a deux branches ne pouvait pas l'exprimer.
      body: JSON.stringify(CORPS_RPC[rpc] ? CORPS_RPC[rpc](profilId) : { p_referent_id: profilId })
    });
    if (!r.ok) return null;
    const d = await r.json();
    return (d && d.ok === true) ? d : null;
  } catch (e) {
    return null;
  }
}

// La relation d'un PNJ SOCIAL : rencontres, conversations, familiarite.
const relationSociale = (profilId, jeton) => lireMemoire('pnj_social_contexte', profilId, jeton);

// La memoire d'un REFERENT : combien de fois il a deja explique des choses a ce
// joueur. Rien d'autre -- ni familiarite, ni confiance. Un referent n'est pas un ami.
const memoirePedagogique = (profilId, jeton) => lireMemoire('referent_pedagogie_contexte', profilId, jeton);

// LA MEMOIRE DES MANDATS -- LE QUATRIEME CANAL, ET LE PLUS ETROIT (11 octobre 2026)
// ---------------------------------------------------------------------------
// UN SEUL PNJ LA RECOIT. Huguette Papier est la Secretaire generale de la Presidence : c'est elle,
// et personne d'autre, qui a vu passer les mandats. Le canal n'est donc pas demande pour les 210
// autres profils -- ce n'est pas un filtrage d'affichage, c'est un appel qui n'a pas lieu.
//
// ELLE NE SE MELANGE A RIEN. Les quatre canaux sont de quatre natures :
//   . contexte public      -> un fait du monde (qui est en face) ;
//   . memoire sociale      -> une relation (vous vous connaissez) ;
//   . memoire pedagogique  -> un historique d'explications (ce qu'on vous a deja dit) ;
//   . memoire des mandats  -> une HISTOIRE NATIONALE (ce que la maison a vu).
// Les confondre effacerait quatre distinctions de game design.
const MEMOIRE_DES_MANDATS = 'huguette_papier';
const memoireDesMandats = (profilId, jeton) =>
  profilId === MEMOIRE_DES_MANDATS
    ? lireMemoire('presidence_memoire_mon_pays', null, jeton)
    : Promise.resolve(null);

// LE CINQUIEME CANAL — CE QUE L'AGENTE D'ENTRETIEN A VU (11 octobre 2026)
// ---------------------------------------------------------------------------
// UNE SEULE PNJ LE RECOIT, exactement comme la memoire des mandats n'en concerne qu'une : Renee
// Toitout nettoie l'Assemblee nationale, elle y circule toute la journee, et personne ne fait
// attention a elle. Pour les 212 autres profils, l'appel n'est pas emis.
//
// IL EST DE LA CINQUIEME NATURE, et c'est pour cela qu'il ne se melange a aucun des quatre autres :
//   . contexte public      -> un fait du monde (qui est en face) ;
//   . memoire sociale      -> une relation (vous vous connaissez) ;
//   . memoire pedagogique  -> un historique d'explications ;
//   . memoire des mandats  -> une histoire nationale ;
//   . regards de l'Assemblee -> une OBSERVATION LOCALE, celle d'une employee qui a des yeux.
//
// LA PORTE NE CREE AUCUNE SURVEILLANCE : elle lit `historique_deplacements` -- deja ecrit par
// `deplacement_enregistrer`, sous RLS sans policy et sans aucun droit client --, les neuf sieges et
// les scrutins clos. Et elle dit AUSSI ce qu'elle ne sait pas : `rien_a_signaler` et
// `aucun_scrutin` sont la pour que l'IA n'ait rien a remplir.
const REGARDS_ASSEMBLEE = 'renee_toitout';
const regardsAssemblee = (profilId, jeton) =>
  profilId === REGARDS_ASSEMBLEE
    ? lireMemoire('assemblee_regards', null, jeton)
    : Promise.resolve(null);

// LE SIXIEME CANAL — OU EN EST LA VISITE D'ACCUEIL (13 octobre 2026)
// ---------------------------------------------------------------------------
// UN SEUL PNJ LE RECOIT, et c'est le guide : Jeremy conduit la quete d'accueil, il est le
// premier PNJ qu'une nouvelle joueuse rencontre et celui a qui elle parle le plus. Pour les 214
// autres profils, l'appel n'est pas emis -- ce n'est pas un filtrage d'affichage, c'est un
// aller-retour reseau qui n'a pas lieu.
//
// IL EST DE LA SIXIEME NATURE : les cinq autres canaux disent le monde, une relation, un
// historique d'explications, une histoire nationale ou une observation locale. Celui-ci dit OU
// EN EST CE JOUEUR-CI. Les confondre effacerait une distinction de game design.
//
// LA PORTE NE REND QUE L'ETAPE, jamais la consigne : la phrase d'objectif est un miroir de
// QUETE_ACCUEIL_OBJECTIFS, cote depot (api/_pnj-profils.js). Le serveur dit ou on en est ; il
// n'invente pas quoi faire.
const VISITE_D_ACCUEIL = 'jeremy';
const etapeDeLaVisite = (profilId, jeton) =>
  profilId === VISITE_D_ACCUEIL
    ? lireMemoire('quete_accueil_contexte', null, jeton)
    : Promise.resolve(null);

// QUI EST EN FACE : son nom et sa fonction officielle. C'est le seul des trois canaux qui ne
// depend pas du PNJ : il est le meme pour tous, et presque tous le recoivent. Il echoue en
// silence comme les deux autres -- sans lui, le prompt est rigoureusement celui d'avant.
const contextePublicJoueur = (jeton) => lireMemoire('pnj_contexte_public', null, jeton);

export default async function handler(req, res) {
  const origin = req.headers.origin;
  if (origin === ALLOWED_ORIGIN) {
    res.setHeader('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  // Authorization doit etre acceptee : c'est elle qui porte le jeton du joueur.
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const erreur = validerPayload(req.body);
  if (erreur) return res.status(400).json({ error: erreur });

  const utilisateur = await joueurAuthentifie(req);
  if (!utilisateur) return res.status(401).json({ error: 'Authentification requise.' });

  // LES SIX lectures partent ENSEMBLE : elles sont independantes, et les enchainer ajouterait
  // quatre allers-retours reseau a chaque replique. Un PNJ n'a jamais les deux memoires -- un
  // social n'est pas referent, un referent ne se lie pas --, le contexte public les concerne
  // tous, et les deux derniers n'en concernent QU'UN CHACUN : la memoire des mandats pour
  // Huguette Papier, les regards de l'Assemblee pour Renee Toitout. Pour tous les autres profils,
  // ces trois appels ne sont pas emis du tout -- le troisieme etant l'etape de la
  // visite d'accueil, qui n'appartient qu'a Jeremy.
  const [relation, pedagogie, contextePublic, mandats, regards, visite] = await Promise.all([
    relationSociale(req.body.profil, utilisateur.jeton),
    memoirePedagogique(req.body.profil, utilisateur.jeton),
    contextePublicJoueur(utilisateur.jeton),
    memoireDesMandats(req.body.profil, utilisateur.jeton),
    regardsAssemblee(req.body.profil, utilisateur.jeton),
    etapeDeLaVisite(req.body.profil, utilisateur.jeton)
  ]);
  const systeme = construirePromptSysteme(
    req.body.profil, req.body.lang, relation, pedagogie, contextePublic, mandats, regards, visite);
  if (!systeme) return res.status(400).json({ error: 'Profil inconnu.' });

  const messages = [];
  for (const m of (req.body.historique || [])) messages.push({ role: m.role, content: m.content });
  messages.push({ role: 'user', content: req.body.message });

  const r = await appelDeepSeek({
    systeme,
    messages,
    maxTokens: maxTokensProfil(req.body.profil),
    timeoutMs: 30000
  });

  if (!r.ok) return res.status(502).json({ error: 'Le PNJ est momentanément indisponible.' });
  return res.status(200).json({ reponse: r.texte });
}
