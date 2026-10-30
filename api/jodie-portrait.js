// Portrait de Jodie : génération ET publication sous identité système côté serveur.
// Ne jamais autoriser le navigateur à écrire en tant que « Jodie Moitout ».
import { createHash, createHmac, timingSafeEqual } from 'node:crypto';
import { joueurAuthentifie, appelDeepSeek } from './_deepseek.js';

const URL = process.env.SUPABASE_URL || 'https://jxpwoosmmhohoihxpbuc.supabase.co';
const QUESTIONS = [
  'Qui êtes-vous ?', "Qu'est-ce qui vous a amené ici ?", "Qu'aimeriez-vous accomplir ?",
  'Quel regard portez-vous sur votre ville ou sur le pays ?',
  'Y a-t-il quelque chose que les habitants devraient savoir sur vous ?'
];
const TITRE = 'Un jour, un portrait : ';
const INVITATION = "Un portrait pour L'Autruche Entravée ?";
const REFUS = "Un portrait pour L'Autruche Entravée ? (classé)";
const EDITEUR = 'Jodie Moitout';

function entetes() {
  const secret = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!secret) throw new Error('service_non_configure');
  return { apikey: secret, Authorization: 'Bearer ' + secret, 'Content-Type': 'application/json' };
}
async function lire(table, filtre) {
  const r = await fetch(URL + '/rest/v1/' + table + '?' + filtre, { headers: entetes() });
  if (!r.ok) throw new Error('lecture_' + table + '_' + r.status);
  return r.json();
}
async function inserer(table, data) {
  const r = await fetch(URL + '/rest/v1/' + table, {
    method: 'POST', headers: { ...entetes(), Prefer: 'return=representation' },
    body: JSON.stringify(data)
  });
  if (!r.ok) throw new Error('ecriture_' + table + '_' + r.status);
  return r.json();
}
function signer(obj) {
  // Le token est lié à l'identité réelle, expire rapidement et ne dépend d'aucun état navigateur.
  const payload = Buffer.from(JSON.stringify(obj)).toString('base64url');
  const signature = createHmac('sha256', process.env.SUPABASE_SERVICE_ROLE_KEY).update(payload).digest('base64url');
  return payload + '.' + signature;
}
function verifier(token) {
  if (typeof token !== 'string' || token.length > 12000) return null;
  const parties = token.split('.');
  if (parties.length !== 2) return null;
  const attendu = createHmac('sha256', process.env.SUPABASE_SERVICE_ROLE_KEY).update(parties[0]).digest();
  let recu;
  try { recu = Buffer.from(parties[1], 'base64url'); } catch { return null; }
  if (recu.length !== attendu.length || !timingSafeEqual(recu, attendu)) return null;
  try {
    const d = JSON.parse(Buffer.from(parties[0], 'base64url').toString('utf8'));
    return d && typeof d.exp === 'number' && d.exp > Date.now() && d.exp <= Date.now() + 30 * 60 * 1000 ? d : null;
  } catch { return null; }
}
function nettoyer(s) {
  return s.replace(/\*\*(.+?)\*\*/g, '$1').replace(/\*(.+?)\*/g, '$1')
    .replace(/^#{1,6}\s+/gm, '').replace(/^[-*+]\s+/gm, '').replace(/[*#]/g, '').trim();
}
async function etat(nom) {
  const mails = await lire('mails',
    'to_player=eq.' + encodeURIComponent(nom) +
    '&from_player=eq.' + encodeURIComponent(EDITEUR) +
    '&subject=in.(' + encodeURIComponent('"'+INVITATION+'"') + ',' + encodeURIComponent('"'+REFUS+'"') + ')' +
    '&select=subject&limit=50');
  return {
    invite: mails.some(m => m.subject === INVITATION),
    refuse: mails.some(m => m.subject === REFUS)
  };
}
export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ ok: false, error: 'Méthode refusée.' });
  if (!process.env.SUPABASE_SERVICE_ROLE_KEY) return res.status(503).json({ ok: false, error: 'Service indisponible.' });
  const body = req.body;
  if (!body || typeof body !== 'object' || Array.isArray(body) ||
      typeof body.personnage !== 'string' || body.personnage.length > 100 || !body.personnage.trim()) {
    return res.status(400).json({ ok: false, error: 'Requête invalide.' });
  }
  const utilisateur = await joueurAuthentifie(req, { signal: AbortSignal.timeout(8000) });
  if (!utilisateur) return res.status(401).json({ ok: false, error: 'Connexion requise.' });
  try {
    const nom = body.personnage;
    const proprio = await lire('personnages_donnees',
      'name=eq.' + encodeURIComponent(nom) + '&user_id=eq.' + encodeURIComponent(utilisateur.id) + '&select=name&limit=1');
    if (!proprio.length) return res.status(403).json({ ok: false, error: 'Personnage non autorisé.' });
    const dossier = await etat(nom);
    if (!dossier.invite || dossier.refuse) return res.status(403).json({ ok: false, error: 'Interview non autorisée.' });
    const identifiant = createHash('sha256').update(utilisateur.id + ':' + nom).digest('hex').slice(0, 28);
    const topicId = 'topic-jodie-' + identifiant;
    const postId = 'post-jodie-' + identifiant;
    const ancien = await lire('forum_topics', 'id=eq.' + encodeURIComponent(topicId) + '&select=id&limit=1');
    if (ancien.length) {
      const posts = await lire('forum_posts', 'id=eq.' + encodeURIComponent(postId) + '&select=id&limit=1');
      if (posts.length) return res.status(409).json({ ok: false, error: 'Portrait déjà publié.' });
    }
    if (body.action === 'apercu') {
      if (!Array.isArray(body.reponses) || body.reponses.length !== 5 ||
          !body.reponses.every(s => typeof s === 'string' && s.trim().length && s.length <= 500)) {
        return res.status(400).json({ ok: false, error: 'Réponses incomplètes.' });
      }
      const contenu = QUESTIONS.map((q, i) => (i + 1) + '. ' + q + '\nRéponse : ' + body.reponses[i].trim()).join('\n\n');
      const prompt = "Tu es Jodie Moitout, journaliste du journal L'Autruche Entravée, dans Républia. " +
        'Rédige un court portrait (120 à 200 mots), à la troisième personne, fidèle strictement aux réponses ci-dessous. ' +
        'Ton enjoué et malicieux. Aucun fait substantiel inventé, aucun titre, aucun Markdown. Texte brut uniquement.\n\n' +
        'Personnage : ' + nom + '\n\n' + contenu;
      const generation = await appelDeepSeek({messages:[{role:'user',content:prompt}],maxTokens:550,timeoutMs:24000});
      if (!generation?.ok || typeof generation.texte !== 'string' || !generation.texte.trim()) {
        return res.status(503).json({ ok: false, error: 'Jodie ne peut pas rédiger actuellement.' });
      }
      const texte = nettoyer(generation.texte).slice(0,6000);
      const jeton = signer({nom, uid: utilisateur.id, texte, exp: Date.now() + 20 * 60 * 1000});
      return res.status(200).json({ok:true, texte, jeton});
    }
    if (body.action !== 'publier') return res.status(400).json({ok:false,error:'Action inconnue.'});
    const preuve = verifier(body.jeton);
    if (!preuve || preuve.nom !== nom || preuve.uid !== utilisateur.id || typeof preuve.texte !== 'string' || !preuve.texte.trim()) {
      return res.status(403).json({ok:false,error:'Aperçu expiré ou invalide. Régénérez le portrait.'});
    }
    const time = new Date().toISOString();
    if (!ancien.length) {
      try {
        await inserer('forum_topics', {id:topicId, forum_id:'presse',title:TITRE+nom,author:EDITEUR,country:'republic',
          time,views:1,replies:0,last_post_author:EDITEUR,last_post_time:time,author_is_org:false,author_secret:false});
      } catch (e) {
        // Une écriture concurrente peut avoir inséré le sujet ; vérifier son existence.
        const existant = await lire('forum_topics','id=eq.'+encodeURIComponent(topicId)+'&select=id&limit=1');
        if (!existant.length) throw e;
      }
    }
    const dejaPost = await lire('forum_posts','id=eq.'+encodeURIComponent(postId)+'&select=id&limit=1');
    if (!dejaPost.length) {
      try {
        await inserer('forum_posts',{id:postId,topic_id:topicId,author:EDITEUR,content:preuve.texte,
          time,author_is_org:false,author_secret:false,content_blocks:[],content_layout:null});
      } catch (e) {
        const existant = await lire('forum_posts','id=eq.'+encodeURIComponent(postId)+'&select=id&limit=1');
        if (!existant.length) throw e;
      }
    }
    return res.status(200).json({ok:true, dejaPublie:!!dejaPost.length});
  } catch (e) {
    // Ne pas transmettre les détails des tables ou les erreurs SQL au client.
    console.error('jodie_portrait_echec', e?.message || 'inconnu');
    return res.status(503).json({ok:false,error:'La publication est momentanément indisponible. Réessayez.'});
  }
}
