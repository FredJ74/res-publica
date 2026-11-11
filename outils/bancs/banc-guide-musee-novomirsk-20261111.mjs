// Guide du Musée de la République (11/11/2026) : présente dans les neuf salles, portrait dédié,
// et sa carte n'ouvre pas le dialogue libre gratuit.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const racine = new URL('../../', import.meta.url);
const lire = f => fs.readFileSync(new URL(f, racine), 'utf8');

test('la guide est dans les neuf salles du musée de Novomirsk', () => {
  const ctx = { window: {}, console, navigator: {}, localStorage: { getItem() { return null; }, setItem() {} },
    document: { addEventListener() {}, getElementById() { return null; }, querySelector() { return null; } } };
  ctx.self = ctx.window;
  vm.createContext(ctx);
  vm.runInContext(lire('data.js') + ';globalThis.__W = WORLD;', ctx);
  const ro = ctx.__W.soviet.capitale.buildingContext['musee-national-republia'].roomOverrides;
  const salles = Object.keys(ro);
  assert.equal(salles.length, 9);
  for (const s of salles) {
    const p = ro[s].persons || [];
    assert.equal(p.length, 1, s);
    assert.equal(p[0].guideMusee, true, s);
    assert.equal(p[0].photoUrl, 'images/Sovarka/Novomirsk/Novo_guide_musee_national_portrait.webp');
  }
  assert.ok(fs.existsSync(new URL('images/Sovarka/Novomirsk/Novo_guide_musee_national_portrait.webp', racine)));
});

test('la carte de la guide ouvre sa fenêtre, pas le dialogue PNJ', () => {
  const m = lire('plateau-multijoueur.js');
  const i = m.indexOf('if (p.guideMusee === true) {');
  assert.ok(i > 0 && i < m.indexOf("onclick=\"openPnjModal(this.dataset.enc)\""));
  assert.match(m.slice(i, i + 500), /onclick="ouvrirGuideMusee\(\)"/);
  assert.match(m, /function ouvrirGuideMusee\(\)/);
});

// Fiches d'Ouliana (11/11/2026, validées par Fred) : ordre « Écouter la guide », neuf langues, aucun débit.
const SALLES = ['hall', 'salle_presidents', 'salle_politiques', 'salle_honneur_militaire_nationale', 'salle_organisations',
  'salle_artistes_sportifs', 'salle_civils_intellectuels', 'salle_grandes_villes', 'expositions_temporaires'];
const LANGUES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
function catalogue(langue) {
  const ctx = { langue, RP_I18N_GAME_ENABLED: true };
  ctx.RPPlateauI18n = { language: () => ctx.langue };
  vm.createContext(ctx); ctx.window = ctx;
  vm.runInContext(lire('i18n/guide-musee-novomirsk-resources.js'), ctx);
  return ctx;
}

test('neuf fiches dans les neuf langues, mêmes paragraphes, aucun texte vide', () => {
  const ctx = catalogue('fr');
  assert.deepEqual([...ctx.RPGuideMuseeNovomirskI18n.langues], LANGUES);
  for (const s of SALLES) {
    const fr = ctx.texteGuideMusee('f_' + s);
    assert.ok(fr.length > 200, s);
    for (const l of LANGUES) {
      ctx.langue = l;
      const t = ctx.texteGuideMusee('f_' + s);
      assert.ok(t.length > 80, l + ' ' + s);
      assert.equal(t.split('\n\n').length, fr.split('\n\n').length, l + ' ' + s + ' (paragraphes)');
      if (l !== 'fr') assert.notEqual(t, fr, l + ' ' + s);
    }
    ctx.langue = 'fr';
  }
  assert.match(ctx.texteGuideMusee('f_salle_artistes_sportifs'), /Arvydas Tkatchenko/);
  assert.match(ctx.texteGuideMusee('f_salle_artistes_sportifs'), /Andreï Volkov/);
  assert.match(ctx.texteGuideMusee('f_salle_presidents'), /Taras Sergueïevitch Belov/);
});

test('chaque salle propose « Écouter la guide », gratuit, routé sans débit', () => {
  const ctx = { window: {}, console, navigator: {}, localStorage: { getItem() { return null; }, setItem() {} },
    document: { addEventListener() {}, getElementById() { return null; }, querySelector() { return null; } } };
  vm.createContext(ctx);
  vm.runInContext(lire('data.js') + ';globalThis.__W = WORLD;', ctx);
  const ro = ctx.__W.soviet.capitale.buildingContext['musee-national-republia'].roomOverrides;
  assert.deepEqual(Object.keys(ro).sort(), [...SALLES].sort());
  for (const s of SALLES) {
    const o = (ro[s].orders || []).find(x => x.fn === 'ecouter_guide_musee');
    assert.ok(o, s);
    assert.equal(o.pa, 0); assert.equal(o.cost, 0); assert.equal(o.i18nKey, 'variant.guide_listen');
  }
  const r = lire('plateau-router.js');
  assert.match(r, /if \(fn === 'ecouter_guide_musee' && typeof ouvrirGuideMusee === 'function'\) \{ ouvrirGuideMusee\(\); return; \}/);
  // Placé juste après « Fouiller ou voler », dont le relais garantit la sortie avant tout débit générique.
  assert.ok(r.indexOf("fn === 'ecouter_guide_musee'") - r.indexOf("fn === 'fouiller_voler'") < 400);
  assert.match(lire('baseline/seeds/95_a-regenerer/ordres_couts.sql'), /\('ecouter_guide_musee',0,0\)/);
});

test('la fenêtre de la guide affiche la fiche de la salle dans la langue du joueur, sans appel serveur', async () => {
  const modales = [], appels = [];
  const ctx = { console, langue: 'ru', RP_I18N_GAME_ENABLED: true, state: { currentRoom: 'salle_grandes_villes' },
    document: { head: { appendChild() {} }, createElement() { return {}; } },
    sovModal: (t, h, r) => modales.push([t, h, r]), showToast() {},
    sbRpcVerdict: async fn => { appels.push(fn); return null; } };
  ctx.RPPlateauI18n = { language: () => ctx.langue };
  vm.createContext(ctx); ctx.window = ctx;
  vm.runInContext(lire('i18n/guide-musee-novomirsk-resources.js'), ctx);
  const src = lire('plateau-multijoueur.js');
  const debut = src.indexOf('const GUIDE_MUSEE_CATALOGUE');
  const fin = src.indexOf('\n}\n', src.indexOf('async function ouvrirGuideMusee()')) + 3;
  vm.runInContext(src.slice(debut, fin), ctx);
  await ctx.ouvrirGuideMusee();
  const [titre, html, rouvrir] = modales[0];
  assert.equal(titre, 'Ульяна Историская, официальный гид');
  assert.match(html, /финал 1937 года/);
  assert.equal(appels.length, 0);
  ctx.langue = 'fr';
  rouvrir();
  assert.match(modales[1][1], /la finale de 1937, perdue contre El Estado/);
  ctx.state.currentRoom = 'hall';
  rouvrir();
  assert.equal(modales.length, 2, 'pas de réaffichage hors de la salle d’origine');
});
