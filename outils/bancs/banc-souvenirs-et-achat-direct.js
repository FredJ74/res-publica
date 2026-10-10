/* ===========================================================================
   BANC DES SOUVENIRS D'ACCUEIL ET DU RENDEZ-VOUS NOTARIAL MANQUÉ
   SOURCES: outils/bancs/decor-env-serveur.js api/_referentiels-generes.js api/cron-minuit.js
   Chantier 6 (dernier reliquat) + chantier 5 — 10 octobre 2026
   ===========================================================================

   CE QU'IL PROUVE, PREMIERE MOITIE. `traiterSouvenirsAccueil` tirait le hasard DANS CE
   NAVIGATEUR, puis marquait `revele` par un `sbUpdate('id=eq.X')` qui n'etait PAS un
   compare-and-swap, puis annoncait le scandale par une seconde requete. Son seul rempart contre un
   double tirage etait le registre `joursCron` -- une ligne unique, lue-fusionnee-reecrite sans
   atomicite, ecrite et relue dix-huit fois par nuit. Et chaque fuite insere un evenement global
   « SCANDALE » NOMINATIF et IRREVERSIBLE.

   CE QU'IL PROUVE, SECONDE MOITIE. `nettoyerAchatsDirectsManques` consignait le depot perdu avec
   un `Date.now()` dans l'identifiant -- deux passes la meme nuit ecrivaient DEUX lignes -- et ses
   deux ecritures etaient avalees : le depot pouvait etre consigne sans que le rendez-vous soit
   purge, donc reconsigne la nuit suivante.

   LA PREUVE QUI COMPTE EST L'ABSENCE D'ECRITURE DIRECTE ET L'ABSENCE DE TIRAGE. Ce fichier ne
   doit plus emettre aucune ecriture sur `souvenirs_accueil`, `evenements_globaux`,
   `compromis_historique` ni `terrains_etat` par ces deux chemins, et ne doit plus contenir aucun
   `Math.random` dans le premier.

   CONTRE-EPREUVE. Joue contre la version precedente de api/cron-minuit.js, il ECHOUE :
     git show HEAD:api/cron-minuit.js > /tmp/avant.js
     python3 outils/bancs/lancer-banc.py outils/bancs/banc-souvenirs-et-achat-direct.js \
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

var APPELS = [], VERDICTS = {}, HTTP_OK = true, SOUVENIRS = [], TERRAINS = [];

function estPorteSouvenir(a) { return a.url.indexOf('/rpc/souvenir_accueil_tirer') !== -1; }
function estPorteAchat(a) { return a.url.indexOf('/rpc/achat_direct_manque_resoudre') !== -1; }

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
  if (estPorteSouvenir(appel) || estPorteAchat(appel)) {
    if (!HTTP_OK) return reponse(false, { message: 'panne simulee' }, 500);
    var cle = appel.corps && (appel.corps.p_souvenir_id || appel.corps.p_terrain_id);
    return reponse(true, VERDICTS[cle] !== undefined ? VERDICTS[cle] : null);
  }
  if (appel.methode === 'GET' && appel.url.indexOf('souvenirs_accueil') !== -1) {
    return reponse(true, SOUVENIRS);
  }
  if (appel.methode === 'GET' && appel.url.indexOf('terrains_etat') !== -1) {
    return reponse(true, TERRAINS);
  }
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

function ecrituresDirectes() {
  return APPELS.filter(function (a) {
    return a.methode !== 'GET' && !estPorteSouvenir(a) && !estPorteAchat(a)
        && (a.url.indexOf('souvenirs_accueil') !== -1 || a.url.indexOf('evenements_globaux') !== -1
            || a.url.indexOf('compromis_historique') !== -1
            || a.url.indexOf('terrains_etat') !== -1);
  });
}
// LES COMMENTAIRES DE CE LOT NOMMENT LES DEFAUTS FERMES : les compter reviendrait a declarer un
// defaut present parce qu'on explique qu'il a disparu. On mesure donc le CODE seul.
function sansCommentaires(texte) {
  return texte.split('\n').filter(function (l) { return l.trim().indexOf('//') !== 0; }).join('\n');
}
function portesSouvenir() { return APPELS.filter(estPorteSouvenir); }
function portesAchat() { return APPELS.filter(estPorteAchat); }
// Un banc qui LEVE au lieu de rougir ne dit pas quelle epreuve est tombee : joue contre le code
// precedent, aucune porte n'est appelee, et un acces nu a [0].corps ferait exploser le banc.
function corpsPorte(liste, n) { var a = liste[n || 0]; return (a && a.corps) || {}; }

function souvenir(id, nom) {
  return { id: id, pj_nom: nom || 'Ben', objet_nom: 'Montre en or',
           jour_creation: 1, jour_expiration: 13, revele: false, jour_tirage: null };
}
function terrainEchu(id) {
  return { id: id, country: 'republic', building_id: id.replace('republic_', ''),
    data: JSON.stringify({ city: 'capitale', surface: 700,
      achatDirect: { demandeur: 'Ben', acompte: 1000, dateLimite: Date.now() - 1000 } }) };
}

function rejouerSouvenirs(verdicts, souvenirs, httpOk) {
  APPELS = []; VERDICTS = verdicts || {}; HTTP_OK = httpOk !== false;
  SOUVENIRS = souvenirs || [souvenir('zzs-1')];
  return sync(traiterSouvenirsAccueil());
}
function rejouerAchats(verdicts, terrains, httpOk) {
  APPELS = []; VERDICTS = verdicts || {}; HTTP_OK = httpOk !== false;
  TERRAINS = terrains || [terrainEchu('republic_zz-parcelle')];
  return sync(nettoyerAchatsDirectsManques());
}

print('');
print('BANC DES SOUVENIRS D ACCUEIL ET DU RENDEZ-VOUS MANQUÉ');
print('============================================================================');

print('1. SOUVENIRS : UNE PORTE PAR SOUVENIR, SA JOURNÉE, AUCUNE ÉCRITURE DIRECTE');
var r = rejouerSouvenirs({ 'zzs-1': [{ ok: true, action: 'fuite', pj: 'Ben' }] });
verifier('la porte est appelee une fois', portesSouvenir().length, 1);
vrai('avec l identifiant du souvenir', portesSouvenir().length === 1
     && corpsPorte(portesSouvenir()).p_souvenir_id === 'zzs-1');
vrai('et la journee au format YYYY-MM-DD', portesSouvenir().length === 1
     && /^\d{4}-\d{2}-\d{2}$/.test(String(corpsPorte(portesSouvenir()).p_jour)),
     String(corpsPorte(portesSouvenir()).p_jour));
verifier('aucune ecriture directe', ecrituresDirectes().length, 0);
verifier('la fuite est comptee', r.fuites, 1);
verifier('aucun refus', r.refus, 0);

print('');
print('2. SOUVENIRS : LE TIRAGE A QUITTÉ LE NAVIGATEUR');
var src = readFile(typeof CHEMIN_SOURCE === 'string'
  ? CHEMIN_SOURCE : '/Users/fredericjasseron/ResPublica/api/cron-minuit.js');
var i = src.indexOf('async function traiterSouvenirsAccueil(');
var j = src.indexOf('{', i), p = 0, k = j;
while (k < src.length) { if (src[k] === '{') p++; else if (src[k] === '}') { p--; if (!p) break; } k++; }
var bloc = sansCommentaires(src.slice(i, k + 1));
verifier('aucun Math.random dans la fonction', (bloc.match(/Math\.random/g) || []).length, 0);
vrai("aucune probabilite de fuite recalculee ici", bloc.indexOf('0.05') < 0, bloc.indexOf('0.05'));
vrai("aucun texte de scandale construit ici", bloc.indexOf('SCANDALE') < 0);
vrai("plus aucun marquage direct de revele", bloc.indexOf('revele: true') < 0);

print('');
print('3. SOUVENIRS : CHAQUE VERDICT EST COMPTÉ À SA PLACE');
r = rejouerSouvenirs({ 'zzs-1': [{ ok: true, action: 'pas_de_fuite' }] });
verifier('pas_de_fuite : aucune fuite comptee', r.fuites, 0);
verifier('pas_de_fuite : aucun refus', r.refus, 0);
r = rejouerSouvenirs({ 'zzs-1': [{ ok: true, action: 'deja_tire' }] });
verifier('deja_tire : compte comme deja traite', r.deja_tires, 1);
verifier('deja_tire : aucune fuite', r.fuites, 0);
r = rejouerSouvenirs({ 'zzs-1': [{ ok: true, action: 'deja_revele' }] });
verifier('deja_revele : compte comme deja traite', r.deja_tires, 1);

print('');
print('4. SOUVENIRS : AUCUN VERDICT N EST JAMAIS UNE FUITE');
var avant = ECHECS_PASSE.length;
r = rejouerSouvenirs({ 'zzs-1': null });
verifier('verdict absent : aucune fuite', r.fuites, 0);
vrai('verdict absent : signale', ECHECS_PASSE.length - avant === 1
     && String(ECHECS_PASSE[ECHECS_PASSE.length - 1].etape) === 'souvenir:zzs-1',
     JSON.stringify(ECHECS_PASSE.slice(avant)));
r = rejouerSouvenirs({ 'zzs-1': [] });
verifier('reponse vide : aucune fuite', r.fuites, 0);
r = rejouerSouvenirs({}, null, false);
verifier('panne HTTP : aucune fuite', r.fuites, 0);
verifier('panne HTTP : aucune ecriture directe', ecrituresDirectes().length, 0);
avant = ECHECS_PASSE.length;
r = rejouerSouvenirs({ 'zzs-1': [{ ok: false, raison: 'souvenir_introuvable' }] });
verifier('refus de la porte : aucune fuite', r.fuites, 0);
vrai('refus de la porte : nomme', ECHECS_PASSE.length - avant === 1
     && String(ECHECS_PASSE[ECHECS_PASSE.length - 1].erreur) === 'souvenir_introuvable',
     JSON.stringify(ECHECS_PASSE.slice(avant)));

print('');
print('5. SOUVENIRS : CHAQUE SOUVENIR A SON PROPRE APPEL ET SA PROPRE JOURNÉE');
r = rejouerSouvenirs({ 'zzs-1': [{ ok: true, action: 'fuite' }],
                       'zzs-2': [{ ok: true, action: 'pas_de_fuite' }],
                       'zzs-3': [{ ok: true, action: 'deja_tire' }] },
                     [souvenir('zzs-1'), souvenir('zzs-2', 'May'), souvenir('zzs-3', 'Arnie')]);
verifier('trois appels pour trois souvenirs', portesSouvenir().length, 3);
verifier('une seule fuite', r.fuites, 1);
verifier('un deja traite', r.deja_tires, 1);
vrai('la meme journee pour les trois',
     corpsPorte(portesSouvenir(), 0).p_jour === corpsPorte(portesSouvenir(), 2).p_jour);
verifier('aucune ecriture directe', ecrituresDirectes().length, 0);

print('');
print('6. RENDEZ-VOUS MANQUÉ : UNE PORTE PAR TERRAIN, AUCUNE ÉCRITURE DIRECTE');
r = rejouerAchats({ 'republic_zz-parcelle': [{ ok: true, consigne: true, jour: '2026-10-11' }] });
verifier('la porte est appelee une fois', portesAchat().length, 1);
vrai('avec l identifiant du terrain', portesAchat().length === 1
     && corpsPorte(portesAchat()).p_terrain_id === 'republic_zz-parcelle');
verifier('aucune ecriture directe', ecrituresDirectes().length, 0);
verifier('le manque est compte', r.manques, 1);

print('');
print('7. RENDEZ-VOUS MANQUÉ : PLUS AUCUN Date.now() DANS L IDENTIFIANT');
var i2 = src.indexOf('async function nettoyerAchatsDirectsManques(');
var j2 = src.indexOf('{', i2), p2 = 0, k2 = j2;
while (k2 < src.length) { if (src[k2] === '{') p2++; else if (src[k2] === '}') { p2--; if (!p2) break; } k2++; }
var bloc2 = sansCommentaires(src.slice(i2, k2 + 1));
vrai("plus aucun 'achatdirect-' construit ici", bloc2.indexOf("'achatdirect-") < 0);
vrai('plus aucune insertion de compromis_historique',
     bloc2.indexOf("sbInsert('compromis_historique'") < 0);
vrai("plus aucune ecriture de terrains_etat", bloc2.indexOf("sbUpdate('terrains_etat'") < 0);
vrai("le pre-filtre d echeance est conserve", bloc2.indexOf('etat.achatDirect.dateLimite') >= 0);

print('');
print('8. RENDEZ-VOUS MANQUÉ : LES DEUX REFUS DE LISTE PÉRIMÉE NE SONT PAS DES ÉCHECS');
avant = ECHECS_PASSE.length;
var perimes = ['aucun_achat_direct', 'pas_echu'];
for (var m = 0; m < perimes.length; m++) {
  r = rejouerAchats({ 'republic_zz-parcelle': [{ ok: false, raison: perimes[m] }] });
  verifier('refus « ' + perimes[m] + ' » : rien compte', r.manques, 0);
}
verifier('et aucun des deux n est signale', ECHECS_PASSE.length - avant, 0);
avant = ECHECS_PASSE.length;
r = rejouerAchats({ 'republic_zz-parcelle': [{ ok: false, raison: 'terrain_introuvable' }] });
vrai('un refus inconnu, lui, est signale', ECHECS_PASSE.length - avant === 1,
     JSON.stringify(ECHECS_PASSE.slice(avant)));

print('');
print('9. RENDEZ-VOUS MANQUÉ : AUCUN VERDICT N EST JAMAIS UN MANQUE');
avant = ECHECS_PASSE.length;
r = rejouerAchats({ 'republic_zz-parcelle': null });
verifier('verdict absent : rien compte', r.manques, 0);
vrai('verdict absent : signale', ECHECS_PASSE.length - avant === 1);
r = rejouerAchats({}, null, false);
verifier('panne HTTP : rien compte', r.manques, 0);
verifier('panne HTTP : aucune ecriture directe', ecrituresDirectes().length, 0);

print('');
print('============================================================================');
if (echecs === 0) print('LES ' + total + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + echecs + ' epreuve(s) sur ' + total);
