/* ===========================================================================
   BANC DE appliquerEffetsGreveGenerale — api/cron-minuit.js
   SOURCES: api/_referentiels-generes.js api/cron-minuit.js
   Chantier 6, 9 octobre 2026
   ===========================================================================

   CE QU'IL PROUVE. La greve generale ecrivait son marqueur de journee EN DERNIER, par un
   sbUpdate dont l'echec etait avale -- apres avoir debite la POP de tout un gouvernement,
   reduit le Social du pays, ecrit les coefficients economiques et retire -5 INF a chaque
   syndicat participant. Si cette derniere ecriture mordait, la nuit suivante recommencait
   tout. Son commentaire pretendait pourtant suivre « la meme doctrine que la greve
   ordinaire », devenue fausse depuis le correctif du 7 octobre.

   LA PREUVE QUI COMPTE N'EST PAS UN COMPTEUR, C'EST L'ORDRE ET L'ABSENCE DE REQUETE.
   Le banc enregistre CHAQUE appel reseau, dans l'ordre, et exige :
     . que la revendication soit la toute premiere ecriture, juste apres la lecture des greves ;
     . qu'elle porte la garde du jour dans son FILTRE, pas seulement dans son corps ;
     . que ZERO requete suive quand la revendication n'a pas abouti -- panne de transport comme
       journee deja prise.
   Un banc qui se contenterait de lire `resultats` passerait alors que les effets ont ete
   appliques quand meme.

   CONTRE-EPREUVE. Joue contre la version precedente de api/cron-minuit.js, ce banc ECHOUE :
     git show HEAD~1:api/cron-minuit.js > /tmp/avant.js
     python3 outils/bancs/lancer-banc.py outils/bancs/banc-greve-generale.js \
             api/_referentiels-generes.js /tmp/avant.js
   L'epreuve 3 y tombe -- la premiere ecriture n'est pas la revendication -- et l'epreuve 6
   aussi : les effets partent sans marqueur.
   =========================================================================== */

var echecs = 0, total = 0;

function verifier(libelle, obtenu, attendu) {
  total++;
  var o = JSON.stringify(obtenu), a = JSON.stringify(attendu);
  if (o !== a) {
    echecs++;
    print('  NON ' + libelle);
    print('        obtenu  : ' + o);
    print('        attendu : ' + a);
  } else {
    print('  OK  ' + libelle);
  }
}

function vrai(libelle, condition, detail) {
  total++;
  if (condition) print('  OK  ' + libelle);
  else { echecs++; print('  NON ' + libelle); if (detail !== undefined) print('        ' + detail); }
}

// --------------------------------------------------------------------- decor
// Une greve generale active, de niveau 1, en cours depuis trois jours, avec un syndicat
// participant accepte. Un seul personnage, ministre, pour que le debit de POP soit observable.
var GREVE = {
  id: 'gg-banc', country: 'republic', statut: 'active', puissance_niveau: 1,
  jours_actifs: 3, derniere_application_jour: null,
  participants: [{ orgaId: 'o1', statut: 'accepte' }]
};

var APPELS = [];
var REPONSE_REVENDICATION = { ok: true, corps: [{ id: 'gg-banc' }] };   // 1 ligne touchee

function estRevendication(url, methode) {
  return methode === 'PATCH' && url.indexOf('greves_generales') !== -1;
}

globalThis.fetch = function (url, options) {
  var o = options || {};
  var methode = o.method || 'GET';
  APPELS.push({ methode: methode, url: String(url), corps: o.body ? JSON.parse(o.body) : null });

  function reponse(ok, donnees, statut) {
    return Promise.resolve({
      ok: ok, status: statut || (ok ? 200 : 500),
      json: function () { return Promise.resolve(donnees); },
      text: function () { return Promise.resolve(JSON.stringify(donnees)); }
    });
  }

  if (estRevendication(url, methode)) {
    if (!REPONSE_REVENDICATION.ok) return reponse(false, { message: 'panne simulee' }, 500);
    return reponse(true, REPONSE_REVENDICATION.corps);
  }
  if (methode === 'GET' && String(url).indexOf('greves_generales') !== -1) {
    return reponse(true, [GREVE]);
  }
  if (methode === 'GET' && String(url).indexOf('personnages') !== -1) {
    return reponse(true, [{ name: 'Ministre', poste: { id: 'min_fin' } }]);
  }
  if (methode === 'GET') return reponse(true, []);
  return reponse(true, []);
};

function sync(promesse) {
  var fini = false, valeur = null, erreur = null;
  promesse.then(function (v) { valeur = v; fini = true; },
               function (e) { erreur = e; fini = true; });
  for (var i = 0; i < 20000 && !fini; i++) drainMicrotasks();
  if (!fini) throw new Error('le banc n a pas pu resoudre sa promesse');
  if (erreur) throw erreur;
  return valeur;
}

function rejouer(reponse) {
  APPELS = [];
  REPONSE_REVENDICATION = reponse;
  return sync(appliquerEffetsGreveGenerale());
}

function apresRevendication() {
  for (var i = 0; i < APPELS.length; i++) {
    if (estRevendication(APPELS[i].url, APPELS[i].methode)) return APPELS.slice(i + 1);
  }
  return null;   // aucune revendication emise
}

print('');
print('BANC DE appliquerEffetsGreveGenerale — le marqueur avant l\'effet, et conditionnel');
print('============================================================================');

var jour = jourParisISO();

// ------------------------------------------------- 1. la revendication est bien emise
var r = rejouer({ ok: true, corps: [{ id: 'gg-banc' }] });
var revend = null;
for (var i = 0; i < APPELS.length; i++) {
  if (estRevendication(APPELS[i].url, APPELS[i].methode)) { revend = APPELS[i]; break; }
}
vrai('une revendication PATCH sur greves_generales est emise', revend !== null);

// ------------------------------------------------- 2. la garde du jour est dans le FILTRE
vrai('le filtre cible la ligne par son id',
     revend !== null && revend.url.indexOf('id=eq.gg-banc') !== -1,
     revend && revend.url);
vrai('le filtre EXIGE que le jour ne soit pas deja pose (compare-and-swap)',
     revend !== null && revend.url.indexOf('derniere_application_jour.neq.' + jour) !== -1,
     revend && revend.url);
vrai('le filtre accepte aussi la greve jamais traitee (is.null -- neq exclut les NULL)',
     revend !== null && revend.url.indexOf('derniere_application_jour.is.null') !== -1,
     revend && revend.url);
verifier('le corps pose le jour courant',
         revend && revend.corps && revend.corps.derniere_application_jour, jour);
verifier('le corps incremente le compteur de jours',
         revend && revend.corps && revend.corps.jours_actifs, 4);

// ------------------------------------------------- 3. elle est la PREMIERE ecriture
var premiereEcriture = null;
for (var j = 0; j < APPELS.length; j++) {
  if (APPELS[j].methode !== 'GET') { premiereEcriture = APPELS[j]; break; }
}
vrai('la revendication est la PREMIERE ecriture de la passe',
     premiereEcriture !== null && estRevendication(premiereEcriture.url, premiereEcriture.methode),
     premiereEcriture && (premiereEcriture.methode + ' ' + premiereEcriture.url));
vrai('elle suit immediatement la lecture des greves actives',
     APPELS.length > 1 && APPELS[0].methode === 'GET'
       && APPELS[0].url.indexOf('greves_generales') !== -1
       && estRevendication(APPELS[1].url, APPELS[1].methode),
     APPELS.length > 1 ? (APPELS[1].methode + ' ' + APPELS[1].url) : '(une seule requete)');

// ------------------------------------------------- 4. revendication acquise : les effets partent
verifier('la greve est comptee traitee', r.traitees, 1);
vrai('des requetes suivent la revendication', (apresRevendication() || []).length > 0);
vrai('le gouvernement est relu pour etre debite',
     (apresRevendication() || []).some(function (a) { return a.url.indexOf('personnages') !== -1; }));

// ------------------------------------------------- 5. journee DEJA prise : zero effet
r = rejouer({ ok: true, corps: [] });            // 0 ligne touchee
verifier('journee deja prise : aucune greve traitee', r.traitees, 0);
verifier('journee deja prise : elle est comptee comme deja revendiquee', r.deja_revendiquees, 1);
verifier('journee deja prise : AUCUNE requete apres la revendication',
         (apresRevendication() || ['(aucune revendication)']).length, 0);

// ------------------------------------------------- 6. panne de transport : zero effet
r = rejouer({ ok: false });                      // HTTP 500 -> sbUpdate rend null
verifier('panne de transport : aucune greve traitee', r.traitees, 0);
verifier('panne de transport : le marqueur est declare non pose', r.marqueurs_non_poses, 1);
verifier('panne de transport : AUCUNE requete apres la revendication',
         (apresRevendication() || ['(aucune revendication)']).length, 0);
vrai('panne de transport : aucun debit de POP n a ete tente',
     !APPELS.some(function (a) { return a.methode === 'PATCH' && a.url.indexOf('personnages') !== -1; }));

// ------------------------------------------------- 7. la garde amont n'a pas disparu
GREVE.derniere_application_jour = jour;
r = rejouer({ ok: true, corps: [{ id: 'gg-banc' }] });
verifier('deja applique aujourd hui : rien n est traite', r.traitees, 0);
vrai('deja applique aujourd hui : aucune revendication n est meme tentee',
     apresRevendication() === null);
GREVE.derniere_application_jour = null;

print('');
print('============================================================================');
if (echecs === 0) print('LES ' + total + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + echecs + ' epreuve(s) sur ' + total);
