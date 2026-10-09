/* ===========================================================================
   BANC DE resoudreCompromisExpires ET resoudreCompromisEntreprisesExpires
   api/cron-minuit.js — chantier 6, 9 octobre 2026
   SOURCES: outils/bancs/decor-env-serveur.js api/_referentiels-generes.js api/cron-minuit.js
   ===========================================================================

   CE QU'IL PROUVE. Ces deux passes decidaient du pret bancaire en JavaScript
   (`Math.random() < 0.5`), puis appliquaient la decision en QUATRE ecritures independantes et
   avalees : credit de l'emprunteur, ligne `prets`, blob du bien, ligne `compromis_historique`.
   Les trois scenarios de l'audit du chantier 6 etaient tous atteignables -- double credit de
   pret, argent sans dette, double remboursement d'acompte avec une seconde ligne d'historique
   que la cle primaire ne refusait pas.

   LA PREUVE QUI COMPTE EST L'ABSENCE D'ECRITURE DIRECTE ET DE TIRAGE. Tout est descendu dans
   compromis_expire_resoudre, qui sert les DEUX familles : ce fichier ne doit plus emettre aucune
   ecriture sur terrains_etat, entreprises, prets, personnages ni compromis_historique, et ne doit
   plus tirer au sort. Les compteurs rendus restent les memes qu'avant.

   IL PROUVE AUSSI que le cas Helvetia continue d'etre delegue a SA RPC, et qu'un verdict absent
   n'est jamais compte comme une resolution.

   CONTRE-EPREUVE. Joue contre la version precedente de api/cron-minuit.js, il ECHOUE :
     git show HEAD:api/cron-minuit.js > /tmp/avant.js
     python3 outils/bancs/lancer-banc.py outils/bancs/banc-compromis-nocturnes.js \
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

var APPELS = [], VERDICT = null, VERDICT_HTTP_OK = true, TERRAINS = [], ENTREPRISES = [];

function estRpcPorte(a) { return a.url.indexOf('/rpc/compromis_expire_resoudre') !== -1; }
function estRpcHelvetia(a) { return a.url.indexOf('/rpc/resoudre_compromis_helvetia_expire') !== -1; }

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
    if (!VERDICT_HTTP_OK) return reponse(false, { message: 'panne simulee' }, 500);
    return reponse(true, VERDICT);
  }
  if (estRpcHelvetia(appel)) return reponse(true, 'rembourse');
  if (appel.methode === 'GET' && appel.url.indexOf('terrains_etat') !== -1) return reponse(true, TERRAINS);
  if (appel.methode === 'GET' && appel.url.indexOf('entreprises') !== -1) return reponse(true, ENTREPRISES);
  // LE DECOR REPOND AUSSI A L'ANCIEN CHEMIN : sans personnage credible, la version precedente
  // n'ecrirait rien et l'epreuve « aucune ecriture directe » ne prouverait rien.
  if (appel.methode === 'GET' && appel.url.indexOf('personnages') !== -1) {
    return reponse(true, [{ name: 'Ben', country: 'republic', arg: 5000 }]);
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

var ECHU = Date.now() - 1000;
function terrainEchu(proprietaire) {
  return [{ id: 'zzb-terrain', country: 'republic', building_id: 'zzb-bat',
    data: JSON.stringify({ compromis: true, compromisPar: 'Ben', acompte: 500,
      compromisExpireAt: ECHU, proprietaire: proprietaire || 'Ben',
      permis: { statut: 'refuse' },
      pretDemande: { statut: 'attente_validation', demandeur: 'Ben', montant: 1000,
                     montantTotal: 1200, duree: 30, mensualite: 40 } }) }];
}
function entrepriseEchue() {
  return [{ id: 'zzb-republic-capitale', data: { compromis: true, compromisPar: 'Ben',
    acompte: 300, compromisExpireAt: ECHU,
    pretDemande: { statut: 'attente_validation', demandeur: 'Ben', montant: 800,
                   montantTotal: 900, duree: 20, mensualite: 45 } } }];
}

function ecrituresDirectes() {
  return APPELS.filter(function (a) {
    return a.methode !== 'GET' && !estRpcPorte(a) && !estRpcHelvetia(a)
        && (a.url.indexOf('terrains_etat') !== -1 || a.url.indexOf('entreprises') !== -1
            || a.url.indexOf('/prets') !== -1 || a.url.indexOf('personnages') !== -1
            || a.url.indexOf('compromis_historique') !== -1);
  });
}
function appelsPorte() { return APPELS.filter(estRpcPorte); }

function rejouerTerrains(verdict, httpOk, proprietaire) {
  APPELS = []; VERDICT = verdict; VERDICT_HTTP_OK = httpOk !== false;
  TERRAINS = terrainEchu(proprietaire); ENTREPRISES = [];
  return sync(resoudreCompromisExpires());
}
function rejouerEntreprises(verdict, httpOk) {
  APPELS = []; VERDICT = verdict; VERDICT_HTTP_OK = httpOk !== false;
  TERRAINS = []; ENTREPRISES = entrepriseEchue();
  return sync(resoudreCompromisEntreprisesExpires());
}

print('');
print('BANC DES COMPROMIS NOCTURNES');
print('============================================================================');

print('1. TERRAIN — UNE SEULE PORTE, AUCUNE ECRITURE DIRECTE, AUCUN TIRAGE');
var r = rejouerTerrains([{ ok: true, action: 'rembourse', acompte: 500 }]);
verifier('la porte est appelee une fois', appelsPorte().length, 1);
verifier('aucune ecriture directe', ecrituresDirectes().length, 0);
vrai('le type transmis est « terrain »', appelsPorte().length === 1
     && appelsPorte()[0].corps.p_type === 'terrain', JSON.stringify(appelsPorte()[0] && appelsPorte()[0].corps));
vrai('la cible est l identifiant du bien', appelsPorte().length === 1
     && appelsPorte()[0].corps.p_cible === 'zzb-terrain');
verifier('un remboursement est compte', r.rembourses, 1);
verifier('et compte comme resolu', r.resolus, 1);
verifier('aucun acompte perdu', r.perdus, 0);

print('');
print('2. CHAQUE VERDICT EST COMPTE A SA PLACE');
r = rejouerTerrains([{ ok: true, action: 'perdu', acompte: 500 }]);
verifier('acompte perdu compte', r.perdus, 1);
verifier('et compte comme resolu', r.resolus, 1);
r = rejouerTerrains([{ ok: true, action: 'pret_en_attente_finalisation' }]);
verifier('pret accorde a l instant : compromis gele', r.pretsEnAttenteFinalisation, 1);
verifier('et PAS compte comme resolu', r.resolus, 0);
r = rejouerTerrains([{ ok: true, action: 'pret_accorde_compromis_gele' }]);
verifier('pret deja accorde : rien compte', r.resolus + r.rembourses + r.perdus + r.pretsEnAttenteFinalisation, 0);
verifier('et aucune ecriture directe', ecrituresDirectes().length, 0);

print('');
print('3. LE CAS HELVETIA GARDE SA PROPRE RPC');
r = rejouerTerrains([{ ok: true, action: 'rembourse' }], true, 'Helvetia');
verifier('la porte generique n est PAS appelee', appelsPorte().length, 0);
verifier('la RPC Helvetia est appelee', APPELS.filter(estRpcHelvetia).length, 1);
verifier('et comptee comme deleguee', r.helvetiaDelegues, 1);
verifier('aucune ecriture directe', ecrituresDirectes().length, 0);

print('');
print('4. AUCUN VERDICT N EST JAMAIS UNE RESOLUTION');
r = rejouerTerrains(null, false);
verifier('panne : rien compte', r.resolus + r.rembourses + r.perdus + r.pretsEnAttenteFinalisation, 0);
verifier('panne : aucune ecriture directe', ecrituresDirectes().length, 0);
r = rejouerTerrains([]);
verifier('reponse vide : rien compte', r.resolus + r.rembourses + r.perdus, 0);
r = rejouerTerrains([{ ok: false, action: 'non_applicable' }]);
verifier('refus « non_applicable » : rien compte', r.resolus, 0);
r = rejouerTerrains([{ ok: true }]);
verifier('verdict ok sans action : rien compte', r.resolus + r.rembourses + r.perdus, 0);

print('');
print('5. ENTREPRISE — MEME PORTE, MEME ABSENCE D ECRITURE');
r = rejouerEntreprises([{ ok: true, action: 'perdu', acompte: 300 }]);
verifier('la porte est appelee une fois', appelsPorte().length, 1);
vrai('le type transmis est « entreprise »', appelsPorte().length === 1
     && appelsPorte()[0].corps.p_type === 'entreprise');
vrai('la cible est l identifiant de l entreprise', appelsPorte().length === 1
     && appelsPorte()[0].corps.p_cible === 'zzb-republic-capitale');
verifier('aucune ecriture directe', ecrituresDirectes().length, 0);
verifier('acompte perdu compte', r.perdus, 1);
verifier('et compte comme resolu', r.resolus, 1);

r = rejouerEntreprises([{ ok: true, action: 'pret_en_attente_finalisation' }]);
verifier('pret accorde : compromis gele compte', r.pretsEnAttenteFinalisation, 1);
verifier('et aucune ecriture directe', ecrituresDirectes().length, 0);

r = rejouerEntreprises(null, false);
verifier('panne : rien compte', r.resolus + r.rembourses + r.perdus + r.pretsEnAttenteFinalisation, 0);
verifier('panne : aucune ecriture directe', ecrituresDirectes().length, 0);

print('');
print('6. UN COMPROMIS NON ECHU N EST PAS PRESENTE A LA PORTE');
APPELS = []; VERDICT = [{ ok: true, action: 'perdu' }]; VERDICT_HTTP_OK = true;
TERRAINS = terrainEchu(); ENTREPRISES = [];
var futur = JSON.parse(TERRAINS[0].data); futur.compromisExpireAt = Date.now() + 86400000;
TERRAINS[0].data = JSON.stringify(futur);
r = sync(resoudreCompromisExpires());
verifier('la porte n est pas appelee', appelsPorte().length, 0);
verifier('rien compte', r.resolus, 0);

print('');
print('============================================================================');
if (echecs === 0) print('LES ' + total + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + echecs + ' epreuve(s) sur ' + total);
