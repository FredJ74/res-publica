#!/usr/bin/env python3
"""Extension du même banc : vrais soldats, resolveur de section, miroir et projecteur.
Sans simulation de déplacement serveur ni combat ; aucune écriture distante.
"""
import importlib.util,re,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('groupes',R/'outils/bancs/banc-groupes-universels-local.py');g=importlib.util.module_from_spec(sp);sp.loader.exec_module(g)

def extension(ctx):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 a=g.audit
 tables=(R/'baseline/domaines/socle-PNJ/10_tables.sql').read_text()
 q.execute(re.search(r'CREATE TABLE public\.pnj_soldats_metier \(.*?\n\);',tables,re.S)[0])
 contraintes=(R/'baseline/domaines/socle-PNJ/30_contraintes.sql').read_text()
 for nom in ['pnj_soldats_metier_pkey','pnj_soldats_section_dans_sa_compagnie','soldat_reserve_coherente','pnj_soldats_metier_pnj_id_fkey']:
  q.execute(re.search(r'ALTER TABLE public.pnj_soldats_metier ADD CONSTRAINT '+nom+r' .*?;',contraintes,re.S)[0])
 q.execute("INSERT INTO pnj_institutions VALUES('militaire','militaire_autorite_de_perimetre','resolveur reel')")
 for f,nom in [('militaire/20_fonctions-1.sql','militaire_autorite_de_perimetre'),('militaire/20_fonctions-1.sql','militaire_blob_projeter'),('socle-PNJ/20_fonctions.sql','pnj_miroir_possessions_si_axe_blob'),('socle-PNJ/20_fonctions.sql','pnj_miroir_compagnie'),('socle-PNJ/20_fonctions.sql','pnj_miroir_compagnie_trg')]:
  q.execute(a.fonction('baseline/domaines/'+f,nom))
 q.execute("CREATE TRIGGER miroir_compagnie AFTER INSERT OR UPDATE ON compagnies_militaires FOR EACH ROW EXECUTE FUNCTION pnj_miroir_compagnie_trg()")
 # A est le lieutenant ; B sera le chef emprunteur. Aucun propriétaire PJ fabriqué.
 q.execute("INSERT INTO compagnies_militaires VALUES('cie','{\"pays\":\"republic\",\"autre\":99,\"sections\":[{\"id\":\"cie-s1\",\"lieutenantNom\":\"A\",\"soldats\":[{\"matricule\":\"S1\",\"ville\":\"capitale\",\"buildingId\":\"mairie\",\"roomId\":\"accueil\",\"pa\":12},{\"matricule\":\"S2\",\"ville\":\"capitale\",\"buildingId\":\"mairie\",\"roomId\":\"accueil\",\"pa\":12},{\"matricule\":\"S3\",\"ville\":\"capitale\",\"buildingId\":\"mairie\",\"roomId\":\"accueil\",\"pa\":12},{\"matricule\":\"S4\",\"ville\":\"capitale\",\"buildingId\":\"mairie\",\"roomId\":\"accueil\",\"pa\":12}]}],\"reserve\":[]}')")
 # Déploiement commun réellement présent dans #216 ; même garde de hiérarchie.
 q.execute(a.fonction(a.M,'pnj_deployer_unite'))
 nouveau=(R/'migrations/20261028161732_groupes_soldats_projection_commune.sql').read_text()
 q.execute(a.fonction('baseline/domaines/socle-PNJ/20_fonctions.sql','pnj_membres_ici'))
 if '--contre-soldats' not in sys.argv:
  q.execute(nouveau);q.execute(nouveau)
  cap=(R/'migrations/20261028163800_groupes_capacite_conduite_serveur.sql').read_text();q.execute(cap);q.execute(cap)
 # Seul le décor et le DDL fictifs sont committés pour les deux connexions.
 ctx['c'].commit()
 ids=['cie-S1','cie-S2','cie-S3','cie-S4']
 def etat():
  q.execute("SELECT data FROM compagnies_militaires WHERE id='cie'");return q.fetchone()[0]
 def proprietes():
  q.execute("SELECT id,proprietaire_pj,proprietaire_institution,proprietaire_perimetre FROM pnj_membres WHERE famille='soldat' ORDER BY id");return q.fetchall()
 def pret():
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


if __name__=='__main__':sys.exit(g.main(extension))
