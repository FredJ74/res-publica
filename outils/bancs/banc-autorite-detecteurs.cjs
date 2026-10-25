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

test('Authority suit un renommage exact, sans accepter une source inconnue ou une mauvaise surcharge',()=>{
 const script=String.raw`
import runpy
from pathlib import Path
m=runpy.run_path('outils/baseline/verifier-autorite.py',run_name='controle_importe')
f=m['signatures_inconnues_migration']
connues={'origine(text,integer)'}
renomme='ALTER FUNCTION public.origine(text, integer) RENAME TO interne;'
assert f(renomme+' REVOKE ALL ON FUNCTION public.interne(text,integer) FROM PUBLIC;',connues)==[]
assert f(renomme+' GRANT EXECUTE ON FUNCTION public.interne(text,text) TO authenticated;',connues)==['interne(text,text)']
assert f(renomme+' COMMENT ON FUNCTION public.origine(text,integer) IS \'absente\';',connues)==['origine(text,integer)']
assert f('REVOKE ALL ON FUNCTION public.interne(text,integer) FROM PUBLIC;'+renomme,connues)==['interne(text,integer)']
assert f(renomme,set())==['origine(text,integer)']
assert f('ALTER FUNCTION public.absente(text,integer) RENAME TO interne; REVOKE ALL ON FUNCTION public.interne(text,integer) FROM PUBLIC;',connues)==['absente(text,integer)','interne(text,integer)']
assert f(renomme+' ALTER FUNCTION public.interne(text,integer) RENAME TO finale; REVOKE ALL ON FUNCTION public.finale(text,integer) FROM PUBLIC;',connues)==[]
assert connues=={'origine(text,integer)'}, 'le catalogue de depart ne doit pas etre modifie'
# Ni les commentaires imbriques ni les corps SQL/PLpgSQL ne creent un objet.
for faux in ['-- '+renomme+'\n', '/* commentaire /* imbrique */ '+renomme+' */', "SELECT '"+renomme+"';", 'DO $corps$ BEGIN '+renomme+' END $corps$;', 'DO $$ BEGIN '+renomme+' END $$;']:
    assert f(faux+' REVOKE ALL ON FUNCTION public.interne(text,integer) FROM PUBLIC;',connues)==['interne(text,integer)'], faux
assert f("SELECT '\\'; REVOKE ALL ON FUNCTION public.inconnue() FROM PUBLIC;",connues)==['inconnue()']
assert f("SELECT E'\\\'"+renomme+"'; REVOKE ALL ON FUNCTION public.interne(text,integer) FROM PUBLIC;",connues)==['interne(text,integer)']
assert f('DO $$ BEGIN REVOKE ALL ON FUNCTION public.inconnue() FROM PUBLIC; END $$;',connues)==['inconnue()']
assert f("DO $$ BEGIN EXECUTE 'REVOKE ALL ON FUNCTION public.inconnue() FROM PUBLIC'; END $$;",connues)==['inconnue()']
# Conserver le chemin existant CREATE / droits sans exempter un nom cite.
assert f('CREATE FUNCTION public.neuve() RETURNS void LANGUAGE sql AS $$SELECT 1$$; REVOKE ALL ON FUNCTION public.neuve() FROM PUBLIC;',set())==[]
assert f("-- CREATE OR REPLACE FUNCTION public.inconnue()\nREVOKE ALL ON FUNCTION public.inconnue() FROM PUBLIC;",set())==['inconnue()']
# Cas reel #110 : l'existence de la source est attestee dans le baseline.
sig='acheter_produit_commerce(text,text,text,text,integer)'
assert sig in m['droits_du_baseline']()[2]
sql=Path('migrations/20261023000000_fontaine_exclusivite_sur_place.sql').read_text()
assert f(sql,{sig,'consommer_sur_place_commerce(text,text,text,text)'})==[]
# Supprimer reellement le RENAME doit recreer le defaut : contre-epreuve.
sans=sql.replace('RENAME TO acheter_produit_commerce_interne;','RENAME TO autre_interne;')
assert 'acheter_produit_commerce_interne(text,text,text,text,integer)' in f(sans,{sig})
`;
 const p=spawnSync('python3',['-c',script],{cwd:path.resolve(__dirname,'../..'),encoding:'utf8',timeout:15000});
 assert.equal(p.status,0,`${p.error||''}\n${p.stdout}\n${p.stderr}`);
});
