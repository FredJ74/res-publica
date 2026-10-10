// Banc des DEUX TAUX D'IMPOSITION de plateau-justice-economie.js (chantier 5, chaine 8,
// 10 octobre 2026). On extrait les VRAIES fonctions du fichier de production.
// SOURCES: aucune -- ce banc lit plateau-justice-economie.js lui-meme, par readFile.
//
// CE QUE CE BANC ETABLIT. validerImpotsLocauxReel et validerImpotNational prelevaient 2 PA par
// deduireCoutOrdre, PUIS relisaient le blob du budget, posaient le taux dedans et le REECRIVAIENT
// EN ENTIER -- sans condition de version, sans lire le retour, et avec un toast inconditionnel.
// Trois defauts en un : une modification concurrente d'un autre champ du budget etait perdue, la
// cle du budget venait du client (un maire de Luthecia pouvait taxer Port-Sainte-Marie), et un
// maire pouvait payer sans que rien ne change tout en lisant « Impots locaux fixes ».
//
// Le banc verifie les deux moities : un seul appel a taux_imposition_fixer, aucune cle de budget
// transmise, aucune ecriture directe de budget, et le SUCCES N'EST ANNONCE QUE SUR VERDICT -- avec
// le taux rendu par le serveur, jamais celui du curseur.
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

var console = { error: function () {}, warn: function () {}, log: function () {} };
var RPC = [], TOASTS = [], EVENTS = [], JOURNAL = [], PAIEMENTS = [], REFUS_COUT = [];
var REPONSE = null, VALEUR_CURSEUR = '22', MODAL_FERMEE = false;
var state = { _ordreEnCours: 'fixer_impots_locaux', country: 'republic' };

function sbRpc(nom, args) {
  RPC.push({ nom: nom, args: args });
  if (REPONSE === 'rejet') return Promise.reject(new Error('transport'));
  return Promise.resolve(REPONSE);
}
// Les deux primitives que PLUS AUCUN de ces chemins ne doit appeler.
function deduireCoutOrdre() { RPC.push({ nom: 'deduireCoutOrdre' }); return Promise.resolve({ ok: true }); }
function sbGetBudgetMunicipal() { RPC.push({ nom: 'sbGetBudgetMunicipal' }); return Promise.resolve({}); }
function sbSaveBudgetMunicipal() { RPC.push({ nom: 'sbSaveBudgetMunicipal' }); return Promise.resolve(true); }
function chargerBudgetNational() { RPC.push({ nom: 'chargerBudgetNational' }); return Promise.resolve({}); }
function sbSaveBudgetNational() { RPC.push({ nom: 'sbSaveBudgetNational' }); return Promise.resolve(true); }

function showToast(t, m, ok) { TOASTS.push({ titre: t, message: m, ok: ok === true }); }
function addExternalEvent(m) { EVENTS.push(m); }
function addJournalEntry(m) { JOURNAL.push(m); }
function appliquerPaiementServeur(r) { PAIEMENTS.push(r); return true; }
function signalerRefusCout(r) { REFUS_COUT.push(r); }
var COUNTRIES = { republic: { cur: 'FR' } };
var document = { getElementById: function (id) {
  if (id === 'taux-local-input' || id === 'taux-national-input') return { value: VALEUR_CURSEUR };
  if (id === 'modal-postes') return { classList: { remove: function () { MODAL_FERMEE = true; } } };
  return null;
} };

eval(bloc('signalerRefusTauxImposition'));
eval(bloc('fixerTauxImposition'));
eval(bloc('validerImpotsLocauxReel'));
eval(bloc('validerImpotNational'));

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function sync(p) {
  var fini = false, val;
  Promise.resolve(p).then(function (v) { val = v; fini = true; }, function (e) { val = e; fini = true; });
  for (var i = 0; i < 200 && !fini; i++) drainMicrotasks();
  if (!fini) throw new Error('promesse non resolue apres 200 vidanges');
  return val;
}
function neuf(reponse, curseur, ordre) {
  RPC = []; TOASTS = []; EVENTS = []; JOURNAL = []; PAIEMENTS = []; REFUS_COUT = [];
  MODAL_FERMEE = false;
  REPONSE = reponse === undefined ? null : reponse;
  VALEUR_CURSEUR = curseur === undefined ? '22' : curseur;
  state = { _ordreEnCours: ordre === undefined ? 'fixer_impots_locaux' : ordre,
            country: 'republic' };
}
function rpcDe(nom) { return RPC.filter(function (r) { return r.nom === nom; }); }
function succes() { return TOASTS.filter(function (t) { return t.ok; }); }
function anciennesPrimitives() {
  return RPC.filter(function (r) {
    return r.nom === 'deduireCoutOrdre' || r.nom === 'sbGetBudgetMunicipal'
        || r.nom === 'sbSaveBudgetMunicipal' || r.nom === 'chargerBudgetNational'
        || r.nom === 'sbSaveBudgetNational';
  });
}

print('');
print('1. TAUX LOCAL : UNE PORTE, SES ARGUMENTS, AUCUNE ANCIENNE PRIMITIVE');
neuf([{ ok: true, portee: 'local', taux: 22, cle: 'republic_capitale', ville: 'capitale',
        pa: 8, liquide: 100, arg: 500 }]);
sync(validerImpotsLocauxReel(2, 0));
att('la porte est appelee une fois', rpcDe('taux_imposition_fixer').length === 1);
att('avec la portee, le taux, le nom d ordre et le cout',
    rpcDe('taux_imposition_fixer').length === 1
    && rpcDe('taux_imposition_fixer')[0].args.p_portee === 'local'
    && rpcDe('taux_imposition_fixer')[0].args.p_taux === 22
    && rpcDe('taux_imposition_fixer')[0].args.p_fn === 'fixer_impots_locaux'
    && rpcDe('taux_imposition_fixer')[0].args.p_pa === 2
    && rpcDe('taux_imposition_fixer')[0].args.p_cost === 0,
    JSON.stringify(rpcDe('taux_imposition_fixer')[0] && rpcDe('taux_imposition_fixer')[0].args));
att('AUCUNE cle de budget n est transmise',
    rpcDe('taux_imposition_fixer').length === 1
    && JSON.stringify(rpcDe('taux_imposition_fixer')[0].args).indexOf('republic_') < 0);
att('aucune ancienne primitive n est appelee', anciennesPrimitives().length === 0,
    JSON.stringify(anciennesPrimitives()));
att('le paiement arrete par le serveur est recopie', PAIEMENTS.length === 1
    && PAIEMENTS[0].pa === 8);
att('le succes est annonce', succes().length === 1);
att("le taux annonce est CELUI DU SERVEUR, pas celui du curseur",
    succes().length === 1 && succes()[0].message.indexOf('22') >= 0);
att("l'evenement public porte le taux du serveur",
    EVENTS.length === 1 && EVENTS[0].indexOf("local est fixé à 22%") >= 0, EVENTS.join(' | '));
att('la fenetre est fermee', MODAL_FERMEE === true);

print('');
print('2. LE TAUX ANNONCE EST TOUJOURS CELUI DU SERVEUR, MEME S IL DIFFERE DU CURSEUR');
neuf([{ ok: true, taux: 7, cle: 'republic_capitale', pa: 6 }], '31');
sync(validerImpotsLocauxReel(2, 0));
att('le curseur disait 31, le serveur a arrete 7',
    rpcDe('taux_imposition_fixer')[0].args.p_taux === 31
    && succes().length === 1 && succes()[0].message.indexOf('7') >= 0
    && succes()[0].message.indexOf('31') < 0,
    JSON.stringify(TOASTS));

print('');
print('3. SANS VERDICT, AUCUN TAUX N EST ANNONCE FIXE');
neuf(null);
sync(validerImpotsLocauxReel(2, 0));
att('verdict absent : aucun succes', succes().length === 0);
att("verdict absent : le refus est dit", TOASTS.length === 1 && TOASTS[0].ok === false);
att('verdict absent : aucun evenement public', EVENTS.length === 0);
att('verdict absent : aucun paiement recopie', PAIEMENTS.length === 0);
att('verdict absent : la fenetre reste ouverte', MODAL_FERMEE === false);

neuf('rejet');
sync(validerImpotsLocauxReel(2, 0));
att('transport rejete : aucun succes', succes().length === 0);
att('transport rejete : le refus est dit', TOASTS.length === 1 && TOASTS[0].ok === false);

neuf([]);
sync(validerImpotsLocauxReel(2, 0));
att('reponse vide : aucun succes', succes().length === 0);

print('');
print('4. CHAQUE REFUS PROPRE A CET ACTE EST NOMME');
var refus = [
  ['autorite_insuffisante', 'min_fin', 'Ministre des Finances'],
  ['maire_sans_ville', null, 'aucune ville'],
  ['budget_introuvable', null, "rien n'a été prélevé"],
  ['taux_hors_bornes', null, '0 et 40'],
  ['portee_inconnue', null, "n'existe pas"]
];
for (var i = 0; i < refus.length; i++) {
  neuf([{ ok: false, raison: refus[i][0], poste_requis: refus[i][1] }]);
  sync(validerImpotsLocauxReel(2, 0));
  att('refus « ' + refus[i][0] + " » : nomme au joueur, aucun succes",
      succes().length === 0 && TOASTS.length === 1
      && (TOASTS[0].titre + ' ' + TOASTS[0].message).indexOf(refus[i][2]) >= 0,
      JSON.stringify(TOASTS));
  att('refus « ' + refus[i][0] + ' » : aucun evenement public', EVENTS.length === 0);
}
neuf([{ ok: false, raison: 'autorite_insuffisante', poste_requis: 'maire' }]);
sync(validerImpotsLocauxReel(2, 0));
att("l'autorite manquante nomme le MAIRE quand c'est lui qui est requis",
    TOASTS.length === 1 && TOASTS[0].message.indexOf('Maire') >= 0, JSON.stringify(TOASTS));

print('');
print('5. UN MOTIF DE PAIEMENT EST DELEGUE AU NOMMEUR DEJA EN PLACE');
neuf([{ ok: false, raison: 'fonds_insuffisants' }]);
sync(validerImpotsLocauxReel(2, 0));
att('signalerRefusCout est appele', REFUS_COUT.length === 1
    && REFUS_COUT[0].raison === 'fonds_insuffisants');
att('et aucun succes n est annonce', succes().length === 0);
neuf([{ ok: false, raison: 'cout_non_atteste' }]);
sync(validerImpotsLocauxReel(2, 0));
att('un cout non atteste est delegue de meme', REFUS_COUT.length === 1);

print('');
print('6. TAUX NATIONAL : MEME PORTE, AUTRE PORTEE, AUCUN PAYS TRANSMIS');
neuf([{ ok: true, portee: 'national', taux: 12, cle: 'republic', pa: 8 }], '12', 'fiscal');
sync(validerImpotNational(2, 0));
att('la porte est appelee une fois', rpcDe('taux_imposition_fixer').length === 1);
att("avec la portee « national » et le nom de l'ordre en cours",
    rpcDe('taux_imposition_fixer')[0].args.p_portee === 'national'
    && rpcDe('taux_imposition_fixer')[0].args.p_fn === 'fiscal');
att('AUCUN pays n est transmis',
    JSON.stringify(rpcDe('taux_imposition_fixer')[0].args).indexOf('republic') < 0,
    JSON.stringify(rpcDe('taux_imposition_fixer')[0].args));
att('aucune ancienne primitive n est appelee', anciennesPrimitives().length === 0,
    JSON.stringify(anciennesPrimitives()));
att('le succes est annonce avec le taux du serveur',
    succes().length === 1 && succes()[0].message.indexOf('12') >= 0);
att('le Journal et l evenement public le disent',
    JOURNAL.length === 1 && JOURNAL[0].indexOf('12%') >= 0
    && EVENTS.length === 1 && EVENTS[0].indexOf('12%') >= 0,
    JSON.stringify([JOURNAL, EVENTS]));

neuf([{ ok: false, raison: 'autorite_insuffisante', poste_requis: 'min_fin' }], '12', 'fiscal');
sync(validerImpotNational(2, 0));
att('national refuse : aucun succes, aucun Journal, aucun evenement',
    succes().length === 0 && JOURNAL.length === 0 && EVENTS.length === 0);

print('');
print('7. LE DOUBLON MORT A DISPARU DU FICHIER');
att('ouvrirFixerImpotsLocaux n existe plus',
    src.indexOf('function ouvrirFixerImpotsLocaux(') < 0);
att('validerImpotsLocaux (sans Reel) n existe plus',
    src.indexOf('function validerImpotsLocaux(') < 0);
// Le nom subsiste dans le commentaire qui explique la suppression ; ce qui ne doit plus exister,
// c'est une AFFECTATION.
att('state.tauxImpositionLocal n est plus affecte nulle part',
    src.indexOf('state.tauxImpositionLocal =') < 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
