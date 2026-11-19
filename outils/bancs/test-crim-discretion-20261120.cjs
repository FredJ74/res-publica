'use strict';
// Criminalité, correctifs de discrétion du 20/11/2026 (migration 20261120140000_crim_discretion.sql).
// Trois niveaux, sans se faire passer l'un pour l'autre :
//  1. relevé de l'essai annulé en production du 20/11 (JWT simulés, recopié ci-dessous) ;
//  2. lecture de la migration et des fichiers d'écran ;
//  3. numérotation des masqués recalculée ici (même ordre md5 que le serveur) et bloc d'actions de la fiche exécuté en vm.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const racine = path.join(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');
const sql = lire('migrations/20261120140000_crim_discretion.sql');

// Relevé de l'essai en production (transaction annulée, 20/11/2026) : B = Ben (masqué pour l'essai), A = Arnie, même pièce.
const RELEVE = {
  b_lit_a: { current_city: null, current_building: null, current_room: null, inv_null: true, country: 'soviet' },
  a_lit_a: { current_city: 'ville_b', current_building: 'universite', current_room: 'amphi', inv_null: false },
  secdef_lit_a: 'universite',          // fonction SECURITY DEFINER appelée par B : le code serveur lit toujours la position
  batailles_api: 'refus',              // SELECT direct sur batailles en authenticated
  anon: { visibles: 0, total: 7 },     // aucune position lisible en anon
  presents_vus_par_a: ['Arnie', 'Individu masqué n°1'],
  designation_ben: 'Individu masqué n°1',
  figees: { Ben: 'Individu masqué n°1' },
  adversaire_vu_par_a: 'Individu masqué n°1',
  adversaire_vu_par_b: 'Arnie',
  politique: '(user_id = auth.uid())'
};

test('Essai en production : B lit la ligne de A sans position ni inventaire ; A lit la sienne en entier ; le serveur lit tout', () => {
  for (const c of ['current_city', 'current_building', 'current_room']) {
    assert.equal(RELEVE.b_lit_a[c], null, c);
    assert.ok(RELEVE.a_lit_a[c], c);
  }
  assert.equal(RELEVE.b_lit_a.inv_null, true);
  assert.equal(RELEVE.a_lit_a.inv_null, false);
  assert.equal(RELEVE.secdef_lit_a, RELEVE.a_lit_a.current_building);
  assert.equal(RELEVE.anon.visibles, 0);
  assert.equal(RELEVE.batailles_api, 'refus');
  assert.equal(RELEVE.politique, '(user_id = auth.uid())');
});

test('Essai en production : le masqué porte le même numéro dans les présents et dans le rapport de combat', () => {
  const numeroPresents = RELEVE.presents_vus_par_a.find(n => n.startsWith('Individu masqué'));
  assert.equal(RELEVE.designation_ben, numeroPresents);
  assert.equal(RELEVE.figees.Ben, numeroPresents);
  assert.equal(RELEVE.adversaire_vu_par_a, numeroPresents);
  assert.ok(!Object.values(RELEVE).some(v => v === 'Ben'), 'le vrai nom du masqué n\'apparaît nulle part côté A');
  assert.equal(RELEVE.adversaire_vu_par_b, 'Arnie');
});

// Numérotation serveur : masqués non cachés de la pièce, ordre md5(nom || bâtiment || pièce), sans dépendre de qui regarde.
const numeroter = (presents, bat, piece) => {
  const m = presents.filter(p => p.masque && !p.cache)
    .map(p => ({ nom: p.nom, cle: crypto.createHash('md5').update(p.nom + bat + piece).digest('hex') }))
    .sort((a, b) => (a.cle < b.cle ? -1 : a.cle > b.cle ? 1 : 0));
  return Object.fromEntries(m.map((x, i) => [x.nom, i + 1]));
};

test('Numérotation : identique pour tous les observateurs, masqués cachés exclus', () => {
  const presents = [{ nom: 'Ben', masque: true }, { nom: 'Zoé', masque: true }, { nom: 'Kim', masque: true, cache: true }, { nom: 'Arnie' }];
  const n = numeroter(presents, 'universite', 'amphi');
  assert.deepEqual(Object.keys(n).sort(), ['Ben', 'Zoé']);
  assert.deepEqual(new Set(Object.values(n)), new Set([1, 2]));
  // Le serveur ne retire plus l'observateur de la numérotation : un masqué qui regarde ne décale pas les numéros des autres.
  assert.doesNotMatch(sql, /p\.name <> a AND public\.crim_masque_interne/);
  assert.match(sql, /row_number\(\) OVER \(ORDER BY md5\(p\.name \|\| p_bat \|\| p_piece\)\)/);
  assert.match(sql, /AND public\.crim_masque_interne\(p\.name\) AND NOT public\.crim_cache_interne\(p\.name\)/);
});

test('Migration : présents et rapports partagent la numérotation ; désignations figées à l\'ouverture du combat', () => {
  assert.equal((sql.match(/public\.crim_masques_piece_interne\(/g) || []).length >= 3, true);
  assert.match(sql, /'name', 'Individu masqué n°' \|\| numero/);
  assert.match(sql, /RETURN 'Individu masqué' \|\| coalesce\(' n°' \|\| n, ''\);/);
  assert.match(sql, /'crim_designations', public\.crim_designations_bataille_interne\(\(v_comb ->> 'bataille'\)::bigint\)\) \/\* crim_designations_v1 \*\//);
  assert.match(sql, /rp_raccorder\('public\.crim_combat_ouvrir_interne\(text,jsonb,jsonb,text,uuid\)'/);
  assert.match(sql, /crim_designation_bataille_interne\(b\.id, CASE WHEN v_camp = b\.camp_a THEN b\.leader_b ELSE b\.leader_a END\)/);
  assert.match(sql, /'mon_chef', CASE WHEN g\.leader = v_moi THEN g\.leader ELSE public\.crim_designation_bataille_interne\(b\.id, g\.leader\) END/);
  assert.match(sql, /REVOKE SELECT ON public\.batailles, public\.batailles_engagements, public\.batailles_groupes FROM anon, authenticated;/);
  // Le moteur de combat n'est pas touché.
  assert.doesNotMatch(sql, /militaire_bataille_round|militaire_bataille_rapport\(|militaire_bataille_actions|combat_ouvrir_interne\(text,text,uuid\)/);
});

test('Migration : position masquée comme l\'inventaire, politique de lecture resserrée', () => {
  for (const c of ['current_city', 'current_building', 'current_room']) {
    assert.match(sql, new RegExp(`WHEN user_id = auth\\.uid\\(\\) OR est_appel_serveur\\(\\) OR CURRENT_USER NOT IN \\('anon', 'authenticated'\\) THEN ${c}\\s+ELSE NULL::text\\s+END AS ${c}`));
  }
  assert.match(sql, /WHEN user_id = auth\.uid\(\) OR est_appel_serveur\(\) THEN inventory/);
  assert.match(sql, /ALTER POLICY personnages_lecture ON public\.personnages_donnees USING \(user_id = auth\.uid\(\)\);/);
  assert.doesNotMatch(sql, /\bDROP\b|\bDELETE\b/);
});

test('Écran : plus aucune lecture de la position d\'un autre joueur par la vue', () => {
  const sb = lire('supabase.js');
  assert.match(sb, /sbGet\('personnages', 'select=name,country,nationalite,poste,domicile&order=created_at\.asc'\)/);
  const fichiers = fs.readdirSync(racine).filter(f => f.endsWith('.js'));
  for (const f of fichiers) {
    const s = lire(f);
    const lectures = s.match(/sbGet\(\s*'personnages'[^;]*;/g) || [];
    for (const l of lectures) assert.doesNotMatch(l, /current_(city|building|room)/, `${f} : ${l.slice(0, 80)}`);
  }
  assert.doesNotMatch(lire('forum.js'), /j\.current_city/);
  assert.doesNotMatch(lire('plateau-politique.js'), /c\.current_city/);
});

// Extrait le bloc « if (isPJ && pnj.masque !== true) { … } » de openPnjModal et l'exécute.
function blocActionsPj() {
  const src = lire('plateau-pnj.js');
  const debut = src.indexOf('if (isPJ && pnj.masque !== true) {');
  assert.ok(debut > 0, 'garde du masqué absente de openPnjModal');
  let i = src.indexOf('{', debut), prof = 0;
  for (; i < src.length; i++) { if (src[i] === '{') prof++; else if (src[i] === '}' && --prof === 0) break; }
  return src.slice(debut, i + 1);
}

test('Fiche d\'un masqué : ni Parler, ni Rejoindre, ni Envoyer un mail ; fiche d\'un joueur à visage découvert inchangée', () => {
  const bloc = blocActionsPj();
  const executer = pnj => {
    const ctx = { pnj, isPJ: true, actionBtns: '', pnjSafeName: pnj.name, state: { country: 'soviet', group: null },
      encodePnjSafe: p => encodeURIComponent(JSON.stringify(p)) };
    vm.createContext(ctx);
    vm.runInContext(bloc, ctx);
    return ctx.actionBtns;
  };
  const masque = executer({ name: 'Individu masqué n°1', isPJ: true, masque: true, jeton: '0e1f2a3b-4c5d-4e6f-8a9b-0c1d2e3f4a5b' });
  assert.doesNotMatch(masque, /Parler|Rejoindre|Envoyer un mail/);
  const visible = executer({ name: 'Ben', isPJ: true });
  assert.match(visible, /Parler/);
  assert.match(visible, /Rejoindre ce joueur/);
  assert.match(visible, /Envoyer un mail/);
});
