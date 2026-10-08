/* ===========================================================================
   BANC DE sbPatcherBlob — supabase.js
   Chantier 5, 9 octobre 2026
   ===========================================================================

   CE QU'IL PROUVE. Sept fonctions de supabase.js modifiaient une sous-cle d'une colonne
   `data` en la relisant d'abord, avec `rows?.[0]?.data || {}`. Quand la lecture ECHOUAIT,
   ce `|| {}` faisait ecrire le patch SEUL par-dessus le blob -- et tout le contenu
   anterieur disparaissait, sans erreur et sans trace.

   LA PREUVE QUI COMPTE N'EST PAS LA VALEUR DE RETOUR, C'EST L'ABSENCE DE REQUETE. Une
   fonction qui rend `null` apres avoir quand meme ecrit n'a rien corrige. Le banc compte
   donc les requetes PATCH reellement emises, et exige ZERO des que la lecture n'a pas
   abouti.
   =========================================================================== */

var echecs = 0, total = 0;

function verifier(libelle, obtenu, attendu) {
  total++;
  var o = JSON.stringify(obtenu), a = JSON.stringify(attendu);
  if (o !== a) { echecs++; print('  NON ' + libelle); print('        obtenu  : ' + o);
                 print('        attendu : ' + a); }
  else print('  OK  ' + libelle);
}

function verifierVrai(libelle, cond, detail) {
  total++;
  if (!cond) echecs++;
  print('  ' + (cond ? 'OK  ' : 'NON ') + libelle + (cond ? '' : '   -> ' + detail));
}

// --- LE SERVEUR FACTICE -----------------------------------------------------
// `plan` donne la reponse a la N-ieme requete. `requetes` garde tout ce qui est parti :
// c'est ce journal qui permet d'affirmer qu'aucune ecriture n'a ete tentee.
var plan = [], requetes = [];

globalThis.fetch = function (url, init) {
  requetes.push({ url: url, methode: (init && init.method) || 'GET', corps: init && init.body });
  var r = plan.shift() || { status: 200, corps: [] };
  if (r.rejette) return Promise.reject(new Error('reseau coupe'));
  return Promise.resolve({
    ok: r.status >= 200 && r.status < 300,
    status: r.status,
    json: function () { return Promise.resolve(r.corps); },
    text: function () { return Promise.resolve(r.texte || ''); }
  });
};
globalThis.rpAuthJeton = function () { return 'jeton'; };
globalThis.rpAuthAssurerSession = function () { return Promise.resolve(); };

function ecritures() {
  return requetes.filter(function (r) { return r.methode === 'PATCH'; });
}

async function principal() {
  print('BANC DE sbPatcherBlob — fusionner sans ecraser');
  print('='.repeat(76));

  // ---- 1. CAS NOMINAL : la ligne existe, le blob est FUSIONNE et non remplace
  plan = [{ status: 200, corps: [{ id: 'x', data: { garde: 'moi', statut_interne: 7 } }] },
          { status: 200, corps: [{ id: 'x' }] }];
  requetes = [];
  var r = await sbPatcherBlob('prisonniers_qhs', 'x', { ajoute: 'neuf' }, { statut: 'libere' });
  verifierVrai('1. la ligne existe -> une ecriture est emise', ecritures().length === 1,
               ecritures().length + ' ecriture(s)');
  var corps = JSON.parse(ecritures()[0].corps);
  verifier('1. le blob existant est PRESERVE et complete',
           corps.data, { garde: 'moi', statut_interne: 7, ajoute: 'neuf' });
  verifier('1. la colonne hors blob est posee', corps.statut, 'libere');

  // ---- 2. LIGNE ABSENTE : rien a patcher, donc AUCUNE ecriture
  plan = [{ status: 200, corps: [] }];
  requetes = [];
  r = await sbPatcherBlob('prisonniers_qhs', 'absent', { a: 1 }, { statut: 's' });
  verifier('2. ligne absente -> rend null', r, null);
  verifierVrai('2. et AUCUNE ecriture n\'est emise', ecritures().length === 0,
               ecritures().length + ' ecriture(s)');

  // ---- 3. LE CORRECTIF : panne HTTP a la LECTURE -> aucune ecriture
  plan = [{ status: 500, texte: 'boom' }];
  requetes = [];
  r = await sbPatcherBlob('demandes_manifestation', 'x', { statut: 'acceptee' }, { statut: 'acceptee' });
  verifier('3. lecture en 500 -> rend null', r, null);
  verifierVrai('3. et AUCUNE ecriture : le blob n\'est PAS ecrase',
               ecritures().length === 0, ecritures().length + ' ecriture(s)');

  // ---- 4. PANNE RESEAU a la lecture -> aucune ecriture, et pas d'exception qui fuit
  plan = [{ rejette: true }];
  requetes = [];
  var leve = false;
  try { r = await sbPatcherBlob('rapports_renseignement', 'x', { remonte: true }); }
  catch (e) { leve = true; }
  verifierVrai('4. panne reseau a la lecture -> ne leve pas', !leve, 'une exception a fui');
  verifier('4. et rend null', r, null);
  verifierVrai('4. et AUCUNE ecriture', ecritures().length === 0, ecritures().length + ' ecriture(s)');

  // ---- 5. 401 : identite perdue -> aucune ecriture
  plan = [{ status: 401, texte: 'JWT expired' }];
  requetes = [];
  r = await sbPatcherBlob('engagements_militaires', 'x', { a: 1 }, { statut: 's' });
  verifier('5. lecture en 401 -> rend null', r, null);
  verifierVrai('5. et AUCUNE ecriture', ecritures().length === 0, ecritures().length + ' ecriture(s)');

  // ---- 6. ERREUR POSTGRESQL a la lecture -> aucune ecriture
  plan = [{ status: 400, texte: '{"code":"42501","message":"permission denied"}' }];
  requetes = [];
  r = await sbPatcherBlob('propositions_diplomatiques', 'x', { a: 1 });
  verifier('6. lecture refusee par la RLS (42501) -> rend null', r, null);
  verifierVrai('6. et AUCUNE ecriture', ecritures().length === 0, ecritures().length + ' ecriture(s)');

  // ---- 7. `colonnes` EN FONCTION : le statut se replie sur celui deja en base
  plan = [{ status: 200, corps: [{ id: 'x', statut: 'en_attente', data: { k: 1 } }] },
          { status: 200, corps: [{ id: 'x' }] }];
  requetes = [];
  await sbPatcherBlob('propositions_diplomatiques', 'x', { v: 2 },
                      function (ligne) { return { statut: ligne.statut || 'defaut' }; });
  corps = JSON.parse(ecritures()[0].corps);
  verifier('7. colonnes en fonction : le statut existant est repli', corps.statut, 'en_attente');
  verifier('7. et le blob reste fusionne', corps.data, { k: 1, v: 2 });

  // ---- 8. UN BLOB ABSENT EN BASE n'est pas une panne : on fusionne sur du vide
  plan = [{ status: 200, corps: [{ id: 'x' }] },
          { status: 200, corps: [{ id: 'x' }] }];
  requetes = [];
  await sbPatcherBlob('prisonniers_qhs', 'x', { neuf: true }, { statut: 's' });
  corps = JSON.parse(ecritures()[0].corps);
  verifier('8. ligne sans blob -> le patch devient le blob', corps.data, { neuf: true });

  print('');
  print('LES SEPT APPELANTS PASSENT-ILS BIEN PAR LA PORTE UNIQUE ?');
  print('-'.repeat(76));

  // Chacune des sept fonctions doit, sur une panne de LECTURE, ne rien ecrire du tout.
  var sept = [
    ['sbMajDemandeManifestation', function () { return sbMajDemandeManifestation('x', 'acceptee', { a: 1 }); }],
    ['sbMajPropositionDiplomatique', function () { return sbMajPropositionDiplomatique('x', { statut: 'acceptee' }); }],
    ['sbMajPrisonnierQHS', function () { return sbMajPrisonnierQHS('x', 'libere', { a: 1 }); }],
    ['sbMarquerRapportRemonte', function () { return sbMarquerRapportRemonte('x'); }],
    ['sbMajEngagement', function () { return sbMajEngagement('x', 'clos', { a: 1 }); }],
    ['sbNommerAmbassadeur', function () { return sbNommerAmbassadeur('republic', 'soviet', 'Jean'); }],
    ['sbFixerEcheanceExpulsion', function () { return sbFixerEcheanceExpulsion('republic', 'soviet', 5); }]
  ];
  for (var i = 0; i < sept.length; i++) {
    plan = [{ status: 503, texte: 'indisponible' }];
    requetes = [];
    var res = await sept[i][1]();
    verifierVrai(sept[i][0] + ' : panne de lecture -> aucune ecriture, rend null',
                 ecritures().length === 0 && res === null,
                 ecritures().length + ' ecriture(s), rend ' + JSON.stringify(res));
  }

  print('');
  print('='.repeat(76));
  if (echecs === 0) print('LES ' + total + ' EPREUVES SONT VERTES.');
  else print('ECHEC : ' + echecs + ' epreuve(s) sur ' + total);
  return echecs;
}

principal().then(function (n) { if (n > 0) throw new Error('banc rouge'); });
