// Calendrier électoral de Sovarka : la semaine à la gloire des partis y figure (15/11/2026).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');

async function calendrier(country, gloire) {
  const els = {};
  const el = id => (els[id] ||= { textContent: '', innerHTML: '', classList: { add() {}, remove() {}, contains: () => true } });
  const ctx = { console, document: { getElementById: el, querySelector: () => null, querySelectorAll: () => [], addEventListener() {} },
    localStorage: { getItem: () => null, setItem() {} }, setTimeout, clearTimeout };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('data.js').replace(/^const (WORLD|BUILDINGS|COUNTRIES|POSTES_ELECTIFS|CYCLES_ELECTORAUX) =/mg, 'var $1 ='), ctx);
  vm.runInContext(lire('plateau-politique.js'), ctx);
  const base = { tour: 1, eluId: null, candidats: [], dateDebutCandidatures: Date.now() - 864e5, dateDebutCampagne: Date.now() + 6 * 864e5,
    dateVote: Date.now() + 12 * 864e5, dateResultats: Date.now() + 13 * 864e5, dateFinMandat: Date.now() + 13 * 864e5 };
  ctx.state = { country, currentCity: 'capitale', char: { name: 'Banc' } };
  vm.runInContext('state = globalThis.state;', ctx);
  ctx.CYCLES_ELECTORAUX[country] = { president: { ...base }, maire_capitale: { ...base } };
  if (gloire) ctx.CYCLES_ELECTORAUX[country].gloire_partis = { ...base, candidats: [{ nom: 'Parti du Tracteur' }, { nom: 'Front des Bouleaux' }] };
  ctx.syncCyclesDepuisSupabase = async () => {}; ctx.initCycleElectoral = async () => {};
  vm.runInContext('syncCyclesDepuisSupabase = globalThis.syncCyclesDepuisSupabase; initCycleElectoral = globalThis.initCycleElectoral;', ctx);
  await vm.runInContext('ouvrirCalendrierElectoral()', ctx);
  return el('postes-body').innerHTML;
}

test('Sovarka : la semaine à la gloire figure, partis listés, sans candidature ni second tour', async () => {
  const html = await calendrier('soviet', true);
  assert.match(html, /Semaine à la gloire des partis/);
  const bloc = html.slice(html.indexOf('Semaine à la gloire des partis'));
  assert.match(bloc, /2 parti\(s\)/);
  assert.match(bloc, /Partis : Parti du Tracteur · Front des Bouleaux/);
  assert.match(bloc, /Les partis recrutent leurs partisans par les tracts/);
  assert.doesNotMatch(bloc, /Se porter candidat|Détails →|Second tour éventuel/);
  assert.match(html.slice(0, html.indexOf('Semaine à la gloire')), /Président/);
});

test('Républia inchangée, et Sovarka sans cycle de gloire ne l’invente pas', async () => {
  assert.doesNotMatch(await calendrier('republic', false), /gloire/);
  assert.doesNotMatch(await calendrier('soviet', false), /gloire/);
});
