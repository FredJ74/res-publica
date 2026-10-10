// Banc des DEUX LIBERATIONS DE DESERTION de plateau-politique.js (chantier 5, 10 octobre 2026).
// On extrait les VRAIES fonctions du fichier de production et on leur donne un faux sbRpc.
// SOURCES: aucune -- ce banc lit plateau-politique.js lui-meme, par readFile.
//
// CE QUE CE BANC ETABLIT. `eteindrePoursuitesDesertion` (demobilisation) et
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
function showToast(t, m) { TOASTS.push(t + ' | ' + m); }
function addMailNotification(de, suj, corps) { MAILS.push(suj + ' | ' + corps); }
function addJournalEntry(m) { JOURNAL.push(m); }
function updateUI() {}
function enterBuilding() { TRACES.push('entre_batiment'); }
function enterRoom() { TRACES.push('entre_piece'); }
var document = { getElementById: function () { return null; } };

eval(bloc('estMotifDesertion'));
eval(bloc('eteindrePoursuitesDesertion'));
eval(bloc('doAccepterIncorporation'));

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
  state = { char: { name: 'Ben', requisition: { statut: 'deserteur', depuisJour: 2 } },
            country: 'republic', day: 7, mobilisationNationaleCache: true,
            recherche: [{ acte: 'desertion', country: 'republic' }, { acte: 'vol', country: 'republic' }],
            estEmprisonne: { detentionId: 'det-1', jourFin: 12, jours: 5, motifDesertionSeul: true } };
  for (var k in (etat || {})) state[k] = etat[k];
}
function rpcDe(nom) { return RPC.filter(function (r) { return r.nom === nom; }); }
function ecrituresSur(t) { return ECRITURES.filter(function (e) { return e.table === t; }); }

print('');
print('1. DEMOBILISATION : UNE PORTE, SON MODE, SON VERDICT');
neuf();
REPONSES['detention_clore_motif_eteint'] = [{ ok: true, mode: 'poursuites_eteintes',
  detention_id: 'det-1', sortait_du_qhs: false }];
sync(eteindrePoursuitesDesertion('republic'));
att('la porte est appelee une fois', rpcDe('detention_clore_motif_eteint').length === 1);
att('avec le mode « poursuites_eteintes »', rpcDe('detention_clore_motif_eteint').length === 1
    && rpcDe('detention_clore_motif_eteint')[0].args.p_mode === 'poursuites_eteintes');
att('aucune ecriture cliente sur detentions', ecrituresSur('detentions').length === 0);
att('aucune ecriture cliente sur prisonniers_qhs', ecrituresSur('prisonniers_qhs').length === 0);
att('verdict ok : le detenu est libre localement', state.estEmprisonne === null);
att('verdict ok : la liberation est annoncee', MAILS.join(' | ').indexOf('Vous êtes libéré(e)') >= 0);
att("seuls les motifs de desertion sont retires de l'avis de recherche",
    state.recherche.length === 1 && state.recherche[0].acte === 'vol');
att("l'historique de la requisition est conserve, statut eteinte",
    state.char.requisition.statut === 'eteinte' && state.char.requisition.depuisJour === 2);

print('');
print('2. DEMOBILISATION : SANS VERDICT, PERSONNE N EST LIBERE');
neuf();
REPONSES['detention_clore_motif_eteint'] = [{ ok: false, raison: 'peine_pas_seulement_desertion' }];
sync(eteindrePoursuitesDesertion('republic'));
att('refus : le detenu reste detenu', state.estEmprisonne !== null);
att('refus : aucune liberation annoncee', MAILS.join(' | ').indexOf('Vous êtes libéré(e)') < 0);
att("refus : l'ecart est NOMME au joueur", MAILS.join(' | ').indexOf('reste') >= 0);
att('refus : les autres effets de la demobilisation restent acquis',
    state.char.requisition.statut === 'eteinte' && state.recherche.length === 1);

neuf();
REPONSES['detention_clore_motif_eteint'] = 'rejet';
sync(eteindrePoursuitesDesertion('republic'));
att('transport rejete : le detenu reste detenu', state.estEmprisonne !== null);
neuf();
REPONSES['detention_clore_motif_eteint'] = [];
sync(eteindrePoursuitesDesertion('republic'));
att('reponse vide : le detenu reste detenu', state.estEmprisonne !== null);

print('');
print('3. UNE PEINE QUI NE TENAIT PAS QU A LA DESERTION N EST PAS PRESENTEE A LA PORTE');
neuf({ estEmprisonne: { detentionId: 'det-1', jourFin: 12, jours: 5 } });
REPONSES['detention_clore_motif_eteint'] = [{ ok: true }];
sync(eteindrePoursuitesDesertion('republic'));
att('la porte n est pas appelee', rpcDe('detention_clore_motif_eteint').length === 0);
att('et le detenu reste detenu', state.estEmprisonne !== null);

print('');
print('4. INCORPORATION : MEME PORTE, AUTRE MODE');
neuf();
REPONSES['detention_clore_motif_eteint'] = [{ ok: true, mode: 'incorporation',
  detention_id: 'det-1', sortait_du_qhs: false }];
sync(doAccepterIncorporation());
att('la porte est appelee une fois', rpcDe('detention_clore_motif_eteint').length === 1);
att('avec le mode « incorporation »', rpcDe('detention_clore_motif_eteint').length === 1
    && rpcDe('detention_clore_motif_eteint')[0].args.p_mode === 'incorporation');
att('aucune ecriture cliente sur detentions', ecrituresSur('detentions').length === 0);
att('verdict ok : le detenu quitte les geoles', state.estEmprisonne === null);
att('verdict ok : il est conduit a la caserne', state.currentCity === 'caserne'
    && state.currentBuilding === 'caserne-militaire');
att('verdict ok : il est incorpore', state.char.requisition.statut === 'incorpore');
att('verdict ok : le transfert est annonce', TOASTS.join(' | ').indexOf('Transfert accepté') >= 0);

print('');
print('5. INCORPORATION : SANS VERDICT, PAS DE SOLDAT DETENU');
neuf();
REPONSES['detention_clore_motif_eteint'] = [{ ok: false, raison: 'non_detenu' }];
sync(doAccepterIncorporation());
att('refus : le detenu reste detenu', state.estEmprisonne !== null);
att('refus : il n est PAS conduit a la caserne', state.currentCity !== 'caserne');
att("refus : l'incorporation posee en memoire est REVENUE en arriere",
    state.char.requisition.statut === 'deserteur');
att('refus : le refus est dit', TOASTS.join(' | ').indexOf('Transfert impossible') >= 0);
att('refus : aucune sauvegarde de fiche incoherente', TRACES.indexOf('sauvegarde') < 0);

print('');
print('6. INCORPORATION DIFFEREE : LA PEINE PORTE D AUTRES MOTIFS');
neuf({ estEmprisonne: { detentionId: 'det-1', jourFin: 12, jours: 5 } });
REPONSES['detention_clore_motif_eteint'] = [{ ok: true }];
sync(doAccepterIncorporation());
att('la porte n est pas appelee', rpcDe('detention_clore_motif_eteint').length === 0);
att('le detenu reste detenu', state.estEmprisonne !== null);
att("l'incorporation est actee mais differee",
    state.estEmprisonne.incorporationAcceptee === true
    && state.char.requisition.statut === 'incorpore');
att('et c est dit au joueur', TOASTS.join(' | ').indexOf('à votre libération') >= 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
