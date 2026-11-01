'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const path = require('node:path');

test('Authority recense les helpers historiques et Verdict sans confondre les paramètres imbriqués', () => {
  const script = String.raw`
import runpy, tempfile
from pathlib import Path
m = runpy.run_path('outils/baseline/verifier-autorite.py', run_name='controle_importe')
with tempfile.TemporaryDirectory() as dossier:
    p = Path(dossier) / 'fixture.js'
    p.write_text('''
sbRpc('historique', {p_id: 1, p_extras: {interne: 2}});
sbRpcVerdict ('nouveau', {p_id: 1, p_details: [{imbrique: 2}]});
sbInsert('ancienne', {}); sbUpdate ('ancienne', {}); sbDelete('ancienne', {});
sbInsertVerdict ('nouvelle', {}); sbUpdateVerdict('nouvelle', {}); sbDeleteVerdict ('nouvelle', {});
fauxsbRpcVerdict('ignore', {p_id: 1});
''')
    q = Path(dossier) / 'autre.js'
    q.write_text("sbUpdateVerdict('autre', {});")
    # Les fonctions partagent ce dictionnaire global, pas le dictionnaire copie par runpy.
    for nom in ('rpc_du_navigateur', 'surface_du_navigateur'):
        m[nom].__globals__['fichiers_du_navigateur'] = lambda: [str(p), str(q)]
    rpc = m['rpc_du_navigateur']()
    assert set(rpc) == {'historique', 'nouveau'}, rpc
    assert set(rpc['historique']) == {frozenset({'p_id', 'p_extras'})}, rpc
    assert set(rpc['nouveau']) == {frozenset({'p_id', 'p_details'})}, rpc
    tables, sites, bruts = m['surface_du_navigateur']()
    assert dict(tables) == {'ancienne': {'I','U','D'}, 'nouvelle': {'I','U','D'}, 'autre': {'U'}}, tables
    assert all(len(v) == 1 for v in sites.values()), sites
`;
  const proc = spawnSync('python3', ['-c', script], {
    cwd: path.resolve(__dirname, '../..'), encoding: 'utf8', timeout: 15000
  });
  assert.equal(proc.status, 0, `${proc.error || ''}\n${proc.stdout}\n${proc.stderr}`);
});
test('une declaration preparee est localisee sans devenir une preuve de deploiement',()=>{
 const script=String.raw`
import runpy,tempfile
from pathlib import Path
m=runpy.run_path('outils/baseline/verifier-autorite.py',run_name='controle_importe')
with tempfile.TemporaryDirectory() as dossier:
    migrations=Path(dossier)/'migrations';migrations.mkdir()
    (migrations/'a.sql').write_text('CREATE OR REPLACE FUNCTION public.fixture_rpc(p_nom text) RETURNS text LANGUAGE sql AS $$ SELECT p_nom $$;')
    m['declarations_rpc_migrations'].__globals__['RACINE']=dossier
    assert m['declarations_rpc_migrations']()=={'fixture_rpc':['migrations/a.sql']}
    assert 'fixture_rpc' not in m['parametres_du_baseline']()
`;
 const proc=spawnSync('python3',['-c',script],{cwd:path.resolve(__dirname,'../..'),encoding:'utf8',timeout:15000});
 assert.equal(proc.status,0,`${proc.stdout}\n${proc.stderr}`);
});

test('Authority reconnaît CREATE FUNCTION sans déclarer sa livraison en production',()=>{
 const script=String.raw`
import runpy
m=runpy.run_path('outils/baseline/verifier-autorite.py',run_name='controle_importe')
f=m['fonctions_creees_migration']
assert f('CREATE FUNCTION public.porte(p_id text) RETURNS int LANGUAGE sql AS $$SELECT 1$$;')=={'porte'}
assert f("DO $$ BEGIN EXECUTE format('CREATE FUNCTION public.privee(p_id text) RETURNS int LANGUAGE sql AS %L', corps);END $$;")=={'privee'}
assert f('CREATE OR REPLACE FUNCTION public.autre() RETURNS int LANGUAGE sql AS $$SELECT 1$$;')=={'autre'}
assert not f('REVOKE ALL ON FUNCTION public.absente(text) FROM PUBLIC;')
dynamique="DO $$ DECLARE f record;BEGIN FOR f IN SELECT * FROM (VALUES ('ancien(text)','copie_privee','p_id text')) t(sig,prive,args) LOOP EXECUTE format('CREATE FUNCTION public.%I(%s) RETURNS jsonb LANGUAGE plpgsql AS %L',f.prive,f.args,corps);END LOOP;END $$;"
assert f(dynamique)=={'copie_privee'}
assert not f(dynamique.replace('f.prive,f.args','f.autre,f.args'))
assert not f('-- CREATE FUNCTION public.faussedeclaration() RETURNS int;')
assert 'porte' not in m['parametres_du_baseline']()
`;
 const p=spawnSync('python3',['-c',script],{cwd:path.resolve(__dirname,'../..'),encoding:'utf8'});
 assert.equal(p.status,0,p.stdout+p.stderr);
});

test('commentaires et accolades citées ne retirent ni ne fabriquent de paramètres RPC',()=>{
 const script=String.raw`
import runpy,tempfile
from pathlib import Path
m=runpy.run_path('outils/baseline/verifier-autorite.py',run_name='controle_importe')
with tempfile.TemporaryDirectory() as dossier:
 p=Path(dossier)/'appel.js'
 p.write_text("sbRpc('taux_imposition_fixer', {p_portee:'local', /* } ] ) fausse: */ p_taux:5, // commentaires ( ]\np_fn:'impots',p_pa:0,p_cost:0,p_details:{texte:'} ) ] p_faux:1'}});")
 m['rpc_du_navigateur'].__globals__['fichiers_du_navigateur']=lambda:[str(p)]
 r=m['rpc_du_navigateur']();assert set(r)=={'taux_imposition_fixer'},r
 assert set(r['taux_imposition_fixer'])=={frozenset({'p_portee','p_taux','p_fn','p_pa','p_cost','p_details'})},r
 # Ne pas masquer les gestionnaires exécutables embarqués dans du HTML.
 p.write_text("const html=\"<button onclick=\\\"sbRpc('embarquee',{p_id:1})\\\">X</button>\";")
 assert 'embarquee' in m['rpc_du_navigateur']()
`;
 const p=spawnSync('python3',['-c',script],{cwd:path.resolve(__dirname,'../..'),encoding:'utf8'});
 assert.equal(p.status,0,p.stdout+p.stderr);
});

test('Authority reconnaît une policy citée uniquement sur sa propre table', () => {
  const script = String.raw`
import runpy
m = runpy.run_path('outils/baseline/verifier-autorite.py', run_name='controle_importe')
f=m['policies_creees_migration']
s='CREATE POLICY "reserve jardins lecture" ON public.jardins_ouvriers_reserve FOR SELECT TO authenticated USING (true);'
assert f(s)=={('jardins_ouvriers_reserve','reserve jardins lecture')}
assert ('autre_table','reserve jardins lecture') not in f(s)
assert f('DROP POLICY IF EXISTS "reserve jardins lecture" ON public.jardins_ouvriers_reserve;')==set()
assert f('create policy simple on public.fixture for select using(true);')=={('fixture','simple')}
assert f('-- CREATE POLICY "reserve jardins lecture" ON public.fixture FOR SELECT USING(true);\nSELECT 1;')==set()
assert f("SELECT 'CREATE POLICY faux ON public.fixture FOR SELECT USING(true);';")==set()
assert f('CREATE POLICY "nom""cite" ON public."MaTable" FOR SELECT USING(true);')=={('MaTable','nom"cite')}
`;
  const proc = spawnSync('python3', ['-c', script], {cwd:path.resolve(__dirname,'../..'),encoding:'utf8'});
  assert.equal(proc.status,0,proc.stderr||proc.stdout);
});
