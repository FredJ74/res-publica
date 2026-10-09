// Banc des SEPT CHAINES JUDICIAIRES de plateau-justice-economie.js (chantier 5, 9 octobre 2026).
// On extrait les VRAIES fonctions du fichier de production et on leur donne un faux sbRpc : on ne
// teste pas une copie, on teste le texte qui part en production.
// SOURCES: aucune -- ce banc lit plateau-justice-economie.js lui-meme, par readFile.
//
// CINQ CHAINES ETAIENT A L'INVENTAIRE (9 a 13 de AUDIT-CHANTIER-5-ECRITURES-PLATEAU.md) ; DEUX
// AUTRES sont apparues en les fermant -- la reduction de peine obtenue par l'avocat et l'evasion
// reussie -- portant exactement le defaut de la chaine 11 : une liberation qui ne se persiste pas.
// Elles sont au chapitre 7.
//
// CE QUE CE BANC ETABLIT. Chacune de ces chaines enchainait de deux a quatre ecritures
// independantes, toutes avalees, puis annoncait son resultat sans condition. Le banc verifie les
// deux moities de la correction :
//   1. il n'y a PLUS d'ecriture cliente directe sur detentions / personnages / prisonniers_qhs /
//      jugements / plaintes_en_cours -- une seule porte serveur est appelee ;
//   2. le VERDICT de cette porte est consomme : sans ok, le jeu n'annonce rien et ne pose aucun
//      etat local.
// CHEMIN_SOURCE permet aux CONTRE-EPREUVES de faire lire a ce banc une copie du fichier dans
// laquelle une regression a ete reinjectee : c'est ainsi qu'on prouve qu'il rougit sans le
// correctif (voir contre-epreuves-detention.py).
var src = readFile(typeof CHEMIN_SOURCE === 'string'
  ? CHEMIN_SOURCE : '/Users/fredericjasseron/ResPublica/plateau-justice-economie.js');
function bloc(nom) {
  var i = src.indexOf('async function ' + nom + '(');
  if (i < 0) i = src.indexOf('function ' + nom + '(');
  if (i < 0) throw new Error('introuvable : ' + nom);
  var j = src.indexOf('{', i), p = 0, k = j;
  while (k < src.length) { if (src[k] === '{') p++; else if (src[k] === '}') { p--; if (!p) break; } k++; }
  return src.slice(i, k + 1);
}

// ---- Le decor : tout ce que le navigateur fournit et que jsc ne fournit pas. ----
var console = { error: function () {}, warn: function () { TRACES.push('warn'); }, log: function () {} };
var TRACES = [], RPC = [], ECRITURES = [], TOASTS = [], JOURNAL = [], EVENEMENTS = [], MAILS = [];
var REPONSES = {};                 // nom de la RPC -> verdict a rendre
var state = {};
var COUNTRIES = { republic: { cur: 'FR' } };
var WORLD = {};

function sbRpc(nom, args) { RPC.push({ nom: nom, args: args });
  var r = REPONSES[nom];
  if (r === 'rejet') return Promise.reject(new Error('transport'));
  return Promise.resolve(r === undefined ? null : r); }
// Les quatre ecritures que PLUS AUCUNE chaine ne doit faire : si l'une est appelee, le banc le voit.
function sbUpdate(table, filtre, patch) { ECRITURES.push({ f: 'sbUpdate', table: table, patch: patch }); return Promise.resolve([{}]); }
function sbInsert(table, ligne) { ECRITURES.push({ f: 'sbInsert', table: table }); return Promise.resolve([{}]); }
function sbUpsert(table, ligne) { ECRITURES.push({ f: 'sbUpsert', table: table }); return Promise.resolve([{}]); }
function sbGet(table, filtre) { ECRITURES.push({ f: 'sbGet', table: table }); return Promise.resolve([]); }
function sbSavePlainte(p) { ECRITURES.push({ f: 'sbSavePlainte', table: 'plaintes_en_cours' }); return Promise.resolve([{}]); }
function sbCreerPrisonnierQHS(d) { ECRITURES.push({ f: 'sbCreerPrisonnierQHS', table: 'prisonniers_qhs' }); return Promise.resolve('qhs-x'); }

function showToast(t, m, bon) { TOASTS.push(t + ' | ' + m); }
function addJournalEntry(m) { JOURNAL.push(m); }
function addExternalEvent(m) { EVENEMENTS.push(m); }
function addMailNotification(de, suj, corps) { MAILS.push('notif:' + suj); }
function sbSendMail(de, a, suj) { MAILS.push('mail:' + suj); return Promise.resolve(true); }
function updateUI() {}
function forceRenderCity() {}
function enterBuilding() {}
function teleporterVersCellule(e) { TRACES.push('teleporte'); }
function incrementerDetentionDeserteur() {}
function tracerActionPourRumeur() {}
function endommagerGrillePrison() { return Promise.resolve(true); }
function sbSavePersonnage() { return Promise.resolve(true); }
function formatDateHeureJeu() { return 'Jour 1'; }
var document = { getElementById: function () { return { classList: { remove: function () {} }, innerHTML: '' }; } };

var COUT_OK = true;
function deduireCoutOrdre() { return Promise.resolve({ ok: COUT_OK, raison: 'pa_insuffisants' }); }
function signalerRefusCout() { TRACES.push('refus_cout'); }
var DETENU = false;
function estActuellementDetenu() { return Promise.resolve(DETENU); }
function sbGetActionsTracablesParAuteur() { return Promise.resolve([]); }
var POP_APPELEE = false;
function sbAjusterPopJoueur() { POP_APPELEE = true; return Promise.resolve(true); }
var TRACE_APPELEE = false;
function sbTracerAction() { TRACE_APPELEE = true; return Promise.resolve(true); }
var VOL = 0;
function getStatEffective() { return VOL; }
function getIndiceVille() { return 45; }
var INDICES_NATIONAUX = { republic: { ISN: 45 } };
function consommerBonusBenediction(t) { return t; }
var BONUS_DESERTEUR = 0;
function bonusEvasionDeserteur() { return BONUS_DESERTEUR; }
var RECHERCHES = [];
function ajouterCondamnationRecherche(nom, entree) { RECHERCHES.push(entree); return Promise.resolve(true); }

// Les cinq fonctions eprouvees, extraites telles quelles.
eval(bloc('enregistrerDetention'));
eval(bloc('verifierLiberationPrisonniers'));
eval(bloc('doSeRebeller'));
eval(bloc('placerAuQHS'));
eval(bloc('appliquerSentence'));
eval(bloc('confirmerRequeteAvocat'));
eval(bloc('doTentativeEvasion'));
// prolongerDetentionActive est extraite SOUS UN AUTRE NOM pour les deux premiers chapitres, parce
// que appliquerSentence et placerAuQHS ont besoin d'une version pilotable.
var reelleProlonger = bloc('prolongerDetentionActive').replace('prolongerDetentionActive(', 'prolongerReelle(');
eval(reelleProlonger);
var PROLONGER_OK = true;
function prolongerDetentionActive(nom, motifs, qhs) { TRACES.push('prolonge'); return Promise.resolve(PROLONGER_OK); }

var ko = 0, attendus = 0;
function att(n, c) { attendus++; if (c) print('  ok  ' + n); else { print('  *** ' + n); ko++; } }
function sync(p) {
  var fini = false, val;
  Promise.resolve(p).then(function (v) { val = v; fini = true; }, function (e) { val = e; fini = true; });
  for (var i = 0; i < 200 && !fini; i++) drainMicrotasks();
  if (!fini) throw new Error('promesse non resolue apres 200 vidanges');
  return val;
}
function neuf(etat) {
  RPC = []; ECRITURES = []; TOASTS = []; JOURNAL = []; EVENEMENTS = []; MAILS = []; TRACES = [];
  REPONSES = {}; POP_APPELEE = false; TRACE_APPELEE = false; RECHERCHES = []; BONUS_DESERTEUR = 0;
  state = { char: { name: 'Ben', photoUrl: 'photo' }, country: 'republic', currentCity: 'capitale',
            day: 1, hour: 8, hp: 100, dis: 50, estEmprisonne: null, prisonniers: [], employes: [] };
  for (var k in (etat || {})) state[k] = etat[k];
}
function ecrituresSur(table) { return ECRITURES.filter(function (e) { return e.table === table; }); }
function rpcDe(nom) { return RPC.filter(function (r) { return r.nom === nom; }); }

print('1. OUVRIR UNE DETENTION : UNE SEULE PORTE, ET SON VERDICT');
neuf();
REPONSES['detention_ouvrir_soi'] = [{ ok: true, detention_id: 'det-1', jour_debut: 1, jour_fin: 7 }];
var id = sync(enregistrerDetention('Ben', 'Vol', 10, undefined, 'capitale', { country: 'republic', motifs: [{ type: 'Vol', jours: 9 }] }));
att('la porte detention_ouvrir_soi est appelee une fois', rpcDe('detention_ouvrir_soi').length === 1);
att('aucune ecriture cliente dans detentions', ecrituresSur('detentions').length === 0);
att('aucune ecriture cliente dans personnages', ecrituresSur('personnages').length === 0);
att("l'identifiant rendu est celui du serveur", id === 'det-1');
att('le jour de fin retenu est CELUI DU SERVEUR, pas celui passe par le client',
    state.estEmprisonne.jourFin === 7 && state.estEmprisonne.jours === 6);
att('la duree envoyee au serveur est une DUREE, pas une date', rpcDe('detention_ouvrir_soi')[0].args.p_jours === 9);

neuf();
REPONSES['detention_ouvrir_soi'] = [{ ok: true, detention_id: 'det-2', jour_debut: 3, jour_fin: 8 }];
sync(enregistrerDetention('Ben', 'Sentence', 9, true, 'qhs', {
  country: 'republic', motifs: [{ type: 'S', jours: 6 }], jourAffaire: 4, issueJudiciaire: 'prison',
  autorite: 'juge', villeCondamnation: 'ville_a', detentionPrecedenteId: 'det-0', reliquatJours: 2,
  retourVille: 'ville_a' }));
var ex = rpcDe('detention_ouvrir_soi')[0].args.p_extras;
att('les six metadonnees judiciaires traversent la porte',
    ex.jour_affaire === 4 && ex.issue_judiciaire === 'prison' && ex.autorite === 'juge'
    && ex.ville_condamnation === 'ville_a' && ex.detention_precedente_id === 'det-0'
    && ex.reliquat_jours === 2 && ex.retour_ville === 'ville_a');
att('le caractere QHS est demande a la porte, pas ecrit par le client',
    rpcDe('detention_ouvrir_soi')[0].args.p_qhs === true && ecrituresSur('prisonniers_qhs').length === 0);

neuf();
REPONSES['detention_ouvrir_soi'] = [{ ok: false, raison: 'cible_deja_detenue' }];
id = sync(enregistrerDetention('Ben', 'Vol', 5, undefined, 'capitale', {}));
att('verdict refuse : aucun identifiant rendu', id === null);
att('verdict refuse : aucun etat de detention pose', state.estEmprisonne === null);
att('verdict refuse : aucun prisonnier ajoute a la liste locale', state.prisonniers.length === 0);

neuf();
id = sync(enregistrerDetention('Ben', 'Vol', null, undefined, 'capitale', {}));
att('une peine sans terme est refusee, pas inventee', id === null && rpcDe('detention_ouvrir_soi').length === 0);

print('');
print('2. PROLONGER : UN MOTEUR, DEUX PORTES');
neuf({ estEmprisonne: { detentionId: 'det-1', jours: 3, jourFin: 4 } });
REPONSES['detention_prolonger_soi'] = [{ ok: true, jours_ajoutes: 1, jour_fin: 5, detention_id: 'det-1' }];
var r = sync(prolongerReelle('Ben', [{ type: 'Rebellion', jours: 1 }]));
att('sur soi-meme : la porte detention_prolonger_soi', rpcDe('detention_prolonger_soi').length === 1);
att('et jamais celle du juge', rpcDe('justice_prolonger_peine').length === 0);
att('la cible n est PAS un parametre de la porte du detenu',
    rpcDe('detention_prolonger_soi')[0].args.p_nom === undefined && rpcDe('detention_prolonger_soi')[0].args.p_cible === undefined);
att('aucune relecture cliente des motifs de la detention', ecrituresSur('detentions').length === 0);
att('aucune ecriture cliente sur la fiche', ecrituresSur('personnages').length === 0);
att('le jour de fin vient du serveur', r === true && state.estEmprisonne.jourFin === 5 && state.estEmprisonne.jours === 4);

neuf({ estEmprisonne: { detentionId: 'det-1', jours: 3, jourFin: 4 } });
REPONSES['justice_prolonger_peine'] = [{ ok: true, jours_ajoutes: 3, jour_fin: 7 }];
r = sync(prolongerReelle('Marsault', [{ type: 'Jugement', jours: 3 }]));
att('sur un tiers : la porte du juge', rpcDe('justice_prolonger_peine').length === 1 && r === true);
att('et jamais celle du detenu', rpcDe('detention_prolonger_soi').length === 0);
att('la peine du joueur courant n est pas touchee par celle d un tiers', state.estEmprisonne.jourFin === 4);

neuf({ estEmprisonne: { detentionId: 'det-1', jours: 3, jourFin: 4 } });
REPONSES['detention_prolonger_soi'] = [{ ok: false, raison: 'cible_non_detenue' }];
r = sync(prolongerReelle('Ben', [{ type: 'Rebellion', jours: 1 }]));
att('verdict refuse : false rendu et peine inchangee',
    r === false && state.estEmprisonne.jourFin === 4 && state.estEmprisonne.jours === 3);

print('');
print('3. FIN DE PEINE : AUCUNE LIBERATION SANS VERDICT');
neuf({ day: 9, estEmprisonne: { detentionId: 'det-1', jourFin: 5, qhs: true, retourVille: null } });
REPONSES['detention_clore_purgee'] = [{ ok: false, raison: 'peine_non_purgee', jour: 3, jour_fin: 5 }];
sync(verifierLiberationPrisonniers());
att('la porte est appelee', rpcDe('detention_clore_purgee').length === 1);
att('refus : le detenu reste detenu', state.estEmprisonne !== null);
att('refus : aucune liberation annoncee', MAILS.length === 0 && JOURNAL.length === 0);
att('refus : aucune ecriture cliente', ECRITURES.length === 0);

neuf({ day: 9, estEmprisonne: { detentionId: 'det-1', jourFin: 5, qhs: true, retourVille: null },
       detentionQHS: { enQHS: true } });
REPONSES['detention_clore_purgee'] = [{ ok: true, detention_id: 'det-1', jour: 9, sortait_du_qhs: true, retour_ville: null }];
sync(verifierLiberationPrisonniers());
att('verdict ok : le detenu est libre', state.estEmprisonne === null);
att('verdict ok : le drapeau QHS local tombe', state.detentionQHS === null);
att('verdict ok : la liberation est annoncee une fois', MAILS.length === 1 && JOURNAL.length === 1);
att('aucune ecriture cliente sur detentions ni personnages',
    ecrituresSur('detentions').length === 0 && ecrituresSur('personnages').length === 0);

print('');
print('4. TRANSFERT AU QHS : QUATRE ECRITURES DEVENUES UNE');
VOL = 0;  // taux de reussite nul : la rebellion est matee a coup sur
neuf({ estEmprisonne: { detentionId: 'det-1', jourFin: 4 } });
REPONSES['detention_transferer_qhs'] = [{ ok: true, detention_id: 'det-9', jour_fin: 31, qhs: true, detention_precedente: 'det-1' }];
sync(doSeRebeller(1, 0));
att('la porte detention_transferer_qhs est appelee', rpcDe('detention_transferer_qhs').length === 1);
att('aucune cloture cliente de l ancienne ligne', ecrituresSur('detentions').length === 0);
att('aucune inscription cliente au registre du QHS', ecrituresSur('prisonniers_qhs').length === 0);
att('aucun drapeau QHS ecrit par le client', ecrituresSur('personnages').length === 0);
att('la nouvelle peine est celle du serveur',
    state.estEmprisonne.detentionId === 'det-9' && state.estEmprisonne.jourFin === 31 && state.estEmprisonne.qhs === true);
att('le drapeau local est un OBJET, jamais une chaine',
    typeof state.detentionQHS === 'object' && state.detentionQHS.enQHS === true);
att('le transfert est annonce', TOASTS.join(' | ').indexOf('Transfere au QHS') >= 0);

neuf({ estEmprisonne: { detentionId: 'det-1', jourFin: 4 } });
REPONSES['detention_transferer_qhs'] = [{ ok: false, raison: 'non_detenu' }];
sync(doSeRebeller(1, 0));
att('verdict refuse : aucun QHS annonce', TOASTS.join(' | ').indexOf('Transfere au QHS') < 0);
att('verdict refuse : la peine en cours reste celle qui vaut', state.estEmprisonne.detentionId === 'det-1');
att('verdict refuse : la rebellion elle-meme est quand meme racontee', TOASTS.length === 1);

print('');
print('5. PLACEMENT AU QHS : PAS DE TELEPORTATION SANS PEINE');
neuf();
PROLONGER_OK = false;
REPONSES['detention_ouvrir_soi'] = [{ ok: false, raison: 'cible_deja_detenue' }];
sync(placerAuQHS('republic', 5, 'Vol a la caserne', 'ville_a'));
att('aucune peine ouverte : personne n est teleporte', TRACES.indexOf('teleporte') < 0);
att('et le refus est dit', TOASTS.join(' | ').indexOf('Transfert impossible') >= 0);

neuf();
REPONSES['detention_ouvrir_soi'] = [{ ok: true, detention_id: 'det-4', jour_debut: 1, jour_fin: 6 }];
sync(placerAuQHS('republic', 5, 'Vol a la caserne', 'ville_a'));
att('peine ouverte : teleportation en cellule', TRACES.indexOf('teleporte') >= 0);
att('la ville de retour traverse la porte', rpcDe('detention_ouvrir_soi')[0].args.p_extras.retour_ville === 'ville_a');
att('aucune inscription cliente au registre du QHS', ecrituresSur('prisonniers_qhs').length === 0);
PROLONGER_OK = true;

print('');
print('6. SENTENCE : RIEN N EST ANNONCE QUI NE SOIT ECRIT');
var affaire = { id: 'plainte-1', country: 'republic', city: 'capitale', cible: 'Marsault',
                motif: 'Vol aggrave', status: 'deposee', jour: 1 };
function affaireNeuve() { var a = {}; for (var k in affaire) a[k] = affaire[k]; return a; }

// LA COMPETENCE EST VERIFIEE AVANT TOUTE CONSEQUENCE : sans cela, un magistrat incompetent
// voyait sa sanction appliquee puis son archivage refuse, et l'affaire restait rejugeable --
// donc la peine infligeable deux fois.
neuf(); DETENU = true; COUT_OK = true;
state.plaintesEnCours = [affaireNeuve()];
REPONSES['affaire_autorite_de'] = false;
sync(appliquerSentence('plainte-1', 'qhs', 1, 0));
att('competence refusee : la porte du greffe n est PAS appelee', rpcDe('justice_rendre_sentence').length === 0);
att('competence refusee : AUCUNE sanction appliquee', TRACES.indexOf('prolonge') < 0);
att('competence refusee : le PA n est meme pas preleve', TRACES.indexOf('refus_cout') < 0 && RPC.length === 1);
att('competence refusee : le refus est dit', TOASTS.join(' | ').indexOf('Compétence refusée') >= 0);

neuf(); DETENU = true; COUT_OK = true;
state.plaintesEnCours = [affaireNeuve()];
REPONSES['affaire_autorite_de'] = true;
REPONSES['justice_rendre_sentence'] = [{ ok: false, raison: 'affaire_deja_jugee' }];
sync(appliquerSentence('plainte-1', 'qhs', 1, 0));
att('la porte justice_rendre_sentence est appelee', rpcDe('justice_rendre_sentence').length === 1);
att('refus d autorite : aucune sentence annoncee', TOASTS.join(' | ').indexOf('Sentence rendue') < 0);
att('refus d autorite : aucun evenement public', EVENEMENTS.length === 0);
att('refus d autorite : aucun courrier au condamne', MAILS.length === 0);
att("refus d autorite : l affaire reste au role", state.plaintesEnCours[0].status === 'deposee');
att('refus d autorite : aucun jugement ecrit par le client', ecrituresSur('jugements').length === 0);
att("refus d autorite : l affaire n est pas reecrite par le client", ecrituresSur('plaintes_en_cours').length === 0);

neuf(); DETENU = true;
state.plaintesEnCours = [affaireNeuve()];
REPONSES['affaire_autorite_de'] = true;
REPONSES['justice_rendre_sentence'] = [{ ok: true, jugement_id: 'jug-plainte-1', juge: 'Ben', jour: 1 }];
sync(appliquerSentence('plainte-1', 'qhs', 1, 0));
att('verdict ok : la sentence est annoncee', TOASTS.join(' | ').indexOf('Sentence rendue') >= 0);
att('verdict ok : le magistrat nomme est CELUI DU SERVEUR',
    EVENEMENTS.join(' ').indexOf('Juge : Ben') >= 0);
att('verdict ok : le condamne est averti', MAILS.length === 1);
att("verdict ok : l archive locale porte le jour du serveur",
    state.archivesJugements.length === 1 && state.archivesJugements[0].jour === 1);

neuf(); DETENU = true; PROLONGER_OK = false;
state.plaintesEnCours = [affaireNeuve()];
REPONSES['affaire_autorite_de'] = true;
REPONSES['justice_rendre_sentence'] = [{ ok: true, jugement_id: 'jug-plainte-1', juge: 'Ben', jour: 1 }];
sync(appliquerSentence('plainte-1', 'qhs', 1, 0));
att('peine non appliquee : la porte du greffe n est meme pas appelee', rpcDe('justice_rendre_sentence').length === 0);
att('peine non appliquee : aucune sentence annoncee', TOASTS.join(' | ').indexOf('Sentence rendue') < 0);
att("peine non appliquee : l affaire reste au role", state.plaintesEnCours[0].status === 'deposee');

neuf(); DETENU = true; PROLONGER_OK = false;
state.plaintesEnCours = [affaireNeuve()];
REPONSES['affaire_autorite_de'] = true;
sync(appliquerSentence('plainte-1', 'torture', 1, 0));
att('torture refusee : la popularite n est pas abaissee', POP_APPELEE === false);
att('torture refusee : la condamnation n est pas comptee au cumul', TRACE_APPELEE === false);
PROLONGER_OK = true;

print('');
print('7. L AVOCAT ET L EVASION : DEUX CHAINES QUE L INVENTAIRE AVAIT MANQUEES');
// LE TIRAGE EST MAITRISE, sinon ces epreuves seraient aleatoires : Math.random est remplace.
var TIRAGE = 0;
Math.random = function () { return TIRAGE; };

neuf({ arg: 5000, estEmprisonne: { detentionId: 'det-1', jourFin: 12, jours: 11 } });
VOL = 30; TIRAGE = 0;            // roll = 1, la plaidoirie est acceptee
REPONSES['detention_reduire_peine'] = [{ ok: true, acceptee: true, reduction: 6, jour_fin: 6, jours: 5, libere: false }];
sync(confirmerRequeteAvocat(1, 0));
att('la porte detention_reduire_peine est appelee', rpcDe('detention_reduire_peine').length === 1);
att('aucune ecriture cliente sur detentions', ecrituresSur('detentions').length === 0);
att('le resultat de la plaidoirie est transmis, pas le montant',
    rpcDe('detention_reduire_peine')[0].args.p_requete_acceptee === true
    && rpcDe('detention_reduire_peine')[0].args.p_reduction === undefined);
att('la nouvelle peine est celle du serveur',
    state.estEmprisonne.jourFin === 6 && state.estEmprisonne.jours === 5);
att('et l avocat est marque consomme', state.estEmprisonne.avocatUtilise === true);
att('la reduction est annoncee', TOASTS.join(' | ').indexOf('Réduction obtenue') >= 0);

neuf({ arg: 5000, estEmprisonne: { detentionId: 'det-1', jourFin: 2, jours: 1 } });
VOL = 30; TIRAGE = 0;
REPONSES['detention_reduire_peine'] = [{ ok: true, acceptee: true, reduction: 1, jour_fin: 1, jours: 0, libere: true }];
sync(confirmerRequeteAvocat(1, 0));
att('reduction liberatrice : le detenu est libre', state.estEmprisonne === null);
att('et la liberation est annoncee', TOASTS.join(' | ').indexOf('Libéré(e) !') >= 0);

neuf({ arg: 5000, estEmprisonne: { detentionId: 'det-1', jourFin: 12, jours: 11 } });
VOL = 0; TIRAGE = 0.999;         // roll = 100, la plaidoirie est refusee
REPONSES['detention_reduire_peine'] = [{ ok: true, acceptee: false, reduction: 0, libere: false }];
sync(confirmerRequeteAvocat(1, 0));
att('requete refusee : la porte est quand meme appelee, pour consommer l avocat',
    rpcDe('detention_reduire_peine').length === 1
    && rpcDe('detention_reduire_peine')[0].args.p_requete_acceptee === false);
att('requete refusee : la peine ne bouge pas',
    state.estEmprisonne.jourFin === 12 && state.estEmprisonne.jours === 11);
att('requete refusee : aucune reduction annoncee', TOASTS.join(' | ').indexOf('Réduction obtenue') < 0);

neuf({ arg: 5000, estEmprisonne: { detentionId: 'det-1', jourFin: 12, jours: 11 } });
VOL = 30; TIRAGE = 0;
REPONSES['detention_reduire_peine'] = [{ ok: false, raison: 'avocat_deja_utilise' }];
sync(confirmerRequeteAvocat(1, 0));
att('verdict refuse : aucune reduction annoncee', TOASTS.join(' | ').indexOf('Réduction obtenue') < 0);
att('verdict refuse : la peine reste intacte', state.estEmprisonne.jourFin === 12);
att('verdict refuse : le refus est dit', TOASTS.join(' | ').indexOf('Requête non déposée') >= 0);

neuf({ estEmprisonne: { detentionId: 'det-1', jourFin: 9, jours: 8 } });
VOL = 30; TIRAGE = 0; BONUS_DESERTEUR = 90;
REPONSES['detention_clore_evasion'] = [{ ok: true, detention_id: 'det-1', reliquat_jours: 8,
  motifs: [{ type: 'Vol', jours: 8 }], country: 'republic', jour: 1 }];
sync(doTentativeEvasion(1, 0));
att('la porte detention_clore_evasion est appelee', rpcDe('detention_clore_evasion').length === 1);
att('aucune lecture ni ecriture cliente de detentions', ecrituresSur('detentions').length === 0);
att('le detenu est libre localement', state.estEmprisonne === null);
att('l evasion est annoncee', TOASTS.join(' | ').indexOf('Evasion reussie !') >= 0);
att('l avis de recherche conserve les motifs d origine rendus par la porte',
    RECHERCHES.length === 1 && RECHERCHES[0].motifs.length === 2
    && RECHERCHES[0].motifs[0].type === 'Vol' && RECHERCHES[0].motifs[1].type === 'Évasion');
att('et le reliquat vient du serveur', RECHERCHES.length === 1 && RECHERCHES[0].reliquat_jours === 8);
att('la detention precedente est citee', RECHERCHES.length === 1 && RECHERCHES[0].detention_precedente_id === 'det-1');

neuf({ estEmprisonne: { detentionId: 'det-1', jourFin: 9, jours: 8 } });
VOL = 30; TIRAGE = 0; BONUS_DESERTEUR = 90;
REPONSES['detention_clore_evasion'] = [{ ok: false, raison: 'non_detenu' }];
sync(doTentativeEvasion(1, 0));
att('verdict refuse : aucune evasion annoncee', TOASTS.join(' | ').indexOf('Evasion reussie') < 0);
att('verdict refuse : le detenu reste detenu', state.estEmprisonne !== null);
att('verdict refuse : aucun avis de recherche emis', RECHERCHES.length === 0);
att('verdict refuse : le refus est dit', TOASTS.join(' | ').indexOf('Evasion manquee') >= 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
