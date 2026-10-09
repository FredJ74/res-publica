/* ===========================================================================
   BANC DE preleverPreemptionsServeur — api/cron-minuit.js
   SOURCES: outils/bancs/decor-env-serveur.js api/_referentiels-generes.js api/cron-minuit.js
   Chantier 6, 9 octobre 2026
   ===========================================================================

   CE QU'IL PROUVE. Cette passe faisait QUATRE allers-retours par pays : lire le budget, lire
   la caisse, ecrire la caisse, ecrire le budget. Les deux ecritures etaient deux transactions
   distinctes : une interruption entre elles debitait la caisse du Ministere des Finances SANS
   reduire la dette de la preemption, et le marqueur de tacheQuotidienne, deja pose, interdisait
   la reprise. L'argent disparaissait en silence.

   LA PREUVE QUI COMPTE EST L'ABSENCE D'ECRITURE DIRECTE. Tout le traitement est descendu dans
   preemption_mensualite_prelever ; ce fichier ne doit plus emettre AUCUN PATCH sur
   caisses_batiments ni sur budgets_nationaux. Un banc qui se contenterait de lire `resultats`
   ne verrait pas la difference -- les compteurs sont les memes.

   IL PROUVE AUSSI que l'identite serveur est exigee (la RPC n'est executable que par
   service_role), que chaque verdict est consomme, et qu'un echec de transport n'est jamais
   compte comme un prelevement.

   DEUX MODES, ET LE SECOND EST LE CHEMIN FAIL-CLOSED :
     python3 outils/bancs/lancer-banc.py outils/bancs/banc-preemptions.js
         -> mode nominal, avec identite serveur (le decor la pose).
     python3 outils/bancs/lancer-banc.py outils/bancs/banc-preemptions.js \
             api/_referentiels-generes.js api/cron-minuit.js
         -> SANS le decor : la cle de service est absente, et le banc exige alors ZERO requete.
   Le banc detecte lui-meme dans quel mode il tourne.

   CONTRE-EPREUVE. Joue contre la version precedente de api/cron-minuit.js, il ECHOUE :
     git show HEAD:api/cron-minuit.js > /tmp/avant.js
     python3 outils/bancs/lancer-banc.py outils/bancs/banc-preemptions.js \
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

var APPELS = [];
var REPONSES = {};          // pays -> { ok:bool, corps:any }

function estRpcPreemption(a) {
  return a.url.indexOf('/rpc/preemption_mensualite_prelever') !== -1;
}

globalThis.fetch = function (url, options) {
  var o = options || {};
  var appel = {
    methode: o.method || 'GET',
    url: String(url),
    corps: o.body ? JSON.parse(o.body) : null,
    entetes: o.headers || {}
  };
  APPELS.push(appel);

  function reponse(ok, donnees, statut) {
    return Promise.resolve({
      ok: ok, status: statut || (ok ? 200 : 500),
      json: function () { return Promise.resolve(donnees); },
      text: function () { return Promise.resolve(JSON.stringify(donnees)); }
    });
  }

  if (estRpcPreemption(appel)) {
    var pays = appel.corps && appel.corps.p_pays;
    var r = REPONSES[pays] || { ok: true, corps: { ok: true, action: 'aucune_preemption' } };
    if (!r.ok) return reponse(false, { message: 'panne simulee' }, 500);
    return reponse(true, r.corps);
  }

  // LE DECOR REPOND AUSSI A L'ANCIEN CHEMIN, et ce n'est pas de la complaisance : sans cela, la
  // contre-epreuve ne toucherait pas le defaut. La version precedente LISAIT le budget puis la
  // caisse, puis ecrivait les deux. Si ces lectures rendaient une liste vide, elle sortait par
  // `continue` sans jamais ecrire -- et l'epreuve « aucune ecriture directe » passerait aussi
  // sur le code fautif, donc ne prouverait rien. Avec une preemption et une caisse garnie, le
  // code fautif emet ses deux PATCH et l'epreuve tombe. Le code actuel, lui, n'emet aucune de
  // ces lectures : elles restent sans effet sur le mode nominal.
  if (appel.methode === 'GET' && appel.url.indexOf('budgets_nationaux') !== -1) {
    return reponse(true, [{ id: 'republic', data: { preemption: {
      entrepriseType: 'zz_banc', montantRestant: 2500, mensualite: 1000 } } }]);
  }
  if (appel.methode === 'GET' && appel.url.indexOf('caisses_batiments') !== -1) {
    return reponse(true, [{ id: 'republic_gouvernement-min_fin', data: { solde: 50000 } }]);
  }
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

function rejouer(reponses) {
  APPELS = [];
  REPONSES = reponses || {};
  return sync(preleverPreemptionsServeur());
}

function ecrituresDirectes() {
  return APPELS.filter(function (a) {
    return a.methode !== 'GET'
        && (a.url.indexOf('caisses_batiments') !== -1 || a.url.indexOf('budgets_nationaux') !== -1)
        && !estRpcPreemption(a);
  });
}

print('');

// --------------------------------------------------------------- MODE FAIL-CLOSED
if (typeof SUPABASE_SERVICE_ROLE === 'undefined' || !SUPABASE_SERVICE_ROLE) {
  print('BANC DES PREEMPTIONS — mode SANS identite serveur (decor absent)');
  print('============================================================================');
  var rf = rejouer({});
  verifier('aucune requete n est envoyee sans cle de service', APPELS.length, 0);
  verifier('aucune mensualite prelevee', rf.payes, 0);
  verifier('la cause est tracee comme une erreur', rf.erreurs, 1);
  print('');
  print('============================================================================');
  if (echecs === 0) print('LES ' + total + ' EPREUVES SONT VERTES.');
  else print('ECHEC : ' + echecs + ' epreuve(s) sur ' + total);
} else {

// --------------------------------------------------------------- MODE NOMINAL
print('BANC DES PREEMPTIONS — tout dans la RPC, aucune ecriture directe');
print('============================================================================');

var empires = Object.keys(VILLES_SERVEUR);

// 1. un appel de RPC par empire, et rien d'autre
var r = rejouer({
  republic: { ok: true, corps: { ok: true, action: 'preleve', preleve: 1000, restant: 1500 } },
  soviet:   { ok: true, corps: { ok: true, action: 'aucune_preemption' } },
  narco:    { ok: true, corps: { ok: true, action: 'aucune_preemption' } },
  khalija:  { ok: true, corps: { ok: true, action: 'aucune_preemption' } }
});
verifier('un appel de RPC par empire du referentiel', APPELS.filter(estRpcPreemption).length, empires.length);
verifier('AUCUNE ecriture directe de caisse ni de budget', ecrituresDirectes().length, 0);
verifier('aucune autre requete que les RPC', APPELS.length, empires.length);
verifier('une mensualite comptee', r.payes, 1);
verifier('aucun report', r.reportes, 0);

// 2. l'identite serveur est exigee
var premier = APPELS.filter(estRpcPreemption)[0];
vrai('la RPC part sous identite serveur, pas sous la cle anon',
     premier && premier.entetes && premier.entetes.apikey === 'zz-cle-service-de-banc',
     premier && JSON.stringify(premier.entetes));
vrai('le pays est passe en parametre nomme p_pays',
     premier && premier.corps && typeof premier.corps.p_pays === 'string',
     premier && JSON.stringify(premier.corps));

// 3. chaque verdict est consomme
r = rejouer({
  republic: { ok: true, corps: { ok: true, action: 'solde',       preleve: 400, restant: 0 } },
  soviet:   { ok: true, corps: { ok: true, action: 'reporte',     raison: 'solde_insuffisant' } },
  narco:    { ok: true, corps: { ok: true, action: 'deja_traite' } },
  khalija:  { ok: true, corps: { ok: true, action: 'aucune_preemption' } }
});
verifier('la derniere mensualite compte comme payee', r.payes, 1);
verifier('et comme soldee', r.soldes, 1);
verifier('le report est compte', r.reportes, 1);
verifier('la journee deja prise est comptee a part', r.deja_traites, 1);
verifier('toujours aucune ecriture directe', ecrituresDirectes().length, 0);

// 4. un refus explicite n'est pas avale
r = rejouer({
  republic: { ok: true, corps: { ok: false, raison: 'preemption_illisible' } },
  soviet:   { ok: true, corps: { ok: true, action: 'aucune_preemption' } },
  narco:    { ok: true, corps: { ok: true, action: 'aucune_preemption' } },
  khalija:  { ok: true, corps: { ok: true, action: 'aucune_preemption' } }
});
verifier('un refus metier est compte comme refus', r.refus, 1);
verifier('et jamais comme un prelevement', r.payes, 0);

// 5. une panne de transport n'est ni un prelevement ni un report
r = rejouer({
  republic: { ok: false },
  soviet:   { ok: true, corps: { ok: true, action: 'preleve', preleve: 500, restant: 500 } },
  narco:    { ok: true, corps: { ok: true, action: 'aucune_preemption' } },
  khalija:  { ok: true, corps: { ok: true, action: 'aucune_preemption' } }
});
verifier('la panne est comptee comme erreur', r.erreurs, 1);
verifier('elle n est pas comptee comme report', r.reportes, 0);
verifier('les autres empires sont quand meme traites', r.payes, 1);
verifier('et aucune ecriture directe n a ete tentee', ecrituresDirectes().length, 0);

// 6. une reponse vide ou illisible ne compte pas comme un succes
r = rejouer({
  republic: { ok: true, corps: [] },
  soviet:   { ok: true, corps: { ok: true, action: 'aucune_preemption' } },
  narco:    { ok: true, corps: { ok: true, action: 'aucune_preemption' } },
  khalija:  { ok: true, corps: { ok: true, action: 'aucune_preemption' } }
});
verifier('une reponse vide est un refus, pas un prelevement', r.refus, 1);
verifier('aucune mensualite comptee sur reponse vide', r.payes, 0);

print('');
print('============================================================================');
if (echecs === 0) print('LES ' + total + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + echecs + ' epreuve(s) sur ' + total);
}
