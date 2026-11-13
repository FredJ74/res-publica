// Renseignement de Sovarka (Fred, 13/11/2026) : équipes par ministère, habilitations, consultation des
// archives, interrogatoire du voleur. Banc statique ; le banc SQL annulé est banc-renseignement-sovarka-20261113.sql.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const lire = f => fs.readFileSync(f, 'utf8');
const data = lire('data.js');
const routeur = lire('plateau-router.js');
const prov = lire('plateau-sovarka-provinces.js');
const justice = lire('plateau-justice-economie.js');
const m = n => lire('migrations/' + fs.readdirSync('migrations').find(f => f.startsWith(n)));

test('ordres : habilitations au bureau de la Sécurité du Peuple, consultation dans les trois centres, interrogatoire ouvert aux deux ministres', () => {
  const ctx = {}; vm.createContext(ctx); vm.runInContext(data + ';this.BUILDINGS=BUILDINGS;this.WORLD=WORLD;', ctx);
  const sov = JSON.stringify(ctx.WORLD.soviet ?? ctx.WORLD);
  assert.match(data, /fn: 'sovarka_habilitations'[^\n]*requiresPost: 'min_int'/);
  for (const id of ['poste-vigilance-glaciale', 'station-radar-krasnov']) {
    const fns = ctx.BUILDINGS[id].rooms.salle_ecoute.orders.map(o => o.fn + ':' + o.pa).join();
    assert.equal(fns, 'voler_archives_ecoute:2,consulter_archives_ecoute:1', id);
  }
  assert.ok(sov.length > 0);
  const i = data.indexOf("'siege-renseignement': {", data.indexOf('buildingContext:'));
  const ctxSiege = data.slice(i, data.indexOf('// Caserne centrale', i));
  assert.match(ctxSiege, /fn: 'consulter_archives_ecoute'/);
  assert.match(ctxSiege, /excludeOrders: \['interroger_renseignement'\]/);
  assert.doesNotMatch(ctxSiege.slice(ctxSiege.indexOf('salle_interrogatoire_renseignement')), /requiresPost/);
});

test('écran : routes, lieu de détention en salle d’interrogatoire, réponses du serveur seules', () => {
  for (const r of ['consulter_archives_ecoute', 'sovarka_habilitations', 'interroger_renseignement']) assert.match(routeur, new RegExp("fn === '" + r + "'"));
  assert.match(justice, /d\.interrogatoire && typeof d\.interrogatoire\.batiment === 'string'/);
  for (const rpc of ['sovarka_habilitations_lire', 'sovarka_habilitation_accorder', 'sovarka_habilitation_retirer', 'sovarka_ecoute_archives_consulter', 'renseignement_detenus_interrogatoire', 'renseignement_interroger'])
    assert.ok(prov.includes("'" + rpc + "'"), rpc);
  assert.doesNotMatch(prov.slice(prov.indexOf('HABILITATIONS, CONSULTATION')), /Math\.random|Date\.now/);
});

test('textes : neuf langues pour les nouvelles clés', async () => {
  const g = { RP_I18N_RESOURCES: {} };
  vm.createContext(g); vm.runInContext(lire('i18n/sovarka-provinces-resources.js').replace(/\(typeof window!=='undefined'\?window:globalThis\)/, '(this)'), g);
  const t = g.RPSovarkaProvincesI18n;
  assert.equal(t.langues.length, 9);
  for (const k of ['tHabil', 'consultFound', 'interroOk', 'caughtInterro', 'm_pas_habilite', 'm_pas_soi_meme', 'm_pas_en_interrogatoire'])
    assert.ok(t.cles.includes(k), k);
});

test('serveur : équipes par ministère, 250 PSK, une opération à la fois, habilitations, 1 jour, interrogatoire', () => {
  assert.match(m('20261113230000'), /'soviet-min_int', 'coordinateur', 'Arkadi Moltchanov'/);
  assert.match(m('20261113230000'), /'soviet-min_def', 'coordinateur', 'Iouri Glazov'/);
  const c = m('20261113230100');
  assert.match(c, /c_cout := 250/);
  assert.match(c, /equipe_deja_en_mission/);
  assert.match(c, /cellule_d_un_autre_ministere/);
  const h = m('20261113230200');
  assert.match(h, /pas_soi_meme/);
  assert.match(h, /consulter_archives_ecoute', 1, 0/);
  assert.match(h, /current_room = ''bureau_min_def''/);
  assert.match(m('20261113230300'), /interrogatoire_novomirsk/);
  assert.match(m('20261113230400'), /vol_archives_un_jour/);
});
