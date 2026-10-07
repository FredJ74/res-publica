/* ===========================================================================
   BANC — TRANSPORT DES RPC ET RENOUVELLEMENT DE SESSION
   28 septembre 2026. Reproduit, hors navigateur, le defaut constate en
   production : jeton expire, renouvellement non abouti, requete d'ecriture
   repartie sous la cle anon, 401 aplati sur null, message « rien n'a ete
   modifie ». Verifie que ce chemin est ferme et que les quatre etats du
   transport sont distincts.

   Execution :
     jsc .scratch/banc_transport_session.js
   Aucun reseau, aucune base : fetch et localStorage sont simules.
   =========================================================================== */

// --- simulacres de plateforme ----------------------------------------------
var _stock = {};
var localStorage = {
  getItem: function (k) { return Object.prototype.hasOwnProperty.call(_stock, k) ? _stock[k] : null; },
  setItem: function (k, v) { _stock[k] = String(v); },
  removeItem: function (k) { delete _stock[k]; }
};

// Journal des requetes reellement emises : c'est LUI qui prouve qu'une action
// sans identite ne part pas, et sous quel porteur partent les autres.
var REQUETES = [];
var _programme = null;   // (url, opts) -> reponse simulee, ou jette pour un echec reseau

var fetch = function (url, opts) {
  REQUETES.push({ url: String(url), entetes: (opts && opts.headers) || {}, corps: (opts && opts.body) || null });
  return Promise.resolve().then(function () { return _programme(String(url), opts || {}); });
};

function reponse(status, corps) {
  var texte = (typeof corps === 'string') ? corps : JSON.stringify(corps);
  return {
    ok: status >= 200 && status < 300,
    status: status,
    text: function () { return Promise.resolve(texte); },
    json: function () { return Promise.resolve(JSON.parse(texte)); }
  };
}

// On garde la console silencieuse : les modules journalisent volontairement
// beaucoup, et ce bruit masquerait le rapport.
var _erreurs = [];
var console = { error: function () { _erreurs.push(Array.prototype.join.call(arguments, ' ')); },
                warn: function () {}, log: function () {} };

load('supabase.js');
load('auth.js');

// --- outillage du banc ------------------------------------------------------
var CAS = [];
function cas(nom, attendu, obtenu, ok) { CAS.push({ nom: nom, attendu: attendu, obtenu: obtenu, ok: ok }); }

function reinitialiser() {
  REQUETES = []; _erreurs = []; _stock = {};
  RP_AUTH_SESSION = null; RP_AUTH_PROMESSE = null; RP_AUTH_ETAT = null; RP_AUTH_INDISPONIBLE = false;
}

function session(jeton, dansMs, refresh) {
  return { access_token: jeton, refresh_token: (refresh === undefined ? 'refresh-valide' : refresh),
           expire_le: Date.now() + dansMs, user: { id: 'uid-arnie', email: null, est_anonyme: true } };
}

function porteur(req) {
  var a = (req && req.entetes && req.entetes.Authorization) || '';
  return a.replace('Bearer ', '');
}
function requetesRpc() { return REQUETES.filter(function (r) { return r.url.indexOf('/rest/v1/rpc/') >= 0; }); }
function requetesAuth() { return REQUETES.filter(function (r) { return r.url.indexOf('/auth/v1/') >= 0; }); }

// Le renouvellement rend un jeton neuf ; l'ecriture metier accepte.
function programmeNormal(nouveauJeton) {
  return function (url, opts) {
    if (url.indexOf('/auth/v1/token') >= 0) {
      return reponse(200, { access_token: nouveauJeton, refresh_token: 'refresh-2',
                            expires_in: 3600, user: { id: 'uid-arnie', is_anonymous: true } });
    }
    if (url.indexOf('/rest/v1/rpc/') >= 0) return reponse(200, { ok: true, referenceId: 'ref-banc' });
    return reponse(404, { message: 'hors banc' });
  };
}

async function executer() {

  // ---------------------------------------------------------------- CAS 1
  // Jeton valide : l'ecriture part, et elle part sous le JETON DU JOUEUR.
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-valide', 30 * 60 * 1000);
  _programme = programmeNormal('jwt-neuf');
  var v1 = await sbRpcVerdict('fonds_reference_creer', { p_acteur: 'Arnie' });
  cas('1. jeton valide : ecriture emise sous le jeton joueur',
      'emise, porteur = jwt-valide, ok:true',
      requetesRpc().length + ' emise(s), porteur = ' + porteur(requetesRpc()[0]) + ', ok:' + (v1 && v1.ok),
      requetesRpc().length === 1 && porteur(requetesRpc()[0]) === 'jwt-valide' && v1 && v1.ok === true);
  cas('1b. aucun renouvellement inutile', '0 appel /auth', requetesAuth().length + ' appel(s)',
      requetesAuth().length === 0);

  // ---------------------------------------------------------------- CAS 2
  // Jeton DANS la marge d'expiration (30 s restantes, marge 60 s) : il doit
  // etre renouvele AVANT l'appel, et l'ecriture partir sous le jeton neuf.
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-presque-perime', 30 * 1000);
  rpAuthEcrireStockage(RP_AUTH_SESSION);
  _programme = programmeNormal('jwt-renouvele');
  var v2 = await sbRpcVerdict('fonds_reference_creer', { p_acteur: 'Arnie' });
  cas('2. jeton proche expiration : renouvelle puis action poursuivie',
      'renouvellement + porteur = jwt-renouvele + ok:true',
      requetesAuth().length + ' renouv., porteur = ' + porteur(requetesRpc()[0]) + ', ok:' + (v2 && v2.ok),
      requetesAuth().length === 1 && porteur(requetesRpc()[0]) === 'jwt-renouvele' && v2 && v2.ok === true);

  // ---------------------------------------------------------------- CAS 3
  // Jeton franchement expire, renouvellement possible : idem.
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-perime', -5 * 60 * 1000);
  rpAuthEcrireStockage(RP_AUTH_SESSION);
  _programme = programmeNormal('jwt-apres-expiration');
  var v3 = await sbRpcVerdict('fonds_reference_creer', { p_acteur: 'Arnie' });
  cas('3. jeton expire + renouvellement possible : action poursuivie',
      'porteur = jwt-apres-expiration, ok:true',
      'porteur = ' + porteur(requetesRpc()[0]) + ', ok:' + (v3 && v3.ok),
      porteur(requetesRpc()[0]) === 'jwt-apres-expiration' && v3 && v3.ok === true);

  // ---------------------------------------------------------------- CAS 4
  // Renouvellement REFUSE definitivement (400). C'est le cas du 28 septembre.
  // L'ecriture ne doit PAS partir, et surtout pas sous la cle anon.
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-perime', -5 * 60 * 1000);
  rpAuthEcrireStockage(RP_AUTH_SESSION);
  _stock['respublica_auth_identite'] = JSON.stringify({ email: 'arnie@example.test' });
  _programme = function (url) {
    if (url.indexOf('/auth/v1/token') >= 0) return reponse(400, { error: 'invalid_grant' });
    return reponse(200, { ok: true });
  };
  var v4 = await sbRpcVerdict('fonds_reference_creer', { p_acteur: 'Arnie' });
  cas('4. renouvellement impossible : ECRITURE NON EMISE',
      '0 requete RPC', requetesRpc().length + ' requete(s) RPC', requetesRpc().length === 0);
  cas('4b. motif rendu au joueur', 'session_perdue', (v4 && v4.raison), v4 && v4.raison === 'session_perdue');
  cas('4c. aucune requete sous la cle anon', 'aucune',
      requetesRpc().filter(function (r) { return porteur(r) === SUPABASE_ANON; }).length + ' constatee(s)',
      requetesRpc().filter(function (r) { return porteur(r) === SUPABASE_ANON; }).length === 0);

  // ---------------------------------------------------------------- CAS 5
  // Aucun refresh token en reserve.
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-perime', -60 * 1000, null);
  rpAuthEcrireStockage(RP_AUTH_SESSION);
  _stock['respublica_auth_identite'] = JSON.stringify({ email: 'arnie@example.test' });
  _programme = function () { return reponse(200, { ok: true }); };
  var v5 = await sbRpcVerdict('fonds_reference_creer', { p_acteur: 'Arnie' });
  cas('5. pas de refresh token : ecriture non emise, session_perdue',
      '0 RPC + session_perdue',
      requetesRpc().length + ' RPC + ' + (v5 && v5.raison),
      requetesRpc().length === 0 && v5 && v5.raison === 'session_perdue');

  // ---------------------------------------------------------------- CAS 6
  // Coupure reseau PENDANT le renouvellement : echec passager. La session ne
  // doit pas etre jetee (sinon le joueur perd son personnage sur une coupure).
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-perime', -60 * 1000);
  rpAuthEcrireStockage(RP_AUTH_SESSION);
  _programme = function (url) {
    if (url.indexOf('/auth/v1/token') >= 0) throw new Error('reseau coupe');
    return reponse(200, { ok: true });
  };
  var v6 = await sbRpcVerdict('fonds_reference_creer', { p_acteur: 'Arnie' });
  cas('6. reseau coupe pendant le renouvellement : ecriture non emise',
      '0 RPC + session_perdue',
      requetesRpc().length + ' RPC + ' + (v6 && v6.raison),
      requetesRpc().length === 0 && v6 && v6.raison === 'session_perdue');
  cas('6b. le refresh token est CONSERVE', 'conserve',
      (rpAuthLireStockage() && rpAuthLireStockage().refresh_token) ? 'conserve' : 'perdu',
      !!(rpAuthLireStockage() && rpAuthLireStockage().refresh_token));

  // ---------------------------------------------------------------- CAS 7
  // Lecture REELLEMENT publique, sans aucune session : elle doit continuer a
  // fonctionner, sous la cle anon, exactement comme avant.
  reinitialiser();
  _programme = function (url) {
    if (url.indexOf('/auth/v1/') >= 0) return reponse(400, { error: 'pas de session dans ce cas' });
    return reponse(200, [{ generique_id: 'souvenir' }]);
  };
  var v7 = await sbRpc('fonds_generiques_accessibles', { p_fonds_id: 'fonds-x' });
  cas('7. lecture publique sans session : emise sous la cle anon et servie',
      '1 RPC, porteur = cle anon, donnees recues',
      requetesRpc().length + ' RPC, porteur anon = ' + (porteur(requetesRpc()[0]) === SUPABASE_ANON)
        + ', donnees = ' + (Array.isArray(v7) ? v7.length : 'null'),
      requetesRpc().length === 1 && porteur(requetesRpc()[0]) === SUPABASE_ANON
        && Array.isArray(v7) && v7.length === 1);

  // ---------------------------------------------------------------- CAS 8
  // Ecriture authentifiee sans aucun jeton et sans identite memorisee : meme
  // si l'ouverture anonyme echoue, rien ne doit partir.
  reinitialiser();
  _programme = function (url) {
    if (url.indexOf('/auth/v1/') >= 0) return reponse(500, { error: 'auth en panne' });
    return reponse(200, { ok: true });
  };
  var v8 = await sbRpcVerdict('fonds_reference_produire', { p_acteur: 'Arnie' });
  cas('8. ecriture authentifiee sans jeton : rien n\'est emis',
      '0 RPC + session_perdue',
      requetesRpc().length + ' RPC + ' + (v8 && v8.raison),
      requetesRpc().length === 0 && v8 && v8.raison === 'session_perdue');

  // ---------------------------------------------------------------- CAS 9
  // Ouverture de session reussie a froid puis ecriture : le parcours normal
  // d'un joueur qui arrive sans session exploitable.
  reinitialiser();
  _programme = function (url) {
    if (url.indexOf('/auth/v1/signup') >= 0 || url.indexOf('/auth/v1/token') >= 0) {
      return reponse(200, { access_token: 'jwt-frais', refresh_token: 'r', expires_in: 3600,
                            user: { id: 'uid-neuf', is_anonymous: true } });
    }
    return reponse(200, { ok: true, referenceId: 'ref-banc' });
  };
  var v9 = await sbRpcVerdict('fonds_reference_creer', { p_acteur: 'Arnie' });
  cas('9. ecriture apres ouverture de session : emise sous le jeton neuf',
      'porteur = jwt-frais + ok:true',
      'porteur = ' + (requetesRpc()[0] ? porteur(requetesRpc()[0]) : 'aucune') + ' + ok:' + (v9 && v9.ok),
      requetesRpc().length === 1 && porteur(requetesRpc()[0]) === 'jwt-frais' && v9 && v9.ok === true);

  // --------------------------------------------------------------- CAS 10
  // 401 rendu par le serveur alors qu'un jeton existait : c'est l'identite que
  // le serveur refuse, pas la regle du jeu.
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-valide', 30 * 60 * 1000);
  _programme = function () { return reponse(401, { code: '42501', message: 'permission denied for function fonds_reference_creer' }); };
  var v10 = await sbRpcVerdict('fonds_reference_creer', { p_acteur: 'Arnie' });
  cas('10. 401 du serveur : session_perdue, http et code conserves',
      'session_perdue / 401 / 42501',
      (v10 && v10.raison) + ' / ' + (v10 && v10.transport && v10.transport.http) + ' / ' + (v10 && v10.transport && v10.transport.code),
      v10 && v10.raison === 'session_perdue' && v10.transport.http === 401 && v10.transport.code === '42501');

  // --------------------------------------------------------------- CAS 11
  // 500 : panne de service, distincte d'une session perdue.
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-valide', 30 * 60 * 1000);
  _programme = function () { return reponse(500, { message: 'boom' }); };
  var v11 = await sbRpcVerdict('fonds_reference_creer', {});
  cas('11. 500 : transport_indisponible (et non session_perdue)',
      'transport_indisponible / 500',
      (v11 && v11.raison) + ' / ' + (v11 && v11.transport && v11.transport.http),
      v11 && v11.raison === 'transport_indisponible' && v11.transport.http === 500);

  // --------------------------------------------------------------- CAS 12
  // Rejet de fetch : coupure reseau sur l'appel metier lui-meme.
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-valide', 30 * 60 * 1000);
  _programme = function () { throw new Error('hors ligne'); };
  var v12 = await sbRpcVerdict('fonds_reference_creer', {});
  cas('12. fetch rejete : reseau_indisponible',
      'reseau_indisponible', (v12 && v12.raison), v12 && v12.raison === 'reseau_indisponible');

  // --------------------------------------------------------------- CAS 13
  // REFUS METIER : il doit traverser intact, sans etre confondu avec une panne.
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-valide', 30 * 60 * 1000);
  _programme = function () { return reponse(200, { ok: false, raison: 'generique_hors_perimetre' }); };
  var v13 = await sbRpcVerdict('fonds_reference_creer', {});
  cas('13. refus metier transmis tel quel, sans champ transport',
      'ok:false / generique_hors_perimetre / pas de transport',
      'ok:' + (v13 && v13.ok) + ' / ' + (v13 && v13.raison) + ' / transport = ' + (v13 && v13.transport ? 'present' : 'absent'),
      v13 && v13.ok === false && v13.raison === 'generique_hors_perimetre' && !v13.transport);

  // --------------------------------------------------------------- CAS 14
  // COMPATIBILITE HISTORIQUE : sbRpc doit toujours rendre null sur echec, sinon
  // les ~300 `if (!r)` du jeu changeraient de sens en silence.
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-valide', 30 * 60 * 1000);
  _programme = function () { return reponse(500, { message: 'boom' }); };
  var c1 = await sbRpc('fonds_reference_creer', {});
  reinitialiser();
  _programme = function (url) {
    if (url.indexOf('/auth/v1/') >= 0) return reponse(500, {});
    return reponse(200, { ok: true });
  };
  var c2 = await sbRpc('fonds_reference_creer', {});
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-valide', 30 * 60 * 1000);
  _programme = function () { throw new Error('hors ligne'); };
  var c3 = await sbRpc('fonds_reference_creer', {});
  cas('14. sbRpc rend TOUJOURS null sur echec (http, session, reseau)',
      'null / null / null',
      c1 + ' / ' + c2 + ' / ' + c3,
      c1 === null && c2 === null && c3 === null);

  // --------------------------------------------------------------- CAS 15
  // sbRpc rend le corps analyse sur succes : contrat inchange.
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-valide', 30 * 60 * 1000);
  _programme = function () { return reponse(200, [{ ok: true, n: 7 }]); };
  var c4 = await sbRpc('fonds_reference_creer', {});
  cas('15. sbRpc rend le corps analyse sur succes',
      'tableau de 1, n = 7',
      (Array.isArray(c4) ? ('tableau de ' + c4.length + ', n = ' + c4[0].n) : String(c4)),
      Array.isArray(c4) && c4.length === 1 && c4[0].n === 7);

  // --------------------------------------------------------------- CAS 16
  // REJEU DU PARCOURS REEL DU 28 SEPTEMBRE, avec les identifiants exacts du
  // commerce d'Arnie. Aucun reseau : fetch est simule, donc rien n'est ecrit
  // ni dans sa boutique ni en base. On verifie le CORPS reellement emis.
  var PARCOURS = {
    acteur: 'Arnie',
    fonds: 'fonds-republic-1790594742432-237945',
    generique: 'souvenir',
    recette: 'porte_cle_palais_luthecia',
    nom: 'Porte-cle du Palais presidentiel'
  };
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-arnie', 30 * 60 * 1000);
  _programme = function () { return reponse(200, { ok: true, referenceId: 'ref-simule' }); };
  var v16 = await sbFondsReferenceCreer(PARCOURS.acteur, PARCOURS.fonds, PARCOURS.generique,
                                        PARCOURS.recette, PARCOURS.nom, 'Un souvenir de Luthecia.');
  var corps = JSON.parse(requetesRpc()[0].corps);
  var cles = Object.keys(corps).sort().join(',');
  cas('16. rejeu du parcours reel : 6 parametres exacts, sous le jeton joueur',
      'p_acteur,p_description,p_fonds_id,p_generique_id,p_nom,p_recette_id',
      cles,
      cles === 'p_acteur,p_description,p_fonds_id,p_generique_id,p_nom,p_recette_id');
  cas('16b. valeurs transmises intactes',
      PARCOURS.generique + ' / ' + PARCOURS.recette + ' / ' + PARCOURS.fonds,
      corps.p_generique_id + ' / ' + corps.p_recette_id + ' / ' + corps.p_fonds_id,
      corps.p_generique_id === PARCOURS.generique && corps.p_recette_id === PARCOURS.recette
        && corps.p_fonds_id === PARCOURS.fonds && corps.p_acteur === PARCOURS.acteur);
  cas('16c. porteur = jeton joueur (jamais la cle anon)',
      'jwt-arnie', porteur(requetesRpc()[0]), porteur(requetesRpc()[0]) === 'jwt-arnie');
  cas('16d. verdict metier remonte', 'ok:true', 'ok:' + (v16 && v16.ok), v16 && v16.ok === true);

  // --------------------------------------------------------------- CAS 17
  // Le MEME parcours, session devenue inexploitable : c'est l'echec vecu par
  // l'utilisateur. Rien ne part, et le motif est nomme.
  reinitialiser();
  RP_AUTH_SESSION = session('jwt-perime', -5 * 60 * 1000);
  rpAuthEcrireStockage(RP_AUTH_SESSION);
  _stock['respublica_auth_identite'] = JSON.stringify({ email: 'arnie@example.test' });
  _programme = function (url) {
    if (url.indexOf('/auth/v1/token') >= 0) return reponse(400, { error: 'invalid_grant' });
    return reponse(200, { ok: true });
  };
  var v17 = await sbFondsReferenceCreer(PARCOURS.acteur, PARCOURS.fonds, PARCOURS.generique,
                                        PARCOURS.recette, PARCOURS.nom, null);
  cas('17. meme parcours, session perdue : AUCUNE requete metier emise',
      '0 RPC + session_perdue',
      requetesRpc().length + ' RPC + ' + (v17 && v17.raison),
      requetesRpc().length === 0 && v17 && v17.raison === 'session_perdue');

  // --- rapport --------------------------------------------------------------
  var ok = CAS.filter(function (c) { return c.ok; }).length;
  print('');
  print('=========================================================');
  print('  BANC TRANSPORT / SESSION — ' + ok + '/' + CAS.length + ' cas verts');
  print('=========================================================');
  CAS.forEach(function (c) {
    print((c.ok ? '  [OK]   ' : '  [ECHEC]') + ' ' + c.nom);
    if (!c.ok) { print('           attendu : ' + c.attendu); print('           obtenu  : ' + c.obtenu); }
  });
  print('');
  if (ok !== CAS.length) throw new Error('BANC EN ECHEC');
}

executer().catch(function (e) { print('EXCEPTION : ' + (e && (e.stack || e.message || e))); });
