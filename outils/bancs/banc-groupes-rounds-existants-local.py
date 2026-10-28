#!/usr/bin/env python3
"""Exécuter le vrai round militaire, sans le prétendre encore universel.
Toutes les fonctions sont les corps existants du dépôt, pas de coup simulé.
"""
import importlib.util,sys,re
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('interieur',R/'outils/bancs/banc-groupes-interieurs-local.py');interieur=importlib.util.module_from_spec(sp);sp.loader.exec_module(interieur)
def suite(ctx):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 a=interieur.natif.rue.force.corps.g.audit
 # Mêmes tables militaires ; compléter seulement la table de fixture allégée.
 src=(R/'baseline/domaines/militaire/10_tables.sql').read_text()
 for m in re.finditer(r'CREATE TABLE public\.(\w+) \((.*?)\n\);',src,re.S):
  nom,body=m.groups();q.execute('SELECT to_regclass(%s)',('public.'+nom,))
  if q.fetchone()[0] is None:q.execute(m[0])
  elif nom=='batailles_engagements':
   for ligne in body.splitlines():
    ligne=ligne.strip().rstrip(',')
    if ligne:q.execute('ALTER TABLE public.batailles_engagements ADD COLUMN IF NOT EXISTS '+ligne)
 # Les trois clés réellement utilisées par ON CONFLICT dans le moteur existant.
 contraintes=(R/'baseline/domaines/militaire/30_contraintes.sql').read_text()
 for nom in ['batailles_rounds','batailles_groupes','batailles_engagements']:
  for m in re.finditer(r'ALTER TABLE public\.'+nom+r' ADD CONSTRAINT .*?;',contraintes,re.S):
   if 'PRIMARY KEY' in m[0] or 'UNIQUE' in m[0]:q.execute(m[0])
 for ligne in (R/'baseline/domaines/militaire/35_index.sql').read_text().splitlines():
  if ligne.startswith('CREATE UNIQUE INDEX') and any(n in ligne for n in ['batailles_rounds','batailles_engagements']):q.execute(ligne)
 q.execute("ALTER TABLE personnages_donnees ADD COLUMN competences_militaires jsonb DEFAULT '{}',ADD COLUMN stats jsonb DEFAULT '{}'")
 q.execute((R/'baseline/seeds/92_mixte/militaire_armes_bonus.sql').read_text())
 q.execute('ALTER TABLE pnj_membres ADD COLUMN IF NOT EXISTS classe text')
 tables_def={}
 for fichier in (R/'baseline/domaines').glob('*/10_tables.sql'):
  for m in re.finditer(r'CREATE TABLE public\.(\w+) \(.*?\n\);',fichier.read_text(),re.S):tables_def[m[1]]=m[0]
 def assurer_table(nom):
  if nom not in tables_def:return
  q.execute('SELECT to_regclass(%s)',('public.'+nom,))
  if q.fetchone()[0] is None:q.execute(tables_def[nom])
 definitions={}
 for f in (R/'baseline/domaines').glob('*/20_fonctions*.sql'):
  for m in re.finditer(r'CREATE OR REPLACE FUNCTION public\.(\w+)\(',f.read_text()):definitions[m[1]]=str(f.relative_to(R))
 vus=set();nouvelles=[]
 def installer(nom):
  q.execute('SELECT EXISTS(SELECT 1 FROM pg_proc WHERE pronamespace=\'public\'::regnamespace AND proname=%s)',(nom,))
  if q.fetchone()[0] or nom in vus:return
  vus.add(nom)
  if nom not in definitions:
   q.execute('SELECT to_regclass(%s)',('public.'+nom,))
   if q.fetchone()[0] is not None:return
   raise RuntimeError('dépendance absente : '+nom)
  corps=a.fonction(definitions[nom],nom)
  for rel in set(re.findall(r'public\.(\w+)',corps)):assurer_table(rel)
  for enfant in sorted(set(re.findall(r'public\.(\w+)\s*\(',corps))-{nom}):installer(enfant)
  q.execute(corps);nouvelles.append(nom)
 installer('militaire_bataille_poursuivre')
 installer('militaire_bataille_recruter')
 installer('militaire_bataille_groupes_constituer')
 # Copier les ACL canoniques des fonctions chargées : authenticated doit passer
 # par la vraie porte, pas appeler directement un helper au défaut PUBLIC.
 q.execute("SELECT oid::regprocedure::text FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname=ANY(%s)",(nouvelles,))
 for (signature,) in q.fetchall():q.execute('REVOKE ALL ON FUNCTION '+signature+' FROM PUBLIC,anon,authenticated,service_role')
 for fichier in (R/'baseline/domaines').glob('*/70_droits.sql'):
  for ligne in fichier.read_text().splitlines():
   m=re.match(r'GRANT EXECUTE ON FUNCTION public\.(\w+)\((.*?)\) TO ',ligne)
   if m and m[1] in nouvelles:
    q.execute('SELECT to_regprocedure(%s)',('public.'+m[1]+'('+m[2]+')',))
    if q.fetchone()[0] is not None:q.execute(ligne)

 q.execute((R/'baseline/seeds/90_socle/pnj_familles_classes.sql').read_text())
 ctx['c'].commit()
 def round_pj(avec_soldats=False):
  # La bataille est un décor de deux camps militaires, pas une nouvelle porte d'agression.
  sql("UPDATE personnages_donnees SET current_building='hotel-republica',current_room='bar',pa=100 WHERE name IN ('A','C')")
  if avec_soldats:sql("UPDATE personnages_donnees SET current_building='hotel-republica',current_room='bar',current_street=NULL WHERE name='B'")
  sql("UPDATE personnages_donnees SET country='soviet' WHERE name='C'")
  sql("INSERT INTO services_militaires(personnage,pays,grade) VALUES('C','soviet','soldat')")
  sql("""INSERT INTO guerres(id,statut,data) VALUES('guerre-fixture','active','{"attaquant":"republic","attaque":"soviet"}')""")
  sql("INSERT INTO batailles(id,pays,ville,batiment,piece,camp_a,camp_b,initiative,leader_a,leader_b) VALUES(50,'republic','capitale','hotel-republica','bar','republic','soviet','simultane','A','C')")
  q.execute("SELECT militaire_bataille_recruter(50,'republic','capitale','hotel-republica','bar'),militaire_bataille_recruter(50,'soviet','capitale','hotel-republica','bar')")
  q.execute("SELECT militaire_bataille_groupes_constituer(50)")
  q.execute('SELECT count(*) FROM batailles_engagements WHERE bataille_id=50');assert q.fetchone()[0]==(6 if avec_soldats else 2)
  v=exige(rpc('militaire_bataille_poursuivre',(50,)))
  assert v.get('round')==1,v
  q.execute('SELECT count(*) FROM batailles_rounds WHERE bataille_id=50 AND numero=1');assert q.fetchone()[0]==2
  q.execute("SELECT count(*),min(pa),max(pa) FROM personnages_donnees WHERE name IN ('A','C')");n,m,M=q.fetchone();assert n==2 and 0<=m<=M<=100
 cas('round_militaire_existant_deux_PJ_coups_reels_et_rapports_persistes',round_pj)
 cas('round_militaire_existant_PJ_et_quatre_vrais_soldats_contre_PJ',lambda:round_pj(True))
 def droits():
  q.execute("SELECT has_function_privilege('authenticated','militaire_bataille_round(bigint)','EXECUTE'),has_function_privilege('authenticated','militaire_bataille_poursuivre(bigint)','EXECUTE')");assert q.fetchone()==(False,True)
  exige(rpc('militaire_bataille_poursuivre',(50,),qui=None),'acteur_non_authentifie')
 cas('round_existant_acl_helpers_et_identite_authentifiee',droits)
 ctx['preuves_extension']['round_militaire']='Corps existants, deux PJ militaires fictifs puis un PJ et quatre soldats contre un PJ. Ne prouve pas le recrutement des policiers ni une agression générale.'
 ctx['preuves_extension']['fonctions_rounds_chargees']=sorted(nouvelles)
if __name__=='__main__':
 natif=interieur.natif;rue=natif.rue;f=rue.force
 sys.exit(f.corps.g.main(lambda c:f.corps.extension(c,lambda c:f.suite(c,lambda c:rue.suite(c,lambda c:natif.suite(c,lambda c:interieur.suite(c,suite)))))))
