/* ===========================================================================
   BANC DE traiterCandidaturesPostesExpirees — api/cron-minuit.js
   SOURCES: outils/bancs/decor-env-serveur.js api/_referentiels-generes.js api/cron-minuit.js
   Chantier 6, 9 octobre 2026
   ===========================================================================

   CE QU'IL PROUVE. Cette passe tirait le gagnant en JavaScript
   -- candidatsEligibles[Math.floor(Math.random() * ...)] -- puis appliquait la decision en SIX
   ecritures independantes, toutes avalees : titulaire PNJ retire, registre postes_attribues,
   fiche du gagnant, courrier au gagnant, POP du nominateur divisee par deux, courrier au
   nominateur. Et le drapeau `traitee` du dossier n'etait ecrit qu'APRES la boucle entiere : une
   coupure perdait TOUS les drapeaux de la passe, et la nuit suivante retirait au sort une
   seconde fois -- autre gagnant possible, POP redivisee, deux courriers de plus.

   LA PREUVE QUI COMPTE EST L'ABSENCE DE TIRAGE ET D'ECRITURE DIRECTE. Tout est descendu dans
   candidature_poste_tirage_appliquer : ce fichier ne doit plus emettre AUCUNE ecriture sur
   postes_attribues, titulaires_pnj, personnages ni mails pour ce mecanisme, et ne doit plus
   choisir personne. Les compteurs rendus, eux, sont les memes qu'avant -- un banc qui les lirait
   seuls ne verrait aucune difference.

   IL PROUVE AUSSI que chaque verdict est consomme, que le drapeau est persiste dossier par
   dossier, et qu'un echec de transport ne pose NI drapeau NI sanction : la nuit suivante retente.

   CONTRE-EPREUVE. Joue contre la version precedente de api/cron-minuit.js, il ECHOUE :
     git show HEAD:api/cron-minuit.js > /tmp/avant.js
     python3 outils/bancs/lancer-banc.py outils/bancs/banc-candidatures-nocturnes.js \
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
  } else print('  OK  ' + libelle);
}

function vrai(libelle, condition, detail) {
  total++;
  if (condition) print('  OK  ' + libelle);
  else { echecs++; print('  NON ' + libelle); if (detail !== undefined) print('        ' + detail); }
}

var APPELS = [], VERDICT = null, VERDICT_HTTP_OK = true, ETAT = null;

function estRpcTirage(a) {
  return a.url.indexOf('/rpc/candidature_poste_tirage_appliquer') !== -1;
}

globalThis.fetch = function (url, options) {
  var o = options || {};
  var appel = { methode: o.method || 'GET', url: String(url),
                corps: o.body ? JSON.parse(o.body) : null, entetes: o.headers || {} };
  APPELS.push(appel);
  function reponse(ok, donnees, statut) {
    return Promise.resolve({ ok: ok, status: statut || (ok ? 200 : 500),
      json: function () { return Promise.resolve(donnees); },
      text: function () { return Promise.resolve(JSON.stringify(donnees)); } });
  }

  if (estRpcTirage(appel)) {
    if (!VERDICT_HTTP_OK) return reponse(false, { message: 'panne simulee' }, 500);
    return reponse(true, VERDICT);
  }
  // L'etat du batiment national qui porte les dossiers de candidature.
  if (appel.url.indexOf('batiments_etat') !== -1) {
    // `batiments_etat.data` est une CHAINE JSON, pas un objet : sbGetBatimentEtat fait un
    // JSON.parse. Rendre un objet ici ferait silencieusement rendre {} -- et le banc n'aurait
    // jamais trouve de dossier a traiter.
    if (appel.methode === 'GET') return reponse(true, [{ id: 'republic_national_candidatures_postes', data: JSON.stringify(ETAT) }]);
    return reponse(true, [{}]);
  }
  // LE DECOR REPOND AUSSI A L'ANCIEN CHEMIN. Sans personnages ni titulaires_pnj credibles, la
  // version precedente sortirait par `continue` avant d'ecrire, et l'epreuve « aucune ecriture
  // directe » passerait aussi sur le code fautif -- donc ne prouverait rien.
  if (appel.methode === 'GET' && appel.url.indexOf('personnages') !== -1) {
    var m = /name=eq\.([^&]+)/.exec(appel.url);
    if (m) {
      // Fiche nommee : le filtre d'eligibilite, ou la lecture de la POP du nominateur.
      var nom = decodeURIComponent(m[1]);
      if (nom === 'Arnie') {
        return reponse(true, [{ name: 'Arnie', country: 'republic',
                                poste: { id: 'min_just', city: null }, resources: { pop: 9 } }]);
      }
      return reponse(true, [{ name: nom, country: 'republic', poste: null, resources: { pop: 30 } }]);
    }
    // Balayage : resoudreTitulaireActuelPosteServeur. Personne ne tient « juge » a la capitale,
    // et min_just est a Arnie -- c'est donc lui l'autorite de nomination restee passive.
    return reponse(true, [{ name: 'Arnie', country: 'republic', poste: { id: 'min_just', city: null } }]);
  }
  if (appel.methode === 'GET' && appel.url.indexOf('titulaires_pnj') !== -1) {
    return reponse(true, [{ id: 'republic_juge_capitale', nom_pnj: 'Juge PNJ' }]);
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

function dossierExpire() {
  return { candidatures: { 'juge|capitale': {
    posteId: 'juge', city: 'capitale', autoriteNom: 'Arnie',
    echeanceTs: Date.now() - 1000,
    candidats: [{ nom: 'Ben' }, { nom: 'Lee Capene' }, { nom: 'Parti', retiree: true }]
  } } };
}

function rejouer(verdict, httpOk, etat) {
  APPELS = []; VERDICT = verdict; VERDICT_HTTP_OK = httpOk !== false;
  ETAT = etat || dossierExpire();
  return sync(traiterCandidaturesPostesExpirees());
}

function ecrituresDirectes() {
  return APPELS.filter(function (a) {
    return a.methode !== 'GET' && !estRpcTirage(a)
        && (a.url.indexOf('postes_attribues') !== -1 || a.url.indexOf('titulaires_pnj') !== -1
            || a.url.indexOf('/mails') !== -1
            || (a.url.indexOf('personnages') !== -1 && a.url.indexOf('batiments_etat') === -1));
  });
}
function ecrituresEtat() {
  return APPELS.filter(function (a) { return a.methode !== 'GET' && a.url.indexOf('batiments_etat') !== -1; });
}
function appelsTirage() { return APPELS.filter(estRpcTirage); }
function etatEcrit(i) { return JSON.parse(ecrituresEtat()[i].corps.data); }

print('');
print('BANC DES CANDIDATURES NOCTURNES');
print('============================================================================');

// 1. LA NOMINATION PASSE PAR LA PORTE, ET PAR ELLE SEULE.
var r = rejouer([{ ok: true, gagnant: 'Ben', sanction: true, pop_avant: 9, pop_apres: 4 }]);
verifier('la porte du tirage est appelee une fois', appelsTirage().length, 1);
verifier('aucune ecriture directe sur le registre, les PNJ, les fiches ou les mails',
         ecrituresDirectes().length, 0);
verifier('une nomination automatique est comptee', r.nominationsAuto, 1);
verifier('la sanction du nominateur est comptee', r.sanctions, 1);
verifier('le dossier est compte comme traite', r.traitees, 1);

// La porte n'a peut-etre pas ete appelee du tout (c'est le cas sur le code d'avant ce lot, et
// c'est ce que la contre-epreuve veut voir) : on ne doit pas lever ici, sinon la contre-epreuve
// s'arrete avant d'avoir montre TOUTES les epreuves qui tombent.
var c = appelsTirage().length ? appelsTirage()[0].corps : {};
vrai('le pays est transmis explicitement', c.p_pays === 'republic', JSON.stringify(c));
vrai('le poste et la ville viennent du dossier', c.p_poste_id === 'juge' && c.p_city === 'capitale');
vrai('le libelle vient du referentiel', c.p_label === 'Juge');
vrai("l'autorite resolue est transmise", c.p_autorite === 'Arnie');
vrai('les candidats eligibles sont une LISTE, pas un gagnant deja choisi',
     Array.isArray(c.p_candidats) && c.p_candidats.length === 2
     && c.p_candidats.indexOf('Ben') >= 0 && c.p_candidats.indexOf('Lee Capene') >= 0,
     JSON.stringify(c.p_candidats));
vrai('le candidat retire du dossier n est pas presente au tirage',
     Array.isArray(c.p_candidats) && c.p_candidats.indexOf('Parti') < 0);
vrai('le drapeau du dossier est persiste', ecrituresEtat().length >= 1);
vrai('et le dossier persiste porte bien traitee',
     ecrituresEtat().length >= 1 && etatEcrit(0).candidatures['juge|capitale'].traitee === true);

// 2. PLUS AUCUN CANDIDAT ELIGIBLE SELON LE SERVEUR : rien a nommer, pas de sanction.
r = rejouer([{ ok: true, gagnant: null, raison: 'aucun_candidat_eligible' }]);
verifier('aucune nomination', r.nominationsAuto, 0);
verifier('aucune sanction', r.sanctions, 0);
vrai('le dossier est quand meme clos', ecrituresEtat().length >= 1
     && etatEcrit(0).candidatures['juge|capitale'].traitee === true);

// 3. LE POSTE A ETE POURVU ENTRE-TEMPS : annulation sans sanction.
r = rejouer([{ ok: false, raison: 'poste_deja_attribue', titulaire: 'Lee Capene' }]);
verifier('comptee comme annulee sans sanction', r.annuleesSansSanction, 1);
verifier('aucune nomination', r.nominationsAuto, 0);
verifier('aucune sanction', r.sanctions, 0);

// 4. LE REJEU DANS LA MEME NUIT : la porte referme la journee, le drapeau est repose.
r = rejouer([{ ok: false, raison: 'deja_traite_aujourdhui' }]);
verifier('aucune seconde nomination', r.nominationsAuto, 0);
verifier('aucune seconde sanction', r.sanctions, 0);
vrai('le drapeau perdu est repose', ecrituresEtat().length >= 1
     && etatEcrit(0).candidatures['juge|capitale'].traitee === true);

// 5. UNE PANNE NE POSE NI DRAPEAU NI SANCTION : la nuit suivante retente.
r = rejouer(null, false);
verifier('aucune nomination sur panne', r.nominationsAuto, 0);
verifier('aucune sanction sur panne', r.sanctions, 0);
verifier('aucune annulation sur panne', r.annuleesSansSanction, 0);
vrai('AUCUN drapeau traitee n est pose', ecrituresEtat().every(function (a) {
  var d = JSON.parse(a.corps.data).candidatures['juge|capitale'];
  return !d || d.traitee !== true;
}), JSON.stringify(ecrituresEtat().map(function (a) { return a.corps.data; })));
verifier('et aucune ecriture directe n a ete tentee', ecrituresDirectes().length, 0);

// 6. UNE REPONSE VIDE N EST PAS UN SUCCES.
r = rejouer([]);
verifier('reponse vide : aucune nomination', r.nominationsAuto, 0);
vrai('reponse vide : aucun drapeau pose', ecrituresEtat().every(function (a) {
  var d = JSON.parse(a.corps.data).candidatures['juge|capitale'];
  return !d || d.traitee !== true;
}));

// 7. UN DOSSIER NON ECHU N EST PAS TOUCHE.
var futur = dossierExpire();
futur.candidatures['juge|capitale'].echeanceTs = Date.now() + 86400000;
r = rejouer([{ ok: true, gagnant: 'Ben' }], true, futur);
verifier('la porte n est pas appelee avant l echeance', appelsTirage().length, 0);
verifier('aucune nomination', r.nominationsAuto, 0);

// 8. UN DOSSIER DEJA TRAITE N EST PAS REJOUE.
var deja = dossierExpire();
deja.candidatures['juge|capitale'].traitee = true;
r = rejouer([{ ok: true, gagnant: 'Ben' }], true, deja);
verifier('la porte n est pas appelee pour un dossier deja traite', appelsTirage().length, 0);

print('');
print('============================================================================');
if (echecs === 0) print('LES ' + total + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + echecs + ' epreuve(s) sur ' + total);
