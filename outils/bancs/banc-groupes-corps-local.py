#!/usr/bin/env python3
"""Extension du même banc : vrais soldats, resolveur de section, miroir et projecteur.
Sans simulation de déplacement serveur ni combat ; aucune écriture distante.
"""
import importlib.util,re,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('groupes',R/'outils/bancs/banc-groupes-universels-local.py');g=importlib.util.module_from_spec(sp);sp.loader.exec_module(g)

def extension(ctx, suite=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 a=g.audit
 tables=(R/'baseline/domaines/socle-PNJ/10_tables.sql').read_text()
 q.execute(re.search(r'CREATE TABLE public\.pnj_soldats_metier \(.*?\n\);',tables,re.S)[0])
 contraintes=(R/'baseline/domaines/socle-PNJ/30_contraintes.sql').read_text()
 for nom in ['pnj_soldats_metier_pkey','pnj_soldats_section_dans_sa_compagnie','soldat_reserve_coherente','pnj_soldats_metier_pnj_id_fkey']:
  q.execute(re.search(r'ALTER TABLE public.pnj_soldats_metier ADD CONSTRAINT '+nom+r' .*?;',contraintes,re.S)[0])
 q.execute('ALTER TABLE personnages_donnees ADD COLUMN poste jsonb')
 q.execute("UPDATE personnages_donnees SET poste='{\"id\":\"commissaire\",\"city\":\"capitale\"}' WHERE name='B';UPDATE personnages_donnees SET poste='{\"id\":\"commissaire\",\"city\":\"ville_a\"}' WHERE name='C'")
 q.execute("INSERT INTO pnj_institutions VALUES('militaire','militaire_autorite_de_perimetre','resolveur reel')")
 for f,nom in [('militaire/20_fonctions-1.sql','militaire_autorite_de_perimetre'),('militaire/20_fonctions-1.sql','militaire_blob_projeter'),('socle-PNJ/20_fonctions.sql','pnj_miroir_possessions_si_axe_blob'),('socle-PNJ/20_fonctions.sql','pnj_miroir_compagnie'),('socle-PNJ/20_fonctions.sql','pnj_miroir_compagnie_trg')]:
  q.execute(a.fonction('baseline/domaines/'+f,nom))
 q.execute("CREATE TRIGGER miroir_compagnie AFTER INSERT OR UPDATE ON compagnies_militaires FOR EACH ROW EXECUTE FUNCTION pnj_miroir_compagnie_trg()")
 # A est le lieutenant ; B sera le chef emprunteur. Aucun propriétaire PJ fabriqué.
 q.execute("INSERT INTO compagnies_militaires VALUES('cie','{\"pays\":\"republic\",\"autre\":99,\"sections\":[{\"id\":\"cie-s1\",\"lieutenantNom\":\"A\",\"soldats\":[{\"matricule\":\"S1\",\"ville\":\"capitale\",\"buildingId\":\"mairie\",\"roomId\":\"accueil\",\"pa\":12},{\"matricule\":\"S2\",\"ville\":\"capitale\",\"buildingId\":\"mairie\",\"roomId\":\"accueil\",\"pa\":12},{\"matricule\":\"S3\",\"ville\":\"capitale\",\"buildingId\":\"mairie\",\"roomId\":\"accueil\",\"pa\":12},{\"matricule\":\"S4\",\"ville\":\"capitale\",\"buildingId\":\"mairie\",\"roomId\":\"accueil\",\"pa\":12}]}],\"reserve\":[]}')")
 # Déploiement commun réellement présent dans #216 ; même garde de hiérarchie.
 q.execute(a.fonction(a.M,'pnj_deployer_unite'))
 nouveau=(R/'migrations/20261031115746_groupes_soldats_projection_commune.sql').read_text()
 q.execute(a.fonction('baseline/domaines/socle-PNJ/20_fonctions.sql','pnj_membres_ici'))
 if '--contre-soldats' not in sys.argv:
  q.execute(nouveau);q.execute(nouveau)
  cap=(R/'migrations/20261031115747_groupes_capacite_conduite_serveur.sql').read_text();q.execute(cap);q.execute(cap)
 q.execute(a.fonction('baseline/domaines/militaire/20_fonctions-2.sql','militaire_section_de_moi'))
 for nom in ['militaire_deposer_soldats','militaire_recuperer_soldats']:
  q.execute(a.fonction('baseline/domaines/militaire/20_fonctions-2.sql',nom))
 q.execute(a.fonction('baseline/domaines/militaire/20_fonctions-1.sql','militaire_affecter_leader'))
 if '--contre-soldats' not in sys.argv:
  adapt=(R/'migrations/20261031115748_groupes_ordres_militaires_adaptateurs.sql').read_text();q.execute(adapt);q.execute(adapt)
 # Seul le décor et le DDL fictifs sont committés pour les deux connexions.
 ctx['c'].commit()
 ids=['cie-S1','cie-S2','cie-S3','cie-S4']
 def etat():
  q.execute("SELECT data FROM compagnies_militaires WHERE id='cie'");return q.fetchone()[0]
 def proprietes():
  q.execute("SELECT id,proprietaire_pj,proprietaire_institution,proprietaire_perimetre FROM pnj_membres WHERE famille='soldat' ORDER BY id");return q.fetchall()
 def pret():
  q.execute("SELECT poste->>'id' FROM personnages_donnees WHERE name='B'");assert q.fetchone()[0]=='commissaire'
  avant=proprietes();exige(rpc('pnj_prendre',(ids,)));exige(rpc('pnj_transferer',(ids,'B',False)))
  assert proprietes()==avant
  b=etat();assert b['autre']==99 and all(x['leaderCourant']=='B' for x in b['sections'][0]['soldats']),b
  exige(rpc('pnj_quitter_groupe',(['cie-S1'],),qui='B'))
  exige(rpc('pnj_prendre',(['cie-S1'],),qui='B'),'autorite_insuffisante')
  exige(rpc('pnj_prendre',(['cie-S1'],)))
  assert proprietes()==avant
 cas('vrais_soldats_section_pret_depose_reprise_autorite',pret)
 def rue():
  exige(rpc('pnj_prendre',(ids,)));sql("UPDATE personnages_donnees SET current_building=NULL,current_room=NULL,current_street='rue-fixture' WHERE name='A'")
  exige(rpc('pnj_deployer_unite',(ids,True)))
  b=etat();assert all(x['rueNoeudId']=='rue-fixture' and x['buildingId'] is None for x in b['sections'][0]['soldats']),b
  exige(rpc('pnj_prendre',(ids,)))
  assert all(x['leaderCourant']=='A' and x['ville'] is None for x in etat()['sections'][0]['soldats'])
 cas('vrais_soldats_groupe_detache_rue_et_projection',rue)
 def radio():
  exige(rpc('pnj_prendre',(ids,)));exige(rpc('pnj_deployer_unite',(ids,True)))
  sql("INSERT INTO pnj_possessions(pnj_id,objet) VALUES('cie-S4','{\"produitMilitaire\":\"radio\"}')")
  sql("UPDATE personnages_donnees SET current_building='bar',current_room='salle' WHERE name='A'")
  r=exige(rpc('pnj_rappeler_radio',('cie-S1',)));assert r['rappeles']==4
  assert all(x['leaderCourant']=='A' for x in etat()['sections'][0]['soldats'])
  exige(rpc('pnj_rappeler_radio',('cie-S1',)))
 cas('vrais_soldats_radio_collective_et_rejeu',radio)
 def anciens_ordres():
  exige(rpc('pnj_prendre',(ids,)))
  exige(rpc('militaire_deposer_soldats',('cie','cie-s1',4)))
  exige(rpc('militaire_recuperer_soldats',('cie','cie-s1',4)))
  exige(rpc('militaire_affecter_leader',('cie','cie-s1',4,'B')))
  assert all(x['leaderCourant']=='B' for x in etat()['sections'][0]['soldats'])
 cas('ordres_historiques_par_nombre_deleguent_aux_portes_communes',anciens_ordres)
 def ancienne_reprise_ancre():
  exige(rpc('pnj_prendre',(ids,)));exige(rpc('pnj_deployer_unite',(ids,True)))
  exige(rpc('militaire_recuperer_soldats',('cie','cie-s1',1)),'unite_incomplete')
  exige(rpc('militaire_recuperer_soldats',('cie','cie-s1',4)))
 cas('ordre_par_nombre_reprend_unite_liee_sans_violer_hierarchie',ancienne_reprise_ancre)

 def panne():
  sql("CREATE FUNCTION panne_projection() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_projection_fixture';END$$;CREATE TRIGGER panne BEFORE UPDATE ON compagnies_militaires FOR EACH ROW EXECUTE FUNCTION panne_projection()")
  q.execute("SELECT to_jsonb(m) FROM pnj_membres m WHERE id='cie-S1'");avant=q.fetchone()[0]
  sql('SAVEPOINT avant_panne')
  try:rpc('pnj_prendre',(['cie-S1'],));raise AssertionError('projection non appelee')
  except Exception as e:
   assert 'panne_projection_fixture' in str(e),e
   sql('ROLLBACK TO SAVEPOINT avant_panne')
  q.execute("SELECT to_jsonb(m) FROM pnj_membres m WHERE id='cie-S1'");assert q.fetchone()[0]==avant
 cas('panne_projecteur_annule_prise_soldat',panne)
 def droits():
  for nom in ['pnj_groupes_verrouiller_projections_interne(text[])','pnj_groupes_projeter_interne(text[])']:
   for role in ['anon','authenticated','service_role']:
    q.execute("SELECT has_function_privilege(%s,%s,'EXECUTE')",(role,nom));assert q.fetchone()[0] is False
 cas('adaptateurs_projection_injoignables_du_reseau',droits)
 def capacite():
  v=exige(rpc('pnj_membres_ici',('republic','capitale','mairie','accueil',None)))
  soldats=[m for m in v['membres'] if m['famille']=='soldat']
  assert len(soldats)==4 and all(m.get('mouvement_individuel') is True for m in soldats),v
 cas('capacite_soldat_confirmee_par_les_gardes_serveur',capacite)
 def verrou_compagnie():
  import psycopg2,time
  from concurrent.futures import ThreadPoolExecutor
  un=psycopg2.connect(ctx['serveur'].get_uri());deux=psycopg2.connect(ctx['serveur'].get_uri());trois=psycopg2.connect(ctx['serveur'].get_uri())
  try:
   for cc in [un,deux,trois]:cc.cursor().execute("SET statement_timeout='5s'")
   un.cursor().execute("SELECT id FROM compagnies_militaires WHERE id='cie' FOR UPDATE")
   with ThreadPoolExecutor(1) as pool:
    fut=pool.submit(rpc,'pnj_prendre',(['cie-S1'],),'A',deux.cursor())
    limite=time.monotonic()+3;attend=False
    while time.monotonic()<limite:
     q.execute('SELECT pg_stat_clear_snapshot()');q.execute("SELECT wait_event_type FROM pg_stat_activity WHERE pid=%s",(deux.get_backend_pid(),))
     ligne=q.fetchone()
     if ligne and ligne[0]=='Lock':attend=True;break
     if fut.done():break
     time.sleep(.02)
    assert attend,'aucun verrou de compagnie observé'
    # L'acteur n'est pas verrouillé avant la compagnie : évite l'inversion.
    try:trois.cursor().execute("SELECT name FROM personnages_donnees WHERE name='A' FOR UPDATE NOWAIT")
    finally:trois.rollback();un.rollback()
    exige(fut.result(timeout=7))
  finally:un.rollback();deux.rollback();trois.rollback();un.close();deux.close();trois.close()
 cas('compagnie_verrouillee_avant_acteur_commun',verrou_compagnie)
 # Vraies structures policières, sans les ouvrir artificiellement aux groupes.

 for nom in ['pnj_force_publique_metier','pnj_metiers_profils']:
  q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',tables,re.S)[0])
  q.execute(re.search(r'ALTER TABLE public\.'+nom+' ADD CONSTRAINT '+nom+r'_pkey .*?;',contraintes,re.S)[0])
 q.execute((R/'baseline/seeds/90_socle/pnj_metiers_profils.sql').read_text())
 etat=(R/'baseline/domaines/immobilier-et-territoire/10_tables.sql').read_text()
 q.execute(re.search(r'CREATE TABLE public\.batiments_etat \(.*?\n\);',etat,re.S)[0])
 for f,nom in [('socle-PNJ/20_fonctions.sql','pnj_metier_profil'),('justice/20_fonctions-2.sql','police_autorite_de_perimetre'),('justice/20_fonctions-2.sql','police_pnj_id'),('justice/20_fonctions-2.sql','police_caracteristiques_metier'),('immobilier-et-territoire/20_fonctions.sql','batiment_etat_lire'),('socle-PNJ/20_fonctions.sql','pnj_miroir_police'),('socle-PNJ/20_fonctions.sql','pnj_miroir_police_declencheur')]:
  q.execute(a.fonction('baseline/domaines/'+f,nom))
 q.execute("INSERT INTO pnj_institutions VALUES('police','police_autorite_de_perimetre','resolveur reel')")
 if '--catalogue-20261029' in sys.argv:
  import json,hashlib
  vivant=next(x for x in json.loads((R/'outils/bancs/fixtures/groupes-catalogue-communique-20261029.json').read_text())['fonctions'] if x['nom']=='pnj_miroir_police')
  assert hashlib.sha256(vivant['sql'].encode()).hexdigest()==vivant['sha256'];q.execute(vivant['sql'])
  q.execute("SELECT md5(prosrc) FROM pg_proc WHERE oid='pnj_miroir_police(text,text,text)'::regprocedure");assert q.fetchone()[0]=='22e615ce9027190a6e592ac27644d8fe'
 q.execute("CREATE TRIGGER miroir_police AFTER INSERT OR UPDATE ON batiments_etat FOR EACH ROW EXECUTE FUNCTION pnj_miroir_police_declencheur()")
 for ville,bat,mat in [('capitale','commissariat',['P1','P2','P3']),('ville_a','commissariat-local',['E1'])]:
  import json
  agents=[{'matricule':m,'buildingId':'mairie','roomId':'accueil','type':'standard'} for m in mat]
  q.execute("INSERT INTO batiments_etat(id,country,city,building_id,data) VALUES(%s,'republic',%s,%s,%s::jsonb)",(ville,ville,bat,json.dumps({'effectifsPolice':{'policiers':agents},'autre':42})))
 def police_autorite():
  for matricule in ['P1','P2','P3']:
   assert rpc('pnj_peut_administrer',('B','police-republic-capitale-'+matricule)) is True
   assert rpc('pnj_peut_administrer',('C','police-republic-capitale-'+matricule)) is False
  assert rpc('pnj_peut_administrer',('B','police-republic-ville_a-E1')) is False
  assert rpc('pnj_peut_administrer',('C','police-republic-ville_a-E1')) is True
 cas('vrais_policiers_autorite_commissariat_territoriale',police_autorite)
 def police_miroir_bloquant():
  # Décor de diagnostic, PAS une prise de policier prétendument autorisée.
  sql("UPDATE pnj_membres SET leader_pj='B',ville=NULL,building_id=NULL,room_id=NULL,rue_noeud_id=NULL WHERE id='police-republic-capitale-P1';SAVEPOINT avant_miroir")
  import psycopg2
  try:
   q.execute("SELECT pnj_miroir_police('republic','capitale','commissariat')")
   raise AssertionError('le raccordement institutionnel ancien a changé : réexaminer le diagnostic')
  except psycopg2.errors.CheckViolation as e:
   assert e.diag.constraint_name=='pnj_position_deux_etats',e
   sql('ROLLBACK TO SAVEPOINT avant_miroir')
  q.execute("SELECT leader_pj,ville FROM pnj_membres WHERE id='police-republic-capitale-P1'");assert q.fetchone()==('B',None)
 cas('blocage_reproduit_miroir_police_et_groupe_ne_sont_pas_raccordes',police_miroir_bloquant)
 # Porte de combat originale, sans round simulé ni faux helper de combat.
 mt=(R/'baseline/domaines/militaire/10_tables.sql').read_text()
 for nom in ['services_militaires','batailles','guerres','mutineries','mutineries_membres']:
  q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',mt,re.S)[0])
 q.execute('ALTER TABLE personnages_donnees ADD COLUMN pa integer DEFAULT 12')
 q.execute("INSERT INTO services_militaires(personnage,pays,grade,compagnie_id,section_id) VALUES('A','republic','lieutenant','cie','cie-s1')")
 for nom in ['mutinerie_camp_de','mutinerie_est_camp','mutinerie_camps_presents']:
  q.execute(a.fonction('baseline/domaines/militaire/20_fonctions-3.sql',nom))
 q.execute(a.fonction('baseline/domaines/militaire/20_fonctions-1.sql','militaire_bataille_engager'))
 if '--contre-soldats' not in sys.argv:
  patch=(R/'migrations/20261031115749_groupes_bataille_pays_adverse.sql').read_text();q.execute(patch);q.execute(patch)
 cas('porte_bataille_sans_ennemi_refuse_sans_erreur_alias_ni_mutation',lambda:exige(rpc('militaire_bataille_engager'),'aucun_ennemi_ici'))
 cas('porte_bataille_conserve_refus_non_militaire',lambda:exige(rpc('militaire_bataille_engager',qui='C'),'pas_militaire'))
 def derive_refusee():
  q.execute("SELECT pg_get_functiondef('militaire_recuperer_soldats(text,text,integer)'::regprocedure)")
  ancien=q.fetchone()[0];q.execute(ancien.replace('BEGIN','BEGIN\n -- definition modifiee de fixture',1))
  q.execute('SAVEPOINT derive')
  try:
   q.execute((R/'migrations/20261031115748_groupes_ordres_militaires_adaptateurs.sql').read_text())
   raise AssertionError('ancienne porte inconnue remplacee')
  except Exception as e:
   assert 'ordre_militaire_definition_non_examinee' in str(e),e
   sql('ROLLBACK TO SAVEPOINT derive')
 cas('migration_refuse_porte_militaire_vivante_differente',derive_refusee)

 if suite is not None:suite(ctx)





if __name__=='__main__':sys.exit(g.main(extension))
