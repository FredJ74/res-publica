#!/usr/bin/env python3
"""337 acquis conservés puis vraies ouvertures/rounds civils et PNJ unique."""
import importlib.util,sys,json,hashlib,re
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('camions',R/'outils/bancs/banc-groupes-camions-local.py');c=importlib.util.module_from_spec(sp);sp.loader.exec_module(c)
def suite(ctx):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 vivants=json.loads((R/'outils/bancs/fixtures/groupes-justice-communiquee-20261030.json').read_text())['fonctions']
 for x in vivants:
  assert hashlib.sha256(x['sql'].encode()).hexdigest()==x['sha256'];q.execute(x['sql'])
 # Conserver la séparation commune sur le corps judiciaire vivant réinstallé.
 q.execute((R/'migrations/20261028222000_justice_position_cellule_serveur.sql').read_text())
 q.execute((R/'migrations/20261029120000_groupes_separation_ecrou.sql').read_text())
 for f in ['20261030202300_combats_profils_et_occupation_unique.sql','20261030202400_combat_ouverture_civile_commune.sql','20261030202500_combat_civil_rounds_et_issues_communes.sql','20261030202600_combat_fermeture_ancienne_porte_et_automates.sql']:
  q.execute((R/'migrations'/f).read_text());q.execute((R/'migrations'/f).read_text())
 q.execute(re.search(r'INSERT INTO public.ordres_couts .*?ON CONFLICT DO NOTHING;', (R/'migrations/20261027110100_crimes_actes_serveur.sql').read_text(),re.S)[0])
 # Le vrai détecteur de crime remplace le substitut du vieux banc de contrat.
 q.execute("SELECT to_regprocedure('public.crime_detecter_interne(text,text,boolean)')")
 if q.fetchone()[0] is not None:q.execute('ALTER FUNCTION crime_detecter_interne(text,text,boolean) RENAME TO crime_detecter_fixture_ancienne')
 source=(R/'migrations/20261027110000_crimes_socle_serveur.sql').read_text()
 for nom in ['crime_rechercher_interne','crime_detecter_interne']:
  q.execute(re.search(r'CREATE OR REPLACE FUNCTION public\.'+nom+r'\(.*?\$function\$;',source,re.S)[0])
 q.execute('ALTER TABLE terrains_etat ADD CONSTRAINT terrains_etat_pkey PRIMARY KEY(id)')
 ctx['c'].commit()
 req=lambda n:f'00000000-0000-4000-8000-{n:012d}'
 def pret(occupation=None):
  sql('DELETE FROM police_interceptions;DELETE FROM police_action_receipts;DELETE FROM batailles_rounds;DELETE FROM batailles_groupes;DELETE FROM batailles_engagements;DELETE FROM batailles;DELETE FROM groupes_pj_adhesions;DELETE FROM navigation_requetes')
  sql("UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='terrain-a-batir',current_room='terrain',current_street=NULL,pa=100,hp=100,hospitalisation=NULL,est_emprisonne=NULL,historique_crimes='[]',stats='{\"VOL\":10,\"PER\":10,\"DUP\":10}' WHERE name IN ('A','B','C','D')")
  sql("UPDATE pnj_membres SET leader_pj=NULL,leader_pnj_id=NULL,ville='capitale',building_id='ailleurs',room_id='ailleurs',rue_noeud_id=NULL WHERE statut='actif'")
  if occupation:
   q.execute("INSERT INTO terrains_etat(id,country,building_id,data) VALUES('republic_terrain-a-batir','republic','terrain-a-batir',%s) ON CONFLICT(id) DO UPDATE SET data=EXCLUDED.data",(json.dumps({'city':'capitale','pnj':occupation,'occupationInitialisee':True}),))
  sql("DELETE FROM rue_sorties_batiments WHERE country='republic' AND city='capitale' AND building='terrain-a-batir';INSERT INTO rue_sorties_batiments(country,city,building,noeud) VALUES('republic','capitale','terrain-a-batir','rue-1')")
 def ouvrir(occ=None):
  pret(occ);v=exige(rpc('combat_ouvrir',('terrain-a-batir' if occ else 'C','mains',req(100001))))
  return v
 def civil():
  v=ouvrir();assert v['phase']=='choix';b=v['bataille']
  etat=exige(rpc('militaire_bataille_etat',(b,)))['bataille'];assert etat['phase_initiale'] and etat['peut_decider']
  q.execute("SELECT pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()[0]==98
  assert rpc('combat_ouvrir',('C','mains',req(100001)))==v
  q.execute("SELECT pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()[0]==98
 cas('civil_ouverture_reelle_choix_paiement_unique_rejeu',civil)
 for occ in ['squatter_cool','squatter_agr']:
  def pnju(occ=occ):
   v=ouvrir(occ);b=v['bataille'];q.execute("SELECT m.nom,m.car_vol,m.car_ent,m.classe,m.leader_pj,m.leader_pnj_id FROM batailles_engagements e JOIN pnj_membres m ON m.id=e.pnj_id WHERE e.bataille_id=%s AND e.camp='defenseur'",(b,));assert q.fetchall()==[('squatteurs',13 if occ.endswith('agr') else 10,10,'beta',None,None)]
   exige(rpc('combat_ouvrir',('terrain-a-batir','mains',req(100002))),'combat_en_cours')
  cas('squatteurs_PNJ_unique_profil_valide_'+occ,pnju)
 def rendre():
  b=ouvrir()['bataille'];v=exige(rpc('militaire_bataille_decider',(b,'rendre',0,req(100003))))
  q.execute("SELECT pa,hp,current_building FROM personnages_donnees WHERE name='A'");assert q.fetchone()==(0,100,'terrain-a-batir')
  q.execute("SELECT count(*) FROM detentions WHERE nom='A' AND jour_fin_effective IS NULL");assert q.fetchone()[0]==0
 cas('civil_reddition_initiale_sans_deces_deplacement_ni_ecrou_innocent',rendre)
 def fuir():
  b=ouvrir()['bataille'];exige(rpc('militaire_bataille_decider',(b,'replier',0,req(100004))))
  q.execute("SELECT current_building,current_street FROM personnages_donnees WHERE name='A'");assert q.fetchone()==(None,'rue-1')
 cas('civil_fuite_initiale_deplacement_reel',fuir)
 def rounds():
  b=ouvrir()['bataille']
  for n in range(5):
   if n:
    for action in ['replier','rendre']:exige(rpc('militaire_bataille_decider',(b,action,n,req(100100+n))),'cinq_rounds_obligatoires')
   v=exige(rpc('militaire_bataille_poursuivre',(b,n,req(100200+n))))
   assert v['round']==n+1
   if v.get('terminee'):break
  q.execute('SELECT round_courant FROM batailles WHERE id=%s',(b,));assert q.fetchone()[0]>=1
  exige(rpc('militaire_bataille_poursuivre',(b,6,req(100300))),'round_obsolete')
 cas('civil_vrais_rounds_sans_defenseur_connecte_et_aucun_saut',rounds)
 def jusquau_bout(b,offset):
  for n in range(200):
   q.execute('SELECT statut,round_courant FROM batailles WHERE id=%s',(b,));statut,nround=q.fetchone()
   if statut=='terminee':break
   exige(rpc('militaire_bataille_poursuivre',(b,nround,req(offset+n))))
  q.execute("SELECT statut,contexte->'resultat_civil' FROM batailles WHERE id=%s",(b,));statut,v=q.fetchone();assert statut=='terminee';return v
 for occ in ['squatter_cool','squatter_agr']:
  def deces(occ=occ):
   b=ouvrir(occ)['bataille'];v=jusquau_bout(b,110000);assert v['issue'] in ['tues','neutralises','defaite'],v
   q.execute("SELECT count(*) FROM batailles_engagements WHERE bataille_id=%s AND pnj_id IS NOT NULL",(b,));assert q.fetchone()[0]==1
   q.execute("SELECT jsonb_array_length(historique_crimes) FROM personnages_donnees WHERE name='A'");nb=q.fetchone()[0];assert nb==(0 if v['issue']=='defaite' else 1)
   q.execute('SELECT combat_finaliser_interne(%s)',(b,));assert q.fetchone()[0]==v
   q.execute("SELECT jsonb_array_length(historique_crimes) FROM personnages_donnees WHERE name='A'");assert q.fetchone()[0]==nb
  cas('squatteurs_rounds_reels_issue_et_unique_trace_'+occ,deces)
 def rendre_pnj():
  b=ouvrir('squatter_cool')['bataille']
  # Choix serveur de doctrine, aucun ordre du joueur ne décide pour le PNJ.
  q.execute("UPDATE batailles SET decision_b='rendre' WHERE id=%s",(b,))
  exige(rpc('militaire_bataille_poursuivre',(b,0,req(120001))))
  q.execute("SELECT contexte->'resultat_civil'->>'issue',round_courant FROM batailles WHERE id=%s",(b,));assert q.fetchone()==('neutralises',0)
  q.execute("SELECT data::jsonb->>'pnj' FROM terrains_etat WHERE id='republic_terrain-a-batir'");assert q.fetchone()[0] is None
  q.execute("SELECT m.statut FROM pnj_membres m JOIN batailles_engagements e ON e.pnj_id=m.id WHERE e.bataille_id=%s",(b,));assert q.fetchone()[0]!='mort'
 cas('squatteurs_reddition_automate_reelle_sans_mort_sans_second_combat',rendre_pnj)
 def ancienne():
  pret();exige(rpc('crime_neutraliser',('C','mains',10)),'combat_universel_requis')
  q.execute("SELECT pa,hp FROM personnages_donnees WHERE name='A'");assert q.fetchone()==(100,100)
 cas('ancien_jet_neutraliser_inaccessible_aucun_contournement',ancienne)
 def issue_reelle(attendue):
  # Rechercher un seed reproductible du vrai moteur, jamais fabriquer un résultat.
  for seed in range(50):
   q.execute('SAVEPOINT recherche')
   q.execute('SELECT setseed(%s)',(seed/50-0.5,))
   pret('squatter_cool')
   if attendue=='defaite':sql("UPDATE personnages_donnees SET pa=3 WHERE name='A'")
   b=exige(rpc('combat_ouvrir',('terrain-a-batir','mains',req(130000))))['bataille']
   v=jusquau_bout(b,131000)
   if v['issue']==attendue:
    q.execute("SELECT data::jsonb FROM terrains_etat WHERE id='republic_terrain-a-batir'");e=q.fetchone()[0]
    if attendue=='tues':
     assert e.get('pnj')=='cadavre',e
     q.execute("SELECT m.statut FROM pnj_membres m JOIN batailles_engagements x ON x.pnj_id=m.id WHERE x.bataille_id=%s",(b,));assert q.fetchone()[0]=='mort'
    else:assert e.get('pnj')=='squatter_cool',e
    q.execute('RELEASE SAVEPOINT recherche');return
   q.execute('ROLLBACK TO SAVEPOINT recherche');q.execute('RELEASE SAVEPOINT recherche')
  raise AssertionError('Aucune issue réelle '+attendue+' sur les 50 seeds testés')
 for issue in ['tues','defaite']:cas('squatteurs_issue_reelle_obligatoire_'+issue,lambda issue=issue:issue_reelle(issue))
 def mains():
  b=ouvrir()['bataille'];q.execute("SELECT arme_feu,bonus_arme FROM militaire_bataille_combattants(%s,'acteur')",(b,));assert q.fetchone()==(False,0)
 cas('civil_mains_ne_selectionne_pas_une_arme_automatiquement',mains)
 def fuite_pnj():
  b=ouvrir('squatter_cool')['bataille'];q.execute("UPDATE batailles SET decision_b='replier' WHERE id=%s",(b,))
  exige(rpc('militaire_bataille_poursuivre',(b,0,req(140000))))
  q.execute("SELECT contexte->'resultat_civil'->>'issue' FROM batailles WHERE id=%s",(b,));v=q.fetchone()[0];assert v=='neutralises',v
  q.execute("SELECT m.rue_noeud_id,m.building_id FROM pnj_membres m JOIN batailles_engagements e ON e.pnj_id=m.id WHERE e.bataille_id=%s",(b,));v=q.fetchone();assert v==('rue-1',None),v
 cas('squatteurs_fuite_automate_deplacement_reel_pas_une_mort',fuite_pnj)
 ctx['preuves_extension']['civil']='Ouverture, paiement, mêmes rounds, profils uniques et décisions initiales réels ; base jetable, corps vivants communiqués.'
if __name__=='__main__':sys.exit(c.f.d.c.c.lancer(lambda ctx:c.f.suite(ctx,lambda ctx:c.suite(ctx,suite))))
