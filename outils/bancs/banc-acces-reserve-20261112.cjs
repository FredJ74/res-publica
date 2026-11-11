// Accès réservé du Pavillon des Ambassadeurs et de la Résidence impériale (Fred, 11-12/11/2026).
// Contrôle hors ligne : textes en 9 langues, raccords de navigation et d'ordres, migration serveur.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');

const ctx = { console, state: { char: { name: 'Test' } } };
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(lire('plateau-acces-reserve.js'), ctx);
const T = ctx.ACCES_TEXTES;
assert.deepEqual(Object.keys(T).sort(), ['ar', 'de', 'en', 'es', 'fr', 'ko', 'pt-BR', 'ru', 'zh-TW']);
const vars = s => (s.match(/\{\w+\}/g) || []).sort().join();
for (const [l, t] of Object.entries(T)) {
  assert.deepEqual(Object.keys(t).sort(), Object.keys(T.fr).sort(), l);
  for (const k of Object.keys(T.fr)) {
    assert.ok(t[k].trim(), l + '/' + k);
    assert.equal(vars(t[k]), vars(T.fr[k]), l + '/' + k);
  }
}
// Le refus ne s'ouvre que pour les trois raisons de la porte serveur.
assert.equal(ctx.accesReserveRefus({ raison: 'porte_fermee_a_cle' }), false);

const nav = lire('plateau-navigation.js');
assert.match(nav, /\['acces_dignitaires','location_requise','un_seul_invite'\]\.includes\(r\?\.raison\)&&typeof accesReserveRefus==='function'/);
const router = lire('plateau-router.js');
for (const fn of ['acces_reserve_info', 'residence_reserver', 'residence_minibar', 'residence_location'])
  assert.ok(router.includes("fn === '" + fn + "'"), fn);
assert.match(lire('plateau.html'), /plateau-acces-reserve\.js\?v=/);

const data = lire('data.js');
const res = data.slice(data.indexOf("'residence-imperiale-novomirsk': {"), data.indexOf('// GARAGE DE NOVOMIRSK'));
assert.ok(!/louer_local|gerer_local|À LOUER|Local à louer|isLocationRoom/.test(res), 'ancienne location de local');
assert.ok(res.includes('Lev Zamkov (PNJ)') && res.includes('Ekaterina Klioutcheva (PNJ)'));
const pav = data.slice(data.indexOf("'pavillon-ambassadeurs-novomirsk': {"), data.indexOf("'residence-imperiale-novomirsk': {"));
assert.ok(!pav.includes('À LOUER') && pav.includes("fn:'acces_reserve_info'"));
for (const f of ['Novo_lev_zamkov_portrait.webp', 'Novo_ekaterina_klioutcheva_portrait.webp'])
  assert.ok(fs.existsSync(path.join(root, 'images/Sovarka/Novomirsk', f)), f);

const mig = lire('migrations/20261111232000_acces_reserve_pavillon_residence.sql');
for (const m of ['acces_reserve_v1', 'acces_reserve_garde_v1', 'residence_bonus_nuit_interne', "('forcer_passage', 'delit_mineur', 100, 1, 1500, false)",
  '60 + 4 * (v_vol - 13)', "+ time '12:00') AT TIME ZONE 'Europe/Paris'", "('residence_minibar', 0, 350)"])
  assert.ok(mig.includes(m), m);
console.log('Accès réservé : 9 langues, navigation, ordres et migration en place.');
