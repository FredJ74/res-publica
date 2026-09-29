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
async function relationSociale(profilId, jeton) {
  const url = process.env.SUPABASE_URL || 'https://jxpwoosmmhohoihxpbuc.supabase.co';
  const anon = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw';
  try {
    const r = await fetch(url.replace(/\/$/, '') + '/rest/v1/rpc/pnj_social_contexte', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': anon,
        'Authorization': 'Bearer ' + jeton
      },
      body: JSON.stringify({ p_pnj_id: profilId })
    });
    if (!r.ok) return null;
    const d = await r.json();
    return (d && d.ok === true) ? d : null;
  } catch (e) {
    return null;
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

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const erreur = validerPayload(req.body);
  if (erreur) return res.status(400).json({ error: erreur });

  const utilisateur = await joueurAuthentifie(req);
  if (!utilisateur) return res.status(401).json({ error: 'Authentification requise.' });

  const relation = await relationSociale(req.body.profil, utilisateur.jeton);
  const systeme = construirePromptSysteme(req.body.profil, req.body.lang, relation);
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
