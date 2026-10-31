#!/usr/bin/env python3
"""Même contrôle d'audience/asile par identité, JWT fictif jamais substitué."""
import importlib.util,re,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('rondes',R/'outils/bancs/banc-groupes-rounds-existants-local.py');rondes=importlib.util.module_from_spec(sp);sp.loader.exec_module(rondes)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']];a=rondes.interieur.natif.rue.force.corps.g.audit
 # Tables et corps effectivement présents dans les migrations de Claude.
 for f,nom in [('20261024184500_ambassades_audiences.sql','ambassades_audiences'),('20261025020000_ambassades_asile.sql','ambassades_asiles')]:
  s=(R/'migrations'/f).read_text();q.execute(re.search(r'CREATE TABLE IF NOT EXISTS public\.'+nom+r' \(.*?\n\);',s,re.S)[0])
 # La table des ambassades ouvertes est déjà dans le baseline (aucune donnée réelle).
 for f in (R/'baseline/domaines').glob('*/10_tables.sql'):
  m=re.search(r'CREATE TABLE public\.ambassades_ouvertes \(.*?\n\);',f.read_text(),re.S)
  if m:q.execute(m[0]);break
 for f,nom in [('20261024184500_ambassades_audiences.sql','ambassade_identite'),('20261024184500_ambassades_audiences.sql','ambassades_audiences_echoir'),('20261025020000_ambassades_asile.sql','ambassade_refuge_de'),('20261025020000_ambassades_asile.sql','ambassades_asiles_echoir'),('20261025020100_ambassades_asile_acces.sql','ambassade_acces_bureau')]:q.execute(a.fonction('migrations/'+f,nom))
 q.execute('REVOKE ALL ON FUNCTION ambassade_acces_bureau(text) FROM PUBLIC,anon;GRANT EXECUTE ON FUNCTION ambassade_acces_bureau(text) TO authenticated')
 migration=(R/'migrations/20261031115803_navigation_ambassades_par_membre.sql').read_text();
 if '--contre-ambassades' not in sys.argv:q.execute(migration);q.execute(migration)
 sql("INSERT INTO rue_sorties_batiments VALUES('republic','capitale','quartier-ambassades','rue-1')")
 ctx['c'].commit()
 def dedans():return rpc('navigation_interieure',('quartier-ambassades','bureau_sovarka'),qui='B')
 def audience(nom,expire=False):q.execute("INSERT INTO ambassades_audiences(demandeur,pays_hote,empire,statut,accord_prevu_le,accordee_le,expire_le) VALUES(%s,'republic','soviet','accordee',now(),now(),now()+(CASE WHEN %s THEN interval '-1 hour' ELSE interval '1 hour' END))",(nom,expire))
 def photo():
  q.execute("SELECT jsonb_agg(to_jsonb(d) ORDER BY name) FROM personnages_donnees d");return q.fetchone()[0]
 def chef_seul():
  audience('B');avant=photo();v=exige(dedans(),'sur_audience');assert v['membre']=='A' and photo()==avant
 cas('ambassade_audience_chef_ne_couvre_pas_membre',chef_seul)
 def tous():
  audience('A');audience('B');exige(dedans())
  q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND current_room='bureau_sovarka'");assert q.fetchone()[0]==2
 cas('ambassade_deux_autorisations_distinctes_autorisent_groupe',tous)
 def expiree():
  audience('A',True);audience('B');avant=photo();exige(dedans(),'sur_audience');assert photo()==avant
 cas('ambassade_audience_membre_expiree_refuse_groupe',expiree)
 def public_soi():
  audience('A');v=exige(rpc('ambassade_acces_bureau',('soviet',)));assert v['motif']=='audience'
  exige(rpc('ambassade_acces_bureau',('soviet',),qui='B'),'sur_audience')
 cas('ambassade_ancienne_porte_conserve_identite_appelant',public_soi)
 def asile():
  audience('B');sql("INSERT INTO ambassades_asiles(demandeur,pays_hote,empire,statut,decision_prevue_le,decide_le) VALUES('A','republic','soviet','accorde',now(),now())")
  exige(dedans())
 cas('ambassade_asile_et_audience_reutilisent_memes_controles',asile)
 def acl():
  for role in ['anon','authenticated','service_role']:
   q.execute("SELECT has_function_privilege(%s,'ambassade_acces_bureau_interne(text,text)','EXECUTE')",(role,));assert q.fetchone()[0] is False
 cas('ambassade_identite_parametree_inaccessible_clients',acl)
 if suivante is not None:suivante(ctx)
if __name__=='__main__':
 interieur=rondes.interieur;natif=interieur.natif;rue=natif.rue;f=rue.force
 sys.exit(f.corps.g.main(lambda c:f.corps.extension(c,lambda c:f.suite(c,lambda c:rue.suite(c,lambda c:natif.suite(c,lambda c:interieur.suite(c,lambda c:rondes.suite(c,suite))))))))
