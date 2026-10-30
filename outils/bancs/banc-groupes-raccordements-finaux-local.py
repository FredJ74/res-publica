#!/usr/bin/env python3
"""Compléments réels à la suite conservée de 317 cas, jamais production."""
import importlib.util,sys,json
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('directions',R/'outils/bancs/banc-groupes-fuite-directions-local.py');d=importlib.util.module_from_spec(sp);sp.loader.exec_module(d)
def suite(ctx,suivante=None):
 d.suite(ctx)
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 if '--catalogue-20261029' in sys.argv:
  def asile():
   ctx['controle_ordinaire_decor']();sql("INSERT INTO asile_fixture VALUES('C')")
   v=rpc('police_detection_verifier',('mairie','accueil',None),qui='C');assert v.get('raison')=='refugie_protege',v
   q.execute("SELECT count(*) FROM police_interceptions WHERE personnage='C'");assert q.fetchone()[0]==0
  cas('catalogue_asile_reel_preserve_apres_tous_les_adaptateurs',asile)
 ctx['installer_fonction_canonique']('militaire_bataille_decision_effective')
 for f in ['20261029223700_batailles_repli_navigation_commune.sql','20261029223800_navigation_geometrie_commune_et_replis_pnj.sql','20261029223900_batailles_progression_serveur_existante.sql']:
  q.execute((R/'migrations'/f).read_text());q.execute((R/'migrations'/f).read_text())
 if '--contre-repli-sans-mouvement' in sys.argv:
  q.execute("CREATE OR REPLACE FUNCTION navigation_commander_personnage_interne(p_nom text,p_mode text,p_destination text,p_piece text) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$SELECT '{\"ok\":true}'::jsonb$$")
 ctx['c'].commit()
 def pret():
  sql("DELETE FROM police_interceptions;DELETE FROM police_action_receipts;DELETE FROM batailles_rounds;DELETE FROM batailles_groupes;DELETE FROM batailles_engagements;DELETE FROM batailles;DELETE FROM groupes_pj_adhesions;DELETE FROM services_militaires WHERE personnage='C';DELETE FROM guerres;DELETE FROM jugements")
  sql("UPDATE personnages_donnees SET est_emprisonne=NULL,hospitalisation=NULL WHERE name IN ('A','B','C','D')")
  ctx['bataille_mixte_decor']()
  sql("DELETE FROM rue_sorties_batiments WHERE country='republic' AND city='capitale' AND building='hotel-republica'")
  sql("INSERT INTO rue_sorties_batiments(country,city,building,noeud) VALUES('republic','capitale','hotel-republica','rue-1')")
  sql('UPDATE batailles SET round_courant=5 WHERE id=71')
 def repli():
  pret()
  v=exige(rpc('militaire_bataille_decider',(71,'replier',5,'00000000-0000-4000-8000-000000090001')))
  q.execute("SELECT name,current_building,current_street FROM personnages_donnees WHERE name IN ('A','B') ORDER BY name");assert q.fetchall()==[('A',None,'rue-1'),('B',None,'rue-1')]
  q.execute("SELECT count(*) FROM batailles_engagements WHERE bataille_id=71 AND camp='republic' AND sorti_round IS NULL");assert q.fetchone()[0]==0
  q.execute("SELECT count(*) FROM groupe_participants_interne('A') p WHERE NOT est_pj AND rue<>'rue-1'");assert q.fetchone()[0]==0
  assert rpc('militaire_bataille_decider',(71,'replier',5,'00000000-0000-4000-8000-000000090001'))==v
 cas('repli_militaire_meme_navigation_PJ_PNJ_sortie_reelle_et_rejeu',repli)
 def refus():
  pret();sql("UPDATE personnages_donnees SET hp=0 WHERE name='B'")
  v=exige(rpc('militaire_bataille_decider',(71,'replier',5,'00000000-0000-4000-8000-000000090002')),'repli_refuse');assert v['refus']['raison']=='acteur_incapacite',v
  q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND current_building='hotel-republica'");assert q.fetchone()[0]==2
  q.execute("SELECT count(*) FROM batailles_engagements WHERE bataille_id=71 AND camp='republic' AND sorti_round IS NOT NULL");assert q.fetchone()[0]==0
 cas('repli_militaire_refus_individuel_annule_sortie_et_tous_mouvements',refus)
 def autonome():
  pret()
  # Unité institutionnelle réellement sans PJ : aucun chef ou soldat factice créé.
  sql("UPDATE pnj_membres SET leader_pj=NULL,leader_pnj_id=NULL,ville='capitale',building_id='hotel-republica',room_id='bar',rue_noeud_id=NULL WHERE id IN ('cie-S1','cie-S2','cie-S3','cie-S4') AND statut='actif'")
  sql("DELETE FROM batailles_engagements WHERE bataille_id=71 AND camp='republic' AND (pnj_id IS NULL OR pnj_id NOT IN ('cie-S1','cie-S2','cie-S3','cie-S4'));DELETE FROM batailles_groupes WHERE bataille_id=71;SELECT militaire_bataille_groupes_constituer(71);UPDATE batailles_groupes SET leader=NULL WHERE bataille_id=71 AND camp='republic'")
  q.execute("SELECT militaire_bataille_decrocher_groupe(71,groupe_id,5) FROM batailles_groupes WHERE bataille_id=71 AND camp='republic'");valeurs=q.fetchall();assert valeurs and all(n>0 for (n,) in valeurs),valeurs
  q.execute("SELECT count(*) FROM pnj_membres WHERE statut='actif' AND id IN ('cie-S1','cie-S2','cie-S3','cie-S4') AND (building_id IS NOT NULL OR rue_noeud_id IS DISTINCT FROM 'rue-1')");assert q.fetchone()[0]==0
 cas('repli_unite_PNJ_sans_faux_PJ_meme_geometrie_et_projection',autonome)
 def adverse_absent():
  pret();v=exige(rpc('militaire_bataille_poursuivre',(71,5,'00000000-0000-4000-8000-000000090003')))
  assert not v.get('en_attente'),v
  q.execute('SELECT round_courant FROM batailles WHERE id=71');assert q.fetchone()[0]==6
 cas('poursuite_apres_cinq_sans_clic_du_defenseur_doctrine_existante',adverse_absent)
 def calendrier():
  pret();sql("UPDATE batailles_groupes SET attente_depuis=now()-interval '91 seconds' WHERE bataille_id=71")
  q.execute("SELECT set_config('role','service_role',true),set_config('request.jwt.claim.sub','',true),set_config('request.path','/rpc/militaire_batailles_echues_traiter',true)")
  # Le prédicat d'autorité service est celui du dépôt, pas celui simplifié du décor.
  q.execute('RESET ROLE')
  source=(R/'baseline/domaines/socle/20_fonctions.sql').read_text()
  import re
  q.execute(re.search(r'CREATE OR REPLACE FUNCTION public.est_appel_serveur\(\).*?\$function\$;',source,re.S)[0])
  q.execute("SELECT set_config('role','service_role',true),set_config('request.jwt.claim.sub','',true),set_config('request.path','/rpc/militaire_batailles_echues_traiter',true)")
  q.execute('SELECT militaire_batailles_echues_traiter()');v=exige(q.fetchone()[0]);q.execute('RESET ROLE');assert v['traitees']==1,v
  q.execute("SELECT statut,issue FROM batailles WHERE id=71");assert q.fetchone()==('terminee',None)
  q.execute('SELECT militaire_batailles_echues_traiter()');v=q.fetchone()[0];assert v['traitees']==0,v
 cas('calendrier_serveur_sans_JWT_joueur_resout_et_rejoue_sans_effet',calendrier)
 def droits_calendrier():
  for role in ['anon','authenticated']:
   q.execute("SELECT has_function_privilege(%s,'militaire_batailles_echues_traiter()','execute')",(role,));assert not q.fetchone()[0]
 cas('calendrier_non_declenchable_par_le_navigateur',droits_calendrier)
 def acces():
  for role in ['anon','authenticated','service_role']:
   q.execute("SELECT has_function_privilege(%s,'navigation_commander_personnage_interne(text,text,text,text)','execute')",(role,));assert not q.fetchone()[0]
 cas('navigation_identite_explicite_reste_privee',acces)
 ctx['preparer_bataille_repli']=pret
 if suivante is not None:suivante(ctx)
if __name__=='__main__':sys.exit(d.c.c.lancer(suite))
