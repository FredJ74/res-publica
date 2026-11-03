// Métadonnées SQL, pas de connexion ni d'exécution des migrations.
import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
const script=String.raw`
import importlib.util,json,tempfile,pathlib
from pglast import parse_sql
s=importlib.util.spec_from_file_location('s','outils/baseline/simuler-rpc-apres-lot.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
a=m.charger_autorite()
texte="""DO $x$
DECLARE f text;
 a_entete text := 'public.source(p_id text)';
BEGIN
 f := pg_get_functiondef('public.source(text)'::regprocedure);
 f := replace(f, a_entete, 'public.copie(p_org text,p_id text)');
 EXECUTE f;
END $x$;
REVOKE ALL ON FUNCTION public.copie(text,text)FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.copie(text,text)TO authenticated;
"""
source={('source',('text',)):{'noms':['p_id'],'obligatoires':1,'auth':False,'source':'fixture'}}
def appliquer(t,f=None):
 f=dict(source if f is None else f)
 with tempfile.TemporaryDirectory()as d:
  p=pathlib.Path(d)/'fixture.sql';p.write_text(t);e=m.appliquer(f,str(p));assert e is None,e
 return f
positif=appliquer(texte)
assert positif[('copie',('text','text'))]['noms']==['p_org','p_id']
assert positif[('copie',('text','text'))]['auth']
assert a.fonctions_creees_migration(texte,{'source(text)'})=={'copie'}
assert a.fonctions_creees_migration(texte,set())==set()
variantes={
 'sans_execute':texte.replace(' EXECUTE f;',''),
 'mauvaise_variable_execute':texte.replace(' EXECUTE f;',' EXECUTE autre;'),
 'execute_commente':texte.replace(' EXECUTE f;',' -- EXECUTE f;'),
 'ancre_incoherente':texte.replace("a_entete text := 'public.source(p_id text)'","a_entete text := 'public.autre(p_id text)'"),
 'ecrasement_opaque':texte.replace(' EXECUTE f;'," f := 'SELECT 1';\n EXECUTE f;"),
 'renommage_concurrent':texte.replace(' EXECUTE f;'," f := replace(f, a_entete, 'public.fantome(p_id text)');\n EXECUTE f;"),
 'ancre_modifiee':texte.replace(' EXECUTE f;'," a_entete := 'public.copie(p_org text,p_id text)';\n EXECUTE f;"),
 'expression_ulterieure':texte.replace(' EXECUTE f;'," f := replace(f, 'public.copie(p_org text,p_id text)', 'public.fantome(p_id text)');\n EXECUTE f;"),
 'commentaire':"/*\n"+texte.split('REVOKE')[0]+"*/",
 'fonction_non_executee':texte.split('REVOKE')[0].replace('DO $x$',"CREATE FUNCTION public.non_executee()RETURNS void LANGUAGE plpgsql AS $x$"),
}
for nom,t in variantes.items():
 assert ('copie',('text','text'))not in appliquer(t),nom
assert ('copie',('text','text'))not in appliquer(texte,{})
assert not appliquer(texte+'REVOKE EXECUTE ON FUNCTION public.copie(text,text)FROM authenticated;')[('copie',('text','text'))]['auth']
assert ('copie',('text','text'))not in appliquer(texte+'DROP FUNCTION public.copie(text,text);')
reel=pathlib.Path('migrations/20261103011000_agences_securite_pj.sql').read_text()
assert 'employeur_embaucher_agence'in a.fonctions_creees_migration(reel,{'employeur_embaucher(text)'})
print(json.dumps({'positif':True,'contre_epreuves':list(variantes)+['source_absente','revoke','drop'],'migration_reelle_reconnue':True}))
`;
test('déclaration dérivée : vraie chaîne exécutée, source présente et droits exigés',()=>{
 const v=JSON.parse(execFileSync('python3',['-c',script],{encoding:'utf8',maxBuffer:2**20}));
 assert.equal(v.positif,true);assert.equal(v.migration_reelle_reconnue,true);assert.equal(v.contre_epreuves.length,13);
});
