// =====================
// API VERCEL — PROXY ANTHROPIC (durci, lot P0 securite, 22 aout 2026)
// =====================
// Historique : relais totalement ouvert (CORS *, aucune validation de req.body) jusqu'a l'audit
// du 22 aout 2026, qui l'a classe CRITIQUE -- n'importe qui sur Internet (pas seulement un joueur)
// pouvait consommer le budget Anthropic du projet a volonte (modele/max_tokens/prompt systeme
// arbitraires).
//
// Correctif retenu : allowlist stricte du payload plutot qu'un eclatement en endpoints
// specialises par fonctionnalite -- cartographie exhaustive des 17 appelants reels (tous des
// fetch('/api/chat') directs depuis le navigateur, aucun appelant serveur) confirme qu'ils
// partagent tous EXACTEMENT la meme forme : model parmi 2 valeurs connues, max_tokens <= 500,
// messages = 1 a 7 tours {role,content} sans aucun autre champ (jamais de system/tools/stream/
// temperature). Cette allowlist ferme integralement l'usage comme relais Anthropic generique
// (modele/tokens/prompt systeme arbitraires, appels d'outils, streaming) sans toucher a un seul
// prompt ni fichier appelant.
//
// Limite assumee et non resolue ici (aucun faux mecanisme d'identite introduit) : aucune
// authentification joueur n'existe dans ce projet (dette systemique deja documentee dans
// api/upload-org-avatar.js) -- un appel direct hors navigateur, respectant cet allowlist, reste
// possible et repetable en boucle. CORS n'est qu'une restriction de lecture cross-origin cote
// navigateur, jamais une authentification. Fermer ce residu necessite soit une authentification
// joueur reelle, soit un rate limiting fiable (aucune primitive Vercel de ce type deja configuree
// dans ce projet a ce jour -- non ajoute ici, signale separement).

const ALLOWED_ORIGIN = 'https://res-publica.vercel.app';

// Les 2 seuls modeles reellement appeles par les 17 sites d'appel recenses (cartographie du lot
// P0 securite, 22 aout 2026) -- jamais un modele plus recent/couteux choisi par l'appelant.
const ALLOWED_MODELS = ['claude-haiku-4-5-20251001', 'claude-sonnet-4-5'];

// Plus haute valeur reellement utilisee (jodiePortraitGenererApercu, plateau-communication.js) --
// aucune marge ajoutee au-dela de ce qui est reellement necessaire aux usages actuels.
const MAX_TOKENS_CAP = 500;

// Le seul appelant a historique (plateau-pnj.js:1346) envoie au maximum 1 message de base + 6
// messages d'historique = 7 -- marge de 1 conservee sans justification d'aller plus haut.
const MAX_MESSAGES = 8;
const ALLOWED_ROLES = ['user', 'assistant'];

// Le prompt le plus riche reellement observe (dialogue PNJ, plateau-pnj.js ~ligne 1286 --
// personnalite + profil + lieu + autres joueurs presents + contexte forum + historique du jour)
// combine plusieurs blocs eux-memes bornes (2 sujets de forum max, ordres d'UNE seule piece,
// 6 echanges d'historique max) : estimation large a 3-5000 caracteres en pratique. Plafond fixe
// a 12000 pour une marge confortable (~3x) sans ouvrir la porte a un payload de taille arbitraire.
const MAX_CONTENT_LENGTH_PER_MESSAGE = 12000;
const MAX_TOTAL_CONTENT_LENGTH = 16000;

function validerPayload(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return 'Corps de requête invalide.';

  // Aucune autre cle toleree (system/tools/tool_choice/stream/temperature/top_p/top_k/metadata/
  // stop_sequences/etc.) -- c'est precisement ce qui transformait cet endpoint en relais
  // Anthropic generique.
  const clesAutorisees = ['model', 'max_tokens', 'messages'];
  const clesRecues = Object.keys(body);
  if (clesRecues.some(k => !clesAutorisees.includes(k))) return 'Champ non autorisé dans la requête.';

  if (!ALLOWED_MODELS.includes(body.model)) return 'Modèle non autorisé.';

  if (!Number.isInteger(body.max_tokens) || body.max_tokens < 1 || body.max_tokens > MAX_TOKENS_CAP) {
    return 'max_tokens invalide.';
  }

  if (!Array.isArray(body.messages) || body.messages.length < 1 || body.messages.length > MAX_MESSAGES) {
    return 'messages invalide.';
  }

  let longueurTotale = 0;
  for (const m of body.messages) {
    if (!m || typeof m !== 'object' || Array.isArray(m)) return 'messages invalide.';
    const clesMessage = Object.keys(m);
    if (clesMessage.some(k => k !== 'role' && k !== 'content')) return 'Champ non autorisé dans un message.';
    if (!ALLOWED_ROLES.includes(m.role)) return 'role de message invalide.';
    if (typeof m.content !== 'string' || m.content.length === 0) return 'content de message invalide.';
    if (m.content.length > MAX_CONTENT_LENGTH_PER_MESSAGE) return 'content de message trop long.';
    longueurTotale += m.content.length;
  }
  if (longueurTotale > MAX_TOTAL_CONTENT_LENGTH) return 'Contenu total trop volumineux.';

  return null;
}

export default async function handler(req, res) {
  const origin = req.headers.origin;
  if (origin === ALLOWED_ORIGIN) {
    res.setHeader('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Preflight
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const erreur = validerPayload(req.body);
  if (erreur) {
    return res.status(400).json({ error: erreur });
  }

  try {
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'API key not configured' });
    }

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify(req.body)
    });

    const data = await response.json();
    return res.status(response.status).json(data);

  } catch (error) {
    console.error('Proxy error:', error);
    return res.status(500).json({ error: 'Proxy error', details: error.message });
  }
}
