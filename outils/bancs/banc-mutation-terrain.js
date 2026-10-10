// Banc de la MUTATION DE PROPRIETE D'UN TERRAIN -- plateau-pnj.js (chantier 5, 10 octobre 2026).
// On extrait la VRAIE fonction du fichier de production.
// SOURCES: aucune -- ce banc lit plateau-pnj.js lui-meme, par readFile.
//
// CE QUE CE BANC ETABLIT. finaliserAchatTerrain est la mutation de propriete la plus centrale du
// jeu : les deux branches d'achat (compromis et achat direct) y aboutissent. Le solde du prix est
// deja parti cote serveur (deduireCoutOrdre -> payer_ordre) quand elle s'execute, et son ecriture
// etait AVALEE : l'acheteur pouvait payer et ne rien recevoir. L'historique public de la vente,
// ecrit juste apres et avale lui aussi, pouvait acter une vente qui n'existe pas -- avec un
// identifiant portant Date.now(), donc jamais dedoublonnable. Et la purge de la reservation
// consommee etait une TROISIEME ecriture, elle aussi avalee : si elle se perdait,
// doActeVenteTerrain reproposait l'acte et le joueur repayait le solde.
//
// Le banc verifie les deux moities : un seul appel a terrain_proprietaire_muter, portant le TITRE
// et un PATCH (jamais un blob entier relu dans le cache), la purge de la reservation DANS LE MEME
// patch, et aucune annonce d'achat si le verdict n'est pas venu.
var src = readFile(typeof CHEMIN_SOURCE === 'string'
  ? CHEMIN_SOURCE : '/Users/fredericjasseron/ResPublica/plateau-pnj.js');
function bloc(nom) {
  var i = src.indexOf('async function ' + nom + '(');
  if (i < 0) i = src.indexOf('function ' + nom + '(');
  if (i < 0) throw new Error('introuvable : ' + nom);
  var j = src.indexOf('{', i), p = 0, k = j;
  while (k < src.length) { if (src[k] === '{') p++; else if (src[k] === '}') { p--; if (!p) break; } k++; }
  return src.slice(i, k + 1);
}

var console = { error: function () {}, warn: function () {}, log: function () {} };
var RPC = [], ANCIENNES = [], TOASTS = [], JOURNAL = [], CACHE = [];
var VERDICT = null, GELE = false;
var state = { char: { name: 'Ben' }, country: 'republic', currentCity: 'capitale', arg: 5000 };

function sbRpc(nom, args) {
  RPC.push({ nom: nom, args: args });
  if (VERDICT === 'rejet') return Promise.reject(new Error('transport'));
  return Promise.resolve(VERDICT);
}
// Les deux primitives que cette fonction ne doit plus appeler.
function sbSetTerrainState(p, id, etat) { ANCIENNES.push({ quoi: 'sbSetTerrainState', etat: etat }); return Promise.resolve(true); }
function sbEnregistrerVenteTerrain() { ANCIENNES.push({ quoi: 'sbEnregistrerVenteTerrain' }); return Promise.resolve(true); }

function setTerrainState(id, patch) { CACHE.push(patch); return { _fusionne: true, id: id }; }
function refuserSiGele() { return Promise.resolve(GELE); }
function sbGetMariageActif() { return Promise.resolve(null); }
function getVilleTerrain(id) { return 'ville_a'; }
function showToast(t, m, ok) { TOASTS.push({ titre: t, message: m, ok: ok === true }); }
function addJournalEntry(m, c) { JOURNAL.push({ texte: m, classe: c }); }
function updateUI() {}
var COUNTRIES = { republic: { cur: 'FR' } };
var BUILDINGS = { 'zz-parcelle': { shortName: 'Parcelle du banc' } };

eval(bloc('finaliserAchatTerrain'));

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function sync(p) {
  var fini = false, val;
  Promise.resolve(p).then(function (v) { val = v; fini = true; }, function (e) { val = e; fini = true; });
  for (var i = 0; i < 300 && !fini; i++) drainMicrotasks();
  if (!fini) throw new Error('promesse non resolue apres 300 vidanges');
  return val;
}
function neuf(verdict, gele) {
  RPC = []; ANCIENNES = []; TOASTS = []; JOURNAL = []; CACHE = [];
  VERDICT = verdict === undefined
    ? [{ ok: true, titre: 'compromis', cle: 'republic_zz-parcelle', proprietaire: 'Ben',
         vente_consignee: true,
         // UN TEMOIN QUE SEUL LE SERVEUR CONNAIT : le patch ne le porte pas. Sans lui, un cache
         // qui recopierait le patch au lieu de l'etat rendu passerait l'epreuve sans rien prouver.
         etat: { proprietaire: 'Ben', surface: 800, valeur_totale: 9000,
                 permis: { statut: 'valide' }, zzTemoinServeur: 4242 } }]
    : verdict;
  GELE = !!gele;
  state = { char: { name: 'Ben' }, country: 'republic', currentCity: 'capitale', arg: 5000 };
}
function portes() { return RPC.filter(function (r) { return r.nom === 'terrain_proprietaire_muter'; }); }
function succes() { return TOASTS.filter(function (t) { return t.ok; }); }

print('');
print('1. UNE PORTE, UN TITRE, UN PATCH -- JAMAIS UN BLOB DE CACHE');
neuf();
var rendu = sync(finaliserAchatTerrain('zz-parcelle', 9000, 800, true, 'compromis',
                                       { compromis: null, compromisPar: null }));
att('la porte est appelee une fois', portes().length === 1);
att('le titre invoque est transmis', portes().length === 1
    && portes()[0].args.p_titre === 'compromis');
att("l'identifiant du terrain est transmis", portes().length === 1
    && portes()[0].args.p_terrain_id === 'zz-parcelle');
att('aucune ancienne primitive', ANCIENNES.length === 0, JSON.stringify(ANCIENNES));
att('la fonction rend true', rendu === true, String(rendu));

var patch = portes()[0].args.p_patch;
att('le patch porte la mutation de propriete', patch.proprietaire === 'Ben');
att('le patch porte le prix et la surface',
    patch.valeur_totale === 9000 && patch.surface === 800);
att("la ville vient de getVilleTerrain, jamais de currentCity", patch.city === 'ville_a',
    String(patch.city));
att('LA PURGE DE LA RESERVATION EST DANS LE MEME PATCH',
    'compromis' in patch && patch.compromis === null && patch.compromisPar === null,
    JSON.stringify(patch));
att("le patch ne contient pas un blob entier de cache (pas de cle _fusionne)",
    !('_fusionne' in patch));
att("le cache local recopie l'etat RENDU PAR LE SERVEUR",
    CACHE.length === 1 && CACHE[0].zzTemoinServeur === 4242
    && CACHE[0].permis && CACHE[0].permis.statut === 'valide',
    JSON.stringify(CACHE));
att("l'achat est annonce", succes().length >= 1
    && succes().some(function (t) { return t.titre.indexOf('Terrain acheté') >= 0; }),
    JSON.stringify(TOASTS));

print('');
print('2. ACHAT DIRECT : MEME PORTE, AUTRE TITRE, AUTRE PURGE');
neuf([{ ok: true, titre: 'achat_direct', proprietaire: 'Ben', vente_consignee: true,
        etat: { proprietaire: 'Ben' } }]);
sync(finaliserAchatTerrain('zz-parcelle', 7000, 600, false, 'achat_direct',
                           { achatDirect: null }));
att('le titre est « achat_direct »', portes().length === 1
    && portes()[0].args.p_titre === 'achat_direct');
att('la purge de la reservation est dans le patch',
    'achatDirect' in portes()[0].args.p_patch
    && portes()[0].args.p_patch.achatDirect === null);
att('sans permis, la construction n est PAS autorisee',
    portes()[0].args.p_patch.constructionAutorisee === false);
att('aucune ancienne primitive', ANCIENNES.length === 0, JSON.stringify(ANCIENNES));

print('');
print('3. SANS VERDICT, L ACHETEUR N EST PAS ANNONCE PROPRIETAIRE');
var echecs = [[null, 'verdict absent'], [[], 'reponse vide'], ['rejet', 'transport rejete'],
              [[{ ok: false, raison: 'pas_mon_compromis' }], 'titre refuse'],
              [[{ ok: false, raison: 'terrain_gele' }], 'terrain gele au serveur']];
for (var i = 0; i < echecs.length; i++) {
  neuf(echecs[i][0]);
  var r = sync(finaliserAchatTerrain('zz-parcelle', 9000, 800, true, 'compromis',
                                     { compromis: null }));
  att(echecs[i][1] + ' : la fonction rend false', r === false, String(r));
  att(echecs[i][1] + ' : aucun achat annonce',
      !succes().some(function (t) { return t.titre.indexOf('Terrain acheté') >= 0; }),
      JSON.stringify(TOASTS));
  att(echecs[i][1] + ' : le joueur est averti que rien n a ete enregistre',
      TOASTS.length === 1 && TOASTS[0].titre.indexOf('non enregistré') >= 0,
      JSON.stringify(TOASTS));
  att(echecs[i][1] + ' : le cache local n est PAS modifie', CACHE.length === 0,
      JSON.stringify(CACHE));
  att(echecs[i][1] + " : le motif est nomme au Journal",
      JOURNAL.length === 1 && JOURNAL[0].classe === 'event-bad', JSON.stringify(JOURNAL));
}

print('');
print('4. UN TERRAIN GELE PAR UNE SUCCESSION N ATTEINT MEME PAS LA PORTE');
neuf(undefined, true);
var rg = sync(finaliserAchatTerrain('zz-parcelle', 9000, 800, true, 'compromis', {}));
att('la porte n est pas appelee', portes().length === 0);
att('la fonction rend false', rg === false, String(rg));

print('');
print('5. LES TROIS PORTES D ENTREE D HIER ONT DISPARU');
att('finaliserAchatTerrain ne fait plus aucune ecriture directe de terrain',
    bloc('finaliserAchatTerrain').indexOf('sbSetTerrainState') < 0);
att('elle n enregistre plus la vente a part',
    bloc('finaliserAchatTerrain').indexOf('sbEnregistrerVenteTerrain') < 0);
att('elle recoit bien un titre et une purge',
    src.indexOf('async function finaliserAchatTerrain(id, prix, surface, aPermis, titre, purge)') >= 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
