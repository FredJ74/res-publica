/* ===========================================================================
   BANC DE renouvellerCotisationsOrganisations — api/cron-minuit.js
   SOURCES: outils/bancs/decor-env-serveur.js api/_referentiels-generes.js api/cron-minuit.js
   Chantier 6, famille D (1/2) — 10 octobre 2026
   ===========================================================================

   CE QU'IL PROUVE. Une cotisation etait TROIS requetes HTTP : debit du membre
   (sbUpdate personnages), credit de la contrepartie (crediterBudgetClubServeur, elle-meme une
   lecture-modification-ecriture de budgets_clubs avec catch avale, ou orga.caisse en memoire),
   puis ecriture du blob portant le marqueur. Le code consignait lui-meme la dette.

   LA PREUVE QUI COMPTE EST L'ABSENCE D'ECRITURE DIRECTE. Tout est descendu dans
   cotisation_renouveler : ce chemin ne doit plus emettre aucune ecriture sur personnages,
   organisations, budgets_clubs ni mails, et ne doit plus lire la fiche du membre.

   IL PROUVE AUSSI que la REGLE D'ECHEANCE est inchangee -- c'est la seule chose qui reste ici :
   supporters a chaque nouvelle saison lue sur saison.numero, syndicat des Dockers tous les trois
   mois calendaires, et les autres organisations jamais. Un membre qui n'est pas du ne doit meme
   pas etre presente a la porte.

   ET que les verdicts sont comptes a leur place : un verdict absent n'est jamais un succes, les
   deux refus de liste perimee ne sont pas des echecs, tout autre refus est signale.

   CONTRE-EPREUVE. Joue contre la version precedente de api/cron-minuit.js, il ECHOUE :
     git show HEAD:api/cron-minuit.js > /tmp/avant.js
     python3 outils/bancs/lancer-banc.py outils/bancs/banc-cotisations-organisations.js \
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

var APPELS = [], VERDICTS = {}, HTTP_OK = true, ORGAS = [], SAISON = { numero: 7 };

function estRpcPorte(a) { return a.url.indexOf('/rpc/cotisation_renouveler') !== -1; }

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
    var cle = (appel.corps && appel.corps.p_orga_id) + '/' + (appel.corps && appel.corps.p_membre);
    return reponse(true, VERDICTS[cle] !== undefined ? VERDICTS[cle] : null);
  }
  if (appel.methode === 'GET' && appel.url.indexOf('organisations') !== -1) {
    return reponse(true, ORGAS);
  }
  if (appel.methode === 'GET' && appel.url.indexOf('championnat') !== -1) {
    return reponse(true, SAISON === null ? [] : [{ data: JSON.stringify(SAISON) }]);
  }
  // LE DECOR REPOND AUSSI A L'ANCIEN CHEMIN : sans fiche de personnage credible, la version
  // precedente resilierait tout le monde sans rien debiter, et l'epreuve « aucune ecriture
  // directe » passerait aussi sur le code fautif -- donc ne prouverait rien.
  if (appel.methode === 'GET' && appel.url.indexOf('personnages') !== -1) {
    return reponse(true, [{ name: 'Ben', country: 'republic', arg: 5000 }]);
  }
  if (appel.methode === 'GET' && appel.url.indexOf('budgets_clubs') !== -1) {
    return reponse(true, [{ id: 'olympique-luthecia', data: { clubId: 'olympique-luthecia',
                            caisse: 0, historique: [] } }]);
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

function orga(id, blob) {
  return { id: id, country_origine: 'republic', data: JSON.stringify(blob) };
}
function supporters(membres) {
  return orga('orga_supporters_republic_capitale', { id: 'orga_supporters_republic_capitale',
    type: 'supporters', nom: 'Supporters de Luthécia', country: 'republic', city: 'capitale',
    membres: membres });
}
function syndicatPSM(membres) {
  return orga('orga_syndicat_dockers_republic_ville_a',
    { id: 'orga_syndicat_dockers_republic_ville_a', type: 'syndicale',
      nom: 'Syndicat des Dockers de Port-Sainte-Marie', country: 'republic', city: 'ville_a',
      caisse: 0, membres: membres });
}

function ecrituresDirectes() {
  return APPELS.filter(function (a) {
    return a.methode !== 'GET' && !estRpcPorte(a)
        && (a.url.indexOf('organisations') !== -1 || a.url.indexOf('personnages') !== -1
            || a.url.indexOf('budgets_clubs') !== -1 || a.url.indexOf('mails') !== -1
            || a.url.indexOf('/rpc/mail_systeme_poser') !== -1);
  });
}
function lecturesInutiles() {
  return APPELS.filter(function (a) {
    return a.methode === 'GET' && (a.url.indexOf('personnages') !== -1
                                   || a.url.indexOf('budgets_clubs') !== -1);
  });
}
function appelsPorte() { return APPELS.filter(estRpcPorte); }
function membresPresentes() {
  return appelsPorte().map(function (a) { return a.corps.p_membre; });
}

function rejouer(verdicts, orgas, httpOk, saison) {
  APPELS = []; VERDICTS = verdicts || {}; HTTP_OK = httpOk !== false;
  ORGAS = orgas || []; SAISON = saison === undefined ? { numero: 7 } : saison;
  return sync(renouvellerCotisationsOrganisations());
}

// Une date reelle vieille de N mois, pour l'echeance du syndicat.
function ilYaDesMois(n) {
  var d = new Date(); d.setMonth(d.getMonth() - n); return d.toISOString();
}

print('');
print('BANC DES COTISATIONS D ORGANISATION');
print('============================================================================');

print('1. UNE PORTE PAR MEMBRE DU, AUCUNE ECRITURE DIRECTE, AUCUNE LECTURE INUTILE');
var r = rejouer({ 'orga_supporters_republic_capitale/Ben':
                    [{ ok: true, action: 'renouvellement', montant: 50 }] },
                [supporters([{ nom: 'Ben', derniereCotisationSaison: 6 }])]);
verifier('la porte est appelee une fois', appelsPorte().length, 1);
vrai('avec l organisation, le membre et la saison', appelsPorte().length === 1
     && appelsPorte()[0].corps.p_orga_id === 'orga_supporters_republic_capitale'
     && appelsPorte()[0].corps.p_membre === 'Ben'
     && appelsPorte()[0].corps.p_saison === 7,
     JSON.stringify(appelsPorte()[0] && appelsPorte()[0].corps));
verifier('aucune ecriture directe', ecrituresDirectes().length, 0);
verifier('la fiche du membre n est plus relue ici', lecturesInutiles().length, 0);
verifier('un renouvellement est compte', r.renouvellements, 1);
verifier('et aucune resiliation', r.resiliations, 0);

print('');
print('2. LA REGLE D ECHEANCE DES SUPPORTERS EST INCHANGEE : LA SAISON');
r = rejouer({}, [supporters([{ nom: 'Ben', derniereCotisationSaison: 7 }])]);
verifier('deja a jour pour la saison : jamais presente', appelsPorte().length, 0);
r = rejouer({}, [supporters([{ nom: 'Ben', derniereCotisationSaison: 6 }])], true, null);
verifier('sans championnat lisible, personne n est presente', appelsPorte().length, 0);
r = rejouer({ 'orga_supporters_republic_capitale/Nouvelle':
                [{ ok: true, action: 'renouvellement' }] },
            [supporters([{ nom: 'Nouvelle' }])]);
verifier('un membre sans marqueur est du', membresPresentes(), ['Nouvelle']);

print('');
print('3. LA REGLE D ECHEANCE DU SYNDICAT EST INCHANGEE : TROIS MOIS CALENDAIRES');
r = rejouer({ 'orga_syndicat_dockers_republic_ville_a/Vieux':
                [{ ok: true, action: 'renouvellement' }] },
            [syndicatPSM([{ nom: 'Vieux', derniereCotisationDate: ilYaDesMois(4) },
                          { nom: 'Recent', derniereCotisationDate: ilYaDesMois(1) },
                          { nom: 'SansDate' }])]);
verifier('seul le membre echu est presente', membresPresentes(), ['Vieux']);
vrai('et la saison ne lui est pas transmise',
     appelsPorte().length === 1 && appelsPorte()[0].corps.p_saison === null,
     JSON.stringify(appelsPorte()[0] && appelsPorte()[0].corps));
verifier('aucune ecriture directe', ecrituresDirectes().length, 0);

print('');
print('4. LES AUTRES ORGANISATIONS NE COTISENT PAS');
r = rejouer({}, [orga('orga_syndicale_pj_quelconque',
                      { id: 'orga_syndicale_pj_quelconque', type: 'syndicale', nom: 'Un syndicat PJ',
                        country: 'republic', city: 'capitale',
                        membres: [{ nom: 'Ben', derniereCotisationDate: ilYaDesMois(9) }] })]);
verifier('un syndicat fonde par un PJ n est pas presente', appelsPorte().length, 0);
r = rejouer({}, [supporters([])]);
verifier('une organisation sans membre n est pas presentee', appelsPorte().length, 0);
r = rejouer({}, [{ id: 'cassee', country_origine: 'republic', data: '{ pas du json' }]);
verifier('un blob illisible est saute sans incident', appelsPorte().length, 0);

print('');
print('5. UNE RESILIATION EST COMPTEE, ET SON COURRIER N EST PLUS ECRIT ICI');
r = rejouer({ 'orga_supporters_republic_capitale/Fauche':
                [{ ok: true, action: 'resiliation' }] },
            [supporters([{ nom: 'Fauche', derniereCotisationSaison: 6 }])]);
verifier('une resiliation est comptee', r.resiliations, 1);
verifier('et aucun renouvellement', r.renouvellements, 0);
verifier('aucun courrier n est ecrit par ce chemin', ecrituresDirectes().length, 0);

print('');
print('6. AUCUN VERDICT N EST JAMAIS UN SUCCES');
var avant = ECHECS_PASSE.length;
r = rejouer({ 'orga_supporters_republic_capitale/Ben': null },
            [supporters([{ nom: 'Ben', derniereCotisationSaison: 6 }])]);
verifier('verdict absent : rien compte', r.renouvellements + r.resiliations, 0);
vrai('verdict absent : signale', ECHECS_PASSE.length - avant === 1
     && String(ECHECS_PASSE[ECHECS_PASSE.length - 1].etape)
          .indexOf('cotisation:orga_supporters_republic_capitale:Ben') === 0,
     JSON.stringify(ECHECS_PASSE.slice(avant)));
r = rejouer({ 'orga_supporters_republic_capitale/Ben': [] },
            [supporters([{ nom: 'Ben', derniereCotisationSaison: 6 }])]);
verifier('reponse vide : rien compte', r.renouvellements + r.resiliations, 0);
r = rejouer({}, [supporters([{ nom: 'Ben', derniereCotisationSaison: 6 }])], false);
verifier('panne HTTP : rien compte', r.renouvellements + r.resiliations, 0);
verifier('panne HTTP : aucune ecriture directe', ecrituresDirectes().length, 0);
r = rejouer({ 'orga_supporters_republic_capitale/Ben': [{ ok: true }] },
            [supporters([{ nom: 'Ben', derniereCotisationSaison: 6 }])]);
verifier('verdict ok sans action : rien compte', r.renouvellements + r.resiliations, 0);

print('');
print('7. LES DEUX REFUS DE LISTE PERIMEE NE SONT PAS DES ECHECS, LES AUTRES OUI');
avant = ECHECS_PASSE.length;
var perimes = ['organisation_introuvable', 'membre_introuvable'];
for (var i = 0; i < perimes.length; i++) {
  r = rejouer({ 'orga_supporters_republic_capitale/Ben': [{ ok: false, action: perimes[i] }] },
              [supporters([{ nom: 'Ben', derniereCotisationSaison: 6 }])]);
  verifier('refus « ' + perimes[i] + ' » : rien compte', r.renouvellements + r.resiliations, 0);
}
verifier('et aucun des deux n est signale', ECHECS_PASSE.length - avant, 0);
avant = ECHECS_PASSE.length;
r = rejouer({ 'orga_supporters_republic_capitale/Ben': [{ ok: false, action: 'caisse_absente' }] },
            [supporters([{ nom: 'Ben', derniereCotisationSaison: 6 }])]);
vrai('un refus inconnu, lui, est signale', ECHECS_PASSE.length - avant === 1,
     JSON.stringify(ECHECS_PASSE.slice(avant)));

print('');
print('8. CHAQUE MEMBRE DU A SON PROPRE APPEL, ET UN ECHEC N ARRETE PAS LES AUTRES');
r = rejouer({ 'orga_supporters_republic_capitale/A': [{ ok: true, action: 'renouvellement' }],
              'orga_supporters_republic_capitale/B': null,
              'orga_supporters_republic_capitale/C': [{ ok: true, action: 'resiliation' }] },
            [supporters([{ nom: 'A', derniereCotisationSaison: 6 },
                         { nom: 'B', derniereCotisationSaison: 6 },
                         { nom: 'C', derniereCotisationSaison: 6 }])]);
verifier('trois appels pour trois membres', membresPresentes(), ['A', 'B', 'C']);
verifier('le renouvellement est compte', r.renouvellements, 1);
verifier('la resiliation est comptee', r.resiliations, 1);
verifier('aucune ecriture directe', ecrituresDirectes().length, 0);

print('');
print('9. CE QUE L ANCIEN CODE PORTAIT ET QUI N A PLUS DE RAISON D ETRE');
vrai('plus aucun compteur de marqueurs non poses', r.marqueurs_non_poses === undefined,
     JSON.stringify(r));

print('');
print('============================================================================');
if (echecs === 0) print('LES ' + total + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + echecs + ' epreuve(s) sur ' + total);
