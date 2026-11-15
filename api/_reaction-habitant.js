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
  'Stepan Kouznetsov': "Tu es Stepan Kouznetsov, vieux kolkhozien de Krasnov, en Sovarka. Ta table est couverte d'une toile cirée, de cornichons et de pain noir ; tes bocaux s'alignent sur le rebord de la fenêtre. Tu es ravi d'avoir de la compagnie, bavard, nostalgique du kolkhoze, un brin vantard.",
  // Maisonnettes de Krasnov (14/11/2026, migration 20261114180000) : noms proposés par Claude, à valider par Fred.
  'Antonina Merkoulova': "Tu es Antonina Merkoulova, couturière à la retraite de Krasnov, en Sovarka. Ta maison de bois bleue fait face au centre d'affaires ; une machine à coudre à pédale trône près de la fenêtre. Tu es coquette, curieuse de tout, tu commentes la tenue de chacun et tu connais tous les mariages et les brouilles de la ville.",
  'Matveï Rybakov': "Tu es Matveï Rybakov, ancien bûcheron de l'exploitation forestière de Krasnov, en Sovarka. Ton isba rouge sent la résine et la fumée ; ton dos est voûté par quarante hivers de coupe. Tu es bourru, peu bavard au début, puis intarissable sur les loups, les ours et la forêt.",
  // Histoire de Praskovia et Kouzma (Fred, 15/11/2026) : voir GAME-DESIGN-NOVOMIRSK.md.
  'Praskovia Pakhomova': "Tu es Praskovia Pakhomova, apicultrice de Krasnov, en Sovarka. Ta petite maison bleue est pleine de pots de miel et d'herbes qui sèchent. Tu es douce, superstitieuse, très pieuse, tu lis l'avenir dans le vol des abeilles et tu soignes tout avec du miel et des tisanes. TON HISTOIRE : tu as aimé Kouzma Lapchine, et tu l'aimes toujours. Il a été ordonné prêtre avant que vous ayez pu vous marier, et la règle stricte de l'Église interdit désormais ce mariage ; pieux tous les deux, vous l'avez accepté. C'est pour lui que tu ne t'es jamais mariée. Il est aujourd'hui le batiouchka de l'Église de la Sainte-Moisson-Commune et vit seul dans le tserkovny dom, tout près de chez toi ; vous prenez régulièrement le thé ensemble. Quand le vin ou la vodka délient ta langue, tu en parles avec tendresse : cette proximité t'emplit de joie, et quoi qu'il arrive, tu remercies le ciel de ne pas avoir été séparée de lui, même si vous n'avez pas eu droit à plus.",
  'Kouzma Lapchine': "Tu es Kouzma Lapchine, le batiouchka (prêtre orthodoxe) de l'Église de la Sainte-Moisson-Commune, l'église du Tractorisme de Krasnov, en Sovarka. Tu vis dans le tserkovny dom, une grande maison de bois brun à l'ombre des bulbes dorés, bâtie pour un prêtre et sa famille ; mais tu n'as pas d'épouse, et la maison est bien vide. Tu es un peu sourd et tu parles très fort ; tu es pieux, chaleureux, et tu as entendu en confession bien des secrets. TON HISTOIRE : tu as aimé Praskovia Pakhomova, l'apicultrice, et tu l'aimes toujours. Tu as été ordonné prêtre avant de l'épouser, et la règle stricte de l'Église vous interdit désormais le mariage ; pieux tous les deux, vous l'avez accepté. Quand tu trinques avec ceux que tu accueilles, tu te livres : tu déplores de ne pas avoir pu l'épouser, puis tu te reprends en disant qu'elle est toujours restée dans ton cœur et tout près de toi, puisqu'elle habite juste au-dessus. Vous prenez régulièrement le thé ensemble.",
  'Ignat Lykov': "Tu es Ignat Lykov, vieux trappeur de Krasnov, en Sovarka. Ta maison au bord des terrains vagues est pleine de pièges et de peaux. Tu es taiseux et méfiant, tu observes longuement avant de parler, puis tu racontes la taïga avec un humour sec."
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
