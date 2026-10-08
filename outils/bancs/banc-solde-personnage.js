/* ===========================================================================
   BANC DE sbEcrireSoldePersonnage — supabase.js
   Chantier 5, 9 octobre 2026
   ===========================================================================

   LE DEFAUT QU'IL VERROUILLE, et c'est le plus grave de la nuit. Cinq fonctions ecrivaient
   le solde d'un autre personnage sur ce motif :

       const rows = await sbGet('personnages', `name=eq.${nom}&select=arg`);
       const argActuel = rows?.[0]?.arg ?? 0;
       await sbUpdate('personnages', `name=eq.${nom}`, { arg: argActuel + montant });

   `?? 0` SUR UNE LECTURE QUI A ECHOUE REMPLACE LE SOLDE. sbGet rend `null` sur toute erreur
   HTTP : `argActuel` vaut alors 0, et l'ecriture pose `arg = 0 + montant`. Un joueur qui
   avait 50 000 FR et recoit 200 FR de salaire se retrouve a 200 FR. Ce n'est pas un credit
   manque, c'est une DESTRUCTION de solde, d'autant plus grande que la victime etait riche.

   Et symetriquement, l'ECRITURE avalee faisait rendre un montant preleve qui ne l'avait pas
   ete -- de l'argent cree a partir de rien des que l'appelant le reversait.

   LE BANC EXIGE DONC TROIS CHOSES : qu'aucune ecriture ne parte sans un solde REELLEMENT lu,
   que l'ecriture soit CONDITIONNELLE au solde lu -- donc qu'une course soit detectee -- et
   qu'un echec soit RENDU, jamais avale.
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

var plan = [], requetes = [];
globalThis.fetch = function (url, init) {
  requetes.push({ url: url, methode: (init && init.method) || 'GET', corps: init && init.body });
  var r = plan.shift() || { status: 200, corps: [] };
  if (r.rejette) return Promise.reject(new Error('reseau coupe'));
  return Promise.resolve({
    ok: r.status >= 200 && r.status < 300, status: r.status,
    json: function () { return Promise.resolve(r.corps); },
    text: function () { return Promise.resolve(r.texte || ''); }
  });
};
globalThis.rpAuthJeton = function () { return 'jeton'; };
globalThis.rpAuthAssurerSession = function () { return Promise.resolve(); };
function ecritures() { return requetes.filter(function (r) { return r.methode === 'PATCH'; }); }

async function principal() {
  print('BANC DE sbEcrireSoldePersonnage — ni solde devine, ni ecriture avalee');
  print('='.repeat(76));

  // ---- 1. REFUS D'ECRIRE SUR UN SOLDE NON LU : le coeur du correctif
  requetes = [];
  var r = await sbEcrireSoldePersonnage('Jean', null, 500);
  verifier('1. solde attendu null -> refus', r, { ok: false, raison: 'solde_attendu_illisible' });
  verifierVrai('1. et AUCUNE requete ne part', requetes.length === 0, requetes.length + ' requete(s)');

  requetes = [];
  r = await sbEcrireSoldePersonnage('Jean', undefined, 500);
  verifier('2. solde attendu undefined -> refus', r, { ok: false, raison: 'solde_attendu_illisible' });
  verifierVrai('2. et AUCUNE requete', requetes.length === 0, requetes.length + ' requete(s)');

  requetes = [];
  r = await sbEcrireSoldePersonnage('Jean', NaN, 500);
  verifier('3. solde attendu NaN -> refus', r, { ok: false, raison: 'solde_attendu_illisible' });

  requetes = [];
  r = await sbEcrireSoldePersonnage('Jean', 100, NaN);
  verifier('4. nouveau solde NaN -> refus', r, { ok: false, raison: 'nouveau_solde_invalide' });
  verifierVrai('4. et AUCUNE requete', requetes.length === 0, requetes.length + ' requete(s)');

  // ---- 5. CAS NOMINAL : l'ecriture est CONDITIONNELLE au solde lu
  plan = [{ status: 200, corps: [{ name: 'Jean', arg: 1200 }] }];
  requetes = [];
  r = await sbEcrireSoldePersonnage('Jean', 1000, 1200);
  verifier('5. ecriture reussie -> verdict ok', r, { ok: true, solde: 1200 });
  verifierVrai('5. le filtre porte le solde ATTENDU (compare-and-swap)',
               ecritures()[0].url.indexOf('arg=eq.1000') > 0, ecritures()[0].url);
  verifier('5. et le corps ne porte que arg', JSON.parse(ecritures()[0].corps), { arg: 1200 });

  // ---- 6. LA COURSE EST DETECTEE : zero ligne touchee
  plan = [{ status: 200, corps: [] }];
  requetes = [];
  r = await sbEcrireSoldePersonnage('Jean', 1000, 1200);
  verifier('6. solde change entre-temps -> echec explicite',
           r, { ok: false, raison: 'solde_modifie_entre_temps', touchees: 0 });

  // ---- 7. PANNE HTTP a l'ecriture -> echec RENDU, jamais avale
  plan = [{ status: 500, texte: 'boom' }];
  requetes = [];
  r = await sbEcrireSoldePersonnage('Jean', 1000, 1200);
  verifierVrai('7. HTTP 500 -> ok:false', r.ok === false, JSON.stringify(r));
  verifierVrai('7. et la raison est celle du transport',
               r.raison === 'transport_indisponible', r.raison);

  // ---- 8. PANNE RESEAU -> echec rendu, sans exception qui fuit
  plan = [{ rejette: true }];
  requetes = [];
  var leve = false;
  try { r = await sbEcrireSoldePersonnage('Jean', 1000, 1200); } catch (e) { leve = true; }
  verifierVrai('8. panne reseau -> ne leve pas', !leve, 'une exception a fui');
  verifierVrai('8. et rend ok:false', r && r.ok === false, JSON.stringify(r));

  // ---- 9. SOLDE ATTENDU ZERO : la colonne peut valoir NULL en base
  plan = [{ status: 200, corps: [{ name: 'Jean', arg: 200 }] }];
  requetes = [];
  await sbEcrireSoldePersonnage('Jean', 0, 200);
  verifierVrai('9. solde attendu 0 : le filtre accepte aussi arg IS NULL',
               ecritures()[0].url.indexOf('or=(arg.eq.0,arg.is.null)') > 0
               || ecritures()[0].url.indexOf('or%3D') > 0
               || ecritures()[0].url.indexOf('arg.is.null') > 0,
               ecritures()[0].url);

  print('');
  print('sbAppliquerSalaire — LE SALAIRE N\'ECRASE PLUS LE SOLDE');
  print('-'.repeat(76));

  // ---- 10. LA REGRESSION HISTORIQUE : lecture en panne -> AUCUNE ecriture
  plan = [{ status: 500, texte: 'boom' }];
  requetes = [];
  r = await sbAppliquerSalaire('Jean', 200);
  verifierVrai('10. lecture du solde en panne -> ok:false', r.ok === false, JSON.stringify(r));
  verifierVrai('10. et AUCUNE ecriture : le solde n\'est PAS remplace par 200',
               ecritures().length === 0, ecritures().length + ' ecriture(s)');

  // ---- 11. CAS NOMINAL : 50 000 + 200, pas 0 + 200
  plan = [{ status: 200, corps: [{ arg: 50000 }] },
          { status: 200, corps: [{ name: 'Jean', arg: 50200 }] }];
  requetes = [];
  r = await sbAppliquerSalaire('Jean', 200);
  verifier('11. salaire credite sur le solde REEL', r, { ok: true, solde: 50200 });
  verifier('11. et le corps ecrit 50200', JSON.parse(ecritures()[0].corps), { arg: 50200 });

  // ---- 12. PERSONNAGE ABSENT : vide REEL, pas une panne
  plan = [{ status: 200, corps: [] }];
  requetes = [];
  r = await sbAppliquerSalaire('Fantome', 200);
  verifier('12. personnage absent -> refus explicite', r, { ok: false, raison: 'personnage_absent' });
  verifierVrai('12. et AUCUNE ecriture', ecritures().length === 0, ecritures().length + ' ecriture(s)');

  // ---- 13. SOLDE A NULL EN BASE : zero est alors la bonne lecture
  plan = [{ status: 200, corps: [{ arg: null }] },
          { status: 200, corps: [{ name: 'Jean', arg: 200 }] }];
  requetes = [];
  r = await sbAppliquerSalaire('Jean', 200);
  verifier('13. arg NULL en base -> credite 0 + montant, et c\'est juste', r, { ok: true, solde: 200 });

  print('');
  print('='.repeat(76));
  if (echecs === 0) print('LES ' + total + ' EPREUVES SONT VERTES.');
  else print('ECHEC : ' + echecs + ' epreuve(s) sur ' + total);
  return echecs;
}

principal().then(function (n) { if (n > 0) throw new Error('banc rouge'); });
