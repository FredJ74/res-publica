#!/usr/bin/env python3
"""Règles du 29/10 : cinq rounds, chef, reddition et continuité du groupe."""
import importlib.util,sys,json
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('controle',R/'outils/bancs/banc-groupes-controles-ordinaires-local.py');c=importlib.util.module_from_spec(sp);sp.loader.exec_module(c)
def suite(ctx,suivante=None):
 c.suite(ctx)
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 for f in ['20261030210600_combats_cinq_rounds_et_commandement.sql','20261030210700_combats_chef_neutralise_effets_differes.sql']:
  q.execute((R/'migrations'/f).read_text());q.execute((R/'migrations'/f).read_text())
 ctx['c'].commit()
 decor=ctx['bataille_mixte_decor'];req=lambda n:f'00000000-0000-4000-8000-{n:012d}'
 def pret():
  sql('DELETE FROM police_interceptions; DELETE FROM police_action_receipts')
  sql("UPDATE personnages_donnees SET est_emprisonne=NULL,hospitalisation=NULL WHERE name IN ('A','B','C','D')")
  # PNJ de ce décor, distinct de ceux qu'un scénario parent a pu tuer.
  sql("INSERT INTO pnj_membres(id,famille,nom,pays,proprietaire_pj,leader_pj,pa,car_per,car_vol,car_dup) VALUES('compagnon-cinq','employe','Compagnon de fixture','republic','A','A',12,12,16,8)")
  sql("INSERT INTO pnj_employes_metier(pnj_id,job,role_libelle) VALUES('compagnon-cinq','agent_securite','agent')")
  decor()
 for n in range(5):
  def limite(n=n):
   pret();q.execute('UPDATE batailles SET round_courant=%s WHERE id=71',(n,))
   for action in ['replier','rendre']:
    exige(rpc('militaire_bataille_decider',(71,action,n,req(25000+n))),'cinq_rounds_obligatoires')
   q.execute('SELECT count(*) FROM batailles_engagements WHERE bataille_id=71 AND sorti_round IS NOT NULL');assert q.fetchone()[0]==0
  cas('cinq_rounds_aucun_desengagement_round_'+str(n),limite)
 def membre():
  pret();exige(rpc('militaire_bataille_poursuivre',(71,0,req(25010)),qui='B'),'pas_chef_de_groupe')
 cas('cinq_rounds_membre_ne_decide_pas_poursuite',membre)
 def reddition():
  pret();sql('UPDATE batailles SET round_courant=5 WHERE id=71')
  q.execute("SELECT inventory,current_city,current_building,current_room FROM personnages_donnees WHERE name='A'");avant=q.fetchone()
  v=exige(rpc('militaire_bataille_decider',(71,'rendre',5,req(25011))));assert v['reddition']
  q.execute("SELECT inventory,current_city,current_building,current_room,pa FROM personnages_donnees WHERE name='A'");apres=q.fetchone();assert apres[:4]==avant and apres[4]==0
  q.execute("SELECT count(*) FROM batailles_engagements WHERE bataille_id=71 AND camp='republic' AND etat_final='mort'");assert q.fetchone()[0]==0
  assert rpc('militaire_bataille_decider',(71,'rendre',5,req(25011)))==v
 cas('cinq_rounds_reddition_collective_sans_mort_deplacement_ni_rejeu',reddition)
 def chef_zero():
  pret();q.execute("SELECT id FROM batailles_engagements WHERE bataille_id=71 AND personnage='A'");eng=q.fetchone()[0]
  sql("UPDATE personnages_donnees SET pa=1 WHERE name='A'")
  q.execute('SELECT militaire_bataille_appliquer(71,%s::jsonb,1)',(json.dumps([{'cib_eng':eng,'cib_nom':'A','cib_pj':True,'cib_camp':'republic','degre':'critique','mode':'cac'}]),))
  q.execute("SELECT current_city,current_building,pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()==('capitale','hotel-republica',0)
  q.execute("SELECT chef FROM groupes_pj_adhesions WHERE membre='B'");assert q.fetchone()[0]=='A'
  q.execute("SELECT leader_pj FROM pnj_membres WHERE id='compagnon-cinq'");assert q.fetchone()[0]=='A'
  exige(rpc('militaire_bataille_decider',(71,'tenir',0,req(25012)),qui='B'),'pas_chef_de_groupe')
  v=exige(rpc('militaire_bataille_poursuivre',(71,0,req(25013)),qui='B'));assert v['round']==1
  q.execute("SELECT pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()[0]==0
 cas('cinq_rounds_chef_zero_groupe_preserve_et_resolution_automatique',chef_zero)
 def veritables():
  pret();trouve=False
  for n in range(100):
   q.execute('SAVEPOINT cinq');q.execute('SELECT setseed(%s)',(n/100,))
   try:
    for round_ in range(5):
     v=exige(rpc('militaire_bataille_poursuivre',(71,round_,req(25100+round_))))
     if v.get('terminee'):break
     assert not v.get('en_attente'),v
    if v.get('round')==5:
     trouve=True;break
   finally:q.execute('ROLLBACK TO SAVEPOINT cinq')
  assert trouve,'aucune séquence de cinq vrais rounds obtenue'
 cas('cinq_rounds_coups_reels_sans_attente_defenseur',veritables)
 if suivante is not None:suivante(ctx)
def lancer(suivante=None):return c.b.lancer(lambda ctx:suite(ctx,suivante))
if __name__=='__main__':sys.exit(lancer())
