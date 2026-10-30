#!/usr/bin/env python3
"""Ordres d'effectifs authentifiés, paiement et miroir dans une transaction."""
import importlib.util,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('militaire',R/'outils/bancs/banc-groupes-miroir-militaire-local.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 ctx['installer_fonction_canonique']('douane_caracteristiques_metier')
 sp_a=importlib.util.spec_from_file_location('audit',R/'outils/bancs/banc-audit-securite-135-local.py');a=importlib.util.module_from_spec(sp_a);sp_a.loader.exec_module(a)
 q.execute(a.fonction('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','batiment_etat_sous_cle_ecrire'))
 sql("INSERT INTO postes_attribues(id,country,poste_id,city,titulaire,source) VALUES('chef-D-fixture','republic','chef_douanes',NULL,'D','fixture') ON CONFLICT DO NOTHING")
 q.execute((R/'migrations/20261029131000_effectifs_recrutement_et_licenciement_atomiques.sql').read_text())
 if '--contre-document-effectifs' in sys.argv:
  # Retire la protection, jamais le scénario : l'écriture brute doit alors
  # être acceptée et rendre rouge le même test de sécurité.
  q.execute('ALTER TABLE batiments_etat DISABLE TRIGGER effectifs_ecriture_metier')
 ctx['c'].commit()
 requete=lambda n:f'00000000-0000-4000-8000-{n:012d}'
 def photo():
  q.execute("SELECT jsonb_agg(to_jsonb(t) ORDER BY name) FROM personnages_donnees t");a=q.fetchone()[0]
  q.execute("SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM batiments_etat t");b=q.fetchone()[0]
  q.execute("SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM pnj_membres t");return a,b,q.fetchone()[0]
 def preparer(service):
  sql("UPDATE personnages_donnees SET hp=100,pa=12,country='republic',current_city='capitale',current_building='mairie',current_room='accueil',current_street=NULL WHERE name='B'")
  if service=='douane':
   sql("UPDATE postes_attribues SET titulaire='B' WHERE id='chef-D-fixture'")
 def recruter(service,typ):
  preparer(service);ident=requete(9901)
  v=exige(rpc('force_publique_effectif_acte',(service,'recruter',typ,None,ident),qui='B'))
  q.execute("SELECT pa FROM personnages_donnees WHERE name='B'");assert q.fetchone()[0]==11
  q.execute("SELECT count(*) FROM pnj_membres WHERE nom=%s AND proprietaire_institution=%s",(v['matricule'],service));assert q.fetchone()[0]==1
  avant=photo();assert rpc('force_publique_effectif_acte',(service,'recruter',typ,None,ident),qui='B')==v;assert photo()==avant
  exige(rpc('force_publique_effectif_acte',(service,'recruter','autre',None,ident),qui='B'),'parametres_invalides');assert photo()==avant
 for service in ['police','douane']:
  for typ in ['standard','cynophile']:cas('effectif_'+service+'_'+typ+'_paiement_unique_miroir_rejeu',lambda service=service,typ=typ:recruter(service,typ))
 def sans_pa():
  preparer('police');sql("UPDATE personnages_donnees SET pa=0 WHERE name='B'");avant=photo()
  v=rpc('force_publique_effectif_acte',('police','recruter','standard',None,requete(9902)),qui='B')
  assert not v.get('ok'),v;assert photo()==avant
 cas('effectif_sans_PA_aucune_naissance',sans_pa)
 def sans_droits():
  avant=photo();exige(rpc('force_publique_effectif_acte',('police','recruter','standard',None,requete(9903)),qui='D'),'autorite_insuffisante');assert photo()==avant
 cas('effectif_cache_ne_donne_pas_mandat',sans_droits)
 def ancien():
  avant=photo()
  exige(rpc('batiment_etat_sous_cle_ecrire',('republic','capitale','commissariat','effectifsPolice','{"policiers":[]}'),qui='B'),'operation_atomique_requise')
  exige(rpc('payer_ordre',('B','recruter_policier',1,0),qui='B'),'operation_atomique_requise');assert photo()==avant
 cas('effectif_ancien_document_et_paiement_isole_refuses_sans_debit',ancien)
 def brut():
  sql('GRANT SELECT,UPDATE ON batiments_etat TO authenticated')
  q.execute('SAVEPOINT ancien_document')
  try:
   q.execute("SELECT set_config('role','authenticated',true),set_config('request.path','/rpc/force_publique_effectif_acte',true)")
   q.execute("UPDATE batiments_etat SET data=jsonb_set(data,'{effectifsPolice,policiers}','[]') WHERE id='capitale'")
  except Exception as exc:
   q.execute('ROLLBACK TO SAVEPOINT ancien_document');assert 'effectifs_ecriture_metier_requise' in str(exc),str(exc)
  else:q.execute('ROLLBACK TO SAVEPOINT ancien_document');raise AssertionError('liste directe acceptée')
 cas('effectif_document_brut_et_chemin_falsifie_refuses',brut)
 def licencier():
  preparer('douane')
  q.execute("SELECT to_jsonb(pe) FROM pnj_position_effective('douane-republic-ville_a-D1') pe");avant=q.fetchone()[0]
  v=exige(rpc('force_publique_effectif_acte',('douane','licencier',None,'D1',requete(9904)),qui='B'))
  q.execute("SELECT statut FROM pnj_membres WHERE id='douane-republic-ville_a-D1'");assert q.fetchone()[0]=='disparu'
  q.execute("SELECT to_jsonb(pe) FROM pnj_position_effective('douane-republic-ville_a-D1') pe");assert q.fetchone()[0]==avant
  p=photo();assert rpc('force_publique_effectif_acte',('douane','licencier',None,'D1',requete(9904)),qui='B')==v;assert photo()==p
 cas('effectif_licenciement_detache_sur_place_et_rejeu',licencier)
 def engage():
  preparer('douane')
  sql("UPDATE police_interceptions SET rencontre='douane-engagee',country='republic',city='ville_a',building='port-sainte-marie',room='douanes',expires_at=now()+interval '10min',combattants_forces='[\"pnj:douane-republic-ville_a-D1\"]' WHERE personnage='C'")
  avant=photo();exige(rpc('force_publique_effectif_acte',('douane','licencier',None,'D1',requete(9905)),qui='B'),'interception_en_cours');assert photo()==avant
 cas('effectif_PNJ_detache_engage_non_licenciable',engage)
 def panne():
  preparer('police');avant=photo()
  sql("CREATE FUNCTION panne_effectif_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_effectif_fixture';END$$;CREATE TRIGGER panne_effectif AFTER INSERT ON pnj_membres FOR EACH ROW EXECUTE FUNCTION panne_effectif_fixture()")
  q.execute('SAVEPOINT panne_apres_paiement')
  try:rpc('force_publique_effectif_acte',('police','recruter','standard',None,requete(9906)),qui='B')
  except Exception as exc:
   q.execute('ROLLBACK TO SAVEPOINT panne_apres_paiement');assert 'panne_effectif_fixture' in str(exc),str(exc)
  else:raise AssertionError('panne non rencontrée')
  assert photo()==avant
 cas('effectif_panne_creation_annule_aussi_paiement',panne)
 def vide_rejeu():
  sql("UPDATE batiments_etat SET data=jsonb_set(data,'{effectifsDouane,douaniers}','[]') WHERE building_id='port-sainte-marie'")
  q.execute((R/'migrations/20261029131000_effectifs_recrutement_et_licenciement_atomiques.sql').read_text())
  q.execute("SELECT public.batiment_etat_lire(data)->'effectifsDouane'->'douaniers' FROM batiments_etat WHERE country='republic' AND building_id='port-sainte-marie'");assert q.fetchone()[0]==[]
 cas('effectif_douane_vide_non_reconstitue_au_rejeu',vide_rejeu)
 def concurrence():
  import psycopg2
  from threading import Barrier
  from concurrent.futures import ThreadPoolExecutor
  q.execute("SELECT count(*) FROM pnj_membres WHERE proprietaire_institution='police'");avant=q.fetchone()[0]
  barriere=Barrier(2)
  def executer():
   cn=psycopg2.connect(ctx['serveur'].get_uri())
   try:
    cur=cn.cursor();cur.execute("SET statement_timeout='15s'");barriere.wait(timeout=5)
    v=rpc('force_publique_effectif_acte',('police','recruter','standard',None,requete(9907)),qui='B',cur=cur)
    cn.commit();return v
   finally:cn.close()
  with ThreadPoolExecutor(2) as pool:
   a=pool.submit(executer);b=pool.submit(executer);un=exige(a.result(timeout=20));deux=exige(b.result(timeout=20))
  assert un==deux
  q.execute("SELECT count(*) FROM pnj_membres WHERE proprietaire_institution='police'");assert q.fetchone()[0]==avant+1
  q.execute("SELECT pa FROM personnages_donnees WHERE name='B'");assert q.fetchone()[0]==11
  q.execute("SELECT count(*) FROM navigation_requetes WHERE acteur='B' AND requete=%s",(requete(9907),));assert q.fetchone()[0]==1
 # Décor et ordres fictifs committés uniquement pour deux connexions locales.
 preparer('police');ctx['c'].commit()
 cas('effectif_concurrence_deux_sessions_un_recu_un_paiement',concurrence)
 ctx['preuves_extension']['effectifs']='Ordres métier entiers, source canonique des mandats, paie unique et reçu, miroir, licenciement sur place et refus en interception. Fermeture ancien document/paiement, panne aval annulée. Compte et ACL de décor uniquement.'
 if suivante is not None:suivante(ctx)
def lancer(suivante=None):return m.lancer(lambda ctx:suite(ctx,suivante))
if __name__=='__main__':sys.exit(lancer())
