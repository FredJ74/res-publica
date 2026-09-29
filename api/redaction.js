// =====================
// API VERCEL — REDACTION DE TEXTES DE JEU (DeepSeek) — 29 septembre 2026
// =====================
// POURQUOI UN ENDPOINT SEPARE DE /api/chat.
//
// Seize fonctions du jeu font ecrire un texte par l'IA : la meteo politique, un
// sondage, une fuite de presse, un decret inutile, la reponse d'un stagiaire, le
// recit d'une escort... Ce ne sont PAS des dialogues de PNJ. Elles n'ont ni
// personnalite, ni memoire, ni connaissances a borner : elles ont un gabarit metier
// qui varie a chaque appel, ecrit dans le code du jeu depuis des mois.
//
// Les faire passer par les profils PNJ aurait suppose de reecrire seize prompts
// metier -- exactement ce qu'un changement de fournisseur ne doit pas faire. Elles
// gardent donc leur texte, et c'est l'ENDPOINT qui porte l'autorite :
//
//   - AUTHENTIFICATION SUPABASE OBLIGATOIRE. La voie Anthropic qu'on remplace
//     n'en avait AUCUNE : n'importe qui pouvait consommer du credit. C'est un
//     durcissement, pas un assouplissement.
//   - USAGE DECLARE contre une allowlist fermee. Un appel sans usage reconnu est
//     refuse. On ne peut donc pas se servir de cet endpoint comme d'un relais IA
//     generique : il ne sert qu'aux seize usages du jeu, nommes un par un.
//   - MODELE ET max_tokens IMPOSES PAR LE SERVEUR. Le navigateur ne choisit plus
//     ni l'un ni l'autre -- il les choisissait tous les deux avant.
//   - PLAFOND DE LONGUEUR par usage, pour que le cout reste borne.
//
// CE QU'IL NE FAIT PAS : il n'accepte aucun prompt SYSTEME, aucun parametre de
// modele, aucune temperature, et il ne touche ni aux profils PNJ ni a /api/chat.

import { appelDeepSeek, joueurAuthentifie } from './_deepseek.js';

const ALLOWED_ORIGIN = 'https://res-publica.vercel.app';

// ---------------------------------------------------------------------------
// LES SEIZE USAGES — LA TABLE FERMEE
// ---------------------------------------------------------------------------
// `tokens` reprend EXACTEMENT la valeur que chaque appelant demandait a Anthropic :
// c'est un changement de fournisseur, pas un rearbitrage des longueurs.
// `max` borne la taille du prompt envoye, largement au-dessus de ce que chaque
// gabarit produit, pour refuser une requete aberrante sans jamais gener un usage reel.
const USAGES = {
  evenement_aleatoire:   { tokens: 220, max:  4000 },
  sondage:               { tokens: 250, max:  4000 },
  meteo_politique:       { tokens: 120, max:  4000 },
  quete_accueil_jeremy:  { tokens: 300, max:  8000 },
  fuite_presse:          { tokens: 220, max:  8000 },
  scandale_presse:       { tokens: 220, max:  8000 },
  jodie_portrait:        { tokens: 500, max: 12000 },
  pnj_autre_joueur:      { tokens: 100, max:  4000 },
  reaction_journaliste:  { tokens: 150, max:  8000 },
  escort_infos:          { tokens:  60, max:  4000 },
  kompromat:             { tokens: 150, max:  4000 },
  escort_piege:          { tokens: 120, max:  4000 },
  decret:                { tokens: 250, max:  8000 },
  quete_nouvelle:        { tokens: 150, max:  4000 },
  quete_progression:     { tokens: 100, max:  4000 },
  // SEUL USAGE A LONGUEUR VARIABLE. Le client demandait 250, 320, 400 ou 480 tokens
  // selon le palier de la relation. Il ne choisit plus le nombre : il declare le
  // PALIER, borne a l'entier 0-3, et le serveur applique le bareme d'origine.
  escort_amour:          { tokens: 480, max:  8000, paliers: [250, 320, 400, 480] }
};

function usageValide(u) {
  return typeof u === 'string' && Object.prototype.hasOwnProperty.call(USAGES, u);
}

function validerPayload(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return 'Corps de requête invalide.';
  const clesAutorisees = ['usage', 'texte', 'palier'];
  if (Object.keys(body).some(k => !clesAutorisees.includes(k))) return 'Champ non autorisé.';
  if (!usageValide(body.usage)) return 'Usage non autorisé.';
  if (typeof body.texte !== 'string' || body.texte.trim().length === 0) return 'Texte invalide.';
  if (body.texte.length > USAGES[body.usage].max) return 'Texte trop long.';
  if (body.palier !== undefined) {
    if (!Number.isInteger(body.palier) || body.palier < 0 || body.palier > 3) return 'Palier invalide.';
  }
  return null;
}

function tokensPour(usage, palier) {
  const u = USAGES[usage];
  if (u.paliers && Number.isInteger(palier)) {
    return u.paliers[Math.max(0, Math.min(u.paliers.length - 1, palier))];
  }
  return u.tokens;
}

export default async function handler(req, res) {
  const origin = req.headers.origin;
  if (origin === ALLOWED_ORIGIN) res.setHeader('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const erreur = validerPayload(req.body);
  if (erreur) return res.status(400).json({ error: erreur });

  const utilisateur = await joueurAuthentifie(req);
  if (!utilisateur) return res.status(401).json({ error: 'Authentification requise.' });

  const r = await appelDeepSeek({
    messages: [{ role: 'user', content: req.body.texte }],
    maxTokens: tokensPour(req.body.usage, req.body.palier),
    timeoutMs: 30000
  });

  if (!r.ok) {
    return res.status(502).json({ error: 'Rédaction momentanément indisponible.' });
  }
  // MEME FORME DE REPONSE QUE LA VOIE PNJ : { reponse }. Les seize appelants lisent
  // desormais ce champ unique, au lieu du `content[0].text` propre a l'ancien
  // fournisseur -- c'est le seul changement que la migration leur impose.
  return res.status(200).json({ reponse: r.texte, tronque: !!r.tronque });
}
