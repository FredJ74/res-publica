// Portrait d'accueil (« Un jour, un portrait ») : invitation, refus, rédaction ET publication sous
// identité système côté serveur. Ne jamais autoriser le navigateur à écrire au nom d'un journaliste.
//
// Interview d'accueil des nouveaux personnages (Fred, 21/11/2026, GAME-DESIGN-INTERVIEW-ACCUEIL-20261121.md) :
//   1. l'invitation vient du journaliste de l'antenne de la ville où se trouve le personnage
//      (api/_presse-antennes.js) ; Jodie Moitout n'interviewe que les personnages de Luthécia ;
//      une antenne sans journaliste nommé n'envoie rien ;
//   2. une invitation envoyée est toujours publiable, premier jour compris : le verrou « Portrait
//      disponible après le premier jour » ne s'applique plus aux réponses. Il n'avait de raison
//      d'être que parce que le navigateur écrivait lui-même l'invitation (donc falsifiable) :
//      c'est désormais ce serveur qui l'écrit (action 'inviter'), et la migration
//      20261122150000_interview_accueil_invitation_serveur retire au navigateur le droit d'écrire
//      au nom de Jodie Moitout ;
//   3. toute condition bloquante se vérifie AVANT d'ouvrir le formulaire (action 'etat').
//
// Actions : 'etat', 'inviter', 'refuser', 'apercu', 'publier'.
import { createHash, createHmac, timingSafeEqual } from 'node:crypto';
import { joueurAuthentifie, appelDeepSeek } from './_deepseek.js';
import { ANTENNES_PRESSE, TITRE_PORTRAIT, sujetInvitation, sujetRefus, antennePour, antenneDuJournaliste, journalistesPresse } from './_presse-antennes.js';

const URL = process.env.SUPABASE_URL || 'https://jxpwoosmmhohoihxpbuc.supabase.co';
const QUESTIONS = [
  'Qui êtes-vous ?', "Qu'est-ce qui vous a amené ici ?", "Qu'aimeriez-vous accomplir ?",
  'Quel regard portez-vous sur votre ville ou sur le pays ?',
  'Y a-t-il quelque chose que les habitants devraient savoir sur vous ?'
];
const TITRE = TITRE_PORTRAIT;
// Délai avant l'ENVOI de l'invitation (inchangé : jamais le jour même de la création). Il ne bloque
// plus jamais les réponses à une invitation déjà reçue.
const DELAI_INVITATION_MS = 86400000;

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
async function modifier(table, filtre, data) {
  const r = await fetch(URL + '/rest/v1/' + table + '?' + filtre, {
    method: 'PATCH', headers: { ...entetes(), Prefer: 'return=minimal' }, body: JSON.stringify(data)
  });
  if (!r.ok) throw new Error('modification_' + table + '_' + r.status);
}
// Courrier système (même RPC que le cron du journal) : appel serveur, donc aucune règle d'expéditeur
// du navigateur ne s'applique, et le courrier perdu est consigné par la base.
async function envoyerCourrier(expediteur, destinataire, sujet, corps, heure) {
  const r = await fetch(URL + '/rest/v1/rpc/mail_systeme_envoyer', {
    method: 'POST', headers: entetes(),
    body: JSON.stringify({ p_expediteur: expediteur, p_destinataire: destinataire, p_sujet: sujet, p_corps: corps, p_heure: heure || null })
  });
  if (!r.ok) throw new Error('courrier_' + r.status);
  const v = await r.json();
  const verdict = Array.isArray(v) ? v[0] : v;
  if (!verdict || verdict.ok !== true) throw new Error('courrier_refuse_' + (verdict?.raison || 'inconnu'));
  return verdict.id || null;
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
// personnages.created_at est un « timestamp without time zone » écrit en UTC. Sans le « Z », le
// navigateur le lisait en heure de Paris et le serveur en UTC : une heure d'écart. C'est ce qui a
// fait recevoir à Tom Tom (23 h après sa création) une invitation que le serveur refusait ensuite.
function instantUtc(valeur) {
  if (typeof valeur !== 'string' || !valeur) return NaN;
  const iso = valeur.replace(' ', 'T');
  return Date.parse(/[zZ]|[+-]\d\d:?\d\d$/.test(iso) ? iso : iso + 'Z');
}
const liste = noms => '(' + noms.map(n => encodeURIComponent('"' + n + '"')).join(',') + ')';

// Dossier d'accueil du personnage, lu en base à chaque appel (jamais un état du navigateur).
// L'antenne qui compte pour répondre est celle qui a INVITÉ (le personnage a pu changer de ville
// depuis) ; l'antenne de la ville actuelle ne sert qu'à choisir qui invite.
async function dossier(nom) {
  const sujets = ANTENNES_PRESSE.flatMap(a => [sujetInvitation(a), sujetRefus(a)]);
  const [mails, publies] = await Promise.all([
    lire('mails', 'to_player=eq.' + encodeURIComponent(nom) +
      '&from_player=in.' + liste(journalistesPresse()) +
      '&subject=in.' + liste([...new Set(sujets)]) + '&select=id,from_player,subject&limit=50'),
    lire('forum_topics', 'forum_id=eq.presse&author=in.' + liste(journalistesPresse()) +
      '&title=eq.' + encodeURIComponent(TITRE + nom) + '&select=id,author&limit=5')
  ]);
  // Publié = un sujet ET son texte. Un sujet resté sans texte (panne au milieu de la publication)
  // ne doit pas bloquer le personnage : il pourra republier.
  const posts = publies.length ? await lire('forum_posts', 'topic_id=in.' + liste(publies.map(t => t.id)) + '&select=id&limit=1') : [];
  let antenne = null, refuse = false;
  for (const m of mails) {
    const a = antenneDuJournaliste(m.from_player);
    if (!a) continue;
    if (m.subject === sujetRefus(a)) refuse = true;
    else if (m.subject === sujetInvitation(a) && !antenne) antenne = a;
  }
  return { antenne, refuse, publie: posts.length > 0, contacte: mails.length > 0 };
}
function etatPublic(d) {
  const peutRepondre = !!d.antenne && !d.refuse && !d.publie;
  return {
    ok: true, peutRepondre,
    raison: peutRepondre ? null : d.publie ? 'deja_publie' : d.refuse ? 'refuse' : 'pas_invite',
    journaliste: d.antenne?.journaliste || null, journal: d.antenne?.journal || null,
    ville: d.antenne?.villeNom || null, questions: QUESTIONS
  };
}
function corpsInvitation(a) {
  if (a.journaliste === 'Jodie Moitout') {
    return "Bonjour,<br><br>" +
      "Jodie Moitout, journaliste à <em>L'Autruche Entravée</em> — le petit dernier du groupe La Tribune, celui qui pose les questions que les autres n'osent pas.<br><br>" +
      "Un nouveau visage en ville, ça ne m'échappe jamais très longtemps. Ça vous dirait de répondre à quelques questions pour un petit portrait ? Rien de formel — juste de quoi donner un visage à votre nom, pour la rubrique Presse &amp; Médias.<br><br>" +
      "Libre à vous d'accepter ou de décliner, bien sûr : les deux boutons sont juste en dessous.<br><br>" +
      "Jodie Moitout<br><br>" +
      "<em>« Tout le monde a une histoire. La mienne, c'est de la trouver. »</em>";
  }
  return 'Bonjour,<br><br>' +
    a.journaliste + ', journaliste à <em>' + a.journal + '</em>, antenne de ' + a.villeNom + '.<br><br>' +
    'Un nouveau visage en ville, ça se remarque. Accepteriez-vous de répondre à cinq questions pour un petit portrait ? ' +
    'Il sera publié dans la rubrique Presse &amp; Médias, seulement après votre accord.<br><br>' +
    'Libre à vous d\'accepter ou de refuser : les deux boutons sont juste en dessous.<br><br>' + a.journaliste;
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
    const heure = typeof body.heure === 'string' && body.heure.length <= 40 ? body.heure.replace(/[<>]/g, '') : null;

    if (body.action === 'etat') return res.status(200).json(etatPublic(await dossier(nom)));

    if (body.action === 'inviter') {
      const fiches = await lire('personnages',
        'name=eq.' + encodeURIComponent(nom) + '&select=created_at,country,current_city&limit=1');
      const fiche = fiches[0];
      const naissance = instantUtc(fiche?.created_at);
      if (!Number.isFinite(naissance) || Date.now() - naissance < DELAI_INVITATION_MS) {
        return res.status(200).json({ ok: true, envoye: false, raison: 'trop_tot' });
      }
      const antenne = antennePour(fiche.country, fiche.current_city);
      if (!antenne) return res.status(200).json({ ok: true, envoye: false, raison: 'aucun_journaliste' });
      const d = await dossier(nom);
      // Déjà contacté (invitation ou refus, quelle que soit l'antenne) ou portrait déjà publié : jamais deux fois.
      if (d.contacte || d.publie) return res.status(200).json({ ok: true, envoye: false, raison: 'deja' });
      await envoyerCourrier(antenne.journaliste, nom, sujetInvitation(antenne), corpsInvitation(antenne), heure);
      return res.status(200).json({ ok: true, envoye: true, journaliste: antenne.journaliste });
    }

    const d = await dossier(nom);
    if (body.action === 'refuser') {
      if (!d.antenne) return res.status(403).json({ ok: false, error: "Aucune invitation à refuser." });
      if (d.refuse) return res.status(200).json({ ok: true, dejaRefuse: true });
      const a = d.antenne;
      const corps = "Compris, on n'en parle plus : aucun portrait de vous ne sera publié.<br><br>" + a.journaliste;
      const id = await envoyerCourrier(a.journaliste, nom, sujetRefus(a), corps, heure);
      // Le refus est archivé tout de suite : il fait foi pour toujours (jamais purgé avec la boîte).
      if (id) await modifier('mails', 'id=eq.' + encodeURIComponent(id), { archived: true }).catch(() => {});
      return res.status(200).json({ ok: true });
    }

    if (!d.antenne || d.refuse) return res.status(403).json({ ok: false, error: 'Interview non autorisée.' });
    const a = d.antenne;
    const identifiant = createHash('sha256').update(utilisateur.id + ':' + nom).digest('hex').slice(0, 28);
    const topicId = 'topic-jodie-' + identifiant;
    const postId = 'post-jodie-' + identifiant;
    const ancien = await lire('forum_topics', 'id=eq.' + encodeURIComponent(topicId) + '&select=id&limit=1');
    if (ancien.length) {
      const posts = await lire('forum_posts', 'id=eq.' + encodeURIComponent(postId) + '&select=id&limit=1');
      if (posts.length) {
        // Si la réponse précédente a été perdue, publier est une réussite idempotente.
        if (body.action === 'publier') return res.status(200).json({ok:true,dejaPublie:true});
        return res.status(409).json({ok:false,error:'Portrait déjà publié.'});
      }
    }
    // Portrait déjà publié sous un autre identifiant (personnage passé d'un compte à un autre).
    if (d.publie) return res.status(409).json({ok:false,error:'Portrait déjà publié.'});
    if (body.action === 'apercu') {
      if (!Array.isArray(body.reponses) || body.reponses.length !== 5 ||
          !body.reponses.every(s => typeof s === 'string' && s.trim().length && s.length <= 500)) {
        return res.status(400).json({ ok: false, error: 'Réponses incomplètes.' });
      }
      const contenu = QUESTIONS.map((q, i) => (i + 1) + '. ' + q + '\nRéponse : ' + body.reponses[i].trim()).join('\n\n');
      const ton = a.journaliste === 'Jodie Moitout' ? 'Ton enjoué et malicieux.' : 'Ton vivant et bienveillant.';
      const prompt = 'Tu es ' + a.journaliste + ', journaliste du journal ' + a.journal + ', à ' + a.villeNom + ', dans ' + a.paysNom + '. ' +
        'Rédige un court portrait (120 à 200 mots), à la troisième personne, fidèle strictement aux réponses ci-dessous. ' +
        ton + ' Aucun fait substantiel inventé, aucun titre, aucun Markdown. Texte brut uniquement.\n\n' +
        'Personnage : ' + nom + '\n\n' + contenu;
      const generation = await appelDeepSeek({messages:[{role:'user',content:prompt}],maxTokens:550,timeoutMs:24000});
      if (!generation?.ok || typeof generation.texte !== 'string' || !generation.texte.trim()) {
        return res.status(503).json({ ok: false, error: a.journaliste + ' ne peut pas rédiger pour le moment. Vos réponses sont gardées : réessayez dans un instant.' });
      }
      const texte = nettoyer(generation.texte).slice(0,6000);
      const jeton = signer({nom, uid: utilisateur.id, texte, journaliste: a.journaliste, exp: Date.now() + 20 * 60 * 1000});
      return res.status(200).json({ok:true, texte, jeton, journaliste: a.journaliste, journal: a.journal});
    }
    if (body.action !== 'publier') return res.status(400).json({ok:false,error:'Action inconnue.'});
    const preuve = verifier(body.jeton);
    if (!preuve || preuve.nom !== nom || preuve.uid !== utilisateur.id || typeof preuve.texte !== 'string' || !preuve.texte.trim()) {
      return res.status(403).json({ok:false,error:'Aperçu expiré ou invalide. Régénérez le portrait.'});
    }
    const auteur = (preuve.journaliste && antenneDuJournaliste(preuve.journaliste)) ? preuve.journaliste : a.journaliste;
    const pays = antenneDuJournaliste(auteur)?.pays || a.pays;
    const time = new Date().toISOString();
    if (!ancien.length) {
      try {
        await inserer('forum_topics', {id:topicId, forum_id:'presse',title:TITRE+nom,author:auteur,country:pays,
          time,views:1,replies:0,last_post_author:auteur,last_post_time:time,author_is_org:false,author_secret:false});
      } catch (e) {
        // Une écriture concurrente peut avoir inséré le sujet ; vérifier son existence.
        const existant = await lire('forum_topics','id=eq.'+encodeURIComponent(topicId)+'&select=id&limit=1');
        if (!existant.length) throw e;
      }
    }
    const dejaPost = await lire('forum_posts','id=eq.'+encodeURIComponent(postId)+'&select=id&limit=1');
    if (!dejaPost.length) {
      try {
        await inserer('forum_posts',{id:postId,topic_id:topicId,author:auteur,content:preuve.texte,
          time,author_is_org:false,author_secret:false,content_blocks:[],content_layout:null});
      } catch (e) {
        const existant = await lire('forum_posts','id=eq.'+encodeURIComponent(postId)+'&select=id&limit=1');
        if (!existant.length) throw e;
      }
    }
    return res.status(200).json({ok:true, dejaPublie:!!dejaPost.length, journaliste: auteur});
  } catch (e) {
    // Ne pas transmettre les détails des tables ou les erreurs SQL au client.
    console.error('jodie_portrait_echec', e?.message || 'inconnu');
    return res.status(503).json({ok:false,error:'Le serveur de la presse ne répond pas. Vos réponses sont gardées : réessayez dans un instant.'});
  }
}
