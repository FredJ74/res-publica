import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const core = readFileSync(new URL('../../plateau-core.js', import.meta.url), 'utf8');
const db = readFileSync(new URL('../../supabase.js', import.meta.url), 'utf8');
const sql = readFileSync(new URL('../../migrations/20261017190000_fermetures_date_universelle.sql', import.meta.url), 'utf8');

test('une fermeture datée ne dépend pas du jour personnel', () => {
  const start = core.indexOf('function fermetureEncoreActive(r)');
  const end = core.indexOf('async function chargerBatimentsFermes()', start);
  assert.ok(start >= 0 && end > start);
  const body = core.slice(start, end);
  assert.match(body, /date_fin_universelle/);
  const formatteur = core.match(/const FMT_JOUR_PARIS_CLIENT = [\s\S]*?;\n/);
  assert.ok(formatteur, 'le formatteur partage doit exister');
  const jourDebut=core.indexOf('function jourPartageISO()');
  const jourFin=core.indexOf('function dateReelleParisStr()',jourDebut);
  assert.ok(jourDebut>=0 && jourFin>jourDebut);
  const jour=core.slice(jourDebut,jourFin);
  for(const [instant,fin,active] of [
    ['2026-10-17T21:59:59Z','2026-10-18',true],
    ['2026-10-17T22:00:00Z','2026-10-18',false],
    ['2026-10-30T22:59:59Z','2026-10-31',true],
    ['2026-10-30T23:00:00Z','2026-10-31',false]
  ]) {
    class Horloge extends Date { constructor(...args){super(...(args.length?args:[instant]));} }
    const c=vm.createContext({Date:Horloge,Intl,state:{day:99999}});
    vm.runInContext(formatteur[0]+jour+body,c);
    assert.equal(c.fermetureEncoreActive({date_fin_universelle:fin}),active,instant);
    c.state.day=-100;
    assert.equal(c.fermetureEncoreActive({date_fin_universelle:fin}),active,instant+' independant du jour personnel');
    assert.equal(c.fermetureEncoreActive({}),false);
  }
});
test('la date de fin est décidée par PostgreSQL', () => {
  assert.match(sql, /NEW\.date_fin_universelle := \(now\(\) AT TIME ZONE 'Europe\/Paris'\)::date \+ NEW\.duree_jours/);
  assert.match(sql, /BEFORE INSERT ON public\.batiments_fermes/);
  // 27 octobre 2026 : la fermeture n'est plus ecrite par le navigateur (crime_incendier,
  // crime_explosifs) ; il n'existe donc plus de calcul de date cote client.
  assert.equal(db.indexOf('async function sbFermerBatiment'), -1);
  assert.doesNotMatch(db, /dateFin\.toISOString/);
});
