#!/usr/bin/env python3
"""Anciens actes camion réels, vrais groupes, PostgreSQL jetable, pas de production."""
import importlib.util,sys,re,ast
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('finaux',R/'outils/bancs/banc-groupes-raccordements-finaux-local.py');f=importlib.util.module_from_spec(sp);sp.loader.exec_module(f)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 # Réutiliser le décor initial du banc corps : un décès précédent a aussi
 # retiré le matricule du blob, que le projecteur ne doit pas ressusciter.
 source_corps=ast.parse((R/'outils/bancs/banc-groupes-corps-local.py').read_text())
 inserts=[n.args[0].value for n in ast.walk(source_corps) if isinstance(n,ast.Call) and ((isinstance(n.func,ast.Name) and n.func.id=='sql') or (isinstance(n.func,ast.Attribute) and n.func.attr=='execute')) and n.args and isinstance(n.args[0],ast.Constant) and isinstance(n.args[0].value,str) and n.args[0].value.startswith("INSERT INTO compagnies_militaires VALUES('cie',")]
 assert len(inserts)==1
 blob_initial=re.search(r"VALUES\('cie',('.*')\)$",inserts[0])[1]

 for nom in ['camion_monter','camion_descendre','camion_deplacer']:
  ctx['installer_fonction_canonique'](nom)
 source=(R/'baseline/domaines/militaire/20_fonctions-2.sql').read_text()
 q.execute(re.search(r'CREATE OR REPLACE FUNCTION public.militaire_grade_effectif\(.*?\$function\$;',source,re.S)[0])
 contraintes=(R/'baseline/domaines/militaire/30_contraintes.sql').read_text()
 for nom in ['camions_militaires_pkey','camions_ordres_pkey','camions_embarquements_pkey']:
  q.execute(re.search(r'ALTER TABLE public\.\w+ ADD CONSTRAINT '+nom+r' .*?;',contraintes,re.S)[0])
 q.execute("GRANT EXECUTE ON FUNCTION camion_monter(text,text),camion_descendre(text),camion_deplacer(text,text,boolean,text) TO authenticated")
 q.execute((R/'migrations/20261030202100_camions_groupes_et_refus_atomiques.sql').read_text());q.execute((R/'migrations/20261030202100_camions_groupes_et_refus_atomiques.sql').read_text());q.execute((R/'migrations/20261030202200_navigation_provenance_pnj_et_lecture_commune.sql').read_text());q.execute((R/'migrations/20261030202200_navigation_provenance_pnj_et_lecture_commune.sql').read_text());ctx['c'].commit()
 if '--contre-repli-provenance-oubliee' in sys.argv:
  q.execute("SELECT pg_get_functiondef('militaire_repli_pnj_interne(bigint,text,integer)'::regprocedure)");s=q.fetchone()[0]
  a='r.rue_noeud_id,r.rue_depuis)';assert a in s;q.execute(s.replace(a,'r.rue_noeud_id,NULL)'))
 if '--contre-camion-solo' in sys.argv:
  q.execute("SELECT pg_get_functiondef('camion_monter_corps_interne(text,text)'::regprocedure)");s=q.fetchone()[0]
  a='WHERE name IN (SELECT identifiant FROM public.groupe_participants_interne(v_moi) WHERE est_pj);';assert a in s
  q.execute(s.replace(a,'WHERE name=v_moi;'))
 def pret():
  sql("DELETE FROM police_interceptions;DELETE FROM police_action_receipts;DELETE FROM batailles_rounds;DELETE FROM batailles_groupes;DELETE FROM batailles_engagements;DELETE FROM batailles;DELETE FROM groupes_pj_adhesions;DELETE FROM camions_ordres;DELETE FROM camions_embarquements;DELETE FROM camions_militaires;DELETE FROM camions_destinations")
  sql("UPDATE personnages_donnees SET est_emprisonne=NULL,hospitalisation=NULL,country='republic',current_city='capitale',current_building='mairie',current_room='accueil',current_street=NULL,hp=100,pa=100 WHERE name IN ('A','B','C','D')")
  # Réinitialiser les QUATRE soldats fictifs de ce décor indépendant, comme
  # les quatre PJ ci-dessus : leurs anciennes morts/positions dans un autre
  # cas ne sont pas les conditions initiales d'un trajet de section apte.
  # Aucun de ces identifiants ni aucune écriture n'existe en production.
  sql("UPDATE pnj_membres SET pa=12,statut='actif',leader_pj='A',leader_pnj_id=NULL,ville=NULL,building_id=NULL,room_id=NULL,rue_noeud_id=NULL WHERE id IN ('cie-S1','cie-S2','cie-S3','cie-S4')")
  q.execute("UPDATE compagnies_militaires SET data="+blob_initial+"::jsonb WHERE id='cie'")
  q.execute("SELECT pnj_groupes_projeter_interne(ARRAY['cie-S1','cie-S2','cie-S3','cie-S4'])")
  sql("UPDATE personnages_donnees SET poste='{\"id\":\"lieutenant\"}' WHERE name='A'")
  exige(rpc('groupe_pj_rejoindre',('A',),qui='B'))
  sql("INSERT INTO camions_militaires(id,pays,libelle,capacite,caserne_ville,caserne_building,caserne_room,caserne_libelle,ville,building_id,room_id) VALUES('camion-test','republic','Camion de fixture',25,'caserne','caserne-militaire','corps_garde','Caserne','capitale','mairie','accueil')")
  sql("INSERT INTO camions_destinations(pays,cle,ville,building_id,room_id,libelle) VALUES('republic','destination-test','capitale','hotel-republica','bar','Destination de fixture')")
 def parcours():
  pret();v=exige(rpc('camion_monter',('camion-test','monter-fixture')));assert v['embarques']>=2,v
  q.execute("SELECT current_building,current_room FROM personnages_donnees WHERE name IN ('A','B') ORDER BY name");assert q.fetchall()==[('camion-militaire','camion-test')]*2
  assert exige(rpc('camion_monter',('camion-test','monter-fixture')))['rejeu']
  exige(rpc('camion_descendre',('camion-test',),qui='B'),'chef_de_groupe_requis')
  exige(rpc('camion_descendre',('camion-test',)))
  q.execute("SELECT current_building,current_room FROM personnages_donnees WHERE name IN ('A','B') ORDER BY name");assert q.fetchall()==[('mairie','accueil')]*2
  assert exige(rpc('camion_descendre',('camion-test',)))['deja_debarque']
 cas('camion_ancien_acte_embarque_et_debarque_groupe_PJ_entier_rejeu',parcours)
 def voyage():
  pret();exige(rpc('camion_monter',('camion-test','monter-voyage')))
  q.execute("SELECT pa FROM personnages_donnees WHERE name IN ('A','B') ORDER BY name");avant=q.fetchall()
  v=exige(rpc('camion_deplacer',('camion-test','destination-test',True,'voyage-fixture')))
  q.execute("SELECT pa FROM personnages_donnees WHERE name IN ('A','B') ORDER BY name");assert q.fetchall()==[(x[0]-2,) for x in avant]
  assert exige(rpc('camion_deplacer',('camion-test','destination-test',True,'voyage-fixture')))['rejeu']
  exige(rpc('camion_descendre',('camion-test',)))
  q.execute("SELECT current_building,current_room FROM personnages_donnees WHERE name IN ('A','B') ORDER BY name");assert q.fetchall()==[('hotel-republica','bar')]*2
 cas('camion_voyage_reel_cout_historique_2PA_par_PJ_et_rejeu_sans_double_debit',voyage)
 def section_epuisee():
  pret();exige(rpc('camion_monter',('camion-test','monter-section-epuisee')))
  q.execute("SELECT count(*) FROM camion_occupants('camion-test') WHERE NOT est_pj");assert q.fetchone()[0]>=1
  sql("UPDATE pnj_membres SET pa=1 WHERE id='cie-S2'")
  q.execute("SELECT pnj_groupes_projeter_interne(ARRAY['cie-S2'])")
  v=exige(rpc('camion_deplacer',('camion-test','destination-test',True,'section-epuisee')),'pa_insuffisants_section');assert 'S2' in v['manquants']
  q.execute("SELECT pa FROM personnages_donnees WHERE name IN ('A','B') ORDER BY name");assert q.fetchall()==[(100,),(100,)]
  q.execute("SELECT building_id,room_id FROM camions_militaires WHERE id='camion-test'");assert q.fetchone()==('mairie','accueil')
 cas('camion_section_epuisee_refuse_sans_debit_ni_deplacement',section_epuisee)

 def incapacite():
  pret();sql("UPDATE personnages_donnees SET hp=0 WHERE name='B'");exige(rpc('camion_monter',('camion-test','incapable-fixture')),'acteur_incapacite')
  q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND current_building='mairie'");assert q.fetchone()[0]==2
  q.execute('SELECT count(*) FROM camions_ordres');assert q.fetchone()[0]==0
 cas('camion_membre_incapable_refus_total_sans_recu_ni_debit',incapacite)
 def cle():
  pret();exige(rpc('camion_monter',('camion-test','cle-fixture')))
  exige(rpc('camion_monter',('camion-test','cle-fixture'),qui='C'),'requete_reutilisee')
 cas('camion_recu_autre_acteur_refuse_avant_lecture_resultat',cle)
 def refus():
  pret();sql('UPDATE camions_militaires SET capacite=1')
  v=rpc('camion_monter',('camion-test','capacite-fixture'));assert not v.get('ok'),v
  q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND current_building='mairie'");assert q.fetchone()[0]==2
 cas('camion_capacite_complete_du_groupe_pas_un_seul_PJ',refus)
 def refus_aval():
  pret()
  q.execute("SELECT pg_get_functiondef('camion_monter_corps_interne(text,text)'::regprocedure)");s=q.fetchone()[0]
  a='  RETURN v_res;';assert s.count(a)==1
  q.execute(s.replace(a,"  RETURN jsonb_build_object('ok',false,'raison','refus_aval_fixture');"))
  exige(rpc('camion_monter',('camion-test','refus-aval-fixture')),'refus_aval_fixture')
  q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND current_building='mairie'");assert q.fetchone()[0]==2
  q.execute('SELECT count(*) FROM camions_ordres');assert q.fetchone()[0]==0
  q.execute('SELECT count(*) FROM camions_embarquements');assert q.fetchone()[0]==0
 cas('camion_refus_apres_mutations_annule_positions_embarquements_et_recu',refus_aval)
 def droits():
  for role in ['anon','authenticated','service_role']:
   q.execute("SELECT has_function_privilege(%s,'camion_monter_corps_interne(text,text)','execute')",(role,));assert not q.fetchone()[0]
 cas('camion_corps_historiques_prives_pas_de_chemin_ancien_parallele',droits)
 def position_personnelle():
  pret()
  for qui in ['A','B']:
   v=exige(rpc('groupe_pj_lire',(),qui=qui));p=v['position_personnelle'];assert p['personnage']==qui and p['building']=='mairie' and p['depuis'] is None,p
 cas('lecture_commune_position_personnelle_pas_celle_du_chef',position_personnelle)
 def provenance_pnj():
  pret();sql("INSERT INTO pnj_membres(id,famille,nom,pays,proprietaire_pj,ville,rue_noeud_id) VALUES('pnj-provenance-fixture','employe','Fixture de provenance','republic','A','capitale','rue-1')")
  sql("UPDATE pnj_membres SET rue_noeud_id='rue-2' WHERE id='pnj-provenance-fixture'")
  q.execute("SELECT rue_depuis FROM pnj_membres WHERE id='pnj-provenance-fixture'");assert q.fetchone()[0]=='rue-1'
  sql("UPDATE pnj_membres SET rue_depuis='mensonge' WHERE id='pnj-provenance-fixture'")
  q.execute("SELECT rue_depuis FROM pnj_membres WHERE id='pnj-provenance-fixture'");assert q.fetchone()[0]=='rue-1'
 cas('provenance_PNJ_derivee_du_mouvement_pas_d_une_ecriture_declaree',provenance_pnj)
 def depose_provenance():
  pret()
  sql("UPDATE personnages_donnees SET current_city='ville_a',current_building=NULL,current_room=NULL,current_street='psm-tribunal-banque' WHERE name IN ('A','B')")
  sql("UPDATE personnages_donnees SET current_street='psm-carrefour-musee' WHERE name IN ('A','B')")
  sql("INSERT INTO pnj_membres(id,famille,nom,pays,proprietaire_pj,leader_pj) VALUES('pnj-depose-provenance','employe','Fixture de dépose','republic','A','A')")
  exige(rpc('pnj_quitter_groupe',(['pnj-depose-provenance'],)))
  q.execute("SELECT rue_noeud_id,rue_depuis FROM pnj_membres WHERE id='pnj-depose-provenance'");assert q.fetchone()==('psm-carrefour-musee','psm-tribunal-banque')
 cas('depose_PNJ_reprend_provenance_effective_du_groupe_sans_invention',depose_provenance)
 def psm_repli():
  import subprocess,json
  ctx['preparer_bataille_repli']()
  source=subprocess.check_output(['node','-e',"const fs=require('fs'),vm=require('vm'),c=vm.createContext({});vm.runInContext(fs.readFileSync('plateau-rue-centrale.js','utf8'),c);console.log(vm.runInContext(\"JSON.stringify(RUE_CENTRALE_NOEUDS.republic['psm-carrefour-musee'])\",c))"],cwd=R,text=True)
  node=json.loads(source);depuis='psm-tribunal-banque';gauche=node['liensParArrivee'][depuis]['gauche']
  q.execute("INSERT INTO rue_noeuds_serveur(country,city,noeud,voisins,directions) VALUES('republic','ville_a','psm-carrefour-musee',%s,%s::jsonb),('republic','ville_a',%s,ARRAY['psm-carrefour-musee'],'{}')",(list(node['liensParArrivee']),json.dumps({'liens':node['liens'],'parArrivee':node['liensParArrivee']}),gauche))
  q.execute("SELECT e.id,e.pnj_id FROM batailles_engagements e JOIN pnj_membres m ON m.id=e.pnj_id WHERE e.bataille_id=71 AND e.camp='republic' AND m.statut='actif' LIMIT 1");ident,pnj=q.fetchone()
  q.execute('DELETE FROM batailles_engagements WHERE bataille_id=71 AND id<>%s',(ident,));sql('DELETE FROM batailles_groupes WHERE bataille_id=71;SELECT militaire_bataille_groupes_constituer(71)')
  sql("UPDATE batailles SET ville='ville_a',batiment=NULL,piece=NULL WHERE id=71")
  q.execute("UPDATE pnj_membres SET leader_pj=NULL,leader_pnj_id=NULL,ville='ville_a',building_id=NULL,room_id=NULL,rue_noeud_id=%s WHERE id=%s",(depuis,pnj))
  q.execute("UPDATE pnj_membres SET rue_noeud_id='psm-carrefour-musee' WHERE id=%s",(pnj,))
  q.execute('SELECT militaire_bataille_decrocher_groupe(71,groupe_id,5) FROM batailles_groupes WHERE bataille_id=71');assert q.fetchone()[0]==1
  q.execute('SELECT rue_noeud_id,rue_depuis FROM pnj_membres WHERE id=%s',(pnj,));assert q.fetchone()==(gauche,'psm-carrefour-musee')
 cas('repli_PNJ_PSM_vraie_gauche_selon_provenance_serveur',psm_repli)
 # Décor fictif committé pour deux connexions réellement concurrentes.
 pret();ctx['c'].commit()
 def concurrence():
  import psycopg2
  from threading import Barrier
  from concurrent.futures import ThreadPoolExecutor
  barriere=Barrier(2)
  def agir():
   cn=psycopg2.connect(ctx['serveur'].get_uri())
   try:
    cur=cn.cursor();cur.execute("SET statement_timeout='15s'");barriere.wait(timeout=5)
    v=rpc('camion_monter',('camion-test','concurrent-fixture'),cur=cur);cn.commit();return v
   finally:cn.close()
  with ThreadPoolExecutor(2) as pool:
   a=pool.submit(agir);b=pool.submit(agir);un=exige(a.result(timeout=20));deux=exige(b.result(timeout=20))
  assert un['embarques']==deux['embarques']
  q.execute("SELECT count(*) FROM camions_ordres WHERE requete='concurrent-fixture'");assert q.fetchone()[0]==1
  q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND current_building='camion-militaire'");assert q.fetchone()[0]==2
 cas('camion_deux_sessions_du_chef_un_embarquement_et_un_recu',concurrence)
 if suivante is not None:suivante(ctx)

if __name__=='__main__':sys.exit(f.d.c.c.lancer(lambda ctx:f.suite(ctx,suite)))
