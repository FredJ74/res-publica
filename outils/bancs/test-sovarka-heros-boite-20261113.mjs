// Héros du Travail et boîte aux lettres du Parti (Fred, 13/11/2026) : ordres, routes, traductions,
// accroches d'écran, tâche de minuit et garanties de la migration.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const LANGUES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];

const ctx = vm.createContext({});
vm.runInContext(lire('data.js'), ctx);
const ordres = (ville, bat, piece) => JSON.parse(vm.runInContext(
  `JSON.stringify(ordresDeclaresDeLaPiece(BUILDINGS['${bat}']?.rooms?.['${piece}'], WORLD.soviet.${ville}.buildingContext['${bat}'], '${piece}'))`, ctx));

test('ordres : tableau à l’accueil des 3 mairies, classement chez le ministre, boîte dans les 3 salles des partis', () => {
  for (const [v, b, p] of [['capitale', 'mairie-capitale', 'hall_mairie'], ['ville_a', 'mairie', 'accueil_mairie'], ['ville_b', 'mairie', 'accueil_mairie']]) {
    const o = ordres(v, b, p).find(x => x.fn === 'heros_travail_tableau');
    assert.ok(o && o.pa === 0 && o.cost === 0, v);
    const salle = JSON.parse(vm.runInContext(`JSON.stringify(WORLD.soviet.${v}.buildingContext['${b}'].roomsExtra.salle_partis.orders)`, ctx));
    const d = salle.find(x => x.fn === 'parti_denoncer');
    assert.ok(d && d.pa === 1 && d.cost === 0 && d.type === 'legal' && d.label === 'Poster une dénonciation', v);
    assert.ok(salle.find(x => x.fn === 'parti_boite_registre' && x.pa === 0), v);
    assert.ok(salle.find(x => x.fn === 'sovarka_partis'), 'ordres existants conservés ' + v);
  }
  const m = ordres('capitale', 'palais-gouvernement', 'bureau_min_fin').map(x => x.fn);
  assert.ok(m.includes('heros_travail_classement'));
  const base = JSON.parse(vm.runInContext(`JSON.stringify((BUILDINGS['palais-gouvernement'].rooms.bureau_min_fin.orders||[]).map(o=>o.fn))`, ctx));
  const exclus = ['preempter_entreprise'];
  for (const fn of base) if (!exclus.includes(fn)) assert.ok(m.includes(fn), 'ordre du gabarit conservé : ' + fn);
  assert.equal(vm.runInContext(`JSON.stringify(WORLD.republic.capitale?.buildingContext?.['mairie-capitale']?.roomOverrides?.hall_mairie?.orders||[]).includes('heros_travail')`, ctx), false, 'Républia inchangée');
});

test('coûts miroirs : seeds régénérés et migration concordants', () => {
  const seed = lire('baseline/seeds/95_a-regenerer/ordres_couts.sql');
  for (const l of ["('parti_denoncer',1,0)", "('parti_boite_registre',0,0)", "('heros_travail_tableau',0,0)", "('heros_travail_classement',0,0)"])
    assert.ok(seed.includes(l), l);
  assert.match(lire('migrations/20261113163000_sovarka_heros_travail_boite_parti.sql'), /\('parti_denoncer', 1, 0\)/);
});

test('routes : les quatre ordres ouvrent le module ; le module expose ses fonctions', () => {
  const r = lire('plateau-router.js');
  for (const [fn, f] of [['heros_travail_tableau', 'ouvrirHerosTravailTableau'], ['heros_travail_classement', 'ouvrirHerosTravailClassement'],
    ['parti_denoncer', 'ouvrirPartiDenoncer'], ['parti_boite_registre', 'ouvrirPartiRegistre']])
    assert.match(r, new RegExp(`fn === '${fn}'\\)\\s*\\{ ${f}\\(\\); return; \\}`), fn);
  const html = lire('plateau.html');
  assert.match(html, /plateau-sovarka-heros-boite\.js\?v=heros-boite-20261113"/);
  assert.match(html, /i18n\/sovarka-heros-boite-resources\.js\?v=/);
  assert.ok(html.indexOf('plateau-sovarka-heros-boite.js') < html.indexOf('plateau-router.js'));
  for (const f of ['data.js', 'plateau-router.js', 'plateau-pnj.js', 'plateau-divers.js', 'plateau-personnage.js', 'plateau-equipements.js',
    'i18n/orders-resources.js', 'i18n/sovarka-infobulles-resources.js', 'i18n/equipements-resources.js'])
    assert.match(html, new RegExp(f.replace(/[.\/]/g, '\\$&') + '\\?v=[^"]*heros-boite-20261113"'), 'cache ' + f);
  assert.match(lire('outils/audits/audit-i18n-editorial.cjs'), /'sovarka-heros-boite-resources\.js'/);
});

const ci = vm.createContext({});
vm.runInContext(lire('i18n/sovarka-heros-boite-resources.js'), ci);
const I = vm.runInContext('RPSovarkaHerosBoiteI18n', ci);
const textes = vm.runInContext('(' + lire('i18n/sovarka-heros-boite-resources.js').match(/const texts=(\{[\s\S]*?\});\nfor/)[1] + ')', vm.createContext({}));

test('catalogue : 9 langues, mêmes clés, mêmes variables ; toutes les clés appelées existent', () => {
  assert.deepEqual([...I.langues], LANGUES);
  const fr = textes.fr;
  const vars = s => (s.match(/\{\w+\}/g) || []).sort().join();
  for (const l of LANGUES) {
    assert.deepEqual(Object.keys(textes[l]).sort(), Object.keys(fr).sort(), l);
    for (const k of Object.keys(fr)) { assert.ok(textes[l][k].trim(), l + ' ' + k); assert.equal(vars(textes[l][k]), vars(fr[k]), l + ' ' + k); }
  }
  const js = lire('plateau-sovarka-heros-boite.js');
  const appelees = new Set([...js.matchAll(/hbT\('([a-zA-Z_]+)'/g)].map(m => m[1]).filter(k => !k.endsWith('_')));
  for (const k of appelees) assert.ok(fr[k], 'clé manquante ' + k);
  const raisons = vm.runInContext(js.match(/const HB_RAISONS = (\[[\s\S]*?\]);/)[1], vm.createContext({}));
  for (const r of raisons) assert.ok(fr['r_' + r], 'raison ' + r);
  assert.ok(fr.dec_heros_travail);
  assert.equal(I.text('whichBox'), 'Dans quelle boîte aux lettres de parti voulez-vous poster votre dénonciation anonyme ?');
});

test('infobulles et libellés : texte français exact de data.js, 9 colonnes', () => {
  const ib = lire('i18n/sovarka-infobulles-resources.js');
  const lab = lire('i18n/orders-resources.js');
  const tous = [...ordres('capitale', 'mairie-capitale', 'hall_mairie'), ...ordres('capitale', 'palais-gouvernement', 'bureau_min_fin'),
    ...JSON.parse(vm.runInContext(`JSON.stringify(WORLD.soviet.capitale.buildingContext['mairie-capitale'].roomsExtra.salle_partis.orders)`, ctx))]
    .filter(o => /^(heros_travail|parti_)/.test(o.fn));
  assert.equal(tous.length, 4);
  for (const o of tous) {
    const ligne = ib.split('\n').find(l => l.startsWith('  [' + JSON.stringify(o.desc) + ','));
    assert.ok(ligne, 'infobulle ' + o.fn);
    assert.equal(JSON.parse(ligne.trim().replace(/,$/, '')).length, 9, o.fn);
    assert.ok(lab.includes(`"${o.fn}": ${JSON.stringify(o.label)}`), 'libellé ' + o.fn);
  }
});

test('écran : médaille traduite et échappée, objets ordinaires intacts ; refus et libellé d’équipement', () => {
  const c = vm.createContext({});
  c.window = c;
  vm.runInContext(lire('i18n/sovarka-heros-boite-resources.js'), c);
  vm.runInContext(lire('plateau-sovarka-heros-boite.js'), c);
  c.item = { generique_id: 'medaille_heros_travail', name: 'x', desc: 'y', decore: '<b>Arnie</b>', semaine: '2026-11-02', points: 20 };
  assert.equal(vm.runInContext('herosObjetTexte(item, "name")', c), 'Médaille de Héros du Travail');
  const d = vm.runInContext('herosObjetTexte(item, "desc")', c);
  assert.ok(d.includes('&lt;b&gt;Arnie&lt;/b&gt;') && d.includes('02/11/2026') && d.includes('20 points'), d);
  c.autre = { name: 'Pain', desc: 'Frais' };
  assert.equal(vm.runInContext('herosObjetTexte(autre, "name") + herosObjetTexte(autre, "desc")', c), 'PainFrais');
  const eq = lire('plateau-equipements.js');
  assert.match(eq, /'medaille_heros_travail': 'Médaille de Héros du Travail'/);
  assert.match(eq, /medaille_logement_seulement: /);
  const er = lire('i18n/equipements-resources.js');
  assert.match(er, /"lib\.medaille_heros_travail":\[/);
  assert.match(er, /"eq\.medaille_logement_seulement":\[/);
  assert.match(lire('plateau-pnj.js'), /herosDecorationsDans\(decoEl, pnjKey\)/);
  assert.match(lire('plateau-divers.js'), /herosObjetTexte\(item, 'name'\)/);
  assert.match(lire('plateau-personnage.js'), /medaille_heros_travail' && \/\^images/);
});

test('minuit : clôture hebdomadaire appelée chaque nuit, verdict contrôlé', () => {
  const c = lire('api/cron-minuit.js');
  assert.match(c, /sbRpc\('heros_travail_cloturer', \{ p_jour: jourParisISO\(new Date\(\)\) \}, HEADERS_SERVICE\)/);
  assert.match(c, /tacheQuotidienne\('heros_travail', traiterHerosTravailHebdomadaire\)/);
  assert.match(c, /urbanismeSovarka, herosTravail, production/);
});

test('migration : anonymat, compte jamais bloquant, droits fermés, décision non automatique', () => {
  const s = lire('migrations/20261113163000_sovarka_heros_travail_boite_parti.sql');
  const table = s.match(/CREATE TABLE IF NOT EXISTS public\.parti_denonciations \(([\s\S]*?)\);/)[1];
  assert.doesNotMatch(table, /auteur|personnage|acteur/);
  for (const f of ['heros_travail_pa_declencheur', 'heros_travail_garage_declencheur', 'heros_travail_chantier_declencheur']) {
    const corps = s.split('FUNCTION public.' + f)[1].split('$$;')[0];
    assert.match(corps, /EXCEPTION WHEN others THEN NULL/, f);
  }
  assert.match(s, /GRANT EXECUTE ON FUNCTION public\.heros_travail_cloturer\(date\) TO service_role;/);
  assert.match(s, /REVOKE ALL ON FUNCTION public\.heros_travail_noter_interne/);
  assert.doesNotMatch(s.split('FUNCTION public.heros_travail_cloturer')[1].split('$$;')[0], /heros_travail_decorer|decore = true/);
  assert.match(s, /record_superieur_en_attente/);
  assert.match(s, /deja_decore_cette_semaine/);
  assert.match(s, /RAISE EXCEPTION 'heros_travail : ancre/);
});
