// =====================
// API VERCEL — LA CONFERENCE DE PRESSE (11 octobre 2026)
// =====================
// LES JOURNALISTES ACCREDITES POSENT LEURS QUESTIONS DEPUIS ICI, ET DE NULLE PART AILLEURS.
//
// POURQUOI CET ENDPOINT N'EST PAS UN USAGE DE /api/redaction. Les seize usages de la redaction
// rendent un TEXTE au navigateur, qui en fait ce qu'il veut. Ici, le texte produit doit etre
// ECRIT EN BASE avant d'etre montre, sous identite de service, parce que c'est la transcription
// d'une conference officielle : si le navigateur recevait la question et la renvoyait pour
// enregistrement, il pourrait l'ecrire autrement -- donc choisir ce que les journalistes lui
// demandent. `conference_question_poser` n'est appelable QUE par le service, et c'est ici que
// vit cette identite.
//
// CE QUE L'IA RECOIT, ET RIEN DE PLUS :
//   . la fonction publique de celui qui parle, telle qu'elle etait au moment de la communication ;
//   . le titre et le texte de la communication, tels qu'ils ont ete declares ;
//   . les questions deja posees, les reponses EXACTES, et les refus, dans l'ordre ;
//   . quelques faits publics recents du pays, tels que la chronique nationale les a enregistres.
// Aucune statistique privee, aucun solde, aucune relation, aucun jugement anterieur.
//
// CE QUE L'IA N'A PAS LE DROIT DE FAIRE, et qui est ecrit dans son prompt :
//   . dire qu'une reponse est vraie ou fausse, ni qu'un ministre mente ;
//   . interpreter un refus de repondre ;
//   . produire une note, un score, une appreciation de credibilite ou de qualite ;
//   . inventer un fait qui ne lui a pas ete donne.
// ELLE FORMULE DES QUESTIONS. CE SONT LES HUMAINS QUI JUGENT LES REPONSES.
//
// LE MINIMUM D'UNE QUESTION NE DEPEND PAS DU FOURNISSEUR. Si l'IA est en panne, coupee, hors
// credit ou hors delai, une question neutre DETERMINISTE est posee a sa place : une communication
// officielle deja payee ne doit jamais se retrouver sans conference. Au-dela de la premiere
// question, une panne ferme la conference NORMALEMENT -- ce qui a eu lieu est conserve.

import { appelDeepSeek, joueurAuthentifie } from './_deepseek.js';
import { sbRpcVerdict, sbGetVerdict, identiteServeurDisponible } from './_supabase.js';

const ALLOWED_ORIGIN = 'https://res-publica.vercel.app';

// LE SERVEUR IMPOSE LA LONGUEUR, comme pour les seize usages de la redaction. Une question de
// journaliste est courte : 120 jetons sont largement au-dessus de ce qu'une question reelle
// demande, et bornent le cout.
const JETONS_QUESTION = 120;
const DELAI_FOURNISSEUR_MS = 20000;

// LE MAXIMUM EST DEJA TENU PAR LA BASE (contrainte `echange_rang_borne` et la porte
// `conference_question_poser`). Il est redit ici pour fermer la conference NORMALEMENT au lieu
// de laisser la porte refuser : la fin d'une conference n'est pas une erreur.
const QUESTIONS_MAXIMUM = 5;

// LES QUESTIONS DE REPLI. Neutres, factuelles, sans presupposition sur la veracite de quoi que ce
// soit. Deterministes par rang : la meme panne, au meme moment, pose la meme question -- on ne
// tire pas au sort le contenu d'une transcription officielle.
const REPLI = [
  // Sans civilité (31/10/2026) : « Monsieur le Ministre » supposait à la fois le genre et la fonction.
  'Pouvez-vous préciser ce que cette annonce change concrètement, et à partir de quand ?',
  'Qui est chargé de l\'application de ce que vous venez d\'annoncer ?',
  'Quels moyens avez-vous prévus pour cela ?',
  'Un calendrier a-t-il été arrêté ?',
  'Souhaitez-vous ajouter quelque chose à l\'intention des Républiains ?'
];

// ---------------------------------------------------------------------------
// LE PROMPT
// ---------------------------------------------------------------------------
function texteSeul(html) {
  return String(html || '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|h[1-6]|li)>/gi, '\n')
    .replace(/<[^>]*>/g, '')
    .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/\n{3,}/g, '\n\n').trim();
}

const SYSTEME = [
  'Tu es un journaliste accrédité qui couvre une conférence de presse officielle du gouvernement de',
  'Républia. Tu poses UNE SEULE question, en français, à la personne qui vient de s\'exprimer.',
  '',
  'CE QUE TU PEUX FAIRE : relancer sur ce qui vient d\'être dit, changer d\'angle, demander une',
  'précision, revenir sur une réponse précédente, ou interroger sur une affaire publique récente',
  'du pays même si elle sort du sujet de la communication.',
  '',
  'CE QUE TU NE FAIS JAMAIS :',
  '- tu ne dis pas si une réponse est vraie ou fausse, tu n\'accuses personne de mentir ;',
  '- tu n\'interprètes pas un refus de répondre et tu ne lui prêtes aucune intention ;',
  '- tu ne donnes aucune note, aucun score, aucune appréciation de crédibilité ou de qualité ;',
  '- tu n\'inventes aucun fait : tu n\'utilises que ce qui t\'est donné ci-dessous ;',
  '- tu ne commentes pas, tu ne conclus pas, tu ne résumes pas.',
  '',
  'FORME : une seule phrase interrogative, vouvoiement, 30 mots au maximum, sans guillemets, sans',
  'préambule, sans ton nom. Rien d\'autre que la question.',
  '',
  'SI PLUS AUCUN ANGLE PERTINENT NE RESTE, réponds exactement : FIN'
].join('\n');

// LA CIVILITE (31/10/2026). Le genre vient de pnj_contexte_public(), lu sur la fiche du personnage
// authentifie (l'auteur de la conference) et normalise : 'H', 'F', 'neutre' ou null. Il n'est
// jamais recu du navigateur, et sans genre verifie le journaliste ne suppose rien.
function ligneCivilite(genre) {
  if (genre === 'H') return 'CIVILITÉ (fiche vérifiée) : masculin. « Monsieur », titres et accords au masculin (« Monsieur le ministre »…), jamais « Madame ».';
  if (genre === 'F') return 'CIVILITÉ (fiche vérifiée) : féminin. « Madame », titres et accords au féminin (« Madame la ministre »…), jamais « Monsieur ».';
  if (genre === 'neutre') return 'CIVILITÉ (fiche vérifiée) : ni « Monsieur » ni « Madame » ; aucune civilité genrée, tournures sans accord de genre.';
  return 'CIVILITÉ : genre non vérifié. N\'emploie ni « Monsieur » ni « Madame » ni titre accordé au genre ; ne le déduis ni du nom ni de la fonction.';
}

function construireMessage(conf, echanges, contexte, genre) {
  const l = [];
  l.push('QUI PARLE : ' + (conf.fonction || conf.auteur || 'un responsable du gouvernement') + '.');
  l.push(ligneCivilite(genre));
  l.push('');
  l.push('COMMUNICATION OFFICIELLE — « ' + (conf.titre || '') + ' »');
  l.push(texteSeul(conf.communication).slice(0, 4000));
  if (contexte && contexte.length) {
    l.push('');
    l.push('FAITS PUBLICS RÉCENTS DU PAYS (pour pouvoir élargir ; aucun autre fait n\'existe) :');
    contexte.forEach(f => l.push('- ' + f));
  }
  if (echanges && echanges.length) {
    l.push('');
    l.push('CE QUI A DÉJÀ ÉTÉ ÉCHANGÉ DANS CETTE CONFÉRENCE :');
    echanges.forEach(e => {
      l.push('Question ' + e.rang + ' : ' + e.question);
      if (e.refus) l.push('Réponse ' + e.rang + ' : a refusé de répondre.');
      else if (e.reponse) l.push('Réponse ' + e.rang + ' : ' + String(e.reponse).slice(0, 1500));
    });
    l.push('');
    l.push('Pose maintenant ta question suivante, ou FIN s\'il ne reste rien de pertinent.');
  } else {
    l.push('');
    l.push('Pose la première question de la conférence.');
  }
  return l.join('\n');
}

// ---------------------------------------------------------------------------
// LE CONTEXTE PUBLIC RECENT
// ---------------------------------------------------------------------------
// LA CHRONIQUE NATIONALE EST LA COUCHE PUBLIQUE DU JEU, et son `libelle` est deja une phrase
// factuelle ecrite au point d'ecriture -- on ne la reinterprete pas, on la recopie. La ligne de
// CETTE conference en est exclue : la rappeler a l'IA n'apporte rien et ferait boucle.
//
// UNE PANNE DE LECTURE NE CASSE RIEN : le contexte est un PLUS, pas une condition. Sans lui, le
// journaliste s'en tient a la communication -- ce qui reste une conference valide.
// Le genre de l'auteur, lu par le canal commun des PNJ (pnj_contexte_public, jeton du joueur).
// Une panne de lecture rend null : la question reste posée, sans civilité genrée.
async function genreDeLAuteur(jeton) {
  const r = await sbRpcVerdict('pnj_contexte_public', {}, { jeton }).catch(() => null);
  const d = r && r.ok ? (Array.isArray(r.donnees) ? r.donnees[0] : r.donnees) : null;
  return d && d.ok === true && ['H', 'F', 'neutre'].includes(d.genre) ? d.genre : null;
}

async function contextePublicRecent(pays, exclureId) {
  const depuis = new Date(Date.now() - 48 * 3600 * 1000).toISOString();
  const r = await sbGetVerdict('chronique_nationale',
    'country=eq.' + encodeURIComponent(pays)
    + '&created_at=gte.' + encodeURIComponent(depuis)
    + '&select=id,libelle&order=created_at.desc&limit=12', { service: true }).catch(() => null);
  if (!r || !r.ok || !Array.isArray(r.donnees)) return [];
  return r.donnees
    .filter(x => x && x.id !== exclureId && typeof x.libelle === 'string' && x.libelle.trim())
    .map(x => x.libelle.trim().slice(0, 300))
    .slice(0, 10);
}

// ---------------------------------------------------------------------------
// L'ENDPOINT
// ---------------------------------------------------------------------------
export default async function handler(req, res) {
  const origin = req.headers.origin;
  if (origin === ALLOWED_ORIGIN) res.setHeader('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const body = req.body;
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return res.status(400).json({ error: 'Corps de requête invalide.' });
  }
  if (Object.keys(body).some(k => k !== 'conference')) {
    return res.status(400).json({ error: 'Champ non autorisé.' });
  }
  const id = body.conference;
  if (typeof id !== 'string' || !/^conf-[0-9]{6,20}$/.test(id)) {
    return res.status(400).json({ error: 'Conférence invalide.' });
  }

  // L'AUTHENTIFICATION EST REELLE, comme partout ailleurs : le jeton est presente a Supabase.
  const utilisateur = await joueurAuthentifie(req);
  if (!utilisateur) return res.status(401).json({ error: 'Authentification requise.' });

  // SANS IDENTITE DE SERVICE, ON NE FAIT RIEN. Poser une question exige d'ecrire sous une
  // identite que le navigateur n'a pas ; retomber sur son jeton ferait echouer l'ecriture en
  // silence et laisserait la pop-up vide sans dire pourquoi.
  if (!identiteServeurDisponible()) {
    console.error('conference : SUPABASE_SERVICE_ROLE_KEY absente');
    return res.status(503).json({ error: 'Conférence momentanément indisponible.' });
  }

  // QUI DEMANDE ? La porte de lecture admet l'auteur ET la presse du pays -- c'est bien pour
  // lire, mais un journaliste ne doit pas pouvoir declencher les questions de la conference d'un
  // ministre. On relit donc le personnage du demandeur et on exige qu'il soit l'auteur.
  const moi = await sbRpcVerdict('mon_personnage', {}, { jeton: utilisateur.jeton }).catch(() => null);
  // PostgREST rend un scalaire tel quel ; on accepte aussi la forme tableau, parce qu'une
  // erreur de lecture d'identite ici autoriserait la conference d'autrui.
  const brutNom = moi && moi.ok
    ? (Array.isArray(moi.donnees) ? moi.donnees[0] : moi.donnees) : null;
  const monNom = (typeof brutNom === 'string' && brutNom.trim()) ? brutNom.trim() : null;
  if (!monNom) return res.status(401).json({ error: 'Personnage introuvable.' });

  const lu = await sbRpcVerdict('conference_lire', { p_conference_id: id }, { service: true })
    .catch(() => null);
  if (!lu || !lu.ok || !lu.donnees || lu.donnees.ok !== true) {
    return res.status(404).json({ error: 'Conférence inconnue.' });
  }
  const conf = lu.donnees.conference || {};
  const echanges = Array.isArray(lu.donnees.echanges) ? lu.donnees.echanges : [];

  if (conf.auteur !== monNom) return res.status(403).json({ error: 'Ce n\'est pas votre conférence.' });
  if (conf.statut !== 'ouverte') {
    return res.status(200).json({ ok: true, fin: true, statut: conf.statut, echanges });
  }
  // UNE QUESTION SANS SUITE EST DEJA POSEE : on la rend telle quelle plutot que d'en poser une
  // seconde. C'est ce qui rend l'appel REJOUABLE -- un rechargement de page ne duplique rien.
  const enAttente = echanges.find(e => e.reponse == null && !e.refus);
  if (enAttente) {
    return res.status(200).json({ ok: true, rang: enAttente.rang, question: enAttente.question,
                                  echanges });
  }

  // LE NOMBRE DE QUESTIONS N'EST PAS DECIDE A L'AVANCE : il se decide ici, apres chaque reponse.
  const rang = echanges.length + 1;
  if (rang > QUESTIONS_MAXIMUM) {
    await sbRpcVerdict('conference_clore', { p_conference_id: id, p_interrompue: false },
                       { service: true }).catch(() => null);
    return res.status(200).json({ ok: true, fin: true, statut: 'terminee', echanges });
  }

  const [contexte, genre] = await Promise.all([
    contextePublicRecent(conf.pays, conf.chronique_id || null),
    genreDeLAuteur(utilisateur.jeton)
  ]);
  const ia = await appelDeepSeek({
    systeme: SYSTEME,
    messages: [{ role: 'user', content: construireMessage(conf, echanges, contexte, genre) }],
    maxTokens: JETONS_QUESTION,
    timeoutMs: DELAI_FOURNISSEUR_MS
  });

  let question = null;
  let fournisseurMuet = false;
  if (ia && ia.ok && typeof ia.texte === 'string') {
    const t = ia.texte.trim().replace(/^[«"'\s]+|[»"'\s]+$/g, '').trim();
    if (/^FIN\b/i.test(t) || t.length === 0) {
      // L'IA ESTIME QU'IL NE RESTE RIEN. C'est son droit, et c'est la fin naturelle voulue --
      // SAUF avant la premiere question : une communication officielle a toujours droit a au
      // moins une question.
      if (rang > 1) {
        await sbRpcVerdict('conference_clore', { p_conference_id: id, p_interrompue: false },
                           { service: true }).catch(() => null);
        return res.status(200).json({ ok: true, fin: true, statut: 'terminee', echanges });
      }
    } else {
      question = t.slice(0, 600);
    }
  } else {
    fournisseurMuet = true;
  }

  if (!question) {
    // LE REPLI. Au premier rang, une question neutre est posee quoi qu'il arrive. Au-dela, une
    // panne du fournisseur ferme la conference NORMALEMENT : ce qui a eu lieu est conserve, la
    // communication reste publiee, et rien n'est corrompu.
    if (rang > 1 && fournisseurMuet) {
      await sbRpcVerdict('conference_clore', { p_conference_id: id, p_interrompue: false },
                         { service: true }).catch(() => null);
      return res.status(200).json({ ok: true, fin: true, statut: 'terminee', echanges });
    }
    question = REPLI[Math.min(rang, REPLI.length) - 1];
  }

  const pose = await sbRpcVerdict('conference_question_poser',
    { p_conference_id: id, p_question: question }, { service: true }).catch(() => null);
  if (!pose || !pose.ok || !pose.donnees || pose.donnees.ok !== true) {
    const raison = pose && pose.donnees && pose.donnees.raison;
    if (raison === 'maximum_de_questions_atteint' || raison === 'conference_close') {
      return res.status(200).json({ ok: true, fin: true, statut: 'terminee', echanges });
    }
    console.error('conference : question refusee (' + (raison || 'transport') + ')');
    // LA COMMUNICATION N'EST NI ANNULEE NI CORROMPUE : on rend un echec de CONFERENCE, et la
    // pop-up proposera de reessayer. Rien n'a ete ecrit.
    return res.status(502).json({ error: 'La salle de presse est momentanément indisponible.' });
  }

  return res.status(200).json({
    ok: true, rang: pose.donnees.rang, question: pose.donnees.question,
    echanges
  });
}

// Exposés pour les bancs (aucun effet sur le point d'entrée).
export { construireMessage, ligneCivilite, REPLI };
