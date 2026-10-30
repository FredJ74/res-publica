#!/usr/bin/env python3
"""Le chef innocent commande ; seule la cible détectée peut être écrouée."""
import importlib.util,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('mixtes',R/'outils/bancs/banc-groupes-rounds-mixtes-local.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 q.execute((R/'migrations/20261029122000_police_interception_groupe_et_commandement.sql').read_text())
 q.execute((R/'migrations/20261029122000_police_interception_groupe_et_commandement.sql').read_text())
 q.execute((R/'migrations/20261029123000_police_detection_groupes_reels.sql').read_text())
 q.execute((R/'migrations/20261029123000_police_detection_groupes_reels.sql').read_text())
 q.execute((R/'migrations/20261029124000_police_fuite_collective_commune.sql').read_text())
 q.execute((R/'migrations/20261029124000_police_fuite_collective_commune.sql').read_text())
 if '--contre-force-solo' in sys.argv or '--contre-victime-solo' in sys.argv:
  q.execute("SELECT pg_get_functiondef('police_combat_personnage_interne(text,text,text,text,integer,text)'::regprocedure)");s=q.fetchone()[0]
  if '--contre-force-solo' in sys.argv:
   a=' v_actifs:=public.police_force_combattants_interne(v_nom,p_rencontre);';assert s.count(a)==1
   s=s.replace(a," SELECT coalesce(jsonb_agg(x),'[]'::jsonb) INTO v_actifs FROM jsonb_array_elements(public.police_force_combattants_interne(v_nom,p_rencontre)) x JOIN pnj_membres m ON m.id=x->>'pnj_socle_id' WHERE m.famille IN ('policier','employe');")
  else:
   a=' v_victimes:=public.police_groupe_combattants_interne(v_nom,p_rencontre);';assert s.count(a)==1;s=s.replace(a,' v_victimes:=jsonb_build_array(public.combat_membre_decrire_interne(true,v_nom));')
  q.execute(s)
 ctx['c'].commit()
 def decor():
  ctx['preparer_combat_mixte']()
  exige(rpc('groupe_pj_quitter',(),qui='D'))
  exige(rpc('groupe_pj_rejoindre',('D',),qui='C'))
 def rencontre():
  for seed in range(40):
   q.execute('SAVEPOINT choix_detection');q.execute('SELECT setseed(%s)',(seed/40,))
   v=exige(rpc('police_detection_verifier',('mairie','accueil',None),qui='D'))
   if v.get('detecte'):
    q.execute('RELEASE SAVEPOINT choix_detection');return v
   q.execute('ROLLBACK TO SAVEPOINT choix_detection');q.execute('RELEASE SAVEPOINT choix_detection')
  raise AssertionError('pas de détection réelle du compagnon')
 def detecte():
  decor();v=rencontre();assert v['personnage_intercepte']=='C',v
  assert v['effectif']==9,v
  exige(rpc('groupe_pj_quitter',(),qui='B'),'interception_en_cours')
  q.execute("SELECT count(*) FROM detentions WHERE nom IN ('C','D')");assert q.fetchone()[0]==0
  reprise=exige(rpc('police_reprise_lire',(),qui='D'))
  assert reprise['active'] and reprise['chef']=='D' and reprise['personnage_intercepte']=='C' and not reprise['reddition_personnelle'],reprise
  exige(rpc('police_reddition_resoudre',(v['rencontre'],),qui='D'),'rencontre_invalide')
 cas('interception_compagnon_recherche_detecte_sans_sanction_automatique_du_chef',detecte)
 def commande():
  decor();v=rencontre();rid=v['rencontre']
  exige(rpc('police_combat_resoudre',(rid,None,'mairie','accueil',1),qui='C'),'chef_de_groupe_requis')
  premier=exige(rpc('police_combat_resoudre',(rid,None,'mairie','accueil',1),qui='D'))
  assert premier['contrat_groupes']==1,premier
  assert premier['personnage_intercepte']=='C' and premier['commandeur']=='D',premier
  q.execute("SELECT pa FROM personnages_donnees WHERE name='D'");assert q.fetchone()[0]==premier['pa']
  assert rpc('police_combat_resoudre',(rid,None,'mairie','accueil',1),qui='D')==premier
  recu=exige(rpc('police_action_resultat_lire',(rid,'combat',1),qui='D'));assert recu['verdict']==premier
  autre=exige(rpc('police_action_resultat_lire',(rid,'combat',1),qui='B'));assert not autre['trouve']
  q.execute("SELECT count(*) FROM detentions WHERE nom='D'");assert q.fetchone()[0]==0
 cas('interception_chef_innocent_commande_round_du_groupe_recu_et_PA_propres',commande)
 def obsolete():
  decor();v=rencontre();rid=v['rencontre']
  q.execute("SELECT jsonb_agg(to_jsonb(d)) FROM personnages_donnees d");avant=q.fetchone()[0]
  exige(rpc('police_combat_resoudre',(rid,None,'mairie','accueil',2),qui='D'),'round_obsolete')
  q.execute("SELECT jsonb_agg(to_jsonb(d)) FROM personnages_donnees d");assert q.fetchone()[0]==avant
 cas('round_futur_ou_obsolete_refuse_avant_coup_sans_mutation',obsolete)
 def reddition():
  decor();v=rencontre();r=exige(rpc('police_reddition_resoudre',(v['rencontre'],),qui='C'));assert r['detention_id']
  q.execute("SELECT current_building,current_room,est_emprisonne FROM personnages_donnees WHERE name='D'");assert q.fetchone()==('mairie','accueil',None)
  q.execute("SELECT leader_pj FROM pnj_membres WHERE id='ancre'");assert q.fetchone()[0] is None
 cas('reddition_personnelle_compagnon_ecroue_pas_chef_ni_PNJ',reddition)
 def fuite(reussite):
  decor();v=rencontre();rid=v['rencontre'];trouve=False
  for seed in range(40):
   q.execute('SAVEPOINT choix_fuite');q.execute('SELECT setseed(%s)',(seed/40,))
   try:
    v=exige(rpc('police_fuite_resoudre',(rid,),qui='D'))
    if v['reussite'] is not reussite:continue
    assert v['commandeur']=='D' and v['personnage_intercepte']=='C',v
    for nom in ['C','D']:
     q.execute('SELECT current_building,current_room,current_street FROM personnages_donnees WHERE name=%s',(nom,))
     assert q.fetchone()==((None,None,'rue-1') if reussite else ('mairie','accueil',None))
    for ident in ['ancre','autre']:
     q.execute('SELECT building_id,rue_noeud_id FROM pnj_position_effective(%s)',(ident,))
     assert q.fetchone()==((None,'rue-1') if reussite else ('mairie',None))
    assert rpc('police_fuite_resoudre',(rid,),qui='D')==v
    lu=exige(rpc('police_action_resultat_lire',(rid,'fuite',0),qui='D'));assert lu['verdict']==v
    trouve=True;break
   finally:q.execute('ROLLBACK TO SAVEPOINT choix_fuite')
  assert trouve,'issue de fuite non obtenue'
 cas('fuite_collective_jet_reel_ensemble_PJ_PNJ_moteur_commun_rejeu',lambda:fuite(True))
 cas('fuite_collective_refusee_jet_reel_personne_ne_bouge_rejeu',lambda:fuite(False))
 def mouvement_refuse():
  decor();v=rencontre();rid=v['rencontre']
  # Le chef reste apte ; son compagnon est désormais incapable de se déplacer.
  sql("UPDATE personnages_donnees SET hp=0 WHERE name='C'")
  trouve=False
  for seed in range(40):
   q.execute('SAVEPOINT refus_fuite');q.execute('SELECT setseed(%s)',(seed/40,))
   try:
    v=rpc('police_fuite_resoudre',(rid,),qui='D')
    if v.get('ok'):continue
    exige(v,'acteur_incapacite')
    q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('C','D') AND current_building='mairie'");assert q.fetchone()[0]==2
    q.execute("SELECT fuite_tentee,expires_at>now() FROM police_interceptions WHERE personnage='C'");assert q.fetchone()==(False,True)
    trouve=True;break
   finally:q.execute('ROLLBACK TO SAVEPOINT refus_fuite')
  assert trouve,'garde de mouvement jamais exécutée'
 cas('fuite_collective_incapacite_annule_jet_tentative_et_tous_mouvements',mouvement_refuse)
 def issue_collective(victoire):
  decor()
  if victoire:
   sql("UPDATE personnages_donnees SET pa=1 WHERE name IN ('A','B');UPDATE pnj_membres SET pa=1 WHERE leader_pj='B'")
   # Profils fictifs explicites du scénario gagnant, aucun coefficient du
   # moteur modifié : les coups et degrés restent ceux des fonctions réelles.
   sql("UPDATE personnages_donnees SET stats='{\"VOL\":20,\"PER\":20}' WHERE name IN ('C','D')")
  else:sql("UPDATE personnages_donnees SET pa=1 WHERE name IN ('C','D');UPDATE pnj_membres SET pa=1 WHERE leader_pj IN ('C','D')")
  q.execute("SELECT pnj_groupes_projeter_interne(ARRAY(SELECT id FROM pnj_membres WHERE leader_pj IN ('B','C','D')))")
  rid=rencontre()['rencontre'];fini=False
  q.execute('SELECT setseed(0.5)')
  for n in range(1,41):
   v=exige(rpc('police_combat_resoudre',(rid,None,'mairie','accueil',n),qui='D'))
   if v['arrestation'] or v['police_neutralisee']:
    assert v['police_neutralisee'] is victoire,v
    if victoire:
     q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND pa>0");assert q.fetchone()[0]==0,'force PJ oubliée'
     q.execute("SELECT count(*) FROM pnj_membres WHERE leader_pj='B' AND pa>0");assert q.fetchone()[0]==0,'force PNJ oubliée'
    else:
     q.execute("SELECT pa,est_emprisonne,current_building FROM personnages_donnees WHERE name='D'");assert q.fetchone()==(0,None,'mairie'),'chef oublié ou emprisonné à tort'
     q.execute("SELECT count(*) FROM detentions WHERE nom='C'");assert q.fetchone()[0]==1
    assert rpc('police_combat_resoudre',(rid,None,'mairie','accueil',n),qui='D')==v
    fini=True;break
  assert fini,'issue collective non résolue'
 cas('interception_victoire_force_entiere_PJ_PNJ_pas_seulement_policiers',lambda:issue_collective(True))
 cas('interception_defaite_compagnon_ecroue_pas_chef_recu_apres_separation',lambda:issue_collective(False))
 # Une rencontre de décor committée pour les connexions concurrentes, pas un
 # joueur réel. Les bancs parents signalent déjà ces commits fictifs.
 decor();rid_concurrent=rencontre()['rencontre'];ctx['c'].commit()
 def concurrence():
  import psycopg2
  from concurrent.futures import ThreadPoolExecutor
  from threading import Barrier
  barrier=Barrier(2)
  def jouer():
   conn=psycopg2.connect(ctx['serveur'].get_uri())
   try:
    cur=conn.cursor();cur.execute("SET statement_timeout='10s'");barrier.wait(timeout=5)
    v=rpc('police_combat_resoudre',(rid_concurrent,None,'mairie','accueil',1),qui='D',cur=cur);conn.commit();return v
   finally:conn.close()
  with ThreadPoolExecutor(2) as pool:res=list(pool.map(lambda _:jouer(),range(2)))
  exige(res[0]);assert res[0]==res[1],res
  q.execute("SELECT count(*) FROM police_action_receipts WHERE rencontre=%s AND action='combat'",(rid_concurrent,));assert q.fetchone()[0]==1
  lu=exige(rpc('police_action_resultat_lire',(rid_concurrent,'combat',1),qui='D'));assert lu['verdict']==res[0]
 cas('round_collectif_concurrent_deux_sessions_un_seul_round_et_relecture',concurrence)
 sql("UPDATE police_interceptions SET expires_at=now();DELETE FROM groupes_pj_adhesions WHERE membre IN ('C','D') OR chef IN ('C','D')")
 ctx['c'].commit()
 ctx['preparer_interception_collective']=decor;ctx['detecter_interception_collective']=rencontre
 if suivante is not None:suivante(ctx)
def lancer(suivante=None):return m.lancer(lambda c:suite(c,suivante))
if __name__=='__main__':sys.exit(lancer())
