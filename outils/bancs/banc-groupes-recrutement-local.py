#!/usr/bin/env python3
"""Sélection canonique et anti-évasion, à la suite des vrais rounds policiers.
PostgreSQL jetable uniquement ; mutations de chaque scénario annulées.
"""
import importlib.util,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('police_native',R/'outils/bancs/banc-groupes-police-native-local.py');p=importlib.util.module_from_spec(sp);sp.loader.exec_module(p)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 selection=R/'migrations/20261029110000_groupes_recrutement_combattants.sql'
 garde=R/'migrations/20261029110100_groupes_composition_sous_confrontation.sql'
 militaire=R/'migrations/20261029110200_militaire_recrutement_presence_et_etat.sql'
 q.execute(selection.read_text())
 if '--contre-composition' not in sys.argv:q.execute(garde.read_text());q.execute(garde.read_text())
 if '--contre-recrutement-militaire' not in sys.argv:q.execute(militaire.read_text());q.execute(militaire.read_text())
 if '--contre-etat-police' not in sys.argv:q.execute((R/'migrations/20261029110300_police_combattant_etat_canonique.sql').read_text())
 ctx['c'].commit()
 def liste():
  q.execute("SELECT cle,pa FROM groupe_combattants_interne('B')")
  return dict(q.fetchall())
 def groupe():
  noms=liste();assert {'pj:A','pj:B'}<=noms.keys(),noms
  assert 'pj:C' not in noms and 'pj:D' not in noms,noms
  assert all('pnj:cie-S'+str(i) in noms for i in range(1,5)),noms
  assert all('pnj:police-republic-capitale-P'+str(i) in noms for i in range(1,4)),noms
  assert len(noms)==9,noms
 cas('recrutement_groupe_reel_2PJ_4soldats_3policiers_sans_tiers',groupe)
 def absent():
  # Les soldats sont prêtés à B, pas à leur propriétaire A. Déplacer A ne
  # doit pas les retirer du combat de B. Seul S1 est remis à A dans ce cas.
  sql("UPDATE pnj_membres SET leader_pj='A' WHERE id='cie-S1'")
  sql("UPDATE personnages_donnees SET current_room='autre' WHERE name='A'")
  noms=liste();assert 'pj:A' not in noms and 'pnj:cie-S1' not in noms and 'pnj:cie-S2' in noms,noms
 cas('recrutement_absent_et_ses_suiveurs_non_participants',absent)
 for champ,val in [('pa','0'),('hp','0'),('est_emprisonne',"'{\"ville\":\"capitale\"}'::jsonb"),('hospitalisation',"'{\"jourFin\":999}'::jsonb")]:
  def indisponible(champ=champ,val=val):
   sql('UPDATE personnages_donnees SET '+champ+'='+val+" WHERE name='A'")
   assert 'pj:A' not in liste()
  cas('recrutement_PJ_exclu_'+champ,indisponible)
 def statuts():
  sql("UPDATE pnj_membres SET statut='detenu' WHERE id='police-republic-capitale-P1'")
  sql("UPDATE pnj_membres SET statut='mort',leader_pj=NULL,leader_pnj_id=NULL,ville='capitale',building_id='mairie',room_id='accueil' WHERE id='police-republic-capitale-P3'")
  sql("UPDATE pnj_membres SET pa=0 WHERE id='cie-S1'")
  noms=liste();assert not {'pnj:police-republic-capitale-P1','pnj:police-republic-capitale-P3','pnj:cie-S1'}&noms.keys(),noms
 cas('recrutement_PNJ_morts_detenus_sans_PA_exclus',statuts)
 def rencontre():
  sql("INSERT INTO police_interceptions(personnage,rencontre,country,city,building,room,expires_at) VALUES('A','rencontre-fixture','republic','capitale','mairie','accueil',now()+interval '10 minutes')")
 def confrontation():
  rencontre();assert 'pj:A' not in liste()
  q.execute("SELECT cle FROM groupe_combattants_interne('B','rencontre-fixture')")
  assert 'pj:A' in [x[0] for x in q.fetchall()]
 cas('recrutement_interception_uniquement_rencontre_concernee',confrontation)
 def quitter(qui):
  rencontre();q.execute('SELECT jsonb_agg(to_jsonb(g)) FROM groupes_pj_adhesions g');avant=q.fetchone()[0]
  exige(rpc('groupe_pj_quitter',(),qui=qui),'interception_en_cours')
  q.execute('SELECT jsonb_agg(to_jsonb(g)) FROM groupes_pj_adhesions g');assert q.fetchone()[0]==avant
 for qui in ['A','B']:cas('interception_interdit_depart_groupe_'+qui,lambda qui=qui:quitter(qui))
 def rejoindre():
  rencontre();exige(rpc('groupe_pj_rejoindre',('B',),qui='C'),'interception_en_cours')
 cas('interception_interdit_nouveau_membre',rejoindre)
 for fn,args in [('pnj_quitter_groupe',(['police-republic-capitale-P1'],)),('pnj_transferer',(['police-republic-capitale-P1'],'C',False)),('pnj_deployer_unite',(['police-republic-capitale-P1'],True))]:
  def deplacer(fn=fn,args=args):
   rencontre();exige(rpc(fn,args,qui='B'),'interception_en_cours')
   q.execute("SELECT leader_pj FROM pnj_membres WHERE id='police-republic-capitale-P1'");assert q.fetchone()[0]=='B'
  cas('interception_interdit_'+fn,deplacer)
 def force():
  sql("INSERT INTO police_interceptions(personnage,rencontre,country,city,building,room,expires_at,intervenants) VALUES('C','rencontre-force','republic','capitale','mairie','accueil',now()+interval '10 minutes','[\"P1\"]')")
  exige(rpc('pnj_quitter_groupe',(['police-republic-capitale-P1'],),qui='B'),'interception_en_cours')
 cas('interception_interdit_retirer_force_policier_selectionne',force)
 def droits():
  q.execute("SELECT has_function_privilege('authenticated','groupe_combattants_interne(text,text,bigint)','EXECUTE')");assert not q.fetchone()[0]
 cas('recrutement_porte_interne_inaccessible_au_navigateur',droits)
 def decor_militaire():
  sql("UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='hotel-republica',current_room='bar',current_street=NULL,pa=100,hp=100 WHERE name IN ('A','B','C')")
  sql("INSERT INTO services_militaires(personnage,pays,grade) VALUES('C','soviet','soldat')")
  sql("INSERT INTO guerres(id,statut,data) VALUES('guerre-recrutement','active','{\"attaquant\":\"republic\",\"attaque\":\"soviet\"}')")
  sql("INSERT INTO batailles(id,pays,ville,batiment,piece,camp_a,camp_b,initiative,leader_a,leader_b) VALUES(51,'republic','capitale','hotel-republica','bar','republic','soviet','simultane','A','C')")
 def recruter():
  q.execute("SELECT militaire_bataille_recruter(51,'republic','capitale','hotel-republica','bar'),militaire_bataille_recruter(51,'soviet','capitale','hotel-republica','bar')")
 def round_reel():
  decor_militaire();recruter()
  q.execute("SELECT personnage,camp FROM batailles_engagements WHERE bataille_id=51 AND personnage IS NOT NULL ORDER BY personnage")
  assert q.fetchall()==[('A','republic'),('C','soviet')],'Pays physique confondu avec le camp militaire'
  q.execute("SELECT militaire_bataille_groupes_constituer(51)")
  v=exige(rpc('militaire_bataille_poursuivre',(51,)));assert v['round']==1,v
  q.execute('SELECT count(*) FROM batailles_rounds WHERE bataille_id=51');assert q.fetchone()[0]==2
 cas('round_militaire_reel_deux_camps_physiquement_presents_meme_pays',round_reel)
 for champ,val in [('hp','0'),('est_emprisonne',"'{\"ville\":\"capitale\"}'::jsonb"),('hospitalisation',"'{\"jourFin\":999}'::jsonb")]:
  def non_participant(champ=champ,val=val):
   decor_militaire();sql('UPDATE personnages_donnees SET '+champ+'='+val+" WHERE name='A'")
   recruter();q.execute("SELECT count(*) FROM batailles_engagements WHERE bataille_id=51 AND personnage='A'");assert q.fetchone()[0]==0
  cas('recrutement_militaire_exclut_PJ_'+champ,non_participant)
 def interception_militaire():
  decor_militaire();rencontre();recruter()
  q.execute("SELECT count(*) FROM batailles_engagements WHERE bataille_id=51 AND personnage='A'");assert q.fetchone()[0]==0
 cas('recrutement_militaire_interception_prioritaire',interception_militaire)
 def pnj_etranger():
  decor_militaire()
  # Origine républicaine conservée, lieu effectif soviétique : pas sur ce champ.
  sql("UPDATE personnages_donnees SET country='soviet' WHERE name='B'")
  recruter();q.execute('SELECT count(*) FROM batailles_engagements WHERE bataille_id=51 AND matricule IS NOT NULL');assert q.fetchone()[0]==0
 cas('recrutement_militaire_PNJ_presence_physique_pas_origine',pnj_etranger)
 cas('rounds_police_reels_apres_raccordement_selection_et_rejeu',ctx['police_deux_rounds_reels'])
 for champ,val in [('hp','0'),('est_emprisonne',"'{\"ville\":\"capitale\"}'::jsonb"),('hospitalisation',"'{\"jourFin\":999}'::jsonb")]:
  def police_etat(champ=champ,val=val):
   sql("UPDATE personnages_donnees SET current_city='capitale',current_building='mairie',current_room='accueil',current_street=NULL,"+champ+'='+val+" WHERE name='C'")
   q.execute("SELECT to_jsonb(d) FROM personnages_donnees d WHERE name='C'");avant=q.fetchone()[0]
   exige(rpc('police_combat_resoudre',('rencontre-fixture',None,'mairie','accueil',1),qui='C'),'joueur_indisponible')
   q.execute("SELECT to_jsonb(d) FROM personnages_donnees d WHERE name='C'");assert q.fetchone()[0]==avant
  cas('police_refus_avant_coups_et_mutations_'+champ,police_etat)
 def verrou_graphe():
  import psycopg2,time
  from concurrent.futures import ThreadPoolExecutor
  un=psycopg2.connect(ctx['serveur'].get_uri());deux=psycopg2.connect(ctx['serveur'].get_uri())
  try:
   un.cursor().execute("SELECT pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0))")
   cur=deux.cursor();cur.execute("SET statement_timeout='5s'")
   with ThreadPoolExecutor(1) as pool:
    fut=pool.submit(rpc,'pnj_prendre',(['police-republic-capitale-P1'],),'B',cur)
    limite=time.monotonic()+3;attend=False
    while time.monotonic()<limite:
     q.execute('SELECT pg_stat_clear_snapshot()');q.execute('SELECT wait_event_type FROM pg_stat_activity WHERE pid=%s',(deux.get_backend_pid(),))
     ligne=q.fetchone()
     if ligne and ligne[0]=='Lock':attend=True;break
     if fut.done():break
     time.sleep(.02)
    assert attend,'absence de sérialisation des compositions'
    un.rollback();exige(fut.result(timeout=6))
  finally:un.rollback();deux.rollback();un.close();deux.close()
 cas('prise_PNJ_concurrente_serialisee_graphe_entre_deux_sessions',verrou_graphe)
 ctx['preuves_extension']['recrutement']='Lecteur privé du groupe canonique et gardes de composition. Ne prouve pas encore les rounds mixtes universels ni la reddition collective.'
 if suivante is not None:suivante(ctx)
if __name__=='__main__':sys.exit(p.v.d.i.lancer(lambda c:p.v.d.suite(c,lambda c:p.v.suite(c,lambda c:p.suite(c,suite)))))
