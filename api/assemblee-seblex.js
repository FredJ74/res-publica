// ===========================================================================
// SEB LEX — LE JURISTE DE L'ASSEMBLEE NATIONALE
// ---------------------------------------------------------------------------
// Seb Lex met en forme l'intention d'un deposant. Il n'est ni conseiller
// politique, ni militant, ni depute, ni juge de l'opportunite d'une loi : c'est
// un legiste. Il transforme « je veux interdire le bois » en un projet clair,
// accompagne d'une portee mecanique que le moteur sait REELLEMENT appliquer.
//
// IL N'EST JAMAIS LA SOURCE DE VERITE JURIDIQUE. Deux garanties, et la seconde
// est la seule qui compte vraiment :
//   1. sa vision du monde vient du CATALOGUE lu en base
//      (assemblee_catalogue_legislatif) : il ne connait ni matiere, ni categorie,
//      ni effet qui n'existe pas dans le jeu ;
//   2. tout ce qu'il repond est REVALIDE ici contre ce meme catalogue, puis une
//      troisieme fois au depot par assemblee_deposer_projet. Le texte naturel
//      qu'il redige ne sera JAMAIS reinterprete pour determiner un effet : seule
//      la portee structuree compte, et elle passe par une liste fermee.
//
// CE QU'IL NE FAIT PAS : il ne depose rien, ne debite aucun PA, ne touche a
// aucune table. La conversation est gratuite ; le cout du depot (1 PA) est
// preleve par la RPC de depot, et par elle seule.
//
// REUTILISATION, PAS SECONDE ARCHITECTURE : le fournisseur est celui de tout le
// projet (api/_deepseek.js), avec son mode json_object -- exactement comme le
// Journal. L'authentification est celle de /api/chat et /api/redaction.
//
// FRAGILITE EVITEE, celle du 29 septembre : aucune construction de prompt hors
// try/catch, et aucun champ au type variable. Tout ce qui vient de l'IA est lu
// avec un type verifie avant usage.
// ===========================================================================

import { appelDeepSeek, joueurAuthentifie, classerEchecFournisseur } from './_deepseek.js';
import { sbRpcVerdict, sbGetVerdict } from './_supabase.js';

const ALLOWED_ORIGIN = 'https://res-publica.vercel.app';

// Bornes de la conversation. Courtes volontairement : Seb doit conclure, pas
// bavarder, et chaque tour est un appel paye.
const MAX_MESSAGE      = 1200;
const MAX_HISTORIQUE   = 8;     // 4 echanges : au-dela, Seb doit avoir conclu
const MAX_CONTENU_TOUR = 1200;
const MAX_TOKENS       = 700;   // une synthese + une portee, pas un memoire
const TIMEOUT_MS       = 25000;

// LA CONFIGURATION SUPABASE VIENT DESORMAIS DE api/_supabase.js (chantier 5, 9 octobre 2026).
// Elle etait recopiee ici, comme dans huit autres fonctions de api/ : neuf exemplaires de la
// meme URL et de la meme cle, qu'il fallait penser a changer neuf fois.

// ---------------------------------------------------------------------------
// LE CATALOGUE — LU EN BASE, SOUS L'IDENTITE DU JOUEUR
// ---------------------------------------------------------------------------
// LE JETON DU JOUEUR, PAS LA CLE ANON, et c'est structurel : la RLS doit voir SON auth.uid()
// pour ne lui montrer que ce que la loi de SON empire autorise. Le socle porte cette identite
// explicitement (`{ jeton }`), au lieu que chaque appelant recompose ses en-tetes a la main.
//
// LE CONTRAT DE RETOUR EST INCHANGE : `null` des que le catalogue n'est pas exploitable, quelle
// qu'en soit la cause. C'est voulu ici, et c'est un fail-closed : l'appelant est Seb Lex, qui
// propose des lois a deposer. Un catalogue partiel lui ferait proposer des categories qui
// n'existent pas. En revanche, la cause de l'echec n'est plus PERDUE -- `r.transport` la porte,
// et elle est journalisee au lieu de disparaitre dans un `catch` muet.
async function catalogueLegislatif(jeton) {
  const r = await sbRpcVerdict('assemblee_catalogue_legislatif', {}, { jeton })
                  .catch(e => ({ ok: false, raison: 'exception', transport: { message: e && e.message } }));
  if (!r.ok) {
    console.error('assemblee-seblex : catalogue legislatif indisponible', r.raison, r.transport);
    return null;
  }
  const c = r.donnees;
  if (!c || typeof c !== 'object') return null;
  if (!Array.isArray(c.categories) || !Array.isArray(c.matieres)) return null;
  if (c.categories.length === 0) return null;
  return c;
}

// ---------------------------------------------------------------------------
// LES LOIS QU'ON PEUT ABROGER
// ---------------------------------------------------------------------------
// Le joueur dit « je veux supprimer la loi sur le bois » ; c'est Seb qui doit
// retrouver DE QUELLE loi il parle, et demander si plusieurs peuvent
// correspondre. Il lui faut donc la liste -- lue en base, jamais inventee. Simple
// lecture REST : la table porte une policy de SELECT pour tout joueur, aucune RPC
// nouvelle n'est necessaire.
async function loisAbrogeables(jeton) {
  const q = 'statut=eq.adoptee&select=id,titre,type,categorie,adoptee_ts,appliquee_ts'
          + '&order=adoptee_ts.desc&limit=60';
  const r = await sbGetVerdict('assemblee_propositions', q, { jeton })
                  .catch(e => ({ ok: false, raison: 'exception', transport: { message: e && e.message } }));
  if (!r.ok) {
    // LISTE VIDE, MAIS PLUS EN SILENCE. Le contrat est conserve -- Seb ne proposera aucune
    // abrogation -- et c'est le bon sens de defaut : proposer d'abroger une loi dont on n'a
    // pas pu lire l'existence serait pire. Ce qui change, c'est que la panne LAISSE UNE TRACE
    // au lieu d'etre indistinguable d'un parlement qui n'a encore rien vote.
    console.error('assemblee-seblex : lois abrogeables illisibles', r.raison, r.transport);
    return [];
  }
  return Array.isArray(r.donnees) ? r.donnees : [];
}

// ---------------------------------------------------------------------------
// LE PROMPT SYSTEME — BORNE, COURT, SANS CONNAISSANCE INUTILE
// ---------------------------------------------------------------------------
// Il ne contient AUCUNE regle de jeu au-dela de ce que Seb doit formaliser, et
// aucune personnalite bavarde : chaque phrase inutile est un cout a chaque tour.
function construirePrompt(catalogue, lois) {
  const lignesCat = catalogue.categories.map(c => {
    const cibles = [];
    if (Array.isArray(c.matieres) && c.matieres.length) cibles.push(c.matieres.join(', '));
    if (Array.isArray(c.types_objet) && c.types_objet.length) {
      const st = (Array.isArray(c.sous_types) && c.sous_types.length) ? ' (' + c.sous_types.join(', ') + ')' : '';
      cibles.push('objets de type ' + c.types_objet.join(', ') + st);
    }
    const dims = [];
    if (c.transformation_pertinente === true) dims.push('transformation possible');
    if (c.production_pertinente === true) dims.push('production possible');
    // CE QUE LE DEPOSANT PEUT CHOISIR, et rien d'autre. Seb ne doit proposer un arbitrage que
    // s'il existe reellement : annoncer un choix que le moteur n'honore pas serait pire que de
    // ne rien proposer.
    const choix = [];
    if (c.choix_volets === true) choix.push('peut viser la matiere, les objets, ou les deux');
    if (Array.isArray(c.sous_types_disponibles) && c.sous_types_disponibles.length > 1) {
      choix.push('sous-types au choix : ' + c.sous_types_disponibles.join(', '));
    }
    return '- ' + c.categorie + ' « ' + c.label + ' » : ' + cibles.join(' ; ')
         + (dims.length ? ' [' + dims.join(', ') + ']' : ' [ni production ni transformation dans le jeu]')
         + (choix.length ? '\n    CHOIX OUVERT AU DEPOSANT : ' + choix.join(' ; ') : '');
  }).join('\n');

  const lignesLois = (lois && lois.length)
    ? lois.map(l => '- ' + l.id + ' : « ' + String(l.titre || '').slice(0, 110) + ' »').join('\n')
    : '(aucune loi en vigueur : rien ne peut etre abroge pour l\'instant)';

  return [
    "Tu es Seb Lex, juriste de l'Assemblee nationale de Republia. Tu mets en forme les projets de loi des deposants.",
    "",
    "TON ROLE, ET RIEN D'AUTRE : rendre une proposition claire, concise et non ambigue, puis la qualifier.",
    "Tu n'es ni conseiller politique, ni militant, ni depute. Tu ne juges JAMAIS si une loi est bonne, juste,",
    "utile ou opportune, et tu ne refuses jamais un SUJET. Tu ne donnes aucun avis, aucune statistique.",
    "",
    "TU NE FAIS PAS SUBIR D'INTERROGATOIRE. Tu ne poses une question que si une information MECANIQUE",
    "necessaire manque vraiment. Si le deposant l'a deja donnee, tu n'y reviens pas. Jamais deux questions",
    "a la fois. Des que tu sais, tu conclus.",
    "",
    "TROIS NATURES DE PROPOSITION, et c'est TOI qui tranches -- le deposant ne les connait pas :",
    "",
    "1. INTERDICTION (effet mecanique reel). Le moteur ne sait interdire QUE l'une de ces categories :",
    lignesCat,
    "   LA CATEGORIE DIT CE QUI PEUT ETRE VISE ; C'EST LE DEPOSANT QUI DIT CE QU'IL VISE VRAIMENT.",
    "   Une categorie n'impose jamais une portee politique : quand elle ouvre un choix, tu le poses,",
    "   en francais, sans jamais nommer un champ technique. Trois nuances existent, et seulement elles :",
    "",
    "   a) TRANSFORMATION : la loi interdit-elle AUSSI de transformer un stock deja possede (fabriquer",
    "      des produits avec) ? Dans les deux cas elle interdit deja de produire, d'acheter, de vendre",
    "      et d'importer legalement. Ne pose la question QUE si la categorie porte « transformation possible ».",
    "",
    "   b) MATIERE OU OBJETS : quand la categorie porte « peut viser la matiere, les objets, ou les deux »,",
    "      demande lequel. Exemple : interdire les medicaments, est-ce interdire le commerce de la matiere,",
    "      les produits de soin eux-memes, ou les deux ? Sans reponse, la loi vise les deux.",
    "",
    "   c) SOUS-TYPES : quand la categorie liste des sous-types au choix, demande lesquels sont vises.",
    "      Exemple : interdire les armes, est-ce viser l'armement militaire, les armes civiles, ou tout ?",
    "      Sans reponse, la loi vise tout ce que la categorie recouvre. Tu ne peux retenir QUE des",
    "      sous-types figurant dans la liste de la categorie : tout autre serait refuse.",
    "",
    "   N'invente aucune autre nuance : elle serait refusee. Et ne demande jamais un choix que la",
    "   categorie n'ouvre pas -- une categorie purement matiere n'a ni objets ni sous-types.",
    "   Restent TOUJOURS permis, quoi qu'on te demande : posseder un stock, le consommer, le DONNER.",
    "",
    "2. DECLARATIVE. Une proposition parfaitement legitime que le moteur ne sait pas rendre automatique.",
    "   C'EST LE CAS LE PLUS FREQUENT ET IL N'A RIEN DE DEGRADANT : conges, salaires, ceremonies, morale",
    "   publique, diplomatie... Le jeu n'a pas de mecanique pour tout. Tu l'annonces sans detour -- cette",
    "   disposition n'aura pas d'effet automatique -- et tu proposes de la deposer comme loi declarative.",
    "   Tu n'inventes JAMAIS un effet pour faire entrer une idee dans une categorie qui ne lui correspond pas.",
    "",
    "3. ABROGATION. Le deposant veut supprimer une loi en vigueur. Lois abrogeables (identifiant : titre) :",
    lignesLois,
    "   Tu dois designer UNE loi, par son identifiant exact. Si plusieurs peuvent correspondre, demande",
    "   laquelle en citant leurs titres. N'invente jamais un identifiant.",
    "",
    "SI LA PROPOSITION EST DEJA CLAIRE, ne demande rien. Une declarative limpide se traite en une reponse :",
    "tu dis brievement que tu n'as rien a ajouter et que la demande est recevable, puis tu synthetises.",
    "",
    "FORMAT — reponds UNIQUEMENT par un objet JSON valide, sans texte autour, selon l'un de ces cas :",
    'A) il te manque un element : {"etat":"question","question":"<une seule question, 1 a 2 phrases>"}',
    'B) interdiction : {"etat":"synthese","nature":"interdiction","titre":"<80 car. max>",',
    '   "synthese":"<le projet en 1 a 3 phrases, francais clair>","categorie":"<identifiant EXACT>",',
    '   "transformation_interdite":<true|false>,"vise_matiere":<true|false>,"vise_objets":<true|false>,',
    '   "sous_types":[<sous-types EXACTS de la categorie, ou omis si tous>],',
    '   "mot":"<ta phrase d\'accompagnement, 1 phrase>"}',
    '   vise_matiere et vise_objets valent true par defaut ; ne les mets a false que si le deposant',
    '   a explicitement restreint. N\'ecris sous_types que si le deposant a restreint.',
    'C) declarative : {"etat":"synthese","nature":"declarative","titre":"<80 car. max>",',
    '   "synthese":"<le projet en 1 a 3 phrases>","mot":"<ta phrase : rien a ajouter, ou bien qu\'elle',
    '   n\'aura pas d\'effet automatique>"}',
    'D) abrogation : {"etat":"synthese","nature":"abrogation","loi_cible":"<identifiant EXACT de la liste>",',
    '   "synthese":"<ce qui est abroge, 1 a 2 phrases>","mot":"<ta phrase>"}',
    "",
    "Dans la synthese et dans ton mot, ecris comme un legiste : pas de JSON, pas de nom de categorie",
    "technique, pas de « niveau », pas de booleen, pas d'identifiant. Le deposant lit une loi."
  ].join('\n');
}

// ---------------------------------------------------------------------------
// VALIDATION DE LA SORTIE — FERMEE, ET FAIL CLOSED
// ---------------------------------------------------------------------------
// On ne fait JAMAIS confiance au JSON de l'IA. Tout ce qui n'est pas exactement
// conforme est rejete : mieux vaut demander au deposant de reformuler qu'ecrire
// en base une portee que le moteur n'honorera pas.
function texteCourt(v, max) {
  return (typeof v === 'string' && v.trim().length > 0) ? v.trim().slice(0, max) : null;
}

function validerReponse(brut, catalogue, lois) {
  let j;
  try {
    j = JSON.parse(brut);
  } catch (e) {
    return { ok: false, motif: 'json_invalide' };
  }
  if (!j || typeof j !== 'object' || Array.isArray(j)) return { ok: false, motif: 'racine_invalide' };

  const etat = (typeof j.etat === 'string') ? j.etat.trim() : '';

  if (etat === 'question') {
    const q = texteCourt(j.question, 400);
    if (!q) return { ok: false, motif: 'question_vide' };
    return { ok: true, etat: 'question', question: q };
  }

  if (etat !== 'synthese') return { ok: false, motif: 'etat_inconnu' };

  const nature   = texteCourt(j.nature, 20);
  const synthese = texteCourt(j.synthese, 900);
  const mot      = texteCourt(j.mot, 400);
  if (!synthese) return { ok: false, motif: 'synthese_vide' };

  // --- ABROGATION : la cible doit exister, telle quelle. -------------------
  if (nature === 'abrogation') {
    const cible = texteCourt(j.loi_cible, 80);
    if (!cible) return { ok: false, motif: 'cible_absente' };
    const fiche = (lois || []).find(l => l && l.id === cible);
    if (!fiche) return { ok: false, motif: 'cible_inconnue' };   // aucune cible inventee
    return {
      ok: true, etat: 'synthese', nature: 'abrogation',
      titre: 'Abrogation — ' + String(fiche.titre || '').slice(0, 100),
      synthese, mot: mot || null,
      loi_cible: fiche.id, loi_cible_titre: texteCourt(fiche.titre, 120)
    };
  }

  // --- DECLARATIVE : aucune mecanique, et c'est legitime. ------------------
  if (nature === 'declarative') {
    const titre = texteCourt(j.titre, 110);
    if (!titre) return { ok: false, motif: 'titre_absent' };
    return { ok: true, etat: 'synthese', nature: 'declarative', titre, synthese, mot: mot || null };
  }

  // --- INTERDICTION : categorie fermee, portee bornee. ---------------------
  if (nature === 'interdiction') {
    const titre = texteCourt(j.titre, 110);
    const cat   = texteCourt(j.categorie, 60);
    if (!titre || !cat) return { ok: false, motif: 'synthese_incomplete' };

    // LA CATEGORIE DOIT EXISTER. Garde-fou central : l'IA ne peut pas inventer
    // une cible.
    const fiche = catalogue.categories.find(c => c && c.categorie === cat);
    if (!fiche) return { ok: false, motif: 'categorie_inconnue' };

    // LA PORTEE : chaque dimension est ramenee a ce que la CATEGORIE offre reellement.
    // Un effet que le moteur n'appliquerait pas ne doit jamais etre annonce au deposant --
    // c'est la regle qui empeche l'IA de promettre une loi qui ne fera rien.
    let transfo = (j.transformation_interdite === true);
    if (fiche.transformation_pertinente !== true) transfo = false;

    // Les deux volets : true par defaut. On ne retient un false que si la categorie ouvre
    // vraiment le choix ; sinon mettre un volet a false neutraliserait la loi en silence.
    const choixVolets = (fiche.choix_volets === true);
    const viseMatiere = choixVolets ? (j.vise_matiere !== false) : true;
    const viseObjets  = choixVolets ? (j.vise_objets  !== false) : true;
    if (choixVolets && !viseMatiere && !viseObjets) {
      return { ok: false, motif: 'portee_vide' };   // une loi qui ne vise rien n'est pas une loi
    }

    // Les sous-types : uniquement ceux que la categorie propose. Un sous-type invente est
    // rejete, pas ignore -- l'ignorer elargirait la loi au lieu de la restreindre.
    const dispo = Array.isArray(fiche.sous_types_disponibles) ? fiche.sous_types_disponibles : [];
    let sousTypes = null;
    if (Array.isArray(j.sous_types) && j.sous_types.length) {
      if (j.sous_types.some(st => typeof st !== 'string' || dispo.indexOf(st) === -1)) {
        return { ok: false, motif: 'sous_type_inconnu' };
      }
      // Retenir TOUS les sous-types disponibles revient a ne pas restreindre : on normalise,
      // pour que deux lois identiques s'ecrivent pareil en base.
      if (j.sous_types.length < dispo.length) sousTypes = j.sous_types.slice();
    }

    const portee = { transformation_stock_interdite: transfo,
                     volet_matieres: viseMatiere, volet_objets: viseObjets };
    if (sousTypes) portee.sous_types = sousTypes;

    return {
      ok: true, etat: 'synthese', nature: 'interdiction', titre, synthese, mot: mot || null,
      categorie: cat,
      label_categorie: texteCourt(fiche.label, 60) || cat,
      portee
    };
  }

  return { ok: false, motif: 'nature_inconnue' };
}

// ---------------------------------------------------------------------------
function validerPayload(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return 'Corps de requête invalide.';
  const clesAutorisees = ['message', 'historique'];
  if (Object.keys(body).some(k => !clesAutorisees.includes(k))) return 'Champ non autorisé.';
  if (typeof body.message !== 'string' || body.message.trim().length === 0) return 'Message invalide.';
  if (body.message.length > MAX_MESSAGE) return 'Message trop long.';
  if (body.historique !== undefined) {
    if (!Array.isArray(body.historique)) return 'Historique invalide.';
    if (body.historique.length > MAX_HISTORIQUE) return 'Historique trop long.';
    for (const t of body.historique) {
      if (!t || typeof t !== 'object') return 'Historique invalide.';
      if (t.role !== 'user' && t.role !== 'assistant') return 'Rôle non autorisé.';
      if (typeof t.content !== 'string' || t.content.length > MAX_CONTENU_TOUR) return 'Tour trop long.';
    }
  }
  return null;
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

  const catalogue = await catalogueLegislatif(utilisateur.jeton);
  if (!catalogue) {
    return res.status(502).json({ error: "Le juriste n'a pas pu consulter le code en vigueur." });
  }
  // La liste des lois abrogeables n'est pas bloquante : sans elle, Seb ne pourra
  // simplement pas qualifier une abrogation, et la validation la refusera.
  const lois = await loisAbrogeables(utilisateur.jeton);

  // TOUTE la construction du prompt est ici, dans le try : c'est la lecon du
  // 29 septembre, ou un prompt construit hors try/catch laissait le joueur sur
  // une attente sans fin.
  let systeme, messages;
  try {
    systeme = construirePrompt(catalogue, lois);
    messages = [];
    for (const t of (req.body.historique || [])) {
      messages.push({ role: t.role, content: String(t.content).slice(0, MAX_CONTENU_TOUR) });
    }
    messages.push({ role: 'user', content: req.body.message.trim().slice(0, MAX_MESSAGE) });
  } catch (e) {
    console.error('[seblex] construction du prompt impossible', e && e.message);
    return res.status(500).json({ error: "Le juriste n'a pas pu préparer la consultation." });
  }

  const r = await appelDeepSeek({ systeme, messages, maxTokens: MAX_TOKENS, json: true, timeoutMs: TIMEOUT_MS });
  if (!r.ok) {
    // ON NOMME LA PANNE DANS LE JOURNAL SERVEUR, et seulement la. Le joueur lit une
    // phrase sobre ; ni la cle, ni le code HTTP, ni un mot de facturation ne sortent
    // d'ici. Le marqueur est volontairement greppable dans les journaux Vercel.
    const c = classerEchecFournisseur(r) || { cause: 'autre', critique: false, journal: 'inconnu' };
    console.error('[seblex][IA_INDISPONIBLE] cause=' + c.cause
                  + (c.critique ? ' CRITIQUE' : '') + ' :: ' + c.journal);
    if (c.cause === 'credits_epuises' || c.cause === 'authentification' || c.cause === 'cle_absente') {
      // La ligne que Fred cherchera : une intervention humaine est necessaire,
      // aucune attente ne reparera cela.
      console.error('[ALERTE][IA] Seb Lex est HORS SERVICE et le restera : ' + c.journal
                    + '. Aucun joueur ne peut deposer de projet de loi tant que ce point n\'est pas regle.');
    }
    // 200 et non 502 : ce n'est pas une erreur de la requete du joueur, et l'ecran
    // doit pouvoir afficher le message sans perdre ce qu'il a saisi.
    return res.status(200).json({
      etat: 'indisponible',
      // `attendre` distingue « reessayez dans un instant » de « cela ne se reparera
      // pas tout seul » -- sans jamais dire pourquoi au joueur.
      attendre: !c.critique,
      message: c.critique
        ? 'Seb Lex est indisponible. Le bureau du juriste est fermé pour le moment ; réessayez plus tard.'
        : 'Seb Lex est momentanément indisponible. Réessayez dans un instant.'
    });
  }

  // Repli defensif, comme le Journal : si le fournisseur enrobait la reponse.
  const brut = String(r.texte || '').trim()
    .replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/i, '');

  const v = validerReponse(brut, catalogue, lois);
  if (!v.ok) {
    // FAIL CLOSED. On ne devine pas ce que l'IA voulait dire : on le dit au
    // joueur et on lui demande de reformuler. Le motif reste en journal serveur.
    console.error('[seblex] sortie non conforme : ' + v.motif);
    // FAIL CLOSED, mais jamais un refus de sujet : on renvoie une QUESTION, pour que
    // le deposant reformule sans perdre son idee. Aucun projet n'est fabrique.
    return res.status(200).json({
      etat: 'question',
      question: (v.motif === 'cible_inconnue' || v.motif === 'cible_absente')
        ? "Je ne vois pas clairement de quelle loi en vigueur vous parlez. Pouvez-vous me la nommer ?"
        : "Je n'ai pas réussi à mettre cela en forme. Pouvez-vous me le redire autrement ?"
    });
  }

  return res.status(200).json(v);
}
