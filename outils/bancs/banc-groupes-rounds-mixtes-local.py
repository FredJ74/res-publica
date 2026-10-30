#!/usr/bin/env python3
"""Deux groupes réels, même RPC de rounds et mêmes coups que la police."""
import importlib.util,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('ecrou',R/'outils/bancs/banc-groupes-ecrou-local.py');e=importlib.util.module_from_spec(sp);sp.loader.exec_module(e)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 q.execute(((R/'migrations/20261029121000_police_rounds_groupes_mixtes.sql').read_text()+(R/'migrations/20261029121001_police_rounds_suites.sql').read_text()))
 q.execute(((R/'migrations/20261029121000_police_rounds_groupes_mixtes.sql').read_text()+(R/'migrations/20261029121001_police_rounds_suites.sql').read_text()))
 ctx['c'].commit()
 cas('rounds_police_preexistants_conserves_apres_extension_mixte',ctx['police_deux_rounds_reels'])
 def decor():
  sql("UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='mairie',current_room='accueil',current_street=NULL,pa=100,hp=100,stats='{\"VOL\":15,\"PER\":15}',resources='{\"dis\":0}' WHERE name IN ('A','B','C','D')")
  exige(rpc('groupe_pj_rejoindre',('C',),qui='D'))
  sql("UPDATE pnj_membres SET leader_pj=NULL,leader_pnj_id=NULL,rue_noeud_id=NULL,ville='capitale',building_id='mairie',room_id='accueil' WHERE id='autre'")
  sql("UPDATE pnj_membres SET proprietaire_pj='C',leader_pj='C',leader_pnj_id=NULL,ville=NULL,building_id=NULL,room_id=NULL,pa=12,car_per=(pnj_metier_profil('agent_securite')->>'PER')::integer,car_vol=(pnj_metier_profil('agent_securite')->>'VOL')::integer WHERE id IN ('ancre','autre') AND statut='actif'")
  sql("INSERT INTO jugements(id,country,city,accuse,motif,data,executee) VALUES('jugement-mixte-fixture','republic','capitale','C','Peine fictive','{\"motifs\":[{\"jours\":2}]}',false)")
  q.execute("SELECT pnj_groupes_projeter_interne(ARRAY['police-republic-capitale-P1','police-republic-capitale-P2','police-republic-capitale-P3'])")
 def photo():
  q.execute("SELECT jsonb_agg(jsonb_build_array(name,pa,inventory,liquide,est_emprisonne) ORDER BY name) FROM personnages_donnees");a=q.fetchone()[0]
  q.execute("SELECT jsonb_agg(jsonb_build_array(id,pa,statut,leader_pj) ORDER BY id) FROM pnj_membres");return a,q.fetchone()[0]
 def deux_rounds():
  decor();obtenu=False
  for seed in range(40):
   q.execute('SAVEPOINT choix_rounds');q.execute('SELECT setseed(%s)',(seed/40,))
   try:
    d=exige(rpc('police_detection_verifier',('mairie','accueil',None),qui='C'))
    if not d.get('detecte'):continue
    rencontre=d['rencontre'];un=exige(rpc('police_combat_resoudre',(rencontre,None,'mairie','accueil',1),qui='C'))
    if un['arrestation'] or un['police_neutralisee']:continue
    q.execute("SELECT combattants_victimes,combattants_forces FROM police_interceptions WHERE personnage='C'");victimes,forces=q.fetchone()
    assert {'pj:C','pj:D','pnj:ancre','pnj:autre'}<=set(victimes),victimes
    assert {'pj:A','pj:B','pnj:cie-S1','pnj:police-republic-capitale-P1'}<=set(forces),forces
    assert not set(victimes)&set(forces)
    avant=photo();assert rpc('police_combat_resoudre',(rencontre,None,'mairie','accueil',1),qui='C')==un;assert photo()==avant
    exige(rpc('groupe_pj_quitter',(),qui='B'),'interception_en_cours')
    deux=exige(rpc('police_combat_resoudre',(rencontre,None,'mairie','accueil',2),qui='C'))
    avant=photo();assert rpc('police_combat_resoudre',(rencontre,None,'mairie','accueil',2),qui='C')==deux;assert photo()==avant
    q.execute("SELECT count(*) FROM detentions WHERE nom IN ('A','B','D')");assert q.fetchone()[0]==0
    q.execute("SELECT count(*) FROM police_action_receipts WHERE personnage='C' AND rencontre=%s AND action='combat'",(rencontre,));assert q.fetchone()[0]==2
    obtenu=True;break
   finally:q.execute('ROLLBACK TO SAVEPOINT choix_rounds')
  assert obtenu,'deux rounds mixtes réels non obtenus'
 cas('rounds_mixtes_2groupes_PJ_policiers_soldats_agents_prives_PA_rejeu_et_gel',deux_rounds)
 def detecter():
  for seed in range(40):
   q.execute('SAVEPOINT detection_mixte');q.execute('SELECT setseed(%s)',(seed/40,))
   d=exige(rpc('police_detection_verifier',('mairie','accueil',None),qui='C'))
   if d.get('detecte'):
    q.execute('RELEASE SAVEPOINT detection_mixte');return d['rencontre']
   q.execute('ROLLBACK TO SAVEPOINT detection_mixte');q.execute('RELEASE SAVEPOINT detection_mixte')
  raise AssertionError('aucune détection réelle')
 def issue(victoire):
  decor()
  if victoire:
   sql("UPDATE personnages_donnees SET pa=1 WHERE name IN ('A','B');UPDATE pnj_membres SET pa=1 WHERE leader_pj='B'")
  else:
   sql("UPDATE personnages_donnees SET pa=1 WHERE name IN ('C','D');UPDATE pnj_membres SET pa=1 WHERE leader_pj IN ('C','D')")
  q.execute("SELECT pnj_groupes_projeter_interne(ARRAY(SELECT id FROM pnj_membres WHERE leader_pj IN ('B','C','D')))")
  rencontre=detecter();fini=False
  for n in range(1,41):
   v=exige(rpc('police_combat_resoudre',(rencontre,None,'mairie','accueil',n),qui='C'))
   if v['arrestation'] or v['police_neutralisee']:
    assert v['police_neutralisee'] is victoire,v
    assert v['arrestation'] is not victoire,v
    fini=True;break
  assert fini,'confrontation non résolue'
  q.execute("SELECT count(*) FROM detentions WHERE nom IN ('A','B','D')");assert q.fetchone()[0]==0
  q.execute("SELECT count(*) FROM detentions WHERE nom='C'");assert q.fetchone()[0]==(0 if victoire else 1)
  if not victoire:
   q.execute("SELECT current_building,current_room FROM personnages_donnees WHERE name='D'");assert q.fetchone()==('mairie','accueil')
   q.execute("SELECT leader_pj FROM pnj_membres WHERE id='ancre'");assert q.fetchone()[0] is None
   q.execute("SELECT pa FROM personnages_donnees WHERE name='D'");assert q.fetchone()[0]==0,'compagnon encore debout lors de l’écrou'
  else:
   q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND pa>0");assert q.fetchone()[0]==0,'PJ de la force oublié'
   q.execute("SELECT count(*) FROM pnj_membres WHERE leader_pj='B' AND pa>0");assert q.fetchone()[0]==0,'PNJ de la force oublié'
 cas('rounds_mixtes_victoire_ensemble_force_neutralisee_pas_seulement_detecteur',lambda:issue(True))
 cas('rounds_mixtes_defaite_ecrou_recherche_uniquement_separation_PNJ',lambda:issue(False))
 ctx['preparer_combat_mixte']=decor;ctx['detecter_combat_mixte']=detecter
 ctx['preuves_extension']['rounds_mixtes']='Extension du même police_combat_resoudre et combat_coup_resoudre : groupes PJ/policiers/soldats/agents, victoire/défaite, reçus et écrou réel. Dégâts PA du contexte policier conservés, pas de mort artificielle.'
 if suivante is not None:suivante(ctx)
def lancer(suivante=None):return e.lancer(lambda c:suite(c,suivante))
if __name__=='__main__':sys.exit(lancer())
