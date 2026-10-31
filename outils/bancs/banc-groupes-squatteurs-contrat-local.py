#!/usr/bin/env python3
"""Contrat privé PR233 : issue constatée, pas une bataille de squatteurs configurée.

Les états terminaux sont des fixtures de contrat ; les vrais rounds mixtes
restent dans le banc parent. Aucun profil/résistance de squatteur inventé.
"""
import importlib.util,json,re,hashlib,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('commandes',R/'outils/bancs/banc-groupes-bataille-commandes-local.py');c=importlib.util.module_from_spec(sp);sp.loader.exec_module(c)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 sp_a=importlib.util.spec_from_file_location('audit',R/'outils/bancs/banc-audit-securite-135-local.py');a=importlib.util.module_from_spec(sp_a);sp_a.loader.exec_module(a)
 ctx['installer_fonction_canonique']('terrain_etat_fusionner_interne')
 q.execute('ALTER TABLE personnages_donnees ADD COLUMN IF NOT EXISTS historique_crimes jsonb')
 q.execute(a.fonction('historique/migrations-appliquees/20261027110000_crimes_socle_serveur.sql','crime_tracer_interne'))
 src=(R/'migrations/20261031113630_acquisitions_capacites_et_gardes.sql').read_text()
 q.execute(re.search(r'CREATE TABLE IF NOT EXISTS public.terrain_acquisitions_recus.*?;',src,re.S)[0])
 q.execute((R/'migrations/20261031113650_squatteurs_issue_combat.sql').read_text())
 q.execute((R/'migrations/20261031115836_squatteurs_issue_reelle_bataille.sql').read_text())
 q.execute((R/'migrations/20261031115836_squatteurs_issue_reelle_bataille.sql').read_text())
 # Entrée propre au décor, jamais déployée : appelle le helper privé comme le
 # fera le moteur, sous authenticated et sans remplacer son identité JWT.
 q.execute("CREATE FUNCTION fixture_cloture_squatteurs(p_issue text,p_requete uuid) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO public,pg_temp AS $$ SELECT terrain_squatteurs_issue_bataille_interne('terrain-a-batir','A',p_issue,p_requete,72) $$")
 ctx['c'].commit()
 req='00000000-0000-4000-8000-000000019501'
 def decor(issue):
  sql("UPDATE personnages_donnees SET current_city='capitale',current_building='terrain-a-batir',current_room='terrain',country='republic',historique_crimes='[]' WHERE name='A'")
  sql("INSERT INTO terrains_etat(id,country,building_id,data) VALUES('republic_terrain-a-batir','republic','terrain-a-batir','{\"city\":\"capitale\",\"pnj\":\"squatter_cool\"}')")
  q.execute("INSERT INTO batailles(id,pays,ville,batiment,piece,camp_a,camp_b,statut,contexte) VALUES(72,'republic','capitale','terrain-a-batir','terrain','acteur','squatteurs','terminee','{\"type\":\"squatteurs\",\"acteur\":\"A\",\"camp_squatteurs\":\"squatteurs\",\"camp_acteur\":\"acteur\"}')")
  etat={'neutralises':'neutralise','tues':'mort','defaite':None}[issue]
  q.execute("INSERT INTO batailles_engagements(bataille_id,camp,pnj_id,matricule,etat_final,sorti_round) VALUES(72,'squatteurs','ancre','ancre',%s,%s)",(etat,1 if etat else None))
  q.execute("INSERT INTO batailles_engagements(bataille_id,camp,personnage,etat_final,sorti_round) VALUES(72,'acteur','A',%s,%s)",('neutralise' if issue=='defaite' else None,1 if issue=='defaite' else None))
  if issue=='defaite':sql("UPDATE personnages_donnees SET current_city='caserne',current_building='caserne-militaire',current_room='infirmerie' WHERE name='A'")
 def constater(issue):
  decor(issue);v=exige(rpc('fixture_cloture_squatteurs',(issue,req)))
  assert v['issue']==issue and 'jet' not in v,v
  q.execute("SELECT data::jsonb->>'pnj' FROM terrains_etat WHERE id='republic_terrain-a-batir'");pnj=q.fetchone()[0]
  assert pnj=={'neutralises':None,'tues':'cadavre','defaite':'squatter_cool'}[issue]
  q.execute("SELECT historique_crimes FROM personnages_donnees WHERE name='A'");crimes=q.fetchone()[0]
  assert len(crimes)==(0 if issue=='defaite' else 1)
  if crimes:assert crimes[0]['acte']==('meurtre' if issue=='tues' else 'agression')
  exige(rpc('fixture_cloture_squatteurs',(issue,req)))
  q.execute("SELECT jsonb_array_length(historique_crimes) FROM personnages_donnees WHERE name='A'");assert q.fetchone()[0]==len(crimes)
 for issue in ['neutralises','tues','defaite']:cas('squatteurs_contrat_issue_reelle_'+issue,lambda issue=issue:constater(issue))
 def faux():
  decor('neutralises');exige(rpc('fixture_cloture_squatteurs',('tues',req)),'issue_non_constatee')
  q.execute("SELECT data::jsonb->>'pnj' FROM terrains_etat WHERE id='republic_terrain-a-batir'");assert q.fetchone()[0]=='squatter_cool'
 cas('squatteurs_refus_issue_non_constatee_aucune_mutation',faux)
 def interrompu():
  decor('defaite');sql("UPDATE batailles_engagements SET sorti_round=NULL,etat_final=NULL WHERE bataille_id=72 AND personnage='A'")
  exige(rpc('fixture_cloture_squatteurs',('defaite',req)),'combat_interrompu')
  q.execute("SELECT data::jsonb->>'pnj' FROM terrains_etat WHERE id='republic_terrain-a-batir'");assert q.fetchone()[0]=='squatter_cool'
 cas('squatteurs_combat_interrompu_aucune_liberation_fictive',interrompu)
 def pas_fini():
  decor('neutralises');sql("UPDATE batailles SET statut='en_cours' WHERE id=72")
  sql("UPDATE batailles_engagements SET sorti_round=NULL,etat_final=NULL WHERE bataille_id=72")
  q.execute("SELECT militaire_camps_hostiles(72,'acteur')");assert q.fetchone()[0]==['squatteurs']
  q.execute("SELECT militaire_camps_hostiles(72,'squatteurs')");assert q.fetchone()[0]==['acteur']
  exige(rpc('fixture_cloture_squatteurs',('neutralises',req)),'combat_non_constate')
 cas('squatteurs_aucune_cloture_avant_fin_des_rounds',pas_fini)
 def prive():
  q.execute("SELECT has_function_privilege('authenticated','terrain_squatteurs_issue_bataille_interne(text,text,text,uuid,bigint)','EXECUTE')");assert not q.fetchone()[0]
 cas('squatteurs_aucun_score_ni_issue_decidable_par_navigateur',prive)
 ctx['preuves_extension']['squatteurs']='Contrat interne PR233 seulement, source Git épinglée. États terminaux fictifs de contrat, pas un combat réel de squatteurs ; profils et ouvrant encore manquants.'
 if suivante is not None:suivante(ctx)
def lancer(suivante=None):return c.lancer(lambda ctx:suite(ctx,suivante))
if __name__=='__main__':sys.exit(lancer())
