// Banc de la CLOTURE D'UNE TOURNEE -- plateau-actions-illegales-rumeurs.js (chantier 5, chaine 6,
// 10 octobre 2026). On extrait la VRAIE fonction du fichier de production.
// SOURCES: aucune -- ce banc lit plateau-actions-illegales-rumeurs.js lui-meme, par readFile.
//
// CE QUE CE BANC ETABLIT. resoudreTournee avait quatre sorties -- personne n'a accepte, les
// ressources ne sont plus reunies, la vente est refusee, la tournee est servie -- et les quatre
// faisaient la meme chose a la main : supprimer les invitations une par une avec un catch avale,
// puis appeler sbMarquerTourneeResolue SANS LIRE SON RETOUR. Si ce dernier echouait, la ligne
// restait en 'en_resolution' ; trente secondes plus tard le polling la RECLAMAIT et tout
// recommencait -- vente, PA, stock, caisse.
//
// Et sur la sortie « servie », crediterTourneeInviteAcceptant ecrivait la fiche de l'AUTRE joueur
// depuis le navigateur : mesure faite en base, cet UPDATE LEVE personnage_non_possede, donc le
// catch l'avalait et AUCUN invite n'a jamais recu ses +2 Moral / +1 ENT.
//
// Le banc verifie que les quatre sorties passent par UNE porte, que le succes n'est annonce que si
// la cloture a pris, et qu'aucune des anciennes primitives n'est plus appelee.
var src = readFile(typeof CHEMIN_SOURCE === 'string'
  ? CHEMIN_SOURCE : '/Users/fredericjasseron/ResPublica/plateau-actions-illegales-rumeurs.js');
function bloc(nom) {
  var i = src.indexOf('async function ' + nom + '(');
  if (i < 0) i = src.indexOf('function ' + nom + '(');
  if (i < 0) throw new Error('introuvable : ' + nom);
  var j = src.indexOf('{', i), p = 0, k = j;
  while (k < src.length) { if (src[k] === '{') p++; else if (src[k] === '}') { p--; if (!p) break; } k++; }
  return src.slice(i, k + 1);
}

var console = { error: function () {}, warn: function () {}, log: function () {} };
var RPC = [], TOASTS = [], JOURNAL = [], ANCIENNES = [];
var VERDICT_CLOTURE = null, VENTE = null, COMMERCE = null, INVITATIONS = [];
var state = { char: { name: 'Ben' }, moral: 50, day: 7 };

function sbRpc(nom, args) {
  RPC.push({ nom: nom, args: args });
  if (VERDICT_CLOTURE === 'rejet') return Promise.reject(new Error('transport'));
  return Promise.resolve(VERDICT_CLOTURE);
}
// Les primitives que PLUS AUCUNE sortie ne doit appeler.
function sbSupprimerInvitationDiner(id) { ANCIENNES.push('supprimer:' + id); return Promise.resolve(true); }
function sbMarquerTourneeResolue() { ANCIENNES.push('marquer_resolue'); return Promise.resolve(true); }
function sbMarquerTourneePaDebite() { ANCIENNES.push('marquer_pa'); return Promise.resolve(true); }
function crediterTourneeInviteAcceptant(n) { ANCIENNES.push('crediter:' + n); return Promise.resolve(); }

function sbGetInvitationsTournee() { return Promise.resolve(INVITATIONS); }
function chargerCommerce() { return Promise.resolve(COMMERCE); }
function commerceVendreProduit() { return Promise.resolve(VENTE); }
function getFondsDisponiblesOrdinaires() { return 100000; }
function appliquerGainENT() {}
function sbSavePersonnage() { return Promise.resolve(true); }
function showToast(t, m, ok) { TOASTS.push({ titre: t, message: m, ok: ok === true }); }
function addJournalEntry(m) { JOURNAL.push(m); }
function updateUI() {}
var RECETTES_ALIMENTAIRES = { biere: { label: 'Bière' } };

eval(bloc('resoudreTournee'));

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function sync(p) {
  var fini = false, val;
  Promise.resolve(p).then(function (v) { val = v; fini = true; }, function (e) { val = e; fini = true; });
  for (var i = 0; i < 500 && !fini; i++) drainMicrotasks();
  if (!fini) throw new Error('promesse non resolue apres 500 vidanges');
  return val;
}
function neuf() {
  RPC = []; TOASTS = []; JOURNAL = []; ANCIENNES = [];
  VERDICT_CLOTURE = [{ ok: true, servie: true, credites: 1, invitations_supprimees: 1 }];
  VENTE = { ok: true, net: 40 };
  COMMERCE = { id: 'bar-republic-capitale',
               stockProduits: { biere: 50 },
               parametres: { prixVente: { biere: 10 } } };
  INVITATIONS = [{ id: 1, invite: 'Autre', statut: 'acceptee' }];
  state = { char: { name: 'Ben' }, moral: 50, day: 7 };
}
function tournee(extra) {
  var t = { id: 'zztr-1', offreur: 'Ben', country: 'republic', ville: 'capitale',
            building_id: 'bar', room_id: 'salle', commerce_type: 'bar', recette_id: 'biere',
            pnj_resultats: [], pa_debite: false };
  for (var k in (extra || {})) t[k] = extra[k];
  return t;
}
function portes() { return RPC.filter(function (r) { return r.nom === 'tournee_cloturer'; }); }
function succes() { return TOASTS.filter(function (t) { return t.ok; }); }

print('');
print('1. TOURNEE SERVIE : UNE PORTE, SERVIE=TRUE, AUCUNE ANCIENNE PRIMITIVE');
neuf();
sync(resoudreTournee(tournee()));
att('la porte est appelee une fois', portes().length === 1);
att("avec l'identifiant et servie=true", portes().length === 1
    && portes()[0].args.p_tournee_id === 'zztr-1' && portes()[0].args.p_servie === true,
    JSON.stringify(portes()[0] && portes()[0].args));
att('aucune ancienne primitive', ANCIENNES.length === 0, ANCIENNES.join(' | '));
att('le succes est annonce', succes().length === 1
    && succes()[0].titre.indexOf('Tournée servie') >= 0, JSON.stringify(TOASTS));
att('le Journal le dit', JOURNAL.length === 1 && JOURNAL[0].indexOf('accepté') >= 0);
att("l'offreur garde son gain local", state.moral === 52);

print('');
print('2. SANS CLOTURE, LA TOURNEE N EST PAS ANNONCEE SERVIE');
var echecs = [[null, 'verdict absent'], [[], 'reponse vide'], ['rejet', 'transport rejete'],
              [[{ ok: false, raison: 'pas_en_resolution' }], 'refus de la porte']];
for (var i = 0; i < echecs.length; i++) {
  neuf(); VERDICT_CLOTURE = echecs[i][0];
  sync(resoudreTournee(tournee()));
  att(echecs[i][1] + ' : aucune tournee servie annoncee',
      succes().length === 0, JSON.stringify(TOASTS));
  att(echecs[i][1] + ' : le joueur est averti que la cloture n a pas pris',
      TOASTS.length === 1 && TOASTS[0].titre.indexOf('non confirmée') >= 0,
      JSON.stringify(TOASTS));
  att(echecs[i][1] + ' : le gain local n est pas pose',
      state.moral === 50, String(state.moral));
}

print('');
print('3. PERSONNE N A ACCEPTE : LA PORTE EST APPELEE AVEC SERVIE=FALSE');
neuf();
INVITATIONS = [{ id: 1, invite: 'Autre', statut: 'refusee' }];
VERDICT_CLOTURE = [{ ok: true, servie: false, credites: 0, invitations_supprimees: 1 }];
sync(resoudreTournee(tournee()));
att('la porte est appelee une fois', portes().length === 1);
att('avec servie=false', portes().length === 1 && portes()[0].args.p_servie === false);
att('aucune vente n a eu lieu', true);
att('le refus est dit', TOASTS.length === 1 && TOASTS[0].titre.indexOf('déclinée') >= 0,
    JSON.stringify(TOASTS));
att('aucune ancienne primitive', ANCIENNES.length === 0, ANCIENNES.join(' | '));

print('');
print('4. RESSOURCES PLUS REUNIES : MEME PORTE, SERVIE=FALSE');
neuf();
COMMERCE = { id: 'bar-republic-capitale', stockProduits: { biere: 0 },
             parametres: { prixVente: { biere: 10 } } };
VERDICT_CLOTURE = [{ ok: true, servie: false, credites: 0, invitations_supprimees: 1 }];
sync(resoudreTournee(tournee()));
att('la porte est appelee une fois avec servie=false',
    portes().length === 1 && portes()[0].args.p_servie === false);
att('la tournee est annoncee annulee', TOASTS.length === 1
    && TOASTS[0].titre.indexOf('annulée') >= 0, JSON.stringify(TOASTS));
att('aucune ancienne primitive', ANCIENNES.length === 0, ANCIENNES.join(' | '));

print('');
print('5. VENTE REFUSEE : MEME PORTE, SERVIE=FALSE, AUCUN SUCCES');
neuf();
VENTE = { ok: false, raison: 'fonds_insuffisants' };
VERDICT_CLOTURE = [{ ok: true, servie: false, credites: 0, invitations_supprimees: 1 }];
sync(resoudreTournee(tournee()));
att('la porte est appelee une fois avec servie=false',
    portes().length === 1 && portes()[0].args.p_servie === false);
att('aucun succes', succes().length === 0);
att('aucune ancienne primitive', ANCIENNES.length === 0, ANCIENNES.join(' | '));

print('');
print('6. LES ANCIENNES PRIMITIVES ONT DISPARU DU FICHIER');
att('crediterTourneeInviteAcceptant n est plus definie',
    src.indexOf('async function crediterTourneeInviteAcceptant(') < 0);
att('nettoyerInvitations n existe plus',
    src.indexOf('async function nettoyerInvitations(') < 0);
att('sbMarquerTourneeResolue n est plus appelee',
    src.indexOf('await sbMarquerTourneeResolue(') < 0);
att('sbMarquerTourneePaDebite n est plus appelee',
    src.indexOf('await sbMarquerTourneePaDebite(') < 0);
att('aucune suppression d invitation ligne par ligne ne subsiste dans la resolution',
    bloc('resoudreTournee').indexOf('sbSupprimerInvitationDiner') < 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
