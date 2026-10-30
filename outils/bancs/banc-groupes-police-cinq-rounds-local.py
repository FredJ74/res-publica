#!/usr/bin/env python3
"""Phases judiciaires réelles et autorité du chef après les règles du 29/10."""
import importlib.util,sys,json
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('cinq',R/'outils/bancs/banc-groupes-cinq-rounds-local.py');c=importlib.util.module_from_spec(sp);sp.loader.exec_module(c)
def suite(ctx):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 q.execute((R/'migrations/20261030210800_police_commandement_et_cinq_rounds.sql').read_text());q.execute((R/'migrations/20261030210800_police_commandement_et_cinq_rounds.sql').read_text());ctx['c'].commit()
 def pret():
  sql('DELETE FROM batailles_rounds;DELETE FROM batailles_groupes;DELETE FROM batailles_engagements;DELETE FROM batailles;DELETE FROM police_action_receipts;DELETE FROM police_interceptions;DELETE FROM police_detection_attempts;DELETE FROM jugements;DELETE FROM groupes_pj_adhesions')
  sql("UPDATE personnages_donnees SET est_emprisonne=NULL,hospitalisation=NULL WHERE name IN ('A','B','C','D')")
  ctx['preparer_interception_collective']()
  return ctx['detecter_interception_collective']()['rencontre']
 def rendre():
  rid=pret();exige(rpc('police_reddition_resoudre',(rid,),qui='C'),'chef_de_groupe_requis')
  v=exige(rpc('police_reddition_resoudre',(rid,),qui='D'));assert v['detention_id'] and v['commandeur']=='D'
  q.execute("SELECT nom FROM detentions WHERE jour_fin_effective IS NULL AND nom IN ('C','D')");assert q.fetchall()==[('C',)]
  assert rpc('police_reddition_resoudre',(rid,),qui='D')==v
 cas('police_reddition_initiale_chef_seul_cible_seule_ecrouee_rejeu',rendre)
 for n in range(1,5):
  def phase(n=n):
   rid=pret()
   # Décor de frontière de phase ; les vrais coups sont exercés par les bancs parents.
   q.execute("INSERT INTO police_action_receipts(personnage,rencontre,action,round_key,verdict) VALUES('C',%s,'combat',%s,'{\"ok\":true}')",(rid,n))
   for fn in ['police_reddition_resoudre','police_fuite_resoudre']:
    exige(rpc(fn,(rid,),qui='D'),'cinq_rounds_obligatoires')
   q.execute("SELECT count(*) FROM detentions WHERE jour_fin_effective IS NULL AND nom IN ('C','D')");assert q.fetchone()[0]==0
  cas('police_desengagement_refuse_apres_round_'+str(n),phase)
 def apres():
  rid=pret();q.execute("INSERT INTO police_action_receipts(personnage,rencontre,action,round_key,verdict) VALUES('C',%s,'combat',5,'{\"ok\":true}')",(rid,))
  v=exige(rpc('police_reddition_resoudre',(rid,),qui='D'));assert v['reddition']
  q.execute("SELECT pa FROM personnages_donnees WHERE name='D'");assert q.fetchone()[0]==0
 cas('police_reddition_collective_autorisee_apres_cinq',apres)
if __name__=='__main__':sys.exit(c.lancer(suite))
