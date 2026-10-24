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
test('Authority reconnait acteur_est_moi comme les autres resolveurs, sans accepter une fonction sans garde',()=>{
 const script=String.raw`import runpy
m=runpy.run_path('outils/baseline/verifier-autorite.py',run_name='controle_importe')
f=m['garde_a_un_saut']
assert f('resilier_bail_volontaire',{'resilier_bail_volontaire':"IF NOT public.acteur_est_moi(p_acteur) THEN RETURN; END IF;"})
assert not f('dangereuse',{'dangereuse':"UPDATE public.objets SET nom='autrui';"})
assert f('porte',{'porte':'PERFORM interne();','interne':'PERFORM public.acteur_est_moi(p_acteur);'})
assert not f('porte',{'porte':'PERFORM milieu();','milieu':'PERFORM interne();','interne':'PERFORM public.acteur_est_moi(p_acteur);'})
`;
 const p=spawnSync('python3',['-c',script],{cwd:path.resolve(__dirname,'../..'),encoding:'utf8'});assert.equal(p.status,0,p.stdout+p.stderr);
});
