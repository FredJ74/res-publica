// Banc du VOTE ELECTORAL (chantier 5, 9 octobre 2026). On extrait la vraie fonction voterPour de
// plateau-politique.js et on lui donne un faux sbRpc.
// SOURCES: aucune -- ce banc lit plateau-politique.js lui-meme, par readFile.
//
// CE QUE CE BANC ETABLIT. L'ancien chemin faisait DEUX ecritures clientes independantes -- la
// ligne de `votes_electoraux` dans un try/catch vide, puis le blob du cycle en `.catch(() => {})`
// -- puis annoncait « Vote enregistre ! » sans rien attendre ni rien lire : la fonction n'etait
// meme pas asynchrone. Le banc verifie qu'il n'existe plus qu'UNE porte, que son verdict est lu,
// et qu'aucune confirmation n'est donnee sans lui. Les contre-epreuves (plus bas, meme fichier)
// reinjectent l'ancienne annonce inconditionnelle et exigent que le banc rougisse.
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
var RPC = [], ECRITURES = [], TOASTS = [], JOURNAL = [];
var REPONSES = {}, state = {}, CYCLES_ELECTORAUX = {};
var PHASES_ELECTORALES = { VOTE: 'vote', VOTE2: 'vote2', VOTE3E_SIEGE: 'vote3e', MANDAT: 'mandat', REPOS: 'repos' };
var PHASE = PHASES_ELECTORALES.VOTE;

function sbRpc(nom, args) { RPC.push({ nom: nom, args: args });
  var r = REPONSES[nom];
  if (r === 'rejet') return Promise.reject(new Error('transport'));
  return Promise.resolve(r === undefined ? null : r); }
// Les deux ecritures que le vote ne doit PLUS faire lui-meme.
function sbInsert(t) { ECRITURES.push(t); return Promise.resolve([{}]); }
function sbUpsert(t) { ECRITURES.push(t); return Promise.resolve([{}]); }
function sbUpdate(t) { ECRITURES.push(t); return Promise.resolve([{}]); }
function sbSaveCycleElectoral() { ECRITURES.push('cycles_electoraux'); return Promise.resolve([{}]); }
function sbVoterPourAbsente() {}

function showToast(t, m) { TOASTS.push(t + ' | ' + m); }
function addJournalEntry(m) { JOURNAL.push(m); }
function getCleCycle(posteId, city) { return city ? posteId + '_' + city : posteId; }
function getPhaseActuelle() { return PHASE; }

eval(bloc('voterPour'));

var ko = 0, attendus = 0;
function att(n, c) { attendus++; if (c) print('  ok  ' + n); else { print('  *** ' + n); ko++; } }
function sync(p) {
  var fini = false, val;
  Promise.resolve(p).then(function (v) { val = v; fini = true; }, function (e) { val = e; fini = true; });
  for (var i = 0; i < 200 && !fini; i++) drainMicrotasks();
  if (!fini) throw new Error('promesse non resolue apres 200 vidanges');
  return val;
}
function neuf() {
  RPC = []; ECRITURES = []; TOASTS = []; JOURNAL = []; REPONSES = {};
  PHASE = PHASES_ELECTORALES.VOTE;
  state = { char: { name: 'Ben' }, country: 'republic', domicile: { country: 'republic' } };
  CYCLES_ELECTORAUX = { republic: { maire_capitale: {
    votes: {}, candidats: [{ nom: 'Arnie' }, { nom: 'Marsault' }] } } };
}
function annonceVerte() { return TOASTS.join(' | ').indexOf('Vote enregistré !') >= 0; }

print('1. UNE SEULE PORTE, ET AUCUNE ECRITURE CLIENTE');
neuf();
REPONSES['election_voter'] = [{ ok: true, votant: 'Ben', candidat: 'Arnie', cle: 'maire_capitale' }];
sync(voterPour('Arnie', 'maire', 'republic', 'capitale'));
att('la porte election_voter est appelee une fois', RPC.length === 1 && RPC[0].nom === 'election_voter');
att('aucune ecriture cliente, ni bulletin ni blob', ECRITURES.length === 0);
att("le votant n'est PAS un parametre de la porte",
    RPC[0].args.p_votant === undefined && RPC[0].args.p_nom === undefined);
att('le scrutin et le candidat sont transmis tels quels',
    RPC[0].args.p_pays === 'republic' && RPC[0].args.p_poste_id === 'maire'
    && RPC[0].args.p_ville === 'capitale' && RPC[0].args.p_candidat === 'Arnie');
att('verdict ok : le vote est annonce', annonceVerte() && JOURNAL.length === 1);
att('verdict ok : le bulletin est reflete localement', CYCLES_ELECTORAUX.republic.maire_capitale.votes.Ben === 'Arnie');

print('');
print('2. AUCUNE CONFIRMATION SANS ECRITURE AUTORITAIRE');
var refus = [
  ['deja_vote', 'Vous avez déjà voté'],
  ['vote_ferme', "Le vote n'est pas ouvert"],
  ['non_domicilie', 'Vous ne pouvez pas voter dans cet empire'],
  ['candidat_inconnu', 'Ce candidat ne figure pas'],
  ['acteur_non_authentifie', 'Session non reconnue'],
  ['cycle_absent', "n'a pas pu être enregistré"],
  ['cycle_illisible', "n'a pas pu être enregistré"]
];
for (var i = 0; i < refus.length; i++) {
  neuf();
  REPONSES['election_voter'] = [{ ok: false, raison: refus[i][0] }];
  sync(voterPour('Arnie', 'maire', 'republic', 'capitale'));
  att('refus « ' + refus[i][0] + '  » : aucun « Vote enregistré ! »', !annonceVerte());
  att('refus « ' + refus[i][0] + '  » : le motif est dit honnetement',
      TOASTS.join(' | ').indexOf(refus[i][1]) >= 0);
  att('refus « ' + refus[i][0] + '  » : aucun bulletin local',
      CYCLES_ELECTORAUX.republic.maire_capitale.votes.Ben === undefined && JOURNAL.length === 0);
}

print('');
print('3. LES TROIS PANNES QUI FAISAIENT ANNONCER UN SUCCES');
neuf();
REPONSES['election_voter'] = 'rejet';           // coupure reseau / 500
sync(voterPour('Arnie', 'maire', 'republic', 'capitale'));
att('transport rejete : la fonction ne pretend pas avoir vote',
    !annonceVerte() && CYCLES_ELECTORAUX.republic.maire_capitale.votes.Ben === undefined);
att("transport rejete : l electeur obtient quand meme un refus, pas un silence",
    TOASTS.join(' | ').indexOf('Vote non enregistré') >= 0);

neuf();
REPONSES['election_voter'] = null;              // refus RLS rendu vide
sync(voterPour('Arnie', 'maire', 'republic', 'capitale'));
att('reponse vide : aucune annonce', !annonceVerte());
att('reponse vide : le motif est « indisponible », pas un succes',
    TOASTS.join(' | ').indexOf('indisponible') >= 0);

neuf();
REPONSES['election_voter'] = [{}];              // ligne sans ok
sync(voterPour('Arnie', 'maire', 'republic', 'capitale'));
att('verdict sans ok : aucune annonce', !annonceVerte());

print('');
print('4. LES GARDES CLIENTES SUBSISTENT, ET N AJOUTENT AUCUNE REGLE');
neuf();
state.domicile = { country: 'helvetia' };
sync(voterPour('Arnie', 'maire', 'republic', 'capitale'));
att('non domicilie : la porte n est meme pas appelee', RPC.length === 0 && !annonceVerte());

neuf();
PHASE = PHASES_ELECTORALES.MANDAT;
sync(voterPour('Arnie', 'maire', 'republic', 'capitale'));
att('hors fenetre de vote : la porte n est pas appelee', RPC.length === 0 && !annonceVerte());

neuf();
CYCLES_ELECTORAUX.republic.maire_capitale.votes.Ben = 'Marsault';
sync(voterPour('Arnie', 'maire', 'republic', 'capitale'));
att('deja vote selon le blob local : la porte n est pas appelee', RPC.length === 0);
att('et le bulletin local n est pas remplace', CYCLES_ELECTORAUX.republic.maire_capitale.votes.Ben === 'Marsault');

neuf();
PHASE = PHASES_ELECTORALES.VOTE2;
REPONSES['election_voter'] = [{ ok: true }];
sync(voterPour('BLANC', 'maire', 'republic', 'capitale'));
att('second tour : le vote reste ouvert', RPC.length === 1);
att('le vote blanc traverse la porte comme un choix reel', RPC[0].args.p_candidat === 'BLANC');
att('et il est annonce comme blanc', TOASTS.join(' | ').indexOf('voté blanc') >= 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
