// Banc du transport REST : on extrait les VRAIES fonctions de supabase.js et on leur donne un
// faux fetch. On ne teste pas une copie : on teste le texte qui part en production.
var src = readFile('/Users/fredericjasseron/ResPublica/supabase.js');
function bloc(nom) {
  var i = src.indexOf('async function ' + nom + '(');
  if (i < 0) i = src.indexOf('function ' + nom + '(');
  if (i < 0) throw new Error('introuvable : ' + nom);
  var j = src.indexOf('{', i), p = 0, k = j;
  while (k < src.length) { if (src[k]==='{') p++; else if (src[k]==='}') { p--; if (!p) break; } k++; }
  return src.slice(i, k + 1);
}
// JavaScriptCore n'a pas de `console` : on le pose, sinon le chemin d'erreur de
// sbTransportRest leve au lieu de rendre son enveloppe -- et le banc testerait le banc.
var console = { error: function () {}, warn: function () {}, log: function () {} };
var SUPABASE_URL = 'https://exemple.test';
function sbEnTetes() { return {}; }
var REPONSE = null, APPELS = [];
function fetch(url, init) {
  APPELS.push({ url: url, methode: (init && init.method) || 'GET' });
  if (REPONSE === 'rejet') return Promise.reject(new Error('Failed to fetch'));
  return Promise.resolve(REPONSE);
}
function rep(statut, corps) {
  return { ok: statut >= 200 && statut < 300, status: statut,
           json: function () { return Promise.resolve(corps); },
           text: function () { return Promise.resolve(typeof corps === 'string' ? corps : JSON.stringify(corps)); } };
}
eval(bloc('sbTransportRest')); eval(bloc('sbVerdictRest'));
eval(bloc('sbGetVerdict')); eval(bloc('sbRelancerSiReseau')); eval(bloc('sbGet')); eval(bloc('sbInsert')); eval(bloc('sbUpsert'));
eval(bloc('sbDelete'));

var ko = 0, attendus = 0;
function att(n, c) { attendus++; if (c) print('  ok  ' + n); else { print('  *** ' + n); ko++; } }

function sync(p) {  // le banc est synchrone : on vide explicitement la micro-file de JSC
  var fini = false, val;
  p.then(function (v) { val = v; fini = true; }, function (e) { val = e; fini = true; });
  for (var i = 0; i < 50 && !fini; i++) drainMicrotasks();
  if (!fini) throw new Error('promesse non resolue apres 50 vidanges');
  return val;
}

print('1. LES CINQ ETATS SONT NOMMES, ET DISTINCTS');
REPONSE = rep(200, [{ id: 'x' }]);
var e = sync(sbTransportRest('GET', 'ma_table', 'id=eq.x'));
att("2xx avec ligne -> etat ok", e.etat === 'ok');
att("les donnees sont la",       e.donnees && e.donnees.length === 1);

REPONSE = rep(200, []);
e = sync(sbTransportRest('GET', 'ma_table', 'id=eq.absent'));
att("2xx vide -> etat ok AUSSI (vide REEL)", e.etat === 'ok');
att("et les donnees sont un tableau vide",   Array.isArray(e.donnees) && e.donnees.length === 0);

REPONSE = rep(401, { code: '42501' });
e = sync(sbTransportRest('GET', 'ma_table', ''));
att("401 -> session_perdue", e.etat === 'session_perdue' && e.raison === 'session_perdue');
att("le code PostgREST est conserve", e.code === '42501');

REPONSE = rep(500, { code: 'XX000' });
e = sync(sbTransportRest('GET', 'ma_table', ''));
att("500 -> http / transport_indisponible", e.etat === 'http' && e.raison === 'transport_indisponible');
att("le statut HTTP est conserve", e.http === 500);

REPONSE = 'rejet';
e = sync(sbTransportRest('GET', 'ma_table', ''));
att("fetch rejete -> reseau / reseau_indisponible", e.etat === 'reseau' && e.raison === 'reseau_indisponible');
att("et envoyee reste vrai : on ne peut pas affirmer que rien n a eu lieu", e.envoyee === true);

print('');
print('2. LE DEFAUT HISTORIQUE : PANNE ET VIDE ETAIENT CONFONDUS');
REPONSE = rep(200, []);
var vide = sync(sbGetVerdict('t', ''));
REPONSE = rep(500, {});
var panne = sync(sbGetVerdict('t', ''));
att("le vide reel est un SUCCES",        vide.ok === true && vide.donnees.length === 0);
att("la panne est un ECHEC",             panne.ok === false);
att("et elle porte un motif lisible",    panne.raison === 'transport_indisponible');
att("les deux ne sont plus confondus",   vide.ok !== panne.ok);

print('');
print('3. LE CONTRAT HISTORIQUE DES QUATRE PRIMITIVES EST INTACT');
REPONSE = rep(200, [{ id: 'x' }]);
att("sbGet rend le corps en succes",  (sync(sbGet('t','')) || [])[0].id === 'x');
REPONSE = rep(200, []);
var r = sync(sbGet('t',''));
att("sbGet rend [] sur un vide reel", Array.isArray(r) && r.length === 0);
REPONSE = rep(500, {});
att("sbGet rend null sur echec HTTP", sync(sbGet('t','')) === null);
REPONSE = 'rejet';
att("sbGet LEVE toujours sur rejet reseau (comportement d avant preserve)",
    sync(sbGet('t','')) instanceof Error);
REPONSE = rep(201, [{ id: 'y' }]);
att("sbInsert rend le corps",         (sync(sbInsert('t', { id: 'y' })) || [])[0].id === 'y');
REPONSE = rep(403, {});
att("sbInsert rend null sur refus",   sync(sbInsert('t', { id: 'y' })) === null);
REPONSE = rep(204, null);
att("sbDelete rend true sur 204",     sync(sbDelete('t','id=eq.y')) === true);
REPONSE = rep(500, {});
att("sbDelete rend null sur echec",   sync(sbDelete('t','id=eq.y')) === null);

print('');
print('4. L UPSERT N A PLUS DE LECTURE DE CONTROLE A SE TROMPER');
APPELS = []; REPONSE = rep(201, [{ id: 'z' }]);
sync(sbUpsert('budgets_municipaux', { id: 'z', data: {} }));
att("un seul aller-retour, pas de lecture prealable", APPELS.length === 1);
att("et c est un POST",                               APPELS[0].methode === 'POST');

print('');
print(ko ? 'ECHEC : ' + ko + ' cas sur ' + attendus
         : 'BANC TRANSPORT REST VERT (' + attendus + ' cas)');
