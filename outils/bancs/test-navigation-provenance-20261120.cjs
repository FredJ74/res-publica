'use strict';
// Sortie de bâtiment, provenance de rue et peines codées en dur (bug signalé par Fred le 20/11/2026 : Tom Tom libéré
// des geôles de Krasnov retombait sur l'ancienne navigation avec le titre et le décor par défaut de Luthécia).
// Essai annulé en base le 20/11 (Tom Tom) : mise à jour directe ignorée ; sortie vers la porte, provenance voisine
// gardée ; pas de rue → provenance = rue quittée ; mise en cellule → provenance vidée ; sortie sans provenance →
// première arrivée déclarée ou NULL ; correction imposée (rp.provenance_imposee) acceptée ; entrée par la porte gardée.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');
const nav = lire('plateau-navigation.js');
function extraire(nom) {
  const debut = nav.search(new RegExp('(async )?function ' + nom + '\\('));
  assert.ok(debut >= 0, nom);
  let i = nav.indexOf('{', debut), n = 0;
  for (; i < nav.length; i++) { if (nav[i] === '{') n++; else if (nav[i] === '}' && --n === 0) break; }
  return nav.slice(debut, i + 1);
}

test('Orientation : seule une rue voisine de la porte oriente la scène', () => {
  const ctx = { RUE_CENTRALE_NOEUDS: { soviet: { porte: { liens: { arriere: 'a', toutDroit: 'b' } },
    carrefour: { liens: {}, liensParArrivee: { x: { gauche: 'y' } } } } } };
  vm.runInNewContext(extraire('orientationRueVoisine') + ';this.f=orientationRueVoisine;', ctx);
  assert.equal(ctx.f('soviet', 'porte', 'b'), 'b');
  assert.equal(ctx.f('soviet', 'porte', 'loin'), null);
  assert.equal(ctx.f('soviet', 'carrefour', 'x'), 'x');
  assert.equal(ctx.f('soviet', 'inconnu', 'b'), null);
  assert.match(nav, /typeof orientationRueVoisine==='function'\?orientationRueVoisine\(state\.country,positionConfirmee\.street,orientationBrute\)/);
});

test('Sortie : une ville en mémoire sans rues est réalignée sur la position du serveur', async () => {
  const state = { country: 'republic', currentCity: 'krasnov', char: {} };
  const ctx = { state, WORLD: { soviet: { ville_b: {} } }, theme: null,
    rueCentraleServeur: (p, v) => p === 'soviet' && v === 'ville_b',
    sbRpcVerdict: async () => ({ ok: true, country: 'soviet', city: 'ville_b', building: 'commissariat-local' }),
    applyEmpireTheme(p) { ctx.theme = p; } };
  vm.runInNewContext(extraire('realignerVilleSurServeurAvantSortie') + ';this.f=realignerVilleSurServeurAvantSortie;', ctx);
  assert.equal(await ctx.f(), true);
  assert.equal(state.country, 'soviet'); assert.equal(state.currentCity, 'ville_b'); assert.equal(state.char.currentCity, 'ville_b');
  assert.equal(ctx.theme, 'soviet');
  // Ville déjà valide : aucune lecture.
  let lectures = 0; ctx.sbRpcVerdict = async () => { lectures++; return null; };
  assert.equal(await ctx.f(), false); assert.equal(lectures, 0);
  // Réponse invalide : rien n'est adopté.
  state.currentCity = 'nulle_part'; ctx.sbRpcVerdict = async () => ({ ok: false });
  assert.equal(await ctx.f(), false); assert.equal(state.currentCity, 'nulle_part');
  assert.match(nav, /if \(typeof realignerVilleSurServeurAvantSortie === 'function'\) await realignerVilleSurServeurAvantSortie\(\);\n  const contexteSortie=contexteNavigationRue\(\);/);
});

test('Rue : jamais le titre ni le décor d\'une autre ville', () => {
  const corps = extraire('showVueRue');
  assert.match(corps, /\} else \{\s+\/\/ Ville inconnue en memoire[\s\S]*?getElementById\('rue-title'\)\.textContent = '';[\s\S]*?adopterPositionServeurRelue\(\)/);
});

test('Serveur : provenance déduite et cohérente, peines au barème commun', () => {
  const sql = lire('migrations/20261120250000_navigation_provenance_peines_bareme.sql');
  assert.match(sql, /current_setting\('rp\.provenance_imposee', true\), ''\) = 'on' THEN RETURN NEW;/);
  assert.match(sql, /s\.building = NEW\.current_building AND s\.noeud = OLD\.current_street\)\) THEN\n  -- Entrée qui ne vient pas/);
  assert.match(sql, /NEW\.current_street_from = ANY \(r\.voisins\)/);
  assert.match(sql, /jsonb_object_keys\(coalesce\(r\.directions -> 'parArrivee', '\{\}'::jsonb\)\)/);
  assert.match(sql, /public\.crim_peine_jours_interne\('voler_archives_ecoute', p\.country\)\)\); \/\* vol_archives_bareme_v1/);
  assert.match(sql, /public\.crim_peine_jours_interne\('vol_materiel_militaire', v_pj\.country\) \/\* crim_bareme_militaire_v1/);
  assert.match(lire('RELAIS.md'), /rp\.provenance_imposee/);
});
