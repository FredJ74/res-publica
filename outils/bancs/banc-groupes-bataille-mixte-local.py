#!/usr/bin/env python3
"""Bataille historique : vrais métiers PJ/soldats/police/douane/employés."""
import importlib.util,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('effectifs',R/'outils/bancs/banc-groupes-effectifs-atomiques-local.py');e=importlib.util.module_from_spec(sp);sp.loader.exec_module(e)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 ctx['installer_fonction_canonique']('militaire_bataille_decider')
 ctx['installer_fonction_canonique']('militaire_bataille_etat')
 q.execute((R/'migrations/20261029190000_batailles_groupes_identites_universelles.sql').read_text())
 q.execute((R/'migrations/20261029190000_batailles_groupes_identites_universelles.sql').read_text())
 if '--contre-bataille-metier-seul' in sys.argv:
  q.execute("SELECT pg_get_functiondef('militaire_bataille_recruter_metier_interne(bigint,text,text,text,text)'::regprocedure)")
  q.execute(q.fetchone()[0].replace('public.militaire_bataille_recruter_metier_interne(','public.militaire_bataille_recruter('))
 ctx['c'].commit()
 def decor():
  sql("UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='hotel-republica',current_room='bar',current_street=NULL,pa=100,hp=100,stats='{\"PER\":12,\"DUP\":12,\"VOL\":12}' WHERE name IN ('A','B','C','D')")
  # A militaire et B commissaire forment le même groupe volontaire ; aucune
  # famille ni affectation professionnelle n'est changée pour fabriquer le cas.
  exige(rpc('groupe_pj_quitter',(),qui='A'));exige(rpc('groupe_pj_rejoindre',('A',),qui='B'))
  exige(rpc('groupe_pj_rejoindre',('C',),qui='D'))
  sql("UPDATE pnj_membres SET leader_pj='A',leader_pnj_id=NULL,ville=NULL,building_id=NULL,room_id=NULL,pa=12 WHERE id='ancre'")
  sql("UPDATE pnj_membres m SET car_per=(pnj_metier_profil(e.job)->>'PER')::int,car_dup=(pnj_metier_profil(e.job)->>'DUP')::int,car_vol=(pnj_metier_profil(e.job)->>'VOL')::int FROM pnj_employes_metier e WHERE e.pnj_id=m.id")
  sql("UPDATE pnj_membres SET leader_pj='C',leader_pnj_id=NULL,ville=NULL,building_id=NULL,room_id=NULL,pa=12 WHERE id='douane-republic-ville_a-D1'")
  sql("INSERT INTO services_militaires(personnage,pays,grade) VALUES('C','soviet','soldat')")
  sql("INSERT INTO guerres(id,statut,data) VALUES('mixte-native','active','{\"attaquant\":\"republic\",\"attaque\":\"soviet\"}')")
  sql("INSERT INTO batailles(id,pays,ville,batiment,piece,camp_a,camp_b,initiative,leader_a,leader_b) VALUES(71,'republic','capitale','hotel-republica','bar','republic','soviet','simultane','A','C')")
  q.execute("SELECT militaire_bataille_recruter(71,'republic','capitale','hotel-republica','bar'),militaire_bataille_recruter(71,'soviet','capitale','hotel-republica','bar')")
  q.execute('SELECT militaire_bataille_groupes_constituer(71)')
 def identites():
  decor()
  q.execute("SELECT personnage FROM batailles_engagements WHERE bataille_id=71 AND personnage IS NOT NULL ORDER BY personnage");assert q.fetchall()==[('A',),('B',),('C',),('D',)]
  q.execute("SELECT DISTINCT m.famille FROM batailles_engagements e JOIN pnj_membres m ON m.id=e.pnj_id WHERE e.bataille_id=71");assert {'soldat','policier','douanier','employe'}<=set(x[0] for x in q.fetchall())
  q.execute("SELECT count(*) FROM batailles_engagements WHERE bataille_id=71");n=q.fetchone()[0]
  q.execute("SELECT militaire_bataille_recruter(71,'republic','capitale','hotel-republica','bar')")
  q.execute("SELECT count(*) FROM batailles_engagements WHERE bataille_id=71");assert q.fetchone()[0]==n,'recrutement double'
  q.execute("SELECT count(*) FROM militaire_bataille_combattants(71,'republic')");lus=q.fetchone()[0]
  q.execute("SELECT count(*) FROM batailles_engagements WHERE bataille_id=71 AND camp='republic'");attendus=q.fetchone()[0]
  assert lus==attendus,('effectifs camp republic',lus,attendus,n)
 cas('bataille_recrutement_reel_quatre_metiers_sans_carriere_fictive_et_rejeu',identites)
 def rounds():
  decor()
  q.execute("SELECT militaire_bataille_actions(71,'republic',1,false)");actions=q.fetchone()[0]
  assert any(a.get('att_mat')=='ancre' for a in actions),actions
  q.execute('SELECT setseed(0.3)')
  v=exige(rpc('militaire_bataille_poursuivre',(71,),qui='A'));assert v['round']==1,v
  q.execute('SELECT count(*) FROM batailles_rounds WHERE bataille_id=71 AND numero=1');assert q.fetchone()[0]==2
 cas('bataille_round_reel_et_rapports_mixtes_persistes',rounds)
 def chute(ident):
  decor();q.execute("SELECT id,camp FROM batailles_engagements WHERE bataille_id=71 AND pnj_id=%s",(ident,));eng,camp=q.fetchone()
  import json
  action={'degre':'critique','mode':'cac','cib_eng':eng,'cib_camp':camp,'cib_pj':False,'cib_nom':None}
  # Le degré est fourni au helper privé d'application pour couvrir la borne
  # terminale ; le scénario rounds ci-dessus utilise les vrais jets.
  q.execute("SELECT militaire_degats_pct('critique')");assert q.fetchone()[0]>0
  sql("UPDATE pnj_membres SET pa=1 WHERE id='"+ident+"'")
  q.execute('SELECT militaire_bataille_appliquer(71,%s::jsonb,1)',(json.dumps([action]),))
  q.execute('SELECT statut,pa,leader_pj FROM pnj_membres WHERE id=%s',(ident,));assert q.fetchone()==('mort',0,None)
  q.execute('SELECT etat_final FROM batailles_engagements WHERE id=%s',(eng,));assert q.fetchone()[0]=='mort'
  q.execute("SELECT count(*) FROM pnj_evenements WHERE pnj_id=%s AND type='mort'",(ident,));assert q.fetchone()[0]==1
  q.execute("SELECT pnj_miroir_compagnie('cie'),pnj_miroir_police('republic','capitale','commissariat'),pnj_miroir_douane('republic','ville_a','port-sainte-marie')")
  q.execute('SELECT statut FROM pnj_membres WHERE id=%s',(ident,));assert q.fetchone()[0]=='mort'
 for ident in ['ancre','douane-republic-ville_a-D1','police-republic-capitale-P1','cie-S1']:
  cas('bataille_mort_au_socle_'+ident,lambda ident=ident:chute(ident))
 def repli():
  decor()
  q.execute("UPDATE batailles_groupes SET repli='{\"ville\":\"caserne\",\"batiment\":\"caserne-militaire\",\"piece\":\"corps_garde\"}' WHERE bataille_id=71")
  q.execute("SELECT leader FROM batailles_groupes WHERE bataille_id=71 AND groupe_id='republic|pj:A'");assert q.fetchone()[0]=='A'
  q.execute("SELECT count(*) FROM batailles_engagements WHERE bataille_id=71 AND camp='republic'");n=q.fetchone()[0]
  exige(rpc('militaire_bataille_decider',(71,'replier'),qui='A'))
  q.execute("SELECT count(*) FROM batailles_engagements WHERE bataille_id=71 AND camp='republic' AND etat_final='replie'");assert q.fetchone()[0]==n
  q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND current_city='caserne'");assert q.fetchone()[0]==2
  q.execute("SELECT count(*) FROM batailles_engagements e CROSS JOIN LATERAL pnj_position_effective(e.pnj_id) pe WHERE e.bataille_id=71 AND e.camp='republic' AND e.pnj_id IS NOT NULL AND pe.ville='caserne'");assert q.fetchone()[0]==n-2
  q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('C','D') AND current_city='capitale'");assert q.fetchone()[0]==2
 cas('bataille_repli_meme_groupe_PJ_PNJ_sans_entrainer_autre_camp',repli)
 def repli_refuse():
  decor();sql("UPDATE personnages_donnees SET est_emprisonne='{}' WHERE name='B'")
  q.execute("SELECT jsonb_agg(to_jsonb(d) ORDER BY name) FROM personnages_donnees d");avant=q.fetchone()[0]
  q.execute('SAVEPOINT repli_refuse')
  try:rpc('militaire_bataille_decider',(71,'replier'),qui='A')
  except Exception as exc:
   q.execute('ROLLBACK TO SAVEPOINT repli_refuse');assert 'repli_refuse' in str(exc),str(exc)
  else:raise AssertionError('un détenu a suivi le repli')
  q.execute("SELECT jsonb_agg(to_jsonb(d) ORDER BY name) FROM personnages_donnees d");assert q.fetchone()[0]==avant
  q.execute("SELECT count(*) FROM batailles_engagements WHERE bataille_id=71 AND sorti_round IS NOT NULL");assert q.fetchone()[0]==0
 cas('bataille_repli_refus_detenu_annule_positions_et_sorties',repli_refuse)
 def neutralise():
  decor();q.execute("SELECT id FROM batailles_engagements WHERE bataille_id=71 AND personnage='A'");eng=q.fetchone()[0]
  import json
  action={'degre':'critique','mode':'cac','cib_eng':eng,'cib_camp':'republic','cib_pj':True,'cib_nom':'A'}
  q.execute('SELECT militaire_bataille_appliquer(71,%s::jsonb,1)',(json.dumps([action]),))
  q.execute("SELECT pa,current_city FROM personnages_donnees WHERE name='A'");assert q.fetchone()==(0,'caserne')
  q.execute("SELECT current_city FROM personnages_donnees WHERE name='B'");assert q.fetchone()[0]=='capitale'
  q.execute("SELECT count(*) FROM groupes_pj_adhesions WHERE chef='A' OR membre='A'");assert q.fetchone()[0]==0
  q.execute("SELECT leader_pj,ville FROM pnj_membres WHERE id='ancre'");assert q.fetchone()==(None,'capitale')
 cas('bataille_chef_neutralise_seul_evacue_et_groupes_separes',neutralise)
 def pas_de_retrait_pnj():
  decor();exige(rpc('pnj_quitter_groupe',(['ancre'],),qui='A'),'combat_en_cours')
 cas('bataille_garde_PNJ_non_militaire_interdit_evasion',pas_de_retrait_pnj)
 ctx['bataille_mixte_decor']=decor
 ctx['preuves_extension']['bataille_mixte']='Vrais métiers conservés ; recrutement, round militaire réel, rapports ; bornes terminales testées séparément par helper privé.'
 if suivante is not None:suivante(ctx)
def lancer(suivante=None):return e.lancer(lambda ctx:suite(ctx,suivante))
if __name__=='__main__':sys.exit(lancer())
