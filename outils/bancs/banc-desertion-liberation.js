// Banc des DEUX LIBERATIONS DE DESERTION de plateau-politique.js (chantier 5, 10 octobre 2026).
// On extrait les VRAIES fonctions du fichier de production et on leur donne un faux sbRpc.
// SOURCES: aucune -- ce banc lit plateau-politique.js lui-meme, par readFile.
//
// MIS A JOUR LE 04/11/2026 : la demobilisation est nationale et faite par le serveur
// (militaire_mobilisation_fixer, banc SQL banc-deserteurs-liberation.sql) ; l'ecran n'a plus de
// eteindrePoursuitesDesertion. L'incorporation appelle TOUJOURS la porte : c'est le serveur qui lit
// les motifs de la detention (le drapeau motifDesertionSeul n'etait pose par personne).
//
// HISTORIQUE. `eteindrePoursuitesDesertion` (demobilisation) et
// `doAccepterIncorporation` (transfert a la caserne) vidaient `state.estEmprisonne` et comptaient
// sur sbSavePersonnage pour le persister -- mais NE CLOSAIENT JAMAIS la ligne `detentions`. Le
// registre carceral declarait donc detenu, indefiniment, un personnage libre.
//
// Le banc verifie les deux moities de la correction : une seule porte serveur est appelee, avec le
// bon mode de fin, et son VERDICT est consomme -- sans lui, le jeu ne libere pas et ne conduit
// personne a la caserne.
var src = readFile(typeof CHEMIN_SOURCE === 'string'
  ? CHEMIN_SOURCE : '/Users/fredericjasseron/ResPublica/plateau-politique.js');
function bloc(nom) {
  var i = src.indexOf('async function ' + nom + '(');
  if (i < 0) i = src.indexOf('function ' + nom + '(');
  if (i < 0) throw new Error('introuvable : ' + nom);
  var j = src.indexOf('{', i), p = 0, k = j;
  while (k < src.length) { if (src[k] === '{') p++; else if (src[k] === '}') { p--; if (!p) break; } k++; }
  return src.slice(i, k + 1);
}

var console = { error: function () {}, warn: function () {}, log: function () {} };
var RPC = [], ECRITURES = [], TOASTS = [], MAILS = [], JOURNAL = [], TRACES = [];
var REPONSES = {}, state = {};

function sbRpc(nom, args) { RPC.push({ nom: nom, args: args });
  var r = REPONSES[nom];
  if (r === 'rejet') return Promise.reject(new Error('transport'));
  return Promise.resolve(r === undefined ? null : r); }
// Les ecritures que PLUS AUCUN de ces deux chemins ne doit faire sur le registre carceral.
function sbUpdate(table, filtre, patch) { ECRITURES.push({ table: table, patch: patch }); return Promise.resolve([{}]); }
function sbInsert(table) { ECRITURES.push({ table: table }); return Promise.resolve([{}]); }
function sbSavePersonnage() { TRACES.push('sauvegarde'); return Promise.resolve(true); }
// LE RETRAIT DE L'AVIS DE RECHERCHE EST UNE PORTE DEPUIS LE 10 OCTOBRE 2026 (chaine 14). Le
// decor l'enregistre ET applique le filtre serveur, pour que les epreuves qui portent sur
// `state.recherche` continuent de mesurer un etat et pas seulement un appel.
var RETRAITS = [];
function retirerRecherche(actes, pays) {
  RETRAITS.push({ actes: actes, pays: pays || null });
  state.recherche = (state.recherche || []).filter(function (e) {
    return !(actes.indexOf(e.acte) >= 0 && (!pays || !e.country || e.country === pays));
  });
  return Promise.resolve(true);
}
function showToast(t, m) { TOASTS.push(t + ' | ' + m); }
function addMailNotification(de, suj, corps) { MAILS.push(suj + ' | ' + corps); }
function addJournalEntry(m) { JOURNAL.push(m); }
function updateUI() {}
function enterBuilding() { TRACES.push('entre_batiment'); }
function enterRoom() { TRACES.push('entre_piece'); }
var document = { getElementById: function () { return null; } };

eval(bloc('doAccepterIncorporation'));
async function adopterPositionServeurRelue() { TRACES.push('position_relue'); }
// Relecture de la fiche apres la porte : le serveur a retire le seul motif de desertion.
function sbLoadPersonnage() { return Promise.resolve({ recherche: (state.recherche || []).filter(function (e) { return e.acte !== 'desertion'; }) }); }

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
  RPC = []; ECRITURES = []; TOASTS = []; MAILS = []; JOURNAL = []; TRACES = []; REPONSES = {};
  RETRAITS = [];
  state = { char: { name: 'Ben', requisition: { statut: 'deserteur', depuisJour: 2 } },
            country: 'republic', day: 7, mobilisationNationaleCache: true,
            recherche: [{ acte: 'desertion', country: 'republic' }, { acte: 'vol', country: 'republic' }],
            estEmprisonne: { detentionId: 'det-1', jourFin: 12, jours: 5 } };
  for (var k in (etat || {})) state[k] = etat[k];
}
function rpcDe(nom) { return RPC.filter(function (r) { return r.nom === nom; }); }
function ecrituresSur(t) { return ECRITURES.filter(function (e) { return e.table === t; }); }

print('');
print('1. DEMOBILISATION : PLUS AUCUNE EXTINCTION LOCALE');
att("eteindrePoursuitesDesertion n'existe plus", src.indexOf('async function eteindrePoursuitesDesertion(') < 0);
att('doDemobiliser lit les liberes rendus par le serveur', bloc('doDemobiliser').indexOf('rDemob.extinction') >= 0);
att('plus aucun drapeau motifDesertionSeul lu par l ecran', !/estEmprisonne\.motifDesertionSeul/.test(src));

print('');
print('2. INCORPORATION, SEULE DESERTION : LA PORTE CLOT ET CONDUIT A LA CASERNE');
neuf();
REPONSES['detention_clore_motif_eteint'] = [{ ok: true, mode: 'incorporation', differee: false, detention_id: 'det-1' }];
sync(doAccepterIncorporation());
att('la porte est appelee une fois, mode incorporation', rpcDe('detention_clore_motif_eteint').length === 1
    && rpcDe('detention_clore_motif_eteint')[0].args.p_mode === 'incorporation');
att('aucune ecriture cliente sur detentions', ecrituresSur('detentions').length === 0);
att('verdict ok : le detenu quitte les geoles', state.estEmprisonne === null);
att('verdict ok : il est conduit a la caserne', state.currentCity === 'caserne' && state.currentBuilding === 'caserne-militaire');
att('verdict ok : il est incorpore', state.char.requisition.statut === 'incorpore');
att('seul le motif de desertion disparait de l avis', state.recherche.length === 1 && state.recherche[0].acte === 'vol');
att("aucun retrait d'avis demande par l'ecran (fait par la porte)", RETRAITS.length === 0);

print('');
print('3. INCORPORATION : SANS VERDICT, PAS DE SOLDAT DETENU');
neuf();
REPONSES['detention_clore_motif_eteint'] = [{ ok: false, raison: 'non_detenu' }];
sync(doAccepterIncorporation());
att('refus : le detenu reste detenu', state.estEmprisonne !== null);
att('refus : il n est PAS conduit a la caserne', state.currentCity !== 'caserne');
att('refus : la requisition reste deserteur', state.char.requisition.statut === 'deserteur');
att('refus : le refus est dit', TOASTS.join(' | ').indexOf('Transfert impossible') >= 0);
att('refus : aucune sauvegarde de fiche', TRACES.indexOf('sauvegarde') < 0);
neuf();
REPONSES['detention_clore_motif_eteint'] = 'rejet';
sync(doAccepterIncorporation());
att('transport rejete : le detenu reste detenu', state.estEmprisonne !== null && state.char.requisition.statut === 'deserteur');
neuf();
REPONSES['detention_clore_motif_eteint'] = [{ ok: false, raison: 'mobilisation_levee' }];
sync(doAccepterIncorporation());
att('mobilisation levee : le motif est nomme', TOASTS.join(' | ').indexOf('mobilisation est levée') >= 0);

print('');
print('4. INCORPORATION DIFFEREE : LA PEINE PORTE D AUTRES MOTIFS');
neuf();
REPONSES['detention_clore_motif_eteint'] = [{ ok: true, mode: 'incorporation', differee: true }];
sync(doAccepterIncorporation());
att('la porte est appelee (le serveur lit les motifs)', rpcDe('detention_clore_motif_eteint').length === 1);
att('le detenu reste detenu', state.estEmprisonne !== null);
att("l'incorporation est actee", state.char.requisition.statut === 'incorpore');
att('il reste aux geoles', state.currentCity !== 'caserne');
att('et c est dit au joueur', TOASTS.join(' | ').indexOf('à votre libération') >= 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
