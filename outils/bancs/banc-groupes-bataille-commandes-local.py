#!/usr/bin/env python3
"""Commandes militaires avec round attendu et reçu, vrais rounds PostgreSQL."""
import importlib.util,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('mixte',R/'outils/bancs/banc-groupes-bataille-mixte-local.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 migration=R/'migrations/20261030210200_batailles_commandes_et_reprises.sql'
 q.execute(migration.read_text());q.execute(migration.read_text());ctx['c'].commit()
 if '--contre-poursuite-sans-recu' in sys.argv:
  q.execute("CREATE OR REPLACE FUNCTION public.militaire_bataille_poursuivre(p_bataille_id bigint,p_round_attendu integer,p_requete uuid) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO public,pg_temp AS $$ SELECT public.militaire_bataille_poursuivre_interne(p_bataille_id) $$")
  ctx['c'].commit()
 decor=ctx['bataille_mixte_decor'];req=lambda n:f'00000000-0000-4000-8000-{n:012d}'
 def photo():
  q.execute('SELECT jsonb_agg(to_jsonb(e) ORDER BY id) FROM batailles_engagements e');a=q.fetchone()[0]
  q.execute('SELECT jsonb_agg(to_jsonb(d) ORDER BY name) FROM personnages_donnees d');b=q.fetchone()[0]
  q.execute('SELECT jsonb_agg(to_jsonb(m) ORDER BY id) FROM pnj_membres m');return a,b,q.fetchone()[0]
 def rejeu():
  decor();v=exige(rpc('militaire_bataille_poursuivre',(71,0,req(19401))));assert v['round']==1,v
  avant=photo();assert rpc('militaire_bataille_poursuivre',(71,0,req(19401)))==v;assert photo()==avant
  exige(rpc('militaire_bataille_poursuivre',(71,0,req(19402))),'round_obsolete');assert photo()==avant
 cas('bataille_reponse_perdue_meme_recu_pas_de_second_round',rejeu)
 def legacy():
  decor();avant=photo()
  exige(rpc('militaire_bataille_poursuivre',(71,)),'requete_requise')
  exige(rpc('militaire_bataille_decider',(71,'tenir')),'requete_requise')
  exige(rpc('militaire_bataille_engager',()),'requete_requise');assert photo()==avant
 cas('bataille_anciens_appels_sans_recu_refuses',legacy)
 for champ,valeur in [('pa','0'),('hp','0'),('est_emprisonne',"'{}'::jsonb"),('hospitalisation',"'{\"jourFin\":9999}'::jsonb")]:
  def indisponible(champ=champ,valeur=valeur):
   decor();sql('UPDATE personnages_donnees SET '+champ+'='+valeur+" WHERE name='A'");avant=photo()
   exige(rpc('militaire_bataille_decider',(71,'tenir',0,req(19403))),'acteur_indisponible');assert photo()==avant
  cas('bataille_commande_refuse_etat_'+champ,indisponible)
 def chef():
  decor();exige(rpc('militaire_bataille_decider',(71,'tenir',0,req(19404)),qui='B'),'pas_chef_de_groupe')
 cas('bataille_decision_reservee_chef_reel_pas_grade_ou_employeur',chef)
 def droits():
  for signature in ['militaire_bataille_commande_interne(bigint,text,integer,uuid)','militaire_bataille_poursuivre_interne(bigint)','combat_gilet_pnj_absorber_interne(text)']:
   q.execute('SELECT has_function_privilege(%s,%s,%s)',('authenticated',signature,'EXECUTE'));assert not q.fetchone()[0],signature
 cas('bataille_adaptateurs_internes_prives',droits)
 def observateur():
  decor();sql("UPDATE personnages_donnees SET pa=0 WHERE name='A'")
  exige(rpc('militaire_bataille_poursuivre',(71,0,req(19406))))
  q.execute("SELECT pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()[0]==0
  q.execute("SELECT sorti_round,etat_final FROM batailles_engagements WHERE bataille_id=71 AND personnage='A'");assert q.fetchone()==(1,'indisponible')
 cas('bataille_observateur_epuise_fait_avancer_sans_etre_recrute',observateur)
 def complete(camp):
  decor();trouve=False
  for graine in range(1,17):
   q.execute('SAVEPOINT bataille_complete')
   try:
    # Choix « tenir » des deux chefs dans le décor, pas un faux jet/coup.
    sql("UPDATE batailles_groupes SET decision='tenir' WHERE bataille_id=71")
    # Fin d'un camp déjà épuisé : restent un PJ et un PNJ à 1 PA.
    # Ce décor permet de vérifier les deux issues sans faire dépendre le test
    # d'une victoire improbable d'une petite équipe contre dix adversaires.
    q.execute("UPDATE personnages_donnees SET pa=0 WHERE name IN (SELECT personnage FROM batailles_engagements WHERE bataille_id=71 AND camp<>%s)",(camp,))
    q.execute("UPDATE personnages_donnees SET pa=1 WHERE name=(SELECT min(personnage) FROM batailles_engagements WHERE bataille_id=71 AND camp<>%s)",(camp,))
    q.execute("UPDATE pnj_membres SET pa=0 WHERE id IN (SELECT pnj_id FROM batailles_engagements WHERE bataille_id=71 AND camp<>%s)",(camp,))
    q.execute("UPDATE pnj_membres SET pa=1 WHERE id=(SELECT min(pnj_id) FROM batailles_engagements WHERE bataille_id=71 AND camp<>%s)",(camp,))
    q.execute('SELECT setseed(%s)',(graine/17,))
    for n in range(40):
     q.execute('SELECT round_courant,statut,issue FROM batailles WHERE id=71');round_,statut,issue=q.fetchone()
     if statut=='terminee':
      if issue=='victoire_'+camp:
       q.execute("SELECT count(*) FROM pnj_evenements WHERE type='mort'");assert q.fetchone()[0]>0
       trouve=True
      break
     exige(rpc('militaire_bataille_poursuivre',(71,round_,req(19600+n))))
    if trouve:break
   finally:q.execute('ROLLBACK TO SAVEPOINT bataille_complete')
  assert trouve,'issue réelle non obtenue pour '+camp
 for camp in ['republic','soviet']:cas('bataille_rounds_reels_jusqua_resolution_'+camp,lambda camp=camp:complete(camp))
 # Décor et deux ordres fictifs committés, uniquement pour la concurrence.
 decor();ctx['c'].commit()
 def concurrence():
  import psycopg2
  from threading import Barrier
  from concurrent.futures import ThreadPoolExecutor
  barriere=Barrier(2)
  def jouer():
   cn=psycopg2.connect(ctx['serveur'].get_uri())
   try:
    cur=cn.cursor();cur.execute("SET statement_timeout='15s'");barriere.wait(timeout=5)
    v=rpc('militaire_bataille_poursuivre',(71,0,req(19405)),cur=cur);cn.commit();return v
   finally:cn.close()
  with ThreadPoolExecutor(2) as pool:
   a=pool.submit(jouer);b=pool.submit(jouer);un=exige(a.result(timeout=20));deux=exige(b.result(timeout=20))
  assert un==deux
  q.execute('SELECT round_courant FROM batailles WHERE id=71');assert q.fetchone()[0]==1
  q.execute('SELECT count(*) FROM batailles_rounds WHERE bataille_id=71 AND numero=1');assert q.fetchone()[0]==2
 cas('bataille_deux_commandes_concurrentes_un_round_et_deux_rapports',concurrence)
 ctx['preuves_extension']['commandes_bataille']='Vrais rounds, round attendu, reçu et deux connexions ; refus anciens appels/états invalides avant coup. Aucun joueur réel.'
 if suivante is not None:suivante(ctx)
def lancer(suivante=None):return m.lancer(lambda ctx:suite(ctx,suivante))
if __name__=='__main__':sys.exit(lancer())
