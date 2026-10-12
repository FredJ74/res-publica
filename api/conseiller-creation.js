// =====================
// API VERCEL — LE CONSEILLER DE CREATION (DeepSeek)
// =====================
// IL CONSEILLE, IL NE CREE PAS. Cet endpoint rend une SUGGESTION de parcours : une origine
// sociale, des etudes, une nature profonde, une carriere, et deux phrases qui expliquent
// pourquoi. Il n'ecrit rien, ne valide rien, ne reserve rien. La creation du personnage se
// poursuit exactement comme avant, et le joueur peut choisir autre chose a chaque etape.
//
// LE CONSEILLER NE CONNAIT PAS LES REGLES, IL LES RECOIT. Le prompt est bati ici, cote serveur,
// a partir de `api/_referentiels-generes.js` -- l'artefact GENERE depuis data.js, jamais ressaisi
// (outils/generateurs/generer_referentiels_serveur.py). Le navigateur n'envoie QUE l'empire deja
// choisi et le texte libre du joueur : il ne peut donc pas faire inventer une carriere, une
// ecole ni une nature qui n'existent pas.
//
// ET LA SORTIE EST REVALIDEE CONTRE LES MEMES CATALOGUES. Un identifiant inconnu, une carriere
// que les etudes proposees ferment, un JSON mal forme : la reponse est REFUSEE, et la creation
// continue sans aucune suggestion. Fail closed -- jamais une creation corrompue.
//
// AUCUNE SELECTION AUTOMATIQUE. L'endpoint ne renvoie pas « le build » : il renvoie quatre
// propositions que l'ecran affiche discretement. Rien n'est pre-selectionne, rien n'est verrouille.

import { appelDeepSeek, joueurAuthentifie } from './_deepseek.js';
import {
  CREATION_ORIGINES_SERVEUR, CREATION_ECOLES_SERVEUR,
  CREATION_NATURES_SERVEUR, CREATION_CARRIERES_SERVEUR
} from './_referentiels-generes.js';

const ALLOWED_ORIGIN = 'https://res-publica.vercel.app';
const MAX_SOUHAIT = 800;
const MAX_HISTORIQUE = 4;
const EMPIRES = ['republic', 'soviet', 'khalija', 'narco'];

// LA REGLE QUE LE CONSEILLER DOIT CONNAITRE, ET LA SEULE QUI SOIT UNE CONTRAINTE DE JEU.
// Elle n'est pas une opinion : elle est posee en base par `carrieres_acquises`, dont la cle
// primaire est le personnage.
const REGLE_CARRIERES =
  "Un personnage a UNE carriere initiale, choisie maintenant, plus AU MAXIMUM UNE seconde " +
  "carriere acquise plus tard a l'Universite. Jamais trois. La carriere ouvre certaines " +
  "professions specialisees et en ferme d'autres.";

function validerPayload(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return 'Corps de requête invalide.';
  const cles = ['empire', 'souhait', 'lang', 'historique'];
  if (Object.keys(body).some(k => !cles.includes(k))) return 'Champ non autorisé dans la requête.';
  if (typeof body.empire !== 'string' || !EMPIRES.includes(body.empire)) return 'Empire inconnu.';
  if (typeof body.souhait !== 'string') return 'Souhait invalide.';
  if (body.souhait.length > MAX_SOUHAIT) return 'Souhait trop long.';
  if (body.lang !== undefined && (typeof body.lang !== 'string' || body.lang.length > 8)) return 'Langue invalide.';
  if (body.historique !== undefined) {
    if (!Array.isArray(body.historique) || body.historique.length > MAX_HISTORIQUE) return 'Historique invalide.';
    for (const m of body.historique) {
      if (!m || typeof m !== 'object' || Array.isArray(m)) return 'Historique invalide.';
      if (Object.keys(m).some(k => k !== 'role' && k !== 'content')) return 'Historique invalide.';
      if (m.role !== 'user' && m.role !== 'assistant') return 'Historique invalide.';
      if (typeof m.content !== 'string' || !m.content.length || m.content.length > 1500) return 'Historique invalide.';
    }
  }
  return null;
}

// Le catalogue, rendu court : le conseiller a besoin des identifiants, des noms et des effets,
// pas de la mise en page.
function ligneEffets(e) {
  const plus = Object.entries(e.bonuses || {}).map(([k, v]) => '+' + v + ' ' + k);
  const moins = Object.entries(e.malus || {}).map(([k, v]) => v + ' ' + k);
  return plus.concat(moins).join(' ');
}

function catalogues() {
  const origines = CREATION_ORIGINES_SERVEUR.map(o =>
    `- ${o.id} : ${o.name} (${ligneEffets(o)}, capital ${o.arg} FR)`).join('\n');
  const ecoles = CREATION_ECOLES_SERVEUR.map(s =>
    `- ${s.id} : ${s.name} (${ligneEffets(s)})` +
    ((s.blocks || []).length ? ` — FERME les carrieres : ${s.blocks.join(', ')}` : ' — ouvre toutes les carrieres')).join('\n');
  const natures = CREATION_NATURES_SERVEUR.map(a =>
    `- ${a.id} : ${a.name} (${ligneEffets(a)}) — ${a.desc}`).join('\n');
  const carrieres = CREATION_CARRIERES_SERVEUR.map(c =>
    `- ${c.id} : ${c.name} (+1 ${c.statKey}, capital ${c.argBonus} FR) — ${c.comp}` +
    ((c.blocks || []).length ? ` — EXIGE des etudes autres que : ${c.blocks.join(', ')}` : '')).join('\n');
  return { origines, ecoles, natures, carrieres };
}

function promptSysteme() {
  const c = catalogues();
  return [
    "Tu es le conseiller de creation de personnage de Human Gambit, un jeu politique textuel.",
    "Ton role : aider un joueur a traduire le personnage qu'il imagine dans les regles du jeu.",
    "",
    "TU N'INVENTES AUCUNE REGLE ET AUCUNE OPTION. Tu choisis EXCLUSIVEMENT parmi les identifiants",
    "des quatre catalogues ci-dessous. Un identifiant hors catalogue rend ta reponse inutilisable.",
    "",
    "ORIGINES SOCIALES (d'ou vient le personnage) :\n" + c.origines,
    "",
    "ETUDES (quel parcours scolaire il a recu) :\n" + c.ecoles,
    "",
    "NATURES PROFONDES (qui il est -- une inclination, jamais un metier ni un comportement oblige) :\n" + c.natures,
    "",
    "CARRIERES (ce qu'il sait faire professionnellement) :\n" + c.carrieres,
    "",
    "CONTRAINTE A RESPECTER ABSOLUMENT : l'ecole proposee ne doit pas figurer dans les `blocks`",
    "de la carriere proposee. Si elle y figure, ta proposition est invalide.",
    "",
    "REGLE DE JEU A EXPLIQUER SANS L'ALOURDIR : " + REGLE_CARRIERES,
    "",
    "TON. Accueillant, adulte, bref. Jamais professoral, jamais infantilisant. Tu n'es PAS un",
    "optimiseur de build : tu ne dis jamais « meilleur build », « build optimal », « mauvais choix »",
    "ni « vous devez ». Aucune combinaison nature/carriere n'est interdite ni deconseillee : un",
    "criminel peut etre legaliste, un avocat transgressif, un officier idealiste.",
    "",
    "CAS PARTICULIER, ET IL EST IMPORTANT. Si le joueur dit qu'il ne sait pas, qu'il decouvre,",
    "qu'il verra, ou qu'il veut juste essayer : ce n'est NI une erreur NI une information",
    "insuffisante. Reponds dans cet esprit : il n'a pas besoin de savoir des maintenant ce qu'il",
    "voudra devenir ; tu lui proposes un personnage polyvalent pour decouvrir le jeu, sans chercher",
    "a l'optimiser pour une activite particuliere ; il pourra decouvrir la politique, l'economie,",
    "les organisations et les relations sociales avant de trouver sa voie ; et il pourra acquerir",
    "une seconde carriere plus tard. Dans ce cas, varie reellement tes propositions d'une fois sur",
    "l'autre -- il ne doit pas exister un unique « parcours de debutant » qui fabriquerait des clones.",
    "",
    "Reponds en json, et uniquement avec cet objet :",
    '{"origin":"<id>","school":"<id>","archetype":"<id>","career":"<id>",',
    ' "message":"<2 a 4 phrases adressees au joueur>",',
    ' "pourquoi":{"origin":"<une phrase>","school":"<une phrase>","archetype":"<une phrase>","career":"<une phrase>"}}'
  ].join('\n');
}

// LA REVALIDATION, ET C'EST ELLE QUI PROTEGE LA CREATION. Le modele a pu repondre n'importe quoi :
// tant que ces quatre identifiants ne sont pas dans les catalogues ET compatibles entre eux, rien
// n'est renvoye au navigateur.
function valider(prop) {
  if (!prop || typeof prop !== 'object') return null;
  const dans = (liste, id) => liste.some(e => e.id === id);
  if (!dans(CREATION_ORIGINES_SERVEUR, prop.origin)) return null;
  if (!dans(CREATION_ECOLES_SERVEUR, prop.school)) return null;
  if (!dans(CREATION_NATURES_SERVEUR, prop.archetype)) return null;
  if (!dans(CREATION_CARRIERES_SERVEUR, prop.career)) return null;

  const carriere = CREATION_CARRIERES_SERVEUR.find(c => c.id === prop.career);
  if ((carriere.blocks || []).includes(prop.school)) return null;
  const ecole = CREATION_ECOLES_SERVEUR.find(s => s.id === prop.school);
  if ((ecole.blocks || []).includes(prop.career)) return null;

  const texte = (v, max) => (typeof v === 'string' ? v.slice(0, max) : '');
  const p = prop.pourquoi && typeof prop.pourquoi === 'object' ? prop.pourquoi : {};
  return {
    origin: prop.origin, school: prop.school, archetype: prop.archetype, career: prop.career,
    message: texte(prop.message, 900),
    pourquoi: {
      origin: texte(p.origin, 300), school: texte(p.school, 300),
      archetype: texte(p.archetype, 300), career: texte(p.career, 300)
    }
  };
}

export default async function handler(req, res) {
  const origine = req.headers.origin;
  if (origine === ALLOWED_ORIGIN) res.setHeader('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  res.setHeader('Vary', 'Origin');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Méthode non autorisée.' });

  const joueur = await joueurAuthentifie(req);
  if (!joueur) return res.status(401).json({ error: 'Authentification requise.' });

  const refus = validerPayload(req.body);
  if (refus) return res.status(400).json({ error: refus });

  const souhait = (req.body.souhait || '').trim();
  const messages = [].concat(
    (req.body.historique || []),
    [{ role: 'user', content: souhait || "Je ne sais pas encore, je decouvre le jeu." }]
  );

  const r = await appelDeepSeek({
    systeme: promptSysteme(), messages, maxTokens: 700, json: true, timeoutMs: 20000
  });
  // INDISPONIBLE N'EST PAS CORROMPU. Le navigateur recoit un refus propre et poursuit la creation
  // normale : c'est tout l'interet d'une etape facultative.
  if (!r || !r.ok) return res.status(503).json({ error: 'Conseiller indisponible.' });

  let brut = null;
  try { brut = JSON.parse(r.texte); } catch (e) { brut = null; }
  const prop = valider(brut);
  if (!prop) return res.status(422).json({ error: 'Proposition non conforme aux catalogues.' });

  return res.status(200).json({ ok: true, proposition: prop });
}
