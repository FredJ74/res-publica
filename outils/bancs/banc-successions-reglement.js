/* ===========================================================================
   BANC DU REGLEMENT DES SUCCESSIONS — api/cron-minuit.js
   SOURCES: outils/bancs/decor-env-serveur.js api/_referentiels-generes.js api/cron-minuit.js
   Chantier 6, famille D (2/2) — 10 octobre 2026
   ===========================================================================

   CE QU'IL PROUVE. reglerSuccession etait bien construite -- l'audit du 7 octobre se trompait en
   la decrivant comme une passoire. Son defaut residuel etait UNE FENETRE : entre le credit reel et
   la pose du marqueur `regle`, deux requetes HTTP. Un plantage dans cet intervalle laissait un
   heritier credite sans marqueur, donc recredite la nuit suivante.

   LA PREUVE QUI COMPTE EST L'ABSENCE D'ECRITURE DIRECTE DE REGLEMENT. Toutes les mutations sont
   descendues dans succession_regler : ce chemin ne doit plus emettre aucune ecriture sur
   terrains_etat, entreprises, personnages, budgets_nationaux ni caisses_batiments, et ne doit plus
   relire la fiche d'un beneficiaire ni une caisse.

   LA SEULE ECRITURE DIRECTE QUI RESTE EST CELLE DE LA PHASE DE DECISION : la persistance des
   `dispositions` fraichement tranchees, AVANT tout reglement. Le banc l'exige explicitement --
   la supprimer ferait muter des actifs sur une decision jamais ecrite.

   IL PROUVE AUSSI qu'une succession dont une disposition n'a pas de decision n'est pas presentee a
   la porte, qu'un verdict absent n'est jamais une cloture, et qu'une etape refusee est NOMMEE dans
   ECHECS_PASSE meme quand le reste a abouti.

   CONTRE-EPREUVE. Joue contre la version precedente de api/cron-minuit.js, il ECHOUE :
     git show HEAD:api/cron-minuit.js > /tmp/avant.js
     python3 outils/bancs/lancer-banc.py outils/bancs/banc-successions-reglement.js \
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

var APPELS = [], VERDICT = null, HTTP_OK = true, SUCCESSIONS = [];

function estRpcPorte(a) { return a.url.indexOf('/rpc/succession_regler') !== -1; }

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
    return reponse(true, VERDICT);
  }
  if (appel.methode === 'GET' && appel.url.indexOf('successions') !== -1) {
    return reponse(true, SUCCESSIONS);
  }
  // LE DECOR REPOND AUSSI A L'ANCIEN CHEMIN : terrain, entreprise, fiche et caisse credibles,
  // sinon la version precedente sortirait par `return false` avant d'ecrire, et l'epreuve
  // « aucune ecriture de reglement » passerait aussi sur le code fautif.
  if (appel.methode === 'GET' && appel.url.indexOf('terrains_etat') !== -1) {
    return reponse(true, [{ id: 'republic_zz-parcelle', country: 'republic',
      building_id: 'zz-parcelle',
      data: JSON.stringify({ city: 'capitale', proprietaire: 'Zz Defunt',
                             coproprietaire: 'Zz Copro', succession_gel: 'zzs-1' }) }]);
  }
  if (appel.methode === 'GET' && appel.url.indexOf('entreprises') !== -1) {
    return reponse(true, [{ id: 'zze-1', data: { proprietaire: 'Zz Defunt',
                                                 succession_gel: 'zzs-1' } }]);
  }
  if (appel.methode === 'GET' && appel.url.indexOf('personnages') !== -1) {
    return reponse(true, [{ name: 'Ben', country: 'republic', arg: 1000 }]);
  }
  if (appel.methode === 'GET' && appel.url.indexOf('budgets_nationaux') !== -1) {
    return reponse(true, [{ id: 'republic', data: { reserveJour: 0 } }]);
  }
  if (appel.methode === 'GET' && appel.url.indexOf('caisses_batiments') !== -1) {
    return reponse(true, [{ id: 'republic_office-notarial', data: { solde: 200 } }]);
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

// Une succession dont TOUTES les dispositions portent deja leur decision : la phase de decision
// n'a rien a trancher, le reglement est presente immediatement.
function successionTranchee() {
  return { id: 'zzs-1', defunt: 'Zz Defunt', country: 'republic', statut: 'en_attente',
    conjoint: null, droits_total: 1000, part_etat: 900, part_notaire: 100,
    part_etat_reglee: false, part_notaire_reglee: false,
    dispositions: [
      { type: 'terrain', id: 'zz-parcelle', regle: false,
        resultat: { beneficiaire: 'Ben', statut: 'accepte' } },
      { type: 'argent', part_nette: 700, regle: false,
        resultat: { beneficiaire: 'Ben', statut: 'accepte' } },
      { type: 'entreprise', id: 'zze-1', regle: false,
        resultat: { beneficiaire: null, statut: 'devolution_etat' } }
    ] };
}

// Une succession dont une disposition attend encore une reponse non echue : rien a regler.
function successionEnAttenteDeReponse() {
  var demain = new Date(Date.now() + 86400000).toISOString();
  return { id: 'zzs-2', defunt: 'Zz Defunt 2', country: 'republic', statut: 'en_attente',
    conjoint: null, droits_total: 0, part_etat: 0, part_notaire: 0,
    dispositions: [
      { type: 'argent', part_nette: 100, regle: false,
        chaine: [{ role: 'principal', beneficiaire: 'Ben', convoque_le: '2026-10-01T00:00:00.000Z',
                   expires_at: demain, reponse: null, repondu_le: null }] }
    ] };
}

function ecrituresDeReglement() {
  return APPELS.filter(function (a) {
    return a.methode !== 'GET' && !estRpcPorte(a)
        && (a.url.indexOf('terrains_etat') !== -1 || a.url.indexOf('entreprises') !== -1
            || a.url.indexOf('personnages') !== -1 || a.url.indexOf('budgets_nationaux') !== -1
            || a.url.indexOf('caisses_batiments') !== -1);
  });
}
function lecturesInutiles() {
  return APPELS.filter(function (a) {
    return a.methode === 'GET' && (a.url.indexOf('budgets_nationaux') !== -1
            || a.url.indexOf('caisses_batiments') !== -1
            || a.url.indexOf('terrains_etat') !== -1 || a.url.indexOf('entreprises') !== -1);
  });
}
function ecrituresSuccessions() {
  return APPELS.filter(function (a) {
    return a.methode !== 'GET' && !estRpcPorte(a) && a.url.indexOf('successions') !== -1;
  });
}
function appelsPorte() { return APPELS.filter(estRpcPorte); }

function rejouer(verdict, successions, httpOk) {
  APPELS = []; VERDICT = verdict === undefined ? null : verdict;
  HTTP_OK = httpOk !== false; SUCCESSIONS = successions || [];
  return sync(resoudreSuccessionsExpirees());
}

print('');
print('BANC DU REGLEMENT DES SUCCESSIONS');
print('============================================================================');

print('1. UNE PORTE PAR SUCCESSION, AUCUNE ECRITURE DE REGLEMENT, AUCUNE LECTURE INUTILE');
var r = rejouer([{ ok: true, dispositions_reglees: 3, fiscalite: ['etat', 'notaire'],
                   cloturee: true, echecs: [] }], [successionTranchee()]);
verifier('la porte est appelee une fois', appelsPorte().length, 1);
vrai('avec l identifiant de la succession', appelsPorte().length === 1
     && appelsPorte()[0].corps.p_succession_id === 'zzs-1',
     JSON.stringify(appelsPorte()[0] && appelsPorte()[0].corps));
verifier('aucune ecriture de reglement', ecrituresDeReglement().length, 0);
verifier('aucune relecture d actif, de budget ni de caisse', lecturesInutiles().length, 0);
verifier('la cloture est comptee', r.successions_reglees, 1);

print('');
print('2. LA PHASE DE DECISION EST INTACTE, ET ELLE PERSISTE AVANT DE REGLER');
r = rejouer([{ ok: true, dispositions_reglees: 1, fiscalite: [], cloturee: true, echecs: [] }],
            [{ id: 'zzs-3', defunt: 'Zz Defunt 3', country: 'republic', statut: 'en_attente',
               conjoint: null, droits_total: 0, part_etat: 0, part_notaire: 0,
               dispositions: [{ type: 'argent', part_nette: 100, regle: false, chaine: [] }] }]);
verifier('une chaine vide est tranchee en devolution a l Etat au premier passage',
         ecrituresSuccessions().length >= 1
         && ecrituresSuccessions()[0].corps.dispositions[0].resultat.statut, 'devolution_etat');
vrai('la decision est ecrite AVANT l appel a la porte',
     APPELS.indexOf(ecrituresSuccessions()[0]) < APPELS.indexOf(appelsPorte()[0]),
     'decision a l index ' + APPELS.indexOf(ecrituresSuccessions()[0])
     + ', porte a l index ' + APPELS.indexOf(appelsPorte()[0]));
verifier('aucune ecriture de reglement', ecrituresDeReglement().length, 0);

print('');
print('3. UNE SUCCESSION DONT UNE DISPOSITION ATTEND N EST PAS PRESENTEE');
r = rejouer([{ ok: true, cloturee: true }], [successionEnAttenteDeReponse()]);
verifier('la porte n est pas appelee', appelsPorte().length, 0);
verifier('aucune cloture comptee', r.successions_reglees, 0);
verifier('aucune ecriture de reglement', ecrituresDeReglement().length, 0);

print('');
print('4. AUCUN VERDICT N EST JAMAIS UNE CLOTURE');
var avant = ECHECS_PASSE.length;
r = rejouer(null, [successionTranchee()]);
verifier('verdict absent : aucune cloture', r.successions_reglees, 0);
vrai('verdict absent : signale', ECHECS_PASSE.length - avant === 1
     && String(ECHECS_PASSE[ECHECS_PASSE.length - 1].etape) === 'succession:zzs-1',
     JSON.stringify(ECHECS_PASSE.slice(avant)));
r = rejouer([], [successionTranchee()]);
verifier('reponse vide : aucune cloture', r.successions_reglees, 0);
r = rejouer([{ ok: true, cloturee: true }], [successionTranchee()], false);
verifier('panne HTTP : aucune cloture', r.successions_reglees, 0);
verifier('panne HTTP : aucune ecriture de reglement', ecrituresDeReglement().length, 0);
avant = ECHECS_PASSE.length;
r = rejouer([{ ok: false, raison: 'succession_introuvable' }], [successionTranchee()]);
verifier('refus de la porte : aucune cloture', r.successions_reglees, 0);
vrai('refus de la porte : signale et NOMME', ECHECS_PASSE.length - avant === 1
     && String(ECHECS_PASSE[ECHECS_PASSE.length - 1].erreur) === 'succession_introuvable',
     JSON.stringify(ECHECS_PASSE.slice(avant)));

print('');
print('5. UN REGLEMENT PARTIEL N EST PAS UN SUCCES SILENCIEUX');
avant = ECHECS_PASSE.length;
r = rejouer([{ ok: true, dispositions_reglees: 2, fiscalite: ['etat', 'notaire'],
               cloturee: false, echecs: ['0:terrain_introuvable'] }], [successionTranchee()]);
verifier('non cloturee : rien compte', r.successions_reglees, 0);
vrai('l etape refusee est NOMMEE', ECHECS_PASSE.length - avant === 1
     && String(ECHECS_PASSE[ECHECS_PASSE.length - 1].erreur)
          .indexOf('0:terrain_introuvable') >= 0,
     JSON.stringify(ECHECS_PASSE.slice(avant)));
avant = ECHECS_PASSE.length;
r = rejouer([{ ok: true, dispositions_reglees: 3, fiscalite: ['etat', 'notaire'],
               cloturee: true, echecs: ['2:entreprise_introuvable'] }], [successionTranchee()]);
verifier('cloturee malgre une etape refusee : la cloture est comptee', r.successions_reglees, 1);
vrai('et l etape refusee est signalee QUAND MEME', ECHECS_PASSE.length - avant === 1,
     JSON.stringify(ECHECS_PASSE.slice(avant)));

print('');
print('6. PLUSIEURS SUCCESSIONS, UN APPEL CHACUNE');
var a = successionTranchee(), b = successionTranchee();
b.id = 'zzs-autre';
r = rejouer([{ ok: true, dispositions_reglees: 3, fiscalite: [], cloturee: true, echecs: [] }],
            [a, b]);
verifier('deux appels pour deux successions',
         appelsPorte().map(function (x) { return x.corps.p_succession_id; }),
         ['zzs-1', 'zzs-autre']);
verifier('deux clotures comptees', r.successions_reglees, 2);
verifier('aucune ecriture de reglement', ecrituresDeReglement().length, 0);

print('');
print('============================================================================');
if (echecs === 0) print('LES ' + total + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + echecs + ' epreuve(s) sur ' + total);
