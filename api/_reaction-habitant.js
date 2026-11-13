// =====================
// RÉACTION DE L'HABITANT À LA BOUTEILLE — écrite par DeepSeek (décision de Fred, 13/11/2026)
// =====================
// Starovka et Krasnov : quand un PJ trinque avec l'habitant (sovarka_maison_agir, action « trinquer »),
// le serveur a déjà tout décidé (bouteille retirée, 3 PA, secrets échangés). Ce module n'écrit QUE la
// réplique de l'habitant, à la place de la phrase fixe : aucune donnée de jeu n'en dépend.
//
// Porte : /api/chat?mode=trinquer (module préfixé « _ » : pas de 13e fonction Vercel, voir AGENTS.md).
// Garde : la lecture sovarka_maison_trinquer_lire, sous le jeton du joueur, vérifie que le geste a bien
// eu lieu (le sien, réussi, il y a moins de 15 minutes) et ne se consomme qu'UNE fois : un seul appel à
// l'IA par bouteille. En cas d'échec, l'écran garde la phrase fixe déjà affichée.
import { appelDeepSeek, joueurAuthentifie } from './_deepseek.js';
import { LANGUES, langueDialogueAutorisee } from './_pnj-profils.js';
import { SUPABASE_URL, SUPABASE_ANON } from './_supabase.js';

const ORIGINE = 'https://res-publica.vercel.app';
const BUDGET_MS = 15000;

// Les deux habitants (noms validés par Fred le 13/11/2026), d'après leurs fiches de data.js.
const HABITANTS = {
  'Dolgor Tsybikova': "Tu es Dolgor Tsybikova, vieille dame bouriate de Starovka, ville glacée de Sovarka où les rues sont vides à cause du froid polaire. Ta maison de bois est basse, le poêle ronfle, le thé au beurre chauffe sur le feu. Tu es d'une hospitalité chaleureuse, malicieuse, avec la sagesse des steppes et un humour pince-sans-rire.",
  'Stepan Kouznetsov': "Tu es Stepan Kouznetsov, vieux kolkhozien de Krasnov, en Sovarka. Ta table est couverte d'une toile cirée, de cornichons et de pain noir ; tes bocaux s'alignent sur le rebord de la fenêtre. Tu es ravi d'avoir de la compagnie, bavard, nostalgique du kolkhoze, un brin vantard."
};
const ALCOOLS = {
  vodka: 'une bouteille de vodka',
  slivovitz: 'une bouteille de slivovitz (eau-de-vie de prune)',
  samogon: 'une bouteille de samogon (alcool de contrebande fait maison)',
  alcool: "une bouteille d'alcool de l'entrepôt d'État, rude et sans étiquette"
};

async function lireGeste(requete, jeton) {
  const url = SUPABASE_URL.replace(/\/$/, '');
  const anon = SUPABASE_ANON;
  try {
    const r = await fetch(url + '/rest/v1/rpc/sovarka_maison_trinquer_lire', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: anon, Authorization: 'Bearer ' + jeton },
      body: JSON.stringify({ p_requete: requete }), signal: AbortSignal.timeout(3000)
    });
    return r.ok ? await r.json() : null;
  } catch (e) { return null; }
}

export async function handlerReactionHabitant(req, res) {
  if (req.headers.origin === ORIGINE) res.setHeader('Access-Control-Allow-Origin', ORIGINE);
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  const body = req.body && typeof req.body === 'object' && !Array.isArray(req.body) ? req.body : null;
  const requete = body && typeof body.requete === 'string' ? body.requete.trim().slice(0, 80) : '';
  if (!requete || Object.keys(body).some(k => k !== 'requete' && k !== 'lang')) return res.status(400).json({ error: 'Requête invalide.' });

  const utilisateur = await joueurAuthentifie(req, { signal: AbortSignal.timeout(4000) });
  if (!utilisateur) return res.status(401).json({ error: 'Authentification requise.' });
  const geste = await lireGeste(requete, utilisateur.jeton);
  if (!geste || geste.ok !== true) return res.status(403).json({ error: 'Geste introuvable.', raison: geste?.raison || 'indisponible' });
  const portrait = HABITANTS[geste.habitant];
  if (!portrait) return res.status(403).json({ error: 'Habitant inconnu.', raison: 'habitant_inconnu' });

  const langue = langueDialogueAutorisee(body.lang);
  const consigne = (LANGUES[langue] || LANGUES.en || {}).consigne || '';
  const systeme = portrait
    + "\nUn visiteur vient de t'offrir " + (ALCOOLS[geste.alcool] || ALCOOLS.alcool) + " et vous trinquez ensemble."
    + "\nRéagis en une ou deux phrases courtes, à voix haute, avec ta personnalité : ce que t'inspire cette bouteille, puis un toast."
    + " Pas de didascalie, pas de guillemets, pas de secret ni de ragot (ils viennent juste après), aucune promesse d'objet ou d'argent."
    + "\n" + consigne;
  const r = await appelDeepSeek({ systeme, messages: [{ role: 'user', content: '*trinque*' }], maxTokens: 120, timeoutMs: BUDGET_MS });
  if (!r.ok || !r.texte) return res.status(502).json({ error: 'L’habitant est momentanément indisponible.' });
  const texte = String(r.texte).replace(/^["«\s]+|["»\s]+$/g, '').slice(0, 400);
  return res.status(200).json({ reaction: texte, habitant: geste.habitant });
}
