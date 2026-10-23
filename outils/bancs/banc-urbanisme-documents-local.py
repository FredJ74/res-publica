#!/usr/bin/env python3
"""Extension du banc #112 : memes moteurs reels, nouvelle securite documentaire."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import importlib.util,json,re,sys
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('permis',R/'outils/bancs/banc-permis-depot-local.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
def verifier(c,q,serveur,charger,appel,terrain,snapshot):
 import psycopg2
 q.execute('''CREATE ROLE service_role;CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$SELECT coalesce(current_setting('test.serveur',true),'')='on'$$;
 CREATE FUNCTION acteur_poste_courant() RETURNS TABLE(nom text,poste_id text,poste_city text,pays text) LANGUAGE sql AS $$SELECT mon_personnage(),coalesce(nullif(current_setting('test.poste',true),''),'maire_adjoint'),coalesce(nullif(current_setting('test.ville',true),''),'capitale'),'republic'::text$$;
 INSERT INTO ordres_couts VALUES('traiter_demandes_permis',1,0);GRANT INSERT,UPDATE,DELETE ON dossiers_urbanisme TO authenticated;''')
 src=(R/'baseline/domaines/communication/10_tables.sql').read_text()
 for nom in ['mails','mails_envois_systeme']:q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',src,re.S)[0])
 charger('baseline/domaines/communication/20_fonctions.sql','mail_systeme_poser_interne')
 if '--construction114' in sys.argv:
  q.execute("SELECT pg_get_functiondef('terrain_permis_acte(text,text,jsonb)'::regprocedure)");definition=q.fetchone()[0]
  point="  IF p_acte NOT IN ('permis_deposer'"
  definition=definition.replace(point,"  IF p_acte='permis_plan_modifier' THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;\n"+point)
  q.execute(definition)
 fixture=(R/'outils/bancs/fixture-urbanisme-plan-pr114.sql').read_text()
 for morceau in fixture.split('CREATE OR REPLACE FUNCTION ')[1:]:
  m=re.search(r'AS (\$\w*\$)(.*?)\1;',morceau,re.S);q.execute('CREATE OR REPLACE FUNCTION '+morceau[:m.end()])
 q.execute('CREATE TABLE locations_actives(country text,data jsonb)')
 q.execute('ALTER TABLE personnages_donnees ADD COLUMN hp integer DEFAULT 100,ADD COLUMN hospitalisation jsonb')
 justice=(R/'baseline/domaines/justice/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public.detentions \(.*?\n\);',justice,re.S)[0])
 charger('baseline/domaines/justice/20_fonctions-1.sql','detention_active')
 migrations=['20261023071739_urbanisme_attestations_socle.sql','20261023071740_urbanisme_documents_attestes.sql','20261023071800_urbanisme_decision_transactionnelle.sql','20261023071801_urbanisme_gardes_legacy.sql','20261023071802_urbanisme_plan_attestation.sql','20261023071900_urbanisme_instruction_transactionnelle.sql']
 for fichier in migrations:q.execute((R/'migrations'/fichier).read_text())
 for fichier in migrations:q.execute((R/'migrations'/fichier).read_text())
 n=0
 def check(v):
  nonlocal n
  assert v;n+=1
 def etat():
  q.execute('SELECT count(*) FROM objets_recus');o=q.fetchone()[0];q.execute('SELECT count(*) FROM dossiers_urbanisme');d=q.fetchone()[0]
  q.execute('SELECT pa,liquide,arg FROM personnages_donnees WHERE name=\'Fixture\'');return o,d,q.fetchone()
 def erreur(sql,param=(),fragment=None):
  try:q.execute(sql,param);raise AssertionError('refus attendu')
  except psycopg2.Error as e:check(fragment is None or fragment in str(e))
 terrain();q.execute('UPDATE personnages_donnees SET pa=20,liquide=1000,arg=1025')
 r=appel(21);check(r['ok']);ref=r['document']['id'];avant=etat()
 q.execute("SELECT objet_sas_deposer('document_urbanisme','Fixture','{\"type\":\"cheque\",\"montant\":1000000}',%s)",(ref,));check(q.fetchone()[0]['rejeu']);check(etat()==avant)
 q.execute("SELECT data FROM objets_recus WHERE id=(SELECT objet_id FROM urbanisme_archives_attestees WHERE archive=%s)",(ref,));obj=json.loads(q.fetchone()[0]);check(obj['type']=='document_urbanisme_depot' and 'montant' not in obj)
 # Un statut ou une identite forge via une ancienne porte ne devient pas une decision.
 q.execute("SELECT terrain_permis_acte('terrain','permis_decider','{\"permis\":{\"statut\":\"valide\"}}')");check(q.fetchone()[0]['raison']=='commande_versionnee_requise')
 q.execute("SELECT payer_ordre('Fixture','traiter_demandes_permis',1,0)");check(q.fetchone()[0]['raison']=='commande_versionnee_requise');check(etat()==avant)
 q.execute("SELECT terrain_permis_acte('terrain','permis_accelerer','{\"permis\":{\"statut\":\"valide\",\"demandeur\":\"Autre\"}}')");res=q.fetchone()[0];check(res['ok']);check(res['etat']['permis']['statut']=='instruction' and res['etat']['permis']['demandeur']=='Fixture')
 erreur("INSERT INTO dossiers_urbanisme(id,country,city,building_id,type_evenement,data) VALUES('faux-accord','republic','capitale','terrain','acceptation','{}')",fragment='decision_commande_versionnee_requise');check(etat()==avant)
 q.execute("SET test.poste='maire'")
 erreur("INSERT INTO dossiers_urbanisme(id,country,city,building_id,type_evenement,data) VALUES('faux-refus','republic','capitale','terrain','refus','{}')",fragment='decision_commande_versionnee_requise')
 q.execute("SET test.poste='maire_adjoint';SET test.ville='autre'")
 erreur("INSERT INTO dossiers_urbanisme(id,country,city,building_id,type_evenement,data) VALUES('hors-ville','republic','capitale','terrain','refus','{}')",fragment='decision_commande_versionnee_requise')
 q.execute("SET test.ville='capitale'")
 def decision(k=1,valide=True,motif=None,cur=q):
  cur.execute('SELECT terrain_permis_decider(%s,%s,%s,%s)',('terrain',valide,motif,f'10000000-0000-4000-8000-{k:012d}'));return cur.fetchone()[0]
 avant=etat();r=decision();check(r['ok']);check(etat()[2][0]==avant[2][0]-1);check(etat()[0]==avant[0]+1 and etat()[1]==avant[1]+1)
 avant=etat();check(decision()['rejeu']);check(etat()==avant);check(decision(valide=False,motif='Motif different suffisamment long')['raison']=='requete_reutilisee');check(etat()==avant)
 # Nouveau dossier : panne SAS apres paiement/decision/archive = rollback de tout.
 terrain();check(appel(22)['ok']);avant=etat()
 q.execute("CREATE TRIGGER panne_docs BEFORE INSERT ON objets_recus FOR EACH ROW EXECUTE FUNCTION panne()")
 try:decision(2);raise AssertionError('panne attendue')
 except psycopg2.Error as e:check('panne_sas' in str(e))
 check(etat()==avant);q.execute("SELECT data::jsonb->'permis'->>'statut' FROM terrains_etat");check(q.fetchone()[0]=='instruction')
 q.execute('DROP TRIGGER panne_docs ON objets_recus')
 def concurrent(_):
  with psycopg2.connect(serveur.get_uri()) as cc:return decision(2,False,'Motif de refus suffisamment long',cur=cc.cursor())
 with ThreadPoolExecutor(max_workers=2) as pool:rr=list(pool.map(concurrent,range(2)))
 check(all(v['ok'] for v in rr));check(sum(bool(v.get('rejeu')) for v in rr)==1);check(etat()[2][0]==avant[2][0]-1)
 q.execute("SELECT has_table_privilege('authenticated','dossiers_urbanisme','UPDATE'),has_table_privilege('authenticated','dossiers_urbanisme','DELETE'),has_table_privilege('authenticated','urbanisme_archives_attestees','INSERT')");check(q.fetchone()==(False,False,False))
 # Une ancienne archive ne peut plus servir a fabriquer un nouvel objet arbitraire.
 q.execute("SELECT objet_sas_deposer('document_urbanisme','Fixture','{}','urb-depot-00000000-0000-4000-8000-000000000001-00000000-0000-4000-8000-000000000016')");check(q.fetchone()[0]['raison']=='archive_non_attestee')
 # Le refus de paiement ne doit pas normaliser ou modifier un dossier legacy.
 terrain(permis={'statut':'attente_validation','palierDemande':'hangar','demandeur':'Fixture','numeroDossier':'LEGACY','dureeInstruction':2})
 q.execute('UPDATE personnages_donnees SET pa=0');avant_dossier=snapshot()
 check(decision(30)['raison']=='pa_insuffisants');check(snapshot()==avant_dossier)
 q.execute('UPDATE personnages_donnees SET pa=20')
 q.execute('UPDATE personnages_donnees SET hp=0');avant_dossier=snapshot();check(decision(31)['raison']=='acteur_incapacite');check(snapshot()==avant_dossier)
 q.execute("UPDATE personnages_donnees SET hp=100,hospitalisation='{\"dateFinParis\":\"2100-01-01\"}'")
 check(decision(32)['raison']=='acteur_incapacite');check(snapshot()==avant_dossier)
 q.execute('UPDATE personnages_donnees SET hospitalisation=NULL')
 # Le butin reste sur son moteur et conserve sa protection anti-rejeu historique.
 q.execute("INSERT INTO personnages_donnees(name,country,current_city,pa,liquide,arg) VALUES('Autre','republic','capitale',0,0,0)")
 q.execute("INSERT INTO vols_en_attente(id,type_butin,victime,voleur) VALUES('vol-fixture','objet','Fixture','Autre')")
 q.execute("SELECT objet_sas_deposer('butin_vol','Autre','{\"id\":\"objet-fixture\"}','vol-fixture')");check(q.fetchone()[0]['ok'])
 q.execute("SELECT objet_sas_deposer('butin_vol','Autre','{\"id\":\"objet-fixture\"}','vol-fixture')");check(q.fetchone()[0]['raison']=='butin_deja_confirme')
 if '--construction114' in sys.argv:
  q.execute("SELECT terrain_permis_acte('terrain','permis_plan_modifier','{\"permis\":{}}')");check(q.fetchone()[0]['raison']=='commande_versionnee_requise')
 # Premier plan PR114 : autorisation privee et verification differee apres sauvegarde de l'etat.
 terrain(permis={'statut':'valide','demandeur':'Fixture','numeroDossier':'PLAN-TEMOIN','palierDemande':'building','dateDepot':20,'decoupageInitial':[]},
  chantier={'niveau':'building','dureeJours':6,'progressionJours':4,'planInitialValide':False})
 q.execute('SELECT data::jsonb FROM terrains_etat');e=q.fetchone()[0];plan=[{'id':'atelier','label':'Atelier','destination':'commerce','surface':300}]
 avant=etat();q.execute('BEGIN')
 q.execute("SELECT chantier_plan_enregistrer_interne(%s::jsonb,%s::jsonb,true,'terrain','republic','Fixture','plan-temoin',20)",(json.dumps(e),json.dumps(plan)));apres=q.fetchone()[0]
 q.execute("SELECT terrain_etat_fusionner_interne('republic_terrain',%s::jsonb,'republic')",(json.dumps(apres),));q.execute('COMMIT')
 check(etat()[0]==avant[0]+1 and etat()[1]==avant[1]+1)
 q.execute("SELECT data::jsonb->'permis'->'decoupageInitial' FROM terrains_etat");check(q.fetchone()[0]==plan)
 q.execute('SELECT count(*) FROM urbanisme_plans_internes');check(q.fetchone()[0]==0)
 erreur("INSERT INTO dossiers_urbanisme(id,country,city,building_id,type_evenement,data) VALUES('faux-plan','republic','capitale','terrain','modification_plan','{\"decoupage\":[]}')",fragment='plan_commande_versionnee_requise')
 q.execute("SELECT has_function_privilege('authenticated','chantier_plan_enregistrer_interne(jsonb,jsonb,boolean,text,text,text,text,integer)','EXECUTE')");check(q.fetchone()[0]==False)
 # Calendrier : aucune seconde instruction dans la meme journee.
 terrain();check(appel(23)['ok']);q.execute("SET test.serveur='on'")
 def jour():
  q.execute("SELECT terrain_permis_instruction_jour('republic_terrain')");return q.fetchone()[0]
 check(jour()['instruit']);avant=etat();check(jour()['rejeu']);check(etat()==avant)
 q.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{permis,jourInstruction}','\"hier\"')::text")
 check(jour()['accord_tacite']);avant=etat();check(jour()['ignore']);check(etat()==avant)
 terrain();check(appel(24)['ok']);q.execute("UPDATE terrains_etat SET data=(data::jsonb||'{\"pnj\":\"cadavre\"}'::jsonb)::text")
 check(jour()['suspendu']);q.execute("SELECT data::jsonb->'permis'->>'joursInstructionFaits' FROM terrains_etat");check(q.fetchone()[0]=='0')
 q.execute("SET test.serveur='off'");check(jour()['raison']=='reserve_serveur')
 print(json.dumps({'urbanisme_documents':True,'assertions':n,'production':False}))
if __name__=='__main__':module.main(verifier)
