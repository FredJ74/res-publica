/* ===========================================================================
   BANC DU TRANSPORT SERVERLESS — api/_supabase.js
   SOURCES: api/_supabase.js
   Chantier 5, 9 octobre 2026
   ===========================================================================

   CE QU'IL EPROUVE, ET POURQUOI IL EXISTE. Le socle de api/_supabase.js promet de
   distinguer six situations que les trois transports qu'il remplace confondaient. Une
   promesse de ce genre ne se verifie pas en relisant le code : elle se verifie en faisant
   repondre un serveur, et en regardant ce que l'appelant recoit.

   COMMENT IL TOURNE SANS NODE NI RESEAU. Cette machine n'a ni Node, ni npx, ni conteneur :
   le seul moteur JavaScript disponible est JavaScriptCore (jsc). Le banc injecte donc un
   `fetch` factice et un `process.env` minimal, charge le module en forme script, et appelle
   le vrai code. Aucune requete ne part, aucune base n'est touchee -- et c'est pourtant le
   VRAI transport qui est exerce, pas une imitation.

   Lancer :
       python3 outils/bancs/banc-api-supabase.py
   =========================================================================== */

var echecs = 0, total = 0;

function verifier(libelle, obtenu, attendu) {
  total++;
  var o = JSON.stringify(obtenu), a = JSON.stringify(attendu);
  var ok = o === a;
  if (!ok) echecs++;
  print('  ' + (ok ? 'OK  ' : 'NON ') + libelle);
  if (!ok) { print('        obtenu  : ' + o); print('        attendu : ' + a); }
}

function verifierVrai(libelle, condition, detail) {
  total++;
  if (!condition) echecs++;
  print('  ' + (condition ? 'OK  ' : 'NON ') + libelle + (condition ? '' : '   -> ' + detail));
}

// --- LE SERVEUR FACTICE -----------------------------------------------------
// `reponse` decide de ce que le prochain fetch rendra. Un seul point de reglage : le banc
// ne peut donc pas se tromper sur ce qu'il simule.
var reponse = null, dernieresRequetes = [];

globalThis.fetch = function (url, init) {
  dernieresRequetes.push({ url: url, init: init });
  if (reponse.rejette) return Promise.reject(new Error(reponse.message || 'echec reseau simule'));
  return Promise.resolve({
    ok: reponse.status >= 200 && reponse.status < 300,
    status: reponse.status,
    json: function () {
      if (reponse.corpsInvalide) return Promise.reject(new Error('json invalide'));
      return Promise.resolve(reponse.corps);
    },
    text: function () { return Promise.resolve(reponse.texte || ''); }
  });
};

async function principal() {
  print('BANC DU TRANSPORT SERVERLESS — les six etats que le socle doit distinguer');
  print('='.repeat(76));

  // ---- 1. SUCCES AVEC DONNEE
  reponse = { status: 200, corps: [{ id: 'a', solde: 12 }] };
  var r = await sbGetVerdict('caisses_batiments', 'id=eq.a');
  verifier('1. succes avec donnee', r, { ok: true, donnees: [{ id: 'a', solde: 12 }] });

  // ---- 2. SUCCES VIDE -- le coeur du chantier : un vide RECU n'est pas une panne
  reponse = { status: 200, corps: [] };
  r = await sbGetVerdict('forum_topics', 'forum_id=eq.x');
  verifier('2. succes VIDE (liste vraiment vide)', r, { ok: true, donnees: [] });
  verifierVrai('2. et ce vide est bien distinct d\'un echec', r.ok === true, 'r.ok=' + r.ok);

  // ---- 3. HTTP NON-2XX
  reponse = { status: 500, texte: 'boom' };
  r = await sbGetVerdict('mails', '');
  verifier('3. HTTP 500', r, { ok: false, raison: 'transport_indisponible',
    transport: { etat: 'http', http: 500, code: null, envoyee: true, quoi: 'GET mails' } });

  // ---- 4. SESSION PERDUE (401), distinguee des autres erreurs HTTP
  reponse = { status: 401, texte: 'JWT expired' };
  r = await sbGetVerdict('personnages', '');
  verifierVrai('4. HTTP 401 -> session_perdue', r.raison === 'session_perdue', 'raison=' + r.raison);
  verifierVrai('4. et son etat de transport le dit aussi', r.transport.etat === 'session_perdue',
               'etat=' + r.transport.etat);

  // ---- 5. ERREUR RESEAU : fetch rejette
  reponse = { rejette: true, message: 'ECONNREFUSED' };
  r = await sbInsertVerdict('evenements_globaux', { texte: 'x' });
  verifierVrai('5. rejet reseau -> raison reseau_indisponible',
               r.raison === 'reseau_indisponible', 'raison=' + r.raison);
  verifierVrai('5. et envoyee=true : on ne peut PAS affirmer que rien n\'est parti',
               r.transport.envoyee === true, 'envoyee=' + r.transport.envoyee);

  // ---- 6. ERREUR POSTGRESQL / POSTGREST : le code doit remonter
  reponse = { status: 409, texte: '{"code":"23505","message":"duplicate key"}' };
  r = await sbInsertVerdict('repartitions_versements', { id: 'x' });
  verifierVrai('6. erreur PostgreSQL : le code SQLSTATE remonte',
               r.transport.code === '23505', 'code=' + JSON.stringify(r.transport.code));
  verifierVrai('6. et l\'etat reste http', r.transport.etat === 'http', 'etat=' + r.transport.etat);

  // ---- 7. ABSENCE METIER LEGITIME : 204 sans corps
  reponse = { status: 204 };
  r = await sbDeleteVerdict('dons_en_attente', 'id=eq.x');
  verifier('7. 204 sans corps -> succes', r, { ok: true, donnees: true });

  // ---- 8. CORPS ILLISIBLE sur un 2xx : succes, sans inventer de donnee
  reponse = { status: 200, corpsInvalide: true };
  r = await sbGetVerdict('villes', '');
  verifier('8. 2xx au corps illisible -> succes, donnees=true', r, { ok: true, donnees: true });

  print('');
  print('LES ADAPTATEURS LEGACY : le contrat historique est-il preserve ?');
  print('-'.repeat(76));

  reponse = { status: 200, corps: [{ id: 'z' }] };
  var v = await sbGet('villes', '');
  verifier('9. sbGet succes -> le corps, comme avant', v, [{ id: 'z' }]);

  reponse = { status: 500, texte: 'boom' };
  v = await sbGet('villes', '');
  verifier('10. sbGet erreur HTTP -> null, comme avant', v, null);

  // ---- 11. onEchec : un echec aplati doit pouvoir etre JOURNALISE
  var vus = [];
  reponse = { status: 503, texte: 'indisponible' };
  v = await sbUpdate('caisses_batiments', 'id=eq.a', { data: {} },
                     { onEchec: function (env) { vus.push(env.etat + ':' + env.http); } });
  verifier('11. sbUpdate erreur -> null', v, null);
  verifier('11. et onEchec a ete appele avec l\'etat reel', vus, ['http:503']);

  reponse = { status: 200, corps: [] };
  vus = [];
  v = await sbGet('villes', '', { onEchec: function () { vus.push('appele'); } });
  verifier('12. onEchec n\'est PAS appele sur un succes vide', vus, []);

  print('');
  print('L\'IDENTITE SERVEUR : fail-closed si la cle manque');
  print('-'.repeat(76));

  // ---- 13. sans cle service, l'en-tete privilegie LEVE au lieu de retomber sur anon
  var leve = false, msg = '';
  try { sbEnTetes({ service: true }); } catch (e) { leve = true; msg = e.message; }
  verifierVrai('13. sbEnTetes({service:true}) leve si la cle est absente', leve, 'aucune exception');
  verifierVrai('13. et le message nomme la cause',
               msg.indexOf('SUPABASE_SERVICE_ROLE_KEY') >= 0, 'message=' + msg);
  verifierVrai('13. identiteServeurDisponible() le dit aussi',
               identiteServeurDisponible() === false, 'rend ' + identiteServeurDisponible());

  // ---- 14. l'identite anon reste utilisable, elle
  var h = sbEnTetes();
  verifierVrai('14. en-tetes anon : apikey posee', !!h['apikey'], 'apikey absente');
  verifierVrai('14. en-tetes anon : Authorization porte la meme cle',
               h['Authorization'] === 'Bearer ' + h['apikey'], h['Authorization']);

  print('');
  print('L\'IDENTITE DU JOUEUR : la RLS doit voir SON auth.uid(), pas la cle partagee');
  print('-'.repeat(76));

  // ---- 15. le jeton du joueur part dans Authorization, l'apikey reste celle du PROJET
  var hj = sbEnTetes({ jeton: 'jeton-du-joueur' });
  verifierVrai('15. jeton : Authorization porte le jeton du joueur',
               hj['Authorization'] === 'Bearer jeton-du-joueur', hj['Authorization']);
  verifierVrai('15. jeton : apikey reste la cle du projet, pas le jeton',
               hj['apikey'] !== 'jeton-du-joueur' && !!hj['apikey'], hj['apikey']);

  // ---- 16. service ET jeton ensemble : on leve, on ne choisit pas en silence
  var leve2 = false;
  try { sbEnTetes({ service: true, jeton: 'x' }); } catch (e) { leve2 = true; }
  verifierVrai('16. service + jeton ensemble -> leve (identites exclusives)', leve2,
               'aucune exception');

  // ---- 17. le transport transmet bien le jeton jusqu'a la requete
  reponse = { status: 200, corps: [] };
  dernieresRequetes = [];
  await sbGetVerdict('personnages', '', { jeton: 'jeton-du-joueur' });
  verifierVrai('17. sbGetVerdict({jeton}) envoie le jeton',
               dernieresRequetes[0].init.headers['Authorization'] === 'Bearer jeton-du-joueur',
               dernieresRequetes[0].init.headers['Authorization']);

  // ---- 18. l'upsert demande bien la resolution a PostgREST
  reponse = { status: 200, corps: [{ id: 'u' }] };
  dernieresRequetes = [];
  await sbUpsertVerdict('budgets_municipaux', { id: 'u' });
  var pref = dernieresRequetes[0].init.headers['Prefer'];
  verifierVrai('18. sbUpsertVerdict pose resolution=merge-duplicates',
               pref.indexOf('resolution=merge-duplicates') >= 0, 'Prefer=' + pref);

  // ---- 16. une RPC passe bien par /rpc/
  reponse = { status: 200, corps: { ok: true } };
  dernieresRequetes = [];
  await sbRpcVerdict('budget_municipal_cascade', { p_pays: 'republic' });
  verifierVrai('19. sbRpcVerdict appelle /rest/v1/rpc/<fn>',
               dernieresRequetes[0].url.indexOf('/rest/v1/rpc/budget_municipal_cascade') > 0,
               dernieresRequetes[0].url);

  print('');
  print('='.repeat(76));
  if (echecs === 0) {
    print('LES ' + total + ' EPREUVES SONT VERTES.');
  } else {
    print('ECHEC : ' + echecs + ' epreuve(s) sur ' + total);
  }
  return echecs;
}

principal().then(function (n) { if (n > 0) throw new Error('banc rouge'); });
