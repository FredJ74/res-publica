#!/usr/bin/env python3
"""Direction réelle de fuite : même géographie, provenance serveur, pas un voisin au hasard."""
import importlib.util,sys,json,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('police',R/'outils/bancs/banc-groupes-police-cinq-rounds-local.py');c=importlib.util.module_from_spec(sp);sp.loader.exec_module(c)
def suite(ctx):
 c.suite(ctx)
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 for pattern in ['20261030223547_navigation_provenance_et_destination_fuite.sql','20261030223548_navigation_directions_reference.sql','20261030223549_navigation_directions_reference.sql','20261030223550_navigation_directions_reference.sql','20261030223551_navigation_directions_reference.sql','20261030223552_navigation_directions_reference.sql','20261030223553_navigation_directions_reference.sql','20261030223554_police_fuite_direction_commune.sql','20261030223555_police_controles_chef_et_fuite_reelle.sql']:
  for f in sorted((R/'migrations').glob(pattern)):
   q.execute(f.read_text());q.execute(f.read_text())
 if '--contre-gauche-fixe' in sys.argv:
  q.execute("SELECT pg_get_functiondef('navigation_destination_fuite_interne(text)'::regprocedure)");body=q.fetchone()[0]
  ancien="destination:=d->'parArrivee'->p.current_street_from->>'gauche';";assert ancien in body
  q.execute(body.replace(ancien,"destination:=d->'liens'->>'gauche';"))
 if '--contre-fuite-immobile' in sys.argv:
  q.execute("SELECT pg_get_functiondef('police_controle_action_interne(text,text)'::regprocedure)");body=q.fetchone()[0]
  ancien="deplacement:=public.navigation_commander_interne('rue',destination,NULL);";assert ancien in body
  q.execute(body.replace(ancien,"deplacement:='{\"ok\":true}'::jsonb;"))
 ctx['c'].commit()
 def lire():
  q.execute("SELECT navigation_destination_fuite_interne('A')");return q.fetchone()[0]
 def pret():
  sql("DELETE FROM police_interceptions; DELETE FROM groupes_pj_adhesions; DELETE FROM batailles_rounds;DELETE FROM batailles_groupes;DELETE FROM batailles_engagements;DELETE FROM batailles;")
  sql("UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building=NULL,current_room=NULL,current_street='rue-1',est_emprisonne=NULL,hospitalisation=NULL WHERE name='A'")
 def gauche():
  pret();sql("UPDATE rue_noeuds_serveur SET directions='{\"liens\":{\"gauche\":\"rue-2\"},\"parArrivee\":{}}' WHERE noeud='rue-1'")
  assert exige(lire())['destination']=='rue-2'
 cas('fuite_gauche_declaree_et_non_voisin_aleatoire',gauche)
 def absent():
  pret();sql("UPDATE rue_noeuds_serveur SET directions=NULL WHERE noeud='rue-1'");exige(lire(),'directions_non_referencees')
  sql("UPDATE rue_noeuds_serveur SET directions='{\"liens\":{},\"parArrivee\":{}}' WHERE noeud='rue-1'");exige(lire(),'rue_gauche_non_referencee')
 cas('fuite_aucune_gauche_inventee',absent)
 def contexte():
  pret()
  # Vraies quatre vues et quatre flèches du catalogue, pas des directions réinventées.
  src=subprocess.check_output(['node','-e',"const fs=require('fs'),vm=require('vm'),c=vm.createContext({});vm.runInContext(fs.readFileSync('plateau-rue-centrale.js','utf8'),c);console.log(vm.runInContext(\"JSON.stringify(RUE_CENTRALE_NOEUDS.republic['psm-carrefour-musee'])\",c))"],cwd=R,text=True)
  d=json.loads(src);arr=d['liensParArrivee'];voisins=list(arr)
  q.execute("INSERT INTO rue_noeuds_serveur(country,city,noeud,voisins,directions) VALUES('republic','capitale','psm-carrefour-musee',%s,%s::jsonb)",(voisins,json.dumps({'liens':d['liens'],'parArrivee':arr})))
  # Un déplacement légitime depuis chaque provenance établit l'orientation.
  for depuis,liens in arr.items():
   q.execute("UPDATE personnages_donnees SET current_street=%s WHERE name='A'",(depuis,))
   sql("UPDATE personnages_donnees SET current_street='psm-carrefour-musee' WHERE name='A'")
   assert exige(lire())['destination']==liens['gauche']
   q.execute("UPDATE personnages_donnees SET current_street_from='mensonge' WHERE name='A'")
   assert exige(lire())['destination']==liens['gauche'],'la provenance fournie par une sauvegarde a été crue'
 cas('fuite_quatre_vues_PSM_et_provenance_non_falsifiable',contexte)
 def batiment():
  pret();sql("INSERT INTO rue_sorties_batiments(country,city,building,noeud) VALUES('republic','capitale','terrain-test','rue-1')")
  sql("UPDATE personnages_donnees SET current_building='terrain-test',current_room='terrain',current_street=NULL WHERE name='A'")
  assert exige(lire())['destination']=='rue-1'
  sql("INSERT INTO rue_sorties_batiments(country,city,building,noeud) VALUES('republic','capitale','terrain-test','rue-2')")
  exige(lire(),'sortie_batiment_non_univoque')
 cas('fuite_batiment_terrain_sortie_serveur_univoque',batiment)
 def fuite_reelle(reussite):
  # Le décor judiciaire préexistant contient le groupe C/D et ses PNJ.
  sql("DELETE FROM batailles_rounds;DELETE FROM batailles_groupes;DELETE FROM batailles_engagements;DELETE FROM batailles;DELETE FROM police_interceptions;DELETE FROM police_action_receipts;DELETE FROM police_detection_attempts;DELETE FROM groupes_pj_adhesions;DELETE FROM jugements")
  sql("UPDATE personnages_donnees SET est_emprisonne=NULL,hospitalisation=NULL WHERE name IN ('A','B','C','D')")
  ctx['preparer_interception_collective']();rid=ctx['detecter_interception_collective']()['rencontre'];trouve=False
  for n in range(100):
   q.execute('SAVEPOINT fuite_dir');q.execute('SELECT setseed(%s)',(n/100,))
   try:
    v=exige(rpc('police_fuite_resoudre',(rid,),qui='D'))
    if v.get('reussite') is not reussite:continue
    q.execute("SELECT current_building,current_street FROM personnages_donnees WHERE name IN ('C','D') ORDER BY name")
    assert q.fetchall()==([(None,'rue-1')]*2 if reussite else [('mairie',None)]*2)
    assert rpc('police_fuite_resoudre',(rid,),qui='D')==v
    trouve=True;break
   finally:q.execute('ROLLBACK TO SAVEPOINT fuite_dir')
  assert trouve,'issue réelle non obtenue'
 cas('fuite_nouvelle_direction_succes_PJ_PNJ_rejeu',lambda:fuite_reelle(True))
 cas('fuite_nouvelle_direction_refus_sans_mouvement_rejeu',lambda:fuite_reelle(False))
 def ordinaire(action,reussite=None,incapable=False):
  ctx['controle_ordinaire_decor']()
  sql("UPDATE personnages_donnees SET current_building='mairie',current_room='accueil',current_street=NULL,current_city='capitale',hp=100,pa=100 WHERE name='D'")
  exige(rpc('groupe_pj_rejoindre',('D',),qui='C'))
  rid=ctx['controle_ordinaire_choix']()['rencontre']
  reprise=exige(rpc('police_reprise_lire',(rid,),qui='D'));assert reprise['controle_ordinaire'] and reprise['personnage_intercepte']=='C' and reprise['peut_commander']
  fn='police_reddition_resoudre' if action=='reddition' else 'police_fuite_resoudre'
  exige(rpc(fn,(rid,),qui='C'),'chef_de_groupe_requis')
  if incapable:sql("UPDATE personnages_donnees SET hp=0 WHERE name='C'")
  obtenu=False
  for n in range(100):
   q.execute('SAVEPOINT ordinaire');q.execute('SELECT setseed(%s)',(n/100,))
   try:
    v=rpc(fn,(rid,),qui='D')
    if incapable:
     if v.get('ok'):continue
     exige(v,'acteur_incapacite')
     q.execute("SELECT expires_at>now() FROM police_interceptions WHERE rencontre=%s",(rid,));assert q.fetchone()[0]
     q.execute("SELECT count(*) FROM police_action_receipts WHERE rencontre=%s",(rid,));assert q.fetchone()[0]==0
    else:
     exige(v)
     if reussite is not None and (v.get('phase')=='fuite')!=reussite:continue
     assert v['commandeur']=='D' and v['personnage_intercepte']=='C'
     if action=='reddition':
      q.execute("SELECT jsonb_array_length(convocations) FROM personnages_donnees WHERE name='C'");assert q.fetchone()[0]==1
      q.execute("SELECT jsonb_array_length(convocations) FROM personnages_donnees WHERE name='D'");assert q.fetchone()[0]==0
     if reussite:
      q.execute("SELECT current_building,current_street FROM personnages_donnees WHERE name IN ('C','D') ORDER BY name");assert q.fetchall()==[(None,'rue-1')]*2
     assert rpc(fn,(rid,),qui='D')==v
    obtenu=True;break
   finally:q.execute('ROLLBACK TO SAVEPOINT ordinaire')
  assert obtenu,'issue contrôle collectif non obtenue'
 cas('controle_ordinaire_chef_decide_porteur_seul_convoque_rejeu',lambda:ordinaire('reddition'))
 cas('controle_ordinaire_fuite_deplace_reellement_groupe',lambda:ordinaire('fuite',True))
 cas('controle_ordinaire_membre_incapable_annule_jet_et_mouvement',lambda:ordinaire('fuite',incapable=True))
 def acl():
  for role in ['anon','authenticated','service_role']:
   q.execute("SELECT has_function_privilege(%s,'navigation_destination_fuite_interne(text)','execute')",(role,));assert not q.fetchone()[0]
 cas('fuite_lecteur_interne_inaccessible_aux_roles_reseau',acl)
 ctx['controle_ordinaire_decor']()
 sql("UPDATE personnages_donnees SET current_building='mairie',current_room='accueil',current_street=NULL,current_city='capitale',hp=100,pa=100 WHERE name='D'")
 exige(rpc('groupe_pj_rejoindre',('D',),qui='C'))
 rid=ctx['controle_ordinaire_choix']()['rencontre'];ctx['c'].commit()
 def concurrence():
  import psycopg2
  from threading import Barrier
  from concurrent.futures import ThreadPoolExecutor
  barriere=Barrier(2)
  def agir():
   cn=psycopg2.connect(ctx['serveur'].get_uri())
   try:
    cur=cn.cursor();cur.execute("SET statement_timeout='15s'");barriere.wait(timeout=5)
    v=rpc('police_reddition_resoudre',(rid,),qui='D',cur=cur);cn.commit();return v
   finally:cn.close()
  with ThreadPoolExecutor(2) as pool:
   a=pool.submit(agir);b=pool.submit(agir);un=exige(a.result(timeout=20));deux=exige(b.result(timeout=20))
  assert un==deux and un['commandeur']=='D'
  q.execute("SELECT jsonb_array_length(convocations) FROM personnages_donnees WHERE name='C'");assert q.fetchone()[0]==1
  q.execute("SELECT count(*) FROM police_action_receipts WHERE rencontre=%s",(rid,));assert q.fetchone()[0]==1
 cas('controle_collectif_deux_sessions_du_chef_un_seul_acte',concurrence)
 ctx['preuves_extension']['phases_et_fuites']='Cinq rounds réels et contrats de phase ; chef seul ; reddition et fuite judiciaires, contrôles ordinaires collectifs, vraies directions dont les quatre vues PSM, provenance, rejouabilité et concurrence. Pas de fuite militaire ni de combat squatteurs réel.'

if __name__=='__main__':sys.exit(c.c.lancer(suite))
