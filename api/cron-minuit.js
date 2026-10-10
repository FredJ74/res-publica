// =====================
// CRON VERCEL — Traitement quotidien (élections, etc.)
// Déclenché automatiquement par vercel.json
// =====================

// Journal du jour (Lot B, 17-18 aout 2026) : génération appelée en toute dernière étape du
// handler, dans son propre try/catch (voir plus bas) — jamais mélangée aux tâches critiques
// existantes ci-dessous, qui restent strictement inchangées.
import { genererToutesLesEditions } from './_journal-generation.js';
// SONDE DE SANTE DU FOURNISSEUR IA (30 septembre 2026). Seb Lex, le juriste de
// l'Assemblee, et les dialogues PNJ vivent de ce fournisseur. Quand son solde
// s'epuise, ils meurent SILENCIEUSEMENT : chaque joueur voit « momentanement
// indisponible » et personne ne previent Fred. La sonde ci-dessous rend cette
// mort visible la ou Fred regarde deja -- voir la section 0 quater.
import { appelDeepSeek, cleConfiguree, classerEchecFournisseur } from './_deepseek.js';

// REFERENTIELS DU JEU -- IMPORTES, PLUS RECOPIES (chantier 4B, 6 octobre 2026).
//
// Ces dix-huit constantes etaient ressaisies a la main dans ce fichier, sous un nom
// en _SERVEUR, parce que ce module serverless ne peut pas importer les fichiers du
// navigateur. Elles sont desormais GENEREES depuis leurs sources canoniques par
// outils/generateurs/generer_referentiels_serveur.py, qui ne les emet que lorsqu il
// a PROUVE que la valeur produite depuis le canon est identique, au texte pres, a
// celle qui etait ecrite ici. Les noms sont inchanges : aucun site d appel ne bouge.
//
// Le module importe est un ARTEFACT GENERE. Ne jamais l editer : une valeur corrigee
// la-bas serait perdue a la prochaine generation, apres avoir fait diverger le
// serveur du jeu. Pour changer une valeur, la changer dans sa source canonique et
// rejouer le generateur.
//
// Les copies qui NE SONT PAS ici sont restees a la main plus bas, chacune pour une
// raison declaree dans outils/generateurs/referentiels-serveur.json : une divergence
// metier en attente d arbitrage, ou l absence de canon.
import {
  GREVE_PALIERS_SERVEUR,
  GREVE_USURE_JOUR_DEBUT_SERVEUR,
  GREVE_USURE_INF_JOUR_SERVEUR,
  GREVE_ACTIVITE_PLANCHER_SERVEUR,
  GREVE_SOCIAL_PLANCHER_SERVEUR,
  GREVE_GENERALE_NIVEAUX_SERVEUR,
  GREVE_GENERALE_RETOURNEMENT_INF_JOUR_SERVEUR,
  DELAI_DECISION_CANDIDATURE_MS_SERVEUR,
  GREVE_ENTREPRISES_CIBLABLES_SERVEUR,
  RESSOURCES_ECONOMIE_SERVEUR,
  CLUBS_SPORTIFS_SERVEUR,
  PERMIS_STATUT_LEGACY_ATTENTE_SERVEUR,
  DUREE_MESURES_EXCEPTION_MS_SERVEUR,
  COUT_HORAIRE_TRAVAIL_SERVEUR,
  PA_PRODUCTION_ARMURERIE_SERVEUR,
  ENTREPOTS_EFFORT_SERVEUR,
  RECETTES_MILITAIRES_SERVEUR,
  POSTES_NOMMES_EXCLUSIFS_SERVEUR,
  VILLES_SERVEUR,
  CAISSES_LEGACY_SERVEUR,
} from './_referentiels-generes.js';

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jxpwoosmmhohoihxpbuc.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw';

// IDENTITE SERVEUR (Lot 1.4, 6 septembre 2026 ; GENERALISEE le 14 septembre 2026, chantier B).
// La cle anon est publique : elle est committee dans supabase.js et lisible par n'importe quel
// navigateur. Tout ce qu'elle autorise est donc declenchable par n'importe qui. Elle n'etait
// employee sous identite serveur que pour prelever_loyer_bail et les deux RPC systeme de
// l'Assemblee ; TOUT LE RESTE du cron ecrivait avec la cle anon.
//
// POURQUOI CA CHANGE MAINTENANT. Le chantier B ferme les tables a l'ecriture anonyme. Un cron qui
// ecrit avec la cle anon serait ferme en meme temps que les joueurs : la nuit entiere tomberait.
// L'identite serveur est donc le PREALABLE a toute fermeture, pas une option. service_role
// traverse RLS par construction : une fois le cron passe dessous, plus aucune policy ne peut le
// gener, et les tables peuvent etre refermees une a une sans jamais le casser.
//
// MEME CONVENTION que api/_journal-generation.js, api/journal-interview.js, api/renseignements.js
// et api/upload-org-avatar.js : variable d'environnement Vercel jamais exposee au client.
const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || null;
const HEADERS_SERVICE = {
  'Content-Type': 'application/json',
  'apikey': SUPABASE_SERVICE_ROLE,
  'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE}`
};

// Les cinq primitives du cron passent desormais par ici. Repli sur la cle anon UNIQUEMENT si la
// variable d'environnement manque -- le handler refuse alors de demarrer (voir son en-tete), de
// sorte que ce repli ne sert qu'a garder le module chargeable, jamais a executer une passe.
const HEADERS = SUPABASE_SERVICE_ROLE ? HEADERS_SERVICE : {
  'Content-Type': 'application/json',
  'apikey': SUPABASE_ANON,
  'Authorization': `Bearer ${SUPABASE_ANON}`
};

// ============================================================================
// REGISTRE D'ECHECS DE LA PASSE (CHANTIER A / P0-2, 14 septembre 2026)
// ============================================================================
// POURQUOI. Les cinq primitives ci-dessous ne LEVENT jamais : sur une reponse non-2xx elles
// se contentaient d'un console.error et rendaient null. Le cron pouvait donc perdre une nuit
// entiere -- lecture de table en echec, colonne inexistante, RPC refusee -- et repondre
// HTTP 200 {ok:true}. Un audit du 13 septembre 2026 a mesure les degats : 15 insertions de
// mails ecrivaient des colonnes qui n'existent pas (voir plus bas), et personne ne l'a su
// pendant des semaines parce que la passe se declarait reussie.
//
// PRINCIPE. Un seul entonnoir : tout non-2xx passe par signalerEchec(). La passe accumule ses
// echecs, les renvoie NOMMES dans la reponse, et le handler conclut sur un statut HTTP non-2xx
// des qu'il y en a au moins un -- ce que la plateforme sait voir, contrairement a un log.
//
// PAS DE FAIL-FAST. On n'interrompt pas la passe au premier echec : les taches suivantes sont
// independantes et doivent tourner. C'est le STATUT FINAL qui est fail-closed, pas le
// deroulement. Le rejeu qui suivra est sur : chaque tache financiere porte desormais son
// marqueur de journee (voir jourCourantISO() et les marqueurs poses tache par tache).
let ECHECS_PASSE = [];

function signalerEchec(etape, detail) {
  const message = (detail && detail.message) ? String(detail.message) : String(detail);
  console.error('[cron-minuit] ECHEC ' + etape + ' :: ' + message);
  ECHECS_PASSE.push({ etape, erreur: message.slice(0, 500) });
}

// ============================================================================
// JOURNAL DURABLE DE LA PASSE (§6.12, 20 septembre 2026)
// ============================================================================
// CE QUI MANQUAIT. La detection d'echec existait deja (ECHECS_PASSE + HTTP 500),
// mais sa TRACE etait volatile : elle ne vivait que dans la reponse rendue a
// l'ordonnanceur. Impossible de repondre apres coup a « la taxe fonciere a-t-elle
// tourne la nuit du 18 ? ». Et comme tacheQuotidienne() pose son marqueur AVANT
// d'appeler fn() -- ce qui reste le bon choix contre le double debit -- une
// exception dans fn() BRULAIT la journee en silence : la tache etait perdue, le
// marqueur disait qu'elle avait tourne, et rien ne signalait l'ecart.
//
// REGLE. Le journal ne doit JAMAIS faire tomber la passe qu'il observe. Toute
// erreur d'ecriture du journal est avalee ici, et uniquement ici : c'est le seul
// catch silencieux legitime du fichier, parce qu'un observateur qui casse ce
// qu'il observe est pire que pas d'observateur.
// On n'emprunte VOLONTAIREMENT pas sbRpc() ici : sbRpc signale ses echecs via
// signalerEchec(), ce qui ferait tomber la passe en 500 parce que son JOURNAL n'a
// pas pu s'ecrire -- exactement l'inversion qu'on veut interdire. Appel autonome,
// entierement muet, et borne dans le temps pour ne pas retenir la passe si
// PostgREST ne repond plus.
async function journaliserCron(tache, jour, statut, erreur, contexte, dureeMs) {
  try {
    const stop = new AbortController();
    const minuteur = setTimeout(() => stop.abort(), 4000);
    try {
      await fetch(`${SUPABASE_URL}/rest/v1/rpc/cron_journal_ecrire`, {
        method: 'POST',
        headers: HEADERS,
        signal: stop.signal,
        body: JSON.stringify({
          p_tache: tache, p_jour: jour, p_statut: statut,
          p_erreur: erreur ? String(erreur).slice(0, 2000) : null,
          p_contexte: contexte || null,
          p_duree_ms: (typeof dureeMs === 'number' && isFinite(dureeMs)) ? Math.round(dureeMs) : null
        })
      });
    } finally { clearTimeout(minuteur); }
  } catch (_) { /* observateur non bloquant : voir la REGLE ci-dessus */ }
}

// Resume d'un retour de tache, borne, pour tenir dans une colonne jsonb sans
// recopier des listes entieres d'objets metier dans le journal.
function resumeContexte(valeur) {
  if (valeur === null || valeur === undefined) return null;
  if (typeof valeur !== 'object') return { valeur: String(valeur).slice(0, 200) };
  if (Array.isArray(valeur)) return { elements: valeur.length };
  const out = {};
  for (const [k, v] of Object.entries(valeur)) {
    if (Object.keys(out).length >= 12) break;
    if (v === null || v === undefined) continue;
    if (typeof v === 'number' || typeof v === 'boolean') out[k] = v;
    else if (typeof v === 'string') out[k] = v.slice(0, 120);
    else if (Array.isArray(v)) out[k] = v.length;
  }
  return Object.keys(out).length ? out : { forme: 'objet' };
}

async function sbGet(table, filters = '') {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${filters}`, { headers: HEADERS });
  if (!res.ok) { signalerEchec('sbGet:' + table, await res.text()); return null; }
  return res.json();
}

async function sbInsert(table, data) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: 'POST',
    headers: { ...HEADERS, 'Prefer': 'return=representation' },
    body: JSON.stringify(data)
  });
  if (!res.ok) { signalerEchec('sbInsert:' + table, await res.text()); return null; }
  return res.json();
}

async function sbUpdate(table, filters, data) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${filters}`, {
    method: 'PATCH',
    headers: { ...HEADERS, 'Prefer': 'return=representation' },
    body: JSON.stringify(data)
  });
  if (!res.ok) { signalerEchec('sbUpdate:' + table, await res.text()); return null; }
  return res.json();
}

// Mise a jour d'une ligne de prets. MANQUAIT ENTIEREMENT ICI (chantier A / P0-1, 14 septembre
// 2026) : preleverPretsBancairesServeur l'appelait a huit endroits alors qu'elle n'existait que
// dans supabase.js, fichier navigateur que ce module serverless n'importe pas. Le premier appel
// levait donc une ReferenceError SYNCHRONE -- que le .catch() accole ne peut pas intercepter,
// puisqu'aucune promesse n'est jamais creee -- remontee jusqu'au try/catch englobant de la
// fonction. Resultat : aucune mensualite prelevee depuis la mise en service, sur de l'argent
// credite a l'emprunteur au moment de l'octroi. Duplique de supabase.js:2879, meme doctrine que
// sbDelete/sbRpc/sbGetBatimentEtat ci-dessous.
async function sbUpdatePret(id, patch) {
  return await sbUpdate('prets', `id=eq.${encodeURIComponent(id)}`, patch);
}

// Envoi d'un mail systeme. BRIQUE UNIQUE DU CRON (chantier A / P0-2, 14 septembre 2026).
// POURQUOI ELLE EXISTE. Ce fichier portait DEUX conventions de colonnes pour la meme table :
// six insertions correctes (from_player/to_player/subject/body/read) et QUINZE heritees d'un
// schema francais qui n'a jamais existe cote base (destinataire/expediteur/sujet/corps). Ces
// quinze-la echouaient toutes en 400 -- colonnes inconnues, et 'id' est NOT NULL sans DEFAUT --
// sans que rien ne le signale : sbInsert rendait null, l'appelant avalait le null.
// Aucun mail du cron n'est donc jamais parti par ce chemin : ni avertissement d'impaye, ni mise
// en demeure, ni ultimatum, ni avis de saisie. Le correctif P0-1 rend le contentieux des prets
// reellement executant ; l'expedier muet aurait saisi des biens sans le moindre avis prealable.
// Toute nouvelle notification du cron passe par ici, jamais par un sbInsert('mails') direct.
//
// DOCTRINE DE LA NOTIFICATION (arbitrage technique du 9 octobre 2026). Trois regles, et elles
// tiennent ensemble :
//   1. UNE NOTIFICATION N'EST PAS L'AUTORITE DE L'ACTE. Un mail qui ne part pas ne doit ni
//      annuler une operation economique correctement acquise, ni la rendre rejouable. Les
//      appelants continuent donc leur passe quoi qu'il arrive -- c'est voulu, pas negligent.
//   2. MAIS L'ECHEC NE DOIT JAMAIS ETRE AVALE. Il l'etait : seize des dix-huit appels portent un
//      `.catch(() => {})`, aucun ne lisait le verdict, et `sbInsert` rendait `null` en silence.
//      Un avis de saisie qui ne part pas ne laissait aucune trace. L'echec est desormais
//      SIGNALE ICI, dans la brique, donc il remonte dans ECHECS_PASSE, dans le journal durable
//      du cron et dans le code HTTP de la passe -- sans que l'appelant ait a s'en occuper.
//   3. CETTE FONCTION NE LEVE PLUS. Elle rend un verdict explicite. C'est ce qui permet a la
//      regle 1 d'etre vraie SANS que chaque appelant ait a se proteger : un `.catch` oublie ne
//      peut plus faire tomber une passe nocturne pour un courrier.
//
// Le verdict est { ok: true, id } ou { ok: false, raison }. Aucun appelant ne le lisait au
// moment de ce changement ; il existe pour que celui qui voudra reessayer puisse le faire.
// `heure` est OPTIONNELLE et n'existe que pour les appelants qui en portaient DEJA une (10
// octobre 2026) : trois courriers du cron ecrivaient `mails` en direct avec leur propre valeur de
// `time` -- un horodatage ISO pour l'un, une date courte pour l'autre, rien du tout pour le
// troisieme. Les router sans ce parametre aurait change un champ affiche. Par defaut, la brique
// garde la date du jour, comme avant.
async function envoyerMailSysteme(destinataire, expediteur, sujet, corps, heure) {
  if (!destinataire || !expediteur) {
    // Pas un echec de transport : une demande incomplete. Tracee quand meme, parce qu'un
    // destinataire absent veut dire qu'un appelant a perdu son acteur en route.
    signalerEchec('mail:destinataire_ou_expediteur_absent',
                  'sujet=' + String(sujet).slice(0, 80));
    return { ok: false, raison: 'parametres_invalides' };
  }
  // 4. ET IL N'Y A PLUS QU'UN SEUL ECRIVAIN DE `mails` (9 octobre 2026). Cette brique faisait
  //    encore son propre INSERT par PostgREST. Elle passe desormais par mail_systeme_envoyer,
  //    qui delegue a mail_systeme_poser_interne -- l'unique ecriture de la table cote serveur.
  //    Deux gains concrets : un echec est aussi consigne dans `mails_envois_systeme` avec son
  //    SQLSTATE, donc nommable depuis la base et pas seulement depuis le journal du cron ; et le
  //    droit d'INSERT direct sur `mails` devient retirable a `service_role` le jour ou plus aucun
  //    chemin ne l'utilise.
  //
  //    L'heure affichee est PRESERVEE telle quelle : sans p_heure, la porte ecrirait « 23h »
  //    (heure de Paris) au lieu de la date du jour que le cron inscrivait.
  let verdict = null;
  try {
    verdict = await sbRpc('mail_systeme_envoyer', {
      p_expediteur: expediteur,
      p_destinataire: destinataire,
      p_sujet: sujet,
      p_corps: corps,
      p_heure: (heure === undefined) ? new Date().toLocaleDateString('fr-FR') : heure
    // HEADERS_SERVICE EXPLICITE, et ce n'est pas de la redondance : sbRpc retombe sur la cle
    // ANON quand aucune cle de service n'est configuree, et mail_systeme_envoyer rendrait alors
    // « acteur_non_authentifie » pour CHAQUE courrier du cron. L'exiger ici fait echouer
    // franchement une configuration incomplete, au lieu de rendre la passe muette.
    }, HEADERS_SERVICE).then(rows => Array.isArray(rows) ? rows[0] : rows);
  } catch (e) {
    // sbRpc ne devrait pas lever (il rend null sur HTTP non-2xx), mais une panne de fetch le
    // fait. On absorbe ici, une fois, plutot que dans dix-huit `.catch` disperses.
    signalerEchec('mail:' + expediteur + '->' + destinataire, e);
    return { ok: false, raison: 'reseau_indisponible' };
  }
  if (!verdict || verdict.ok !== true) {
    signalerEchec('mail:' + expediteur + '->' + destinataire,
                  'la porte des courriers a refuse l\'ecriture (' + ((verdict && verdict.raison) || 'aucun verdict')
                  + ', sujet=' + String(sujet).slice(0, 80) + ')');
    return { ok: false, raison: (verdict && verdict.raison) || 'ecriture_refusee' };
  }
  return { ok: true, id: verdict.id };
}

// Manquait cote cron (seuls sbGet/sbInsert/sbUpdate existaient) -- necessaire pour nettoyer
// titulaires_pnj lors d'une nomination automatique de candidature expiree (lot priorite PJ,
// 25 aout 2026). Duplique de supabase.js.
async function sbDelete(table, filters) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${filters}`, {
    method: 'DELETE',
    headers: HEADERS
  });
  if (!res.ok) { signalerEchec('sbDelete:' + table, await res.text()); return null; }
  return true;
}

// RPC generique, duplique de supabase.js (contexte serverless isole -- voir sbGetBatimentEtat
// ci-dessous pour la meme doctrine). Introduite pour resoudre_placement_national (chantier
// raccordement du placement Banque nationale) : la RPC est l'autorite transactionnelle unique
// (credit compte + ajustement arg + statut resolu + mail), jamais rejouee via des UPDATE separes
// depuis ce fichier.
// headers optionnel : les RPC existantes (Helvetia, placements) continuent d'utiliser la cle anon
// par defaut -- seul l'appelant qui exige une identite serveur passe HEADERS_SERVICE.
async function sbRpc(fn, params, headers) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: { ...(headers || HEADERS), 'Prefer': 'return=representation' },
    body: JSON.stringify(params || {})
  });
  if (!res.ok) { signalerEchec('sbRpc:' + fn, await res.text()); return null; }
  return res.json();
}

// Etat generique par batiment (id = country_city_buildingId), duplique de supabase.js
// car le cron tourne dans un contexte serverless isole, sans acces aux fonctions client.
// BUG CORRIGE LE 8 AOUT 2026 : ces deux fonctions etaient appelees (livrerEntrepotsQuotidien,
// produireTransformateursQuotidien) mais jamais definies ici -> ReferenceError silencieuse,
// avalee par le try/catch englobant -> aucune livraison, caisse jamais alimentee.
async function sbGetBatimentEtat(country, city, buildingId) {
  const id = country + '_' + city + '_' + buildingId;
  const rows = await sbGet('batiments_etat', `id=eq.${encodeURIComponent(id)}`);
  if (rows && rows[0]) {
    try { return JSON.parse(rows[0].data); } catch(e) { return {}; }
  }
  return {};
}

async function sbSetBatimentEtat(country, city, buildingId, patch) {
  const id = country + '_' + city + '_' + buildingId;
  const actuel = await sbGetBatimentEtat(country, city, buildingId);
  const fusion = { ...actuel, ...patch };
  const rows = await sbGet('batiments_etat', `id=eq.${encodeURIComponent(id)}`);
  if (rows && rows[0]) {
    await sbUpdate('batiments_etat', `id=eq.${encodeURIComponent(id)}`, { data: JSON.stringify(fusion), updated_at: new Date().toISOString() });
  } else {
    await sbInsert('batiments_etat', { id, country, city, building_id: buildingId, data: JSON.stringify(fusion) });
  }
  return fusion;
}

// Noms des postes pour les annonces (synchronisé avec data.js POSTES_ELECTIFS)
const POSTE_NOMS = {
  president: 'Président de la République',
  maire: 'Maire',
  depute: 'Député',
};

const POSTE_SCOPE = {
  president: 'national', // visible empire entier
  maire: 'local',         // visible ville uniquement
  depute: 'local',
};

// Duree de mandat — commune aux 4 postes electifs aujourd'hui (voir POSTES_ELECTIFS,
// data.js, mandatSemaines:5 partout). A dupliquer en table complete si jamais ca diverge
// par poste un jour.
const MANDAT_SEMAINES = 5;
const SEMAINE_MS = 7 * 24 * 60 * 60 * 1000;

// Construit un cycle electoral frais (memes valeurs que initCycleElectoral cote client,
// plateau-politique.js) — utilise pour renouveler un mandat echu (PJ ou PNJ).
// =====================
// CALENDRIER ELECTORAL DU DIMANCHE (12 septembre 2026) -- heure de Paris. COPIE IDENTIQUE de
// plateau-politique.js (partiesHeureParis ... lundiMinuitParisApresSemaines) : cloture des
// candidatures le lundi 00:01, vote le dimanche 00:01 -> 23:59, resultat au passage au lundi ;
// second tour le dimanche suivant ; dates calendaires de Paris, jamais +7 x 24 h.
// =====================
const FUSEAU_ELECTORAL = 'Europe/Paris';
const CANDIDATURES_MIN_MS = 6 * 24 * 60 * 60 * 1000;

function partiesHeureParis(ts) {
  const p = {};
  new Intl.DateTimeFormat('en-GB', { timeZone: FUSEAU_ELECTORAL, year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' })
    .formatToParts(new Date(ts)).forEach(x => { p[x.type] = x.value; });
  return { a: +p.year, m: +p.month, j: +p.day, h: (+p.hour) % 24, mi: +p.minute, s: +p.second };
}

function instantHeureParis(a, m, j, h, mi) {
  const mur = Date.UTC(a, m - 1, j, h, mi);
  let t = mur - 3600000;
  for (let k = 0; k < 3; k++) {
    const p = partiesHeureParis(t);
    t = mur - (Date.UTC(p.a, p.m - 1, p.j, p.h, p.mi, p.s) - t);
  }
  return t;
}

function dateCalendairePlusJours(d, n) {
  const x = new Date(Date.UTC(d.a, d.m - 1, d.j + n));
  return { a: x.getUTCFullYear(), m: x.getUTCMonth() + 1, j: x.getUTCDate() };
}

function lundiSemaineParis(ts) {
  const p = partiesHeureParis(ts);
  const jour = new Date(Date.UTC(p.a, p.m - 1, p.j)).getUTCDay();
  return dateCalendairePlusJours(p, -((jour + 6) % 7));
}

function datesScrutinSemaine(lundi) {
  const dim = dateCalendairePlusJours(lundi, 6), suivant = dateCalendairePlusJours(lundi, 7);
  return {
    dateDebutCampagne: instantHeureParis(lundi.a, lundi.m, lundi.j, 0, 1),
    dateVote: instantHeureParis(dim.a, dim.m, dim.j, 0, 1),
    dateResultats: instantHeureParis(suivant.a, suivant.m, suivant.j, 0, 0)
  };
}

function calendrierPremierTour(t) {
  let lundi = dateCalendairePlusJours(lundiSemaineParis(t), 7);
  let d = datesScrutinSemaine(lundi);
  if (d.dateDebutCampagne - t < CANDIDATURES_MIN_MS) d = datesScrutinSemaine(dateCalendairePlusJours(lundi, 7));
  return d;
}

function calendrierTourSuivant(dateVotePrecedent) {
  return datesScrutinSemaine(dateCalendairePlusJours(lundiSemaineParis(dateVotePrecedent), 7));
}

function lundiMinuitParisApresSemaines(t, n) {
  const l = dateCalendairePlusJours(lundiSemaineParis(t), 7 * n);
  return instantHeureParis(l.a, l.m, l.j, 0, 0);
}

// Postes a scrutin local, miroir de POSTES_ELECTIFS/posteEstLocal cote client : un cycle NATIONAL
// ne doit jamais porter de ville (divergence relevee le 12 septembre 2026 -- le cron estampillait
// la ville du cycle precedent sur une presidentielle ou une election syndicale).
const POSTES_ELECTIFS_LOCAUX = ['maire', 'depute'];

function construireNouveauCycleElectoral(posteId, city, now) {
  const cal = calendrierPremierTour(now);
  return {
    posteId, city: POSTES_ELECTIFS_LOCAUX.indexOf(posteId) >= 0 ? (city || null) : null,
    phase: 'candidatures',
    dateDebutCandidatures: now,
    dateDebutCampagne: cal.dateDebutCampagne,
    dateVote: cal.dateVote,
    dateResultats: cal.dateResultats,
    candidats: [],
    votes: {},
    votesPNJ: {},
    tour: 1,
    eluId: null,
    resultatsTraites: false
  };
}

// =====================
// MOTEUR DE DEPOUILLEMENT PARTAGE (chantier "Hotel de Ville / elections", 4 septembre 2026).
// Duplique VERBATIM cote client (plateau-politique.js, calculerScoresBaseCycle/
// resoudreScrutinSimple/resoudreScrutinDepute) -- meme doctrine que construireNouveauCycleElectoral
// deja duplique : ce fichier serveur n'a jamais acces au contexte client, et plateau-politique.js
// n'a jamais acces a ce contexte serveur. Les DEUX copies doivent rester identiques ; testees
// (26/26 assertions) sur la copie client avant duplication ici.
// =====================
function calculerScoresBaseCycle(cycle, fraudesActives) {
  const scores = {};
  (cycle.candidats || []).forEach(c => { scores[c.nom] = 0; });
  let blancs = 0;
  Object.values(cycle.votes || {}).forEach(nom => {
    if (nom === 'BLANC') { blancs++; return; }
    if (scores[nom] !== undefined) scores[nom]++;
  });
  Object.values(cycle.votesPNJ || {}).forEach(nom => {
    if (nom === 'BLANC') { blancs++; return; }
    if (scores[nom] !== undefined) scores[nom]++;
  });
  appliquerEffetsTracts(scores, cycle);
  (fraudesActives || []).forEach(f => {
    if (scores[f.candidat] !== undefined) scores[f.candidat] = Math.max(0, scores[f.candidat] + f.delta_voix);
  });
  const totalCandidats = Object.values(scores).reduce((s, v) => s + v, 0);
  return { scores, blancs, totalExprimes: totalCandidats + blancs };
}

function resoudreScrutinSimple(cycle, fraudesActives) {
  const candidats = cycle.candidats || [];
  if (candidats.length === 0) return null;
  const { scores, blancs, totalExprimes } = calculerScoresBaseCycle(cycle, fraudesActives);
  if (totalExprimes === 0) return { scores, blancs, totalExprimes: 0, elu: null, secondTour: [], blancMajoritaire: false };
  if (blancs > totalExprimes / 2) return { scores, blancs, totalExprimes, elu: null, secondTour: [], blancMajoritaire: true };

  const sorted = Object.entries(scores).sort((a, b) => b[1] - a[1]);
  const premier = sorted[0];
  // CANDIDAT UNIQUE (regle validee le 12 septembre 2026) : il est elu des qu'il fait au moins autant
  // que les bulletins blancs ; le vote blanc ne l'emporte que s'il est STRICTEMENT superieur. Sans
  // cela, l'egalite exacte candidat unique / blancs ne produisait ni elu, ni vote blanc, ni second
  // tour possible (un seul candidat) : le cycle restait bloque indefiniment.
  if (candidats.length === 1) {
    return premier[1] >= blancs
      ? { scores, blancs, totalExprimes, elu: premier[0], secondTour: [], blancMajoritaire: false }
      : { scores, blancs, totalExprimes, elu: null, secondTour: [], blancMajoritaire: true };
  }
  if (premier[1] > totalExprimes / 2) {
    return { scores, blancs, totalExprimes, elu: premier[0], secondTour: [], blancMajoritaire: false };
  }
  // SEUIL DE QUALIFICATION (regle validee le 12 septembre 2026) : 15 % des exprimes. Mais si moins
  // de DEUX candidats l'atteignent, les deux arrives en tete sont qualifies malgre tout -- sans
  // cela le scrutin restait bloque : aucune branche du depouillement ne s'appliquait, le cycle
  // n'etait jamais marque resultatsTraites et le cron le reexaminait chaque nuit indefiniment.
  let qualifies = sorted.filter(([, v]) => v / totalExprimes >= 0.15).map(([n]) => n);
  if (qualifies.length < 2) qualifies = sorted.slice(0, 2).map(([n]) => n);
  return { scores, blancs, totalExprimes, elu: null, secondTour: qualifies, blancMajoritaire: false };
}

function resoudreScrutinDepute(cycle, fraudesActives) {
  const candidats = cycle.candidats || [];
  if (candidats.length === 0) return null;
  const { scores, blancs, totalExprimes } = calculerScoresBaseCycle(cycle, fraudesActives);
  if (totalExprimes === 0) return { scores, blancs, totalExprimes: 0, elus: [], egalite3eSiege: null, blancMajoritaire: false };
  if (blancs > totalExprimes / 2) return { scores, blancs, totalExprimes, elus: [], egalite3eSiege: null, blancMajoritaire: true };

  // Un seul tour (12 septembre 2026) : les 3 meilleurs scores sont elus ; egalite departagee par
  // l'anciennete de la candidature, puis l'ordre alphabetique. Plus aucun second tour partiel.
  const sorted = Object.entries(scores).sort((a, b) => b[1] - a[1] || departageCandidats(candidats, a[0], b[0]));
  return { scores, blancs, totalExprimes, elus: sorted.slice(0, 3).map(([n]) => n), egalite3eSiege: null, blancMajoritaire: false };
}

function departageCandidats(candidats, nomA, nomB) {
  const date = nom => { const c = (candidats || []).find(x => x.nom === nom); const d = Number(c && c.dateInscription); return isFinite(d) && d > 0 ? d : Infinity; };
  return (date(nomA) - date(nomB)) || (nomA < nomB ? -1 : (nomA > nomB ? 1 : 0));
}

// Charge les fraudes NON REVELEES d'un scrutin precis (cycle_debut = cycle.dateDebutCandidatures
// AU MOMENT DE LA FRAUDE -- cle stable a travers les renouvellements, puisque cycles_electoraux
// ecrase la meme ligne a chaque nouveau cycle). Une fraude revelee ne doit plus jamais compter.
// Tracts electoraux aupres des PNJ (11 septembre 2026, migration_tracts_electoraux_pnj.sql) : une
// ligne par participation reussie, effet +1/-1/0 deja borne a la source, pour le tour courant
// (tour = cycle.dateVote). Attaches au cycle par une propriete NON enumerable : les decomptes les
// lisent, JSON.stringify ne les ecrit jamais dans le blob. MEME logique que la copie client
// (attacherEffetsTracts/appliquerEffetsTracts, plateau-politique.js).
async function attacherEffetsTractsServer(cycleId, cycle) {
  const rows = await sbGet('elections_tracts_pnj',
    `cycle_id=eq.${encodeURIComponent(cycleId)}&tour=eq.${Number(cycle.dateVote) || 0}&select=candidat,effet`
  ).catch(() => []);
  const parCandidat = {};
  (rows || []).forEach(r => { parCandidat[r.candidat] = (parCandidat[r.candidat] || 0) + Number(r.effet || 0); });
  Object.defineProperty(cycle, '_effetsTracts', { value: { tour: cycle.dateVote, parCandidat }, enumerable: false, writable: true, configurable: true });
}

function appliquerEffetsTracts(scores, cycle) {
  const e = cycle && cycle._effetsTracts;
  if (!e || e.tour !== cycle.dateVote) return;
  Object.keys(e.parCandidat || {}).forEach(nom => {
    if (scores[nom] !== undefined) scores[nom] = Math.max(0, scores[nom] + e.parCandidat[nom]);
  });
}

async function chargerFraudesActivesServer(country, posteId, city, cycleDebut) {
  const filtreCity = city ? `&city=eq.${encodeURIComponent(city)}` : '&city=is.null';
  const rows = await sbGet('fraudes_electorales',
    `country=eq.${encodeURIComponent(country)}&poste_id=eq.${encodeURIComponent(posteId)}${filtreCity}&cycle_debut=eq.${cycleDebut}&etat=eq.non_revelee`
  ).catch(() => []);
  return rows || [];
}

// =====================
// ARCHIVES DES MANDATS MUNICIPAUX (chantier "Hotel de Ville / elections", 4 septembre 2026).
// Capture UNIQUEMENT des indicateurs reellement partages/persistes cote serveur (jamais
// state.indicesLocaux, qui n'est qu'une illusion cote client, propre a chaque joueur, jamais une
// verite municipale partagee) : taux d'imposition locale + tresorerie municipale
// (budgets_municipaux, deja lu par preleverTaxeFonciere ci-dessus). Aucun indice economique/social
// LOCAL persiste n'existe ailleurs dans le jeu (seul INDICES_NATIONAUX existe, et il est national,
// jamais par ville) -- volontairement absent d'ici, conformement a la consigne "ne jamais inventer
// une statistique que le jeu ne possede pas".
// =====================
async function capturerIndicateursMunicipaux(country, city) {
  const villeKey = country + '_' + city;
  const rows = await sbGet('budgets_municipaux', `id=eq.${encodeURIComponent(villeKey)}`).catch(() => []);
  const budget = (rows && rows[0]) ? rows[0].data : null;
  return {
    taux_impots_locaux: (budget && typeof budget.tauxLocal === 'number') ? budget.tauxLocal : null,
    caisse_municipale: (budget && typeof budget.caisse === 'number') ? budget.caisse : null
  };
}

// Ecrit un bilan de mandat termine -- appele UNIQUEMENT au renouvellement naturel d'un mandat
// echu (voir boucle principale). Une demission anticipee ou une autre sortie de poste n'est PAS
// archivee ici (hors perimetre de ce lot, signale au rapport) : seul le cas dominant (mandat
// arrive a echeance normale) est couvert, jamais une invention pour combler les autres cas.
async function archiverMandatMaireTermine(country, city, maire, estPJ, debutTs, finTs, indicateursDebut) {
  if (!maire) return;
  const indicateursFin = await capturerIndicateursMunicipaux(country, city).catch(() => null);
  await sbInsert('mandats_maires_archives', {
    id: 'mandat-' + country + '-' + city + '-' + debutTs,
    country, city, maire, est_pj: estPJ !== false,
    debut_ts: new Date(debutTs).toISOString(),
    fin_ts: new Date(finTs).toISOString(),
    indicateurs_debut: indicateursDebut || null,
    indicateurs_fin: indicateursFin
  }).catch(e => console.error('archiverMandatMaireTermine error', e));
}

async function purgerVieuxMails() {
  const limite = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString();
  try {
    const filtre = `created_at=lt.${encodeURIComponent(limite)}&archived=eq.false`;
    const res = await fetch(`${SUPABASE_URL}/rest/v1/mails?${filtre}`, {
      method: 'DELETE',
      headers: { ...HEADERS, 'Prefer': 'return=representation' }
    });
    if (!res.ok) { console.error('purgerVieuxMails error', await res.text()); return 0; }
    const deleted = await res.json();
    return Array.isArray(deleted) ? deleted.length : 0;
  } catch(e) { console.error('purgerVieuxMails exception', e); return 0; }
}

// Prelevement quotidien de la taxe fonciere sur tous les terrains possedes. Priorite absolue
// sur les mensualites de prets (appelee avant preleverPretsBancaires si les deux coexistent
// un jour). Progression d'avertissements calquee sur celle des prets bancaires : 5% de la
// valeur du bien = avertissement, 15% = mise en demeure + penalite 10%, 25% = saisie par la
// mairie et mise en vente. NOTE : suppose un seul terrain par (pays, buildingId) — verifie
// le 3 aout 2026 que ce n'etait pas garanti (collision Luthecia/PSM corrigee cote data.js).
// ============================================================================
// FILET DE SECURITE — LIBERATION DES PEINES ECHUES (chantier A / P0-3, 14 septembre 2026)
// ============================================================================
// LE DEFAUT. verifierLiberationPrisonniers (plateau-justice-economie.js) est le SEUL endroit du
// jeu qui libere un detenu, et ses deux appelants sont client : runMidnightUpdate et doDormir.
// Un joueur qui ne se reconnecte pas ne voit donc jamais sa peine s'ecouler -- state.day, sur
// lequel elle est comptee, est son propre compteur et n'avance que quand il joue. La peine
// n'expire pas : elle attend. Combine au double-encodage corrige par ailleurs, cela produisait
// une detention perpetuelle sur une garde a vue de deux jours.
//
// POURQUOI PAS jour_fin. La table detentions compte en jours de jeu (jour_debut/jour_fin), une
// echelle PRIVEE a chaque personnage que le serveur ne peut pas interpreter -- le depot le
// documente deja noir sur blanc (migration_assemblee_nationale.sql, api/cron-minuit.js). Le seul
// repere partage est le temps reel : est_emprisonne.debutTs, pose au debut de chaque detention,
// + 'jours' x 24 h. 'jours' est un invariant DEJA maintenu par tous les chemins qui modifient une
// peine (prolongation, reduction avocat, evasion ratee, rebellion) : l'echeance suit toute seule.
//
// CE QU'IL NE FAIT PAS, VOLONTAIREMENT :
//  - il ne libere JAMAIS du QHS (detention_qhs.enQHS) : chantier separe, hors perimetre ;
//  - il ne libere pas un detenu qui porte une AUTRE ligne de detention encore ouverte ;
//  - il ne touche jamais detentions.motifs, ne supprime aucune ligne, n'ecrase aucun mode_fin
//    deja pose : l'historique est complete, jamais reecrit ;
//  - il ignore et SIGNALE toute detention sans ancre temps reel (donnee anterieure au correctif)
//    plutot que d'inventer une echeance.
// Il n'arrive jamais AVANT le client : il libere a la duree reelle, que le client, lui, peut
// atteindre plus tot en jouant. C'est un filet, pas une autorite concurrente.
const MS_PAR_JOUR_DETENTION = 24 * 60 * 60 * 1000;

function lireJsonPersonnageServeur(valeur) {
  if (!valeur) return null;
  if (typeof valeur === 'object') return valeur;
  if (typeof valeur === 'string') {
    try { const p = JSON.parse(valeur); return (p && typeof p === 'object') ? p : null; } catch (e) { return null; }
  }
  return null;
}

async function libererDetentionsEchuesServeur() {
  const resultats = { liberes: 0, qhsIgnores: 0, sansAncre: 0, autreDetentionActive: 0, details: [] };
  const maintenant = Date.now();
  const detenus = await sbGet('personnages', 'est_emprisonne=not.is.null&select=name,est_emprisonne,detention_qhs');
  if (!detenus) return resultats;

  for (const perso of detenus) {
    const peine = lireJsonPersonnageServeur(perso.est_emprisonne);
    if (!peine) continue;

    const qhs = lireJsonPersonnageServeur(perso.detention_qhs);
    if ((qhs && qhs.enQHS === true) || peine.qhs === true) {
      resultats.qhsIgnores++;
      resultats.details.push({ nom: perso.name, verdict: 'qhs_hors_perimetre' });
      continue;
    }

    const jours = Number(peine.jours);
    const debutTs = Number(peine.debutTs);
    if (!Number.isFinite(jours) || jours <= 0 || !Number.isFinite(debutTs) || debutTs <= 0) {
      resultats.sansAncre++;
      resultats.details.push({ nom: perso.name, verdict: 'sans_ancre_temps_reel', raison: peine.raison || null });
      continue;
    }

    const echeance = debutTs + jours * MS_PAR_JOUR_DETENTION;
    if (maintenant < echeance) continue;

    // Une AUTRE ligne de detention encore ouverte veut dire que ce detenu doit rester detenu pour
    // un motif que cette peine-ci ne couvre pas. On ne libere pas : on signale.
    const lignes = await sbGet('detentions', `nom=eq.${encodeURIComponent(perso.name)}&mode_fin=is.null&select=id,jour_fin`);
    const autres = (lignes || []).filter(l => l.id !== peine.detentionId);
    if (autres.length > 0) {
      resultats.autreDetentionActive++;
      resultats.details.push({ nom: perso.name, verdict: 'autre_detention_ouverte', lignes: autres.map(l => l.id) });
      continue;
    }

    // Cloture du registre AVANT la liberation : si la passe s'interrompt entre les deux, le
    // detenu reste detenu (etat conservateur) et le rejeu reprendra proprement -- l'inverse
    // laisserait une ligne ouverte sur un homme libre.
    if (peine.detentionId) {
      const ligne = (lignes || []).find(l => l.id === peine.detentionId);
      await sbUpdate('detentions', `id=eq.${encodeURIComponent(peine.detentionId)}&mode_fin=is.null`, {
        mode_fin: 'purgee',
        jour_fin_effective: ligne ? ligne.jour_fin : null,
        date_fin_effective: new Date(maintenant).toISOString()
      });
    }
    const maj = await sbUpdate('personnages', `name=eq.${encodeURIComponent(perso.name)}`, { est_emprisonne: null });
    if (maj === null) continue; // echec deja signale par sbUpdate : on ne compte pas une liberation qui n'a pas eu lieu

    await envoyerMailSysteme(perso.name, 'Commissariat', 'Libération',
      'Votre peine est purgée. Vous êtes libre de circuler.');
    resultats.liberes++;
    resultats.details.push({ nom: perso.name, verdict: 'libere', raison: peine.raison || null });
  }
  return resultats;
}

// LA TAXE FONCIERE EST UNE TRANSACTION PAR TERRAIN (chantier 6, 10 octobre 2026).
//
// CE QUI SE PASSAIT. Cette passe debitait le proprietaire PUIS ecrivait le blob du terrain -- deux
// requetes HTTP -- et creditait les mairies APRES la boucle, par commune. Trois consequences,
// toutes atteignables :
//
//   1. AUCUN MARQUEUR PAR TERRAIN. Une seconde execution le meme jour redebitait la taxe, et pour
//      un insolvable faisait avancer de DEUX crans la progression avertissement -> penalite de
//      10 % -> SAISIE MUNICIPALE.
//   2. DEUX MOITIES D'ACTE. Une interruption entre le debit et l'ecriture du blob prelevait sans
//      remettre `dette_fonciere` a zero : la passe suivante redebitait, et la dette restait.
//   3. L'ARGENT POUVAIT DISPARAITRE. Le debit des proprietaires et le credit des mairies etaient
//      separes par toute la boucle.
//
// taxe_fonciere_prelever impose UN terrain par transaction, revendiquee par la brique des actes
// nocturnes, debit et credit inclus. Il ne reste ici que le balayage et le comptage des verdicts.
// Le cache des budgets municipaux et l'agregation par commune ont disparu avec le defaut :
// `recette_municipale` etant additive, un credit par terrain donne le meme total au compteur.
async function preleverTaxeFonciere() {
  const resultats = { collecte: 0, avertissements: 0, saisies: 0 };
  // Ces cinq refus ne sont pas des echecs : ils disent qu'il n'y avait rien a faire sur ce
  // terrain, ou que la journee etait deja prise. Tout autre refus remonte dans ECHECS_PASSE.
  const RIEN_A_FAIRE = ['hors_assiette', 'terrain_introuvable', 'budget_municipal_absent',
                        'proprietaire_introuvable', 'deja_prelevee_aujourdhui'];
  try {
    const terrains = await sbGet('terrains_etat', 'select=id');
    if (!terrains) return resultats;
    for (const row of terrains) {
      const v = await sbRpc('taxe_fonciere_prelever', { p_terrain_id: row.id }, HEADERS_SERVICE)
        .then(rows => Array.isArray(rows) ? rows[0] : rows).catch(() => null);
      if (!v) {
        signalerEchec('taxe_fonciere:' + row.id, 'aucun verdict rendu');
        continue;
      }
      if (v.ok !== true) {
        if (!RIEN_A_FAIRE.includes(v.action)) {
          signalerEchec('taxe_fonciere:' + row.id, v.action || 'refus sans motif');
        }
        continue;
      }
      if (v.action === 'collectee') resultats.collecte += Number(v.montant || 0);
      else if (v.action === 'avertissement') resultats.avertissements++;
      else if (v.action === 'saisie') resultats.saisies++;
    }
  } catch(e) { console.error('preleverTaxeFonciere error', e); }
  return resultats;
}

// (Commentaire historique orphelin : il decrivait preleverLoyersLots, qui vivait ~1850 lignes
// plus bas et a ete remplacee par preleverLoyersBaux au Lot 1.4 -- voir sa documentation sur
// place. Laisse ici pour ne pas toucher a du code sans rapport.)
// LA RESOLUTION D'UN COMPROMIS EST UNE TRANSACTION SERVEUR (chantier 6, 9 octobre 2026).
//
// CE QUI SE PASSAIT. `Math.random() < 0.5` decidait du pret ICI, puis QUATRE ecritures
// independantes et avalees appliquaient la decision : credit de l'emprunteur, ligne `prets`, blob
// du bien, ligne `compromis_historique`. Les trois scenarios que l'audit du chantier 6 avait
// nommes etaient tous atteignables : double credit de pret (le tirage etait rejoue), argent sans
// dette (seul l'INSERT prets echouait), double remboursement d'acompte avec une seconde ligne
// d'historique que la cle primaire ne refusait pas -- son identifiant portait un `Date.now()`.
//
// compromis_expire_resoudre fait tout dans un seul BEGIN, tirage inclus, avec des identifiants
// DATES (un par bien et par jour) proteges par ON CONFLICT. Elle sert les DEUX familles --
// terrain et entreprise -- qui etaient deux fois le meme code ici.
//
// Les deux passes ci-dessous ne gardent que ce qui leur est propre : le balayage de leur table,
// le pre-filtre (compromis actif et echu), et la delegation du cas Helvetia a sa RPC dediee.
function compterVerdictCompromis(v, resultats) {
  if (v.action === 'pret_en_attente_finalisation') { resultats.pretsEnAttenteFinalisation++; return; }
  if (v.action === 'rembourse') { resultats.rembourses++; resultats.resolus++; return; }
  if (v.action === 'perdu') { resultats.perdus++; resultats.resolus++; }
  // 'pret_accorde_compromis_gele' : le compromis reste actif, rien a compter -- c'est deja ce
  // que faisait le `continue` du code d'avant ce lot.
}

async function resoudreUnCompromis(type, cible, resultats) {
  const v = await sbRpc('compromis_expire_resoudre', { p_type: type, p_cible: cible }, HEADERS_SERVICE)
    .then(rows => Array.isArray(rows) ? rows[0] : rows).catch(() => null);
  if (!v) {
    signalerEchec('compromis_' + type, cible + ' : aucun verdict rendu -- retente au prochain cron');
    return;
  }
  if (v.ok !== true) {
    // Ces trois refus ne sont pas des echecs : le pre-filtre et la porte ont vu le monde a deux
    // instants differents, ou le bien releve de la RPC Helvetia.
    if (v.action === 'non_applicable' || v.action === 'pas_encore_expire' || v.action === 'helvetia') return;
    signalerEchec('compromis_' + type, cible + ' : ' + (v.action || 'refus sans motif'));
    return;
  }
  compterVerdictCompromis(v, resultats);
}

async function resoudreCompromisExpires() {
  const resultats = { resolus: 0, rembourses: 0, perdus: 0, pretsEnAttenteFinalisation: 0, helvetiaDelegues: 0 };
  try {
    const terrains = await sbGet('terrains_etat', '');
    if (!terrains) return resultats;

    for (const row of terrains) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      if (!etat.compromis || !etat.compromisExpireAt) continue;
      if (Date.now() < etat.compromisExpireAt) continue; // pas encore echu

      // Bien Helvetia (chantier H2A, 28 aout 2026) : delegue integralement a la RPC dediee,
      // jamais au chemin legacy ci-dessous -- resoudre_compromis_helvetia_expire porte sa propre
      // decision (verrouillage FOR UPDATE, remboursement/perte d'acompte, evaluation d'un
      // pretDemande en attente) que ce cron ne doit pas reimplementer cote client.
      if (etat.proprietaire === 'Helvetia') {
        const res = await sbRpc('resoudre_compromis_helvetia_expire', { p_terrain_id: row.id });
        if (res === null) signalerEchec('compromis_helvetia', row.id + ' : la RPC a echoue -- retente au prochain cron');
        else resultats.helvetiaDelegues++;
        continue;
      }

      await resoudreUnCompromis('terrain', row.id, resultats);
    }
  } catch(e) { console.error('resoudreCompromisExpires error', e); }
  return resultats;
}

// Resolution des compromis de rachat d'entreprise arrives a echeance (Notaire, chantier du
// 10 aout 2026). Pas de clause "permis" ici (aucun equivalent pour une entreprise), mais la
// meme clause "pret bancaire" que le terrain existe desormais -- meme logique que
// resoudreCompromisExpires ci-dessus (et son fix du 10 aout 2026) : un pret accorde gele le
// compromis indefiniment, en attente que le joueur finalise via acte_rachat_entreprise. Balaie
// toute la table 'entreprises' (pas une liste figee par type) pour couvrir automatiquement les
// futures entreprises rachetables sans avoir a toucher ce cron. Table 'entreprises' stocke
// data en jsonb natif (pas de JSON.parse/stringify, contrairement a terrains_etat).
async function resoudreCompromisEntreprisesExpires() {
  const resultats = { resolus: 0, rembourses: 0, perdus: 0, pretsEnAttenteFinalisation: 0 };
  try {
    const entreprises = await sbGet('entreprises', '');
    if (!entreprises) return resultats;

    for (const row of entreprises) {
      const data = row.data;
      if (!data || !data.compromis || !data.compromisExpireAt) continue;
      if (Date.now() < data.compromisExpireAt) continue; // pas encore echu

      // LE PAYS N'EST PLUS DEDUIT ICI (9 octobre 2026) : la porte le lit elle-meme, avec la
      // meme regle -- le blob d'abord, sinon le DEUXIEME segment de l'identifiant
      // (« <type>-<pays>-<ville> », correctif A2 du 16 aout 2026). Et la garde « un pret deja
      // accorde gele le compromis » y est aussi, sous verrou cette fois.
      await resoudreUnCompromis('entreprise', row.id, resultats);
    }
  } catch(e) { console.error('resoudreCompromisEntreprisesExpires error', e); }
  return resultats;
}

// =====================
// SUCCESSIONS DIFFEREES (architecture v4, 21 aout 2026) -- meme doctrine que
// resoudreCompromisExpires ci-dessus : balayage complet de la table, comparaison de timestamps
// stockes, mutation, ecriture -- pas un second moteur temporel. Table 'successions' stocke
// dispositions en jsonb natif (comme 'entreprises', pas de JSON.parse/stringify contrairement a
// terrains_etat). Toute la logique de cascade/reglement est dupliquee ici dans l'idiome raw-fetch
// du cron -- le code client (plateau-personnage.js, determinerEtapeSuivante/doRepondreHeritage)
// tourne dans un runtime navigateur totalement isole, aucun partage de code possible.
// =====================

const DELAI_CONVOCATION_MS_SUCCESSION = 10 * 24 * 60 * 60 * 1000; // 10 jours reels

async function personnageExisteReellementServeur(nom) {
  if (!nom) return false;
  const rows = await sbGet('personnages', 'name=eq.' + encodeURIComponent(nom) + '&select=name').catch(() => null);
  return !!(rows && rows.length > 0);
}

// Cascade principal -> remplacant -> legal_conjoint, amorcee a partir du role qui vient de
// renoncer (explicitement ou tacitement) -- jamais de retour en arriere (dejaConvoques), jamais
// de transmission automatique. Miroir exact de determinerEtapeSuivante() cote client.
async function determinerEtapeSuivanteServeur(disposition, roleActuel, conjointNom) {
  const maintenant = Date.now();
  const expiresAt = new Date(maintenant + DELAI_CONVOCATION_MS_SUCCESSION).toISOString();
  const convoqueLe = new Date(maintenant).toISOString();
  const dejaConvoques = new Set((disposition.chaine || []).map(e => e.role));

  if (roleActuel === 'principal' && disposition.remplacant_prevu && !dejaConvoques.has('remplacant')) {
    if (await personnageExisteReellementServeur(disposition.remplacant_prevu)) {
      return { role: 'remplacant', beneficiaire: disposition.remplacant_prevu, convoque_le: convoqueLe, expires_at: expiresAt, reponse: null, repondu_le: null };
    }
  }
  if (roleActuel !== 'legal_conjoint' && conjointNom && !dejaConvoques.has('legal_conjoint')) {
    return { role: 'legal_conjoint', beneficiaire: conjointNom, convoque_le: convoqueLe, expires_at: expiresAt, reponse: null, repondu_le: null };
  }
  return null;
}

// Reglement IDEMPOTENT d'une succession dont TOUTES les dispositions ont une decision tranchee
// (d.resultat) : transfert des biens, credit des beneficiaires, degel, credit de la fiscalite
// globale deja figee a l'ouverture (Etat 90% / notaire 10%, meme en devolution integrale sans
// heritier vivant -- section 1/9 des arbitrages), cloture finale (statut 'resolue').
//
// IDEMPOTENCE (verification demandee le 21 aout 2026) : scenario couvert -- un terrain est
// transfere, un heritier est credite, la part Etat ou notaire est creditee, puis une etape
// SUIVANTE echoue ; la succession reste 'en_attente' ; le cron repasse le lendemain. Sans
// garde-fou, ce rejeu recrediterait TOUT depuis le debut (double transfert -- inoffensif en soi,
// re-ecrire le meme proprietaire -- mais surtout double credit reel d'argent a l'heritier, a
// l'Etat et au notaire, puisque ces credits sont des += additifs). Le garde-fou : chaque
// disposition porte son propre marqueur persistant dispositions[].regle, et la fiscalite globale
// porte DEUX marqueurs distincts successions.part_etat_reglee / part_notaire_reglee (distincts
// l'un de l'autre : un des deux peut reussir et l'autre echouer sans se confondre). Chaque
// marqueur est ecrit EN BASE immediatement apres que sa mutation reelle a reussi -- jamais tous
// en un seul commit final. statut='resolue' n'est PAS le mecanisme de protection contre le rejeu
// (ce serait insuffisant : il n'est ecrit qu'apres plusieurs mutations, exactement le risque
// signale) -- ce n'est qu'un marqueur de FERMETURE pose en tout dernier, une fois que tous les
// marqueurs individuels sont deja vrais. Au rejeu, toute etape deja marquee est sautee sans
// rejouer sa mutation : aucun transfert, credit heritier, credit Etat ou credit notaire ne peut
// s'executer deux fois par cette voie.
//
// LA FENETRE EST FERMEE (chantier 6, famille D, 10 octobre 2026).
//
// CE QUI RESTAIT, EXACTEMENT. Tout ce qui est decrit ci-dessus etait vrai et bien construit : la
// garde par disposition, chaque ecriture verifiee, le marqueur pose par disposition, les deux
// marqueurs fiscaux independants, la cloture en dernier. Le defaut residuel etait UNE FENETRE, pas
// une passoire : entre le credit reel et la pose du marqueur il restait DEUX requetes HTTP. Un
// depassement du maxDuration: 120 ou un plantage dans cet intervalle laissait un beneficiaire
// credite sans `regle` -- donc RECREDITE la nuit suivante. Probabilite faible, montant eleve : un
// heritage entier, ou la part de l'Etat.
//
// succession_regler met chaque mutation et le marqueur qui la protege DANS LA MEME TRANSACTION.
// Et elle preserve ce qui faisait la valeur de l'architecture v4 -- l'independance des
// dispositions -- en enfermant chaque etape dans sa propre SOUS-TRANSACTION : un terrain
// introuvable annule sa seule etape (mutation ET marqueur ensemble, jamais l'un sans l'autre) et
// laisse les autres acquises, exactement comme avant. Un seul aller-retour la ou il en fallait
// deux par etape.
//
// POURQUOI PAS actes_nocturnes : le verrou juste existe deja et il est METIER
// (dispositions[].regle, part_etat_reglee, part_notaire_reglee). Une cle de journee serait un
// second verrou pour le meme travail -- et elle serait fausse, puisqu'une etape en echec doit
// pouvoir etre reprise des le lendemain.
//
// LA PHASE DE DECISION RESTE AU-DESSUS, cote JS (chaine de convocations, renonciation tacite,
// cascade) : elle est persistee AVANT tout reglement, et aucune mutation n'a lieu sur un etat non
// confirme en base. Rien de cette separation ne change.
//
// Retourne true si la succession a ete effectivement cloturee (statut='resolue') lors de CET
// appel, false sinon -- utilise par resoudreSuccessionsExpirees() pour ne compter dans ses
// statistiques que les clotures reelles.
async function reglerSuccession(s) {
  const etape = 'succession:' + s.id;
  const v = await sbRpc('succession_regler', { p_succession_id: s.id }, HEADERS_SERVICE)
    .then(rows => Array.isArray(rows) ? rows[0] : rows).catch(() => null);
  // AUCUN VERDICT N'EST JAMAIS UNE CLOTURE : sans reponse de la porte, on ne sait pas ce qui a
  // ete regle, et on ne compte rien.
  if (!v) { signalerEchec(etape, 'aucun verdict rendu'); return false; }
  if (v.ok !== true) { signalerEchec(etape, v.raison || 'refus sans motif'); return false; }
  // Les etapes refusees sont NOMMEES : elles seront reprises demain, mais elles ne disparaissent
  // pas dans le silence. Une succession partiellement reglee n'est pas un succes.
  if (Array.isArray(v.echecs) && v.echecs.length > 0) {
    signalerEchec(etape, 'etapes non reglees : ' + v.echecs.join(' ; '));
  }
  return v.cloturee === true;
}

// Passe quotidienne : fait avancer chaque disposition independamment (silence a l'echeance =
// renonciation tacite, jamais une acceptation ; cascade immediate vers l'etape suivante des que
// la renonciation -- explicite ou tacite -- est constatee, aucune attente artificielle une fois
// la chaine effectivement epuisee) ; regle et cloture des qu'une succession n'a plus aucune
// disposition en attente.
async function resoudreSuccessionsExpirees() {
  const resultats = { convocations_expirees: 0, remplacants_convoques: 0, conjoints_convoques: 0, successions_reglees: 0 };
  try {
    const successions = await sbGet('successions', 'statut=eq.en_attente');
    if (!successions) return resultats;

    for (const s of successions) {
      const dispositions = s.dispositions || [];
      let mutated = false;
      const nouveauxConvoques = [];

      for (const d of dispositions) {
        if (d.resultat) continue; // deja resolue individuellement lors d'une passe precedente

        const chaine = d.chaine || [];
        const etape = chaine[chaine.length - 1];

        if (!etape) {
          // Chaine vide des l'ouverture (aucun beneficiaire valide identifie) -- resolution
          // anticipee au premier passage du cron, aucune attente artificielle.
          d.resultat = { beneficiaire: null, statut: 'devolution_etat' };
          d.etat = 'resolue';
          mutated = true;
          continue;
        }

        if (etape.reponse === 'accepte') {
          d.resultat = { beneficiaire: etape.beneficiaire, statut: 'accepte' };
          d.etat = 'resolue';
          mutated = true;
          continue;
        }

        if (etape.reponse === null && Date.now() > new Date(etape.expires_at).getTime()) {
          etape.reponse = 'renonce';
          etape.repondu_le = new Date().toISOString();
          mutated = true;
          resultats.convocations_expirees++;
        }

        if (etape.reponse === 'renonce') {
          const suivante = await determinerEtapeSuivanteServeur(d, etape.role, s.conjoint);
          if (suivante) {
            d.chaine.push(suivante);
            mutated = true;
            nouveauxConvoques.push(suivante.beneficiaire);
            if (suivante.role === 'remplacant') resultats.remplacants_convoques++;
            else resultats.conjoints_convoques++;
          } else {
            d.resultat = { beneficiaire: null, statut: 'devolution_etat' };
            d.etat = 'resolue';
            mutated = true;
          }
        }
      }

      // Phase decision (ci-dessus) et phase reglement (reglerSuccession) separees par leur
      // propre ecriture : les decisions fraichement tranchees cette passe (resultat/chaine) sont
      // persistees ICI, AVANT toute tentative de reglement -- jamais implicitement portees par la
      // toute premiere ecriture interne de reglerSuccession. Si cette persistance echoue, on ne
      // tente meme pas le reglement sur un etat non confirme en base : la succession sera
      // retentee integralement demain, sans aucun risque d'avoir mute un actif sur la base d'une
      // decision jamais realmente ecrite.
      if (mutated) {
        const r = await sbUpdate('successions', `id=eq.${encodeURIComponent(s.id)}`, { dispositions }).catch(() => null);
        if (!r) continue;
      }

      const toutesResolues = dispositions.every(d => !!d.resultat);
      if (toutesResolues) {
        // La porte relit les dispositions en base -- celles qui viennent d'etre persistees juste
        // au-dessus. Plus rien ne lui est transmis en memoire : la base est la seule source.
        const cloturee = await reglerSuccession(s);
        if (cloturee) resultats.successions_reglees++;
      }

      for (const dest of nouveauxConvoques) {
        await envoyerMailSysteme(dest, 'Office Notarial', 'Succession — ' + s.defunt, 'Vous êtes convoqué(e) au sujet de la succession de ' + s.defunt + '. Rendez-vous au Bureau des Successions de l\'Office Notarial de Luthécia, rubrique « Réclamer un héritage ».').catch(() => {});
      }
    }
  } catch(e) { console.error('resoudreSuccessionsExpirees error', e); }
  return resultats;
}

// Nettoie les rendez-vous d'achat direct manques (au-dela des 24h de rattrapage) : le depot
// de garantie est perdu, le terrain redevient libre.
// Table dupliquee cote serveur (les niveaux de construction ne changent que rarement — si
// modifies un jour cote client, penser a repercuter ici aussi).
const NIVEAUX_CONSTRUCTION_SERVEUR = {
  hangar:            { label: 'Hangar',             cout: 30000 },
  commerce_standard: { label: 'Commerce standard',  cout: 50000 },
  commerce_premium:  { label: 'Commerce premium',   cout: 70000 },
  building:          { label: 'Building',           cout: 100000 }
};

const ALEAS_CHANTIER = [
  { cle: 'intemperies', texte: "Intempéries : le chantier a pris du retard à cause de la pluie." },
  { cle: 'canicule',    texte: "Canicule : les travaux ont été suspendus par forte chaleur, pour la sécurité des ouvriers." }
];

// Progression quotidienne de tous les chantiers en cours : verifie les versements dus,
// gere les impayes (relance J+2, perte de l'acompte + recul d'un palier a J+3), tire les
// aleas (intemperies/canicule pour l'instant), et livre le batiment quand tout est paye et
// la date de fin prevue atteinte.
// MOTEUR DE CHANTIER — PROGRESSION EFFECTIVE (Lot 1.5.7)
// Remplace integralement l'ancien moteur calendaire (dateFinPrevue / palierPaye / versements
// imposes) : il n'existe plus qu'UN seul moteur, celui-ci. La progression n'est jamais deduite
// d'une duree ecoulee ; le calendrier ne sert qu'a savoir qu'une nouvelle journee doit etre
// traitee (marqueur jourTraite, meme doctrine anti-rejeu que jourPaiement au Lot 1.4).
//
// DUPLICATION ASSUMEE ET VERROUILLEE PAR TEST : ce fichier est un module serverless isole, il ne
// peut pas charger plateau-chantiers.js (script classique du navigateur). Les quelques formules
// necessaires sont donc reecrites ici -- meme convention que sbGet/sbInsert, deja dupliques. Un
// test compare les DEUX implementations sur les memes entrees -- SAUF QUE CE TEST N'EXISTE PAS :
// verifie dans tout le depot le 6 octobre 2026. L'affirmation est restee ici sans son objet.
const CHANTIER_SEUILS_SERVEUR = { demarrage: 35, premierTiers: 70, deuxTiers: 100 };

function progressionMaxFinanceeServeur(totalVerse, dureeJours, coutTotal) {
  const d = Number(dureeJours) || 0, total = Number(coutTotal) || 0, verse = Math.max(0, Number(totalVerse) || 0);
  if (d <= 0) return 0;
  if (total <= 0) return d;
  if (verse * 100 >= CHANTIER_SEUILS_SERVEUR.deuxTiers * total) return d;
  if (verse * 100 >= CHANTIER_SEUILS_SERVEUR.premierTiers * total) return d * 2 / 3;
  if (verse * 100 >= CHANTIER_SEUILS_SERVEUR.demarrage * total) return d / 3;
  return 0;
}

// TRANSITION PROVISOIRE DU LOT 1.5.7, a remplacer aux Lots 1.5.8 (materiaux) et 1.5.9 (travail) :
// en l'absence de ces sous-systemes, la capacite du jour est reputee complete. Isolee ici, comme
// capaciteProvisoireCompleteLot157 cote client.
// TRAVAIL REEL (Lot 1.5.9). Memes formules que plateau-chantiers.js, dupliquees ici pour la meme
// raison que les materiaux.
// AUCUN TEST NE LE VERIFIE AUJOURD'HUI -- constate le 6 octobre 2026 : le test annonce
// n'existe nulle part dans le depot. La duplication de FONCTIONS est inventoriee et
// reportee au chantier 7 ; le 4B n'a traite que les donnees.
const TAUX_HORAIRE_SERVEUR = 70;

function capaciteHeuresJourServeur(ch) {
  const d = Math.max(0, Number(ch && ch.dureeJours) || 0);
  if (d <= 0) return 0;
  return (Math.max(0, Number(ch.coutTravail) || 0) / TAUX_HORAIRE_SERVEUR) / d;
}

// Reliquat NPC. Quatre bornes simultanees : capacite quotidienne, heures deja faites par des PJ,
// fraction de materiaux reellement disponible APRES approvisionnement, et tresorerie. On ne paie
// jamais des ouvriers pour un travail qui ne peut pas contribuer a la progression du jour --
// 0 % de materiaux, 0 heure NPC, 0 FR verse au ministere.
function reliquatNPCServeur(ch, fMat) {
  const cap = capaciteHeuresJourServeur(ch);
  const f = Math.max(0, Math.min(1, fMat === undefined ? 1 : (Number(fMat) || 0)));
  const utiles = Math.floor(cap * f);
  const faites = Math.max(0, Number(ch && ch.heuresFaites) || 0);
  const restantesUtiles = Math.max(0, utiles - faites);
  const payables = Math.floor(Math.max(0, Number(ch && ch.tresorerie) || 0) / TAUX_HORAIRE_SERVEUR);
  const heures = Math.max(0, Math.min(restantesUtiles, payables));
  return { heures: heures, montant: heures * TAUX_HORAIRE_SERVEUR };
}

function fractionTravailServeur(ch, heuresNPC) {
  const cap = capaciteHeuresJourServeur(ch);
  if (cap <= 0) return 1;
  const faites = Math.max(0, Number(ch && ch.heuresFaites) || 0) + Math.max(0, Number(heuresNPC) || 0);
  return Math.max(0, Math.min(1, faites / cap));
}

// MATERIAUX REELS (Lot 1.5.8). Memes formules que plateau-chantiers.js, dupliquees ici parce que
// le cron est un module serverless isole ; l'egalite des deux implementations est verrouillee par
// test, comme pour progressionMaxFinancee.
const ENTREPOTS_PAR_VILLE_SERVEUR = {
  capitale: 'entrepot-logistique-luthecia',
  ville_a:  'entrepot-logistique-psm',
  ville_b:  'entrepot-logistique-montrouge'
};
const SEQUENCE_METAL_SERVEUR = [33, 33, 34];
const MATERIAUX_SERVEUR = ['bois', 'minerai', 'metal'];

function materiauxDuJourServeur(jour) {
  const n = Math.floor(Number(jour) || 0);
  return { bois: 100, minerai: 50,
           metal: n < 1 ? 0 : SEQUENCE_METAL_SERVEUR[(n - 1) % SEQUENCE_METAL_SERVEUR.length] };
}

function numeroJourChantierServeur(ch) {
  return Math.floor(Math.max(0, Number(ch && ch.progressionJours) || 0)) + 1;
}

// Panier du jour d'une reconfiguration (Lot 1.5.14) : un tiers du budget quotidien dans chaque
// matiere, aux prix de reference. Miroir de materiauxDuJourReamenagement (plateau-chantiers.js).
function materiauxDuJourReamenagementServeur(ch) {
  const duree = Math.max(0, Number(ch && ch.dureeJours) || 0);
  const budget = duree > 0 ? Math.max(0, Number(ch.coutMateriaux) || 0) / duree : 0;
  const parMatiere = budget / MATERIAUX_SERVEUR.length;
  const panier = {};
  MATERIAUX_SERVEUR.forEach(function (cle) {
    const prix = (RESSOURCES_ECONOMIE_SERVEUR[cle] && RESSOURCES_ECONOMIE_SERVEUR[cle].prixBase) || 0;
    panier[cle] = prix > 0 ? Math.round(parMatiere / prix) : 0;
  });
  return panier;
}

// Besoin du jour, quel que soit le type de chantier. Miroir de besoinMateriauxJourChantier.
function besoinMateriauxJourServeur(ch, jourNumero) {
  if (!ch) return { bois: 0, minerai: 0, metal: 0 };
  if (ch.type === 'construction') return materiauxDuJourServeur(jourNumero);
  if (ch.type === 'reamenagement') return materiauxDuJourReamenagementServeur(ch);
  return { bois: 0, minerai: 0, metal: 0 };
}

// La matiere la plus manquante commande. Un besoin nul n'est pas une contrainte.
// Miroir serveur de planifierApprovisionnement (plateau-chantiers.js) -- meme raison que les
// autres duplications du cron.
// AUCUN TEST NE LE VERIFIE AUJOURD'HUI -- constate le 6 octobre 2026 : le test annonce
// n'existe nulle part dans le depot. La duplication de FONCTIONS est inventoriee et
// reportee au chantier 7 ; le 4B n'a traite que les donnees.
function planifierApprovisionnementServeur(besoin, stockChantier, stockEntrepot, tresorerie) {
  const achats = {}, nouveauChantier = {}, nouvelEntrepot = { ...(stockEntrepot || {}) };
  let depense = 0;
  MATERIAUX_SERVEUR.forEach(function (cle) {
    const enChantier = Math.max(0, Number((stockChantier || {})[cle]) || 0);
    nouveauChantier[cle] = enChantier;
    const manque = Math.max(0, (Number((besoin || {})[cle]) || 0) - enChantier);
    if (manque <= 0) return;
    const prix = (RESSOURCES_ECONOMIE_SERVEUR[cle] && RESSOURCES_ECONOMIE_SERVEUR[cle].prixBase) || 0;
    const dispo = Math.max(0, Math.floor(Number(nouvelEntrepot[cle]) || 0));
    const abordable = prix > 0 ? Math.floor(Math.max(0, (Number(tresorerie) || 0) - depense) / prix) : 0;
    const qte = Math.min(manque, dispo, abordable);
    if (qte <= 0) return;
    achats[cle] = qte; depense += qte * prix;
    nouveauChantier[cle] = enChantier + qte;
    nouvelEntrepot[cle] = dispo - qte;
  });
  return { achats, depense, stockChantier: nouveauChantier, stockEntrepot: nouvelEntrepot };
}

function fractionMateriauxServeur(stock, besoin) {
  let f = 1, contrainte = false;
  MATERIAUX_SERVEUR.forEach(function (cle) {
    const r = Math.max(0, Number(besoin[cle]) || 0);
    if (r <= 0) return;
    contrainte = true;
    f = Math.min(f, Math.min(1, Math.max(0, Number((stock || {})[cle]) || 0) / r));
  });
  return contrainte ? Math.max(0, Math.min(1, f)) : 1;
}

// =====================================================================
// INSTRUCTION DES PERMIS ET ACCORD TACITE (Lot 1.5.13)
// =====================================================================
// Le delai d'instruction se compte en journees REELLEMENT instruites, pas en date-cible : c'est ce
// traitement, et lui seul, qui les compte. Passe le delai sans decision, le silence vaut accord.
//
// POURQUOI ICI ET PAS DANS LE NAVIGATEUR : state.day est un compteur propre a chaque joueur, que
// seul le fait de dormir fait avancer. Deux demandeurs auraient des delais differents, et un
// dossier dont le proprietaire ne se connecte pas n'aboutirait jamais. Le passage quotidien est la
// seule horloge commune.
//
// Les FONCTIONS pures ci-dessous restent recopiees de plateau-immobilier.js : le chantier 4B
// n'a traite que les donnees. Leur deduplication demande de separer donnees et comportement
// dans les fichiers du navigateur, et c'est un chantier a part. La CONSTANTE qu'elles lisent,
// PERMIS_STATUT_LEGACY_ATTENTE_SERVEUR, est elle importee du module genere.

function permisEnInstructionServeur(p) {
  const s = p && p.statut;
  return s === 'instruction' || s === PERMIS_STATUT_LEGACY_ATTENTE_SERVEUR;
}

function dureeInstructionPermisServeur(p) {
  const d = p && Number(p.dureeInstruction);
  return (isFinite(d) && d > 0) ? Math.floor(d) : 0;
}

function joursInstructionFaitsServeur(p) {
  const n = p && Number(p.joursInstructionFaits);
  if (isFinite(n) && n >= 0) return Math.floor(n);
  if (p && p.statut === PERMIS_STATUT_LEGACY_ATTENTE_SERVEUR) return dureeInstructionPermisServeur(p);
  return 0;
}

function instructionAcheveeServeur(p) {
  const d = dureeInstructionPermisServeur(p);
  return d > 0 && joursInstructionFaitsServeur(p) >= d;
}

function terrainSuspenduServeur(etat) {
  if (!etat) return false;
  return etat.pnj === 'cadavre' || !!etat.succession_gel;
}

function verdictAccordTaciteServeur(etat) {
  const p = etat && etat.permis;
  if (!p) return { ok: false, raison: 'aucun_permis' };
  if (!permisEnInstructionServeur(p)) return { ok: false, raison: 'deja_decide' };
  if (terrainSuspenduServeur(etat)) return { ok: false, raison: 'suspendu' };
  if (!instructionAcheveeServeur(p)) return { ok: false, raison: 'delai_non_ecoule' };
  return { ok: true, raison: null };
}

// Miroir compact de construireDocumentUrbanisme (plateau-immobilier.js). Memes champs, memes
// valeurs ; les libelles lisibles (batimentLabel, palierLabel) retombent sur les identifiants,
// exactement comme le fait la version client quand BUILDINGS et NIVEAUX_CONSTRUCTION ne sont pas
// charges. Aucune regle ici : un snapshot administratif fige, rien d'autre.
function construireDocumentUrbanismeServeur(etat, permis, nature, opt) {
  const o = opt || {}, p = permis || {}, t = etat || {};
  const plan = Array.isArray(p.decoupageInitial) ? p.decoupageInitial : [];
  return {
    id: (p.numeroDossier || 'URB-SANS-NUMERO') + '-' + nature + '-' + Date.now() + '-' + Math.floor(Math.random() * 1000),
    nature: nature,
    numeroDossier: p.numeroDossier || null,
    jour: (typeof o.jour === 'number') ? o.jour : null,
    jourDepot: (typeof p.dateDepot === 'number') ? p.dateDepot : null,
    demandeur: p.demandeur || null,
    pays: o.pays || null,
    ville: t.city || o.ville || null,
    buildingId: o.buildingId || null,
    batimentLabel: o.buildingId || null,
    palier: p.palierDemande || null,
    palierLabel: p.palierDemande || null,
    surfaceExploitable: (typeof t.surface === 'number' && isFinite(t.surface) && t.surface >= 0) ? t.surface : null,
    decoupage: plan.map(function (l) {
      return { id: l.id, label: l.label, surface: Number(l.surface),
               destination: (l.destination === 'appartement') ? 'appartement' : 'commerce' };
    }),
    motifRefus: null
  };
}

function libelleAccordTaciteServeur(doc) {
  const terrain = doc.batimentLabel || doc.buildingId || 'un terrain';
  const palier = doc.palierLabel ? (' (' + doc.palierLabel + ')') : '';
  return 'Accord tacite au bénéfice de ' + (doc.demandeur || 'un demandeur') + ' pour ' + terrain + palier + '.';
}

// Texte du document physique. Miroir volontairement resserre de texteDocumentUrbanisme : meme
// contenu factuel, sans les fioritures qui dependent des catalogues client.
function texteAccordTaciteServeur(doc) {
  const l = [];
  l.push('Dossier n° ' + (doc.numeroDossier || 'non attribué (dossier antérieur à la numérotation)'));
  l.push('Demandeur : ' + (doc.demandeur || 'inconnu'));
  l.push('Commune : ' + (doc.ville || 'non précisée') + ' (' + (doc.pays || 'non précisé') + ')');
  l.push('Terrain : ' + (doc.batimentLabel || doc.buildingId || 'non précisé'));
  l.push('Nature des travaux : ' + (doc.palierLabel || 'non précisée'));
  l.push('Surface exploitable : ' + (doc.surfaceExploitable !== null ? doc.surfaceExploitable + ' m²' : 'non connue'));
  if (doc.decoupage.length === 0) {
    l.push('Découpage déclaré : aucun — le bâtiment sera livré indivis.');
  } else {
    l.push('Découpage déclaré (' + doc.decoupage.length + ' lot' + (doc.decoupage.length > 1 ? 's' : '') + ') :');
    doc.decoupage.forEach(function (x) {
      l.push('  — ' + x.label + ' : ' + x.surface + ' m² (' + (x.destination === 'appartement' ? 'appartement' : 'commerce') + ')');
    });
  }
  l.push('');
  l.push("Le délai d'instruction s'est écoulé sans décision du service d'urbanisme.");
  l.push("Conformément au droit applicable, l'autorisation est réputée ACCORDÉE.");
  return l.join('\n');
}

// Archive municipale, ecrite par le serveur. Meme table et meme forme de ligne
// qu'archiverEvenementUrbanisme (plateau-immobilier.js) : append-only, une ligne par evenement.
// Renvoie true seulement si la ligne existe reellement -- c'est elle qui COMMANDE.
async function archiverEvenementUrbanismeServeur(doc) {
  // LE PAYS D'UN DOSSIER D'URBANISME EST SA JURIDICTION (chantier 4G, 8 octobre 2026). Cette
  // ligne ecrivait `doc.pays || 'republic'` : un dossier dont le pays n'etait pas renseigne etait
  // archive dans la commune de Republia, quelle que soit celle ou se trouve le terrain. On refuse
  // plutot que d'archiver au mauvais endroit -- une archive append-only ne se corrige pas apres
  // coup, et le refus remonte dans ECHECS_PASSE donc la passe rend 500.
  if (!(doc && VILLES_SERVEUR[doc.pays])) {
    signalerEchec('urbanisme:pays_non_declare', JSON.stringify(doc && doc.pays));
    return false;
  }
  const rows = await sbInsert('dossiers_urbanisme', {
    id: 'urb-' + doc.nature + '-' + Date.now() + '-' + Math.floor(Math.random() * 1000000),
    country: doc.pays,
    city: doc.ville || null,
    building_id: doc.buildingId || null,
    numero_dossier: doc.numeroDossier || null,
    type_evenement: doc.nature,
    demandeur: doc.demandeur || null,
    jour: (typeof doc.jour === 'number') ? doc.jour : null,
    libelle: libelleAccordTaciteServeur(doc),
    data: doc
  }).catch(() => null);
  return !!(rows && rows.length > 0);
}

// TRAITEMENT QUOTIDIEN DE L'INSTRUCTION.
// Une journee par passage, jamais deux (marqueur jourInstruction), jamais pendant une suspension.
// L'accord tacite n'est prononce qu'une fois : des que le permis passe a 'valide', il sort du
// verdict. L'archive municipale COMMANDE -- si elle n'est pas ecrite, l'accord n'a pas lieu et sera
// retente la nuit suivante.
async function traiterInstructionsPermis() {
  const resultats = { instruits: 0, suspendus: 0, accords_tacites: 0, echecs_archive: 0, ignores: 0 };
  try {
    const terrains = await sbGet('terrains_etat', '');
    if (!terrains) return resultats;
    // Cle CRON-SEULEMENT (permis.jourInstruction) : Europe/Paris (arbitrage du 20/09/2026).
    const jour = jourParisISO();

    for (const row of terrains) {
      let etat;
      try { etat = JSON.parse(row.data); } catch (e) { continue; }
      const p = etat.permis;
      if (!permisEnInstructionServeur(p)) continue;
      if (p.jourInstruction === jour) { resultats.ignores++; continue; }   // anti-rejeu quotidien

      p.jourInstruction = jour;
      const suspendu = terrainSuspenduServeur(etat);
      if (suspendu) {
        // L'enquete GELE le compteur : aucune journee consommee, aucune perdue non plus.
        resultats.suspendus++;
      } else if (!instructionAcheveeServeur(p)) {
        p.joursInstructionFaits = joursInstructionFaitsServeur(p) + 1;
        resultats.instruits++;
      }

      const verdict = verdictAccordTaciteServeur(etat);
      if (verdict.ok) {
        const doc = construireDocumentUrbanismeServeur(etat, p, 'accord_tacite',
          { buildingId: row.building_id, pays: row.country, ville: etat.city, jour: null });
        const archive = await archiverEvenementUrbanismeServeur(doc);
        if (!archive) {
          // Rien n'est decide sans acte municipal. On n'ecrit meme pas le compteur : la nuit
          // suivante reprendra exactement au meme point.
          resultats.echecs_archive++;
          continue;
        }

        p.statut = 'valide';
        p.accordTacite = true;
        p.jourDecision = jour;
        etat.constructionAutorisee = true;

        // Copie physique du document, par le canal de reception automatique (Lot 1.5.4) : elle
        // entre meme si l'inventaire est plein, quitte a mettre le demandeur en Surcharge.
        // Identifiant deterministe : un rejeu ne peut pas produire deux exemplaires.
        if (p.demandeur) {
          await sbInsert('objets_recus', {
            id: 'urb-tacite-' + row.id + '-' + (p.numeroDossier || 'sansnumero'),
            destinataire: p.demandeur,
            expediteur: "Services d'urbanisme",
            data: JSON.stringify({
              id: doc.id,
              type: 'document_urbanisme_accord_tacite',
              name: "Attestation d'accord tacite" + (doc.batimentLabel ? ' — ' + doc.batimentLabel : ''),
              icon: 'ti-file-certificate',
              legal: true,
              desc: texteAccordTaciteServeur(doc),
              documentUrbanisme: doc
            })
          }).catch(() => {});
          await envoyerMailSysteme(p.demandeur, "Services d'urbanisme", 'Permis accorde tacitement', "Le delai d'instruction de votre demande s'est ecoule sans decision. Votre permis de construire est donc ACCORDE TACITEMENT : vous pouvez construire. L'attestation vous sera remise a votre prochaine connexion.").catch(() => {});
        }
        resultats.accords_tacites++;
      }

      await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`,
        { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
    }
  } catch (e) { console.error('traiterInstructionsPermis error', e); }
  return resultats;
}

// VERROU DU PLAN ET LIVRAISON (Lots 1.5.11 / 1.5.12). Memes formules que plateau-chantiers.js,
// dupliquees ici pour la meme raison que les materiaux et le travail -- le cron est un module
// serverless isole qui ne peut pas charger un script de navigateur.
// AUCUN TEST NE LE VERIFIE AUJOURD'HUI -- constate le 6 octobre 2026 : le test annonce
// n'existe nulle part dans le depot. La duplication de FONCTIONS est inventoriee et
// reportee au chantier 7 ; le 4B n'a traite que les donnees.
function seuilDeuxTiersServeur(dureeJours) {
  return Math.max(0, Number(dureeJours) || 0) * 2 / 3;
}

function progressionAtteintDeuxTiersServeur(ch) {
  const d = Math.max(0, Number(ch && ch.dureeJours) || 0);
  if (d <= 0) return false;
  return Math.max(0, Number(ch.progressionJours) || 0) >= seuilDeuxTiersServeur(d);
}

// Pose le verrou, ne le retire jamais. Mute le chantier en place, comme tout le reste de cette
// boucle (le cron travaille sur l'objet qu'il vient de parser, pas sur des copies).
function appliquerVerrouPlanServeur(ch, jour) {
  if (!ch || ch.planVerrouille === true) return false;
  if (!progressionAtteintDeuxTiersServeur(ch)) return false;
  ch.planVerrouille = true;
  ch.jourVerrouPlan = (jour === undefined || jour === null) ? null : jour;
  return true;
}

function chantierTermineServeur(ch) {
  const d = Math.max(0, Number(ch && ch.dureeJours) || 0);
  if (d <= 0) return false;
  return Math.max(0, Number(ch.progressionJours) || 0) >= d;
}

function lotsLivrablesDepuisPlanServeur(plan) {
  const lots = Array.isArray(plan) ? plan : [];
  const vus = {}, sortie = [];
  lots.forEach(function (l, i) {
    if (!l || typeof l !== 'object') return;
    const surface = Math.max(0, Number(l.surface) || 0);
    if (surface <= 0) return;
    let id = (typeof l.id === 'string' && l.id.trim()) ? l.id.trim() : ('lot-livre-' + (i + 1));
    if (vus[id]) id = id + '-' + (i + 1);
    vus[id] = true;
    sortie.push({
      id: id,
      label: (typeof l.label === 'string' && l.label.trim()) ? l.label.trim() : ('Lot ' + (i + 1)),
      surface: surface,
      destination: (l.destination === 'appartement') ? 'appartement' : 'commerce',
      locataire: null, loyer: 0
    });
  });
  return sortie;
}

// RELIQUATS A LA LIVRAISON. Ce qui reste dans le chantier a l'instant ou il se solde -- tresorerie
// non depensee, materiaux non consommes. Ce n'est pas un cas rare : un proprietaire qui sur-finance,
// ou un PJ qui livre plus de matieres que la journee n'en consomme, en laissent forcement.
function reliquatsDuChantierServeur(ch) {
  const stock = (ch && ch.stockMateriaux) || {};
  const materiaux = {};
  let total = 0;
  MATERIAUX_SERVEUR.forEach(function (cle) {
    const q = Math.max(0, Math.floor(Number(stock[cle]) || 0));
    if (q > 0) { materiaux[cle] = q; total += q; }
  });
  const tresorerie = Math.max(0, Math.floor(Number(ch && ch.tresorerie) || 0));
  return { tresorerie: tresorerie, materiaux: materiaux, unites: total,
           aRestituer: tresorerie > 0 || total > 0 };
}

// Livraison IDEMPOTENTE : elle retire etat.chantier, donc un cron rejoue ne trouve plus rien a
// livrer. Les lots ne sont ecrits que si le batiment n'en a aucun.
//
// RELIQUATS (arbitrage GD du 7 septembre 2026). Tresorerie et materiaux restants reviennent au
// PROPRIETAIRE ACTUEL DES MURS -- pas a celui qui a lance ou finance le chantier. La livraison les
// SORT du chantier -- chantierAcheve.tresorerie et chantierAcheve.stockMateriaux tombent a zero,
// plus rien n'y est disponible -- et les inscrit dans chantierAcheve.reliquats, qui est a la fois
// la trace historique de ce qui a ete rendu et l'ordre de paiement a executer.
// Le versement lui-meme n'a pas lieu ici : il touche trois tables et doit etre atomique, donc il
// passe par la RPC restituer_reliquats_chantier, appelee juste apres l'ecriture du terrain. Tant
// que restitue vaut false, la nuit suivante rejouera -- rien ne peut etre perdu, et le marqueur
// pose dans la meme transaction que les paiements interdit de payer deux fois.
function livrerChantierServeur(etat, jour) {
  const ch = etat && etat.chantier;
  if (!ch) return { livre: false, raison: 'chantier_absent', lots: 0 };
  if (!chantierTermineServeur(ch)) return { livre: false, raison: 'chantier_en_cours', lots: 0 };

  const plan = (etat.permis && Array.isArray(etat.permis.decoupageInitial)) ? etat.permis.decoupageInitial : [];
  const dejaDivise = Array.isArray(etat.subdivisions) && etat.subdivisions.length > 0;
  if (!etat.niveau_construction) etat.niveau_construction = ch.niveau || null;
  const lots = dejaDivise ? [] : lotsLivrablesDepuisPlanServeur(plan);
  if (lots.length > 0) etat.subdivisions = lots;

  const reliquats = reliquatsDuChantierServeur(ch);
  etat.chantierAcheve = { ...ch, planVerrouille: true, livre: true,
                          jourLivraison: (jour === undefined || jour === null) ? null : jour,
                          // Plus rien n'est disponible dans le chantier livre : les valeurs sont
                          // parties, et ne subsistent que dans reliquats, a titre historique.
                          tresorerie: 0,
                          stockMateriaux: { bois: 0, minerai: 0, metal: 0 },
                          reliquats: {
                            tresorerie: reliquats.tresorerie,
                            materiaux: reliquats.materiaux,
                            beneficiaire: etat.proprietaire || null,
                            restitue: !reliquats.aRestituer,     // rien a rendre = rien a attendre
                            jourLivraison: (jour === undefined || jour === null) ? null : jour
                          } };
  delete etat.chantier;
  return { livre: true, raison: null, lots: lots.length, indivis: lots.length === 0,
           reliquats: reliquats };
}

// APPLICATION DE LA RECONFIGURATION (Lot 1.5.14).
//
// ATOMICITE. Le plan cible ne remplace le plan reel qu'a 100 %, et JAMAIS progressivement. Cette
// substitution, l'archivage du chantier et la liberation des surfaces sont trois mutations du MEME
// objet JSON, ecrit ensuite par un seul UPDATE d'une seule ligne : il n'existe aucun instant ou la
// base contiendrait la moitie de l'ancien plan et la moitie du nouveau, ni un chantier reput
// termine dont le plan ne serait pas applique. Aucune RPC n'est necessaire pour cela -- le seul
// mouvement qui traverse plusieurs tables est le versement des reliquats, qui a deja la sienne.
//
// UN SEUL EMPLACEMENT D'ARCHIVE EN ATTENTE. chantierAcheve est le dernier chantier livre, et le
// seul qui puisse porter une restitution non encore versee. Une reconfiguration qui se solde y
// prend la place de la construction, laquelle rejoint chantiersArchives -- l'historique est
// integralement conserve, et la RPC de restitution continue de lire un emplacement unique, sans
// migration ni seconde doctrine. Tant qu'une restitution precedente n'est pas versee, on ne
// deplace rien : la nuit suivante reprendra.
function appliquerReconfigurationServeur(etat, jour) {
  const ch = etat && etat.chantierReamenagement;
  if (!ch) return { livre: false, raison: 'chantier_absent', lots: 0 };
  if (!chantierTermineServeur(ch)) return { livre: false, raison: 'chantier_en_cours', lots: 0 };

  const enAttente = etat.chantierAcheve && etat.chantierAcheve.reliquats
                    && etat.chantierAcheve.reliquats.restitue !== true;
  if (enAttente) return { livre: false, raison: 'restitution_precedente_en_attente', lots: 0 };

  // LE PLAN CIBLE DEVIENT LE PLAN REEL, en une seule affectation. Un plan cible vide est un
  // resultat legitime : toutes les surfaces ont ete reunifiees, le batiment redevient indivis.
  const cible = Array.isArray(ch.planCible) ? ch.planCible : [];
  etat.subdivisions = cible.map(function (l, i) {
    return {
      id: (typeof l.id === 'string' && l.id.trim()) ? l.id.trim() : ('lot-recfg-' + (i + 1)),
      label: (typeof l.label === 'string' && l.label.trim()) ? l.label.trim() : ('Lot ' + (i + 1)),
      surface: Math.max(0, Number(l.surface) || 0),
      destination: (l.destination === 'appartement') ? 'appartement' : 'commerce',
      locataire: null,
      loyer: 0
    };
  }).filter(function (l) { return l.surface > 0; });

  const reliquats = reliquatsDuChantierServeur(ch);
  if (etat.chantierAcheve) {
    etat.chantiersArchives = (etat.chantiersArchives || []).concat([etat.chantierAcheve]);
  }
  etat.chantierAcheve = { ...ch, livre: true,
                          jourLivraison: (jour === undefined || jour === null) ? null : jour,
                          tresorerie: 0,
                          stockMateriaux: { bois: 0, minerai: 0, metal: 0 },
                          // Les surfaces se liberent parce que le chantier n'est plus vivant :
                          // surfaceImmobilisee et l'indisponibilite des lots derivent toutes deux
                          // de etat.chantierReamenagement, qui disparait ci-dessous.
                          surfaceLibreImmobilisee: 0,
                          reliquats: {
                            tresorerie: reliquats.tresorerie,
                            materiaux: reliquats.materiaux,
                            beneficiaire: etat.proprietaire || null,
                            restitue: !reliquats.aRestituer,
                            jourLivraison: (jour === undefined || jour === null) ? null : jour
                          } };
  delete etat.chantierReamenagement;

  return { livre: true, raison: null, lots: etat.subdivisions.length,
           indivis: etat.subdivisions.length === 0, reliquats: reliquats };
}

// Execute l'ordre de paiement depose par la livraison. Rejouable sans risque : la RPC verifie le
// marqueur sous verrou et ne paie qu'une fois. Renvoie true si la restitution est desormais faite
// (ou n'avait rien a faire), false si elle reste en attente -- auquel cas la nuit suivante rejouera.
async function restituerReliquatsServeur(terrainId, etat) {
  const rel = etat && etat.chantierAcheve && etat.chantierAcheve.reliquats;
  if (!rel || rel.restitue === true) return true;
  if (!etat.proprietaire) return false;               // sans proprietaire, aucun beneficiaire legitime
  const rows = await sbRpc('restituer_reliquats_chantier',
    { p_beneficiaire: etat.proprietaire, p_terrain_id: terrainId }).catch(() => null);
  const verdict = Array.isArray(rows) ? rows[0] : rows;
  return !!(verdict && verdict.ok);
}

async function avancerChantiersQuotidien() {
  const resultats = { livraisons: 0, avances: 0, partielles: 0, bloques_financement: 0, penuries: 0, approvisionnements: 0, reprises: 0, heures_npc: 0, ignores: 0, erreurs: 0, verrous_plan: 0, lots_livres: 0, reliquats_restitues: 0, reliquats_en_attente: 0 };
  try {
    const terrains = await sbGet('terrains_etat', '');
    if (!terrains) return resultats;
    // jourTraite n'est ecrit qu'ici : plateau-chantiers.js ne fait que l'initialiser a
    // null. Cle cron-seulement, donc Europe/Paris (arbitrage du 20 septembre 2026).
    const jour = jourParisISO();

    for (const row of terrains) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }

      // RATTRAPAGE DES RESTITUTIONS EN ATTENTE. Une livraison d'une nuit precedente a pu inscrire
      // des reliquats sans reussir a les verser (RPC absente, reseau). Ils sont repris ici, avant
      // toute autre chose : c'est ce rattrapage qui garantit qu'aucun FR et aucun materiau ne peut
      // rester indefiniment en instance. La RPC etant idempotente, ce passage est sans effet quand
      // il n'y a rien a rattraper.
      if (etat.chantierAcheve && etat.chantierAcheve.reliquats
          && etat.chantierAcheve.reliquats.restitue !== true) {
        if (await restituerReliquatsServeur(row.id, etat)) resultats.reliquats_restitues++;
        else resultats.reliquats_en_attente++;
      }

      // UN TERRAIN PEUT PORTER DEUX CHANTIERS VIVANTS AU FIL DE SA VIE : la construction initiale
      // (etat.chantier) puis, une fois le batiment livre, une reconfiguration (Lot 1.5.14). Ils ne
      // coexistent jamais -- on ne reconfigure pas un batiment qui n'existe pas encore -- mais ils
      // partagent EXACTEMENT le meme moteur : approvisionnement, travail PJ et NPC, penurie,
      // progression, verrou, livraison. La boucle passe donc sur les deux emplacements plutot que
      // de dupliquer quatre-vingt-dix lignes de traitement quotidien.
      for (const emplacement of ['chantier', 'chantierReamenagement']) {
      const ch = etat[emplacement];
      if (!ch) continue;

      // LECTURE DEFENSIVE DES CHANTIERS ANCIENS. Un chantier de l'ancien moteur n'a ni type ni
      // progressionJours. On ne lui INVENTE aucune progression a partir de son calendrier : il est
      // repris a 0 jour de travail effectif, avec ses versements deja faits convertis en
      // totalVerse. Aucun chantier de ce genre n'existe en production (verifie), cette branche est
      // un filet de securite.
      if (!ch.type && emplacement === 'chantier') {
        const verseAncien = (Number(ch.montant35) || 0) * Math.max(0, (Number(ch.palierPaye) || 1));
        etat.chantier = {
          type: 'construction', niveau: ch.niveau,
          jourDebut: 0,
          dureeJours: Number(ch.dureeJours) || 0,
          coutTotal: Number(ch.montantTotal) || 0,
          totalVerse: Math.min(verseAncien, Number(ch.montantTotal) || 0),
          tresorerie: 0, stockMateriaux: { bois: 0, minerai: 0, metal: 0 },
          heuresFaites: 0, jourTraite: null, progressionJours: 0, arrete: null,
          evenements: [{ cle: 'reprise_ancien_moteur', jour: jour }],
          travauxPJ: [], ventesMateriauxPJ: []
        };
        await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`,
          { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
        resultats.ignores++;
        continue;                                    // reprise le lendemain, jamais d'avance le jour de la migration
      }

      if (ch.jourTraite === jour) { resultats.ignores++; continue; }   // anti-rejeu quotidien

      const duree = Number(ch.dureeJours) || 0;
      const avant = Math.max(0, Number(ch.progressionJours) || 0);
      const numJour = numeroJourChantierServeur(ch);
      const besoin = besoinMateriauxJourServeur(ch, numJour);
      if (!ch.stockMateriaux) ch.stockMateriaux = { bois: 0, minerai: 0, metal: 0 };

      // APPROVISIONNEMENT AUTOMATIQUE : le chantier complete son stock a l'entrepot logistique de
      // sa ville, dans la limite de sa tresorerie ET du stock reellement disponible la-bas. Aucun
      // materiau ne sort de nulle part : ce qui est achete est retire de l'entrepot et paye dans
      // sa caisse.
      // Un chantier deja arrive a son terme n'a plus de journee a vivre : il ne s'approvisionne
      // plus et n'emploie plus personne, il se solde. Sans cette garde, la derniere nuit
      // depenserait la tresorerie qui doit revenir au proprietaire et rachetes des materiaux
      // qu'aucun travail ne consommera.
      const auTerme = chantierTermineServeur(ch);

      const villeChantier = etat.city || 'capitale';
      const idEntrepot = ENTREPOTS_PAR_VILLE_SERVEUR[villeChantier];
      if (idEntrepot && !auTerme) {
        const etatEnt = await sbGetBatimentEtat(row.country, villeChantier, idEntrepot);
        const stockEnt = (etatEnt.entrepot && etatEnt.entrepot.stock) || {};
        const plan = planifierApprovisionnementServeur(besoin, ch.stockMateriaux, stockEnt, ch.tresorerie);
        const achats = plan.achats, depense = plan.depense;
        if (depense > 0) {
          ch.stockMateriaux = plan.stockChantier;
          ch.tresorerie = Math.max(0, (Number(ch.tresorerie) || 0) - depense);
          // LA RECETTE DE L'ENTREPOT VA DANS SA CAISSE, PLUS DANS SON BLOB (8 octobre 2026).
          // Cette ligne ecrivait `caisse: (blob.caisse || 0) + depense`. Depuis que la cle a
          // quitte le blob, `blob.caisse` vaut toujours undefined : elle aurait donc RECREE la
          // cle avec la depense dedans, a chaque chantier approvisionne. Une seconde bourse,
          // alimentee par de l'argent qui existe deja ailleurs -- c'est-a-dire de la creation
          // monetaire, chaque nuit, en silence.
          etatEnt.entrepot = { ...(etatEnt.entrepot || {}), stock: plan.stockEntrepot };
          await sbSetBatimentEtat(row.country, villeChantier, idEntrepot, { entrepot: etatEnt.entrepot }).catch(() => {});
          const idEnt = row.country + '_' + villeChantier + '_' + idEntrepot;
          const repEnt = await sbRpc('entrepot_caisse_mouvement',
            { p_entrepot_id: idEnt, p_delta: depense }, HEADERS_SERVICE);
          const rEnt = Array.isArray(repEnt) ? repEnt[0] : repEnt;
          if (!rEnt || rEnt.ok !== true) {
            signalerEchec('chantier:recette_entrepot:' + idEnt, (rEnt && rEnt.raison) || 'verdict_absent');
          }
          ch.evenements = (ch.evenements || []).concat([{ cle: 'approvisionnement', jour: jour, achats: achats, cout: depense }]);
          resultats.approvisionnements++;
        }
      }

      // La fraction materiaux est calculee AVANT le travail NPC : elle borne le travail utile de
      // la journee. Payer 50 h d'ouvriers quand les materiaux n'en permettent que 20 reviendrait a
      // remunerer un progres qui ne viendra pas.
      const fMat = fractionMateriauxServeur(ch.stockMateriaux, besoin);

      // TRAVAIL : le reliquat UTILE de la journee est effectue par des NPC, payes par la tresorerie
      // du chantier. Cet argent va dans la caisse REELLE du ministere des Finances, jamais dans
      // budgets_nationaux.reserveJour qui n'est qu'un accumulateur temporaire.
      const npc = auTerme ? { heures: 0, montant: 0 } : reliquatNPCServeur(ch, fMat);
      if (npc.heures > 0) {
        ch.tresorerie = Math.max(0, (Number(ch.tresorerie) || 0) - npc.montant);
        const caisseKey = row.country + '_gouvernement-min_fin';
        const caisseRows = await sbGet('caisses_batiments', `id=eq.${encodeURIComponent(caisseKey)}`).catch(() => null);
        const caisse = (caisseRows && caisseRows[0] && caisseRows[0].data) || { solde: 0 };
        caisse.solde = Math.max(0, (Number(caisse.solde) || 0) + npc.montant);
        if (caisseRows && caisseRows[0]) {
          await sbUpdate('caisses_batiments', `id=eq.${encodeURIComponent(caisseKey)}`, { data: caisse, updated_at: new Date().toISOString() }).catch(() => {});
        } else {
          await sbInsert('caisses_batiments', { id: caisseKey, data: caisse, updated_at: new Date().toISOString() }).catch(() => {});
        }
        ch.evenements = (ch.evenements || []).concat([{ cle: 'travail_npc', jour: jour, heures: npc.heures, montant: npc.montant }]);
        resultats.heures_npc += npc.heures;
      }

      const fTrav = fractionTravailServeur(ch, npc.heures);
      const brut = Math.min(fTrav, fMat);                                  // progression du jour, 0..1
      const plafond = progressionMaxFinanceeServeur(ch.totalVerse, duree, ch.coutTotal);
      const apres = Math.min(duree, Math.max(avant, Math.min(avant + brut, plafond)));
      const gain = apres - avant;

      // CONSOMMATION PROPORTIONNELLE a l'avancee reelle : avancer d'un demi-jour ne consomme que
      // la moitie des materiaux du jour. Jamais plus que le stock present.
      if (gain > 0) {
        for (const cle of MATERIAUX_SERVEUR) {
          const voulu = Math.floor((Number(besoin[cle]) || 0) * gain);
          const pris = Math.min(Math.max(0, Number(ch.stockMateriaux[cle]) || 0), voulu);
          ch.stockMateriaux[cle] = (Number(ch.stockMateriaux[cle]) || 0) - pris;
        }
      }

      ch.progressionJours = apres;
      ch.jourTraite = jour;
      ch.heuresFaites = 0;            // nouvelle journee : le compteur d'heures repart a zero

      // VERROU DU PLAN (Lot 1.5.11). Pose immediatement apres l'ecriture de la progression, donc
      // quelle qu'en soit la cause -- heures PJ, heures NPC, ou simple disponibilite des materiaux.
      // Une regression ulterieure du financement ne le retirera pas : appliquerVerrouPlan ne sait
      // que poser.
      if (appliquerVerrouPlanServeur(ch, jour)) resultats.verrous_plan++;
      // Motif d'arret : la penurie n'est jamais un alea, c'est le constat qu'aucun progres n'est
      // possible. Le financement prime dans le message s'il bloque aussi.
      const bloqueFinance = !(progressionMaxFinanceeServeur(ch.totalVerse, duree, ch.coutTotal) > avant);
      ch.arrete = (gain <= 0 && avant < duree)
        ? (bloqueFinance ? 'financement' : 'penurie_materiaux') : null;

      if (gain > 0 && gain < 1) {
        ch.evenements = (ch.evenements || []).concat([{ cle: 'progression_partielle', jour: jour, fraction: gain }]);
        resultats.partielles++;
      }
      if (ch.arrete === 'penurie_materiaux') {
        resultats.penuries++;
        if (ch.dernierePenurieSignalee !== jour) {
          ch.dernierePenurieSignalee = jour;
          ch.evenements = (ch.evenements || []).concat([{ cle: 'penurie_materiaux', jour: jour, besoin: besoin }]);
          await envoyerMailSysteme(etat.proprietaire, 'Chef de Chantier', 'Chantier a l\'arret — materiaux', 'Les travaux sont a l\'arret faute de materiaux. Approvisionnez le chantier ou creditez sa tresorerie pour qu\'il puisse acheter a l\'entrepot.').catch(() => {});
        }
      } else if (gain > 0 && ch.dernierePenurieSignalee) {
        // REPRISE NATURELLE : rien a declencher, l'approvisionnement redevenu suffisant a suffi.
        ch.dernierePenurieSignalee = null;
        ch.evenements = (ch.evenements || []).concat([{ cle: 'reprise', jour: jour }]);
        resultats.reprises++;
      }

      if (gain > 0) resultats.avances++;
      else if (avant < duree && ch.arrete === 'financement') {
        resultats.bloques_financement++;
        const manque = Math.max(0, Math.ceil(ch.coutTotal * (avant < duree / 3 ? 35 : avant < duree * 2 / 3 ? 70 : 100) / 100) - (Number(ch.totalVerse) || 0));
        await envoyerMailSysteme(etat.proprietaire, 'Chef de Chantier', 'Chantier a l\'arret — financement', 'Les travaux sont a l\'arret faute de financement. Il manque ' + manque + ' FR pour reprendre.').catch(() => {});
      }

      // LIVRAISON REELLE (Lots 1.5.12 / 1.5.14). Le chantier quitte son emplacement vivant -- ce
      // qui suffit a eteindre toute activite (vente, travail, BNE, approvisionnement, vol testent
      // tous ce champ) -- et son resultat est applique : le batiment existe et ses lots naissent
      // pour une construction, le plan cible devient le plan reel pour une reconfiguration.
      etat[emplacement] = ch;
      const livraison = (emplacement === 'chantierReamenagement')
        ? appliquerReconfigurationServeur(etat, jour)
        : livrerChantierServeur(etat, jour);
      if (livraison.livre) {
        resultats.livraisons++;
        resultats.lots_livres += livraison.lots;
        const rel = livraison.reliquats;
        const detailReliquats = !rel.aRestituer ? ''
          : '\n\nReliquats de chantier restitues : '
            + (rel.tresorerie > 0 ? rel.tresorerie + ' FR' : '')
            + (rel.tresorerie > 0 && rel.unites > 0 ? ' et ' : '')
            + (rel.unites > 0 ? Object.keys(rel.materiaux).map(function (m) { return rel.materiaux[m] + ' ' + m; }).join(', ') : '')
            + '. Les materiaux vous seront remis a votre prochaine connexion.';
        await envoyerMailSysteme(etat.proprietaire, 'Chef de Chantier', emplacement === 'chantierReamenagement' ? 'Travaux de reconfiguration acheves' : 'Remise des cles', (emplacement === 'chantierReamenagement'
            ? 'Les travaux sont acheves. Le nouveau decoupage est en vigueur : '
              + (livraison.lots > 0 ? livraison.lots + ' lot' + (livraison.lots > 1 ? 's' : '') + '.'
                 : 'le batiment est desormais indivis.')
              + ' Les locaux concernes redeviennent disponibles.'
            : livraison.indivis
            ? 'Les travaux sont acheves et le batiment vous est remis. Aucun decoupage n\'ayant ete depose, il vous est livre indivis : vous pourrez le diviser plus tard si vous le souhaitez.'
            : 'Les travaux sont acheves et le batiment vous est remis, divise en ' + livraison.lots
              + ' lot' + (livraison.lots > 1 ? 's' : '') + ' conformement au plan depose.') + detailReliquats).catch(() => {});
      }

      await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`,
        { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});

      // VERSEMENT DES RELIQUATS, apres l'ecriture du terrain : l'ordre de paiement doit exister en
      // base avant d'etre execute, sans quoi un echec entre les deux le ferait disparaitre. La RPC
      // relit ce qu'elle doit payer dans cette ligne meme, et pose son marqueur dans la meme
      // transaction que les paiements.
      if (livraison.livre && livraison.reliquats.aRestituer) {
        if (await restituerReliquatsServeur(row.id, etat)) resultats.reliquats_restitues++;
        else resultats.reliquats_en_attente++;
      }
      }   // fin de la boucle sur les emplacements de chantier
    }
  } catch(e) { console.error('avancerChantiersQuotidien error', e); }
  return resultats;
}

// Prelevement quotidien des mensualites de pret, cote serveur — a heure fixe, que le
// joueur ait passe l'ordre Dormir ou non (demande explicite de Fred le 5 aout 2026).
// Portee fidelement depuis l'ancienne version client (jamais appelee), avec la meme
// differenciation narrative Banque Nationale (procedure legale) / Banque Privee
// (intimidation puis expropriation violente).
// Date de mise en service du correctif P0-1. Tout pret ouvert AVANT est gele en attente
// d'arbitrage (voir le commentaire detaille dans la boucle ci-dessous).
const PRETS_GELES_AVANT = '2026-09-14';

async function preleverPretsBancairesServeur() {
  const resultats = { preleves: 0, impayes: 0, saisies: 0, gelesPourArbitrage: [] };
  try {
    // type_banque=neq.helvetia (chantier H2A, 28 aout 2026) : les prets Helvetia ont leur propre
    // contentieux dedie (traiter_prets_helvetia_quotidien, echeancier J+1 a J+9, saisie en
    // cascade puis saisie de bien) -- ce chemin legacy (penalite 10% J+2, saisie terrain directe
    // J+4) ne doit plus jamais les voir, sous peine de double traitement contradictoire.
    const prets = await sbGet('prets', 'statut=eq.en_cours&type_banque=neq.helvetia');
    if (!prets) return resultats;

    // MARQUEUR ANTI-REJEU. Ce traitement n'en avait aucun : jour_dernier_prelevement etait ecrit
    // une seule fois, a la creation du pret, et relu nulle part. Toute seconde execution du cron
    // dans la meme journee reelle (relance manuelle, reessai de la plateforme) reprelevait une
    // mensualite entiere -- et, pour un debiteur a sec, faisait avancer le contentieux de deux
    // crans d'un coup. Meme cle que la fiscalite, la solde et les loyers : jourParisISO().
    // Europe/Paris (arbitrage du 20 septembre 2026). Le client n'ecrit cette colonne
    // qu'a la CREATION du pret -- jamais comme garde quotidienne -- et jourPartageISO()
    // bascule sur Paris dans le meme deploiement : les deux restent alignes.
    const jourPrets = jourParisISO();

    for (const pret of prets) {
      // GEL DES PRETS ANTERIEURS A LA REPARATION (chantier A / P0-1, 14 septembre 2026).
      // sbUpdatePret n'existait pas dans ce fichier : AUCUNE mensualite n'a jamais ete prelevee
      // depuis la mise en service. Les prets deja ouverts a cette date ont donc accumule des
      // semaines d'echeances jamais appelees, sur un echeancier que leur emprunteur n'a pas pu
      // honorer puisqu'on ne le lui a jamais demande. Les reveiller tels quels ferait tomber le
      // contentieux -- avertissement, penalite de 10 %, ultimatum, puis SAISIE du bien a J+4 --
      // sur des joueurs qui n'ont commis aucune faute. C'est une decision qui appartient a
      // l'arbitrage, pas au correctif technique : ces lignes sont donc SIGNALEES et laissees
      // strictement intactes, ni prelevees, ni penalisees, ni marquees. Aucune donnee joueur
      // n'est modifiee. A retirer des que l'arbitrage aura tranche leur sort.
      if (pret.created_at && pret.created_at < PRETS_GELES_AVANT) {
        resultats.gelesPourArbitrage.push({
          id: pret.id, emprunteur: pret.emprunteur, montant_restant: pret.montant_restant,
          mensualite: pret.mensualite, created_at: pret.created_at
        });
        continue;
      }
      if (pret.montant_restant <= 0) {
        await sbUpdatePret(pret.id, { statut: 'remboursé' }).catch(() => {});
        continue;
      }
      if (pret.jour_dernier_prelevement === jourPrets) continue;

      // REVENDICATION DU JOUR, AVANT TOUT MOUVEMENT, ET CONDITIONNELLE
      // (chantier 6, 9 octobre 2026).
      //
      // Le marqueur etait deja pose en premier -- c'etait juste -- MAIS son echec etait avale
      // par un `.catch(() => {})`, et la mensualite partait quand meme. C'est l'inverse exact
      // de la doctrine de tacheQuotidienne(), qui relit son marqueur et RENONCE s'il n'a pas
      // pris : ici, une panne reseau d'une seconde laissait un debit sans sa garde, donc un
      // second prelevement possible la nuit suivante, sur de l'argent reel.
      //
      // Deux changements, et le second est le plus fort. Le verdict est desormais LU : une
      // panne de transport interrompt le traitement de ce pret. Et la garde du jour vit dans
      // le FILTRE de l'ecriture, ce qui en fait un compare-and-swap resolu par PostgreSQL en
      // une seule instruction : deux invocations du cron vraiment simultanees ne peuvent pas
      // revendiquer la meme journee pour le meme pret -- la premiere touche une ligne, la
      // seconde en touche ZERO et renonce. La relecture dans une requete separee, elle,
      // laisserait la fenetre entre la lecture et l'ecriture.
      //
      // `or=(... .is.null, ... .neq.jour)` et non `neq` seul : dans PostgREST, `neq` EXCLUT
      // les NULL, donc un pret dont la colonne est vide n'aurait jamais ete revendique.
      //
      // Ce qu'on echange, sciemment : si la revendication aboutit et qu'un mouvement echoue
      // ensuite, la mensualite de ce jour est perdue -- l'echeancier reprend le lendemain, et
      // le capital restant du n'a pas bouge. Perdre un appel de mensualite est sans commune
      // mesure avec le prelever deux fois.
      const cibleRevendication = `id=eq.${encodeURIComponent(pret.id)}`
        + `&or=(jour_dernier_prelevement.is.null,`
        + `jour_dernier_prelevement.neq.${encodeURIComponent(jourPrets)})`;
      const revendique = await sbUpdate('prets', cibleRevendication,
        { jour_dernier_prelevement: jourPrets }).catch(() => null);
      if (revendique === null) {
        // Panne de transport : on ne sait pas si la garde a pris. Aucun mouvement.
        resultats.marqueurs_non_poses = (resultats.marqueurs_non_poses || 0) + 1;
        continue;
      }
      if (!Array.isArray(revendique) || revendique.length !== 1) {
        // Zero ligne touchee : la journee de ce pret etait deja prise.
        resultats.deja_revendiques = (resultats.deja_revendiques || 0) + 1;
        continue;
      }

      const empRows = await sbGet('personnages', `name=eq.${encodeURIComponent(pret.emprunteur)}`);
      const emprunteur = empRows && empRows[0];
      if (!emprunteur) continue;

      const cur = 'FR';
      const aPayer = Math.min(pret.mensualite, pret.montant_restant);

      if ((emprunteur.arg || 0) >= aPayer) {
        const nouveauRestant = pret.montant_restant - aPayer;
        // arg ET liquide. arg est le capital affiche, liquide la part reellement depensable
        // (debiterFondsOrdinaires, plateau-core.js, ne sait puiser que dans liquide + compte
        // national). Debiter arg seul laissait liquide > arg : le joueur remboursait a l'ecran
        // sans jamais perdre un centime de pouvoir d'achat.
        await sbUpdate('personnages', `name=eq.${encodeURIComponent(pret.emprunteur)}`, {
          arg: emprunteur.arg - aPayer,
          liquide: Math.max(0, (emprunteur.liquide || 0) - aPayer)
        });
        await sbUpdatePret(pret.id, {
          montant_restant: nouveauRestant,
          jours_impayes: 0,
          statut: nouveauRestant <= 0 ? 'remboursé' : 'en_cours'
        });
        resultats.preleves++;
      } else {
        const nouveauxJoursImpayes = (pret.jours_impayes || 0) + 1;
        const estPrivee = pret.type_banque === 'privee';
        resultats.impayes++;

        if (!estPrivee) {
          if (nouveauxJoursImpayes === 1) {
            await envoyerMailSysteme(pret.emprunteur, 'Banque Nationale', 'Impayé', 'Avertissement : votre mensualité de prêt n\'a pas pu être prélevée.').catch(() => {});
          } else if (nouveauxJoursImpayes === 2) {
            const penalite = Math.round(pret.montant_restant * 0.10);
            await sbUpdatePret(pret.id, { montant_restant: pret.montant_restant + penalite });
            await envoyerMailSysteme(pret.emprunteur, 'Banque Nationale', 'Mise en demeure', 'Pénalité de 10% appliquée : +' + penalite + ' ' + cur + '.').catch(() => {});
          } else if (nouveauxJoursImpayes === 3) {
            await envoyerMailSysteme(pret.emprunteur, 'Banque Nationale', 'ULTIMATUM', 'Remboursez l\'intégralité de la dette sous 24h ou le bien sera saisi.').catch(() => {});
          } else if (nouveauxJoursImpayes >= 4) {
            await sbUpdatePret(pret.id, { statut: 'saisi' });
            if (pret.building_id) {
              const tRows = await sbGet('terrains_etat', `country=eq.${encodeURIComponent(pret.country)}&building_id=eq.${encodeURIComponent(pret.building_id)}`);
              const tRow = tRows && tRows[0];
              if (tRow) {
                let etat; try { etat = JSON.parse(tRow.data); } catch(e) { etat = {}; }
                etat.proprietaire = null; etat.coproprietaire = null;
                etat.enVenteParBanque = true;
                etat.prixVenteBanque = Math.round((etat.valeur_totale || 0) * 0.7);
                await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(tRow.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() });
              } else {
                // Pas un terrain (cle building_id+country) : tenter une entreprise (cle id
                // directe, table 'entreprises', pret de compromis de rachat d'entreprise du
                // 10 aout 2026). Pas de remise "prixVenteBanque" ici -- ce mecanisme n'existe
                // pas pour les entreprises, elle redevient simplement rachetable au prix normal.
                const eRows = await sbGet('entreprises', `id=eq.${encodeURIComponent(pret.building_id)}`);
                const eRow = eRows && eRows[0];
                if (eRow) {
                  const dataE = eRow.data || {};
                  dataE.proprietaire = 'PNJ';
                  delete dataE.compromis; delete dataE.compromisPar; delete dataE.acompte;
                  delete dataE.compromisAt; delete dataE.compromisExpireAt; delete dataE.pretDemande;
                  await sbUpdate('entreprises', `id=eq.${encodeURIComponent(eRow.id)}`, { data: dataE, updated_at: new Date().toISOString() });
                }
              }
            }
            await envoyerMailSysteme(pret.emprunteur, 'Banque Nationale', 'SAISIE', 'Votre bien a été saisi pour non-remboursement et sera remis en vente.').catch(() => {});
            resultats.saisies++;
            continue;
          }
        } else {
          if (nouveauxJoursImpayes >= 1 && nouveauxJoursImpayes <= 3) {
            const fraisRappel = Math.round(pret.mensualite * 0.15);
            await sbUpdate('personnages', `name=eq.${encodeURIComponent(pret.emprunteur)}`, {
              arg: Math.max(0, (emprunteur.arg || 0) - fraisRappel),
              liquide: Math.max(0, (emprunteur.liquide || 0) - fraisRappel),
              moral: Math.max(0, (emprunteur.moral || 75) - 10)
            });
            await sbUpdatePret(pret.id, { montant_restant: pret.montant_restant + fraisRappel });
            await envoyerMailSysteme(pret.emprunteur, 'Banque Privée Helvetia', 'Visite désagréable', 'Des hommes sont passés. -' + fraisRappel + ' ' + cur + ', -10 Moral.').catch(() => {});
          } else if (nouveauxJoursImpayes >= 4) {
            await sbUpdatePret(pret.id, { statut: 'saisi' });
            if (pret.building_id) {
              const tRows = await sbGet('terrains_etat', `country=eq.${encodeURIComponent(pret.country)}&building_id=eq.${encodeURIComponent(pret.building_id)}`);
              const tRow = tRows && tRows[0];
              if (tRow) {
                let etat; try { etat = JSON.parse(tRow.data); } catch(e) { etat = {}; }
                etat.proprietaire = null; etat.coproprietaire = null; etat.enVenteParBanque = false;
                await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(tRow.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() });
              } else {
                // Meme repli qu'a la saisie nationale ci-dessus : pas un terrain, tenter une
                // entreprise.
                const eRows = await sbGet('entreprises', `id=eq.${encodeURIComponent(pret.building_id)}`);
                const eRow = eRows && eRows[0];
                if (eRow) {
                  const dataE = eRow.data || {};
                  dataE.proprietaire = 'PNJ';
                  delete dataE.compromis; delete dataE.compromisPar; delete dataE.acompte;
                  delete dataE.compromisAt; delete dataE.compromisExpireAt; delete dataE.pretDemande;
                  await sbUpdate('entreprises', `id=eq.${encodeURIComponent(eRow.id)}`, { data: dataE, updated_at: new Date().toISOString() });
                }
              }
            }
            await sbUpdate('personnages', `name=eq.${encodeURIComponent(pret.emprunteur)}`, { moral: Math.max(0, (emprunteur.moral || 75) - 20) });
            await envoyerMailSysteme(pret.emprunteur, 'Banque Privée Helvetia', 'EXPROPRIATION', 'Des hommes se sont présentés et ont pris les clés. Le bien a disparu. -20 Moral.').catch(() => {});
            resultats.saisies++;
            continue;
          }
        }

        await sbUpdatePret(pret.id, { jours_impayes: nouveauxJoursImpayes });
      }
    }
  } catch(e) { console.error('preleverPretsBancairesServeur error', e); }
  return resultats;
}

// Remboursement quotidien du pret de preemption d'Etat (chantier "refonte des ordres",
// Doctrine V2, droit de preemption du Ministre des Finances). Contrairement aux prets joueurs
// ci-dessus, pas d'escalade/saisie en cas d'impaye -- l'Etat ne peut pas se saisir lui-meme :
// la mensualite est simplement reportee a la nuit suivante si la caisse du Ministere des
// Finances est insuffisante, sans penalite.
async function preleverPreemptionsServeur() {
  const resultats = { payes: 0, reportes: 0, soldes: 0 };
  // FAIL-CLOSED sur l'identite serveur : la RPC n'est executable que par service_role. Sans la
  // variable d'environnement, on n'envoie meme pas la requete -- elle finirait en 401, mais on
  // trace la cause exacte plutot qu'un compteur d'erreurs opaque. Aucun argent ne bouge.
  if (!SUPABASE_SERVICE_ROLE) {
    console.error('preleverPreemptionsServeur : SUPABASE_SERVICE_ROLE_KEY absente, aucune mensualite prelevee');
    resultats.erreurs = 1;
    return resultats;
  }
  try {
    // TOUT LE TRAITEMENT EST DESCENDU DANS UNE RPC (chantier 6, 9 octobre 2026).
    //
    // Cette fonction faisait QUATRE allers-retours par pays : lire le budget, lire la caisse,
    // ECRIRE la caisse, ECRIRE le budget. Les deux ecritures etaient deux transactions : une
    // interruption entre elles debitait la caisse du Ministere des Finances SANS reduire la
    // dette de la preemption -- et le marqueur de tacheQuotidienne, deja pose, interdisait la
    // reprise. L'argent disparaissait sans que personne ne s'en plaigne, parce qu'aucun joueur
    // ne reclame une dette qui ne baisse pas assez vite.
    //
    // preemption_mensualite_prelever fait les deux dans UNE transaction, ouverte par une
    // revendication d'acte nocturne -- actes_nocturnes(pays, mecanisme, sujet, jour), dont la
    // cle primaire rend le rejeu impossible par construction. Et la revendication n'etant pas
    // appelable depuis le reseau, elle ne PEUT PAS se retrouver dans un autre aller-retour que
    // l'effet : c'est la garantie que ce fichier ne pouvait pas donner.
    //
    // Il ne reste ici que la boucle sur les empires et la lecture des verdicts.
    //
    // LES EMPIRES VIENNENT DU REFERENTIEL (chantier 4G), plus d'une liste recopiee a la main --
    // le commentaire d'un de ces quatre sites avouait d'ailleurs « meme liste de pays codee en dur
    // que le reste de ce cron ». Un cinquieme empire declare dans VILLES serait traite sans qu'on y
    // pense, et un empire retire cesserait de l'etre. La RPC est fail-closed : elle ne declenche
    // aucune economie chez un empire qui n'en a pas.
    for (const pays of Object.keys(VILLES_SERVEUR)) {
      const rows = await sbRpc('preemption_mensualite_prelever', { p_pays: pays }, HEADERS_SERVICE);
      // sbRpc rend null sur echec HTTP. Une exception PL/pgSQL signifie que la transaction a ete
      // ANNULEE : ni debit, ni reduction de dette, ni journee revendiquee -- rien a reprendre.
      if (rows === null) { resultats.erreurs = (resultats.erreurs || 0) + 1; continue; }
      const v = Array.isArray(rows) ? rows[0] : rows;
      if (!v || v.ok !== true) {
        // Verdict de refus explicite (preemption illisible, parametres) : signale, jamais avale.
        console.error('preleverPreemptionsServeur : refus pour ' + pays, v && v.raison);
        resultats.refus = (resultats.refus || 0) + 1;
        continue;
      }
      if (v.action === 'preleve')      resultats.payes++;
      else if (v.action === 'solde') { resultats.payes++; resultats.soldes++; }
      else if (v.action === 'reporte') resultats.reportes++;
      else if (v.action === 'deja_traite') resultats.deja_traites = (resultats.deja_traites || 0) + 1;
    }
  } catch(e) { console.error('preleverPreemptionsServeur error', e); }
  return resultats;
}

// Fin automatique d'un blocus syndical si aucun des deux leaders (Secretaire General ou
// Adjoint) ne l'a renouvele depuis plus de 25h (marge de securite sur le cycle de 24h) —
// evite qu'un blocus persiste indefiniment sans intervention. Concerne tous les bâtiments
// (pas seulement les terrains), via la table generique batiments_etat.
// Effet quotidien d'un blocus actif : malus sur la popularite du maire de la ville
// concernee, proportionnel a l'intensite du blocus. NOTE : le malus prevu sur les indices
// de ville n'est pas encore possible — INDICES_VILLES (cote client, plateau-divers.js) n'a
// aucune persistance serveur ; c'est le futur chantier dedie deja identifie le 4 aout 2026.
async function appliquerEffetsBlocusActifs() {
  const resultats = { appliques: 0 };
  try {
    const batiments = await sbGet('batiments_etat', '');
    if (!batiments) return resultats;

    for (const row of batiments) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      if (!etat.blocus) continue;

      const malusPop = Math.max(1, Math.round((etat.blocus.intensite || 40) / 15));
      const maireRows = await sbGet('personnages', `country=eq.${encodeURIComponent(row.country)}&poste->>id=like.maire*`);
      const maire = maireRows && maireRows[0];
      if (maire) {
        // Correctif du 25 aout 2026 (audit signale au rapport v73) : le POP reel est stocke
        // dans personnages.resources.pop (voir sbSavePersonnage, supabase.js : resources:
        // {inf,pop,dis}), jamais dans une colonne racine 'pop' -- ce malus de blocus ecrivait
        // (et lisait) le mauvais champ depuis toujours, sans jamais atteindre le POP reellement
        // affiche au joueur. Meme precedent deja applique/verifie dans
        // traiterCandidaturesPostesExpirees (sanction POP/2 du lot postes nommes) : lecture/
        // ecriture via l'objet resources complet, jamais un champ racine isole. Aucun autre
        // comportement du blocus modifie (malusPop, requete du maire, comptage inchanges).
        const popActuelle = (maire.resources && maire.resources.pop) || 50;
        const nouvellePop = Math.max(0, popActuelle - malusPop);
        const resourcesMaj = { ...(maire.resources || {}), pop: nouvellePop };
        await sbUpdate('personnages', `name=eq.${encodeURIComponent(maire.name)}`, { resources: resourcesMaj }).catch(() => {});
        resultats.appliques++;
      }
    }
  } catch(e) { console.error('appliquerEffetsBlocusActifs error', e); }
  return resultats;
}

// =====================
// GREVES, GREVE GENERALE ET CONTRE-POUVOIRS -- effets quotidiens (audit valide + implementation,
// 3 septembre 2026). Duplique cote serveur (contexte isole, memes constantes que data.js/
// plateau-organisations-quetes.js -- aucun acces possible aux fichiers client depuis ce cron).
// =====================
function palierGreveOrdinaireServeur(nbMembres) {
  return GREVE_PALIERS_SERVEUR.find(p => nbMembres >= p.min && nbMembres <= p.max) || GREVE_PALIERS_SERVEUR[0];
}
// GREVE_ENTREPRISES_CIBLABLES_SERVEUR est importee du module genere : data.js la restreint
// aux 3 transformateurs de Republia pour cette premiere version (entrepots et port hors
// perimetre), et c'est data.js qui en decide desormais, pas une copie locale.
//
// PM + 6 ministeres, jamais le President (meme convention que RUMEUR_POSTES_GOUVERNEMENT,
// plateau-pnj.js -- "immunite totale deja geree ailleurs, hors perimetre ici").
const GREVE_POSTES_GOUVERNEMENT_SERVEUR = ['pm', 'min_int', 'min_fin', 'min_just', 'min_def', 'min_info', 'min_ae'];

function niveauGreveGeneraleServeur(niveau) {
  return GREVE_GENERALE_NIVEAUX_SERVEUR.find(n => n.niveau === niveau) || GREVE_GENERALE_NIVEAUX_SERVEUR[0];
}
const GREVE_GENERALE_ADHERENTS_MIN_SERVEUR = 100;
// GREVE_VILLES_REPUBLIA_SERVEUR EST SUPPRIMEE (chantier 4G, 7 octobre 2026). C'etait la liste
// des vraies villes de Republia, recopiee a la main. Son unique lecteur demande desormais
// villesDeServeur(pays), qui lit le referentiel genere : le meme resultat pour Republia, et la
// structure prete pour les trois autres empires sans qu'aucun parametre soit invente.

// organisations.data est un TEXT column (JSON.stringify), duplique de sbLoadOrganisations/
// sbSaveOrganisation (supabase.js) -- contexte serveur isole, memes raisons que sbGetBatimentEtat.
async function sbLoadOrganisationsServeur() {
  const rows = await sbGet('organisations', 'select=*');
  if (!rows) return [];
  return rows.map(r => { try { return JSON.parse(r.data); } catch(e) { return null; } }).filter(Boolean);
}
// REND SON VERDICT (chantier 6, 7 octobre 2026). Elle avalait son echec, ce qui empechait
// l'appelant de savoir si un marqueur d'idempotence avait bien ete enregistre.
async function sbSaveOrganisationServeur(orga) {
  return await sbUpdate('organisations', `id=eq.${encodeURIComponent(orga.id)}`,
                        { data: JSON.stringify(orga) });
}

async function ajusterPopJoueurServeur(nom, delta) {
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nom)}&select=resources`);
  const resources = rows?.[0]?.resources || { inf: 0, pop: 50, dis: 50 };
  const nouveauPop = Math.max(0, Math.min(100, (resources.pop ?? 50) + delta));
  await sbUpdate('personnages', `name=eq.${encodeURIComponent(nom)}`, { resources: { ...resources, pop: nouveauPop } }).catch(() => {});
}

// PM+6 ministres (Gouvernement) vs tout autre titulaire de poste (Autres elus) -- une seule
// requete par pays, jamais de double comptage (un titulaire du gouvernement ne peut jamais
// apparaitre aussi dans "autres elus", voir la branche if/else ci-dessous).
async function resoudrePostesPaysServeur(pays) {
  const joueurs = await sbGet('personnages', `country=eq.${encodeURIComponent(pays)}&select=name,poste`) || [];
  const gouvernement = [], autresElus = [];
  for (const j of joueurs) {
    let poste = j.poste;
    if (typeof poste === 'string') { try { poste = JSON.parse(poste); } catch(e) { poste = null; } }
    if (!poste || !poste.id) continue;
    if (GREVE_POSTES_GOUVERNEMENT_SERVEUR.includes(poste.id)) gouvernement.push(j.name);
    else autresElus.push(j.name);
  }
  return { gouvernement, autresElus };
}

// Republia : vraies valeurs persistees par ville (indices_villes, meme table que le reste du
// jeu). Les 3 autres empires : AUCUNE persistance serveur n'existe aujourd'hui pour leurs
// indices nationaux (INDICES_NATIONAUX est une constante EN MEMOIRE COTE CLIENT UNIQUEMENT,
// jamais synchronisee en base -- ecart d'architecture identifie et sciemment non traite dans ce
// chantier, decision de Fred le 3 septembre 2026 : "on finalise Republia", chantier dedie a
// venir avant/durant la finalisation des 3 autres empires). "floor" parametrable (-10 pour le
// Social d'une greve, jamais le plancher 0 habituel des autres indices).
async function modifierIndiceVilleServeur(pays, ville, cle, delta, floor) {
  if (pays !== 'republic') return;
  const plancher = floor != null ? floor : 0;
  const id = pays + '_' + ville;
  const rows = await sbGet('indices_villes', `id=eq.${encodeURIComponent(id)}`);
  const row = rows && rows[0];
  const data = row ? row.data : { isn: 30, ie: 50, social: 45, piete: 40, moral: 50 };
  data[cle] = Math.max(plancher, Math.min(100, (data[cle] ?? 50) + delta));
  if (row) await sbUpdate('indices_villes', `id=eq.${encodeURIComponent(id)}`, { data }).catch(() => {});
  else await sbInsert('indices_villes', { id, data }).catch(() => {});
}
async function appliquerDeltaSocialPaysServeur(pays, delta, floor) {
  if (pays !== 'republic') return; // voir modifierIndiceVilleServeur
  for (const ville of villesDeServeur(pays)) {
    await modifierIndiceVilleServeur(pays, ville, 'social', delta, floor);
  }
}

// Effets QUOTIDIENS de la greve ORDINAIRE (cahier des charges §2) : paliers par nombre de
// membres du syndicat greviste, usure INF a partir du 15e jour reel, coefficient d'activite
// economique pour la cible "entreprise" (ecrit sur batiments_etat, lu par produireUneChaine ---
// DOIT s'executer AVANT produireTransformateursQuotidien dans le handler principal, voir plus
// bas). Idempotence par date (derniereApplicationJour) : protege contre un rejeu du cron le meme
// jour, aucun verrou equivalent n'existant par ailleurs pour la production economique generale.
async function appliquerEffetsGrevesOrdinaires() {
  const resultats = { syndicatsTraites: 0 };
  // Cle CRON-SEULEMENT (derniereApplicationJour / derniere_application_jour) :
  // Europe/Paris (arbitrage du 20/09/2026). Le client n'ecrit que la valeur null.
  const aujourdHui = jourParisISO();
  const coefficientsEntreprises = {};
  try {
    const organisations = await sbLoadOrganisationsServeur();

    for (const orga of organisations) {
      if (orga.type !== 'syndicale' || !orga.greve?.actif) continue;
      if (orga.greve.derniereApplicationJour === aujourdHui) continue;

      const nbMembres = orga.membres?.length || 0;
      const palier = palierGreveOrdinaireServeur(nbMembres);
      const type = orga.greve.type;
      const cibleValue = orga.greve.cibleValue;

      // LE MARQUEUR AVANT L'EFFET (chantier 6, 7 octobre 2026).
      //
      // Il etait pose APRES : la POP de tous les elus et le Social du pays etaient debites,
      // PUIS derniereApplicationJour etait ecrit par un sbUpdate dont l'echec etait avale. Si
      // cette ecriture echouait, la nuit suivante redebitait tout le monde. C'est l'inverse de
      // la doctrine deja appliquee par tacheQuotidienne(), par les prets bancaires et par la
      // redistribution fiscale, qui posent tous leur marqueur d'abord et renoncent s'il n'a pas
      // pris.
      //
      // Ce qu'on echange : si la pose reussit et qu'un effet echoue ensuite, la greve de ce jour
      // est perdue. Perdre une journee de malus de POP est sans commune mesure avec la rejouer
      // indefiniment sur les memes personnes.
      orga.greve.joursActifs = (orga.greve.joursActifs || 0) + 1;
      orga.greve.derniereApplicationJour = aujourdHui;
      if (orga.greve.joursActifs >= GREVE_USURE_JOUR_DEBUT_SERVEUR) {
        const infUsure = Number.isFinite(orga.influence) ? orga.influence : 50;
        orga.influence = Math.max(0, infUsure - GREVE_USURE_INF_JOUR_SERVEUR);
      }
      if (!(await sbSaveOrganisationServeur(orga))) {
        resultats.marqueurs_non_poses = (resultats.marqueurs_non_poses || 0) + 1;
        continue;   // aucun effet applique : rien a rejouer, rien a reprendre
      }

      if (type === 'pj') {
        await ajusterPopJoueurServeur(cibleValue, -palier.pop);
      } else if (type === 'gouvernement') {
        const { gouvernement } = await resoudrePostesPaysServeur(cibleValue);
        for (const nom of gouvernement) await ajusterPopJoueurServeur(nom, -palier.pop);
        await appliquerDeltaSocialPaysServeur(cibleValue, -palier.social, GREVE_SOCIAL_PLANCHER_SERVEUR);
      } else if (type === 'entreprise') {
        const coeff = Math.max(GREVE_ACTIVITE_PLANCHER_SERVEUR, 1 - palier.entrepriseReduction);
        coefficientsEntreprises[cibleValue] = Math.min(coeff, coefficientsEntreprises[cibleValue] ?? 1);
      } else if (type === 'organisation') {
        const orgaCible = organisations.find(o => o.id === cibleValue);
        if (orgaCible) {
          const infActuelle = Number.isFinite(orgaCible.influence) ? orgaCible.influence : 50;
          orgaCible.influence = Math.max(0, Math.min(100, infActuelle - palier.orgaInf));
          await sbSaveOrganisationServeur(orgaCible);
        }
      } else if (type === 'pays') {
        // "tous les elus" (§2) : gouvernement + tous les autres titulaires de poste, plus large
        // que la seule cible "Gouvernement" ci-dessus.
        const { gouvernement, autresElus } = await resoudrePostesPaysServeur(cibleValue);
        for (const nom of [...gouvernement, ...autresElus]) await ajusterPopJoueurServeur(nom, -palier.pop);
        await appliquerDeltaSocialPaysServeur(cibleValue, -palier.social, GREVE_SOCIAL_PLANCHER_SERVEUR);
      }

      // Le marqueur, les joursActifs et l'usure d'influence sont deja enregistres plus haut.
      resultats.syndicatsTraites++;
    }

    // Coefficient d'activite des entreprises ciblees (le PIRE cas si plusieurs greves visent la
    // meme entreprise le meme jour, jamais une composition) -- efface un coefficient residuel
    // d'une greve d'hier deja terminee pour toute entreprise plus ciblee aujourd'hui.
    for (const entrepriseId of Object.keys(GREVE_ENTREPRISES_CIBLABLES_SERVEUR)) {
      const cfg = GREVE_ENTREPRISES_CIBLABLES_SERVEUR[entrepriseId];
      const coeff = coefficientsEntreprises[entrepriseId];
      if (coeff !== undefined) {
        await sbSetBatimentEtat(cfg.country, cfg.city, entrepriseId, { greve: { coefficient: coeff, appliqueLe: aujourdHui } }).catch(() => {});
      } else {
        await sbSetBatimentEtat(cfg.country, cfg.city, entrepriseId, { greve: undefined }).catch(() => {});
      }
    }
  } catch (e) { console.error('appliquerEffetsGrevesOrdinaires error', e); }
  return resultats;
}

// Effets QUOTIDIENS de la greve GENERALE (cahier des charges §6/§7) : paliers de puissance +
// retournement d'opinion (-5 INF/jour/syndicat participant a partir du seuil propre a chaque
// niveau) -- le retournement NE diminue JAMAIS les effets eux-memes (les deux continuent en
// parallele, cf. §7 "IMPORTANT"). Idempotence par date (derniere_application_jour), posee
// AVANT les effets et par ECRITURE CONDITIONNELLE -- voir le bloc de revendication ci-dessous.
//
// CE COMMENTAIRE A MENTI PENDANT DEUX JOURS, et c'est la raison du correctif du 9 octobre 2026.
// Il annoncait « meme doctrine que la greve ordinaire ci-dessus ». C'etait vrai jusqu'au
// 7 octobre, date a laquelle la greve ordinaire a recu son marqueur-avant-effet -- et pas
// celle-ci. La greve generale ecrivait donc encore son marqueur en DERNIER, dans un
// `.catch(() => {})`, apres avoir debite la POP de tout un gouvernement. Un commentaire qui
// affirme une protection absente est pire qu'un code sans commentaire : il eteint la question.
async function appliquerEffetsGreveGenerale() {
  const resultats = { traitees: 0 };
  // Cle CRON-SEULEMENT (derniereApplicationJour / derniere_application_jour) :
  // Europe/Paris (arbitrage du 20/09/2026). Le client n'ecrit que la valeur null.
  const aujourdHui = jourParisISO();
  try {
    const greves = await sbGet('greves_generales', 'statut=eq.active') || [];
    for (const gg of greves) {
      if (gg.derniere_application_jour === aujourdHui) continue;
      const niveau = niveauGreveGeneraleServeur(gg.puissance_niveau || 1);
      const participants = gg.participants || [];
      const actifs = participants.filter(p => p.statut === 'accepte');
      if (actifs.length === 0) continue;

      const joursDepuisEntreeVigueur = (gg.jours_actifs || 0) + 1;

      // REVENDICATION DU JOUR, AVANT TOUT EFFET, ET PAR ECRITURE CONDITIONNELLE
      // (chantier 6, 9 octobre 2026).
      //
      // Le marqueur etait pose EN DERNIER, par un sbUpdate dont l'echec etait avale. Entre-temps
      // la POP de tout le gouvernement et celle des autres elus etaient debitees, le Social du
      // pays reduit, les coefficients economiques ecrits et -5 INF retires a chaque syndicat
      // participant. Si cette derniere ecriture mordait, la nuit suivante recommencait tout --
      // sur les memes personnes, et sans que rien ne le signale.
      //
      // Le filtre ne vise pas seulement la ligne : il exige que le jour n'y soit PAS DEJA. C'est
      // un compare-and-swap, et PostgreSQL le resout en une seule instruction. Deux invocations
      // du cron vraiment simultanees ne peuvent donc pas revendiquer la meme journee : la
      // premiere touche une ligne, la seconde en touche ZERO et renonce. Un marqueur relu dans
      // une requete separee n'offre pas cette garantie -- il laisse la fenetre entre la lecture
      // et l'ecriture. Meme motif que l'ecriture conditionnelle du solde d'un personnage.
      //
      // `or=(... .is.null, ... .neq.jour)` et non `neq` seul : dans PostgREST, `neq` EXCLUT les
      // NULL, donc une greve qui n'a jamais tourne n'aurait jamais ete revendiquee.
      //
      // CE QU'ON ECHANGE, sciemment, et c'est la doctrine de la greve ordinaire et de
      // tacheQuotidienne : si la revendication aboutit et qu'un effet echoue ensuite, la greve
      // de ce jour est perdue. Perdre une journee de malus est sans commune mesure avec la
      // rejouer indefiniment sur les memes joueurs.
      const cibleRevendication = `id=eq.${encodeURIComponent(gg.id)}`
        + `&or=(derniere_application_jour.is.null,`
        + `derniere_application_jour.neq.${encodeURIComponent(aujourdHui)})`;
      const revendique = await sbUpdate('greves_generales', cibleRevendication, {
        jours_actifs: joursDepuisEntreeVigueur,
        derniere_application_jour: aujourdHui
      }).catch(() => null);
      if (revendique === null) {
        // Panne de transport : on ne sait pas si le marqueur a pris. Aucun effet.
        resultats.marqueurs_non_poses = (resultats.marqueurs_non_poses || 0) + 1;
        continue;
      }
      if (!Array.isArray(revendique) || revendique.length !== 1) {
        // Zero ligne touchee : la journee etait deja revendiquee. Rien a faire, et surtout
        // rien a refaire.
        resultats.deja_revendiquees = (resultats.deja_revendiquees || 0) + 1;
        continue;
      }

      const { gouvernement, autresElus } = await resoudrePostesPaysServeur(gg.country);
      for (const nom of gouvernement) await ajusterPopJoueurServeur(nom, -niveau.gouvernementPop);
      for (const nom of autresElus) await ajusterPopJoueurServeur(nom, -niveau.autresElusPop);
      await appliquerDeltaSocialPaysServeur(gg.country, -niveau.social, GREVE_SOCIAL_PLANCHER_SERVEUR);
      // Reduction economique nationale : meme doctrine que l'entreprise ciblee par une greve
      // ordinaire (coefficient applique sur la valeur NOMINALE de reference, jamais compose) --
      // ecrite sur les 3 transformateurs de Republia, seule infrastructure economique server-side
      // existante aujourd'hui a l'echelle nationale (voir audit -- les 3 autres empires n'ont pas
      // d'equivalent, meme limitation que le Social ci-dessus).
      if (gg.country === 'republic') {
        const coeffEco = Math.max(GREVE_ACTIVITE_PLANCHER_SERVEUR, 1 - niveau.economieReduction);
        for (const entrepriseId of Object.keys(GREVE_ENTREPRISES_CIBLABLES_SERVEUR)) {
          const cfg = GREVE_ENTREPRISES_CIBLABLES_SERVEUR[entrepriseId];
          const etat = await sbGetBatimentEtat(cfg.country, cfg.city, entrepriseId).catch(() => ({}));
          const coeffExistant = etat.greve?.coefficient;
          const coeffFinal = coeffExistant !== undefined ? Math.min(coeffExistant, coeffEco) : coeffEco;
          await sbSetBatimentEtat(cfg.country, cfg.city, entrepriseId, { greve: { coefficient: coeffFinal, appliqueLe: aujourdHui } }).catch(() => {});
        }
      }

      let retournementDeclenche = false;
      if (joursDepuisEntreeVigueur >= niveau.retournementJour) {
        retournementDeclenche = true;
        const toutesOrgas = await sbLoadOrganisationsServeur();
        for (const p of actifs) {
          const orgaLive = toutesOrgas.find(o => o.id === p.orgaId);
          if (!orgaLive) continue;
          const infActuelle = Number.isFinite(orgaLive.influence) ? orgaLive.influence : 50;
          orgaLive.influence = Math.max(0, infActuelle - GREVE_GENERALE_RETOURNEMENT_INF_JOUR_SERVEUR);
          await sbSaveOrganisationServeur(orgaLive);
        }
      }

      // Le marqueur et le compteur de jours sont deja ecrits : ils ont ete POSES AVANT les
      // effets, par la revendication conditionnelle en tete de boucle. Il n'y a plus rien a
      // ecrire ici -- et c'etait precisement l'ecriture dont l'echec faisait tout rejouer.
      resultats.traitees++;
      if (retournementDeclenche) resultats.retournements = (resultats.retournements || 0) + 1;
    }
  } catch (e) { console.error('appliquerEffetsGreveGenerale error', e); }
  return resultats;
}

// RESSOURCES_ECONOMIE_SERVEUR n'est plus recopiee ici : elle est GENEREE depuis
// RESSOURCES_ECONOMIE (data.js), projetee sur les quatre champs dont ce fichier se sert
// (plafond, prixBase, prixAchatFournisseur, source). Il n'y a donc plus rien a repercuter
// a la main quand data.js change -- il faut rejouer le generateur.
//
// ATTENTION, LE PIEGE EST AILLEURS ET IL EST TOUJOURS LA : api/_journal-collecte.js possede
// SA PROPRE table RESSOURCES_ECONOMIE, dont le champ 'prixBase' contient en realite
// prixAchatFournisseur -- la moitie de la vraie valeur, sur toutes les entrees, et textile
// manquant. Elle n'est pas reutilisee ici pour cette raison, et elle n'a PAS ete corrigee :
// c'est une divergence metier declaree (outils/baseline/referentiels.json), fermee par un
// lot a part, parce que la corriger doublerait des prix publies depuis des semaines.

// Prix de vente directe d'une usine, cote serveur -- MEME FORMULE que getPrixRessource() (client,
// data.js:6741) : stock eleve = prix bas, stock faible = prix haut, +/-40% autour de prixBase a
// 50% de remplissage. Necessaire ici (achat inter-usines automatique) car ce calcul devait
// jusqu'ici toujours etre fait cote client (achat PJ uniquement) -- jamais execute par le cron.
function getPrixRessourceServeur(cle, quantiteEnStock) {
  const res = RESSOURCES_ECONOMIE_SERVEUR[cle];
  if (!res || res.prixBase == null) return 0;
  const tauxRemplissage = Math.max(0, Math.min(1, quantiteEnStock / res.plafond));
  const variation = (0.5 - tauxRemplissage) * 0.8;
  return Math.round(res.prixBase * (1 + variation) * 100) / 100;
}

const ENTREPOTS_VILLES = [
  { buildingId: 'entrepot-logistique-luthecia', city: 'capitale' },
  { buildingId: 'entrepot-logistique-psm',      city: 'ville_a' },
  { buildingId: 'entrepot-logistique-montrouge', city: 'ville_b' }
];

// =====================================================================
// CAPACITE ET STOCKS CIBLES DES ENTREPOTS (14 septembre 2026)
// =====================================================================
// La capacite d'un entrepot est de 5 000 unites PAR RESSOURCE. Elle est volontairement
// distincte de RESSOURCES_ECONOMIE_SERVEUR[x].plafond, qui reste la capacite des USINES, le
// denominateur du prix dynamique de la vente directe, et surtout la base du contrat
// d'exportation (plafond x equivalentVilles = 225 cereales / 125 viande). Confondre les deux
// ferait passer l'export a 7 500 et 5 000 unites par nuit. Miroir de capacite_entrepot() en base.
const CAPACITE_ENTREPOT_PAR_RESSOURCE = 5000;

// DESIDERATAS PAR DEFAUT (entrepot dirige par un PNJ).
// Ces valeurs ne sont pas choisies : ce sont EXACTEMENT les anciens plafonds de chaque
// ressource, c'est-a-dire le niveau que la livraison automatique visait deja depuis toujours.
// Les reprendre tels quels garantit qu'un entrepot sans directeur PJ se comporte apres ce lot
// exactement comme avant -- aucun equilibre economique n'est deplace par le passage a 5 000.
// Voir le rapport pour les flux observes et la couverture reelle qu'ils offrent.
const DESIDERATA_PNJ_DEFAUT = Object.fromEntries(
  Object.entries(RESSOURCES_ECONOMIE_SERVEUR).map(([cle, r]) => [cle, r.plafond]));

// Desideratas REELLEMENT applicables a un entrepot cette nuit.
// Un directeur PJ pose ses cibles dans entrepot.desiderata, signees de son nom. Des qu'il n'est
// plus en poste, elles sont abandonnees et les valeurs PNJ reprennent automatiquement : c'est
// verifie ici, a chaque passage, plutot que par un hook de depart qu'un revocation brutale ou
// une suppression de personnage pourrait contourner.
function desiderataEffectifs(entrepot, directeursEnPoste, city) {
  const pose = entrepot && entrepot.desiderata;
  const par = entrepot && entrepot.desiderataPar;
  if (!pose || !par) return DESIDERATA_PNJ_DEFAUT;
  if (directeursEnPoste[city] !== par) return DESIDERATA_PNJ_DEFAUT;   // plus en poste
  return Object.assign({}, DESIDERATA_PNJ_DEFAUT, pose);
}

const VOLUME_TOTAL_JOUR = 800;
const NB_LIVRAISONS_JOUR = 6;

// =====================
// LOGISTIQUE PORTUAIRE NATIONALE (lot du 25 aout 2026, Port Industriel de PSM)
// =====================
// Principe impose (clarification explicite avant codage) : ne PAS recalibrer l'abondance des
// matieres premieres. livrerEntrepotsQuotidien() generait deja, chaque jour, un volume aleatoire
// de petrole/produits_exotiques directement dans CHACUN des 3 entrepots (tirage independant par
// ville, cf. boucle ENTREPOTS_VILLES plus bas). Ce lot ne change RIEN a ce calcul pour ces deux
// ressources (meme RNG, memes constantes VOLUME_TOTAL_JOUR/NB_LIVRAISONS_JOUR) : il redirige
// simplement une partie de ce qui etait deja genere vers un stock portuaire intermediaire
// (etat.port.stock, batiment 'port-sainte-marie'), puis le redistribue selon les pourcentages
// du Commandant (defaut 1/3-1/3-1/3) au lieu de le crediter directement a l'entrepot d'origine
// du tirage.
//
// Origines fixes (arbitrage valide, non modifiable par un PJ dans ce lot -- seuls les futurs
// Commandants des autres empires, non developpes ici, pourront un jour regler leurs propres
// exports) :
//  - petrole (BRUT, pas carburant) : 100% transite desormais par le port (2/3 Al-Khalija +
//    1/3 Sovarka). La redirection existante vers la raffinerie de Montrouge (USINE_LOCALE_PAR_
//    VILLE.ville_b) reste totalement inchangee et intervient AVANT ce reroutage (le port ne
//    recoit que ce qui restait apres cette redirection, exactement comme l'entrepot local
//    recevait ce reliquat avant ce lot).
//  - produits_exotiques : 100% transite desormais par le port (El Estado = pays 'narco').
// Ces fractions ne modifient QUE l'endroit ou la quantite deja calculee atterrit (port vs
// entrepot local), jamais sa valeur.
const ORIGINE_IMPORTS_PORT = {
  petrole: { khalija: 2 / 3, soviet: 1 / 3 },
  produits_exotiques: { narco: 1 }
};
const RESSOURCES_REROUTEES_PORT = Object.keys(ORIGINE_IMPORTS_PORT); // ['petrole','produits_exotiques']
const BUILDING_ID_PORT_PSM = 'port-sainte-marie';
const VILLE_ID_PORT_PSM = 'ville_a';
const REPARTITION_PORT_DEFAUT = { capitale: 100 / 3, ville_a: 100 / 3, ville_b: 100 / 3 };

// =====================
// PRODUCTION NATIONALE DE BOIS — SCIERIE GUY TAREMBOIS (lot du 25 aout 2026, correctif dedie)
// =====================
// Remplace l'ancien ORIGINE_IMPORTS_PORT.bois (qui coupait artificiellement en deux un UNIQUE
// tirage aleatoire partage avec les 10 autres ressources livrees, sans aucun volume garanti --
// voir l'audit dedie) par deux flux reels, deterministes et independants du RNG de
// livrerEntrepotsQuotidien() : le bois est desormais totalement exclu du tirage generique
// (ressourcesLivrables ci-dessous), jamais tire, jamais credite directement a un entrepot
// d'origine. Convention de reference (parametres d'equilibrage initiaux, decision de Fred,
// volontairement isoles en constantes nommees pour rester faciles a ajuster) :
//  - 1 ville = BOIS_UNITES_PAR_VILLE_JOUR bois/jour ;
//  - Scierie Guy Tarembois (production interieure republicaine, PSM) = 1,5 ville/jour ;
//  - Importations Sovarka = 1,5 ville/jour.
// Les deux flux sont credites SANS cout entrepot (dotation publique/import national, meme
// doctrine que petrole/produits_exotiques ci-dessus), sommes dans le meme accumulateur
// portAccumulation.bois que le reste de ce lot portuaire, puis distribues aux 3 entrepots via
// EXACTEMENT le meme mecanisme deja existant et deja eprouve (repartirSelonPourcentages/Hamilton,
// plafond par entrepot, reliquat conserve dans port.stock.bois si un entrepot est plein) --
// aucun deuxieme moteur de redistribution, voir le bloc "Credit + distribution du stock
// portuaire" plus bas dans livrerEntrepotsQuotidien(), inchange pour le bois comme pour le reste.
const BOIS_UNITES_PAR_VILLE_JOUR = 100;
const BOIS_SCIERIE_JOUR = Math.round(1.5 * BOIS_UNITES_PAR_VILLE_JOUR); // 150 -- Scierie Guy Tarembois (PSM)
const BOIS_SOVARKA_JOUR = Math.round(1.5 * BOIS_UNITES_PAR_VILLE_JOUR); // 150 -- importations Sovarka
const NB_ARRIVAGES_CONSERVES = 10; // historique court pour le Commandant/Marcel Ancre, pas de croissance illimitee

// Exportations validees (arbitrage) : la reference "1 ville" reutilise le plafond deja existant
// de chaque ressource (RESSOURCES_ECONOMIE_SERVEUR[x].plafond) -- pas un chiffre invente, c'est
// la seule notion de "capacite d'une ville" deja presente dans l'architecture actuelle
// (identique pour les 3 villes). cereales.plafond=150 -> 1.5 ville = 225 ; viande.plafond=125 ->
// 1 ville = 125. Destination fixe (Al-Khalija) pour ce lot uniquement.
const EXPORTATIONS_PORT = {
  cereales: { equivalentVilles: 1.5, destination: 'khalija' },
  viande:   { equivalentVilles: 1,   destination: 'khalija' }
};

// Arrivage de peche quotidien propre a la Criee de PSM (arbitrage valide le 25 aout 2026, §3-5
// du lot Criee/poisson) : totalement independant de l'approvisionnement en poisson des 3
// entrepots (livrerEntrepotsQuotidien, inchange), n'a PAS d'origine etrangere -- ne touche jamais
// ORIGINE_IMPORTS_PORT/RESSOURCES_REROUTEES_PORT ci-dessus, n'entre jamais dans port.stock. Va
// directement dans port.criee.stock.poisson, plafonne (invendus persistants d'un jour sur
// l'autre), jamais de report/dette si l'arrivage depasse la place restante.
const ARRIVAGE_POISSON_CRIEE_MIN = 40;
const ARRIVAGE_POISSON_CRIEE_MAX = 80; // moyenne cible 60 (uniforme sur [40,80])

// Repartit un montant entre les 3 villes selon des pourcentages arbitraires, methode du plus
// fort reste (Hamilton) -- meme algorithme deja utilise et valide pour la repartition fiscale
// nationale (distribuerMontantParVilleAuProrataFiscal, plateau-justice-economie.js) : aucun FR/
// unite perdu par arrondi, deterministe, pas de nouvelle primitive.
function repartirSelonPourcentages(montantTotal, pourcentages, villes) {
  if (montantTotal <= 0) return villes.reduce((acc, v) => { acc[v] = 0; return acc; }, {});
  const parts = villes.map(v => montantTotal * ((pourcentages[v] || 0) / 100));
  const planchers = parts.map(p => Math.floor(p));
  let reliquat = montantTotal - planchers.reduce((s, p) => s + p, 0);
  const ordre = parts
    .map((p, i) => ({ i, frac: p - planchers[i] }))
    .sort((a, b) => b.frac - a.frac || a.i - b.i);
  const montants = [...planchers];
  for (let k = 0; k < ordre.length && reliquat > 0; k++) { montants[ordre[k].i]++; reliquat--; }
  const resultat = {};
  villes.forEach((v, i) => { resultat[v] = montants[i]; });
  return resultat;
}

// Simule les 6 livraisons quotidiennes d'un entrepot en une seule passe (limite du plan
// Vercel Hobby : un seul cron autorise par jour, pas de vrai rythme toutes les 4h). Chaque
// livraison tire aleatoirement 3 a 8 matieres premieres parmi celles pas encore pleines,
// et repartit un volume aleatoire entre elles (le total des 6 livraisons visant ~800
// unites/jour, avec une vraie irregularite entre chaque livraison). Facilement migrable
// vers un vrai cron toutes les 4h si le plan Pro est active un jour.
// Simplification actee (note pour Fred) : le prix de la vente directe du transformateur
// utilise la MEME formule dynamique que l'entrepot (stock eleve = prix bas) tant qu'aucun
// prix manuel n'est fixe — evite un systeme de prix parallele, reste coherent avec tout ce
// qu'on a deja construit. Mode "PJ directeur" (prix reglable dans la fourchette ±40%, et
// repartition entrepots/vente directe reglable) construit le 8 aout 2026 — voir
// DIRECTEUR_USINE_INFO et verifierSalaireDirecteur dans plateau-justice-economie.js.
const TRANSFORMATEURS = [
  { buildingId: 'usine-pharmaceutique-luthecia', city: 'capitale', chaines: [{ matiere: 'plantes', produit: 'medicaments' }, { matiere: 'alcool', produit: 'desinfectant' }] },
  { buildingId: 'pole-tabac-alcools-psm',        city: 'ville_a',  chaines: [{ matiere: 'cereales', produit: 'alcool' }, { matiere: 'plantes', produit: 'tabac' }] },
  { buildingId: 'raffinerie-montrouge',          city: 'ville_b',  chaines: [{ matiere: 'petrole', produit: 'carburant' }] }
];

// Volume et ratio alignes sur le travail PJ (produire_medicaments/alcool/tabac/carburant,
// plateau-justice-economie.js) le 10 aout 2026 : meme ratio de transformation pour les deux
// modes (1 matiere = 2 produits, au lieu de l'ancien RATIO_TRANSFORMATION=2 qui faisait
// l'inverse), seul le volume differe desormais. Le mode PNJ automatique n'est plus que le
// filet de securite (10% du volume d'origine, 80 -> 8) ; les 90% restants sont censes venir
// du travail remunere des joueurs.
const VOLUME_MATIERE_PAR_CHAINE_JOUR = 8; // -> 16 unites produites (ratio 1:2)
// 25% a chacun des 3 entrepots + 25% vente directe (decision de Fred, 30 aout 2026, remplace
// l'ancienne regle 20/20/20/40 -- confirmee reelle dans le code avant modification, voir
// PART_REDISTRIBUTION_ENTREPOTS ci-dessous et son usage dans produireTransformateursQuotidien).
const PART_REDISTRIBUTION_ENTREPOTS = 0.75;
const PLAFOND_VENTE_DIRECTE = 50;

// Redirection d'une partie de chaque livraison quotidienne vers le stock physique de matiere
// premiere de l'usine locale (usine.stockMatieres, meme principe que l'Armurerie -- ajoute le
// 10 aout 2026, remplace l'ancien achat instantane sur la caisse de l'usine). S'accumule si
// personne ne produit, se consomme avec la production (PNJ + PJ). 20% de chaque livraison
// concernee, carve sur le meme flux (pas un volume supplementaire) -- si l'usine n'a pas la
// place, le surplus reste simplement a l'entrepot (pas de perte), demande de Fred.
const USINE_LOCALE_PAR_VILLE = {
  capitale: { buildingId: 'usine-pharmaceutique-luthecia', matieres: ['plantes'] },
  ville_a:  { buildingId: 'pole-tabac-alcools-psm',        matieres: ['cereales', 'plantes'] },
  ville_b:  { buildingId: 'raffinerie-montrouge',          matieres: ['petrole'] }
};
const PART_REDIRECTION_USINE = 0.20;

// =====================
// ACHAT AUTOMATIQUE INTER-USINES (30 aout 2026) -- quand une usine a besoin, comme matiere
// premiere, d'un produit fabrique par une AUTRE usine (jamais un transfert depuis un entrepot).
// Verifie dans le code reel avant d'ecrire cette liste (TRANSFORMATEURS ci-dessus) : la seule
// chaine aujourd'hui dans ce cas est usine-pharmaceutique-luthecia (alcool -> desinfectant),
// l'alcool etant produit par pole-tabac-alcools-psm (cereales -> alcool), PSM et non Luthecia.
// Liste generique (pas de code specifique a alcool/desinfectant) : un ajout futur (une autre
// usine ayant besoin du produit d'une autre) tient dans une seule entree supplementaire.
const ACHATS_INTER_USINES = [
  { buildingIdAcheteur: 'usine-pharmaceutique-luthecia', villeAcheteur: 'capitale',
    produit: 'alcool',
    buildingIdFournisseur: 'pole-tabac-alcools-psm', villeFournisseur: 'ville_a' }
];
// 12,5% de la production REELLE DU JOUR du fournisseur (decision de Fred, 30 aout 2026) -- la
// moitie des 25% qui restent normalement en vente directe chez le fournisseur apres la
// redistribution 25/25/25/25 ci-dessus. Meme convention d'arrondi que versEntrepots
// (Math.round) : avec le volume reel actuel (16 unites/jour/chaine), 16*0.125=2 exactement,
// aucune ambiguite d'arrondi en pratique aujourd'hui.
const PART_ACHAT_INTER_USINES = 0.125;

function chaineDependDUnAchatInterUsine(buildingId, matiere) {
  return ACHATS_INTER_USINES.some(a => a.buildingIdAcheteur === buildingId && a.produit === matiere);
}

// Produit UNE chaine (matiere -> produit) d'un transformateur : consomme sa matiere premiere,
// produit au ratio 1:2, redistribue 25/25/25/25. Extrait de produireTransformateursQuotidien()
// (30 aout 2026, lot achat inter-usines) pour etre rejouable une seconde fois, apres l'achat
// automatique, sur les chaines qui en dependent (ex. alcool -> desinfectant) -- meme code
// exact dans les deux cas, aucune duplication. Mute stockMatieres/venteDirecte en place (memes
// objets que l'appelant), retourne les unites produites (0 si pas assez de matiere en stock).
// coefficientActivite (greves, 3 septembre 2026, optionnel -- absent/1 = comportement inchange
// pour tout appelant anterieur a ce lot) : reduit le volume nominal du jour, jamais une valeur
// deja reduite la veille (VOLUME_MATIERE_PAR_CHAINE_JOUR reste la seule reference, relue a
// l'identique chaque jour -- voir appliquerEffetsGrevesOrdinaires ci-dessous, aucune composition
// multiplicative possible d'un jour sur l'autre).
async function produireUneChaine(transfo, chaine, usine, stockMatieres, venteDirecte, coefficientActivite) {
  const matiereCfg = RESSOURCES_ECONOMIE_SERVEUR[chaine.matiere];
  if (!matiereCfg) return 0;

  const coeff = coefficientActivite != null ? coefficientActivite : 1;
  const volumeJour = Math.max(0, Math.round(VOLUME_MATIERE_PAR_CHAINE_JOUR * coeff));
  if (volumeJour <= 0) return 0;

  const stockDispo = stockMatieres[chaine.matiere] || 0;
  if (stockDispo < volumeJour) return 0; // pas assez de matiere en stock aujourd'hui
  stockMatieres[chaine.matiere] = stockDispo - volumeJour;

  const uniteesProduites = volumeJour * 2; // 1 matiere = 2 produits (ratio inchange)
  // Reglable par le directeur PJ en poste (tableau de bord, aout 2026) — 0.75 par defaut (mode PNJ)
  const partEntrepots = usine.repartitionEntrepots != null ? usine.repartitionEntrepots : PART_REDISTRIBUTION_ENTREPOTS;
  const versEntrepots = Math.round(uniteesProduites * partEntrepots);
  const venteDirecteQte = uniteesProduites - versEntrepots;
  const villesIds = ENTREPOTS_VILLES.map(e => e.city);
  const partsEgales = Object.fromEntries(villesIds.map(v => [v, 100 / villesIds.length]));
  const repartitionEntrepots = repartirSelonPourcentages(versEntrepots, partsEgales, villesIds);

  // Redistribution en parts egales entre les 3 entrepots (Hamilton, aucune unite perdue par
  // arrondi), perdu uniquement si un entrepot est deja plein sur ce produit
  for (const cible of ENTREPOTS_VILLES) {
    const etatCible = await sbGetBatimentEtat('republic', cible.city, cible.buildingId).catch(() => null);
    if (!etatCible) continue;
    const entrepotCible = etatCible.entrepot || { stock: {}, caisse: 8500 };
    const stockCible = entrepotCible.stock || {};
    const plafondProduit = RESSOURCES_ECONOMIE_SERVEUR[chaine.produit].plafond;
    const placeRestante = Math.max(0, plafondProduit - (stockCible[chaine.produit] || 0));
    const qteStockee = Math.min(repartitionEntrepots[cible.city], placeRestante);
    stockCible[chaine.produit] = (stockCible[chaine.produit] || 0) + qteStockee;
    await sbSetBatimentEtat('republic', cible.city, cible.buildingId, { ...etatCible, entrepot: { ...entrepotCible, stock: stockCible } }).catch(() => {});
  }

  // Le reste part en vente directe, plafonne sur place
  const placeRestanteLocal = Math.max(0, PLAFOND_VENTE_DIRECTE - (venteDirecte[chaine.produit] || 0));
  venteDirecte[chaine.produit] = (venteDirecte[chaine.produit] || 0) + Math.min(venteDirecteQte, placeRestanteLocal);

  return uniteesProduites;
}

// Achat automatique quotidien d'une usine aupres d'une autre (jamais depuis un entrepot).
// productionReelleDuJour : { produit: unitesProduitesCeJourLa } -- calculee et transmise par
// produireTransformateursQuotidien() dans la MEME execution (jamais persistee, jamais deduite
// d'un stock courant, conformement a la demande -- elle n'existe nulle part ailleurs, seulement
// en memoire pendant ce passage du cron). Transaction reelle : debit caisse acheteur, credit
// caisse fournisseur (meme montant, aucune creation/destruction d'argent), retrait du stock de
// vente directe du fournisseur, ajout dans stockMatieres de l'acheteur. Traite sequentiellement
// (boucle for...of avec await, comme le reste de ce cron) : si plusieurs entrees ciblaient un
// jour le meme fournisseur/produit, la premiere traitee consommerait le stock avant la seconde
// (premier arrivee, premier servi) -- jamais une simultaneite artificielle sur une architecture
// qui ne l'est pas.
// LOIS D'INTERDICTION (arbitrage du 11 septembre 2026) : une categorie interdite en vigueur bloque
// TOUTE vente legale ou institutionnelle, y compris celles que ce cron execute seul (livraisons
// payees aux entrepots, achats usine -> usine, exportations sous contrat). Decision SERVEUR, a
// l'instant du passage : assemblee_verifier_vente (correspondance categorie -> matiere, loi adoptee,
// adoptee_ts <= now()). Aucun cache : une loi adoptee ou abrogee s'applique au passage suivant.
// Renvoie l'ensemble des matieres interdites, ou null si la verification est impossible -- les
// appelants s'abstiennent alors de vendre ce jour-la (fail-closed). La production, les arrivages
// gratuits et la redistribution gratuite vers les entrepots ne sont pas des ventes : ils continuent,
// le stock n'etant jamais supprime (§34).
async function matieresInterditesRepublia() {
  const cles = Object.keys(RESSOURCES_ECONOMIE_SERVEUR);
  const rep = await sbRpc('assemblee_verifier_vente', { p_objets: cles.map(c => ({ stackKey: c })), p_country: 'republic' });
  const v = Array.isArray(rep) ? rep[0] : rep;
  if (!v || v.raison || !Array.isArray(v.interdits)) return null;
  return new Set(v.interdits.map(i => cles[i.index]).filter(Boolean));
}

async function traiterAchatsInterUsinesQuotidien(productionReelleDuJour) {
  const resultats = [];
  const interdites = await matieresInterditesRepublia();
  for (const achat of ACHATS_INTER_USINES) {
    if (interdites === null) { resultats.push({ ...achat, qte: 0, raison: 'legalite_non_verifiable' }); continue; }
    if (interdites.has(achat.produit)) { resultats.push({ ...achat, qte: 0, raison: 'interdit_par_la_loi' }); continue; }
    const production = productionReelleDuJour[achat.produit] || 0;
    if (production <= 0) { resultats.push({ ...achat, qte: 0, raison: 'production_nulle' }); continue; }

    const etatFournisseur = await sbGetBatimentEtat('republic', achat.villeFournisseur, achat.buildingIdFournisseur).catch(() => null);
    const etatAcheteur = await sbGetBatimentEtat('republic', achat.villeAcheteur, achat.buildingIdAcheteur).catch(() => null);
    if (!etatFournisseur || !etatAcheteur) { resultats.push({ ...achat, qte: 0, raison: 'batiment_indisponible' }); continue; }

    const usineFournisseur = etatFournisseur.usine || { caisse: 3000, venteDirecte: {}, stockMatieres: {} };
    const usineAcheteur = etatAcheteur.usine || { caisse: 3000, venteDirecte: {}, stockMatieres: {} };
    const venteDirecteFournisseur = usineFournisseur.venteDirecte || {};
    const stockMatieresAcheteur = usineAcheteur.stockMatieres || {};

    const stockDispoFournisseur = venteDirecteFournisseur[achat.produit] || 0;
    const plafondProduit = RESSOURCES_ECONOMIE_SERVEUR[achat.produit]?.plafond || 0;
    const placeRestanteAcheteur = Math.max(0, plafondProduit - (stockMatieresAcheteur[achat.produit] || 0));
    const quotaJournalier = Math.round(production * PART_ACHAT_INTER_USINES);

    // Plafonds cumules (section 2 du cahier des charges) : quota 12,5%, stock reellement
    // disponible chez le fournisseur, place restante chez l'acheteur -- jamais plus que ce que
    // le fournisseur possede reellement.
    const qteVisee = Math.min(quotaJournalier, stockDispoFournisseur, placeRestanteAcheteur);
    if (qteVisee <= 0) {
      const raison = stockDispoFournisseur <= 0 ? 'fournisseur_sans_stock' : (placeRestanteAcheteur <= 0 ? 'acheteur_deja_plein' : 'quota_nul');
      resultats.push({ ...achat, qte: 0, raison });
      continue;
    }

    // Prix = exactement le prix de vente directe du fournisseur (prix manuel du directeur PJ
    // s'il en a fixe un, sinon la meme formule dynamique que confirmerVenteDirecteUsine cote
    // client -- getPrixRessourceServeur ci-dessus).
    const prixManuelFournisseur = (usineFournisseur.prixManuel || {})[achat.produit];
    const prixUnitaire = prixManuelFournisseur != null ? prixManuelFournisseur : getPrixRessourceServeur(achat.produit, stockDispoFournisseur);

    const caisseAcheteur = usineAcheteur.caisse || 0;
    const qteAchetable = prixUnitaire > 0 ? Math.floor(caisseAcheteur / prixUnitaire) : qteVisee;
    const qte = Math.min(qteVisee, qteAchetable);
    if (qte <= 0) { resultats.push({ ...achat, qte: 0, raison: 'caisse_insuffisante' }); continue; }

    const montant = Math.round(qte * prixUnitaire * 100) / 100;

    venteDirecteFournisseur[achat.produit] = stockDispoFournisseur - qte;
    usineFournisseur.caisse = (usineFournisseur.caisse || 0) + montant;
    stockMatieresAcheteur[achat.produit] = (stockMatieresAcheteur[achat.produit] || 0) + qte;
    usineAcheteur.caisse = caisseAcheteur - montant;

    await sbSetBatimentEtat('republic', achat.villeFournisseur, achat.buildingIdFournisseur, { ...etatFournisseur, usine: { ...usineFournisseur, venteDirecte: venteDirecteFournisseur } }).catch(() => {});
    await sbSetBatimentEtat('republic', achat.villeAcheteur, achat.buildingIdAcheteur, { ...etatAcheteur, usine: { ...usineAcheteur, stockMatieres: stockMatieresAcheteur } }).catch(() => {});

    resultats.push({ ...achat, qte, prixUnitaire, montant, raison: qte < quotaJournalier ? 'partiel' : 'complet' });
  }
  return resultats;
}

// Production quotidienne automatique (mode PNJ, filet de securite) de chaque transformateur :
// consomme sa matiere premiere depuis son propre stock physique (usine.stockMatieres, alimente
// par livrerEntrepotsQuotidien ci-dessous -- plus d'achat instantane sur caisse depuis le 10
// aout 2026), produit le bien fini au ratio 1:2, redistribue 75% aux 3 entrepots (25% chacun,
// perdu si un entrepot est deja plein sur ce produit), garde 25% en vente directe sur place
// (mini-stock propre, plafonne, prix dynamique comme un entrepot). Ancienne regle reelle
// confirmee dans le code avant modification (30 aout 2026) : 60%/20-20-20/40, remplacee par
// 75%/25-25-25/25 (decision de Fred). Repartition entre les 3 entrepots via
// repartirSelonPourcentages() (methode du plus fort reste/Hamilton, deja utilisee et validee pour
// la logistique portuaire plus haut dans ce fichier) -- corrige au passage une perte par arrondi
// reelle de l'ancien Math.floor(versEntrepots/3) (jusqu'a 2 unites silencieusement jamais
// creditees nulle part quand versEntrepots n'etait pas divisible par 3), decouverte en
// implementant cette regle. venteDirecteQte reste calcule par soustraction exacte (uniteesProduites
// - versEntrepots), donc la conservation totale (entrepots + vente directe = uniteesProduites)
// est garantie quel que soit le reste.
//
// 3 passes (30 aout 2026, lot achat inter-usines) : (1) toutes les chaines SAUF celles qui
// dependent d'un achat inter-usines (ex. alcool -> desinfectant), en enregistrant la production
// REELLE DU JOUR de chaque produit au passage (disponible seulement ici, jamais persistee
// ailleurs) ; (2) achat automatique inter-usines, base sur cette production reelle ; (3) les
// chaines mises de cote en (1), rejouees maintenant que leur matiere premiere externe a pu
// arriver dans stockMatieres -- meme fonction produireUneChaine() dans les 2 cas, aucun code
// parallele.
async function produireTransformateursQuotidien() {
  const resultats = { transformateurs: 0, uniteesProduites: 0 };
  const productionReelleDuJour = {};
  try {
    for (const transfo of TRANSFORMATEURS) {
      const etat = await sbGetBatimentEtat('republic', transfo.city, transfo.buildingId).catch(() => null);
      if (!etat) continue; // batiment pas encore accessible dans cette ville

      // Dotation de depart, meme logique que l'entrepot
      const usine = etat.usine || { caisse: 3000, venteDirecte: {}, stockMatieres: {} };
      const venteDirecte = usine.venteDirecte || {};
      const stockMatieres = usine.stockMatieres || {};

      // Coefficient d'activite (greves, 3 septembre 2026) : ecrit par appliquerEffetsGrevesOrdinaires
      // (appelee AVANT cette fonction dans le handler principal, voir plus bas) sur etat.greve --
      // absent = 1 (aucune reduction), meme table/mecanisme que le blocus syndical.
      const coefficientActivite = etat.greve?.coefficient;

      for (const chaine of transfo.chaines) {
        if (chaineDependDUnAchatInterUsine(transfo.buildingId, chaine.matiere)) continue; // traitee en passe 3
        const u = await produireUneChaine(transfo, chaine, usine, stockMatieres, venteDirecte, coefficientActivite);
        if (u > 0) {
          productionReelleDuJour[chaine.produit] = (productionReelleDuJour[chaine.produit] || 0) + u;
          resultats.uniteesProduites += u;
        }
      }

      await sbSetBatimentEtat('republic', transfo.city, transfo.buildingId, { ...etat, usine: { ...usine, venteDirecte, stockMatieres } }).catch(() => {});
      resultats.transformateurs++;
    }

    resultats.achatsInterUsines = await traiterAchatsInterUsinesQuotidien(productionReelleDuJour);

    // Passe 3 : chaines dependantes d'un achat inter-usines, rejouees maintenant que
    // stockMatieres a potentiellement ete complete par la passe 2 ci-dessus.
    for (const transfo of TRANSFORMATEURS) {
      const chainesDependantes = transfo.chaines.filter(c => chaineDependDUnAchatInterUsine(transfo.buildingId, c.matiere));
      if (chainesDependantes.length === 0) continue;
      const etat = await sbGetBatimentEtat('republic', transfo.city, transfo.buildingId).catch(() => null);
      if (!etat) continue;
      const usine = etat.usine || { caisse: 3000, venteDirecte: {}, stockMatieres: {} };
      const venteDirecte = usine.venteDirecte || {};
      const stockMatieres = usine.stockMatieres || {};
      const coefficientActivite = etat.greve?.coefficient;
      for (const chaine of chainesDependantes) {
        const u = await produireUneChaine(transfo, chaine, usine, stockMatieres, venteDirecte, coefficientActivite);
        if (u > 0) resultats.uniteesProduites += u;
      }
      await sbSetBatimentEtat('republic', transfo.city, transfo.buildingId, { ...etat, usine: { ...usine, venteDirecte, stockMatieres } }).catch(() => {});
    }
  } catch(e) { console.error('produireTransformateursQuotidien error', e); }
  return resultats;
}

async function livrerEntrepotsQuotidien() {
  // COMPTE RENDU LISIBLE (correctif du 14 septembre 2026). `entrepots` s'incrementait meme
  // quand la caisse trop faible empechait le moindre achat : le cron annoncait « 3 entrepots
  // traites » pour une nuit ou zero unite avait ete livree, et l'assechement des caisses a pu
  // durer des jours sans la moindre alerte. On distingue desormais trois issues, sans changer
  // aucune regle economique -- une tresorerie insuffisante reste un fonctionnement NORMAL du
  // jeu, jamais une erreur technique.
  const resultats = { entrepots: 0, unitesLivrees: 0, coutTotal: 0,
                      approvisionnes: 0, sansTresorerie: 0, echecsTechniques: 0,
                      parEntrepot: [] };
  // Accumulateur national (lot logistique portuaire, 25 aout 2026) : sommme, sur les 3 tirages
  // INDEPENDANTS des 3 entrepots (inchanges, meme RNG qu'avant ce lot), la part de
  // bois/petrole/produits_exotiques desormais reroutee vers le port plutot que creditee
  // directement a l'entrepot d'origine du tirage. Ecrit une seule fois a la fin de cette
  // fonction, dans etat.port.stock du batiment 'port-sainte-marie'.
  const portAccumulation = {};
  try {
    // 'bois' explicitement exclu (lot Scierie Guy Tarembois, 25 aout 2026, correctif dedie) :
    // ne participe plus jamais a ce tirage RNG partage avec les 10 autres ressources livrees --
    // sa production est desormais un flux national deterministe, voir BOIS_SCIERIE_JOUR/
    // BOIS_SOVARKA_JOUR plus bas dans cette meme fonction. RESSOURCES_ECONOMIE_SERVEUR.bois
    // garde source:'livraison' (plafond/prixAchatFournisseur toujours valides pour l'entrepot),
    // seule sa participation a CE tirage change.
    // Livraison = achat de l'entrepot a un fournisseur : une matiere interdite n'est plus livree (ni
    // stockee, ni redirigee vers l'usine locale, ni reroutee vers le port). Verification impossible
    // -> aucune livraison ce jour (fail-closed).
    const interdites = await matieresInterditesRepublia();
    if (interdites === null) { resultats.erreur = 'legalite_non_verifiable'; return resultats; }
    resultats.matieresInterdites = [...interdites];
    const ressourcesLivrables = Object.entries(RESSOURCES_ECONOMIE_SERVEUR).filter(([cle, r]) => r.source === 'livraison' && cle !== 'bois' && !interdites.has(cle));

    // Qui dirige reellement chaque entrepot cette nuit ? Une seule requete, lue une fois :
    // elle sert a savoir si les desideratas poses par un PJ sont encore les siens.
    const directeursEnPoste = {};
    try {
      const dirs = await sbGet('personnages', 'select=name,poste&poste->>id=eq.directeur_entrepot');
      (dirs || []).forEach(d => { if (d.poste && d.poste.city) directeursEnPoste[d.poste.city] = d.name; });
    } catch (e) { /* aucun directeur PJ lisible : les valeurs PNJ s'appliqueront */ }

    // LA LECTURE DES CAISSES MUNICIPALES A DISPARU (8 octobre 2026). Elle ne servait qu'au
    // soutien ad hoc de l'entrepot par sa ville -- une seconde regle de financement, retiree
    // avec le reste : l'entrepot touche desormais sa part declaree, 40 % des recettes du jour,
    // versee par la cascade municipale. Cette passe ne lit ni n'ecrit plus aucun budget
    // municipal.

    // Ce qui est deja en route vers chaque entrepot, par ressource. Sans cette lecture, une
    // commande directe passee la veille serait rachetee une seconde fois par le cron.
    const transitsParRessource = {};
    try {
      const enRoute = await sbGet('entrepot_transits', 'select=destination_id,ressource,quantite');
      (enRoute || []).forEach(t => {
        const ville = (ENTREPOTS_VILLES.find(e => t.destination_id === 'republic_' + e.city + '_' + e.buildingId) || {}).city;
        if (!ville) return;
        if (!transitsParRessource[ville]) transitsParRessource[ville] = {};
        transitsParRessource[ville][t.ressource] = (transitsParRessource[ville][t.ressource] || 0) + (t.quantite || 0);
      });
    } catch (e) { /* transit illisible : on approvisionne sans en tenir compte, jamais l'inverse */ }

    for (const { buildingId, city } of ENTREPOTS_VILLES) {
      const etat = await sbGetBatimentEtat('republic', city, buildingId).catch(() => null);
      if (!etat) {
        // Vrai echec technique : l'etat du batiment n'a pas pu etre lu. Distingue d'une
        // tresorerie insuffisante, qui est un fonctionnement normal.
        resultats.echecsTechniques++;
        resultats.parEntrepot.push({ city, buildingId, issue: 'echec_technique', unites: 0 });
        continue;
      }
      // Dotation de depart : de quoi remplir un stock vide a son plafond au prix fournisseur
      // (~8500 FR, calcule sur les 8 ressources livrables). Sans ca, la caisse resterait a 0
      // et l'entrepot ne pourrait jamais payer sa toute premiere livraison.
      const entrepot = etat.entrepot || { stock: {} };
      const stock = entrepot.stock || {};
      // LA TRESORERIE EST DANS SA CAISSE, PLUS DANS LE BLOB (8 octobre 2026). Deux defauts
      // tombent avec ce changement : lire `entrepot.caisse` rendrait desormais zero, et la
      // reecrire en fin de boucle RECREERAIT la cle -- une seconde bourse. Et le repli
      // `{ caisse: 8500 }` ci-dessus FABRIQUAIT 8 500 FR chaque fois que le blob n'avait pas
      // la cle : une dotation de demarrage qui n'avait plus de raison d'etre depuis que les
      // caisses existent vraiment et recoivent 40 % des recettes municipales chaque nuit.
      //
      // On lit la caisse canonique, on calcule la passe en memoire comme avant, et on
      // n'applique a la fin que le DELTA, par la porte serveur verrouillee.
      const lecture = await sbRpc('entrepot_caisse_lire',
        { p_id: 'republic_' + city + '_' + buildingId }, HEADERS_SERVICE);
      const caisseAvant = Number(Array.isArray(lecture) ? lecture[0] : lecture) || 0;
      let caisse = caisseAvant;
      let unitesEntrepot = 0;
      let coutEntrepot = 0;
      let lotsRefusesTresorerie = 0;   // lots que la caisse n'a pas pu payer, voir plus bas
      const achatsDuJour = [];         // pour le registre commercial de l'etablissement

      // Usine locale de cette ville (redirection 20% des matieres qu'elle utilise, voir constante
      // PART_REDIRECTION_USINE ci-dessus)
      const usineLocale = USINE_LOCALE_PAR_VILLE[city];
      let etatUsine = null;
      let stockMatieresUsine = {};
      if (usineLocale) {
        etatUsine = await sbGetBatimentEtat('republic', city, usineLocale.buildingId).catch(() => null);
        if (etatUsine) stockMatieresUsine = (etatUsine.usine && etatUsine.usine.stockMatieres) || {};
      }

      // =================================================================
      // APPROVISIONNEMENT PILOTE PAR LES DESIDERATAS (14 septembre 2026)
      // =================================================================
      // L'ancien mecanisme tirait au hasard 3 a 8 ressources par livraison et leur repartissait
      // un volume aleatoire. Un directeur PJ subissait donc une repartition arbitraire qu'il ne
      // pouvait pas piloter. Desormais chaque entrepot vise des STOCKS CIBLES -- ceux du
      // directeur PJ s'il en a pose, sinon les valeurs PNJ par defaut -- et n'achete que ce qui
      // lui manque reellement.
      //
      // BESOIN = cible - (stock reel + ce qui est deja en route vers cet entrepot). Sans le
      // transit, une commande directe passee la veille serait rachetee une seconde fois.
      //
      // TRESORERIE INSUFFISANTE : plus de refus en bloc. Le budget disponible est reparti AU
      // PRORATA DE LA VALEUR des besoins (besoin x prix d'achat), pas du nombre d'unites --
      // sans quoi une ressource bon marche capterait la meme part qu'une ressource chere.
      // Mathematiquement, cela revient a servir chaque besoin dans la meme proportion.
      const desiderata = desiderataEffectifs(entrepot, directeursEnPoste, city);
      const capacite = CAPACITE_ENTREPOT_PAR_RESSOURCE;

      const besoins = [];
      for (const [cle, res] of ressourcesLivrables) {
        const cible = Math.max(0, Math.min(capacite, Number(desiderata[cle]) || 0));
        if (cible <= 0) continue;                       // 0 = aucun reapprovisionnement voulu
        const enRoute = (transitsParRessource[city] && transitsParRessource[city][cle]) || 0;
        const dejaAcquis = (stock[cle] || 0) + enRoute;
        // Le besoin ne depasse jamais la place reellement disponible : l'entrepot ne paie plus
        // jamais des unites qui ne pourraient pas entrer (anomalie relevee par l'audit du
        // 14 septembre -- l'ancien code reglait la quantite entiere, surplus perdu compris).
        const place = Math.max(0, capacite - (stock[cle] || 0) - enRoute);
        const besoin = Math.max(0, Math.min(cible - dejaAcquis, place));
        if (besoin > 0) besoins.push({ cle, res, besoin, prix: res.prixAchatFournisseur });
      }

      // Rythme quotidien conserve : un entrepot ne peut pas absorber plus de VOLUME_TOTAL_JOUR
      // unites par nuit, comme avant ce lot. Seule la maniere de les repartir change.
      const totalBesoins = besoins.reduce((s, b) => s + b.besoin, 0);
      const facteurVolume = totalBesoins > VOLUME_TOTAL_JOUR ? VOLUME_TOTAL_JOUR / totalBesoins : 1;
      besoins.forEach(b => { b.besoin = Math.floor(b.besoin * facteurVolume); });

      // COUT REELLEMENT A LA CHARGE DE L'ENTREPOT. Toutes les unites tirees ne sont pas payees
      // par lui : la part redirigee vers l'usine locale (20 %) et la totalite des ressources
      // reroutees vers le port (petrole, produits exotiques) sont des dotations publiques
      // gratuites. Calculer le soutien sur besoin x prix le ferait donc SUR-financer, et le
      // surplus resterait en caisse -- exactement l'accumulation que la regle interdit.
      // On simule ici, sans rien muter, la meme cascade que la boucle d'achat ci-dessous.
      let placeUsineSimulee = {};
      const valeurTotale = besoins.reduce(function (s, b) {
        let restante = b.besoin;
        if (usineLocale && etatUsine && usineLocale.matieres.includes(b.cle)) {
          const dejaUsine = (placeUsineSimulee[b.cle] !== undefined)
            ? placeUsineSimulee[b.cle] : (stockMatieresUsine[b.cle] || 0);
          const place = Math.max(0, b.res.plafond - dejaUsine);
          const redirigee = Math.min(Math.round(b.besoin * PART_REDIRECTION_USINE), place);
          placeUsineSimulee[b.cle] = dejaUsine + redirigee;
          restante -= redirigee;
        }
        if (RESSOURCES_REROUTEES_PORT.includes(b.cle)) return s;   // part au port, gratuit
        const placeEntrepot = Math.max(0, capacite - (stock[b.cle] || 0));
        return s + Math.min(restante, placeEntrepot) * b.prix;
      }, 0);

      // =================================================================
      // SOUTIEN MUNICIPAL DIFFERENTIEL (arbitrage du 14 septembre 2026)
      // =================================================================
      // Le directeur d'entrepot est nomme par le maire : c'est donc la VILLE, et non l'Etat,
      // qui soutient son etablissement quand il est tenu par un PNJ. Sans ce filet, les trois
      // entrepots resteraient bloques -- sans marchandise, pas d'export ; sans export, pas de
      // recette ; sans recette, pas de reapprovisionnement.
      //
      // DIFFERENTIEL, jamais une rente : on ne verse QUE le complement manquant, calcule sur le
      // besoin REEL etabli ci-dessus -- desideratas PNJ, moins le stock, moins ce qui est deja
      // en route, borne par la capacite et par le rythme quotidien. Caisse suffisante ->
      // versement nul. Rien ne s'accumule : ce qui est verse est depense dans la foulee.
      //
      // JAMAIS DE MONNAIE ARTIFICIELLE. Le versement est plafonne par ce que la caisse
      // municipale detient reellement. Une ville ruinee laisse donc son entrepot sous-finance,
      // sans aucune compensation de l'Etat : c'est une consequence politique assumee.
      //
      // IL DISPARAIT DES QU'UN PJ DIRIGE L'ETABLISSEMENT. Le test porte sur la detention reelle
      // du poste, pas sur la presence de desideratas : un directeur PJ qui n'a rien configure
      // assume quand meme sa gestion, sa tresorerie et sa faillite eventuelle.
      //
      // PLACEMENT. Ici et nulle part ailleurs : apres la livraison des transits (le besoin tient
      // donc compte de ce qui vient d'arriver) et avant les exportations (dont la recette
      // viendra reduire le soutien des nuits suivantes). Aucun double financement possible --
      // le soutien ne finance que le besoin calcule, jamais un montant forfaitaire.
      const dirigeParPj = !!directeursEnPoste[city];
      // LE SOUTIEN MUNICIPAL AD HOC EST SUPPRIME (8 octobre 2026), et ce n'est pas un effet de
      // bord : c'etait une SECONDE REGLE DE FINANCEMENT, concurrente de celle que l'arbitrage
      // vient de poser. Le mecanisme ponctionnait `budgets_municipaux.data.caisse` -- la bourse
      // supprimee -- pour combler le besoin de l'entrepot quand aucun PJ ne le dirigeait.
      //
      // L'ENTREPOT EST DESORMAIS FINANCE PAR SA PART DECLAREE : 40 % des recettes municipales du
      // jour, chaque nuit, par la cascade. Garder en plus un prelevement discretionnaire dans la
      // caisse de la mairie, decide par le cron et invisible du maire, ferait exactement ce que
      // les arbitrages interdisent -- deux regles qui distribuent le meme argent.
      //
      // Un entrepot qui ne peut pas payer sert donc partiellement, et c'est desormais une
      // consequence lisible de la repartition que le maire a choisie.

      const facteurBudget = (valeurTotale > caisse && valeurTotale > 0) ? caisse / valeurTotale : 1;
      if (facteurBudget < 1) lotsRefusesTresorerie++;   // servi partiellement, faute de tresorerie

      {
        besoins.forEach(({ cle, res, besoin, prix }) => {
          const qteLivree = Math.floor(besoin * facteurBudget);
          if (qteLivree <= 0) return;

          // Redirection vers l'usine locale, carvee sur cette meme livraison (pas un volume
          // supplementaire) -- gratuite pour l'usine (dotation publique, comme la livraison
          // elle-meme). Si l'usine n'a pas la place, le surplus reste simplement a l'entrepot.
          let qteRedirigee = 0;
          if (usineLocale && etatUsine && usineLocale.matieres.includes(cle)) {
            const qteVisee = Math.round(qteLivree * PART_REDIRECTION_USINE);
            const placeUsine = Math.max(0, res.plafond - (stockMatieresUsine[cle] || 0));
            qteRedirigee = Math.min(qteVisee, placeUsine);
            if (qteRedirigee > 0) stockMatieresUsine[cle] = (stockMatieresUsine[cle] || 0) + qteRedirigee;
          }
          let qteRestante = qteLivree - qteRedirigee;

          // Reroutage port (lot logistique portuaire, 25 aout 2026) : petrole/produits_exotiques
          // (100%, la redirection usine ci-dessus reste prioritaire et inchangee pour
          // petrole -> raffinerie) partent au port plutot que d'etre credites/payes directement
          // par CET entrepot -- aucun cout entrepot sur la part reroutee (ce n'est plus un achat
          // local, c'est un import national). Le bois n'apparait plus jamais ici (exclu de
          // ressourcesLivrables ci-dessus, voir lot Scierie Guy Tarembois du 25 aout 2026) :
          // cette branche ne concerne donc plus que petrole/produits_exotiques desormais.
          if (RESSOURCES_REROUTEES_PORT.includes(cle)) {
            portAccumulation[cle] = (portAccumulation[cle] || 0) + qteRestante;
            qteRestante = 0;
          }
          if (qteRestante <= 0) return;

          // ANOMALIE CORRIGEE (audit du 14 septembre 2026). L'ancien code calculait le cout sur
          // la quantite ENTIERE puis n'en stockait que ce qui tenait : l'entrepot payait donc le
          // surplus perdu. Le besoin etant desormais borne par la place disponible, la quantite
          // achetee est exactement celle qui entre -- il n'y a plus de surplus a perdre, ni a
          // payer. La capacite de 5 000 rend d'ailleurs le cas pratiquement inatteignable.
          const placeRestante = Math.max(0, capacite - (stock[cle] || 0));
          const qteStockee = Math.min(qteRestante, placeRestante);
          if (qteStockee <= 0) return;

          const cout = Math.round(qteStockee * prix * 100) / 100;
          if (caisse >= cout) {
            caisse -= cout;
            stock[cle] = (stock[cle] || 0) + qteStockee;
            unitesEntrepot += qteStockee;
            coutEntrepot += cout;
            achatsDuJour.push({ cle, qte: qteStockee, prix, cout });
          } else {
            // Ne devrait plus arriver : le facteur de budget a deja ramene l'ensemble des achats
            // sous la tresorerie disponible. Filet de securite, jamais une dette.
            lotsRefusesTresorerie++;
          }
        });
      }

      // LE BLOB NE GARDE QUE LE STOCK. Et le mouvement de caisse est applique en DELTA, pas en
      // valeur absolue : deux passes concurrentes ne peuvent plus s'ecraser, et la primitive
      // refuse de descendre sous zero.
      await sbSetBatimentEtat('republic', city, buildingId, { ...etat, entrepot: { ...entrepot, stock } }).catch(() => {});
      const deltaCaisse = Math.round((caisse - caisseAvant) * 100) / 100;
      if (deltaCaisse !== 0) {
        const repMvt = await sbRpc('entrepot_caisse_mouvement',
          { p_entrepot_id: 'republic_' + city + '_' + buildingId, p_delta: deltaCaisse },
          HEADERS_SERVICE);
        const rMvt = Array.isArray(repMvt) ? repMvt[0] : repMvt;
        if (!rMvt || rMvt.ok !== true) {
          signalerEchec('livraisons:caisse_entrepot:' + city, (rMvt && rMvt.raison) || 'verdict_absent');
        }
      }
      if (usineLocale && etatUsine) {
        await sbSetBatimentEtat('republic', city, usineLocale.buildingId, { ...etatUsine, usine: { ...(etatUsine.usine || {}), stockMatieres: stockMatieresUsine } }).catch(() => {});
      }
      // Trois issues distinctes, jamais confondues :
      //   approvisionne        au moins une unite reellement achetee et stockee ;
      //   sans_tresorerie      aucune unite, et au moins un lot refuse faute de caisse ;
      //   rien_a_livrer        aucune unite et aucun refus (tout etait deja au plafond, ou
      //                        toutes les matieres etaient interdites par une loi en vigueur).
      // `entrepots` garde son sens historique -- nombre d'entrepots parcourus -- mais il n'est
      // plus le seul chiffre publie, et il ne peut plus faire passer une nuit blanche pour une
      // nuit normale.
      const issue = unitesEntrepot > 0 ? 'approvisionne'
                  : (lotsRefusesTresorerie > 0 ? 'sans_tresorerie' : 'rien_a_livrer');
      if (issue === 'approvisionne') resultats.approvisionnes++;
      else if (issue === 'sans_tresorerie') resultats.sansTresorerie++;
      resultats.parEntrepot.push({ city, buildingId, issue, unites: unitesEntrepot,
                                   cout: Math.round(coutEntrepot * 100) / 100,
                                   caisseRestante: Math.round(caisse * 100) / 100,
                                   lotsRefusesTresorerie,
                                   dirigeParPj });

      // REGISTRE COMMERCIAL. Une ligne par ressource reellement achetee, jamais une ligne par
      // nuit vide : le registre appartient a l'etablissement et doit rester leger.
      // La ligne « soutien municipal » a disparu avec le mecanisme qu'elle tracait (voir plus
      // haut) : l'entrepot est finance par sa part declaree, versee par la cascade, et cette
      // recette-la est journalisee dans repartitions_versements.
      const entrepotId = 'republic_' + city + '_' + buildingId;
      const lignesRegistre = [];
      achatsDuJour.forEach(a => lignesRegistre.push({
        entrepot_id: entrepotId, operation: 'approvisionnement_auto', sens: 'entree',
        contrepartie: 'Fournisseurs', ressource: a.cle, quantite: a.qte,
        prix_unitaire: a.prix, fret_unitaire: 0, montant: a.cout, statut: 'livre'
      }));
      if (lignesRegistre.length > 0) {
        await sbInsert('entrepot_journal', lignesRegistre).catch(() => {});
      }

      resultats.entrepots++;
      resultats.unitesLivrees += unitesEntrepot;
      resultats.coutTotal += coutEntrepot;
    }

    // LA REECRITURE DES CAISSES MUNICIPALES A DISPARU avec le soutien ad hoc qu'elle persistait.
    // Cette passe ne touche plus un seul centime de budget municipal : l'entrepot est finance par
    // la cascade, qui debite la caisse de la mairie par la primitive verrouillee.

    // Production nationale de bois (lot Scierie Guy Tarembois, 25 aout 2026, correctif dedie) :
    // deux flux reels et deterministes, totalement independants du tirage RNG ci-dessus (voir
    // BOIS_SCIERIE_JOUR/BOIS_SOVARKA_JOUR plus haut dans ce fichier). Rejoint le meme
    // accumulateur portAccumulation.bois que le reste de ce lot portuaire -- aucun cout entrepot
    // (dotation publique/import national, meme doctrine que petrole/produits_exotiques
    // ci-dessus), distribue par le meme mecanisme unique juste en dessous (repartirSelonPourcentages/
    // Hamilton, plafond par entrepot, reliquat conserve).
    portAccumulation.bois = (portAccumulation.bois || 0) + BOIS_SCIERIE_JOUR + BOIS_SOVARKA_JOUR;

    // Credit + distribution du stock portuaire (lot logistique portuaire, 25 aout 2026).
    // Aucun cout : ce n'est pas un achat, c'est l'arrivee physique d'un import deja "paye" par
    // construction (aucune caisse n'existait pour cette part avant ce lot non plus -- voir
    // commentaire ORIGINE_IMPORTS_PORT). Respecte le plafond de chaque entrepot ; le reliquat
    // non distribuable (entrepot plein) reste dans etat.port.stock, jamais perdu ni detruit.
    const ressourcesArrivees = Object.entries(portAccumulation).filter(([, q]) => q > 0);
    if (ressourcesArrivees.length > 0) {
      const etatPort = await sbGetBatimentEtat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM).catch(() => ({}));
      const port = (etatPort && etatPort.port) || { stock: {}, repartition: {}, arrivages: [], exportations: {} };
      const stockPort = port.stock || {};
      const villesIds = ENTREPOTS_VILLES.map(e => e.city);
      const stocksEntrepots = {};
      for (const e of ENTREPOTS_VILLES) {
        const etatE = await sbGetBatimentEtat('republic', e.city, e.buildingId).catch(() => null);
        stocksEntrepots[e.city] = { etat: etatE, buildingId: e.buildingId };
      }

      const arrivagesJour = [];
      for (const [cle, qteArrivee] of ressourcesArrivees) {
        stockPort[cle] = (stockPort[cle] || 0) + qteArrivee;
        // Tracabilite des origines pour le bois (retour Fred, 25 aout 2026) : la distribution
        // reste UNIQUE et mutualisee (aDistribuer/repartirSelonPourcentages ci-dessous portent
        // toujours sur stockPort['bois'] combine, aucun deuxieme moteur) -- seul l'historique des
        // arrivages distingue les deux flux reels, pour que la logistique sache que Republia
        // produit reellement 150 (Scierie Guy Tarembois) et importe reellement 150 (Sovarka),
        // plutot qu'un seul evenement anonyme de 300.
        if (cle === 'bois') {
          const horodatage = new Date().toISOString();
          arrivagesJour.push({ jour: horodatage, resource: 'bois', qte: BOIS_SCIERIE_JOUR, origine: 'scierie_psm', label: 'Bois — Scierie Guy Tarembois (Républia)' });
          arrivagesJour.push({ jour: horodatage, resource: 'bois', qte: BOIS_SOVARKA_JOUR, origine: 'sovarka', label: 'Bois — Sovarka' });
        } else {
          arrivagesJour.push({ jour: new Date().toISOString(), resource: cle, qte: qteArrivee });
        }

        // Distribution immediate selon la repartition du Commandant (defaut 1/3-1/3-1/3),
        // plafonnee par entrepot -- le reliquat non distribuable reste dans stockPort.
        const pourcentages = (port.repartition && port.repartition[cle]) || REPARTITION_PORT_DEFAUT;
        const aDistribuer = stockPort[cle];
        const repartis = repartirSelonPourcentages(aDistribuer, pourcentages, villesIds);
        let totalReellementDistribue = 0;
        for (const ville of villesIds) {
          const vise = repartis[ville];
          if (vise <= 0) continue;
          const cible = stocksEntrepots[ville];
          if (!cible || !cible.etat) continue; // batiment pas encore accessible dans cette ville
          const entrepotCible = cible.etat.entrepot || { stock: {}, caisse: 8500 };
          const stockCible = entrepotCible.stock || {};
          const plafondRes = RESSOURCES_ECONOMIE_SERVEUR[cle].plafond;
          const placeRestante = Math.max(0, plafondRes - (stockCible[cle] || 0));
          const qteRecue = Math.min(vise, placeRestante);
          if (qteRecue > 0) {
            stockCible[cle] = (stockCible[cle] || 0) + qteRecue;
            cible.etat = { ...cible.etat, entrepot: { ...entrepotCible, stock: stockCible } };
            totalReellementDistribue += qteRecue;
          }
        }
        stockPort[cle] = Math.max(0, stockPort[cle] - totalReellementDistribue);
      }

      for (const e of ENTREPOTS_VILLES) {
        const cible = stocksEntrepots[e.city];
        if (cible && cible.etat) await sbSetBatimentEtat('republic', e.city, e.buildingId, cible.etat).catch(() => {});
      }

      const arrivagesConserves = [...arrivagesJour, ...(port.arrivages || [])].slice(0, NB_ARRIVAGES_CONSERVES);
      await sbSetBatimentEtat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM, {
        ...(etatPort || {}),
        port: { ...port, stock: stockPort, arrivages: arrivagesConserves }
      }).catch(() => {});
    }
  } catch(e) { console.error('livrerEntrepotsQuotidien error', e); }
  return resultats;
}

// Arrivage quotidien de poisson propre a la Criee de PSM (arbitrage du 25 aout 2026, §3-5).
// Independant a 100% de livrerEntrepotsQuotidien() ci-dessus : ne lit, ne modifie et ne reduit
// JAMAIS le stock d'aucun entrepot -- ecrit uniquement dans port.criee.stock.poisson. Plafonne
// (RESSOURCES_ECONOMIE_SERVEUR.poisson.plafond = 125), invendus persistants (jamais reinitialise
// a chaque passage), aucun report/dette si l'arrivage tire depasse la place restante (le surplus
// est simplement perdu ce jour-la, jamais reporte au lendemain -- coherent avec le principe
// "aucun depassement du plafond" explicitement demande).
async function genererArrivagePoissonCriee() {
  const resultats = { arrivee: 0, stockApres: 0 };
  try {
    const etatPort = await sbGetBatimentEtat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM).catch(() => ({}));
    const port = (etatPort && etatPort.port) || { stock: {}, repartition: {}, arrivages: [], exportations: {}, criee: {} };
    const criee = port.criee || { stock: {} };
    const stockCriee = { ...(criee.stock || {}) };

    const arrivage = Math.round(ARRIVAGE_POISSON_CRIEE_MIN + Math.random() * (ARRIVAGE_POISSON_CRIEE_MAX - ARRIVAGE_POISSON_CRIEE_MIN));
    const plafond = RESSOURCES_ECONOMIE_SERVEUR.poisson.plafond;
    const placeRestante = Math.max(0, plafond - (stockCriee.poisson || 0));
    const qteAjoutee = Math.min(arrivage, placeRestante);

    if (qteAjoutee > 0) {
      stockCriee.poisson = (stockCriee.poisson || 0) + qteAjoutee;
      await sbSetBatimentEtat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM, {
        ...(etatPort || {}),
        port: { ...port, criee: { ...criee, stock: stockCriee } }
      }).catch(() => {});
    }
    resultats.arrivee = qteAjoutee;
    resultats.stockApres = stockCriee.poisson || 0;
  } catch(e) { console.error('genererArrivagePoissonCriee error', e); }
  return resultats;
}

// Exportations institutionnelles Republia -> Al-Khalija (lot logistique portuaire, 25 aout
// 2026). Contrairement aux imports, prelevement REEL sur le stock physique existant des 3
// entrepots (jamais de matiere creee) : si le stock national est insuffisant, seule la
// quantite reellement disponible est exportee, le taux de satisfaction est trace pour le
// Commandant/Marcel Ancre, sans consequence diplomatique automatique (hors perimetre de ce lot).
async function traiterExportationsPortQuotidien() {
  const resultats = { exportations: {} };
  try {
    const etatPort = await sbGetBatimentEtat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM).catch(() => ({}));
    const port = (etatPort && etatPort.port) || { stock: {}, repartition: {}, arrivages: [], exportations: {} };
    const exportations = port.exportations || {};

    const stocksEntrepots = {};
    for (const e of ENTREPOTS_VILLES) {
      const etatE = await sbGetBatimentEtat('republic', e.city, e.buildingId).catch(() => null);
      stocksEntrepots[e.city] = { etat: etatE };
    }

    // Exportation = vente institutionnelle : une matiere interdite n'est plus exportee (le stock reste
    // en entrepot, §34). Verification impossible -> aucune exportation ce jour (fail-closed).
    const interdites = await matieresInterditesRepublia();
    for (const [cle, cfg] of Object.entries(EXPORTATIONS_PORT)) {
      if (interdites === null || interdites.has(cle)) {
        exportations[cle] = { destination: cfg.destination, contrat: 0, envoye: 0, satisfactionPct: 0,
          raison: interdites === null ? 'legalite_non_verifiable' : 'interdit_par_la_loi', jour: new Date().toISOString() };
        resultats.exportations[cle] = { contrat: 0, envoye: 0, raison: exportations[cle].raison };
        continue;
      }
      // "1 ville" reutilise le plafond deja existant de la ressource (RESSOURCES_ECONOMIE_
      // SERVEUR[cle].plafond) -- aucun chiffre invente, voir EXPORTATIONS_PORT plus haut.
      const plafondRes = RESSOURCES_ECONOMIE_SERVEUR[cle].plafond;
      const contrat = Math.round(plafondRes * cfg.equivalentVilles);

      const stocksActuels = {};
      let stockTotal = 0;
      for (const e of ENTREPOTS_VILLES) {
        const s = (stocksEntrepots[e.city].etat?.entrepot?.stock?.[cle]) || 0;
        stocksActuels[e.city] = s;
        stockTotal += s;
      }

      const aExporter = Math.min(contrat, stockTotal);
      // Repartition proportionnelle au stock REEL de chaque ville (pas aux pourcentages du
      // Commandant, qui pilotent les imports, pas les exports) -- arrondi Hamilton, jamais plus
      // preleve que ce qui existe reellement dans un entrepot donne.
      const preleves = {};
      if (aExporter > 0 && stockTotal > 0) {
        const villesIds = ENTREPOTS_VILLES.map(e => e.city);
        const parts = villesIds.map(v => aExporter * (stocksActuels[v] / stockTotal));
        const planchers = parts.map(p => Math.floor(p));
        let reliquat = aExporter - planchers.reduce((s, p) => s + p, 0);
        const ordre = parts.map((p, i) => ({ i, frac: p - planchers[i] })).sort((a, b) => b.frac - a.frac || a.i - b.i);
        const montants = [...planchers];
        for (let k = 0; k < ordre.length && reliquat > 0; k++) { montants[ordre[k].i]++; reliquat--; }
        villesIds.forEach((v, i) => { preleves[v] = montants[i]; });
      }

      // RECETTE D'EXPORTATION (arbitrage du 14 septembre 2026). Jusqu'a ce lot, l'exportation
      // etait le SEUL flux du jeu qui retirait du stock sans rien crediter en retour : les
      // entrepots payaient leurs livraisons et voyaient partir cereales et viande gratuitement,
      // ce qui les a menes a la faillite et maintenait ces deux ressources a zero.
      //
      // Le prix retenu est le prix_base de la ressource, lu dans le MIROIR SERVEUR
      // (RESSOURCES_ECONOMIE_SERVEUR, la meme source qui fournit deja le plafond du contrat
      // quelques lignes plus haut) -- jamais une valeur fournie par un client, qui n'intervient
      // a aucun moment dans ce cron. Meme patron que approvisionner_chantier : prix du miroir,
      // debit physique du stock, credit de la caisse de l'entrepot fournisseur.
      //
      // La repartition financiere suit EXACTEMENT la repartition physique calculee ci-dessus :
      // chaque entrepot n'encaisse que le produit des marchandises qu'il a reellement fournies.
      // Rien n'est credite au Port, ni a un budget national, ni a une caisse etrangere -- Al-Khalija
      // n'est represente par aucune caisse, on n'invente donc aucun debit en face.
      const prixExport = RESSOURCES_ECONOMIE_SERVEUR[cle].prixBase;
      let recetteTotale = 0;

      for (const e of ENTREPOTS_VILLES) {
        const qte = preleves[e.city] || 0;
        if (qte <= 0) continue;
        const cible = stocksEntrepots[e.city];
        if (!cible.etat) continue;
        const entrepotCible = cible.etat.entrepot || { stock: {}, caisse: 8500 };
        const stockCible = entrepotCible.stock || {};
        stockCible[cle] = Math.max(0, (stockCible[cle] || 0) - qte);
        const recette = Math.round(qte * prixExport * 100) / 100;
        recetteTotale += recette;
        // La caisse est relue sur cible.etat, qui porte deja les credits de la ressource
        // precedente de cette meme passe : les deux exportations du jour s'additionnent.
        cible.etat = { ...cible.etat, entrepot: { ...entrepotCible, stock: stockCible,
          caisse: Math.round(((entrepotCible.caisse || 0) + recette) * 100) / 100 } };
      }

      const satisfactionPct = contrat > 0 ? Math.round((aExporter / contrat) * 10000) / 100 : 100;
      exportations[cle] = { destination: cfg.destination, contrat, envoye: aExporter, satisfactionPct,
        prixUnitaire: prixExport, recette: recetteTotale, jour: new Date().toISOString() };
      resultats.exportations[cle] = { contrat, envoye: aExporter, satisfactionPct,
        prixUnitaire: prixExport, recette: recetteTotale };
    }

    for (const e of ENTREPOTS_VILLES) {
      const cible = stocksEntrepots[e.city];
      if (cible.etat) await sbSetBatimentEtat('republic', e.city, e.buildingId, cible.etat).catch(() => {});
    }
    await sbSetBatimentEtat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM, { ...(etatPort || {}), port: { ...port, exportations } }).catch(() => {});
  } catch(e) { console.error('traiterExportationsPortQuotidien error', e); }
  return resultats;
}

async function nettoyerBlocusExpires() {
  const resultats = { leves: 0 };
  try {
    const batiments = await sbGet('batiments_etat', '');
    if (!batiments) return resultats;

    for (const row of batiments) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      if (!etat.blocus) continue;

      const dernierRenouvellement = etat.blocus.dernierRenouvellementTimestamp || etat.blocus.lanceLe;
      if (Date.now() - dernierRenouvellement < 25 * 3600000) continue; // encore dans les temps

      await envoyerMailSysteme(etat.blocus.leaderActuel, etat.blocus.syndicatNom || 'Syndicat', 'Blocus levé', 'Faute de renouvellement, le blocus a été levé.').catch(() => {});

      delete etat.blocus;
      await sbUpdate('batiments_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
      resultats.leves++;
    }
  } catch(e) { console.error('nettoyerBlocusExpires error', e); }
  return resultats;
}

async function nettoyerAchatsDirectsManques() {
  const resultats = { manques: 0 };
  try {
    const terrains = await sbGet('terrains_etat', '');
    if (!terrains) return resultats;

    for (const row of terrains) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      if (!etat.achatDirect || !etat.achatDirect.dateLimite) continue;
      if (Date.now() <= etat.achatDirect.dateLimite) continue;

      // DEUX ECRITURES AVALEES ET UN Date.now() DANS L'IDENTIFIANT (chantier 5/6, 10 octobre
      // 2026). La consignation publique de la perte portait `'achatdirect-' + row.id + '-' +
      // Date.now()` : deux passes la meme nuit ecrivaient DEUX lignes pour le meme depot perdu --
      // exactement le defaut que la migration 575 avait ferme sur l'autre ecrivain de
      // compromis_historique, et qui n'avait pas ete propage jusqu'ici. Les deux ecritures etaient
      // de plus avalees : le depot pouvait etre consigne perdu sans que le rendez-vous soit purge
      // (donc reconsigne la nuit suivante), ou l'inverse.
      //
      // `achat_direct_manque_resoudre` fait les deux dans une transaction, sous verrou du terrain,
      // avec un identifiant DATE et un ON CONFLICT -- et l'index unique pose le meme jour sur
      // (pays, bien, resultat, journee) est la seconde garde.
      const v = await sbRpc('achat_direct_manque_resoudre', { p_terrain_id: row.id },
                            HEADERS_SERVICE)
        .then(rows => Array.isArray(rows) ? rows[0] : rows).catch(() => null);
      if (!v) { signalerEchec('achat_direct_manque:' + row.id, 'aucun verdict rendu'); continue; }
      if (v.ok !== true) {
        // Ces deux refus ne sont pas des echecs : la liste a vieilli entre sa lecture et l'appel.
        if (v.raison !== 'aucun_achat_direct' && v.raison !== 'pas_echu') {
          signalerEchec('achat_direct_manque:' + row.id, v.raison || 'refus sans motif');
        }
        continue;
      }
      resultats.manques++;
    }
  } catch(e) { console.error('nettoyerAchatsDirectsManques error', e); }
  return resultats;
}

// =====================================================================
// MOTEUR UNIFIE DES LOYERS (Lot 1.4, 6 septembre 2026)
// =====================================================================
// Remplace preleverLoyersLots(), qui lisait terrains_etat.data.subdivisions[].locataire/.loyer.
// Depuis le Lot 1.3, locations_actives est la source canonique des baux : un lot loue y possede
// une ligne comme n'importe quel local. Les champs de subdivision restent la description
// PHYSIQUE du lot (prix demande, base de l'indemnite d'eviction) mais ne sont plus une source de
// verite FINANCIERE -- ils ne sont plus lus ici.
//
// Ce moteur est aussi celui des baux jusqu'ici preleves cote client par payerLocations() (locaux
// de centres, suites, box, logements sociaux). CONSEQUENCE ASSUMEE ET SIGNALEE : ces baux
// passaient au reveil du joueur, donc jamais s'il ne se connectait pas ; ils passent desormais
// une fois par jour reel, connecte ou non. C'est deja la doctrine retenue pour les lots ("pour ne
// pas defavoriser le proprietaire si le locataire ne se connecte jamais", doDormir/
// plateau-personnage.js) et la seule frequence unifiable : un moteur client ne peut pas prelever
// un joueur absent.
//
// ATOMICITE : chaque prelevement est delegue a la RPC prelever_loyer_bail (une transaction
// Postgres : verrou du bail, verrou du locataire, credit de la destination, debit, marqueur
// anti-rejeu). Le moteur historique faisait deux UPDATE separes et ne creditait personne si le
// proprietaire avait disparu -- l'argent etait detruit. FAIL-CLOSED : si la RPC n'est pas
// installee, sbRpc renvoie null et RIEN n'est preleve.
// ============================================================================
// LES DEUX DEFINITIONS DU « JOUR » (arbitrage GD du 20 septembre 2026)
// ============================================================================
// DECISION : Europe/Paris est la reference temporelle canonique de Republia.
//
// POURQUOI CE N'EST PAS UN SIMPLE CHANGEMENT DE FONCTION. Le cron tourne a 23 h
// UTC ; a cette heure-la, la date parisienne est TOUJOURS UTC + 1 (CET ou CEST).
// Basculer jourCourantISO() d'un bloc ferait, la nuit de la bascule, qu'une
// tache deja marquee « 2026-09-19 » soit comparee a « 2026-09-20 » : elle
// tournerait une seconde fois. Sur la taxe fonciere ou les prets, c'est un
// double prelevement.
//
// ET SURTOUT : certaines cles de journee sont PARTAGEES avec le client, qui les
// ecrit avec jourPartageISO() (plateau-core.js) -- meme formule UTC. Trois
// traitements sont dans ce cas (prets bancaires, distribution fiscale, virement
// caserne) : le cron les execute ET une passe cliente les execute. Basculer le
// cron seul ferait diverger les deux gardes entre 00 h et 02 h de Paris, la
// fenetre exacte ou le client franchit minuit -- donc double execution.
// Ces trois-la restent donc sur jourCourantISO() jusqu'a ce que leur garde
// partagee soit portee cote serveur. C'est une frontiere ASSUMEE, pas un oubli.
//
// jourParisISO() sert aux cles dont le cron est le SEUL ecrivain : le registre
// des taches quotidiennes, le journal des crons, et le marqueur jourTraite des
// chantiers (le client n'y ecrit que `null` a l'initialisation).

// jourCourantISO() A ETE SUPPRIMEE le 20 septembre 2026. Plus aucune garde de
// rejeu ne parle UTC : toutes ont ete portees sur jourParisISO() ci-dessous, et
// les quatre passes CLIENTES qui partageaient une garde avec ce fichier ont ete
// retirees de runMidnightUpdate() le meme jour. Ne pas la reintroduire : une
// seule definition du jour, Europe/Paris.

// Date Europe/Paris, au format YYYY-MM-DD. Construite par parties plutot que par
// toLocaleDateString('en-CA') : le format rendu par un locale depend de l'ICU
// embarquee par le runtime, celui-ci n'en depend pas.
const FMT_JOUR_PARIS = new Intl.DateTimeFormat('fr-FR', {
  timeZone: 'Europe/Paris', year: 'numeric', month: '2-digit', day: '2-digit'
});
function jourParisISO(d) {
  const p = {};
  for (const part of FMT_JOUR_PARIS.formatToParts(d || new Date())) p[part.type] = part.value;
  return p.year + '-' + p.month + '-' + p.day;
}

// ============================================================================
// REGISTRE D'EXECUTION QUOTIDIENNE (chantier A / P0-4, 14 septembre 2026)
// ============================================================================
// LE DEFAUT. Huit taches nocturnes deplacent de l'argent ou de la matiere sans le moindre
// marqueur : taxe fonciere, preemptions d'Etat, livraisons d'entrepots, exportations du port,
// arrivage de la criee, production des transformateurs, effets de blocus, effort de guerre. Tout
// rejeu de la passe -- relance manuelle, reessai de la plateforme apres un echec tardif,
// redeploiement -- rejouait l'integralite de leurs mouvements. Le cas le plus lourd est la taxe
// fonciere : la dette se cumulait deux fois et la progression avertissement -> penalite -> SAISIE
// avancait de deux crans en une nuit.
//
// POURQUOI UN REGISTRE PARTAGE, ET PAS HUIT MARQUEURS. Chacune de ces taches ecrit dans un
// support different (terrains_etat, budgets_nationaux, trois batiments_etat, la caisse du port...)
// : y loger huit marqueurs differents, c'est huit occasions de se tromper et huit conventions a
// maintenir. On reutilise donc la brique generique deja en place -- sbGetBatimentEtat /
// sbSetBatimentEtat, meme convention que le seau 'global' du fret -- pour tenir UN registre
// { nomDeTache: 'YYYY-MM-DD' } sur une seule ligne batiments_etat.
//
// SERVEUR ET PERSISTANT. Ni state.day (compteur prive d'un joueur) ni un drapeau en memoire du
// processus (une fonction serverless est recreee a chaque invocation) ne protegent quoi que ce
// soit : le marqueur vit en base.
//
// AU PLUS UNE FOIS. Le marqueur est pose AVANT l'effet et son echec d'ecriture empeche la tache
// de tourner (fail-closed). Une interruption au milieu d'une tache coute donc au pire la fin de
// cette tache-la pour la journee -- jamais un second debit. Les taches qui n'ont pas tourne,
// elles, reprennent normalement au rejeu : le registre est nominatif, tache par tache.
const REGISTRE_CRON_ID = { country: 'republic', city: 'global', building: 'cron-minuit' };
let REGISTRE_JOURS_PASSE = null;

// Decale une date YYYY-MM-DD d'un nombre de jours, sans passer par le fuseau local.
function decalerJourISO(iso, jours) {
  const t = Date.parse(iso + 'T12:00:00Z');
  if (!isFinite(t)) return iso;
  return new Date(t + jours * 86400000).toISOString().slice(0, 10);
}

async function chargerRegistreJours() {
  if (REGISTRE_JOURS_PASSE) return REGISTRE_JOURS_PASSE;
  const etat = await sbGetBatimentEtat(REGISTRE_CRON_ID.country, REGISTRE_CRON_ID.city, REGISTRE_CRON_ID.building).catch(() => ({}));
  const brut = (etat && etat.joursCron) ? { ...etat.joursCron } : {};

  // BASCULE UTC -> EUROPE/PARIS, EN UNE SEULE FOIS (20 septembre 2026).
  //
  // Les marqueurs deja en base ont ete ecrits par le cron, a 23 h UTC : la date
  // PARISIENNE de cette nuit-la etait donc leur valeur + 1 jour, toujours -- le
  // decalage vaut +1 en heure d'hiver comme en heure d'ete a cette heure-ci.
  // On les traduit donc une fois, ce qui fait que :
  //   * un REJEU de la nuit deja traitee retrouve son marqueur et ne refait rien ;
  //   * la nuit suivante porte une date parisienne differente et s'execute.
  // Ni double execution, ni journee sautee.
  //
  // Le drapeau rend l'operation idempotente : une fois pose, plus aucune
  // traduction n'aura lieu, y compris si cette passe est rejouee.
  if (!(etat && etat.joursCronFuseau === 'Europe/Paris')) {
    for (const cle of Object.keys(brut)) {
      if (typeof brut[cle] === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(brut[cle])) {
        brut[cle] = decalerJourISO(brut[cle], 1);
      }
    }
    await sbSetBatimentEtat(REGISTRE_CRON_ID.country, REGISTRE_CRON_ID.city, REGISTRE_CRON_ID.building,
      { joursCron: { ...brut }, joursCronFuseau: 'Europe/Paris' });
    // Relecture : sans elle on tiendrait pour acquise une traduction que la base
    // a pu refuser, et la passe suivante retraduirait -- decalant d'un jour de plus.
    const verif = await sbGetBatimentEtat(REGISTRE_CRON_ID.country, REGISTRE_CRON_ID.city, REGISTRE_CRON_ID.building).catch(() => null);
    if (!verif || verif.joursCronFuseau !== 'Europe/Paris') {
      signalerEchec('registre_jours:bascule_fuseau', 'traduction Europe/Paris non persistee');
      // On repart des valeurs REELLEMENT en base, non traduites : mieux vaut
      // sauter la nuit que risquer un double prelevement sur une traduction
      // fantome. La passe suivante retentera la bascule.
      REGISTRE_JOURS_PASSE = (verif && verif.joursCron) ? { ...verif.joursCron } : {};
      return REGISTRE_JOURS_PASSE;
    }
  }

  REGISTRE_JOURS_PASSE = brut;
  return REGISTRE_JOURS_PASSE;
}

// Enveloppe une tache quotidienne : au plus une execution par journee partagee.
async function tacheQuotidienne(nom, fn) {
  // Cle CRON-SEULEMENT (verifie : aucun fichier client n'ecrit dans joursCron),
  // donc basculee sur Europe/Paris sans fenetre de divergence possible.
  const jour = jourParisISO();
  const registre = await chargerRegistreJours();
  if (registre[nom] === jour) {
    // Cas NORMAL et cas ANORMAL se ressemblent ici : soit la tache a deja tourne
    // cette nuit (rejeu sain), soit elle a plante apres la pose du marqueur lors
    // d'une passe precedente et se retrouve sautee pour toujours. Le journal les
    // distingue -- la ligne du jour porte deja 'ok' dans le premier cas, 'echec'
    // ou 'demarree' dans le second. On n'ecrase donc PAS la ligne existante.
    return { ignoree: 'deja_executee_ce_jour', jour };
  }

  registre[nom] = jour;
  await sbSetBatimentEtat(REGISTRE_CRON_ID.country, REGISTRE_CRON_ID.city, REGISTRE_CRON_ID.building, { joursCron: { ...registre } });
  // RELECTURE OBLIGATOIRE. sbSetBatimentEtat rend l'objet fusionne qu'elle a CALCULE, sans jamais
  // verifier que l'ecriture a abouti : son retour est donc truthy meme quand la base a refuse.
  // Se fier a lui ferait tourner la tache sans marqueur, c'est-a-dire exactement le scenario de
  // double debit qu'on cherche a interdire. On relit ce que la base a reellement conserve.
  const verif = await sbGetBatimentEtat(REGISTRE_CRON_ID.country, REGISTRE_CRON_ID.city, REGISTRE_CRON_ID.building).catch(() => null);
  if (!verif || !verif.joursCron || verif.joursCron[nom] !== jour) {
    // Marqueur non persiste : refuser de tourner. Executer sans filet exposerait a un double
    // mouvement au prochain rejeu, ce qui est pire que de perdre la tache pour cette nuit.
    delete registre[nom];
    signalerEchec('registre_jours:' + nom, 'marqueur non persiste, tache non executee');
    await journaliserCron(nom, jour, 'ignoree', 'marqueur non persiste, tache non executee');
    return { ignoree: 'marqueur_non_persiste', jour };
  }

  // A partir d'ici le marqueur EST pose : quoi qu'il arrive, la tache ne
  // retournera pas cette nuit. C'est precisement pour cela qu'elle doit laisser
  // une trace, y compris -- surtout -- quand elle echoue.
  const depart = Date.now();
  await journaliserCron(nom, jour, 'demarree');
  try {
    const resultat = await fn();
    await journaliserCron(nom, jour, 'ok', null, resumeContexte(resultat), Date.now() - depart);
    return resultat;
  } catch (e) {
    // L'exception est journalisee ET signalee (donc la passe rendra 500), puis
    // relancee : on ne transforme pas un echec en succes silencieux, et on ne
    // decide pas ici a la place de l'appelant si la passe doit continuer.
    signalerEchec('tache:' + nom, e);
    await journaliserCron(nom, jour, 'echec', (e && e.message) ? e.message : String(e), null, Date.now() - depart);
    throw e;
  }
}

// ============================================================================
// MIROIRS SERVEUR DES TRAITEMENTS QUOTIDIENS PARTAGES (Lot 4.3)
// ============================================================================
// POURQUOI DES MIROIRS. Le passage de jour cote client (runMidnightUpdate, plateau-core.js) portait
// seul trois traitements NATIONAUX : la redistribution fiscale, le virement vers la caserne et la
// solde des soldats. Sans joueur connecte a minuit, aucune institution du pays n'etait financee et
// aucun soldat n'etait paye. Ces trois-la doivent evoluer meme si personne ne joue.
//
// Ce module serverless ne peut pas importer les fichiers client : on duplique donc de facon
// CONTROLEE ET DOCUMENTEE, exactement comme le font deja RESSOURCES_ECONOMIE_SERVEUR et
// POSTES_NOMMES_EXCLUSIFS_SERVEUR, desormais GENEREE depuis data.js. Chaque constante
// ci-dessous porte le chemin de son original.
//
// PARITE. Les regles, montants, destinations et conditions sont ceux du client, a la ligne pres.
// Les « tests du lot » annonces ici N'EXISTENT PAS : verifie dans tout le depot le 6 octobre
// 2026. Rien ne detecte aujourd'hui une divergence entre ces implementations et le client.
//
// IDEMPOTENCE. Les trois partagent le marqueur du client -- meme champ, meme cle de journee
// (jourCourantISO() === jourPartageISO()). Le second passage, quel qu'il soit, est sans effet :
// client puis cron, cron puis client, cron rejoue, deux clients puis cron.

// CAISSE_PAR_POSTE_BUDGET_SERVEUR ET REPARTITION_DEFAULT_SERVEUR NE SONT PLUS IMPORTEES
// (chantier 4F, 7 octobre 2026), parce qu'elles n'existent plus. La cle de repartition du budget
// national vivait dans le navigateur et le serveur la recevait generee ; elle vit maintenant en
// base (repartitions_budgetaires), ou le Ministre de l'Economie et des Finances la modifie par
// RPC et ou le serveur l'applique. Le commentaire qui occupait ces lignes disait que
// REPARTITION_DEFAULT_SERVEUR n'etait qu'un « REPLI » : c'etait faux, elle etait la regle
// appliquee -- aucune cle `repartition` n'a jamais ete ecrite dans budgets_nationaux.

// Miroir des recettes fiscales quotidiennes de CITY_POPULATION (data.js). La version client est
// mutee en RAM par mettreAJourPopulation() sans jamais etre persistee : les valeurs de base sont
// donc la seule verite partagee, et c'est bien elles que le serveur doit employer.
const RECETTES_FISCALES_JOUR_SERVEUR = { republic: { capitale: 18000, ville_a: 2400, ville_b: 4200 } };

async function chargerBudgetNationalServeur(pays) {
  const rows = await sbGet('budgets_nationaux', `id=eq.${encodeURIComponent(pays)}`).catch(() => null);
  return (rows && rows[0]) ? (rows[0].data || {}) : null;
}

async function sauverBudgetNationalServeur(pays, data) {
  return await sbUpdate('budgets_nationaux', `id=eq.${encodeURIComponent(pays)}`,
    { data: data, updated_at: new Date().toISOString() }).catch(() => null);
}

// LES VRAIES VILLES D'UN EMPIRE, dans l'ordre canonique. Pendant serveur de villesDe()
// (data.js), lu dans le referentiel GENERE : aucune liste de villes n'est plus ecrite a la main
// dans ce fichier. Un empire inconnu rend [] -- jamais les villes de Republia.
function villesDeServeur(pays) {
  const t = VILLES_SERVEUR[pays];
  return t ? Object.keys(t) : [];
}

// L'identifiant de caisse d'une institution de ville, sans le prefixe pays. Pendant serveur de
// caisseTerritorialeId() (data.js) : convention reguliere `<famille>_<ville>`, plus la table des
// cles historiques, GENEREE (CAISSES_LEGACY_SERVEUR) et donc impossible a oublier ici.
function caisseTerritorialeServeur(famille, ville) {
  const v = ville || 'capitale';
  const legacy = CAISSES_LEGACY_SERVEUR[famille] && CAISSES_LEGACY_SERVEUR[famille][v];
  return legacy || (famille + '_' + v);
}

// LA REPARTITION TERRITORIALE AU PRORATA FISCAL A ETE RETIREE (chantier 4F, 7 octobre 2026).
//
// Elle avait ete ecrite la nuit du 7 octobre pour reparer un defaut reel : mairie, commissariat
// et tribunal etaient finances en direct par l'Etat, et uniquement dans la capitale -- les six
// caisses de Montrouge et de Port-Sainte-Marie n'avaient plus rien recu depuis le 19 septembre.
// Elle a bien tourne une nuit, et les chiffres sont au commit ba75c1e.
//
// L'ARBITRAGE DU 8 OCTOBRE REND CE CALCUL SANS OBJET, et c'est un progres : les trois familles
// quittent la cle nationale. Les institutions municipales relevent des MAIRIES, qui les financent
// depuis leur budget municipal ; les tribunaux relevent du MINISTERE DE LA JUSTICE, qui repartit
// entre les trois par la meme brique generique que tous les autres ministeres. L'Etat ne finance
// plus d'institution territoriale en direct, donc il n'a plus de prorata a calculer.
//
// Ce qui subsiste de cette nuit-la : villesDeServeur et caisseTerritorialeServeur, employes par
// les greves et les armureries.

// Credit d'une caisse de batiment. Meme forme que les credits deja pratiques par ce fichier
// (successions, chantiers) : lecture, addition, UPDATE ou INSERT selon l'existence.
async function crediterCaisseBatimentServeur(pays, buildingId, montant) {
  const m = Math.floor(Number(montant) || 0);
  if (m <= 0) return 0;
  const cle = pays + '_' + buildingId;
  const rows = await sbGet('caisses_batiments', `id=eq.${encodeURIComponent(cle)}`).catch(() => null);
  const data = (rows && rows[0] && rows[0].data) ? rows[0].data : { solde: 0 };
  data.solde = (data.solde || 0) + m;
  const r = (rows && rows.length > 0)
    ? await sbUpdate('caisses_batiments', `id=eq.${encodeURIComponent(cle)}`, { data: data, updated_at: new Date().toISOString() }).catch(() => null)
    : await sbInsert('caisses_batiments', { id: cle, data: data, updated_at: new Date().toISOString() }).catch(() => null);
  return r ? m : 0;
}

// Debit PLAFONNE : verse ce que la caisse peut, jamais plus -- comportement de
// debiterCaisseBatimentPlafonne cote client, volontairement tolerant au partiel.
async function debiterCaisseBatimentPlafonneServeur(pays, buildingId, montant) {
  const m = Math.floor(Number(montant) || 0);
  if (m <= 0) return 0;
  const cle = pays + '_' + buildingId;
  const rows = await sbGet('caisses_batiments', `id=eq.${encodeURIComponent(cle)}`).catch(() => null);
  if (!rows || rows.length === 0) return 0;
  const data = rows[0].data || { solde: 0 };
  const verse = Math.max(0, Math.min(m, data.solde || 0));
  if (verse <= 0) return 0;
  data.solde = (data.solde || 0) - verse;
  const r = await sbUpdate('caisses_batiments', `id=eq.${encodeURIComponent(cle)}`,
    { data: data, updated_at: new Date().toISOString() }).catch(() => null);
  return r ? verse : 0;
}

// --- 1. LA CASCADE BUDGETAIRE QUOTIDIENNE -----------------------------------
//
// LE CRON N'ORCHESTRE PLUS RIEN. Il dit au serveur « voici les recettes du jour », et la base
// fait le reste en UNE transaction : les recettes entrent dans la caisse du Ministere de
// l'Economie et des Finances, qui repartit vers les dix caisses nationales en conservant sa
// propre part, puis chaque ministere repartit vers les institutions de son ressort sur la base
// de ce qu'il vient de recevoir.
//
// CE QUI A DISPARU ICI, ET POURQUOI (arbitrage du 7 octobre 2026).
//
//   . LA BOUCLE SUR TREIZE CAISSES. Elle appliquait une cle qui melangeait ministeres,
//     commissariats, tribunaux et mairies, et cette cle vivait dans le CODE
//     (REPARTITION_DEFAULT) -- verifie en base, budgets_nationaux.data ne portait aucune cle
//     `repartition`. Elle vit maintenant dans la table repartitions_budgetaires, qui est la
//     source canonique et que le Ministre des Finances modifie par RPC.
//
//   . LA REPARTITION TERRITORIALE DES TROIS FAMILLES. mairie, commissariat et tribunal quittent
//     la cle nationale : les institutions municipales relevent des mairies, et les tribunaux du
//     Ministere de la Justice. repartirSurVillesAuProrataFiscal n'a donc plus d'appelant ici.
//
//   . LE VIREMENT JOURNALIER VERS LA CASERNE. C'etait un montant ABSOLU en FR
//     (budgets_nationaux.data.virementJournalierCaserne), donc une seconde regle, concurrente de
//     la cle de repartition. Il est remplace par une PART : Defense -> Caserne, 65 %. Le champ
//     etait absent de la base -- l'automatisme ne versait donc rien -- la migration est
//     indolore. Le virement PONCTUEL en FR, lui, reste : c'est un acte, pas une regle.
//
// LE MARQUEUR DE JOURNEE N'EST PLUS ICI NON PLUS. L'idempotence vit dans la cle primaire de
// repartitions_versements, qui porte le jour : un second passage leve une violation d'unicite et
// ne verse rien. Ce n'est plus un champ qu'une ecriture avalee peut perdre.
async function distribuerFiscaliteServeur(pays) {
  const budgetNat = await chargerBudgetNationalServeur(pays);
  if (!budgetNat) return { ok: false, raison: 'budget_national_illisible' };

  // LES RECETTES DU JOUR. Seule chose que le cron calcule encore : la somme des recettes
  // fiscales declarees des villes, plus la reserve accumulee par les taxes de transaction.
  // RECETTES_FISCALES_JOUR_SERVEUR ne connait que Republia -- un empire sans recette declaree
  // passe une base nulle, et la cascade ne verse rien plutot que d'inventer un chiffre.
  const villes = RECETTES_FISCALES_JOUR_SERVEUR[pays] || {};
  const dailyBase = Object.keys(villes).reduce((s, v) => s + (villes[v] || 0), 0);
  const totalDisponible = dailyBase + (budgetNat.reserveJour || 0);

  // La reserve est remise a zero AVANT l'appel : elle vient d'etre versee dans la base de la
  // cascade, et la laisser serait la distribuer deux fois demain. La cascade, elle, porte sa
  // propre garde d'idempotence.
  if ((budgetNat.reserveJour || 0) !== 0) {
    budgetNat.reserveJour = 0;
    if (!(await sauverBudgetNationalServeur(pays, budgetNat))) {
      return { ok: false, raison: 'reserve_non_remise_a_zero' };
    }
  }

  const rows = await sbRpc('budget_cascade_quotidienne', {
    p_pays: pays, p_recettes: totalDisponible
  });
  const r = Array.isArray(rows) ? rows[0] : rows;
  return r || { ok: false, raison: 'rpc_indisponible' };
}

// --- 3. SOLDE QUOTIDIENNE DES SOLDATS ---------------------------------------
// Miroir de payerSoldeQuotidienne (plateau-politique.js). 20 FR par soldat et par jour, effectif lu
// sur soldats.length -- la representation canonique d'une section.
// SOLDE PNJ SUPPRIMEE (18 septembre 2026, arbitrage GD) : les PNJ militaires n'ont aucune solde
// recurrente, le contingent ayant deja ete paye une fois pour toutes par les 20 000 FR de la
// compagnie. Retiree EN MEME TEMPS que son miroir client payerSoldeQuotidienne
// (plateau-politique.js) : les deux partageaient la cle de journee derniereSoldeJour, et n'en
// retirer qu'un aurait laisse l'autre payer seul.
//
// LA COQUILLE EST PARTIE (chantier 6, lot 1, 7 octobre 2026). Le commentaire d'origine disait
// lui-meme « le retirer est un lot de menage » : c'est ce lot. La fonction ne contenait qu'un
// `return;`, son unique appel vivait dans la sequence nocturne, et COUT_SOLDE_PAR_SOLDAT_SERVEUR
// (20 FR) n'avait plus d'autre lecteur qu'elle.

// --- 4. DESERTIONS : convoque -> deserteur a l'expiration du delai ------------
// Miroir de verifierDesertionsQuotidien (plateau-politique.js). Transition PUREMENT temporelle et
// deterministe : passe le deadline pose par la requisition civile, un convoque devient deserteur.
// Sans miroir, un convoque qui ne se connecte plus n'etait jamais declare deserteur tant qu'aucun
// joueur du meme pays ne passait minuit en ligne.
//
// LE DELAI DE 36 HEURES ET LE TIRAGE DE 24 CITOYENS SONT INCHANGES : ils appartiennent au design
// historique, ce miroir ne fait qu'appliquer l'echeance qu'ils posent.
//
// IDEMPOTENCE PAR TRANSITION D'ETAT : un statut deja 'deserteur' n'est pas retraite. Aucun marqueur
// de journee n'est necessaire, et en ajouter un serait une garde de trop.
//
// AUCUNE PEINE JUDICIAIRE N'EST CREEE. L'entree de recherche porte type:'militaire', qui n'existe
// dans aucune table de peines : le deserteur devient reperable et arretable, rien de plus.
async function traiterDesertionsServeur(pays) {
  const rows = await sbGet('compagnies_militaires', 'select=*').catch(() => null);
  if (!rows) return;
  const maintenant = Date.now();
  for (const r of rows) {
    const c = r.data;
    if (!c || c.pays !== pays) continue;
    let modifie = false;
    for (const s of (c.sections || [])) {
      for (const entree of (s.civilsRequisitionnes || [])) {
        if (entree.statut !== 'convoque') continue;
        if (!(maintenant > Number(entree.deadline))) continue;
        entree.statut = 'deserteur';
        modifie = true;
        await sbUpdate('personnages', `name=eq.${encodeURIComponent(entree.nom)}`, {
          requisition: { compagnieId: c.id, sectionId: s.id, statut: 'deserteur' }
        }).catch(() => {});
        // TROISIEME INSTANCE DE LA CHAINE 14, ET AUCUN INVENTAIRE NE LA NOMMAIT (10 octobre
        // 2026). Ces trois lignes etaient une lecture-modification-ecriture du tableau ENTIER,
        // avec les DEUX ecritures avalees : si la fiche du deserteur etait sauvegardee par son
        // navigateur entre la lecture et l'ecriture, l'avis de recherche disparaissait. Et un
        // echec d'ecriture ne laissait aucune trace.
        //
        // `recherche_inscrire` fait un `||` atomique. Le serveur nomme sa cible, puisqu'il n'a
        // pas de personnage : c'est le seul cas ou `p_cible` est exige.
        const vRech = await sbRpc('recherche_inscrire', {
          p_entree: { acte: 'desertion', type: 'militaire', country: pays,
                      compagnieId: c.id, sectionId: s.id, origine: 'requisition_civile' },
          p_cible: entree.nom
        }, HEADERS_SERVICE).then(rows => Array.isArray(rows) ? rows[0] : rows).catch(() => null);
        // UN AVIS DE RECHERCHE QUI NE S'INSCRIT PAS N'EST PAS UNE DESERTION ENREGISTREE : on le
        // dit, au lieu de laisser un deserteur libre de poursuites sans que personne le sache.
        if (!vRech || vRech.ok !== true) {
          signalerEchec('desertion_recherche:' + entree.nom,
                        (vRech && vRech.raison) || 'aucun verdict rendu');
        }
      }
    }
    if (modifie) {
      await sbUpdate('compagnies_militaires', `id=eq.${encodeURIComponent(r.id)}`,
        { data: c }).catch(() => {});
      // Cette fonction fait un read-modify-write du blob ENTIER pour ne changer qu'un statut de
      // requisition. Depuis que la position, le leader et les PA des soldats font autorite au socle
      // (27 septembre 2026), le blob n'en est qu'une projection : une reecriture globale a partir
      // d'une copie lue plus tot pourrait donc y remettre des valeurs perimees. La donnee
      // autoritaire, elle, ne risque rien -- le miroir n'importe plus ces axes. On se contente donc
      // de reprojeter, ce qui remet la copie d'affichage d'accord avec le socle sans rien decider.
      await sbRpc('militaire_blob_projeter', { p_compagnie: r.id }).catch(() => {});
    }
  }
}

// --- 5. EXPULSIONS DIPLOMATIQUES ECHUES --------------------------------------
// Miroir de verifierExpulsionsAmbassadeursQuotidien (plateau-politique.js). Le delai de 24 heures
// pose par l'expulsion doit courir meme si personne ne joue -- sinon l'ambassadeur declare persona
// non grata reste en poste indefiniment, et son ambassade demeure verrouillee hors des futures
// expulsions.
//
// L'AMBASSADE N'EST PAS FERMEE : seul l'ambassadeur s'en va, et l'echeance est effacee, ce qui
// deverrouille l'ambassade pour l'avenir. Sanctionner n'est pas rompre.
//
// IDEMPOTENCE PAR SUPPRESSION DU CHAMP : une echeance traitee disparait, le second passage ne
// trouve plus rien.
async function traiterExpulsionsAmbassadeursServeur(pays) {
  const rows = await sbGet('ambassades_ouvertes',
    `pays_hote=eq.${encodeURIComponent(pays)}`).catch(() => null);
  if (!rows) return;
  const maintenant = Date.now();
  for (const r of rows) {
    const data = r.data || {};
    const echeance = Number(data.expulsionEcheance);
    if (!isFinite(echeance) || echeance <= 0) continue;
    if (maintenant < echeance) continue;
    const nomExpulse = data.ambassadeur || null;
    const suite = Object.assign({}, data);
    delete suite.expulsionEcheance;
    suite.ambassadeur = null;
    suite.derniereExpulsion = { nom: nomExpulse, leTs: maintenant };
    const maj = await sbUpdate('ambassades_ouvertes', `id=eq.${encodeURIComponent(r.id)}`,
      { data: suite }).catch(() => null);

    // L'AVIS D'EXPULSION EST EMIS ICI (§5, 20 septembre 2026), plus par le client.
    // Il etait jusque-la envoye par verifierExpulsionsAmbassadeursQuotidien(), c'est-a-dire
    // depuis le navigateur d'un joueur quelconque -- celui qui passait minuit en premier --
    // sous l'en-tete « Ministere des Affaires Etrangeres ». Aucun de ces joueurs n'est
    // ministre : ce chemin ne survit pas a la fermeture de la tolerance des expediteurs, et
    // il produisait de toute facon un doublon avec cette passe. Le cron, lui, a l'autorite.
    // Envoi conditionne a la reussite de l'ecriture : on n'annonce pas une expulsion
    // qui n'a pas ete enregistree.
    if (nomExpulse && maj) {
      await envoyerMailSysteme(nomExpulse, 'Ministère des Affaires Étrangères',
        'Fin de mission — expulsion',
        'Le délai de 24 heures est écoulé. Votre mission diplomatique prend fin : vous n\'êtes plus ambassadeur et vous perdez l\'accès à l\'ambassade.'
      ).catch(() => {});
    }
  }
}

// --- 6. EXPIRATION DU REGIME D'EXCEPTION -------------------------------------
// Miroir serveur du moteur de mesures d'exception (plateau-gouvernement.js, section 4).
//
// LE MOTEUR EST DEJA SUR DU TEMPS REEL, ET FAIL-SAFE : mesuresActives() renvoie une liste VIDE des
// que l'echeance est passee, que quelqu'un se connecte ou non. Une mesure ne peut donc jamais
// produire d'effet au-dela de son terme, meme sans ce cron. Ce que ce passage ajoute, c'est la
// CLOTURE de l'etat stocke : sans lui, la ligne conserve actif:true pour toujours, et toute lecture
// qui regarde le drapeau plutot que l'echeance (un panneau d'etat, un futur ecran de Conseil)
// afficherait un regime d'exception perpetuel sur un pays qui n'en subit plus rien.
//
// DUREE_MESURES_EXCEPTION_MS_SERVEUR (3 jours reels) est desormais IMPORTEE du module
// genere, depuis plateau-gouvernement.js. DUREE_MAX_EXCEPTION_MS_SERVEUR a ete SUPPRIMEE au
// chantier 6, lot 1 (7 octobre 2026) : le commentaire qui l'accompagnait disait « la constante
// est MORTE -- rien ne la lit dans ce fichier. La supprimer est un nettoyage a part entiere » --
// c'est ce lot. Le plafond absolu de 9 jours reste applique par echeanceEffectiveServeur, qui le
// calcule depuis la duree importee.

// Echeance effective = MINIMUM de l'echeance courante et du plafond absolu. Copie conforme de
// echeanceEffective() : une prolongation ne peut jamais repousser le regime au-dela du 9e jour,
// y compris pour un regime anterieur au plafond relu depuis la base.
function echeanceEffectiveServeur(regime) {
  const r = regime || {};
  const e = Number(r.expireA);
  const p = Number(r.plafondA);
  if (!isFinite(e)) return null;
  return isFinite(p) ? Math.min(e, p) : e;
}

// IDEMPOTENCE PAR LE DRAPEAU LUI-MEME : une fois actif passe a false, le second passage ressort au
// premier test. Aucun marqueur de journee n'est necessaire -- et n'en serait pas un bon, puisque
// l'echeance est horaire, pas quotidienne.
//
// LE COUVRE-FEU ORDINAIRE DU MINISTRE DE L'INTERIEUR N'EST PAS TOUCHE : ce sont deux porteurs
// d'etat distincts (budgetNat.couvreFeu d'un cote, budgetNat.regimeException de l'autre), deux
// horloges distinctes. Lever l'un ne leve pas l'autre.
async function traiterExpirationRegimeExceptionServeur(pays) {
  const budget = await chargerBudgetNationalServeur(pays);
  if (!budget) return;
  const regime = budget.regimeException;
  if (!regime || regime.actif !== true) return;
  const fin = echeanceEffectiveServeur(regime);
  if (fin === null) return;
  if (Date.now() < fin) return;

  // On CLOT, on n'efface pas : mesures et compteur de prolongations sont conserves en trace, le
  // regime devient simplement inactif. Aucune mesure ne reprend et aucune manifestation ni greve
  // interrompue ne repart -- c'est la regle posee par sortManifestationSousRegime et
  // sortGreveSousRegime (reprendAutomatiquement: false).
  budget.regimeException = Object.assign({}, regime, {
    actif: false,
    mesures: [],
    mesuresALaFin: (regime.mesures || []).slice(),
    clotureA: fin,
    motifFin: 'echeance'
  });
  await sauverBudgetNationalServeur(pays, budget);
}

// ORDRE IMPERATIF : fiscalite (qui alimente gouvernement-min_def), PUIS virement vers la caserne,
// PUIS solde. Le meme ordre que runMidnightUpdate cote client.
async function traiterQuotidienNationalServeur(pays) {
  // La cascade porte desormais les DEUX niveaux : national puis ministeriel. Le virement
  // journalier vers la caserne n'est plus une tache separee -- c'est la part Defense -> Caserne
  // de la repartition declaree.
  await distribuerFiscaliteServeur(pays);
  await traiterExpirationRegimeExceptionServeur(pays);
  // Ces deux-la ne dependent d'aucun flux d'argent : leur position apres la solde est sans effet,
  // elles sont regroupees ici pour n'avoir qu'un seul point d'entree quotidien national.
  await traiterDesertionsServeur(pays);
  await traiterExpulsionsAmbassadeursServeur(pays);
}

// ============================================================================
// EFFORT DE GUERRE (13 septembre 2026) — TACHE NOCTURNE
// ============================================================================
// CE QUI RESTE RECOPIE ICI, ET POURQUOI (chantiers 4B et 4D).
// ENTREPOTS_EFFORT_SERVEUR, COUT_HORAIRE_TRAVAIL_SERVEUR, PA_PRODUCTION_ARMURERIE_SERVEUR et
// RECETTES_MILITAIRES_SERVEUR sont desormais importes du module genere -- cette derniere etait
// figee a 3 recettes sur 8 depuis le 18 septembre 2026, ce qui rendait les cinq accessoires
// incommandables en pratique ET faisait liberer chaque nuit le textile, le charbon et les
// fruits_legumes de la reserve strategique. Les deux constantes ci-dessous ne le sont pas :
//   DUREE_EFFORT_GUERRE_MS_SERVEUR  SUPPRIMEE au chantier 6, lot 1 : elle etait morte ;
//   VILLES_ARMURERIES_SERVEUR       ne connait que Republia -- lot 4G ;
// Les raisons sont tenues a jour dans outils/generateurs/referentiels-serveur.json.
// VILLES_ARMURERIES_SERVEUR EST SUPPRIMEE (chantier 4G, 7 octobre 2026). Meme constat que
// GREVE_VILLES_REPUBLIA_SERVEUR : une liste de vraies villes recopiee, et qui ne connaissait que
// Republia. Son lecteur passe par villesDeServeur(pays).
// Plafond de securite : borne le temps d'execution de la passe nocturne (le cron Vercel a une
// duree limitee). Ce qui n'est pas produit ce soir le sera demain -- une commande n'echoue jamais.
const LOTS_MILITAIRES_MAX_PAR_NUIT = 60;

function paTravailMilitaireServeur(produit) {
  const r = RECETTES_MILITAIRES_SERVEUR[produit];
  if (!r) return 0;
  return (typeof r.pa === 'number') ? r.pa : PA_PRODUCTION_ARMURERIE_SERVEUR;
}

function coutRevientLotMilitaireServeur(produit) {
  const r = RECETTES_MILITAIRES_SERVEUR[produit];
  if (!r) return 0;
  let total = 0;
  Object.keys(r.materiaux || {}).forEach(function (m) {
    const prix = (RESSOURCES_ECONOMIE_SERVEUR[m] && RESSOURCES_ECONOMIE_SERVEUR[m].prixBase) || 0;
    total += (Number(r.materiaux[m]) || 0) * prix;
  });
  return Math.round(total + paTravailMilitaireServeur(produit) * COUT_HORAIRE_TRAVAIL_SERVEUR);
}

function ressourcesMilitairesEligiblesServeur() {
  const vues = {};
  Object.keys(RECETTES_MILITAIRES_SERVEUR).forEach(function (p) {
    Object.keys(RECETTES_MILITAIRES_SERVEUR[p].materiaux || {}).forEach(function (m) { vues[m] = true; });
  });
  return Object.keys(vues).sort();
}

function effortActifServeur(effort) {
  if (!effort || effort.actif !== true) return false;
  const fin = Number(effort.expireA);
  if (!isFinite(fin)) return true;   // etat legacy sans echeance : on ne ferme jamais a l'aveugle
  return fin > Date.now();
}

// Stock national par ressource, lu sur les trois entrepots.
async function stocksNationauxEntrepots(pays) {
  const liste = ENTREPOTS_EFFORT_SERVEUR[pays] || [];
  const total = {};
  for (const e of liste) {
    const etat = await sbGetBatimentEtat(pays, e.city, e.building).catch(() => ({}));
    const stock = (etat && etat.entrepot && etat.entrepot.stock) || {};
    const reserve = (etat && etat.entrepot && etat.entrepot.reserveMilitaire) || {};
    Object.keys(stock).forEach(function (m) {
      if (!total[m]) total[m] = { stock: 0, reserve: 0 };
      total[m].stock += Math.max(0, Number(stock[m]) || 0);
      total[m].reserve += Math.max(0, Number(reserve[m]) || 0);
    });
  }
  return total;
}

// --- 1. EXPIRATION -----------------------------------------------------------
// IDEMPOTENCE PAR LE DRAPEAU LUI-MEME, comme le regime d'exception : une fois actif passe a
// false, le second passage ressort au premier test. Aucun marqueur de journee, l'echeance etant
// horaire et non quotidienne.
async function traiterExpirationEffortGuerreServeur(pays) {
  const budget = await chargerBudgetNationalServeur(pays);
  if (!budget) return { clos: false };
  const effort = budget.effortGuerre;
  if (!effort || effort.actif !== true) return { clos: false };
  if (effortActifServeur(effort)) return { clos: false };

  // Ordre volontaire, identique a la cloture volontaire cote client (cloturerEffortGuerre) :
  // liberer la matiere, annuler les reliquats, puis seulement clore le drapeau. Si la passe est
  // interrompue au milieu, le drapeau reste actif et tout sera rejoue proprement demain.
  const ent = ENTREPOTS_EFFORT_SERVEUR[pays] || [];
  if (ent.length) {
    await sbRpc('effort_reserve_appliquer', {
      p_pays: pays, p_entrepots: ent, p_ressources: ressourcesMilitairesEligiblesServeur(), p_pct: 0
    }, HEADERS_SERVICE).catch(() => null);
  }
  const cmds = await sbGet('commandes_militaires',
    `pays=eq.${encodeURIComponent(pays)}&statut=eq.en_cours&select=id`).catch(() => null);
  for (const c of (cmds || [])) {
    await sbUpdate('commandes_militaires', `id=eq.${encodeURIComponent(c.id)}`,
      { statut: 'annulee', updated_at: new Date().toISOString() }).catch(() => {});
  }

  const frais = await chargerBudgetNationalServeur(pays);
  if (!frais) return { clos: false };
  frais.effortGuerre = Object.assign({}, frais.effortGuerre || effort, {
    actif: false, finA: Date.now(), motifFin: 'echeance'
  });
  await sauverBudgetNationalServeur(pays, frais);
  return { clos: true, reliquatsAnnules: (cmds || []).length };
}

// --- 2. RESERVE STRATEGIQUE --------------------------------------------------
// Recalculee CHAQUE NUIT, apres les livraisons et la production des transformateurs : c'est ce
// qui fait que la reserve porte aussi sur les FLUX ENTRANTS, et pas seulement sur le stock
// present au moment ou le ministre a bouge son curseur.
async function traiterReserveMilitaireServeur(pays, effort) {
  const ent = ENTREPOTS_EFFORT_SERVEUR[pays] || [];
  if (!ent.length) return null;
  const pct = Math.max(0, Math.min(100, Number(effort.prioriteProductionMilitaire) || 0));
  return sbRpc('effort_reserve_appliquer', {
    p_pays: pays, p_entrepots: ent,
    p_ressources: ressourcesMilitairesEligiblesServeur(), p_pct: pct
  }, HEADERS_SERVICE).catch(() => null);
}

// --- 3. RAVITAILLEMENT -------------------------------------------------------
// Les denrees sont REELLEMENT ACHETEES au prix normal : la caisse de la caserne paie, celles des
// entrepots encaissent. Le ravitaillement achete sur le stock LIBRE (hors reserve de production).
// Viande et poisson sont equivalents : regle deterministe = viande d'abord, poisson pour le solde.
// PRIORITAIRE sur la production : il est appele avant elle, donc il se sert le premier dans une
// caisse insuffisante -- c'est exactement la regle « ravitaillement d'abord, production ensuite ».
async function traiterRavitaillementServeur(pays, effort) {
  const ent = ENTREPOTS_EFFORT_SERVEUR[pays] || [];
  const pct = Math.max(0, Math.min(100, Number(effort.prioriteRavitaillement) || 0));
  if (!ent.length || pct <= 0) return { achats: {}, total: 0 };

  const nat = await stocksNationauxEntrepots(pays);
  const libre = function (m) {
    const n = nat[m] || { stock: 0, reserve: 0 };
    return Math.max(0, n.stock - n.reserve);
  };
  const cibleCereales = Math.floor(libre('cereales') * pct / 100);
  const besoinProt = Math.floor((libre('viande') + libre('poisson')) * pct / 100);
  const cibleViande = Math.min(besoinProt, libre('viande'));
  const ciblePoisson = besoinProt - cibleViande;
  if (cibleCereales <= 0 && cibleViande <= 0 && ciblePoisson <= 0) return { achats: {}, total: 0 };

  const prix = {};
  ['cereales', 'viande', 'poisson'].forEach(function (m) {
    prix[m] = (RESSOURCES_ECONOMIE_SERVEUR[m] && RESSOURCES_ECONOMIE_SERVEUR[m].prixBase) || 0;
  });
  const rows = await sbRpc('effort_ravitailler', {
    p_pays: pays, p_entrepots: ent,
    p_cibles: { cereales: cibleCereales, viande: cibleViande, poisson: ciblePoisson },
    p_prix: prix
  }, HEADERS_SERVICE).catch(() => null);
  const r = Array.isArray(rows) ? rows[0] : rows;
  return r || { achats: {}, total: 0 };
}

// --- 4. PRODUCTION MILITAIRE -------------------------------------------------
// FIFO strict sur created_at. Chaque lot est produit par une RPC tout-ou-rien qui, dans une
// seule transaction : prend les matieres sur la RESERVE des entrepots, debite la caisse de la
// caserne du cout de revient, credite l'armurerie du MEME montant, livre le stock de la caserne
// avec son lot, avance la commande et inscrit la vente au registre.
//
// REPARTITION ENTRE LES TROIS ARMURERIES : rotation sur le nombre d'unites deja produites de la
// commande. C'est la regle « aussi equitable que possible » la plus simple qui reste juste quand
// la production s'etale sur plusieurs nuits -- la rotation reprend exactement ou elle en etait,
// sans etat supplementaire a stocker. Le statut PJ/PNJ du proprietaire ne change rien, et une
// armurerie detenue par le ministre participe normalement.
async function traiterProductionMilitaireServeur(pays, effort) {
  const ent = ENTREPOTS_EFFORT_SERVEUR[pays] || [];
  const villes = villesDeServeur(pays);
  const resultats = { lots: 0, unites: 0, arrets: [] };
  if (!ent.length || !villes.length) return resultats;
  if (Math.max(0, Number(effort.prioriteProductionMilitaire) || 0) <= 0) return resultats;

  const cmds = await sbGet('commandes_militaires',
    `pays=eq.${encodeURIComponent(pays)}&statut=eq.en_cours&order=created_at.asc&select=*`).catch(() => null);
  if (!cmds || !cmds.length) return resultats;

  // Etiquette de lot, pas une garde de rejeu -- alignee sur Europe/Paris par
  // coherence : une seule definition du jour dans tout le fichier.
  const jour = jourParisISO();
  for (const cmd of cmds) {
    const rec = RECETTES_MILITAIRES_SERVEUR[cmd.produit];
    if (!rec) continue;
    const cout = coutRevientLotMilitaireServeur(cmd.produit);
    let produitDansCetteCommande = Math.max(0, Number(cmd.quantite_produite) || 0);

    while (produitDansCetteCommande < cmd.quantite_demandee && resultats.lots < LOTS_MILITAIRES_MAX_PAR_NUIT) {
      const ville = villes[produitDansCetteCommande % villes.length];
      const armurerieId = 'armurerie-' + pays + '-' + ville;
      const lot = 'L' + jour.replace(/-/g, '') + '-' + ville + '-' + cmd.id.slice(-6) + '-' + produitDansCetteCommande;

      const rows = await sbRpc('effort_produire_lot', {
        p_pays: pays, p_commande_id: cmd.id, p_armurerie: armurerieId,
        p_entrepots: ent,
        p_recette: { materiaux: rec.materiaux, produitParLot: rec.produitParLot },
        p_cout_revient: cout, p_lot: lot,
        p_arme_label: rec.label, p_ville_arm: ville, p_jour: null
      }, HEADERS_SERVICE).catch(() => null);
      const r = Array.isArray(rows) ? rows[0] : rows;

      if (!r || r.ok !== true) {
        // Arret PROPRE : la commande reste 'en_cours', son reliquat attend la nuit suivante.
        // Aucune commande n'echoue jamais faute de matiere ou d'argent -- c'est la regle.
        if (r && r.raison) resultats.arrets.push({ commande: cmd.id, raison: r.raison });
        break;
      }
      resultats.lots += 1;
      resultats.unites += Math.max(1, Number(r.quantite) || 1);
      produitDansCetteCommande += Math.max(1, Number(r.quantite) || 1);
      await envoyerFactureMilitaireServeur(pays, armurerieId, ville, cmd.produit, r);
    }
    if (resultats.lots >= LOTS_MILITAIRES_MAX_PAR_NUIT) break;
  }
  return resultats;
}

// FACTURE AU PROPRIETAIRE. Le montant annonce ici EST le montant credite : les deux viennent du
// meme coutRevientLotMilitaireServeur, ils ne peuvent donc pas diverger. Un proprietaire PNJ ne
// recoit pas de courrier (il n'a pas de boite aux lettres) : la regle economique, elle, est
// identique pour lui.
async function envoyerFactureMilitaireServeur(pays, armurerieId, ville, produit, resultat) {
  const rows = await sbGet('entreprises', `id=eq.${encodeURIComponent(armurerieId)}&select=data`).catch(() => null);
  const data = rows && rows[0] ? rows[0].data : null;
  const proprio = data && data.proprietaire;
  if (!proprio || proprio === 'PNJ') return;

  const rec = RECETTES_MILITAIRES_SERVEUR[produit];
  const pa = paTravailMilitaireServeur(produit);
  const lignes = Object.keys(rec.materiaux || {}).map(function (m) {
    const prix = (RESSOURCES_ECONOMIE_SERVEUR[m] && RESSOURCES_ECONOMIE_SERVEUR[m].prixBase) || 0;
    const q = rec.materiaux[m];
    return '- ' + m + ' x' + q + ' a ' + prix + ' FR = ' + (q * prix) + ' FR';
  }).join('\n');
  const valeurMatieres = Object.keys(rec.materiaux || {}).reduce(function (s, m) {
    const prix = (RESSOURCES_ECONOMIE_SERVEUR[m] && RESSOURCES_ECONOMIE_SERVEUR[m].prixBase) || 0;
    return s + rec.materiaux[m] * prix;
  }, 0);
  const total = Number(resultat.cout) || 0;

  const corps =
    'Commande du Ministere de la Guerre — Effort de guerre.\n\n'
    + 'Produit : ' + rec.label + '\n'
    + 'Quantite produite : ' + (resultat.quantite || rec.produitParLot) + ' (lot ' + (resultat.lot || '') + ')\n'
    + 'Armurerie : ' + ville + '\n\n'
    + 'MATIERES PRISES EN CHARGE\n' + lignes + '\n'
    + 'Cout des matieres : ' + valeurMatieres + ' FR\n'
    + 'Travail : ' + pa + ' PA x ' + COUT_HORAIRE_TRAVAIL_SERVEUR + ' FR = ' + (pa * COUT_HORAIRE_TRAVAIL_SERVEUR) + ' FR\n'
    + 'Cout de revient : ' + total + ' FR\n'
    + 'Montant retrocede : ' + total + ' FR\n\n'
    + 'TOTAL CREDITE A VOTRE CAISSE : ' + total + ' FR\n\n'
    + 'La production et la livraison ont ete automatiques : vous n\'aviez rien a faire.';

  // LA FACTURE PASSE PAR LA BRIQUE (10 octobre 2026). Cet INSERT direct etait avale : une facture
  // qui ne partait pas ne laissait aucune trace, alors que la caisse du proprietaire venait d'etre
  // creditee. `p_heure: null` conserve exactement son champ `time` d'origine -- il n'en avait pas.
  await envoyerMailSysteme(proprio, 'Ministère de la Guerre',
    'Facture — commande militaire (' + rec.label + ')', corps, null);
}

// --- ORCHESTRATION -----------------------------------------------------------
// ORDRE IMPERATIF : expiration d'abord (un Effort echu ne doit rien produire ce soir), puis
// reserve (elle conditionne les matieres disponibles a la production), puis ravitaillement
// (prioritaire sur la caisse), puis production (elle se sert de ce qui reste).
async function traiterEffortDeGuerreServeur(pays) {
  const expiration = await traiterExpirationEffortGuerreServeur(pays);
  const budget = await chargerBudgetNationalServeur(pays);
  const effort = budget && budget.effortGuerre;
  if (!effortActifServeur(effort)) return { actif: false, expiration: expiration };

  const reserve = await traiterReserveMilitaireServeur(pays, effort);
  const ravitaillement = await traiterRavitaillementServeur(pays, effort);
  const production = await traiterProductionMilitaireServeur(pays, effort);
  return { actif: true, expiration: expiration, reserve: !!reserve,
           ravitaillement: ravitaillement, production: production };
}

// Titulaire ACTUEL des murs d'un bail, lu sur le terrain porteur -- jamais sur une valeur figee
// dans le bail. C'est la meme regle que celle appliquee par prelever_loyer_bail pour choisir le
// beneficiaire : vendre les murs transfere les loyers a venir, sans toucher au bail.
// Renvoie null pour un bailleur qui n'est pas un PJ (municipalite, organisation) : ce sont des
// caisses, pas des boites aux lettres.
async function titulaireMursDuBail(data) {
  if (!data || !data.buildingId) return null;
  const dest = data.destinationLoyer || {};
  if (dest.type && dest.type !== 'titulaire_murs') return null;
  let titulaire = dest.titulaire || null;
  if (!titulaire) {
    // LE PAYS DU BAIL NE SE DEVINE PAS (chantier 4G, 8 octobre 2026). Cette lecture ecrivait
    // `data.country || 'republic'` : un bail dont le pays manquait faisait chercher le terrain
    // de MEME buildingId en Republia -- et les identifiants de batiment sont partages entre les
    // quatre empires. Le proprietaire ainsi trouve pouvait donc etre un joueur de Republia, a qui
    // le cron aurait envoye le courrier de loyer d'un bail d'un autre empire. On rend null : pas
    // de pays, pas de titulaire, pas de courrier -- et le loyer lui-meme n'est pas concerne, la
    // RPC prelever_loyer_bail derivant sa destination par ses propres moyens.
    if (!VILLES_SERVEUR[data.country]) return null;
    const rows = await sbGet('terrains_etat',
      `country=eq.${encodeURIComponent(data.country)}&building_id=eq.${encodeURIComponent(data.buildingId)}`).catch(() => null);
    if (rows && rows[0]) {
      try { titulaire = (JSON.parse(rows[0].data) || {}).proprietaire || null; } catch (e) { titulaire = null; }
    }
  }
  if (!titulaire) return null;
  if (titulaire.slice(0, 5) === 'orga:') return null;      // une organisation n'a pas de courrier
  return titulaire.slice(0, 3) === 'pj:' ? titulaire.slice(3) : titulaire;
}

async function preleverLoyersBaux() {
  const resultats = { examines: 0, payes: 0, collecte: 0, avertissements: 0, impayes: 0,
                      ignores: 0, erreurs: 0 };
  // FAIL-CLOSED sur l'identite serveur : la RPC n'est executable que par service_role (voir
  // migration_loyers_unifies_lot14.sql). Sans la variable d'environnement, on n'envoie meme pas
  // la requete -- elle echouerait en 401 de toute facon, mais on trace la cause exacte plutot
  // qu'un compteur d'erreurs opaque. Aucun argent ne bouge : rien n'est prelevé, rien n'est perdu.
  if (!SUPABASE_SERVICE_ROLE) {
    console.error('preleverLoyersBaux : SUPABASE_SERVICE_ROLE_KEY absente, aucun loyer preleve');
    resultats.erreurs++;
    return resultats;
  }
  try {
    const baux = await sbGet('locations_actives', '');
    if (!baux) return resultats;

    for (const row of baux) {
      const data = row.data || {};
      resultats.examines++;

      // Ancien bail exclusif de l'entrepot portuaire : resilie sans frais par le client
      // (payerLocations, traitement one-shot). Jamais preleve ici.
      if (data.buildingId === 'port-sainte-marie' && data.roomId === 'entrepot' && data.isBox !== true) {
        resultats.ignores++;
        continue;
      }

      const verdictRows = await sbRpc('prelever_loyer_bail', { p_bail_id: row.id }, HEADERS_SERVICE);
      // sbRpc renvoie null en cas d'echec HTTP (RPC absente, exception PL/pgSQL). Une exception
      // signifie que la transaction a ete ANNULEE : ni debit, ni credit.
      if (verdictRows === null) { resultats.erreurs++; continue; }
      const verdict = Array.isArray(verdictRows) ? verdictRows[0] : verdictRows;

      if (verdict === 'paye') {
        resultats.payes++;
        resultats.collecte += Number(data.prix) || 0;
      } else if (verdict === 'avertissement') {
        resultats.avertissements++;
        await envoyerMailSysteme(data.locataire, 'Gestionnaire immobilier', 'Loyer impayé — ' + (data.localLabel || 'votre local'), 'Votre loyer de ' + (data.prix || 0) + ' FR pour ' + (data.localLabel || 'votre local')
                 + " n'a pas pu être prélevé. Régularisez sous 24h ou vous serez expulsé(e).").catch(() => {});
      } else if (verdict === 'expulsion_requise' || verdict === 'expulsion_requise_deja_avise') {
        // IMPAYE CONSTATE, JAMAIS D'EXPULSION AUTOMATIQUE (arbitrage du 8 septembre 2026).
        //
        // Ce cron SUPPRIMAIT le bail a minuit apres un seul avertissement : le locataire perdait
        // son local pendant son sommeil, sans procedure, sans recours et sans que personne ne
        // decide rien. Un impaye n'est plus une cause de resiliation automatique -- c'est un FAIT
        // qu'on constate, qu'on chiffre et qu'on conserve. Il ouvre au bailleur la meme voie de
        // recuperation que n'importe quel autre motif (accord amiable ou justice) ; il ne la
        // remplace pas.
        //
        // L'ARDOISE EST CALCULEE ET POSEE PAR LA RPC DEPUIS LE 9 OCTOBRE 2026, et ce bloc ne
        // l'ecrit plus. Il la calculait ici, puis reecrivait le bail avec `{ ...data, impaye }`
        // -- or `data` avait ete lu AVANT l'appel de la RPC. Deux consequences, et la seconde
        // etait la pire :
        //   . la branche « expulsion_requise » etait la seule sortie a effet de la RPC a ne pas
        //     poser `jourPaiement`, donc un rejeu du cron la meme nuit rendait de nouveau ce
        //     verdict et la dette DOUBLAIT ;
        //   . et meme une fois le marqueur pose cote SQL, cette reecriture du blob entier
        //     depuis une lecture perimee l'aurait efface dans la foulee.
        // La revendication et l'effet sont donc descendus ENSEMBLE dans la RPC, qui est une
        // seule transaction et lit le bail FOR UPDATE. Migration 20261009005012.
        //
        // Il ne reste ici que le courrier, qui n'est pas un effet comptable, et le verdict dit
        // lequel des deux cas on a : `expulsion_requise` = l'ardoise vient de s'ouvrir, avis a
        // poster ; `expulsion_requise_deja_avise` = elle courait deja, silence.
        // Aucun argent ne bouge -- le loyer n'a pas ete preleve, il reste du.
        resultats.impayes++;

        // Un seul courrier a l'ouverture de l'ardoise, puis silence : le bailleur consulte l'etat
        // du bail quand il veut, on n'inonde pas deux boites tous les soirs.
        if (verdict === 'expulsion_requise') {
          await envoyerMailSysteme(data.locataire, 'Gestionnaire immobilier', 'Loyer impaye — ' + (data.localLabel || 'votre local'), 'Votre loyer sur ' + (data.localLabel || 'votre local') + " n'est plus paye et la dette s'accumule."
                   + " Votre bail reste en vigueur : vous n'etes pas expulse. Le proprietaire peut toutefois engager"
                   + ' une procedure de recuperation du local. Regularisez pour l\'eviter.').catch(() => {});
          const bailleur = await titulaireMursDuBail(data).catch(() => null);
          if (bailleur) {
            await envoyerMailSysteme(bailleur, 'Gestionnaire immobilier', 'Loyer impaye — ' + (data.localLabel || 'votre local'), (data.locataire || 'Votre locataire') + ' ne paie plus le loyer de '
                     + (data.localLabel || 'votre local') + '. La dette est enregistree et continue de courir.'
                     + ' Le bail n\'est pas resilie automatiquement : il vous appartient de trouver un accord'
                     + ' ou d\'engager une procedure de recuperation.').catch(() => {});
          }
        }
      } else {
        resultats.ignores++;
      }
    }
  } catch(e) { console.error('preleverLoyersBaux error', e); }
  return resultats;
}


async function libererMiroirSubdivision(country, buildingId, lotId) {
  try {
    const rows = await sbGet('terrains_etat',
      `country=eq.${encodeURIComponent(country)}&building_id=eq.${encodeURIComponent(buildingId)}`);
    const row = rows && rows[0];
    if (!row) return false;
    let etat; try { etat = JSON.parse(row.data); } catch(e) { return false; }
    const subdivisions = Array.isArray(etat.subdivisions) ? etat.subdivisions : [];
    const lot = subdivisions.find(l => l && l.id === lotId);
    if (!lot || !lot.locataire) return false;
    lot.locataire = null;
    etat.subdivisions = subdivisions;
    await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`,
      { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
    return true;
  } catch(e) { return false; }
}

// =====================
// COTISATIONS NON ETERNELLES — club de supporters + Syndicat des Dockers de PSM (lot logistique
// portuaire, 25 aout 2026, §13). Principe valide : adhesion = 50 FR pour les deux (rejoindre_
// club_supporters passe de 150 a 50 FR pour rester coherent avec ce meme principe, voir data.js).
// Renouvellement JAMAIS eternel : supporters = a chaque nouveau championnat (evenement reel, lu
// directement sur saison.numero, pas un decompte de jours approximatif) ; syndicat = tous les 3
// mois reels (calendaire, pas un nombre de jours de jeu -- state.day est un compteur PROPRE A
// CHAQUE PERSONNAGE cote client, inutilisable pour comparer des joueurs entre eux, voir
// formatDateHeureJeu/dateReelleParisStr, plateau-core.js). Execute cote serveur/cron (comme
// preleverLoyersLots ci-dessus, meme pattern exact pour debiter le FR PERSONNEL d'un joueur
// potentiellement deconnecte) : jamais depend d'un client connecte. Si le FR manque au moment du
// renouvellement : fin d'adhesion automatique, aucune dette creee (le membre est simplement
// retire de orga.membres).
const COTISATION_MONTANT = 50;
const COTISATION_SYNDICAT_MOIS = 3;
const ID_SYNDICAT_DOCKERS_PSM = 'orga_syndicat_dockers_republic_ville_a';
// CLUBS_SPORTIFS_SERVEUR est importee du module genere : une projection de CLUBS_SPORTIFS
// (data.js) sur id/country/city/nom. Son `nom` part en clair dans les messages de Journal de
// traiterLicencesSportivesSaison, et c'est pour cela qu'il doit venir de data.js plutot que d'une
// copie -- le 5 septembre 2026, une copie perimee a publie des noms de clubs qui n'existaient plus.
// DEPUIS LE 10 OCTOBRE 2026, elle ne sert plus a retrouver la caisse d'un club a partir de
// (country, city) : cette resolution a suivi le credit dans cotisation_renouveler, qui lit
// `clubs_football` -- le miroir SQL genere de CLUBS_SPORTIFS, surveille par une empreinte. Ici, on
// ne la consulte plus que par identifiant de licence.

// Ligne canonique du championnat -- doit rester synchronisee avec CHAMPIONNAT_ROW_ID
// (supabase.js). Deplacee de id=1 vers id=2 le 5 septembre 2026, voir supabase.js.
const CHAMPIONNAT_FILTRE_ID = 'id=eq.2';

// crediterBudgetClubServeur A ETE SUPPRIMEE (chantier 6, famille D, 10 octobre 2026). Elle etait
// une lecture-modification-ecriture de budgets_clubs avec ses deux catch avales, et son unique
// appelant etait la branche 'supporters' de renouvellerCotisationsOrganisations. Le credit de la
// caisse du club vit desormais DANS cotisation_renouveler, dans la meme transaction que le debit
// du membre. Aucune autre passe ne la nommait : elle est partie avec son appelant plutot que de
// rester une seconde maniere de crediter un club.

async function renouvellerCotisationsOrganisations() {
  const resultats = { renouvellements: 0, resiliations: 0 };
  try {
    const rows = await sbGet('organisations', 'select=*');
    if (!rows) return resultats;
    const saisonRows = await sbGet('championnat', CHAMPIONNAT_FILTRE_ID + '&select=data');
    let saisonActuelle = null;
    if (saisonRows && saisonRows[0]) {
      try { saisonActuelle = JSON.parse(saisonRows[0].data); } catch(e) { saisonActuelle = null; }
    }
    const maintenant = Date.now();

    for (const row of rows) {
      let orga;
      try { orga = JSON.parse(row.data); } catch(e) { continue; }
      // Perimetre de ce lot : le club de supporters (adhesion 150->50 FR, renouvellement par
      // saison) et le seul Syndicat des Dockers de PSM (renouvellement tous les 3 mois). Les
      // autres organisations 'syndicale' (moteur generique orga_*, fondees par des PJ) ne sont
      // pas concernees -- aucune mecanique de cotisation validee pour elles dans ce lot.
      const estSyndicatDockersPSM = orga.type === 'syndicale' && orga.id === ID_SYNDICAT_DOCKERS_PSM;
      if (orga.type !== 'supporters' && !estSyndicatDockersPSM) continue;
      if (!orga.membres || orga.membres.length === 0) continue;

      // LA DETTE CONSIGNEE LE 7 OCTOBRE EST PAYEE (chantier 6, famille D, 10 octobre 2026).
      //
      // CE QUI SE PASSAIT ICI. Une cotisation etait TROIS requetes HTTP : debit du membre
      // (sbUpdate personnages), credit de la contrepartie (crediterBudgetClubServeur, elle-meme
      // une lecture-modification-ecriture avec catch avale, ou orga.caisse en memoire), puis
      // ecriture du blob portant le marqueur. Le code le disait lui-meme : « Debiter un personnage
      // et marquer son adhesion sont deux ecritures sur deux tables : les rendre atomiques demande
      // une RPC. Dette consignee. » Une panne au milieu laissait 50 FR sortis du personnage sans
      // arriver nulle part, ou une adhesion payee mais non marquee, donc redebitee la nuit
      // suivante. Tout l'echafaudage qui bornait cette perte -- marqueur pose apres chaque membre,
      // instantane de la liste, persistanceRompue qui interrompait l'organisation -- existait
      // uniquement parce que l'acte n'etait pas atomique. Il disparait avec la cause.
      //
      // CE QUI RESTE ICI, ET SEULEMENT CELA : qui est DU. La regle d'echeance est inchangee --
      // supporters a chaque nouvelle saison lue sur saison.numero, syndicat tous les trois mois
      // calendaires -- et c'est bien une decision d'appelant. cotisation_renouveler, elle, rend
      // l'acte indivisible : verrou sur l'organisation, verrou sur la fiche, puis debit + marqueur
      // + credit de la contrepartie ensemble, ou rien. Le marqueur metier (derniereCotisationSaison
      // / derniereCotisationDate) reste le verrou d'idempotence : la brique actes_nocturnes serait
      // un second verrou pour le meme travail.
      //
      // Le courrier de fin d'adhesion part de la porte, par mail_systeme_poser_interne, avec le
      // meme sujet, le meme corps et le meme horodatage ISO qu'avant.
      for (const membre of orga.membres) {
        let doitRenouveler = false;
        if (orga.type === 'supporters') {
          doitRenouveler = !!saisonActuelle && membre.derniereCotisationSaison !== saisonActuelle.numero;
        } else if (membre.derniereCotisationDate) {
          const echeance = new Date(membre.derniereCotisationDate);
          echeance.setMonth(echeance.getMonth() + COTISATION_SYNDICAT_MOIS);
          doitRenouveler = maintenant >= echeance.getTime();
        }

        if (!doitRenouveler) continue;

        const etape = 'cotisation:' + row.id + ':' + membre.nom;
        const v = await sbRpc('cotisation_renouveler', {
          p_orga_id: row.id, p_membre: membre.nom,
          p_saison: orga.type === 'supporters' ? saisonActuelle.numero : null
        }, HEADERS_SERVICE).then(r => Array.isArray(r) ? r[0] : r).catch(() => null);

        // AUCUN VERDICT N'EST JAMAIS UN SUCCES : sans reponse de la porte, on ne sait pas si le
        // membre a paye, et on ne le compte pas.
        if (!v) { signalerEchec(etape, 'aucun verdict rendu'); continue; }
        if (v.ok !== true) {
          // Ces deux refus ne sont pas des echecs : la liste lue en debut de passe peut avoir
          // vieilli (organisation dissoute, membre parti entre-temps).
          if (v.action !== 'organisation_introuvable' && v.action !== 'membre_introuvable') {
            signalerEchec(etape, v.action || 'refus sans motif');
          }
          continue;
        }
        if (v.action === 'renouvellement') resultats.renouvellements++;
        else if (v.action === 'resiliation') resultats.resiliations++;
        else signalerEchec(etape, 'verdict sans action : ' + JSON.stringify(v));
      }
    }
  } catch(e) { console.error('renouvellerCotisationsOrganisations error', e); }
  return resultats;
}

// =====================
// LICENCES SPORTIVES SAISONNIERES (lot du 25 aout 2026, correctif groupe football)
// =====================
// Prix aligne sur COUT_LICENCE_SPORTIVE (plateau-organisations-quetes.js) -- duplique ici car le
// cron tourne dans un contexte serveur isole, sans acces aux constantes client (meme raison que
// COTISATION_MONTANT ci-dessus).
const LICENCE_SPORTIVE_MONTANT = 150;

// Point SERVEUR unique de renouvellement/non-renouvellement/fin d'annee blanche des licences
// sportives -- deliberement PAS declenche cote client (contrairement a demarrerNouvelleSaison,
// plateau-organisations-quetes.js, qui reste hors perimetre de ce lot) : plusieurs clients
// connectes en meme temps ne doivent jamais pouvoir faire executer un renouvellement/prelevement
// deux fois. Idempotence assuree par licence_sportive.derniereSaisonTraitee, compare au numero de
// la saison persistee (table championnat, id=1) -- exactement le meme principe que
// membre.derniereCotisationSaison ci-dessus pour les cotisations d'organisations. Ce cron tourne
// une fois par jour (vercel.json) ; le traitement reste donc a jour au plus tard le lendemain
// d'un vrai changement de saison, sans jamais pouvoir le rejouer deux fois pour la meme saison.
//
// Machine a etats par personnage (licence_sportive.statut) :
//  - absent/'active'  : licence normale. Si nonRenouvellement===true -> bascule en 'anneeBlanche'
//                       sans prelevement. Sinon, renouvellement tacite dans le meme club (debit
//                       LICENCE_SPORTIVE_MONTANT si les fonds suffisent, sinon 'impaye').
//  - 'impaye'          : rattachement conserve au club d'origine, JAMAIS traite automatiquement
//                        (le joueur ne redevient jamais libre a cause d'un impaye -- il doit
//                        reprendre lui-meme sa licence dans ce meme club, voir
//                        doPrendreLicenceSportive). derniereSaisonTraitee n'avance donc pas ici.
//  - 'anneeBlanche'    : ce statut signifie qu'une saison blanche vient de s'ecouler (puisque
//                        derniereSaisonTraitee, fixe au moment du basculement, differe desormais
//                        du numero de saison courant) -- liberation totale + performance divisee
//                        par deux (Math.round, seule convention numerique deja utilisee pour les
//                        stats de performance dans ce systeme).
async function traiterLicencesSportivesSaison() {
  const resultats = { renouvellements: 0, impayes: 0, nonRenouvellements: 0, finsAnneeBlanche: 0, migrations: 0 };
  try {
    const saisonRows = await sbGet('championnat', CHAMPIONNAT_FILTRE_ID + '&select=data');
    let saisonActuelle = null;
    if (saisonRows && saisonRows[0]) {
      try { saisonActuelle = JSON.parse(saisonRows[0].data); } catch(e) { saisonActuelle = null; }
    }
    if (!saisonActuelle) return resultats; // championnat pas encore initialise, rien a traiter

    const rows = await sbGet('personnages', 'licence_sportive=not.is.null&select=name,arg,day,journal,performance_sportive,licence_sportive');
    if (!rows) return resultats;

    for (const perso of rows) {
      const lic = perso.licence_sportive;
      if (!lic) continue;

      // Migration silencieuse (bootstrap) : une licence achetee avant ce lot n'a pas encore de
      // marqueur de saison. On l'aligne sur la saison actuelle SANS la traiter comme un
      // changement de saison reel (aucun prelevement, aucun message le jour du deploiement) --
      // elle sera traitee normalement au VRAI prochain changement de saison.
      if (lic.derniereSaisonTraitee === undefined) {
        await sbUpdate('personnages', `name=eq.${encodeURIComponent(perso.name)}`, {
          licence_sportive: { ...lic, statut: lic.statut || 'active', derniereSaisonTraitee: saisonActuelle.numero }
        }).catch(() => {});
        resultats.migrations++;
        continue;
      }

      if (lic.derniereSaisonTraitee === saisonActuelle.numero) continue; // deja traite pour cette saison (idempotence)

      const statutActuel = lic.statut || 'active';
      if (statutActuel === 'impaye') continue; // rattachement indefiniment conserve, aucun traitement automatique

      const patch = {};
      let journalTexte = null;

      if (statutActuel === 'anneeBlanche') {
        const perf = perso.performance_sportive || { defense: 0, technique: 0, endurance: 0 };
        patch.performance_sportive = {
          defense: Math.round((perf.defense || 0) / 2),
          technique: Math.round((perf.technique || 0) / 2),
          endurance: Math.round((perf.endurance || 0) / 2)
        };
        patch.licence_sportive = null;
        journalTexte = "Votre saison blanche est terminée : vous pouvez de nouveau prendre une licence sportive dans le club de votre choix. Votre niveau sportif a diminué (performance divisée par deux).";
        resultats.finsAnneeBlanche++;
      } else if (lic.nonRenouvellement === true) {
        patch.licence_sportive = { statut: 'anneeBlanche', derniereSaisonTraitee: saisonActuelle.numero };
        const club = CLUBS_SPORTIFS_SERVEUR.find(c => c.id === lic.clubId);
        journalTexte = 'Conformément à votre demande, votre licence sportive au ' + (club?.nom || 'club') + " n'a pas été renouvelée. Vous devrez attendre la saison suivante avant de pouvoir reprendre une licence.";
        resultats.nonRenouvellements++;
      } else {
        const club = CLUBS_SPORTIFS_SERVEUR.find(c => c.id === lic.clubId);
        if ((perso.arg || 0) >= LICENCE_SPORTIVE_MONTANT) {
          patch.arg = (perso.arg || 0) - LICENCE_SPORTIVE_MONTANT;
          patch.licence_sportive = { ...lic, statut: 'active', derniereSaisonTraitee: saisonActuelle.numero };
          journalTexte = 'Votre licence sportive au ' + (club?.nom || 'club') + ' a été renouvelée pour la nouvelle saison. ' + LICENCE_SPORTIVE_MONTANT + ' FR ont été prélevés.';
          resultats.renouvellements++;
        } else {
          patch.licence_sportive = { ...lic, statut: 'impaye', derniereSaisonTraitee: saisonActuelle.numero };
          journalTexte = 'Votre licence sportive au ' + (club?.nom || 'club') + " n'a pas pu être renouvelée faute de fonds suffisants. Vous pouvez reprendre une licence dans ce club dès que vous disposez de " + LICENCE_SPORTIVE_MONTANT + ' FR. Un transfert reste nécessaire pour rejoindre un autre club.';
          resultats.impayes++;
        }
      }

      if (journalTexte) {
        const journalActuel = Array.isArray(perso.journal) ? perso.journal.slice() : [];
        journalActuel.unshift({ day: perso.day || 1, hour: 8, text: journalTexte, cls: 'event-info', ts: new Date().toISOString() });
        if (journalActuel.length > 120) journalActuel.length = 120;
        patch.journal = journalActuel;
      }

      await sbUpdate('personnages', `name=eq.${encodeURIComponent(perso.name)}`, patch).catch(() => {});
    }
  } catch(e) { console.error('traiterLicencesSportivesSaison error', e); }
  return resultats;
}

// FUITES SPONTANEES DES SOUVENIRS DE L'ACCUEIL — 5 a 10 % par jour et par souvenir.
//
// TROIS DEFAUTS FERMES ICI (chantier 6, 7 octobre 2026).
//
// 1. C'ETAIT LA SEULE TACHE DU FICHIER SANS AUCUN GARDE-FOU. Ni registre de journee, ni
//    marqueur sur la donnee. Chaque passe relancait un TIRAGE par souvenir : deux executions
//    dans la meme nuit doublaient la probabilite de fuite, et chaque fuite insere un
//    `evenements_globaux` « SCANDALE » nominatif -- irreversible. Son appel passe desormais par
//    tacheQuotidienne(), comme les dix-sept autres : marqueur pose AVANT l'effet, relu pour
//    verifier sa persistance, et la tache ne tourne pas si le marqueur n'a pas pris.
//
// 2. LE MARQUAGE `revele: true` N'ETAIT PAS VERIFIE. Un `fetch` PATCH brut sans lecture de
//    `res.ok` : le scandale pouvait etre annonce publiquement alors que le souvenir restait
//    `revele: false`, donc re-tirable la nuit suivante. Le meme joueur pouvait voir le meme
//    secret fuiter deux fois. On n'annonce plus rien avant que le marquage ait abouti.
//
// 3. LA LECTURE AVALAIT SON ECHEC. `if (!res.ok) return resultats;` rendait `{fuites: 0}`, ce
//    qui ne se distingue pas de « aucune fuite cette nuit ». L'echec remonte desormais dans
//    ECHECS_PASSE comme pour toutes les autres lectures du fichier.
//
// `resultats.expires` ET `aujourdHui` ONT ETE RETIRES. Le compteur etait declare et jamais
// incremente, et la variable calculee puis jamais lue : le « nettoyage des souvenirs expires »
// qu'annoncaient le nom de la tache et son commentaire d'appel N'EXISTE PAS -- un commentaire
// interne disait lui-meme « on ignore silencieusement ». Construire ce nettoyage est une
// decision de game design (que devient un souvenir de plus de 12 jours ?), pas du menage.
// LE QUATRIEME DEFAUT, ET C'ETAIT LE DERNIER DU CHANTIER 6 (10 octobre 2026).
//
// Les trois corrections ci-dessus tenaient, mais le §4 de l'audit canonique le disait sans
// detour : SON SEUL REMPART ETAIT LE REGISTRE `joursCron` -- une ligne unique, lue-fusionnee-
// reecrite sans atomicite, ecrite et relue dix-huit fois par nuit. « La frontiere devrait etre LE
// SOUVENIR -- une colonne jour_tirage -- pas la passe. »
//
// Et trois choses restaient fausses ici meme. (1) Le marquage n'etait pas un compare-and-swap :
// `id=eq.X` sans `revele=eq.false`, donc deux marquages concurrents reussissent tous les deux et
// chacun annonce son scandale. (2) Le tirage vivait dans ce navigateur, avant toute ecriture
// autoritaire. (3) Le marquage et l'annonce etaient deux requetes HTTP.
//
// `souvenir_accueil_tirer` fait les trois dans une transaction, sous verrou de ligne, et
// `jour_tirage` est la frontiere exacte que l'audit reclamait : un souvenir est tire au plus une
// fois par journee, QUE LE REGISTRE AIT TENU OU NON. La probabilite (5 a 10 %), le texte du
// scandale, son pays, sa ville et son jour sont inchanges.
//
// La liste est toujours lue ici : choisir QUELS souvenirs presenter n'est pas une autorite, et la
// porte refuse d'elle-meme ceux qui ont deja ete tires ou reveles entre-temps.
async function traiterSouvenirsAccueil() {
  const resultats = { fuites: 0, deja_tires: 0, refus: 0 };
  const souvenirs = await sbGet('souvenirs_accueil', 'revele=eq.false');
  if (!souvenirs) return resultats;   // sbGet a deja signale l'echec

  // jourParisISO() est la SEULE definition du jour de ce fichier depuis le 20 septembre 2026, et
  // le cron est le seul ecrivain de `jour_tirage` : on n'en invente pas une seconde.
  const jour = jourParisISO();
  for (const s of souvenirs) {
    const v = await sbRpc('souvenir_accueil_tirer', { p_souvenir_id: s.id, p_jour: jour },
                          HEADERS_SERVICE)
      .then(rows => Array.isArray(rows) ? rows[0] : rows).catch(() => null);
    // AUCUN VERDICT N'EST JAMAIS UNE FUITE. Sans reponse, on ne sait pas si le scandale est
    // parti, et on ne le compte pas.
    if (!v) { signalerEchec('souvenir:' + s.id, 'aucun verdict rendu'); resultats.refus++; continue; }
    if (v.ok !== true) { signalerEchec('souvenir:' + s.id, v.raison || 'refus sans motif');
                         resultats.refus++; continue; }
    if (v.action === 'fuite') resultats.fuites++;
    else if (v.action === 'deja_tire' || v.action === 'deja_revele') resultats.deja_tires++;
  }
  return resultats;
}

// =====================
// CASCADE DE NOMINATION AUTOMATIQUE — quand un poste nomme reste vacant parce que l'autorite
// censee le pourvoir est elle-meme absente (PJ ou PNJ), on installe le PNJ par defaut plutot
// que de bloquer indefiniment les mecaniques qui en dependent (plan du 8 aout 2026). Perimetre
// volontairement restreint : president->pm->[6 ministeres]->juge (via min_just), et maire->
// commissaire (par ville). N'inclut PAS commandant ni les directeurs d'usine/entrepot, deja
// fonctionnels sans titulaire. Republia uniquement pour l'instant, comme le reste du systeme
// fiscal/electoral (voir meme choix dans plateau-justice-economie.js).
// =====================
const PAYS_CASCADE = 'republic';
const VILLES_CASCADE = ['capitale', 'ville_a', 'ville_b'];

const PNJ_PAR_DEFAUT_POSTE = {
  president:   'Le Président (PNJ)',
  maire:       'Le Maire (PNJ)',
  pm:          'Le Premier Ministre (PNJ)',
  min_int:     "Le Ministre de l'Intérieur (PNJ)",
  min_fin:     'Le Ministre des Finances (PNJ)',
  min_just:    'Le Ministre de la Justice (PNJ)',
  // Martial Bouterin (19 septembre 2026) : le PNJ du ministere a desormais une identite, comme
  // le Juge Fontaine et le Commandant Tom Hawak. Renommer ICI est indispensable -- sans quoi le
  // cron restaurerait l'ancien libelle generique des que le poste redeviendrait vacant.
  min_def:     'Martial Bouterin (PNJ)',
  min_info:    "Le Ministre de l'Information (PNJ)",
  min_ae:      'Le Ministre des Affaires Étrangères (PNJ)',
  commissaire: 'Raoul Toufaud (PNJ)',
  // Commandant et les 3 directeurs d'usine ajoutes le 10 aout 2026 (chantier "priorite PJ",
  // point 2 du backlog). Reutilise les PNJ deja en poste dans chaque batiment (data.js) plutot
  // que d'inventer des noms, sauf Commandant qui n'en avait pas encore.
  commandant:              'Commandant Tom Hawak',
  directeur_pharma:        'Bernard Piluler (PNJ)',
  directeur_tabac_alcools: 'Fernand Cendrier (PNJ)',
  directeur_raffinerie:    'Gustave Baril (PNJ)',
  // Chef des Douanes (lot du 24 aout 2026) : deja en poste dans data.js (persons de la room
  // douanes, port-sainte-marie), meme convention que commissaire/directeurs -- reutilise le nom
  // deja affiche plutot que d'en inventer un second.
  chef_douanes:            'Pascal Paguevite (PNJ)',
  // Commandant du Port (lot logistique portuaire, 25 aout 2026) : deja en poste dans data.js
  // (persons de administration_portuaire, port-sainte-marie), meme convention. A la difference
  // de chef_douanes, capitaine_port n'est PAS dans POSTES_UNIQUES_A_MASQUER (plateau-
  // multijoueur.js) : Marcel Ancre reste visible dans la room meme une fois qu'un PJ est nomme.
  capitaine_port:          'Marcel Ancre (PNJ)'
};

// Directeur d'entrepot (scope:ville, nomme par le maire) : un PNJ different par ville, deja en
// poste dans chaque entrepot (data.js) -- traite dans la boucle par ville ci-dessous, pas dans
// CASCADE_NATIONALE (national uniquement).
// UN JUGE PAR TRIBUNAL (arbitrage GD du 20 septembre 2026). Le juge a quitte
// CASCADE_NATIONALE : il n'existe plus de juge national. Les trois noms ci-dessous ne
// sont PAS inventes -- ce sont les juges PNJ deja presents dans data.js, chacun dans le
// tribunal de sa ville (Juge Fontaine a Luthecia, Mireille Sedlex a Port-Sainte-Marie,
// Gerard Bretellewood a Montrouge). Meme idiome que les directeurs d'entrepot.
const PNJ_JUGE_PAR_VILLE = {
  capitale: 'Juge Fontaine',
  ville_a:  'Mireille Sedlex (PNJ)',
  ville_b:  'Gérard Bretellewood (PNJ)'
};

const PNJ_DIRECTEUR_ENTREPOT_PAR_VILLE = {
  capitale: 'Marcel Silo (PNJ)',
  ville_a:  'Yvon Paletier (PNJ)',
  ville_b:  'Norbert Charton (PNJ)'
};

// Deputes PNJ de secours (chantier "Hotel de Ville / elections", 4 septembre 2026) : 3 sieges
// reels par ville (voir resoudreScrutinDepute) -- si moins de 3 PJ occupent les sieges a l'issue
// du depouillement, les sieges manquants sont completes par ces PNJ (jamais pour chef_syndicat,
// qui peut rester vacant par arbitrage explicite). Noms distincts des PNJ deja en poste ailleurs
// (aucune collision avec PNJ_PAR_DEFAUT_POSTE), un pool de 3 par ville jamais epuisable.
const PNJ_DEPUTES_PAR_VILLE = {
  capitale: ['Député Marchand (PNJ)', 'Députée Fontaine (PNJ)', 'Député Rousseau (PNJ)'],
  ville_a:  ['Député Lecoq (PNJ)', 'Députée Girard (PNJ)', 'Député Ambroise (PNJ)'],
  ville_b:  ['Député Ferraille (PNJ)', 'Députée Charbonnier (PNJ)', 'Député Houiller (PNJ)']
};

// Cascade des postes nommes nationaux, dans l'ordre de dependance (chaque poste ne peut etre
// auto-pourvu qu'une fois celui qui le nomme deja resolu, PJ ou PNJ)
const CASCADE_NATIONALE = [
  { posteId: 'pm',       nommePar: 'president' },
  { posteId: 'min_int',  nommePar: 'pm' },
  { posteId: 'min_fin',  nommePar: 'pm' },
  { posteId: 'min_just', nommePar: 'pm' },
  { posteId: 'min_def',  nommePar: 'pm' },
  { posteId: 'min_info', nommePar: 'pm' },
  { posteId: 'min_ae',   nommePar: 'pm' },
  { posteId: 'commandant',              nommePar: 'min_def' },
  { posteId: 'directeur_pharma',        nommePar: 'min_fin' },
  { posteId: 'directeur_tabac_alcools', nommePar: 'min_fin' },
  { posteId: 'directeur_raffinerie',    nommePar: 'min_fin' },
  { posteId: 'chef_douanes',            nommePar: 'min_int' },
  { posteId: 'capitaine_port',          nommePar: 'min_fin' }
];

// =====================
// PRIORITE PJ SUR POSTES NOMMES — traitement serveur des candidatures expirees (lot du 25 aout
// 2026, apres audit dedie). Duplique de POSTES_NOMMES_EXCLUSIFS (data.js) -- le cron tourne dans
// un contexte serverless isole, sans acces aux fonctions/constantes client, meme convention que
// RESSOURCES_ECONOMIE_SERVEUR ci-dessus. Republia uniquement (comme le reste de ce fichier).
// =====================


// Resout le titulaire ACTUEL d'un poste nomme cote serveur (PJ d'abord via personnages.poste,
// PNJ en repli via titulaires_pnj) -- equivalent serveur de getTitulaireActuel (plateau-
// organisations-quetes.js), qui n'est pas accessible dans ce contexte isole.
async function resoudreTitulaireActuelPosteServeur(posteId, city) {
  const joueurs = await sbGet('personnages', `select=name,country,poste&country=eq.${PAYS_CASCADE}`) || [];
  for (const j of joueurs) {
    let poste = j.poste;
    if (typeof poste === 'string') { try { poste = JSON.parse(poste); } catch(e) { poste = null; } }
    if (!poste || poste.id !== posteId) continue;
    if (city && poste.city !== city) continue;
    return { nom: j.name, estPJ: true, posteComplet: poste };
  }
  const id = PAYS_CASCADE + '_' + posteId + '_' + (city || 'national');
  const rows = await sbGet('titulaires_pnj', `id=eq.${encodeURIComponent(id)}`);
  const row = rows && rows[0];
  if (row && row.nom_pnj) return { nom: row.nom_pnj, estPJ: false, posteComplet: null };
  return null;
}

// Traitement quotidien des candidatures de postes nommes ayant depasse leur fenetre de decision
// de 48h reelles (§2/§4/§16 du lot) : tirage au sort parmi les candidats encore eligibles,
// nomination automatique, sanction POP/2 du nominateur reste passif. Semantique reelle du delai
// (§16, documentee explicitement) : "eligible a nomination automatique a partir de 48h,
// traitement au premier passage serveur disponible apres echeance" -- avec un cron 1x/jour, le
// traitement effectif peut survenir plusieurs heures apres l'echeance exacte ; accepte, pas de
// second cron cree pour gagner quelques heures.
async function traiterCandidaturesPostesExpirees() {
  const resultats = { traitees: 0, nominationsAuto: 0, sanctions: 0, annuleesSansSanction: 0 };
  try {
    const etat = await sbGetBatimentEtat('republic', 'national', 'candidatures_postes').catch(() => ({}));
    const candidatures = (etat && etat.candidatures) || {};
    const now = Date.now();
    let modifie = false;

    for (const [cle, dossier] of Object.entries(candidatures)) {
      if (dossier.traitee) continue;
      const regle = POSTES_NOMMES_EXCLUSIFS_SERVEUR[dossier.posteId];
      if (!regle) { dossier.traitee = true; modifie = true; continue; }

      // Le poste a-t-il deja ete attribue a un PJ entretemps (nomination manuelle par
      // l'autorite, ou via le canal de nomination directe) ? Annulation sans sanction (§7 du
      // lot) : le systeme n'a pas eu a trancher, l'autorite a bien exerce son role.
      const titulaireActuel = await resoudreTitulaireActuelPosteServeur(dossier.posteId, dossier.city || null);
      if (titulaireActuel && titulaireActuel.estPJ) {
        dossier.traitee = true; modifie = true; resultats.annuleesSansSanction++; continue;
      }

      // Reconciliation d'autorite (§5 du lot) : si le nominateur a change depuis la derniere
      // ecriture du dossier, le nouveau titulaire recoit une fenetre complete de 48h -- jamais
      // sanctionne pour l'inaction de son predecesseur, jamais sanctionne moins de 48h apres sa
      // propre prise de fonction.
      // Portee de l'AUTORITE, pas celle du poste : un juge siege en ville mais son
      // nominateur est national (voir autoriteScope, data.js).
      const porteeAutorite = regle.autoriteScope || regle.scope;
      const autoriteActuelle = await resoudreTitulaireActuelPosteServeur(
        regle.nommePar, porteeAutorite === 'ville' ? dossier.city : null);
      const nomAutoriteActuelle = autoriteActuelle ? autoriteActuelle.nom : null;
      if (nomAutoriteActuelle && dossier.autoriteNom !== nomAutoriteActuelle) {
        dossier.autoriteNom = nomAutoriteActuelle;
        dossier.echeanceTs = now + DELAI_DECISION_CANDIDATURE_MS_SERVEUR;
        modifie = true;
        continue; // fenetre repartie a zero pour le nouveau titulaire, pas encore expiree
      }

      if (now < dossier.echeanceTs) continue; // pas encore expiree

      // Candidats encore eligibles : personnage existant, meme pays, pas deja titulaire d'un
      // poste incompatible (§7 du lot).
      const candidatsEligibles = [];
      for (const c of (dossier.candidats || [])) {
        if (c.retiree) continue;
        const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(c.nom)}&select=name,country,poste`);
        const perso = rows && rows[0];
        if (!perso || perso.country !== 'republic') continue;
        let posteActuelCandidat = perso.poste;
        if (typeof posteActuelCandidat === 'string') { try { posteActuelCandidat = JSON.parse(posteActuelCandidat); } catch(e) { posteActuelCandidat = null; } }
        if (posteActuelCandidat?.id && posteActuelCandidat.id !== dossier.posteId && !(regle.compatibles || []).includes(posteActuelCandidat.id)) continue;
        candidatsEligibles.push(c.nom);
      }

      if (candidatsEligibles.length === 0) {
        dossier.traitee = true; modifie = true;
        continue; // plus personne d'eligible, rien a nommer, pas de sanction (aucun candidat valide a ignorer)
      }

      // ======================================================================================
      // LE TIRAGE AU SORT N'EST PLUS FAIT ICI (chantier 6, 9 octobre 2026).
      //
      // CE QUI SE PASSAIT. `candidatsEligibles[Math.floor(Math.random() * ...)]` choisissait le
      // gagnant en JavaScript, puis SIX ecritures independantes, toutes avalees, appliquaient la
      // decision : titulaire PNJ retire, registre postes_attribues, fiche du gagnant, courrier au
      // gagnant, POP du nominateur divisee par deux, courrier au nominateur. Une coupure au
      // milieu laissait un gagnant inscrit au registre mais sans poste sur sa fiche, ou nomme
      // sans que son nominateur soit sanctionne, ou l'inverse.
      //
      // ET LE DRAPEAU `traitee` N'ETAIT ECRIT QU'APRES LA BOUCLE ENTIERE. Une coupure perdait
      // TOUS les drapeaux de la passe : la nuit suivante retirait au sort une seconde fois,
      // pouvait designer quelqu'un d'AUTRE, et divisait la POP du nominateur une seconde fois.
      //
      // candidature_poste_tirage_appliquer fait le tirage ET ses six consequences dans UNE
      // transaction, revendiquee par acte_nocturne_revendiquer -- la brique du chantier 6. Un
      // rejeu n'atteint jamais le tirage. Aucune regle de candidature ne change : tirage uniforme,
      // POP divisee par deux avec le meme plancher a zero, memes courriers, meme source au
      // registre.
      //
      // CE QUI RESTE ICI : le filtre d'eligibilite ci-dessus, parce qu'il lit `regle.compatibles`,
      // absent du miroir postes_nommes_regles -- le serveur ne pourrait pas le reconstituer sans
      // qu'on l'invente. Le CHOIX, lui, n'est plus fait dehors.
      // ======================================================================================
      const vTirage = await sbRpc('candidature_poste_tirage_appliquer', {
        p_pays: 'republic',
        p_poste_id: dossier.posteId,
        p_city: dossier.city || null,
        p_label: regle.label,
        p_candidats: candidatsEligibles,
        p_autorite: nomAutoriteActuelle || null
      }, HEADERS_SERVICE).then(rows => Array.isArray(rows) ? rows[0] : rows).catch(() => null);

      if (!vTirage || vTirage.ok !== true) {
        const raison = vTirage ? vTirage.raison : 'indisponible';
        if (raison === 'poste_deja_attribue') {
          // Le poste a ete pourvu entre-temps : le systeme n'a pas eu a trancher (§7 du lot).
          dossier.traitee = true; modifie = true; resultats.annuleesSansSanction++;
        } else if (raison === 'deja_traite_aujourdhui') {
          // Le dossier a DEJA ete traite cette nuit : son drapeau avait ete perdu. On le repose,
          // et surtout on ne retire pas au sort.
          dossier.traitee = true; modifie = true;
        } else {
          // Ni drapeau, ni sanction, ni nomination : la nuit suivante retentera. C'est le seul
          // comportement qui ne laisse rien a moitie fait.
          signalerEchec('candidatures_postes_expirees',
            'tirage refuse pour ' + cle + ' : ' + raison);
          continue;
        }
      } else if (!vTirage.gagnant) {
        // Plus aucun candidat eligible selon le serveur : rien a nommer, pas de sanction.
        dossier.traitee = true; modifie = true;
      } else {
        resultats.nominationsAuto++;
        if (vTirage.sanction) resultats.sanctions++;
        dossier.traitee = true; modifie = true; resultats.traitees++;
      }

      // LE DRAPEAU EST PERSISTE DOSSIER PAR DOSSIER (9 octobre 2026), plus apres la boucle : une
      // coupure ne perd desormais que le dossier en cours, jamais ceux deja traites.
      await sbSetBatimentEtat('republic', 'national', 'candidatures_postes', { candidatures }).catch(() => {});
    }

    // Filet pour les dossiers sortis de la boucle par `continue` AVANT le tirage : annulation
    // sans sanction, regle inconnue, autorite changee (fenetre repartie a zero). Les dossiers
    // passes par le tirage ont deja ete persistes un par un.
    if (modifie) {
      await sbSetBatimentEtat('republic', 'national', 'candidatures_postes', { candidatures }).catch(() => {});
    }
  } catch(e) { console.error('traiterCandidaturesPostesExpirees error', e); }
  return resultats;
}

// sbSupprimerTitulairePnjServeur A ETE SUPPRIMEE LE 9 OCTOBRE 2026. Son unique appelant etait le
// tirage au sort des candidatures expirees, qui retirait le PNJ sortant par une requete separee
// des cinq autres ecritures de la nomination. Le retrait vit maintenant DANS
// candidature_poste_tirage_appliquer, donc dans la transaction de la nomination : un PNJ ne peut
// plus etre retire d'un poste que personne ne finit par occuper. La logique de
// pourvoirPnj/verifierPostesVacantsEtAutoPourvoir ci-dessous est inchangee et reste inline.

async function verifierPostesVacantsEtAutoPourvoir() {
  const resultats = { pourvus: [] };
  try {
    const now = Date.now();

    // Etat initial en memoire : qui occupe deja quoi (PJ), et quels PNJ sont deja enregistres.
    // Resolution en un seul passage (choix explicite du 8 aout 2026) : la map est mise a jour
    // au fur et a mesure des ecritures, pas relue en base entre chaque etape de la cascade.
    const joueurs = await sbGet('personnages', `select=name,country,poste,poste_depute&country=eq.${PAYS_CASCADE}`) || [];
    const titulairesPnjRows = await sbGet('titulaires_pnj', `country=eq.${PAYS_CASCADE}`) || [];

    const cle = (posteId, ville) => posteId + '|' + (ville || 'national');
    const occupePJ = new Set();
    joueurs.forEach(j => {
      let poste = j.poste;
      if (typeof poste === 'string') { try { poste = JSON.parse(poste); } catch(e) { poste = null; } }
      if (poste?.id) {
        // Correctif Lot 4.3 : 'maire_adjoint' est un poste DISTINCT, il ne doit pas etre
        // normalise en 'maire'. Le prefixe reste utile pour les identifiants de maire par ville.
        const idNormalise = (poste.id !== 'maire_adjoint' && poste.id.startsWith('maire')) ? 'maire' : poste.id;
        occupePJ.add(cle(idNormalise, poste.city));
      }
      // Depute est stocke a part (poste_depute), cumulable avec un autre poste — pas encore
      // couvert par la cascade ci-dessous (aucun fallback PNJ pour depute pour l'instant),
      // mais on l'enregistre deja pour ne pas ecraser un vrai depute le jour ou ce sera le cas.
      let posteDepute = j.poste_depute;
      if (typeof posteDepute === 'string') { try { posteDepute = JSON.parse(posteDepute); } catch(e) { posteDepute = null; } }
      if (posteDepute?.id) occupePJ.add(cle(posteDepute.id, posteDepute.city));
    });
    const occupePNJ = new Set(titulairesPnjRows.filter(r => r.nom_pnj).map(r => cle(r.poste_id, r.city)));
    const estOccupe = (posteId, ville) => occupePJ.has(cle(posteId, ville)) || occupePNJ.has(cle(posteId, ville));

    async function pourvoirPnj(posteId, ville, nomPnj) {
      const id = PAYS_CASCADE + '_' + posteId + '_' + (ville || 'national');
      const existing = titulairesPnjRows.find(r => r.id === id);
      const payload = { id, country: PAYS_CASCADE, poste_id: posteId, city: ville || null, nom_pnj: nomPnj, updated_at: new Date().toISOString() };
      if (existing) await sbUpdate('titulaires_pnj', `id=eq.${encodeURIComponent(id)}`, payload);
      else await sbInsert('titulaires_pnj', payload);
      occupePNJ.add(cle(posteId, ville));
      resultats.pourvus.push({ poste: posteId, city: ville || null, pnj: nomPnj });

      // Retour du Commandant PNJ = reset des repartitions (regle precisee le 25 aout 2026,
      // apres le rapport initial du lot logistique portuaire) : la repartition 1/3-1/3-1/3 est
      // la DOCTRINE du PNJ, pas seulement une valeur initiale -- un ancien Commandant PJ ne doit
      // jamais pouvoir laisser une ville a 0% apres son depart. pourvoirPnj() n'est appelee pour
      // ce poste QUE lorsqu'il etait reellement vacant l'instant d'avant (ni PJ ni PNJ deja
      // titulaire, voir estOccupe() plus haut) : c'est le point de convergence UNIQUE de tous
      // les chemins de perte du poste (revocation, demission, mort/suppression du personnage,
      // arrestation, naturalisation...), donc cette regle les couvre tous sans avoir a patcher
      // chacun individuellement. Une succession PJ -> PJ directe (accepterNominationPosteNomme/
      // accepterCandidaturePoste, plateau-politique.js) installe le nouveau titulaire PJ sans
      // jamais repasser par une vacance ni par pourvoirPnj() : jamais resetee, comme demande.
      if (posteId === 'capitaine_port') {
        const etatPort = await sbGetBatimentEtat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM).catch(() => ({}));
        const port = (etatPort && etatPort.port) || {};
        if (port.repartition && Object.keys(port.repartition).length > 0) {
          await sbSetBatimentEtat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM, { ...(etatPort || {}), port: { ...port, repartition: {} } }).catch(() => {});
        }
      }
    }

    async function pourvoirCycleElu(posteId, ville) {
      const filtre = ville
        ? `country=eq.${PAYS_CASCADE}&poste_id=eq.${posteId}&city=eq.${ville}`
        : `country=eq.${PAYS_CASCADE}&poste_id=eq.${posteId}&city=is.null`;
      const row = (await sbGet('cycles_electoraux', filtre) || [])[0];
      if (!row) return;
      const cycle = JSON.parse(row.data);
      if (!cycle.resultatsTraites || cycle.eluId) return; // pas encore echu, ou deja pourvu
      cycle.eluId = PNJ_PAR_DEFAUT_POSTE[posteId];
      cycle.phase = 'mandat';
      cycle.dateDebutMandatTs = now;
      cycle.dateFinMandat = lundiMinuitParisApresSemaines(now, MANDAT_SEMAINES);   // passage au lundi
      // Archives des mandats (chantier "Hotel de Ville / elections", 4 septembre 2026) : un
      // mandat de maire PNJ de secours suit desormais la meme tracabilite dateDebutMandatTs/
      // indicateursDebutMandat qu'un mandat PJ, pour que le renouvellement futur (boucle
      // principale) puisse l'archiver correctement lui aussi.
      if (posteId === 'maire') {
        cycle.indicateursDebutMandat = await capturerIndicateursMunicipaux(PAYS_CASCADE, ville).catch(() => null);
      }
      // ECRITURE DIRECTE ASSUMEE : la garde `if (!cycle.resultatsTraites || cycle.eluId) return`
      // ci-dessus est la transition d'etat elle-meme -- une fois `eluId` pose, un rejeu sort
      // immediatement. Ce n'est pas une proclamation d'election mais une cascade de secours.
      await sbUpdate('cycles_electoraux', `id=eq.${row.id}`, { data: JSON.stringify(cycle), updated_at: new Date().toISOString() });
      occupePJ.add(cle(posteId, ville));
      resultats.pourvus.push({ poste: posteId, city: ville || null, pnj: PNJ_PAR_DEFAUT_POSTE[posteId] });
    }

    // --- President (elu, titulaire stocke dans cycle.eluId — pas dans titulaires_pnj) ---
    if (!estOccupe('president', null)) await pourvoirCycleElu('president', null);

    // --- Cascade nationale, dans l'ordre (president avant pm avant ministres) ---
    // LE JUGE N'EST PAS ICI, ET C'EST LA REGLE. Il est TERRITORIAL : un juge par ville,
    // pourvu dans la boucle des villes plus bas. Son autorite, elle, reste nationale --
    // le Ministre de la Justice nomme les trois, le maire n'en nomme aucun. Tant qu'il
    // figurait dans cette cascade, le cron creait un quatrieme juge SANS VILLE
    // (republic_juge_national), doublon du juge de la capitale ; il est retire, et la
    // ligne qu'il avait laissee en base est supprimee par la migration du 7 octobre 2026.
    for (const { posteId, nommePar } of CASCADE_NATIONALE) {
      if (estOccupe(posteId, null)) continue;
      if (!estOccupe(nommePar, null)) continue; // l'autorite au-dessus pas encore resolue
      await pourvoirPnj(posteId, null, PNJ_PAR_DEFAUT_POSTE[posteId]);
    }

    // --- Maire (elu, par ville) + Commissaire + Directeur d'entrepot (nommes par le maire, par ville) ---
    for (const ville of VILLES_CASCADE) {
      if (!estOccupe('maire', ville)) await pourvoirCycleElu('maire', ville);
      if (!estOccupe('commissaire', ville) && estOccupe('maire', ville)) {
        await pourvoirPnj('commissaire', ville, PNJ_PAR_DEFAUT_POSTE.commissaire);
      }
      if (!estOccupe('directeur_entrepot', ville) && estOccupe('maire', ville)) {
        await pourvoirPnj('directeur_entrepot', ville, PNJ_DIRECTEUR_ENTREPOT_PAR_VILLE[ville]);
      }
      // Le juge de CE tribunal. L'autorite qui le nomme est NATIONALE : on attend que le
      // Ministre de la Justice soit resolu, pas le maire -- qui n'a aucune autorite ici.
      if (!estOccupe('juge', ville) && estOccupe('min_just', null) && PNJ_JUGE_PAR_VILLE[ville]) {
        await pourvoirPnj('juge', ville, PNJ_JUGE_PAR_VILLE[ville]);
      }
    }
  } catch(e) { console.error('verifierPostesVacantsEtAutoPourvoir error', e); }
  return resultats;
}

// =====================
// BUREAU NATIONAL DE L'EMPLOI — conflit poste politique + emploi BNE (9 aout 2026)
// =====================
// Detecte tout PJ ayant simultanement un poste politique (personnages.poste) ET un emploi BNE
// actif (batiments_etat, id='<pays>_national_bne', voir sbGetEtatBNE cote client) — rendu
// possible par les 3 systemes de postes paralleles et non synchronises entre eux (dette
// technique notee le 9 aout 2026, JOURNAL-SESSION.md), qui ne verifient jamais l'incompatibilite
// avec un emploi BNE. Envoie un mail d'arbitrage plutot que de trancher automatiquement (regle
// demandee par Fred) — l'emploi BNE n'est PAS touche ici, il continue d'etre paye tant que
// le joueur n'a pas explicitement demissionne (au Bureau, ou de son poste politique par les
// canaux habituels).
//
// IMPORTANT : le reste de ce fichier envoie ses mails avec des noms de colonnes differents
// (destinataire/expediteur/sujet/corps) de ceux relus par le client (to_player/from_player/
// subject/body, voir sbGetMailsFor et l'affichage des mails non lus dans plateau-communication.js)
// — tres probablement le meme genre de bug que celui corrige ce soir sur le cycle electoral
// (votes_pj/votes_pnj). Pas corrige ici (hors perimetre BNE), mais le nouveau mail ci-dessous
// utilise volontairement le VRAI schema (to_player/from_player/subject/body) pour ne pas
// reproduire le probleme. A signaler/traiter separement.
// Resolution des investissements arrives a echeance (J+7, chantier "refonte des ordres" /
// Doctrine V2). Score = Base(50) + 2*(INT_snapshot-13) + (IE_ville-50)/5 -- INT est fige au
// moment de la mise (equipe du joueur a ce moment-la), IE_ville est lu EN DIRECT a l'echeance
// (pas snapshot), pour Republia uniquement (indices_villes). Rendement borne [-12%;+12%].
async function resoudreInvestissementsExpires() {
  const resultats = { resolus: 0 };
  const investissements = await sbGet('investissements', 'statut=eq.en_cours');
  if (!investissements) return resultats;

  for (const inv of investissements) {
    if (Date.now() < new Date(inv.jour_resolution_at).getTime()) continue;

    let ie = 50;
    if (inv.pays === 'republic' && inv.ville) {
      const rows = await sbGet('indices_villes', `id=eq.${encodeURIComponent(inv.pays + '_' + inv.ville)}`);
      ie = rows?.[0]?.data?.ie ?? 50;
    }

    const score = 50 + 2 * ((inv.int_snapshot || 8) - 13) + (ie - 50) / 5;
    const rendementPct = Math.max(-12, Math.min(12, (score - 50) * 0.24));
    const montantFinal = Math.round(inv.montant_initial * (1 + rendementPct / 100));

    const demRows = await sbGet('personnages', `name=eq.${encodeURIComponent(inv.joueur)}`);
    const demandeur = demRows && demRows[0];
    if (demandeur) {
      await sbUpdate('personnages', `name=eq.${encodeURIComponent(inv.joueur)}`, { arg: (demandeur.arg || 0) + montantFinal });
    }
    await sbUpdate('investissements', `id=eq.${encodeURIComponent(inv.id)}`, {
      statut: 'resolu',
      rendement_pct: Math.round(rendementPct * 100) / 100,
      montant_final: montantFinal
    });
    resultats.resolus++;
  }
  return resultats;
}

// Resolution des placements Banque nationale arrives a echeance (banque='nationale',
// type='terme'), nouveau systeme placements_bancaires (chantier "PLACEMENT BANQUE NATIONALE",
// phase 2 -- raccordement). Coexiste temporairement avec resoudreInvestissementsExpires()
// ci-dessus (legacy, table investissements, strictement inchangee) tant que l'unique ligne
// active heritee n'est pas resolue -- aucune nouvelle ligne investissements n'est plus jamais
// creee cote client depuis ce lot (voir confirmerInvestir, plateau-justice-economie.js).
//
// Contrairement au legacy, cette fonction ne mute JAMAIS directement comptes_bancaires/
// personnages.arg/placements_bancaires : resoudre_placement_national() est l'autorite
// transactionnelle unique (credit compte, ajustement d'arg du seul delta net, statut resolu,
// mail persistant), evaluee ici uniquement pour calculer rendementPct (formule inchangee) avant
// de la lui transmettre.
//
// IE de la ville (micro-correctif, chantier "PLACEMENT BANQUE NATIONALE") : placements_bancaires
// stocke desormais p.ville (figee au moment du placement, jamais recalculee a l'echeance -- voir
// confirmerInvestir, plateau-justice-economie.js). L'IE est relue EN DIRECT a l'echeance (pas
// snapshotee, memes regles que resoudreInvestissementsExpires ci-dessus) via indices_villes, id =
// pays_ville, meme mecanisme exact que le legacy. Fallback ie=50 (neutre) UNIQUEMENT si p.ville
// est absente/vide (anciennes lignes ou anomalie) ou si aucune donnee IE exploitable n'existe
// reellement pour cette ville -- jamais recalculee depuis une autre source, jamais devinee.
async function resoudrePlacementsNationauxExpires() {
  const resultats = { resolus: 0 };
  const maintenant = new Date().toISOString();
  const placements = await sbGet('placements_bancaires', `banque=eq.nationale&type=eq.terme&statut=eq.actif&prochaine_echeance=lte.${encodeURIComponent(maintenant)}`);
  if (!placements) return resultats;

  for (const p of placements) {
    // Meme garde exacte que resoudreInvestissementsExpires (legacy) : IE consulte uniquement
    // pour 'republic', jamais pour les autres empires (comportement d'origine du jeu, pas une
    // limitation de ce lot -- conserve tel quel).
    let ie = 50;
    if (p.pays === 'republic' && p.ville) {
      const rows = await sbGet('indices_villes', `id=eq.${encodeURIComponent(p.pays + '_' + p.ville)}`);
      ie = rows?.[0]?.data?.ie ?? 50;
    } else if (p.pays === 'republic' && !p.ville) {
      console.error('resoudrePlacementsNationauxExpires : placement ' + p.id + ' (republic) sans ville -- fallback ie=50 (neutre).');
    }

    const score = 50 + 2 * ((p.int_snapshot || 8) - 13) + (ie - 50) / 5;
    const rendementPct = Math.max(-12, Math.min(12, (score - 50) * 0.24));

    const res = await sbRpc('resoudre_placement_national', {
      p_placement_id: p.id,
      p_rendement_pct: Math.round(rendementPct * 100) / 100
    });
    if (res) resultats.resolus++;
    else console.error('resoudre_placement_national a echoue pour ' + p.id + ' -- ligne laissee active, retentee au prochain passage du cron.');
  }
  return resultats;
}

// Resolution des placements Helvetia arrives a echeance (banque='helvetia', type='declare'
// ou 'offshore'), chantier "Helvetia H1". Contrairement au national, resoudre_placement_helvetia
// est entierement autonome (rendement fixe 8%, frais 30%, fiscalite 50% -- tout est calcule et
// persiste DANS la RPC a partir des seules colonnes du placement) : ce cron ne calcule rien,
// il se contente de trouver les lignes echues et d'appeler la RPC pour chacune. La RPC credite
// deja atomiquement la caisse Helvetia (frais) et la reserve nationale (impot si declare) --
// aucune mutation supplementaire a faire ici.
async function resoudrePlacementsHelvetiaExpires() {
  const resultats = { resolus: 0 };
  const maintenant = new Date().toISOString();
  const placements = await sbGet('placements_bancaires', `banque=eq.helvetia&statut=eq.actif&prochaine_echeance=lte.${encodeURIComponent(maintenant)}`);
  if (!placements) return resultats;

  for (const p of placements) {
    const res = await sbRpc('resoudre_placement_helvetia', { p_placement_id: p.id });
    if (res) resultats.resolus++;
    else console.error('resoudre_placement_helvetia a echoue pour ' + p.id + ' -- ligne laissee active, retentee au prochain passage du cron.');
  }
  return resultats;
}

// Traitement quotidien du contentieux des prets Helvetia (chantier H2A, migration consolidee
// installee manuellement dans Supabase le 28 aout 2026, jamais rejouee par ce commit). Toute la
// logique (echeancier J+1 avertissement / J+2 mise en demeure + saisie financiere en cascade
// (Helvetia -> national -> liquide) / J+3 ciblage puis saisie d'un bien / J+4 avertissement +
// proposition d'accord / accord accepte : +20%, gel 10 jours, avertissement J+9) vit DANS la RPC
// -- ce cron ne fait qu'appeler traiter_prets_helvetia_quotidien() une fois pour tous les pays
// (fonction sans parametre, balaie tous les prets type_banque='helvetia' actifs/en contentieux).
// Fail-closed : un echec de la RPC (sbRpc renvoie null, deja logge par sbRpc) n'est jamais
// masque -- reporte explicitement dans le resultat au lieu d'un simple objet vide, pour qu'une
// panne financiere H2A reste visible dans la reponse du cron plutot que silencieusement ignoree.
async function traiterPretsHelvetiaServeur() {
  const res = await sbRpc('traiter_prets_helvetia_quotidien', {});
  if (res === null) {
    console.error('traiter_prets_helvetia_quotidien a echoue -- aucun pret Helvetia traite ce passage, retente au prochain cron.');
    return { ok: false, traites: 0, actions: [] };
  }
  return { ok: true, traites: res.length, actions: res };
}

// Reglement chronologique des creances Helvetia (obligations envers un copropriétaire/surplus de
// saisie + tranches BNR exigibles), chantier H2A -- regler_creances_helvetia_quotidien(p_pays)
// prend un pays a la fois (caisse '{pays}_banque-privee' propre a chaque pays), meme liste de
// pays codee en dur que le reste de ce cron (voir alimenterBudgets plus haut). Meme doctrine
// fail-closed que traiterPretsHelvetiaServeur ci-dessus : un echec sur un pays est signale, pas
// masque, et n'empeche pas de tenter les autres pays.
async function reglerCreancesHelvetiaServeur() {
  const resultats = { ok: true, traites: 0, actions: [] };
  for (const pays of Object.keys(VILLES_SERVEUR)) {   // referentiel des empires, pas liste en dur (4G)
    const res = await sbRpc('regler_creances_helvetia_quotidien', { p_pays: pays });
    if (res === null) {
      console.error('regler_creances_helvetia_quotidien a echoue pour ' + pays + ' -- retente au prochain cron.');
      resultats.ok = false;
      continue;
    }
    resultats.actions.push(...res.map(r => Object.assign({}, r, { pays })));
  }
  resultats.traites = resultats.actions.length;
  return resultats;
}

// =====================
// FRET MARITIME INTERNATIONAL (lot du 24 aout 2026) — passage en_transit -> arrivee
// =====================
// Le seul point qui doit faire arriver reellement une caisse a destination : ne depend d'aucun
// client, aucun doDormir(), aucun tick d'horloge navigateur (exigence explicite du lot). Le cron
// tourne 1x/jour de facon inconditionnelle (vercel.json, 23h UTC). quantite_arrivee est figee
// ici (somme du contenu reel au moment de l'arrivee), base fixe pour le calcul de la valeur
// administrative restante lors d'une eventuelle liquidation J15.
async function traiterArriveesCaissesFret() {
  const resultats = { arrivees: 0 };
  const caisses = await sbGet('caisses_fret', 'statut=eq.en_transit');
  if (!caisses) return resultats;

  const maintenant = new Date();
  for (const c of caisses) {
    if (!c.date_arrivee_prevue || maintenant.getTime() < new Date(c.date_arrivee_prevue).getTime()) continue;

    const contenu = await sbGet('contenu_caisses_fret', 'caisse_id=eq.' + encodeURIComponent(c.id));
    const quantiteArrivee = (contenu || []).reduce((s, l) => s + (l.quantite || 0), 0);

    await sbUpdate('caisses_fret', `id=eq.${encodeURIComponent(c.id)}`, {
      statut: 'arrivee',
      date_arrivee_reelle: maintenant.toISOString(),
      quantite_arrivee: quantiteArrivee
    });
    resultats.arrivees++;
  }
  return resultats;
}

// J15 (arbitrage valide) : caisse arrivee mais jamais entierement videe -> statut 'a_vendre'.
// Ne debite jamais l'ancien destinataire (il perd simplement son droit sur la caisse, aucune
// ecriture financiere ici) ; aucune recette n'est creee tant que personne n'achete le lot (voir
// acheterLotNonReclameeFret, cote client).
async function traiterMiseEnVenteCaissesFret() {
  const resultats = { misesEnVente: 0 };
  const caisses = await sbGet('caisses_fret', 'statut=eq.arrivee');
  if (!caisses) return resultats;

  const maintenant = new Date();
  for (const c of caisses) {
    if (!c.date_arrivee_reelle) continue;
    const joursEcoules = (maintenant.getTime() - new Date(c.date_arrivee_reelle).getTime()) / 86400000;
    if (joursEcoules < 15) continue;

    const contenu = await sbGet('contenu_caisses_fret', 'caisse_id=eq.' + encodeURIComponent(c.id));
    const quantiteRestante = (contenu || []).reduce((s, l) => s + (l.quantite || 0), 0);
    if (quantiteRestante <= 0) continue; // deja videe entre-temps (retrait synchrone cote client)

    await sbUpdate('caisses_fret', `id=eq.${encodeURIComponent(c.id)}`, {
      statut: 'a_vendre',
      date_mise_en_vente: maintenant.toISOString()
    });
    resultats.misesEnVente++;
  }
  return resultats;
}

async function verifierConflitsEmploiBNE() {
  const resultats = { notifies: [] };
  try {
    const idBNE = PAYS_CASCADE + '_national_bne';
    const etatRows = await sbGet('batiments_etat', `id=eq.${encodeURIComponent(idBNE)}`);
    if (!etatRows || !etatRows[0]) return resultats;
    let etat;
    try { etat = JSON.parse(etatRows[0].data); } catch(e) { return resultats; }
    const offres = etat.offres || {};

    const joueurs = await sbGet('personnages', `select=name,country,poste&country=eq.${PAYS_CASCADE}`) || [];

    for (const [offreId, occupants] of Object.entries(offres)) {
      for (const occ of (occupants || [])) {
        if (occ.statut !== 'actif') continue;
        const joueur = joueurs.find(j => j.name === occ.pjNom);
        if (!joueur) continue;
        let poste = joueur.poste;
        if (typeof poste === 'string') { try { poste = JSON.parse(poste); } catch(e) { poste = null; } }
        if (!poste?.id) continue; // pas de poste politique, pas de conflit

        // Deja notifie et pas encore traite (mail non archive avec ce sujet) : ne pas renvoyer chaque nuit
        const dejaNotifie = await sbGet('mails', `to_player=eq.${encodeURIComponent(occ.pjNom)}&subject=eq.${encodeURIComponent('Poste politique et emploi BNE en même temps')}&archived=eq.false`);
        if (dejaNotifie && dejaNotifie.length > 0) continue;

        const corps = 'Vous occupez à la fois le poste politique de <strong>' + (poste.name || poste.id) + '</strong> et un emploi du Bureau National de l\'Emploi (' + offreId + '). Les deux sont incompatibles.<br><br>' +
          'Si vous conservez votre poste politique : rendez-vous au Bureau National de l\'Emploi pour démissionner de votre emploi BNE (immédiat, gratuit).<br>' +
          'Si vous préférez garder l\'emploi BNE : démissionnez de votre poste politique par les moyens habituels. Votre emploi BNE reste actif et payé en attendant votre décision.';

        // PAR LA BRIQUE (10 octobre 2026). `archived: false` est le DEFAUT de la colonne : rien
        // n'est perdu en ne le passant plus. La garde anti-renvoi ci-dessus relit `mails`, donc
        // un courrier perdu sera retente la nuit suivante -- ce qui est le comportement voulu.
        await envoyerMailSysteme(occ.pjNom, 'Bureau National de l\'Emploi',
          'Poste politique et emploi BNE en même temps', corps,
          new Date().toLocaleDateString('fr-FR'));
        resultats.notifies.push({ pjNom: occ.pjNom, poste: poste.id, offre: offreId });
      }
    }
  } catch(e) { console.error('verifierConflitsEmploiBNE error', e); }
  return resultats;
}

// =====================
// VOTE DE CONFIANCE — RÉSOLUTION SERVEUR (chantier "Hotel de Ville / elections", 4 septembre
// 2026). N'existait nulle part avant ce chantier (cloturerVoteConfiance, cote client, n'avait
// aucun appelant -- confirme par l'audit). Adapte a l'Assemblee reelle (9 sieges, 3 par ville,
// jamais 25) : les deputes PJ reellement en poste (personnages.poste_depute.id==='depute')
// votent s'ils l'ont fait ; tout siege restant (PJ n'ayant pas vote OU siege tenu par un PNJ de
// secours) est tranche par un tirage pondere par l'ISN, exactement comme avant, recalibre sur 9.
// =====================
async function resoudreVotesConfianceEchusServeur(nowMs) {
  // LE DEPOUILLEMENT EST UNE TRANSACTION SERVEUR (chantier 6, 10 octobre 2026).
  //
  // CE QUI SE PASSAIT. Les sieges PNJ restants etaient tires ICI, par `Math.random()`, puis la
  // cloture (`statut = 'termine'`, `resultat`) etait ecrite dans un `.catch(() => {})`, suivie de
  // l'evenement public et du courrier de censure -- avales aussi. Si la cloture mordait APRES
  // l'annonce publique, le rejeu REDEPOUILLAIT : le meme vote pouvait passer de confiance a
  // censure, publiquement, deux fois, avec deux evenements contradictoires dans la chronique.
  //
  // vote_confiance_resoudre fait le tirage, la cloture, l'evenement et le courrier dans un seul
  // BEGIN, sous verrou du vote. La transition d'etat EST le verrou -- pas besoin de la brique des
  // actes nocturnes, qui serait d'ailleurs fausse ici : un vote de confiance se depouille une
  // fois dans sa vie, pas une fois par jour.
  //
  // Il ne reste ici que le balayage, le pre-filtre d'echeance et la collecte des verdicts.
  const resultats = [];
  // Ces trois refus ne sont pas des echecs : le pre-filtre et la porte ont vu le monde a deux
  // instants differents, ou une autre passe a deja depouille.
  const RIEN_A_FAIRE = ['pas_echu', 'deja_resolu', 'vote_introuvable'];
  try {
    const votes = await sbGet('votes_confiance', 'statut=eq.en_cours&select=id,cloture_ts') || [];
    for (const vote of votes) {
      if (nowMs < new Date(vote.cloture_ts).getTime()) continue; // pas encore echu
      const v = await sbRpc('vote_confiance_resoudre', { p_vote_id: vote.id }, HEADERS_SERVICE)
        .then(rows => Array.isArray(rows) ? rows[0] : rows).catch(() => null);
      if (!v) {
        signalerEchec('vote_confiance:' + vote.id, 'aucun verdict rendu');
        continue;
      }
      if (v.ok !== true) {
        if (!RIEN_A_FAIRE.includes(v.raison)) {
          signalerEchec('vote_confiance:' + vote.id, v.raison || 'refus sans motif');
        }
        continue;
      }
      resultats.push({ vote_id: v.vote_id, country: v.country, resultat: v.resultat,
                       pour: v.pour, contre: v.contre });
    }
  } catch(e) { console.error('resoudreVotesConfianceEchusServeur error', e); }
  return resultats;
}

// Consequence differee de la censure (arbitrage du 4 septembre 2026) : si le PM n'a toujours pas
// demissionne 48h reelles apres la censure, POP=0 pour le PM, tous les ministres et le president
// -- jamais de destitution automatique, les consequences politiques doivent ensuite emerger du
// jeu (motion de defiance suivante, election, etc.). Idempotent (consequence_appliquee).
async function appliquerConsequencesCensureEchues(nowMs) {
  const resultats = [];
  try {
    const votes = await sbGet('votes_confiance',
      `statut=eq.termine&resultat=eq.censure&consequence_appliquee=eq.false&demission_limite_ts=not.is.null`) || [];
    for (const vote of votes) {
      if (nowMs < new Date(vote.demission_limite_ts).getTime()) continue;

      const pmRows = await sbGet('personnages', `name=eq.${encodeURIComponent(vote.pm_nom)}&select=name,poste,resources`) || [];
      const pm = pmRows[0];
      let pmToujours = false;
      if (pm) {
        let poste = pm.poste;
        if (typeof poste === 'string') { try { poste = JSON.parse(poste); } catch(e) { poste = null; } }
        pmToujours = poste?.id === 'pm';
      }

      if (pmToujours) {
        const cibles = [vote.pm_nom];
        // Ministres + president du meme pays (postes nommes exclusifs, deja lus ailleurs dans ce
        // fichier -- POSTES_NOMMES_EXCLUSIFS_SERVEUR -- + president via cycles_electoraux).
        const ministresRows = await sbGet('personnages', `country=eq.${encodeURIComponent(vote.country)}&select=name,poste`) || [];
        ministresRows.forEach(j => {
          let poste = j.poste;
          if (typeof poste === 'string') { try { poste = JSON.parse(poste); } catch(e) { poste = null; } }
          if (poste?.id && (poste.id === 'pm' || poste.id.startsWith('min_'))) cibles.push(j.name);
        });
        const presCycle = (await sbGet('cycles_electoraux', `country=eq.${encodeURIComponent(vote.country)}&poste_id=eq.president`) || [])[0];
        if (presCycle) {
          const cyclePres = JSON.parse(presCycle.data);
          if (cyclePres.eluId) cibles.push(cyclePres.eluId);
        }
        for (const nom of [...new Set(cibles)]) {
          const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nom)}&select=resources`) || [];
          const perso = rows[0];
          if (!perso) continue;
          const resourcesMaj = { ...(perso.resources || {}), pop: 0 };
          await sbUpdate('personnages', `name=eq.${encodeURIComponent(nom)}`, { resources: resourcesMaj }).catch(() => {});
        }
        await sbInsert('evenements_globaux', {
          country: vote.country, city: null,
          texte: `🏛 Le Premier Ministre ${vote.pm_nom} n'a pas démissionné dans le délai de 48h suivant sa censure. Le gouvernement tout entier voit sa popularité s'effondrer.`,
          jour: null
        }).catch(() => {});
        resultats.push({ vote_id: vote.id, pm: vote.pm_nom, consequence: 'pop_zero_appliquee' });
      } else {
        resultats.push({ vote_id: vote.id, pm: vote.pm_nom, consequence: 'pm_deja_demissionnaire' });
      }

      await sbUpdate('votes_confiance', `id=eq.${encodeURIComponent(vote.id)}`, { consequence_appliquee: true }).catch(() => {});
    }
  } catch(e) { console.error('appliquerConsequencesCensureEchues error', e); }
  return resultats;
}

export default async function handler(req, res) {
  // Securite FAIL CLOSED (18 aout 2026, correctif suite a un declenchement accidentel reel en
  // production) : si CRON_SECRET n'est pas configure, aucune tache ne demarre -- l'ancien
  // comportement (if (process.env.CRON_SECRET && ...)) laissait cet endpoint totalement ouvert
  // tant que la variable n'existait pas. Vercel Cron envoie automatiquement CRON_SECRET dans
  // l'en-tete Authorization des que cette variable est configuree dans le projet -- aucune
  // modification supplementaire n'est necessaire cote appelant legitime.
  const authHeader = req.headers['authorization'];
  if (!process.env.CRON_SECRET || authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  // FAIL CLOSED SUR L'IDENTITE SERVEUR (chantier B, 14 septembre 2026). Le cron ecrit desormais
  // sous service_role : sans la cle, il tournerait sous la cle anon et se ferait refuser, table
  // apres table, a mesure que le chantier B les referme -- en laissant derriere lui une nuit a
  // moitie faite. Mieux vaut ne pas commencer et le dire franchement.
  if (!SUPABASE_SERVICE_ROLE) {
    console.error('[cron-minuit] ARRET : SUPABASE_SERVICE_ROLE_KEY absente, aucune tache executee');
    return res.status(500).json({ ok: false, error: 'SUPABASE_SERVICE_ROLE_KEY absente : passe annulee.' });
  }

  const now = new Date();
  const results = [];

  // Une fonction serverless peut etre REUTILISEE d'une invocation a l'autre : les deux etats de
  // passe doivent repartir de zero, sinon une nuit heriterait des echecs de la precedente et le
  // registre de journees servirait un cache perime (chantier A / P0-2 et P0-4, 14 septembre 2026).
  ECHECS_PASSE = [];
  REGISTRE_JOURS_PASSE = null;

  // Journal de la PASSE elle-meme (§6.12). Les lignes par tache ne disent rien
  // d'une nuit ou le cron n'a pas ete declenche du tout, ou s'est interrompu
  // avant sa premiere tache : ce cas-la ne se lit que par l'ABSENCE de ligne
  // '_passe' du jour, ou par une ligne restee a 'demarree'.
  const jourPasse = jourParisISO();
  const departPasse = Date.now();
  await journaliserCron('_passe', jourPasse, 'demarree');

  try {
    // 0. ASSEMBLEE NATIONALE — REVEIL AUTOMATIQUE DE MINUIT (§24, chantier du 10 septembre 2026)
    //
    // Tout depute PNJ endormi se reveille a minuit. Le traitement est SERVEUR par nature : l'etat
    // 'endormi' est partage entre tous les joueurs, un reveil cote client se declencherait dans
    // chaque navigateur independamment, avec des state.day desynchronises (le jour de jeu est
    // propre a chaque joueur -- le projet l'a deja acte pour les lois et les baux).
    //
    // Un seul UPDATE ensembliste sous verrou, donc idempotent : rejouer ce cron ne fait rien de
    // plus. Place en TETE du handler pour qu'un echec electoral plus bas ne prive jamais
    // l'Assemblee de son reveil.
    //
    // IDENTITE SERVEUR (correctif de securite du 10 septembre 2026) : assemblee_reveil_minuit
    // n'accorde EXECUTE qu'au service_role (migration_assemblee_securisation_droits.sql) -- avec la
    // cle anon, n'importe quel joueur reveillait l'hemicycle a volonte. La base ne reveille que les
    // deputes endormis AVANT le dernier minuit Paris, quelle que soit l'heure d'appel.
    try {
      if (!SUPABASE_SERVICE_ROLE) console.error('assemblee_reveil_minuit : SUPABASE_SERVICE_ROLE_KEY absente, aucun reveil');
      const reveils = SUPABASE_SERVICE_ROLE
        ? await sbRpc('assemblee_reveil_minuit', { p_country: 'republic' }, HEADERS_SERVICE)
        : null;
      const nbReveils = Array.isArray(reveils) ? reveils[0] : reveils;
      if (typeof nbReveils === 'number' && nbReveils > 0) {
        results.push({ tache: 'assemblee_reveil_minuit', deputes_reveilles: nbReveils });
        await sbInsert('evenements_globaux', {
          country: 'republic', city: null,
          texte: '🏛 Les députés assommés de l\'Assemblée nationale ont retrouvé leurs esprits pendant la nuit.',
          jour: null
        }).catch(() => {});
      }
    } catch (e) { console.error('assemblee_reveil_minuit', e); }

    // 0 ter. LOIS ADOPTEES ET NON MISES EN APPLICATION — SANCTION DU GOUVERNEMENT
    //
    // Depuis le chantier du 30 septembre 2026, une loi adoptee par l'Assemblee n'entre en vigueur
    // que lorsque le Ministre de l'Interieur la met en application. Passe 36 h, le gouvernement en
    // repond : -20 POP au premier palier, puis -10 toutes les 24 h tant que la loi dort.
    //
    // CE FICHIER NE CALCULE RIEN, comme pour le reveil ci-dessus. Toute la logique est dans
    // assemblee_sanctionner_lois_non_appliquees : elle trouve les paliers echus, RATTRAPE ceux
    // qu'une passe manquee aurait laisses, debite par la primitive canonique de POP, et inscrit
    // chaque palier dans un registre dont la cle primaire <loi>:<palier> rend tout second debit
    // impossible -- rejeu, crons concurrents ou appel manuel compris. Rejouer ce cron ne coute donc
    // jamais un franc de popularite de plus.
    //
    // CADENCE : cette passe est quotidienne, les paliers sont a 36 h puis toutes les 24 h. Un palier
    // est donc debite lors de la premiere passe qui suit son echeance -- jamais deux fois, jamais
    // saute, mais avec un retard pouvant aller jusqu'a 24 h. C'est un choix : reutiliser
    // l'ordonnanceur existant plutot qu'en ajouter un troisieme.
    try {
      if (!SUPABASE_SERVICE_ROLE) {
        console.error('assemblee_sanctions : SUPABASE_SERVICE_ROLE_KEY absente, aucune sanction');
      } else {
        const brut = await sbRpc('assemblee_sanctionner_lois_non_appliquees',
                                 { p_country: 'republic' }, HEADERS_SERVICE);
        const r = Array.isArray(brut) ? brut[0] : brut;
        const nb = (r && typeof r.paliers_appliques === 'number') ? r.paliers_appliques : 0;
        if (nb > 0) {
          results.push({ tache: 'assemblee_sanctions_lois', paliers: nb, detail: r.detail });
          await sbInsert('evenements_globaux', {
            country: 'republic', city: null,
            texte: '🏛 Des lois votees par l\'Assemblee nationale restent sans application : la popularite du gouvernement en souffre.',
            jour: null
          }).catch(() => {});
        }
      }
    } catch (e) { console.error('assemblee_sanctions_lois', e); }

    // 0 quater. SANTE DU FOURNISSEUR IA — RENDRE VISIBLE LA MORT DE SEB LEX
    //
    // LE PROBLEME. Seb Lex echoue POLIMENT : le joueur lit « Seb Lex est indisponible », l'endpoint
    // journalise la cause exacte (cle absente, solde epuise, authentification, panne passagere),
    // et... c'est tout. Pour lire ce journal il faut savoir qu'il existe et aller le chercher dans
    // les logs de la fonction. Un solde epuise peut donc tuer le juriste de l'Assemblee pendant des
    // jours sans que personne ne le sache.
    //
    // CE QU'ON NE FAIT PAS. On n'invente pas ici de canal d'alerte -- pas de courriel, pas de
    // webhook, pas de table de notifications : il n'en existe aucun dans le projet, et ce lot n'est
    // pas le bon endroit pour en batir un.
    //
    // CE QU'ON FAIT. On reutilise les DEUX mecanismes de signalement que cette passe possede deja :
    //   - cron_journal, qui garde une ligne durable et datee, consultable apres coup ;
    //   - ECHECS_PASSE, qui fait rendre un HTTP 500 a la passe -- et un cron rouge est precisement
    //     ce que le tableau de bord de l'ordonnanceur affiche sans qu'on le lui demande.
    //
    // LE SEUIL EST CHOISI. Seules les pannes DEFINITIVES (solde epuise, cle absente ou refusee)
    // font rougir la passe : elles ne se repareront pas d'elles-memes et exigent une action humaine.
    // Un debit limite, un delai depasse ou un 503 passager sont journalises et rien de plus -- faire
    // rougir la passe chaque nuit pour un hoquet rendrait le signal inutile, ce qui est la maniere
    // la plus sure de ne plus le voir du tout.
    try {
      const jourSonde = jourParisISO();
      if (!cleConfiguree()) {
        signalerEchec('sonde_ia', 'DEEPSEEK_API_KEY absente : Seb Lex et les dialogues PNJ sont hors service.');
        await journaliserCron('sonde_ia', jourSonde, 'echec', 'cle absente').catch(() => {});
      } else {
        // L'appel le plus petit possible : une reponse d'un mot. Il coute une fraction de centime
        // par nuit, et ne coute rien du tout dans le cas qui nous interesse -- un solde epuise est
        // refuse avant d'etre facture.
        const sonde = await appelDeepSeek({
          messages: [{ role: 'user', content: 'Reponds exactement : ok' }],
          maxTokens: 4, timeoutMs: 15000
        });
        if (sonde && sonde.ok) {
          await journaliserCron('sonde_ia', jourSonde, 'ok', null, { fournisseur: 'joignable' }).catch(() => {});
        } else {
          const c = classerEchecFournisseur(sonde) || { cause: 'autre', critique: false, journal: 'inconnu' };
          if (c.critique) {
            // PANNE DEFINITIVE. La passe rendra 500 : Fred le verra dans le tableau de bord des
            // crons, et la ligne de cron_journal lui dira laquelle des trois causes c'etait.
            signalerEchec('sonde_ia', 'IA HORS SERVICE (' + c.cause + ') : ' + c.journal
                          + ' -- Seb Lex et les dialogues PNJ ne repondent plus.');
            await journaliserCron('sonde_ia', jourSonde, 'echec', c.cause + ' :: ' + c.journal).catch(() => {});
          } else {
            console.error('[cron-minuit] sonde_ia : panne passagere (' + c.cause + ') :: ' + c.journal);
            await journaliserCron('sonde_ia', jourSonde, 'ignoree', c.cause + ' :: ' + c.journal).catch(() => {});
          }
        }
      }
    } catch (e) {
      // La sonde est un capteur : si elle se casse elle-meme, elle ne doit pas emporter la passe.
      console.error('sonde_ia', e);
    }

    // 0 bis. CONVOCATIONS ECHUES — AUTORITE SERVEUR (§41, chantier du 10 septembre 2026)
    //
    // Le delai de 36 h est porte par un instant ABSOLU (convocations[].limiteTs). Le serveur TRANCHE
    // l'echeance ; le client du joueur APPLIQUE la peine a sa prochaine connexion -- meme repartition
    // que pour les agressions (impacts_indices_attente).
    //
    // BUG CORRIGE (defaut introduit a la passe precedente de ce chantier). Ce bloc faisait lui-meme
    // une lecture-modification-ecriture de personnages, et y posait est_emprisonne = {jours:2, ...}
    // SANS jourFin. Trois defauts cumules :
    //   1. verifierLiberationPrisonniers teste state.day >= estEmprisonne.jourFin : avec jourFin
    //      undefined, le joueur n'aurait JAMAIS ete libere ;
    //   2. aucune ligne n'etait ecrite au registre 'detentions' ;
    //   3. la sauvegarde suivante d'un client connecte aurait efface est_emprisonne, qu'il republie.
    // Le serveur ne peut d'ailleurs pas calculer la peine : elle s'exprime en jours de jeu, et
    // state.day est propre a chaque joueur.
    //
    // Desormais : une seule RPC ensembliste pose le verdict echue = true, rendu monotone par le
    // trigger personnages_preserver_judiciaire -- aucune sauvegarde client ne peut l'effacer. C'est
    // traiterConvocations (plateau-justice-economie.js) qui, voyant ce verdict, appelle
    // procederArrestation('non_presentation_convocation') : jourFin correct, registre ecrit, cellule.
    //
    // Identite serveur obligatoire : cette RPC ecrit un verdict chez des joueurs potentiellement
    // hors ligne, elle n'est executable que par le service_role. Sans cle, rien n'est ecrit.
    try {
      if (!SUPABASE_SERVICE_ROLE) console.error('convocations_echues : SUPABASE_SERVICE_ROLE_KEY absente, aucun verdict');
      const verdict = SUPABASE_SERVICE_ROLE
        ? await sbRpc('assemblee_marquer_convocations_echues', { p_country: 'republic' }, HEADERS_SERVICE)
        : null;
      const v = Array.isArray(verdict) ? verdict[0] : verdict;
      const marques = (v && Array.isArray(v.marques)) ? v.marques : [];
      if (marques.length > 0) results.push({ tache: 'convocations_echues', joueurs: marques.length });
    } catch (e) { console.error('convocations_echues', e); }

    // 1. Récupérer tous les cycles électoraux
    //
    // NE JAMAIS SORTIR ICI (chantier A / P0-2, 14 septembre 2026). Cette lecture etait suivie de
    // `if (!cycles) return res.status(200).json({ ok: true })` -- avec DEUX consequences graves.
    // D'abord sbGet rend null sur TOUTE reponse non-2xx, pas sur une table vide (une table vide
    // rend [] et traverse la boucle sans rien faire) : le seul cas atteignable etait donc une
    // ERREUR. Ensuite ce return emportait les TRENTE tachess suivantes -- loyers, fiscalite,
    // chantiers, prets, livraisons, Journal -- et la passe se declarait reussie. Un unique 500 ou
    // un timeout transitoire de Supabase sur cette requete sautait la nuit entiere en silence.
    // Le bloc electoral est desormais ce que l'architecture prevoit : une etape ISOLABLE. Son
    // echec est nomme, remonte dans le statut final, et n'empeche plus aucune autre tache.
    const cycles = await sbGet('cycles_electoraux', 'select=*');
    for (const row of (cycles || [])) {
      let cycle;
      try { cycle = JSON.parse(row.data); } catch(e) { continue; }

      const posteId = row.poste_id;
      const country = row.country;
      const ville = row.city || null;
      const posteNom = POSTE_NOMS[posteId] || posteId;
      const scope = POSTE_SCOPE[posteId] || 'national';

      // Renouvellement d'un mandat echu (titulaire PJ ou PNJ) — rouvre un cycle de
      // candidatures frais. C'etait la piece manquante du systeme electoral : sans ca,
      // un cycle resolu restait fige indefiniment (bug remonte le 8 aout 2026).
      if (cycle.phase === 'mandat' && cycle.dateFinMandat && now.getTime() >= cycle.dateFinMandat) {
        // Archive du mandat de maire (chantier "Hotel de Ville / elections", 4 septembre 2026) --
        // seul le cas dominant (mandat arrive naturellement a echeance) est archive ici.
        if (posteId === 'maire' && cycle.eluId) {
          const estPJ = cycle.eluId !== PNJ_PAR_DEFAUT_POSTE.maire;
          const debutTs = cycle.dateDebutMandatTs || (cycle.dateFinMandat - MANDAT_SEMAINES * SEMAINE_MS);
          await archiverMandatMaireTermine(country, ville, cycle.eluId, estPJ, debutTs, cycle.dateFinMandat, cycle.indicateursDebutMandat);
        }
        // CETTE ECRITURE RESTE DIRECTE, ET C'EST LE BON CHOIX (10 octobre 2026). Elle n'est pas
        // une proclamation : c'est un RENOUVELLEMENT, et la transition d'etat le garde deja --
        // le nouveau cycle porte `phase: 'candidatures'`, donc un rejeu ne satisfait plus la
        // condition `phase === 'mandat'` juste au-dessus. La passer par
        // election_resultats_consigner serait meme FAUX : son compare-and-swap exige
        // `resultatsTraites = false`, et un cycle en mandat l'a a vrai.
        const nouveauCycle = construireNouveauCycleElectoral(posteId, ville, now.getTime());
        await sbUpdate('cycles_electoraux', `id=eq.${row.id}`, { data: JSON.stringify(nouveauCycle), updated_at: now.toISOString() });
        results.push({ poste: posteId, country, city: ville, statut: 'nouveau_cycle' });
        continue;
      }

      // Correctif P0 "cycle a 0 candidat bloque indefiniment" (audit du 4 septembre 2026) : un
      // cycle 'vacant' (0 candidat OU 0 vote) ne restait auparavant jamais relance -- ni par ce
      // bloc (qui ne verifiait que phase==='mandat'), ni par la cascade PNJ (qui exige
      // resultatsTraites+pas d'eluId, mais ne couvre que president/maire). relancePossibleApres
      // (pose plus bas au moment de la vacance, +24h) laisse une nuit complete a la cascade PNJ
      // pour tenter de pourvoir le poste (president/maire) avant de relancer un cycle frais --
      // jamais le meme soir que la vacance elle-meme, pour ne jamais court-circuiter cette cascade.
      if (cycle.phase === 'vacant' && cycle.resultatsTraites && cycle.relancePossibleApres && now.getTime() >= cycle.relancePossibleApres) {
        // MEME RAISON QUE LE RENOUVELLEMENT CI-DESSUS : relancer un cycle vacant n'est pas
        // proclamer, la transition d'etat garde (`phase` repasse a 'candidatures'), et le
        // compare-and-swap de la porte refuserait puisque `resultatsTraites` est a vrai ici.
        const nouveauCycleVacant = construireNouveauCycleElectoral(posteId, ville, now.getTime());
        await sbUpdate('cycles_electoraux', `id=eq.${row.id}`, { data: JSON.stringify(nouveauCycleVacant), updated_at: now.toISOString() });
        results.push({ poste: posteId, country, city: ville, statut: 'nouveau_cycle_apres_vacance' });
        continue;
      }

      const dateResultats = cycle.dateResultats;
      if (!dateResultats || now.getTime() < dateResultats) continue; // Pas encore échu
      if (cycle.resultatsTraites) continue; // Déjà traité

      // Fraudes non revelees de CE scrutin precis (cle = date de creation du cycle, stable a
      // travers les renouvellements -- voir chargerFraudesActivesServer).
      // UNE SEULE CONSIGNATION PAR SCRUTIN (chantier 6, 10 octobre 2026). Chaque branche se
      // contente desormais de DECIDER : elle mute `cycle` en memoire et depose son annonce dans
      // ces trois variables. L'ecriture -- blob du cycle, evenement public et chronique -- est
      // faite une seule fois, en bas de la boucle, par election_resultats_consigner, qui garde
      // par compare-and-swap sur `resultatsTraites`.
      let blobAEcrire = null, evenementAPoser = null, chroniqueAPoser = null;
      const cycleDebutCle = cycle.dateDebutCandidatures || row.id;
      const fraudesActives = await chargerFraudesActivesServer(country, posteId, ville, cycleDebutCle);
      await attacherEffetsTractsServer(row.id, cycle);

      if (posteId === 'depute') {
        // ================= LEGISLATIVES : 3 sieges reels par ville =================
        // LA BRANCHE DU DEPARTAGE DU 3e SIEGE EST SUPPRIMEE (chantier 6, lot 1, 7 oct. 2026).
        //
        // Quarante lignes de depouillement d'un second tour PARTIEL, inatteignables. Trois
        // mesures le prouvent :
        //   . resoudreScrutinDepute rend `egalite3eSiege: null` dans ses TROIS retours, ici
        //     comme dans son miroir client (plateau-politique.js) -- depuis le passage aux
        //     legislatives a un tour unique, le 12 septembre 2026 ;
        //   . aucun code du depot n'affecte jamais `phase = 'vote_3e_siege'` ;
        //   . zero des 13 lignes de cycles_electoraux ne porte cette phase (mesure du
        //     7 octobre 2026).
        //
        // Le client conserve le libelle et la couleur de la phase (PHASES_ELECTORALES.
        // VOTE3E_SIEGE, data.js) : c'est une regle de jeu documentee, et l'effacer serait une
        // decision de game design. Ce qui part ici, c'est le depouillement mort -- il ne
        // protegeait rien, et il devait etre relu a chaque passage sur ce fichier.
        //
        // Le bloc nu ci-dessous n'est pas un reste : il garde `resultatDepute` dans sa propre
        // portee, comme le faisait la branche `else` qu'il remplace.
        {
          const resultatDepute = resoudreScrutinDepute(cycle, fraudesActives);
          if (!resultatDepute || resultatDepute.totalExprimes === 0) {
            cycle.resultatsTraites = true;
            cycle.phase = 'vacant';
            cycle.relancePossibleApres = now.getTime() + 24 * 60 * 60 * 1000;
            results.push({ poste: 'depute', country, city: ville, statut: 'vacant' });
          } else if (resultatDepute.blancMajoritaire) {
            blobAEcrire = construireNouveauCycleElectoral('depute', ville, now.getTime());
            evenementAPoser = { country, city: ville, texte: `🗳️ VOTE BLANC MAJORITAIRE : les élections législatives de ${ville} sont invalidées, un nouveau cycle est lancé.` };
            results.push({ poste: 'depute', country, city: ville, statut: 'invalide_vote_blanc' });
          } else {
            let elusFinaux2 = resultatDepute.elus.slice();
            if (elusFinaux2.length < 3) {
              const pool2 = (PNJ_DEPUTES_PAR_VILLE[ville] || []).filter(n => !elusFinaux2.includes(n));
              while (elusFinaux2.length < 3 && pool2.length) elusFinaux2.push(pool2.shift());
            }
            cycle.elus = elusFinaux2;
            cycle.resultatsTraites = true;
            cycle.phase = 'mandat';
            cycle.dateDebutMandatTs = now.getTime();
            cycle.dateFinMandat = lundiMinuitParisApresSemaines(now.getTime(), MANDAT_SEMAINES);   // passage au lundi
            evenementAPoser = { country, city: ville, texte: `🗳️ RÉSULTATS : ${elusFinaux2.join(', ')} sont élu(e)s député(e)s de ${ville} (3 sièges).` };
            chroniqueAPoser = {
              id: `election-${row.id}-${cycle.dateResultats}`,
              country, city: ville, type: 'election_resultat',
              personnages: elusFinaux2,
              libelle: `Assemblée de ${ville} : ${elusFinaux2.join(', ')} sont élu(e)s député(e)s (3 sièges).`,
              data: { poste_id: 'depute', elus: elusFinaux2, cycle_row_id: row.id }, source_ref: row.id
            };
            results.push({ poste: 'depute', country, city: ville, statut: 'elu', elus: elusFinaux2 });
          }
        }
      } else {
        // ================= PRESIDENT / MAIRE / CHEF SYNDICAL : siege unique =================
        const resultatSimple = resoudreScrutinSimple(cycle, fraudesActives);
        if (!resultatSimple || resultatSimple.totalExprimes === 0) {
          cycle.resultatsTraites = true;
          cycle.phase = 'vacant';
          cycle.relancePossibleApres = now.getTime() + 24 * 60 * 60 * 1000;
          results.push({ poste: posteId, country, city: ville, statut: 'vacant' });
        } else if (resultatSimple.blancMajoritaire) {
          blobAEcrire = construireNouveauCycleElectoral(posteId, ville, now.getTime());
          evenementAPoser = { country, city: scope === 'local' ? ville : null, texte: `🗳️ VOTE BLANC MAJORITAIRE : l'élection de ${posteNom} est invalidée, un nouveau cycle est lancé.` };
          results.push({ poste: posteId, country, city: ville, statut: 'invalide_vote_blanc' });
        } else if (resultatSimple.elu) {
          cycle.eluId = resultatSimple.elu;
          cycle.resultatsTraites = true;
          cycle.phase = 'mandat';
          cycle.dateDebutMandatTs = now.getTime();
          cycle.dateFinMandat = lundiMinuitParisApresSemaines(now.getTime(), MANDAT_SEMAINES);   // passage au lundi
          if (posteId === 'maire') {
            cycle.indicateursDebutMandat = await capturerIndicateursMunicipaux(country, ville).catch(() => null);
          }
          const villeLabel = ville ? ` (${ville})` : '';
          const pourcentageVoix = Math.round((resultatSimple.scores[resultatSimple.elu] / resultatSimple.totalExprimes) * 100);
          evenementAPoser = { country, city: scope === 'local' ? ville : null,
            texte: `🗳️ RÉSULTATS : ${resultatSimple.elu} est élu(e) ${posteNom}${villeLabel} avec ${pourcentageVoix}% des voix.` };
          // chronique_nationale (chantier "refonte Tribune", 4 septembre 2026) : historisation
          // permanente du resultat -- cycles_electoraux ecrase l'etat precedent au cycle suivant,
          // seule cette ligne d'historique survit pour le Journal (source cle stable
          // country+poste_id+city+row.id pour eviter tout doublon si ce passage de cron est rejoue).
          chroniqueAPoser = {
            id: `election-${row.id}-${cycle.dateResultats}`,
            country, city: scope === 'local' ? ville : null,
            type: 'election_resultat',
            personnages: [resultatSimple.elu],
            libelle: `${resultatSimple.elu} est élu(e) ${posteNom}${villeLabel} avec ${pourcentageVoix}% des voix.`,
            data: { poste_id: posteId, elu: resultatSimple.elu, pourcentage_voix: pourcentageVoix, cycle_row_id: row.id },
            source_ref: row.id
          };
          results.push({ poste: posteId, country, city: ville, statut: 'elu', gagnant: resultatSimple.elu });
        } else if (resultatSimple.secondTour.length >= 2) {
          const candidatsExistantsSimple = cycle.candidats || [];
          cycle.tour = 2;
          cycle.candidats = resultatSimple.secondTour.map(nom => ({ nom, voix: 0, programme: (candidatsExistantsSimple.find(c => c.nom === nom) || {}).programme || '' }));
          cycle.votes = {};
          cycle.votesPNJ = {};
          // Second tour le dimanche suivant (calendrier du dimanche, 12 septembre 2026) : cloture
          // deja passee (aucune candidature entre les tours), vote dimanche 00:01 -> 23:59.
          const calST = calendrierTourSuivant(cycle.dateVote);
          cycle.dateDebutCampagne = calST.dateDebutCampagne;
          cycle.dateVote = calST.dateVote;
          cycle.dateResultats = calST.dateResultats;
          cycle.phase = 'second_tour';
          const villeLabel2 = ville ? ` (${ville})` : '';
          evenementAPoser = { country, city: scope === 'local' ? ville : null,
            texte: `🗳️ SECOND TOUR : Aucune majorité absolue pour ${posteNom}${villeLabel2}. Second tour entre ${resultatSimple.secondTour.join(' et ')}.` };
          results.push({ poste: posteId, country, city: ville, statut: 'second_tour', candidats: resultatSimple.secondTour });
        }
      }

      // LA CONSIGNATION UNIQUE. Le blob, l'evenement public et la chronique partent ensemble ou
      // pas du tout, sous compare-and-swap sur `resultatsTraites` : un rejeu lit zero ligne et
      // n'annonce donc PAS une seconde fois. C'etait le defaut reel de cette famille -- la
      // chronique etait deja protegee par sa cle, l'evenement public ne l'etait pas du tout.
      const vCons = await sbRpc('election_resultats_consigner', {
        p_cycle_id: row.id,
        p_data: blobAEcrire || cycle,
        p_evenement: evenementAPoser,
        p_chronique: chroniqueAPoser
      }, HEADERS_SERVICE).then(rows => Array.isArray(rows) ? rows[0] : rows).catch(() => null);
      if (!vCons || vCons.ok !== true) {
        // `deja_traite` n'est pas un echec : une autre passe a proclame ce scrutin, et c'est
        // exactement ce que la garde doit produire. Tout le reste en est un.
        if (!vCons || vCons.raison !== 'deja_traite') {
          signalerEchec('election_resultats:' + row.id,
            (vCons && vCons.raison) || 'aucun verdict rendu');
        }
      }
    }

    // 1b. Cascade de nomination automatique — installe un PNJ sur les postes nommes dont
    // l'autorite de nomination vient elle-meme d'etre resolue (voir plan du 8 aout 2026)
    const cascadeAutoPourvoi = await verifierPostesVacantsEtAutoPourvoir();

    // 1c. Priorite PJ sur postes nommes : candidatures ayant depasse leur fenetre de decision
    // de 48h (lot du 25 aout 2026, apres audit dedie) — tirage au sort + sanction eventuelle.
    const candidaturesPostesExpirees = await traiterCandidaturesPostesExpirees();

    // 1d. Vote de confiance — resolution des votes echus (48h reelles) + consequence differee
    // de la censure (chantier "Hotel de Ville / elections", 4 septembre 2026 : mecanique
    // entierement cassee auparavant, aucune fonction de persistance/cloture n'existait).
    const votesConfianceResolus = await resoudreVotesConfianceEchusServeur(now.getTime());
    const consequencesCensure = await appliquerConsequencesCensureEchues(now.getTime());

    // 2. Purger les mails de plus de 14 jours, non archives (recus ET envoyes)
    const mailsSuppres = await purgerVieuxMails();

    // 2b. FILET DE SECURITE CARCERAL (chantier A / P0-3, 14 septembre 2026) : libere les peines
    // dont la duree reelle est ecoulee. Jusqu'ici, seul le client liberait (runMidnightUpdate /
    // doDormir) : un joueur qui ne revenait pas restait detenu indefiniment. Naturellement
    // idempotent -- une fois est_emprisonne remis a null, la ligne n'est plus selectionnee -- donc
    // volontairement hors du registre de journees. Ne touche jamais au QHS (chantier separe).
    const detentionsLiberees = await libererDetentionsEchuesServeur();

    // 3. Fuites spontanees des souvenirs de l'accueil (5-10% par jour et par souvenir).
    // Sous registre depuis le 7 octobre 2026 : c'etait la seule tache du fichier qu'une double
    // execution relancait entierement, et chaque fuite est un scandale public irreversible.
    const fuites = await tacheQuotidienne('souvenirs_accueil', traiterSouvenirsAccueil);

    // 4. Taxe fonciere quotidienne sur tous les terrains possedes
    const taxeFonciere = await tacheQuotidienne('taxe_fonciere', preleverTaxeFonciere);

    // 5. Loyers de TOUS les baux (Lot 1.4) -- source unique locations_actives, destination
    //    portee par le bail, chaque prelevement atomique via la RPC prelever_loyer_bail.
    const loyersLots = await preleverLoyersBaux();

    // 5 bis. TRAITEMENTS NATIONAUX QUOTIDIENS (Lot 4.3) : redistribution fiscale, virement vers la
    //    caserne, solde des soldats. Ils ne tournaient que si un joueur passait minuit connecte --
    //    sans quoi aucune institution n'etait financee et aucun soldat paye. Idempotence partagee
    //    avec le chemin client : le second passage, quel qu'il soit, est sans effet.
    await traiterQuotidienNationalServeur('republic');

    // 5 ter. CASCADE MUNICIPALE (8 octobre 2026). Elle vient APRES la taxe fonciere (4) et les
    //    loyers (5) : ce sont eux qui alimentent le compteur recettes_municipales dont elle tire
    //    sa base. La taxe sur les transactions, elle, l'a alimente en continu pendant la journee.
    //
    //    JUSQU'ICI LA REDISTRIBUTION MUNICIPALE N'ETAIT PAS DANS LE CRON. Elle vivait dans le
    //    navigateur -- distribuerBudgetMunicipalVersBatiments, declenchee par doDormir -- donc
    //    une commune dont aucun habitant ne dormait n'etait jamais financee, et deux joueurs
    //    endormis a la meme seconde passaient tous deux la garde. Le serveur fait desormais foi.
    //
    //    IDEMPOTENCE : la cle primaire de repartitions_versements porte le jour. Un second
    //    passage ne verse rien, et le registre joursCron n'est qu'une commodite par-dessus.
    const cascadeMunicipale = await tacheQuotidienne('budgets_municipaux', async () => {
      const rows = await sbRpc('budget_municipal_cascade', { p_pays: 'republic' }, HEADERS_SERVICE);
      const r = Array.isArray(rows) ? rows[0] : rows;
      if (!r || r.ok !== true) {
        signalerEchec('budgets_municipaux', (r && r.raison) || 'verdict_absent');
      }
      return r || { ok: false, raison: 'rpc_indisponible' };
    });

    // 5b. SUBVENTIONS MUNICIPALES ARRIVEES A ECHEANCE (10 octobre 2026).
    //
    //    APRES la cascade, et ce n'est pas indifferent : la cascade alimente l'enveloppe, cette
    //    tache libere ce qui y etait immobilise. Dans cet ordre, le maire retrouve au reveil une
    //    enveloppe dotee ET degagee de ses propositions mortes.
    //
    //    IDEMPOTENCE : aucune revendication nocturne n'est posee, parce qu'elle n'apporterait
    //    rien. L'UPDATE de subventions_expirer ne trouve que les propositions encore `proposee`
    //    dont l'echeance est atteinte ; un second passage n'en trouve aucune. Et l'expiration ne
    //    deplace AUCUN argent -- la reserve est la somme des propositions en attente, donc
    //    changer leur statut suffit a la liberer.
    const subventionsExpirees = await tacheQuotidienne('subventions_expirees', async () => {
      const rows = await sbRpc('subventions_expirer', { p_pays: 'republic' }, HEADERS_SERVICE);
      const r = Array.isArray(rows) ? rows[0] : rows;
      if (!r || r.ok !== true) {
        signalerEchec('subventions_expirees', (r && r.raison) || 'verdict_absent');
      }
      return r || { ok: false, raison: 'rpc_indisponible' };
    });

    // 6. Resolution atomique des compromis arrives a echeance (permis + pret, ensemble)
    const compromisResolus = await resoudreCompromisExpires();

    // 6b. Meme resolution pour les compromis de rachat d'entreprise (pas de clause, acompte
    // toujours perdu a l'echeance)
    const compromisEntreprisesResolus = await resoudreCompromisEntreprisesExpires();

    // 7. Rendez-vous d'achat direct manques (depot perdu, terrain libere)
    const achatsDirectsManques = await nettoyerAchatsDirectsManques();

    // 7b. Instruction des permis de construire et accord tacite (Lot 1.5.13). AVANT les chantiers :
    // un permis accorde cette nuit doit pouvoir servir des le lendemain, et l'ordre inverse ferait
    // simplement attendre un jour de plus sans raison.
    const permis = await traiterInstructionsPermis();

    // 8. Progression quotidienne des chantiers (versements, alea, livraison)
    const chantiers = await avancerChantiersQuotidien();

    // 9. Mensualites des prets bancaires (a heure fixe, que le joueur dorme ou non)
    const prets = await preleverPretsBancairesServeur();

    // 9b. Contentieux des prets Helvetia (chantier H2A, 28 aout 2026) : echeancier dedie
    // J+1..J+9, exclu du chemin legacy ci-dessus (voir preleverPretsBancairesServeur).
    const pretsHelvetia = await traiterPretsHelvetiaServeur();

    // 10. Expiration des blocus syndicaux non renouveles
    const blocusExpires = await nettoyerBlocusExpires();

    // 11. Effets quotidiens des blocus actifs (malus popularite du maire)
    const effetsBlocus = await tacheQuotidienne('effets_blocus', appliquerEffetsBlocusActifs);

    // 11b. Effets quotidiens des greves (ordinaires + generale) -- chantier "Greves, greve
    // generale et contre-pouvoirs", 3 septembre 2026. DOIT s'executer AVANT l'etape 13
    // (produireTransformateursQuotidien) : ecrit le coefficient d'activite economique lu par
    // produireUneChaine pour les entreprises ciblees.
    const effetsGrevesOrdinaires = await appliquerEffetsGrevesOrdinaires();
    const effetsGreveGenerale = await appliquerEffetsGreveGenerale();

    // 11 ter. Livraison des commandes directes arrivees a echeance (J+1 national, J+2 etranger).
    // AVANT l'approvisionnement automatique : ce qui vient d'arriver doit compter dans le stock
    // du jour, sinon le cron rachèterait ce qu'il vient de recevoir. La RPC est idempotente par
    // construction -- elle supprime chaque ligne livree dans la meme transaction que le credit.
    const transitsLivres = await tacheQuotidienne('transits_entrepots', async function () {
      const r = await sbRpc('entrepot_livrer_transits', {});
      return r || { ok: false, raison: 'rpc_indisponible' };
    });

    // 11 quater. CELLULES DE RENSEIGNEMENT.
    //
    // Deux balayages serveur, tous deux idempotents (ils ne voient que ce qui est
    // encore ouvert, et reclore une cellule deja close renvoie rejeu:true).
    //
    // libererDetentionsEchuesServeur (tache 3) pilote la liberation depuis les FICHES
    // de personnages : il ne verra JAMAIS un detenu PNJ, qui n'en a pas. C'est ce trou
    // que couvre detentions_pnj_liberer_echues -- sans toucher au chemin PJ, qui reste
    // strictement celui d'avant.
    const detentionsPnj = await tacheQuotidienne('detentions_pnj', async function () {
      const r = await sbRpc('detentions_pnj_liberer_echues', {});
      return r || { ok: false, raison: 'rpc_indisponible' };
    });

    // RECRUTEMENT MILITAIRE (24 septembre 2026). Deux passes, dans cet ordre et pour une raison
    // precise : on EXPIRE d'abord les engagements dont les 48 h sont ecoulees, on RELANCE
    // ensuite. Une candidature dont l'acceptation vient d'expirer ne doit pas recevoir, la meme
    // nuit, une relance qui la dirait « toujours a l'etude » -- elle est redevenue rien du tout.
    //
    // Les deux sont idempotentes par construction : l'expiration ne voit que les lignes encore
    // `acceptee`, et la relance se cale sur derniere_relance. Un cron saute ne produit donc
    // jamais deux courriers, et un cron rejoue n'en produit aucun de trop.
    //
    // Ces taches ne rendent AUCUNE place : la capacite est calculee, et une echeance passee
    // cesse de reserver toute seule, a la seconde pres. Elles ne font que ranger les lignes et
    // prevenir les joueurs.
    const affectationsExpirees = await tacheQuotidienne('affectations_militaires_expirer', async function () {
      const r = await sbRpc('militaire_affectations_expirer', {});
      return r || { ok: false, raison: 'rpc_indisponible' };
    });
    const candidaturesRelancees = await tacheQuotidienne('candidatures_militaires_relancer', async function () {
      const r = await sbRpc('militaire_candidatures_relancer', {});
      return r || { ok: false, raison: 'rpc_indisponible' };
    });

    // Collecte des quatre agents, PUIS rapport quotidien par cellule. Dans cet
    // ordre, et AVANT le balayage : une cellule qui s'eteint aujourd'hui doit
    // recevoir son dernier rapport. Les deux sont idempotents -- la collecte
    // dedoublonne sur fait_objectif_ref, le rapport sur sa cle primaire
    // (cellule, jour). Pas de troisieme cron : le "rapport de 22 h" est une
    // convention diegetique, l'execution technique est celle de cette passe.
    const collecteAgents = await tacheQuotidienne('collecte_agents', async function () {
      const r = await sbRpc('cellules_renseignement_collecter', {});
      return r || { ok: false, raison: 'rpc_indisponible' };
    });
    const rapportsCellules = await tacheQuotidienne('rapports_cellules', async function () {
      const r = await sbRpc('cellules_rapports_generer', {});
      return r || { ok: false, raison: 'rpc_indisponible' };
    });

    // Fin naturelle a J+10 et echec quand les quatre agents sont morts. L'arbitrage GD
    // est que la fin naturelle suit EXACTEMENT la meme regle de sortie que la fin
    // volontaire : agent libre -> disparu, agent detenu -> disparu ET detention cloturee
    // avec mode_fin = 'evasion'. Les deux chemins appellent la meme routine.
    const cellulesRenseignement = await tacheQuotidienne('cellules_renseignement', async function () {
      const r = await sbRpc('cellules_renseignement_balayer', {});
      return r || { ok: false, raison: 'rpc_indisponible' };
    });

    // PAYE DES DOUANIERS DU PORT -- SORTIE DU SOMMEIL D'UN JOUEUR (26 septembre 2026).
    // Elle etait declenchee depuis doDormir() de N'IMPORTE QUEL joueur, ce qui est contraire
    // au pilier temporel : un traitement institutionnel quotidien ne peut pas dependre du fait
    // qu'un joueur particulier clique sur Dormir. Et elle echouait de toute facon depuis le
    // 12 septembre, parce que le Chef des Douanes declenchait un debit sur une caisse dont
    // l'autorite exige le poste min_int -- deux postes mutuellement exclusifs.
    // La RPC metier douane_payer_effectifs calcule elle-meme l'effectif, le montant et la
    // caisse, est idempotente par journee mondiale ecoulee, et fonctionne meme si le poste
    // chef_douanes est vacant : c'est le Ministere de l'Interieur qui paie, le Chef ne fait
    // que gerer les effectifs. Aucune horloge nouvelle : la temporalite est celle de cette passe.
    const payeDouane = await tacheQuotidienne('paye_douane', async function () {
      const parPays = {};
      for (const pays of Object.keys(VILLES_SERVEUR)) {   // referentiel des empires, pas liste en dur (4G)
        const r = await sbRpc('douane_payer_effectifs', { p_pays: pays });
        parPays[pays] = r || { ok: false, raison: 'rpc_indisponible' };
      }
      return { ok: true, parPays };
    });

    // 11 ter. ENTRETIEN QUOTIDIEN DES POLICIERS PNJ (27 septembre 2026, lot 3).
    // Deplacee ici depuis doDormir pour la meme raison que la douane -- un traitement
    // institutionnel ne peut pas dependre du sommeil d'un joueur -- plus une fuite propre a la
    // police : le debit partait du sommeil de N'IMPORTE QUEL joueur present dans la ville, alors
    // que l'ecriture des effectifs exige le commissaire DE CETTE VILLE. L'argent sortait de la
    // caisse sans que personne ne soit paye ni retire.
    // Difference avec la douane : la police est MULTI-VILLE. La RPC boucle donc sur toutes les
    // villes du pays qui portent un effectif, chacune avec sa propre caisse de commissariat et
    // son propre marqueur de jour -- un seul prelevement par ville et par jour.
    const payePolice = await tacheQuotidienne('paye_police', async function () {
      const parPays = {};
      for (const pays of Object.keys(VILLES_SERVEUR)) {   // referentiel des empires, pas liste en dur (4G)
        const r = await sbRpc('police_payer_effectifs', { p_pays: pays });
        parPays[pays] = r || { ok: false, raison: 'rpc_indisponible' };
      }
      return { ok: true, parPays };
    });

    // 12. Livraisons quotidiennes des entrepots logistiques (6 livraisons simulees en une
    // passe, limite du plan Vercel Hobby)
    const livraisons = await tacheQuotidienne('livraisons_entrepots', livrerEntrepotsQuotidien);

    // 12b. Exportations institutionnelles du Port de PSM (lot logistique portuaire, 25 aout
    // 2026) : prelevement reel sur le stock des 3 entrepots, apres que les imports du jour ont
    // ete distribues ci-dessus.
    const exportationsPort = await tacheQuotidienne('exportations_port', traiterExportationsPortQuotidien);

    // 12c. Arrivage quotidien de poisson propre a la Criee de PSM (arbitrage du 25 aout 2026) :
    // independant de livrerEntrepotsQuotidien ci-dessus, ne touche aucun entrepot.
    const arrivagePoissonCriee = await tacheQuotidienne('arrivage_criee', genererArrivagePoissonCriee);

    // 13. Production quotidienne des transformateurs (mode PNJ), redistribution 60/40
    const production = await tacheQuotidienne('production_transformateurs', produireTransformateursQuotidien);

    // 13b. EFFORT DE GUERRE (13 septembre 2026) — expiration, reserve, ravitaillement, production.
    // POSITION IMPERATIVE : APRES les livraisons (12) et la production des transformateurs (13),
    // pour que la reserve porte sur les flux REELLEMENT arrives dans les entrepots cette nuit,
    // apres la redirection vers les usines locales. Et APRES le virement quotidien vers la caserne
    // (5 bis, traiterQuotidienNationalServeur), qui alimente la caisse dans laquelle le
    // ravitaillement puis la production vont puiser.
    // Tache non critique : son echec ne doit pas emporter la passe, d'ou le try/catch local,
    // sur le modele des taches 0, 0 bis et 17.
    let effortDeGuerre = null;
    try {
      effortDeGuerre = await tacheQuotidienne('effort_de_guerre', () => traiterEffortDeGuerreServeur('republic'));
    } catch (e) {
      console.error('traiterEffortDeGuerreServeur', e);
    }

    // 14. Conflits poste politique + emploi BNE (mail d'arbitrage, rien n'est tranche automatiquement)
    const conflitsBNE = await verifierConflitsEmploiBNE();

    // 15. Investissements arrives a echeance (J+7, chantier "refonte des ordres") -- legacy,
    // ne concerne plus que l'unique ligne heritee non migree (voir plus bas, 15b).
    const investissements = await resoudreInvestissementsExpires();

    // 15b. Placements Banque nationale arrives a echeance (nouveau systeme placements_bancaires,
    // chantier "PLACEMENT BANQUE NATIONALE" phase 2).
    const placementsNationaux = await resoudrePlacementsNationauxExpires();

    // 15c. Placements Helvetia arrives a echeance (chantier "Helvetia H1").
    const placementsHelvetia = await resoudrePlacementsHelvetiaExpires();

    // 15d. Creances Helvetia (chantier H2A, 28 aout 2026) : obligations copropriete/surplus de
    // saisie + tranches BNR exigibles, ordre chronologique, un pays a la fois.
    const creancesHelvetia = await reglerCreancesHelvetiaServeur();

    // 16. Remboursement quotidien des prets de preemption d'Etat (Ministre des Finances)
    const preemptions = await tacheQuotidienne('preemptions_etat', preleverPreemptionsServeur);

    // 16b. Successions differees : avancement des convocations, cascade remplacant/conjoint,
    // reglement + degel des dossiers integralement resolus
    const successionsResolues = await resoudreSuccessionsExpirees();

    // 16c. Fret maritime international (lot du 24 aout 2026) : arrivee des caisses en transit
    // (en_transit -> arrivee, quantite_arrivee figee), independamment de tout client connecte
    const caissesFretArrivees = await traiterArriveesCaissesFret();

    // 16d. Fret maritime : mise en vente J15 des caisses jamais videes (arrivee -> a_vendre)
    const caissesFretMisesEnVente = await traiterMiseEnVenteCaissesFret();

    // 16e. Cotisations non eternelles (club de supporters + Syndicat des Dockers de PSM, lot
    // logistique portuaire du 25 aout 2026) : renouvellement tacite ou fin d'adhesion automatique
    const cotisationsOrganisations = await renouvellerCotisationsOrganisations();

    // 16f. Licences sportives saisonnieres (lot du 25 aout 2026, correctif groupe football) :
    // seul point qui renouvelle/prelevle/fait expirer une licence -- jamais le client (voir
    // commentaire dedie sur traiterLicencesSportivesSaison), pour qu'un renouvellement ne
    // puisse jamais etre applique deux fois par deux clients differents.
    const licencesSportives = await traiterLicencesSportivesSaison();

    // 17. Journal du jour (Lot B) — STRICTEMENT en dernier, dans son propre try/catch : un
    // echec ou un depassement de son propre budget interne ne doit jamais remettre en cause les
    // 16 taches critiques ci-dessus, deja executees et sauvegardees avant ce point.
    let journalDuJour = null;
    try {
      journalDuJour = await genererToutesLesEditions();
    } catch (e) {
      console.error('Erreur Journal du jour (non bloquante pour le cron)', e);
      journalDuJour = { erreur: e.message };
    }

    // STATUT COHERENT AVEC CE QUI S'EST REELLEMENT PASSE (chantier A / P0-2, 14 septembre 2026).
    // Une passe qui a perdu une lecture, une ecriture ou une RPC n'est pas une passe reussie : on
    // rend 500 avec la LISTE NOMMEE des etapes fautives, ce que la plateforme sait voir et
    // alerter -- un console.error, non. Le corps reste identique par ailleurs : tout ce qui a
    // abouti est conserve et documente, rien n'est annule. Le rejeu qui suivra est sur, chaque
    // tache financiere portant desormais son marqueur de journee (voir tacheQuotidienne).
    const corps = { ok: ECHECS_PASSE.length === 0, traites: results.length, details: results, echecs: ECHECS_PASSE, nbEchecs: ECHECS_PASSE.length, detentionsLiberees, cascadeAutoPourvoi, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, cascadeMunicipale, subventionsExpirees, compromisResolus, compromisEntreprisesResolus, achatsDirectsManques, permis, chantiers, prets, pretsHelvetia, blocusExpires, effetsBlocus, effetsGrevesOrdinaires, effetsGreveGenerale, livraisons, exportationsPort, production, conflitsBNE, investissements, placementsNationaux, placementsHelvetia, creancesHelvetia, preemptions, successionsResolues, caissesFretArrivees, caissesFretMisesEnVente, cotisationsOrganisations, licencesSportives, arrivagePoissonCriee, candidaturesPostesExpirees, votesConfianceResolus, consequencesCensure, effortDeGuerre, journalDuJour, detentionsPnj, cellulesRenseignement, collecteAgents, rapportsCellules, payeDouane, payePolice, affectationsExpirees, candidaturesRelancees };
    if (ECHECS_PASSE.length > 0) {
      console.error('[cron-minuit] PASSE INCOMPLETE : ' + ECHECS_PASSE.length + ' etape(s) en echec -> ' + ECHECS_PASSE.map(e => e.etape).join(', '));
      await journaliserCron('_passe', jourPasse, 'echec',
        ECHECS_PASSE.map(e => e.etape).join(', '),
        { nbEchecs: ECHECS_PASSE.length, traites: results.length }, Date.now() - departPasse);
      return res.status(500).json(corps);
    }
    await journaliserCron('_passe', jourPasse, 'ok', null,
      { traites: results.length }, Date.now() - departPasse);
    return res.status(200).json(corps);
  } catch (e) {
    console.error('Erreur cron-minuit', e);
    await journaliserCron('_passe', jourPasse, 'echec', (e && e.message) ? e.message : String(e),
      { nbEchecs: ECHECS_PASSE.length, interrompue: true }, Date.now() - departPasse);
    return res.status(500).json({ error: e.message, echecs: ECHECS_PASSE, nbEchecs: ECHECS_PASSE.length });
  }
}
