/* ===========================================================================
   BANC DE preleverPretsBancairesServeur — api/cron-minuit.js
   SOURCES: api/_referentiels-generes.js api/cron-minuit.js
   Chantier 6, 9 octobre 2026 ; contrat financier #430, 4 novembre 2026
   ===========================================================================

   CE QU'IL PROUVE. Ce traitement posait bien son marqueur de journee AVANT le mouvement --
   c'etait juste -- mais son echec etait avale par un `.catch(() => {})`, et la mensualite
   partait quand meme. Une panne reseau d'une seconde laissait donc un debit sans sa garde,
   donc un second prelevement possible la nuit suivante, sur de l'argent reel. C'est
   l'inverse exact de la doctrine de tacheQuotidienne(), qui relit son marqueur et RENONCE.

   LA PREUVE QUI COMPTE EST L'ABSENCE DE DEBIT. Le banc enregistre chaque appel reseau dans
   l'ordre et exige qu'AUCUNE commande de debit (RPC ou ancien PATCH) ne soit emise si la revendication n'a
   pas abouti -- panne de transport comme journee deja prise. Lire `resultats` ne suffirait
   pas : un compteur a zero n'empeche pas un debit deja parti.

   IL PROUVE AUSSI QUE LA GARDE EST DANS LE FILTRE, donc que la revendication est un
   compare-and-swap : deux invocations simultanees du cron ne peuvent pas prendre la meme
   journee pour le meme pret.

   CONTRE-EPREUVE. Joue contre la version precedente de api/cron-minuit.js, ce banc ECHOUE :
     git show HEAD~1:api/cron-minuit.js > /tmp/avant.js
     python3 outils/bancs/lancer-banc.py outils/bancs/banc-prets-bancaires.js \
             api/_referentiels-generes.js /tmp/avant.js
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
// Un pret de banque nationale en cours, posterieur au gel du 14 septembre, dont la journee
// n'a pas encore ete prise. Emprunteur solvable : le debit est donc attendu.
var PRET = {
  id: 'pret-banc', emprunteur: 'Emprunteur', country: 'republic', type_banque: 'nationale',
  statut: 'en_cours', montant_restant: 5000, mensualite: 500, jours_impayes: 0,
  jour_dernier_prelevement: null, created_at: '2026-10-01T12:00:00'
};

var APPELS = [];
var REPONSE_REVENDICATION = { ok: true, corps: [{ id: 'pret-banc' }] };
var REPONSE_DEBIT = { transport: true, corps: { ok: true, applique: 500 } };

function estRevendication(appel) {
  return appel.methode === 'PATCH' && appel.url.indexOf('prets') !== -1
      && appel.corps !== null && appel.corps.jour_dernier_prelevement !== undefined;
}

globalThis.fetch = function (url, options) {
  var o = options || {};
  var methode = o.method || 'GET';
  var appel = { methode: methode, url: String(url), corps: o.body ? JSON.parse(o.body) : null };
  APPELS.push(appel);

  function reponse(ok, donnees, statut) {
    return Promise.resolve({
      ok: ok, status: statut || (ok ? 200 : 500),
      json: function () { return Promise.resolve(donnees); },
      text: function () { return Promise.resolve(JSON.stringify(donnees)); }
    });
  }

  if (methode === 'POST' && String(url).indexOf('/rpc/argent_mouvement_serveur') !== -1) {
    return reponse(REPONSE_DEBIT.transport, REPONSE_DEBIT.corps);
  }
  if (estRevendication(appel)) {
    if (!REPONSE_REVENDICATION.ok) return reponse(false, { message: 'panne simulee' }, 500);
    return reponse(true, REPONSE_REVENDICATION.corps);
  }
  if (methode === 'GET' && String(url).indexOf('prets') !== -1) return reponse(true, [PRET]);
  if (methode === 'GET' && String(url).indexOf('personnages') !== -1) {
    return reponse(true, [{ name: 'Emprunteur', arg: 10000, liquide: 10000 }]);
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
  return sync(preleverPretsBancairesServeur());
}

function debitsEmis() {
  return APPELS.filter(function (a) {
    return (a.methode === 'PATCH' && a.url.indexOf('personnages') !== -1)
      || (a.methode === 'POST' && a.url.indexOf('/rpc/argent_mouvement_serveur') !== -1 && a.corps.p_sens === 'debit');
  });
}

function apresRevendication() {
  for (var i = 0; i < APPELS.length; i++) {
    if (estRevendication(APPELS[i])) return APPELS.slice(i + 1);
  }
  return null;
}

print('');
print('BANC DE preleverPretsBancairesServeur — aucun debit sans sa garde');
print('============================================================================');

var jour = jourParisISO();

// ----------------------------------------- 1. la revendication, son filtre, son corps
var r = rejouer({ ok: true, corps: [{ id: 'pret-banc' }] });
var revend = null;
for (var i = 0; i < APPELS.length; i++) { if (estRevendication(APPELS[i])) { revend = APPELS[i]; break; } }
vrai('une revendication PATCH sur prets est emise', revend !== null);
vrai('le filtre cible le pret par son id',
     revend !== null && revend.url.indexOf('id=eq.pret-banc') !== -1, revend && revend.url);
vrai('le filtre EXIGE que la journee ne soit pas deja prise (compare-and-swap)',
     revend !== null && revend.url.indexOf('jour_dernier_prelevement.neq.' + jour) !== -1,
     revend && revend.url);
vrai('le filtre accepte le pret dont la colonne est vide (is.null -- neq exclut les NULL)',
     revend !== null && revend.url.indexOf('jour_dernier_prelevement.is.null') !== -1,
     revend && revend.url);
verifier('le corps pose le jour courant',
         revend && revend.corps && revend.corps.jour_dernier_prelevement, jour);

// ----------------------------------------- 2. elle precede tout mouvement d'argent
var premiereEcriture = null;
for (var j = 0; j < APPELS.length; j++) { if (APPELS[j].methode !== 'GET') { premiereEcriture = APPELS[j]; break; } }
vrai('la revendication est la PREMIERE ecriture de la passe',
     premiereEcriture !== null && estRevendication(premiereEcriture),
     premiereEcriture && (premiereEcriture.methode + ' ' + premiereEcriture.url));

// ----------------------------------------- 3. revendication acquise : la mensualite part
verifier('une mensualite est prelevee', r.preleves, 1);
verifier('un seul debit emis sur l emprunteur', debitsEmis().length, 1);
// #430 : arg est dérivé, seul le moteur financier serveur prélève les poches.
verifier('le debit utilise le moteur financier et son montant exact',
  debitsEmis()[0] && debitsEmis()[0].corps, {p_nom:'Emprunteur',p_montant:500,p_sens:'debit'});
vrai('aucun ancien PATCH financier sur la fiche', !APPELS.some(function(a){
  return a.methode === 'PATCH' && a.url.indexOf('personnages') !== -1 && a.corps && ('arg' in a.corps || 'liquide' in a.corps);
}));
vrai('la dette baisse du montant confirme', APPELS.some(function(a){
  return a.methode === 'PATCH' && a.url.indexOf('prets') !== -1 && a.corps.montant_restant === 4500;
}));
vrai('le debit suit la revendication, jamais avant',
     (apresRevendication() || []).some(function (a) {
       return (a.methode === 'PATCH' && a.url.indexOf('personnages') !== -1)
      || (a.methode === 'POST' && a.url.indexOf('/rpc/argent_mouvement_serveur') !== -1 && a.corps.p_sens === 'debit');
     }));

// ----------------------------------------- 4. journee DEJA prise : aucun debit
r = rejouer({ ok: true, corps: [] });
verifier('journee deja prise : aucune mensualite prelevee', r.preleves, 0);
verifier('journee deja prise : comptee comme deja revendiquee', r.deja_revendiques, 1);
verifier('journee deja prise : AUCUN debit emis', debitsEmis().length, 0);
verifier('journee deja prise : AUCUNE requete apres la revendication',
         (apresRevendication() || ['(aucune)']).length, 0);

// ----------------------------------------- 5. panne de transport : aucun debit
r = rejouer({ ok: false });
verifier('panne de transport : aucune mensualite prelevee', r.preleves, 0);
verifier('panne de transport : le marqueur est declare non pose', r.marqueurs_non_poses, 1);
verifier('panne de transport : AUCUN debit emis', debitsEmis().length, 0);
verifier('panne de transport : AUCUNE requete apres la revendication',
         (apresRevendication() || ['(aucune)']).length, 0);

// #430 : le refus/panne du moteur ne doit pas diminuer la dette malgré le marqueur.
for (var modeDebit of [{transport:true,corps:{ok:false,raison:'fonds_insuffisants'}},
                       {transport:false,corps:{message:'panne simulee'}}]) {
  REPONSE_DEBIT = modeDebit;
  r = rejouer({ok:true,corps:[{id:'pret-banc'}]});
  verifier('debit refuse ou reseau perdu : aucun remboursement annonce', r.preleves, 0);
  verifier('debit refuse ou reseau perdu : echec explicite', r.echecs_prelevement, 1);
  vrai('debit refuse ou reseau perdu : aucune baisse de dette', !APPELS.some(function(a){
    return a.methode === 'PATCH' && a.url.indexOf('prets') !== -1 && a.corps.montant_restant !== undefined;
  }));
}
REPONSE_DEBIT = {transport:true,corps:{ok:true,applique:300}};
r = rejouer({ok:true,corps:[{id:'pret-banc'}]});
vrai('seul le montant reellement confirme reduit la dette', APPELS.some(function(a){
 return a.methode === 'PATCH' && a.url.indexOf('prets') !== -1 && a.corps.montant_restant === 4700;
}));
REPONSE_DEBIT = {transport:true,corps:{ok:true,applique:500}};

// ----------------------------------------- 6. la garde amont et le gel tiennent toujours
PRET.jour_dernier_prelevement = jour;
r = rejouer({ ok: true, corps: [{ id: 'pret-banc' }] });
verifier('deja preleve aujourd hui : rien n est prelevé', r.preleves, 0);
vrai('deja preleve aujourd hui : aucune revendication n est meme tentee',
     apresRevendication() === null);
verifier('deja preleve aujourd hui : aucun debit', debitsEmis().length, 0);
PRET.jour_dernier_prelevement = null;

PRET.created_at = '2026-09-01T12:00:00';          // anterieur au gel du 14 septembre
r = rejouer({ ok: true, corps: [{ id: 'pret-banc' }] });
verifier('pret gele pour arbitrage : signale, jamais touche', r.gelesPourArbitrage.length, 1);
verifier('pret gele pour arbitrage : aucun debit', debitsEmis().length, 0);
vrai('pret gele pour arbitrage : aucune revendication', apresRevendication() === null);
PRET.created_at = '2026-10-01T12:00:00';

print('');
print('============================================================================');
if (echecs === 0) print('LES ' + total + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + echecs + ' epreuve(s) sur ' + total);
