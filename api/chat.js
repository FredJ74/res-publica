// =====================
// API VERCEL — DIALOGUE PNJ (DeepSeek) ET RELAIS HISTORIQUE (Anthropic)
// =====================
// DEUX FORMES DE REQUETE, VOLONTAIREMENT DISJOINTES :
//
//   1. FORME PROFIL (23 septembre 2026) — { profil, lang, message, historique? }
//      C'est la voie des PNJ conversationnels. Le fournisseur est DeepSeek. Le prompt systeme,
//      la personnalite et les connaissances sont construits ICI, cote serveur, a partir de
//      api/_pnj-profils.js : le navigateur ne transmet qu'un IDENTIFIANT de profil, valide contre
//      une table fermee. Il ne peut donc pas faire dire n'importe quoi a un PNJ, ni se servir de
//      l'endpoint comme d'un relais generique.
//      ELLE EXIGE UNE AUTHENTIFICATION REELLE : le jeton Supabase du joueur est verifie aupres de
//      Supabase AVANT tout appel paye. Un `authenticated: true` affirme par le client ne vaut rien
//      et n'est d'ailleurs jamais lu.
//
//   2. FORME HISTORIQUE — { model, max_tokens, messages }
//      Le relais Anthropic d'origine, conserve a l'identique avec son allowlist stricte (audit du
//      22 aout 2026). Il n'est plus alimente en credit, mais rien ne justifiait de le supprimer :
//      dix-sept sites d'appel en dependent encore et basculeront profil par profil.
//
// LA CLE D'API N'EST JAMAIS TRANSMISE AU NAVIGATEUR, ni journalisee, ni renvoyee dans une erreur.

import { construirePromptSysteme, profilExiste, maxTokensProfil } from './_pnj-profils.js';

const ALLOWED_ORIGIN = 'https://res-publica.vercel.app';

// ---- FORME HISTORIQUE (Anthropic) : allowlist inchangee -------------------------------------
const ALLOWED_MODELS = ['claude-haiku-4-5-20251001', 'claude-sonnet-4-5'];
const MAX_TOKENS_CAP = 500;
const MAX_MESSAGES = 8;
const ALLOWED_ROLES = ['user', 'assistant'];
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

// ---- FORME PROFIL (DeepSeek) ------------------------------------------------------------------
// Garde-fous minimaux mais reels : un message de joueur tient tres largement en 1000 caracteres,
// et six echanges suffisent a une conversation de PNJ. Borner ici, c'est borner le cout.
const MAX_MESSAGE_JOUEUR = 1000;
const MAX_HISTORIQUE = 6;
const MAX_CONTENU_HISTORIQUE = 1500;
const DEEPSEEK_MODELE = 'deepseek-chat';
const DEEPSEEK_URL = 'https://api.deepseek.com/chat/completions';

function estFormeProfil(body) {
  return !!body && typeof body === 'object' && !Array.isArray(body)
      && Object.prototype.hasOwnProperty.call(body, 'profil');
}

function validerPayloadProfil(body) {
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

// AUTHENTIFICATION REELLE. On ne croit pas le client sur parole : le jeton porte par l'en-tete
// Authorization est presente a Supabase, qui seul peut dire s'il est valide et a qui il
// appartient. Un jeton absent, expire ou forge echoue ici, AVANT le moindre appel paye.
async function joueurAuthentifie(req) {
  const brut = req.headers.authorization || req.headers.Authorization || '';
  const jeton = brut.startsWith('Bearer ') ? brut.slice(7).trim() : '';
  if (!jeton) return null;

  const url = process.env.SUPABASE_URL;
  const anon = process.env.SUPABASE_ANON_KEY;
  if (!url || !anon) return null;

  // La cle anon est la cle PUBLIQUE du projet : la presenter ici n'expose rien. C'est le jeton du
  // joueur qui porte l'identite, et c'est lui qui est verifie.
  if (jeton === anon) return null;   // la cle anon n'est pas une identite de joueur

  try {
    const r = await fetch(url.replace(/\/$/, '') + '/auth/v1/user', {
      method: 'GET',
      headers: { 'apikey': anon, 'Authorization': 'Bearer ' + jeton }
    });
    if (!r.ok) return null;
    const u = await r.json();
    return (u && u.id) ? u.id : null;
  } catch (e) {
    return null;
  }
}

async function traiterProfil(req, res) {
  const erreur = validerPayloadProfil(req.body);
  if (erreur) return res.status(400).json({ error: erreur });

  const utilisateur = await joueurAuthentifie(req);
  if (!utilisateur) {
    return res.status(401).json({ error: 'Authentification requise.' });
  }

  const cle = process.env.DEEPSEEK_API_KEY;
  if (!cle) return res.status(500).json({ error: 'Fournisseur non configuré.' });

  const systeme = construirePromptSysteme(req.body.profil, req.body.lang);
  if (!systeme) return res.status(400).json({ error: 'Profil inconnu.' });

  const messages = [{ role: 'system', content: systeme }];
  for (const m of (req.body.historique || [])) messages.push({ role: m.role, content: m.content });
  messages.push({ role: 'user', content: req.body.message });

  try {
    const r = await fetch(DEEPSEEK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + cle },
      body: JSON.stringify({
        model: DEEPSEEK_MODELE,
        messages,
        max_tokens: maxTokensProfil(req.body.profil),
        temperature: 0.7
      })
    });

    if (!r.ok) {
      // Le detail du fournisseur n'est jamais renvoye tel quel au navigateur : il pourrait
      // contenir des elements de configuration. Seul le code de statut remonte.
      console.error('DeepSeek HTTP ' + r.status);
      return res.status(502).json({ error: 'Le PNJ est momentanément indisponible.' });
    }

    const data = await r.json();
    const texte = data?.choices?.[0]?.message?.content;
    if (!texte || typeof texte !== 'string') {
      return res.status(502).json({ error: 'Réponse vide du fournisseur.' });
    }
    return res.status(200).json({ reponse: texte.trim() });

  } catch (error) {
    console.error('Erreur dialogue PNJ');
    return res.status(502).json({ error: 'Le PNJ est momentanément indisponible.' });
  }
}

export default async function handler(req, res) {
  const origin = req.headers.origin;
  if (origin === ALLOWED_ORIGIN) {
    res.setHeader('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  // Authorization doit etre acceptee : c'est elle qui porte le jeton du joueur.
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  if (estFormeProfil(req.body)) {
    return traiterProfil(req, res);
  }

  // ---- Voie historique Anthropic, inchangee ----
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
