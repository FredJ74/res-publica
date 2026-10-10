/* ===========================================================================
   BANC DE preleverTaxeFonciere — api/cron-minuit.js
   SOURCES: outils/bancs/decor-env-serveur.js api/_referentiels-generes.js api/cron-minuit.js
   Chantier 6, famille A — 10 octobre 2026
   ===========================================================================

   CE QU'IL PROUVE. Cette passe debitait le proprietaire PUIS ecrivait le blob du terrain -- deux
   requetes HTTP -- et creditait les mairies APRES la boucle, par commune. Elle n'avait AUCUN
   marqueur par terrain : une seconde execution le meme jour redebitait la taxe et faisait avancer
   de DEUX crans la progression avertissement -> penalite de 10 % -> SAISIE MUNICIPALE.

   LA PREUVE QUI COMPTE EST L'ABSENCE D'ECRITURE DIRECTE. Tout est descendu dans
   taxe_fonciere_prelever : ce fichier ne doit plus emettre aucune ecriture sur terrains_etat,
   personnages, budgets_municipaux, caisses_batiments ni evenements_globaux, et ne doit plus lire
   ni le budget municipal ni la fiche du proprietaire. Les compteurs rendus sont les memes.

   IL PROUVE AUSSI que chaque verdict est compte a sa place, que les cinq refus « rien a faire »
   ne sont PAS signales comme des echecs, et qu'un verdict absent n'est jamais une collecte.

   CONTRE-EPREUVE. Joue contre la version precedente de api/cron-minuit.js, il ECHOUE :
     git show HEAD:api/cron-minuit.js > /tmp/avant.js
     python3 outils/bancs/lancer-banc.py outils/bancs/banc-taxe-fonciere.js \
             outils/bancs/decor-env-serveur.js api/_referentiels-generes.js /tmp/avant.js
   =========================================================================== */

var echecs = 0, total = 0;

function verifier(libelle, obtenu, attendu) {
  total++;
  var o = JSON.stringify(obtenu), a = JSON.stringify(attendu);
  if (o !== a) {
    echecs++; print('  NON ' + libelle);
    print('        obtenu  : ' + o); print('        attendu : ' + a);
  } else print('  OK  ' + libelle);
}
function vrai(libelle, condition, detail) {
  total++;
  if (condition) print('  OK  ' + libelle);
  else { echecs++; print('  NON ' + libelle); if (detail !== undefined) print('        ' + detail); }
}

var APPELS = [], VERDICTS = {}, HTTP_OK = true, TERRAINS = [];

function estRpcPorte(a) { return a.url.indexOf('/rpc/taxe_fonciere_prelever') !== -1; }
function estRpcRecette(a) { return a.url.indexOf('/rpc/recette_municipale') !== -1; }

globalThis.fetch = function (url, options) {
  var o = options || {};
  var appel = { methode: o.method || 'GET', url: String(url),
                corps: o.body ? JSON.parse(o.body) : null };
  APPELS.push(appel);
  function reponse(ok, donnees, statut) {
    return Promise.resolve({ ok: ok, status: statut || (ok ? 200 : 500),
      json: function () { return Promise.resolve(donnees); },
      text: function () { return Promise.resolve(JSON.stringify(donnees)); } });
  }
  if (estRpcPorte(appel)) {
    if (!HTTP_OK) return reponse(false, { message: 'panne simulee' }, 500);
    var id = appel.corps && appel.corps.p_terrain_id;
    return reponse(true, VERDICTS[id] !== undefined ? VERDICTS[id] : null);
  }
  if (appel.methode === 'GET' && appel.url.indexOf('terrains_etat') !== -1) {
    return reponse(true, TERRAINS);
  }
  // LE DECOR REPOND AUSSI A L'ANCIEN CHEMIN : sans budget municipal ni proprietaire credibles,
  // la version precedente sortirait par `continue` avant d'ecrire, et l'epreuve « aucune ecriture
  // directe » passerait aussi sur le code fautif -- donc ne prouverait rien.
  if (appel.methode === 'GET' && appel.url.indexOf('budgets_municipaux') !== -1) {
    return reponse(true, [{ id: 'republic_capitale', data: { tauxFoncier: 0.05 } }]);
  }
  if (appel.methode === 'GET' && appel.url.indexOf('personnages') !== -1) {
    return reponse(true, [{ name: 'Ben', country: 'republic', arg: 5000 }]);
  }
  if (estRpcRecette(appel)) return reponse(true, { ok: true });
  return reponse(true, []);
};

function sync(promesse) {
  var fini = false, valeur = null, erreur = null;
  promesse.then(function (v) { valeur = v; fini = true; }, function (e) { erreur = e; fini = true; });
  for (var i = 0; i < 20000 && !fini; i++) drainMicrotasks();
  if (!fini) throw new Error('le banc n a pas pu resoudre sa promesse');
  if (erreur) throw erreur;
  return valeur;
}

function terrainImposable(id) {
  return { id: id || 'zzt-1', country: 'republic', building_id: 'zzt-b',
    data: JSON.stringify({ city: 'capitale', proprietaire: 'Ben', surface: 1000,
                           valeur_totale: 12000 }) };
}
function ecrituresDirectes() {
  return APPELS.filter(function (a) {
    return a.methode !== 'GET' && !estRpcPorte(a)
        && (a.url.indexOf('terrains_etat') !== -1 || a.url.indexOf('personnages') !== -1
            || a.url.indexOf('caisses_batiments') !== -1 || a.url.indexOf('budgets_municipaux') !== -1
            || a.url.indexOf('evenements_globaux') !== -1 || estRpcRecette(a));
  });
}
function lecturesInutiles() {
  return APPELS.filter(function (a) {
    return a.methode === 'GET' && (a.url.indexOf('budgets_municipaux') !== -1
                                   || a.url.indexOf('personnages') !== -1);
  });
}
function appelsPorte() { return APPELS.filter(estRpcPorte); }

function rejouer(verdicts, httpOk, terrains) {
  APPELS = []; VERDICTS = verdicts || {}; HTTP_OK = httpOk !== false;
  TERRAINS = terrains || [terrainImposable()];
  return sync(preleverTaxeFonciere());
}

print('');
print('BANC DE LA TAXE FONCIERE');
print('============================================================================');

print('1. UNE PORTE PAR TERRAIN, AUCUNE ECRITURE DIRECTE, AUCUNE LECTURE INUTILE');
var r = rejouer({ 'zzt-1': [{ ok: true, action: 'collectee', montant: 50, ville: 'capitale' }] });
verifier('la porte est appelee une fois', appelsPorte().length, 1);
vrai('avec l identifiant du terrain', appelsPorte().length === 1
     && appelsPorte()[0].corps.p_terrain_id === 'zzt-1');
verifier('aucune ecriture directe', ecrituresDirectes().length, 0);
verifier('ni le budget municipal ni la fiche ne sont relus ici', lecturesInutiles().length, 0);
verifier('la collecte est comptee au montant rendu', r.collecte, 50);
verifier('aucun avertissement', r.avertissements, 0);
verifier('aucune saisie', r.saisies, 0);

print('');
print('2. CHAQUE VERDICT EST COMPTE A SA PLACE');
r = rejouer({ 'zzt-1': [{ ok: true, action: 'avertissement', montant: 50 }] });
verifier('avertissement compte', r.avertissements, 1);
verifier('et rien collecte', r.collecte, 0);
r = rejouer({ 'zzt-1': [{ ok: true, action: 'saisie', montant: 50 }] });
verifier('saisie comptee', r.saisies, 1);
verifier('et rien collecte', r.collecte, 0);
verifier('aucune ecriture directe', ecrituresDirectes().length, 0);

print('');
print('3. LES CINQ REFUS « RIEN A FAIRE » NE SONT PAS DES ECHECS');
var avant = ECHECS_PASSE.length;
var refus = ['hors_assiette', 'terrain_introuvable', 'budget_municipal_absent',
             'proprietaire_introuvable', 'deja_prelevee_aujourdhui'];
for (var i = 0; i < refus.length; i++) {
  r = rejouer({ 'zzt-1': [{ ok: false, action: refus[i] }] });
  verifier('refus « ' + refus[i] + ' » : rien compte', r.collecte + r.avertissements + r.saisies, 0);
}
verifier('et AUCUN de ces cinq refus n est signale comme un echec', ECHECS_PASSE.length - avant, 0);

print('');
print('4. UN REFUS INCONNU, LUI, EST SIGNALE');
avant = ECHECS_PASSE.length;
r = rejouer({ 'zzt-1': [{ ok: false, action: 'caisse_mairie_introuvable' }] });
verifier('rien compte', r.collecte + r.avertissements + r.saisies, 0);
vrai('et l echec est nomme', ECHECS_PASSE.length - avant === 1
     && String(ECHECS_PASSE[ECHECS_PASSE.length - 1].etape).indexOf('taxe_fonciere:zzt-1') === 0,
     JSON.stringify(ECHECS_PASSE.slice(avant)));

print('');
print('5. AUCUN VERDICT N EST JAMAIS UNE COLLECTE');
avant = ECHECS_PASSE.length;
r = rejouer({ 'zzt-1': null });
verifier('verdict absent : rien compte', r.collecte + r.avertissements + r.saisies, 0);
vrai('verdict absent : signale', ECHECS_PASSE.length - avant === 1);
r = rejouer({ 'zzt-1': [] });
verifier('reponse vide : rien compte', r.collecte + r.avertissements + r.saisies, 0);
r = rejouer({}, false);
verifier('panne HTTP : rien compte', r.collecte + r.avertissements + r.saisies, 0);
verifier('panne HTTP : aucune ecriture directe', ecrituresDirectes().length, 0);
r = rejouer({ 'zzt-1': [{ ok: true }] });
verifier('verdict ok sans action : rien compte', r.collecte + r.avertissements + r.saisies, 0);

print('');
print('6. CHAQUE TERRAIN A SON PROPRE APPEL');
r = rejouer({ 'zzt-1': [{ ok: true, action: 'collectee', montant: 50 }],
              'zzt-2': [{ ok: true, action: 'collectee', montant: 30 }],
              'zzt-3': [{ ok: false, action: 'hors_assiette' }] },
            true, [terrainImposable('zzt-1'), terrainImposable('zzt-2'), terrainImposable('zzt-3')]);
verifier('trois appels pour trois terrains', appelsPorte().length, 3);
verifier('la collecte est la somme des montants rendus', r.collecte, 80);
verifier('aucune ecriture directe', ecrituresDirectes().length, 0);

print('');
print('============================================================================');
if (echecs === 0) print('LES ' + total + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + echecs + ' epreuve(s) sur ' + total);
