/* ===========================================================================
   BANC DE envoyerMailSysteme — api/cron-minuit.js
   SOURCES: outils/bancs/decor-env-serveur.js api/_referentiels-generes.js api/cron-minuit.js
   Chantier 5, 9 octobre 2026
   ===========================================================================

   CE QU'IL PROUVE — LES TROIS REGLES DE LA DOCTRINE DE NOTIFICATION :

     1. UNE NOTIFICATION N'EST PAS L'AUTORITE DE L'ACTE. La fonction NE LEVE JAMAIS : c'est
        par la qu'un mail qui ne part pas ne peut plus annuler une operation economique
        correctement acquise. Le banc l'eprouve en faisant echouer le transport de toutes les
        facons possibles -- HTTP non-2xx, rejet de fetch, exception synchrone de fetch.

     2. L'ECHEC N'EST JAMAIS AVALE. Chaque echec pousse une entree dans ECHECS_PASSE, donc
        remonte dans le journal durable du cron et dans le code HTTP de la passe. C'etait le
        defaut : seize des dix-huit appels portaient `.catch(() => {})`, aucun ne lisait le
        verdict, et sbInsert rendait null en silence -- un avis de saisie qui ne partait pas ne
        laissait aucune trace.

     3. LE VERDICT EST EXPLICITE : { ok: true, id } ou { ok: false, raison }.

   CONTRE-EPREUVE. Joue contre la version precedente de api/cron-minuit.js, ce banc ECHOUE :
     git show HEAD:api/cron-minuit.js > /tmp/avant.js
     python3 outils/bancs/lancer-banc.py outils/bancs/banc-mail-systeme.js \
             outils/bancs/decor-env-serveur.js api/_referentiels-generes.js /tmp/avant.js
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

var MODE = 'ok';          // ok | http500 | rejet | leve
var APPELS = [];

globalThis.fetch = function (url, options) {
  APPELS.push({ url: String(url), methode: (options || {}).method || 'GET' });
  if (MODE === 'leve')  { throw new Error('fetch casse de facon synchrone'); }
  if (MODE === 'rejet') { return Promise.reject(new Error('reseau coupe')); }
  if (MODE === 'http500') {
    return Promise.resolve({
      ok: false, status: 500,
      json: function () { return Promise.resolve({ message: 'boom' }); },
      text: function () { return Promise.resolve('boom'); }
    });
  }
  return Promise.resolve({
    ok: true, status: 201,
    json: function () { return Promise.resolve([{ id: 'mail-pose' }]); },
    text: function () { return Promise.resolve('[]'); }
  });
};

function sync(promesse) {
  var fini = false, valeur = null, erreur = null;
  try {
    promesse.then(function (v) { valeur = v; fini = true; },
                 function (e) { erreur = e; fini = true; });
  } catch (e) { return { leve: true, erreur: e }; }
  for (var i = 0; i < 20000 && !fini; i++) drainMicrotasks();
  if (!fini) throw new Error('le banc n a pas pu resoudre sa promesse');
  if (erreur) return { leve: true, erreur: erreur };
  return { leve: false, valeur: valeur };
}

function envoyer(mode, dest, exp) {
  MODE = mode; APPELS = [];
  var avant = ECHECS_PASSE.length;
  var r;
  try {
    r = sync(envoyerMailSysteme(dest === undefined ? 'Arnie' : dest,
                                exp === undefined ? 'Banque Helvetia' : exp,
                                'Avis de saisie', 'corps du courrier'));
  } catch (e) {
    r = { leve: true, erreur: e };     // une levee SYNCHRONE, que .catch ne rattrape pas
  }
  r.traces = ECHECS_PASSE.slice(avant);
  return r;
}

// DEUX TRACES POUR UN ECHEC HTTP, ET C'EST VOULU. sbInsert signale deja le transport
// (« sbInsert:mails »), ce qui dit QUE l'appel a echoue ; la brique ajoute « mail:<exp>-><dest> »,
// qui dit QUEL COURRIER a ete perdu. La seconde ne se deduit pas de la premiere -- une passe
// nocturne emet des dizaines d'ecritures -- et c'est precisement celle qui manquait. Le banc
// verifie donc la PRESENCE de la trace qui nomme le courrier, pas un compte.
function traceDuCourrier(traces) {
  for (var i = 0; i < traces.length; i++) {
    if (String(traces[i].etape).indexOf('mail:') === 0) return traces[i];
  }
  return null;
}

print('');
print('BANC DE envoyerMailSysteme — un courrier perdu ne casse rien, et ne se perd pas en silence');
print('============================================================================');

// 1. chemin nominal
var r = envoyer('ok');
verifier('succes : ne leve pas', r.leve, false);
verifier('succes : verdict ok', r.valeur && r.valeur.ok, true);
vrai('succes : l identifiant du courrier est rendu',
     r.valeur && typeof r.valeur.id === 'string' && r.valeur.id.indexOf('mail-cron-') === 0,
     r.valeur && r.valeur.id);
verifier('succes : aucune trace d echec', r.traces.length, 0);
verifier('succes : une seule requete emise', APPELS.length, 1);

// 2. HTTP non-2xx -- le cas que sbInsert rendait en null silencieux
r = envoyer('http500');
verifier('HTTP 500 : ne leve pas', r.leve, false);
verifier('HTTP 500 : verdict de refus', r.valeur && r.valeur.ok, false);
verifier('HTTP 500 : la raison est nommee', r.valeur && r.valeur.raison, 'ecriture_refusee');
vrai('HTTP 500 : une trace NOMME le courrier perdu',
     traceDuCourrier(r.traces) !== null
       && traceDuCourrier(r.traces).etape.indexOf('Banque Helvetia') !== -1
       && traceDuCourrier(r.traces).etape.indexOf('Arnie') !== -1,
     JSON.stringify(r.traces));

// 3. rejet de la promesse de fetch
r = envoyer('rejet');
verifier('reseau coupe : ne leve pas', r.leve, false);
verifier('reseau coupe : verdict de refus', r.valeur && r.valeur.ok, false);
verifier('reseau coupe : la raison est nommee', r.valeur && r.valeur.raison, 'reseau_indisponible');
vrai('reseau coupe : une trace NOMME le courrier perdu', traceDuCourrier(r.traces) !== null,
     JSON.stringify(r.traces));

// 4. levee SYNCHRONE de fetch -- celle qu'un .catch accole ne rattrape pas, et qui remontait
//    jusqu'au try/catch englobant de la passe
r = envoyer('leve');
verifier('fetch qui leve : la fonction ne propage pas', r.leve, false);
verifier('fetch qui leve : verdict de refus', r.valeur && r.valeur.ok, false);
vrai('fetch qui leve : une trace NOMME le courrier perdu', traceDuCourrier(r.traces) !== null,
     JSON.stringify(r.traces));

// 5. demande incomplete : aucune requete, mais une trace quand meme
r = envoyer('ok', null);
verifier('destinataire absent : verdict de refus', r.valeur && r.valeur.raison, 'parametres_invalides');
verifier('destinataire absent : aucune requete emise', APPELS.length, 0);
vrai('destinataire absent : tracee quand meme', traceDuCourrier(r.traces) !== null,
     JSON.stringify(r.traces));
r = envoyer('ok', 'Arnie', '');
verifier('expediteur absent : verdict de refus', r.valeur && r.valeur.raison, 'parametres_invalides');

print('');
print('============================================================================');
if (echecs === 0) print('LES ' + total + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + echecs + ' epreuve(s) sur ' + total);
