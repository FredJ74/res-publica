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
 q.execute((R/'migrations/20261031115817_justice_position_cellule_serveur.sql').read_text())
 q.execute((R/'migrations/20261031115823_groupes_separation_ecrou.sql').read_text())
 for f in ['20261031115856_combats_profils_et_occupation_unique.sql','20261031115857_combat_ouverture_civile_commune.sql','20261031115858_combat_civil_rounds_et_issues_communes.sql','20261031115859_combat_fermeture_ancienne_porte_et_automates.sql','20261031115900_combat_composition_commune_depuis_graines.sql','20261031115901_combat_cibles_presence_canonique.sql']:
  q.execute((R/'migrations'/f).read_text());q.execute((R/'migrations'/f).read_text())
 # Fonctions pures réelles #258 : compatibilité avec les soldes/positions
 # confirmés, sans rejouer la migration déjà appliquée ni toucher un joueur.
 for nom in ['fiche_valeur_normalisee','fiche_fusionner_ecran']:
  q.execute(re.search(r'CREATE OR REPLACE FUNCTION public\.'+nom+r'\(.*?\$function\$;',(R/'migrations/20261030160000_fiche_fusion_trois_voies.sql').read_text(),re.S)[0])
 # Contre-épreuves : mutations de la base jetable seulement.
 if '--contre-issue-fausse' in sys.argv:
  q.execute("SELECT pg_get_functiondef('combat_finaliser_interne(bigint)'::regprocedure)");source=q.fetchone()[0];assert "issue:='tues'" in source;q.execute(source.replace("issue:='tues'","issue:='neutralises'"))
 if '--contre-double-paiement' in sys.argv:
  q.execute("SELECT pg_get_functiondef('combat_ouvrir_interne(text,text,uuid)'::regprocedure)");source=q.fetchone()[0];a='IF FOUND THEN RETURN v;END IF;';assert a in source;q.execute(source.replace(a,"IF FOUND THEN PERFORM public.payer_ordre(moi,'neutraliser_'||p_mode,2,0);RETURN v;END IF;"))
 if '--contre-PNJ-immobile' in sys.argv:
  q.execute("SELECT pg_get_functiondef('militaire_repli_pnj_interne(bigint,text,integer)'::regprocedure)");source=q.fetchone()[0];a=' PERFORM public.pnj_positions_separer_interne(positions);';assert a in source;q.execute(source.replace(a,' -- mouvement omis par la contre-épreuve'))
 q.execute(re.search(r'INSERT INTO public.ordres_couts .*?ON CONFLICT DO NOTHING;', (R/'migrations/20261027110100_crimes_actes_serveur.sql').read_text(),re.S)[0])
 # Le vrai détecteur de crime remplace le substitut du vieux banc de contrat.
 q.execute("SELECT to_regprocedure('public.crime_detecter_interne(text,text,boolean)')")
 if q.fetchone()[0] is not None:q.execute('ALTER FUNCTION crime_detecter_interne(text,text,boolean) RENAME TO crime_detecter_fixture_ancienne')
 source=(R/'migrations/20261027110000_crimes_socle_serveur.sql').read_text()
 for nom in ['crime_rechercher_interne','crime_detecter_interne']:
  q.execute(re.search(r'CREATE OR REPLACE FUNCTION public\.'+nom+r'\(.*?\$function\$;',source,re.S)[0])
 q.execute('ALTER TABLE terrains_etat ADD CONSTRAINT terrains_etat_pkey PRIMARY KEY(id)')
 for ligne in (R/'baseline/seeds/92_mixte/militaire_armes_bonus.sql').read_text().splitlines():
  if ligne.startswith('INSERT INTO'):q.execute(ligne[:-1]+' ON CONFLICT DO NOTHING;')
 # Courrier réel du dépôt ; tables de décor selon leurs DDL canoniques.
 for table in ['mails','mails_envois_systeme']:
  q.execute('SELECT to_regclass(%s)',('public.'+table,))
  if q.fetchone()[0] is None:q.execute(re.search(r'CREATE TABLE public\.'+table+r' \(.*?\n\);',(R/'baseline/domaines/communication/10_tables.sql').read_text(),re.S)[0])
 q.execute(re.search(r'CREATE OR REPLACE FUNCTION public\.mail_systeme_poser_interne\(.*?\$function\$;',(R/'baseline/domaines/communication/20_fonctions.sql').read_text(),re.S)[0])
 ctx['installer_fonction_canonique']('militaire_mes_batailles')
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
 def cinq(action):
  # Les rounds peuvent légitimement finir tôt. Trouver un seed où les deux
  # camps survivent cinq rounds, sans retoucher leurs caractéristiques.
  for seed in range(50):
   q.execute('SAVEPOINT recherche_cinq');b=ouvrir()['bataille'];q.execute('SELECT setseed(%s)',(seed/50-0.5,))
   termine=False
   for n in range(5):
    if n:
     exige(rpc('militaire_bataille_decider',(b,'rendre',n,req(150000+n))),'cinq_rounds_obligatoires')
     exige(rpc('militaire_bataille_decider',(b,'replier',n,req(151000+n))),'cinq_rounds_obligatoires')
    v=exige(rpc('militaire_bataille_poursuivre',(b,n,req(152000+n))))
    assert v['round']==n+1,v
    if v.get('terminee'):termine=True;break
   if not termine:q.execute('RELEASE SAVEPOINT recherche_cinq');break
   q.execute('ROLLBACK TO SAVEPOINT recherche_cinq');q.execute('RELEASE SAVEPOINT recherche_cinq')
  else:raise AssertionError('Aucun combat resté ouvert après cinq rounds réels')
  et=exige(rpc('militaire_bataille_etat',(b,)))['bataille'];assert et['round_courant']==5 and not et['phase_initiale']
  v=exige(rpc('militaire_bataille_decider',(b,action,5,req(153000))))
  assert rpc('militaire_bataille_decider',(b,action,5,req(153000)))==v
  q.execute("SELECT pa,hp,current_building,current_street FROM personnages_donnees WHERE name='A'");pa,hp,bat,rue=q.fetchone()
  if action=='replier':assert (bat,rue)==(None,'rue-1')
  elif action=='rendre':assert pa==0 and hp>0 and bat=='terrain-a-batir'
 for action in ['replier','rendre']:cas('civil_cinq_vrais_rounds_puis_'+action,lambda action=action:cinq(action))
 def panne():
  pret();q.execute("CREATE FUNCTION panne_ouverture_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_fixture';END$$")
  q.execute('CREATE TRIGGER panne_ouverture_fixture BEFORE INSERT ON batailles_engagements FOR EACH ROW EXECUTE FUNCTION panne_ouverture_fixture()')
  q.execute('SAVEPOINT panne')
  try:rpc('combat_ouvrir',('C','mains',req(154000)))
  except Exception as e:assert 'panne_fixture' in str(e);q.execute('ROLLBACK TO SAVEPOINT panne')
  else:raise AssertionError('la panne aval a été ignorée')
  q.execute("SELECT pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()[0]==100
  q.execute('SELECT count(*) FROM batailles');assert q.fetchone()[0]==0
  q.execute('SELECT count(*) FROM navigation_requetes');assert q.fetchone()[0]==0
 cas('civil_panne_aval_annule_paiement_bataille_et_recu',panne)
 def prive():
  for fonction in ['combat_ouvrir_interne(text,text,uuid)','combat_agression_preparer_interne(text,text,integer)','combat_finaliser_interne(bigint)']:
   for role in ['anon','authenticated','service_role']:
    q.execute("SELECT has_function_privilege(%s,%s,'execute')",(role,fonction));assert not q.fetchone()[0],(fonction,role)
 cas('civil_aucune_porte_interne_accessible_au_navigateur',prive)
 def obsolete():
  b=ouvrir('squatter_cool')['bataille'];q.execute("SELECT pnj_id FROM batailles_engagements WHERE bataille_id=%s AND pnj_id IS NOT NULL",(b,));pnj=q.fetchone()[0]
  sql("DELETE FROM batailles_groupes;DELETE FROM batailles_engagements;DELETE FROM batailles;DELETE FROM navigation_requetes")
  sql("UPDATE terrains_etat SET data=(data::jsonb-'pnj') WHERE id='republic_terrain-a-batir'")
  exige(rpc('combat_ouvrir',(pnj,'mains',req(160000))),'occupation_obsolete')
  q.execute("SELECT pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()[0]==98
 cas('occupation_resolue_ancien_identifiant_refuse_sans_second_paiement',obsolete)
 def accompagnant():
  pret();sql("UPDATE pnj_membres SET leader_pj='C',leader_pnj_id=NULL,ville=NULL,building_id=NULL,room_id=NULL,rue_noeud_id=NULL WHERE id='ancre'")
  b=exige(rpc('combat_ouvrir',('ancre','mains',req(161000))))['bataille']
  q.execute("SELECT personnage,pnj_id,groupe_id FROM batailles_engagements WHERE bataille_id=%s AND camp='defenseur' ORDER BY personnage NULLS LAST",(b,));assert q.fetchall()==[('C',None,'defenseur|pj:C'),(None,'ancre','defenseur|pj:C')]
  q.execute("SELECT leader FROM batailles_groupes WHERE bataille_id=%s AND camp='defenseur'",(b,));assert q.fetchone()[0]=='C'
 cas('civil_cibler_un_accompagnant_engage_le_groupe_reel_et_son_chef',accompagnant)
 for mode in ['mains','arme','feu']:
  def armes(mode=mode):
   pret();sql("UPDATE personnages_donnees SET inventory='[{\"name\":\"Revolver .38\",\"type\":\"arme\",\"sousType\":\"poing\"},{\"name\":\"Couteau de poche\",\"type\":\"arme\",\"sousType\":\"blanche\"}]',resources='{\"dis\":50}' WHERE name IN ('A','C')")
   v=exige(rpc('combat_ouvrir',('C',mode,req(162000))));b=v['bataille']
   q.execute("SELECT arme_feu,arme_cle,bonus_arme FROM militaire_bataille_combattants(%s,'acteur')",(b,));feu,cle,bonus=q.fetchone()
   assert feu==(mode=='feu') and bonus==({'mains':0,'arme':5,'feu':8}[mode]),(mode,feu,cle,bonus)
   q.execute("SELECT arme_feu,bonus_arme FROM militaire_bataille_combattants(%s,'defenseur')",(b,));assert q.fetchone()==(True,8)
   assert rpc('combat_ouvrir',('C',mode,req(162000)))==v
   q.execute("SELECT pa,resources->>'dis' FROM personnages_donnees WHERE name='A'");assert q.fetchone()==(97 if mode=='feu' else 98,'30' if mode=='feu' else '50')
  cas('civil_mode_'+mode+'_borne_arme_et_paiement_sans_modifier_defenseur',armes)
 def chef_reel():
  for seed in range(50):
   q.execute('SAVEPOINT recherche_chef');pret();q.execute('SELECT setseed(%s)',(seed/50-0.5,))
   exige(rpc('groupe_pj_rejoindre',('A',),qui='B'));sql("UPDATE personnages_donnees SET pa=3 WHERE name='A'")
   b=exige(rpc('combat_ouvrir',('C','mains',req(163000))))['bataille'];trouve=False
   for n in range(10):
    q.execute('SELECT round_courant,statut FROM batailles WHERE id=%s',(b,));nr,statut=q.fetchone()
    if statut=='terminee':break
    v=exige(rpc('militaire_bataille_poursuivre',(b,nr,req(164000+n))))
    q.execute("SELECT a.pa,b.pa,a.current_building FROM personnages_donnees a CROSS JOIN personnages_donnees b WHERE a.name='A' AND b.name='B'");pa,pa_b,lieu=q.fetchone()
    q.execute('SELECT round_courant,statut FROM batailles WHERE id=%s',(b,));nr,statut=q.fetchone()
    if pa==0 and pa_b>0 and statut=='en_cours':
     assert lieu=='terrain-a-batir'
     q.execute("SELECT chef FROM groupes_pj_adhesions WHERE membre='B'");assert q.fetchone()[0]=='A'
     exige(rpc('militaire_bataille_decider',(b,'tenir',nr,req(165000)),qui='B'),'pas_chef_de_groupe')
     exige(rpc('militaire_bataille_poursuivre',(b,nr,req(166000)),qui='B'));trouve=True;break
   if trouve:q.execute('RELEASE SAVEPOINT recherche_chef');return
   q.execute('ROLLBACK TO SAVEPOINT recherche_chef');q.execute('RELEASE SAVEPOINT recherche_chef')
  raise AssertionError('Aucun chef neutralisé avec compagnon encore engagé')
 cas('civil_chef_zero_reel_ne_dissout_pas_groupe_et_compagnon_continue',chef_reel)
 def gamma():
  pret();sql("UPDATE pnj_membres SET classe='gamma',building_id='terrain-a-batir',room_id='terrain' WHERE id='ancre'")
  exige(rpc('combat_ouvrir',('ancre','mains',req(167000))),'cible_protegee')
  q.execute("SELECT pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()[0]==100
 cas('civil_PNJ_gamma_protege_meme_par_appel_direct',gamma)
 def historique():
  pret();sql("DELETE FROM services_militaires WHERE personnage='C';DELETE FROM guerres")
  ctx['bataille_mixte_decor']()
  q.execute('SELECT count(*) FROM batailles_engagements WHERE bataille_id=71');assert q.fetchone()[0]>4
  v=exige(rpc('militaire_bataille_poursuivre',(71,0,req(168000))));assert v['round']==1,v
 cas('armee_recrutement_et_round_mixte_preserves_apres_extraction_commune',historique)
 def partiel():
  pret('squatter_cool');q.execute('ALTER FUNCTION combat_bataille_completer_groupes_interne(bigint,text,text,text,text) RENAME TO composition_absente_fixture')
  exige(rpc('combat_ouvrir',('terrain-a-batir','mains',req(169000))),'installation_incomplete')
  q.execute("SELECT pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()[0]==100
  q.execute("SELECT count(*) FROM pnj_membres WHERE id LIKE 'occupation:%'");assert q.fetchone()[0]==0
  q.execute('SELECT count(*) FROM batailles');assert q.fetchone()[0]==0
 cas('civil_installation_partielle_refuse_avant_PNJ_paiement_et_bataille',partiel)
 for action in ['replier','rendre']:
  def defenseur(action=action):
   b=ouvrir()['bataille'];v=exige(rpc('militaire_bataille_etat',(b,),qui='C'))['bataille'];assert v['phase_initiale'] and v['peut_decider']
   exige(rpc('militaire_bataille_decider',(b,action,0,req(170000)),qui='C'))
   q.execute("SELECT pa,current_building,current_street FROM personnages_donnees WHERE name='C'");pa,bat,rue=q.fetchone()
   if action=='replier':assert (bat,rue)==(None,'rue-1')
   else:assert pa==0 and bat=='terrain-a-batir'
   q.execute("SELECT pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()[0]==98
  cas('civil_defenseur_connecte_decision_initiale_'+action,defenseur)
 def notification():
  b=ouvrir()['bataille'];q.execute("SELECT to_player,count(*) FROM mails WHERE subject='Affrontement' AND body LIKE %s GROUP BY to_player ORDER BY to_player",('%Référence : '+str(b)+'.%',));assert q.fetchall()==[('A',1),('C',1)]
  exige(rpc('combat_ouvrir',('C','mains',req(100001))))
  q.execute("SELECT count(*) FROM mails WHERE subject='Affrontement' AND body LIKE %s",('%Référence : '+str(b)+'.%',));assert q.fetchone()[0]==2
 cas('civil_notification_persistante_reelle_aux_deux_PJ_sans_doublon',notification)
 def rapports():
  b=ouvrir()['bataille'];jusquau_bout(b,171000)
  for qui in ['A','C']:
   v=exige(rpc('militaire_mes_batailles',(10,),qui=qui));bt=next(x for x in v['batailles'] if x['id']==b);assert bt['statut']=='terminee' and len(bt['rounds'])>0
   v=exige(rpc('militaire_bataille_etat',(b,),qui=qui));assert v['bataille']['statut']=='terminee' and len(v['bataille']['rounds'])>0
  exige(rpc('militaire_bataille_etat',(b,),qui='D'),'non_engage')
  assert not any(x['id']==b for x in exige(rpc('militaire_mes_batailles',(10,),qui='D'))['batailles'])
 cas('civil_rapports_persistants_deux_participants_absents_et_tiers_exclu',rapports)
 def nom_pnj():
  pret();sql("UPDATE pnj_membres SET nom='Nom unique de fixture',building_id='terrain-a-batir',room_id='terrain' WHERE id='ancre'")
  b=exige(rpc('combat_ouvrir',('Nom unique de fixture','mains',req(172000))))['bataille']
  q.execute("SELECT pnj_id FROM batailles_engagements WHERE bataille_id=%s AND camp='defenseur'",(b,));assert q.fetchone()[0]=='ancre'
 cas('civil_nom_PNJ_unique_resolu_vers_identite_canonique',nom_pnj)
 def ambigu():
  pret();sql("UPDATE pnj_membres SET nom='Nom ambigu de fixture',statut='actif' WHERE id IN ('ancre','autre')")
  exige(rpc('combat_ouvrir',('Nom ambigu de fixture','mains',req(173000))),'cible_ambigue')
  q.execute("SELECT pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()[0]==100
 cas('civil_nom_PNJ_ambigu_refuse_avant_tout_paiement',ambigu)
 def tentative():
  b=ouvrir()['bataille']
  q.execute("SELECT count(*) FROM personnages_donnees d CROSS JOIN LATERAL jsonb_array_elements(coalesce(recherche,'[]')) x WHERE name='A' AND x->>'acte'='tentative_assassinat'");avant=q.fetchone()[0]
  exige(rpc('militaire_bataille_decider',(b,'rendre',0,req(174000))))
  q.execute("SELECT count(*) FROM personnages_donnees d CROSS JOIN LATERAL jsonb_array_elements(coalesce(recherche,'[]')) x WHERE name='A' AND x->>'acte'='tentative_assassinat'");assert q.fetchone()[0]==avant+1
  q.execute('SELECT combat_finaliser_interne(%s)',(b,));assert q.fetchone()[0]['issue']=='defaite'
  q.execute("SELECT count(*) FROM personnages_donnees d CROSS JOIN LATERAL jsonb_array_elements(coalesce(recherche,'[]')) x WHERE name='A' AND x->>'acte'='tentative_assassinat'");assert q.fetchone()[0]==avant+1
 cas('civil_echec_conserve_motif_penal_historique_sans_double_traitement',tentative)
 def cibles():
  pret();sql("UPDATE pnj_membres SET nom='Garde republicain',statut='actif',classe='beta',pa=pnj_pa_max(),car_vol=(pnj_metier_profil('agent_securite')->>'VOL')::int,car_per=(pnj_metier_profil('agent_securite')->>'PER')::int,car_dup=(pnj_metier_profil('agent_securite')->>'DUP')::int,ville='capitale',building_id='terrain-a-batir',room_id='terrain' WHERE id IN ('ancre','autre')")
  v=exige(rpc('combat_cibles_lire'));x=[x for x in v['cibles'] if x['nom']=='Garde republicain'];assert {x['id'] for x in x}=={'ancre','autre'}
  assert all(set(x)=={'id','nom','classe'} for x in x)
  sql("UPDATE pnj_membres SET building_id='autre-lieu' WHERE id='autre'")
  v=exige(rpc('combat_cibles_lire'));assert [x['id'] for x in v['cibles'] if x['nom']=='Garde republicain']==['ancre']
 cas('cibles_homonymes_identifiants_et_presence_sans_donnees_privees',cibles)
 def absent():
  pret('squatter_cool');v=exige(rpc('combat_cibles_lire'));assert any(x.get('occupation')=='squatter_cool' for x in v['cibles'])
  q.execute("SELECT count(*) FROM pnj_membres WHERE id LIKE 'occupation:%'");assert q.fetchone()[0]==0
 cas('cibles_lecture_squatteurs_ne_cree_aucune_entite',absent)
 def fiche():
  q.execute("SELECT fiche_fusionner_ecran(%s::jsonb,%s::jsonb,%s::jsonb)",(json.dumps({'pa':99,'hp':100,'current_building':'ancien','current_room':'accueil'}),json.dumps({'pa':99,'hp':100,'current_building':'ancien','current_room':'accueil'}),json.dumps({'pa':0,'hp':0,'current_building':None,'current_room':None})))
  v=q.fetchone()[0];assert v['pa']==v['hp']==0 and v['current_building'] is None and v['current_room'] is None
 cas('fiche_258_sauvegarde_perimee_ne_defait_pas_combat_ni_fuite',fiche)
 def livraison_refuse():
  import importlib.util
  sp=importlib.util.spec_from_file_location('livraison219',R/'outils/livraison/preparer-groupes-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  import tempfile
  with tempfile.TemporaryDirectory() as d:
   f=Path(d)/'lot.sql';nb=m.preparer(str(f));assert nb==88
   texte=f.read_text();prevol=re.search(r'DO \$prevol\$.*?\$prevol\$;',texte,re.S)[0]
  q.execute('CREATE SCHEMA IF NOT EXISTS supabase_migrations;CREATE TABLE IF NOT EXISTS supabase_migrations.schema_migrations(version text,name text)')
  q.execute('INSERT INTO supabase_migrations.schema_migrations(version) VALUES(%s)',('20261031115739',))
  q.execute('SAVEPOINT collision')
  try:q.execute(prevol)
  except Exception as e:assert '219_version_deja_enregistree' in str(e);q.execute('ROLLBACK TO SAVEPOINT collision')
  else:raise AssertionError('collision de registre non refusée')
 cas('livraison_88_versions_collision_refusee_avant_DDL',livraison_refuse)
 def integrite_lot():
  import importlib.util,tempfile
  sp=importlib.util.spec_from_file_location('lot219',R/'outils/livraison/preparer-groupes-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  with tempfile.TemporaryDirectory() as d:
   f=Path(d)/'lot.sql';m.preparer(str(f));texte=f.read_text()
  empreinte=re.search(r'CREATE TEMP TABLE hg219_integrite.*?personnages_donnees d;',texte,re.S)[0]
  garde=re.search(r'DO \$integrite\$.*?\$integrite\$;',texte,re.S)[0]
  q.execute(empreinte);q.execute('ALTER TABLE personnages_donnees ADD COLUMN nouveaute_structurelle_fixture text');q.execute(garde)
  q.execute('SAVEPOINT mutation_interdite');q.execute("UPDATE personnages_donnees SET pa=pa+1 WHERE name='A'")
  try:q.execute(garde)
  except Exception as e:assert '219_fiche_PJ_modifiee_par_DDL' in str(e);q.execute('ROLLBACK TO SAVEPOINT mutation_interdite')
  else:raise AssertionError('la garde a accepté une mutation de PA')
 cas('livraison_empreinte_accepte_ajout_colonne_refuse_mutation_PJ',integrite_lot)
 def profil_manquant():
  pret();sql("UPDATE pnj_membres SET statut='actif',building_id='terrain-a-batir',room_id='terrain',car_vol=NULL WHERE id='ancre'")
  v=exige(rpc('combat_cibles_lire'));assert not any(x.get('id')=='ancre' for x in v['cibles'])
  exige(rpc('combat_ouvrir',('ancre','mains',req(180001))),'profil_combattant_incomplet')
  q.execute("SELECT pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()[0]==100
 cas('PNJ_profil_absent_ni_bouton_ni_debit_meme_par_appel_direct',profil_manquant)
 # Deux connexions et reçus réellement concurrents, décor fictif seulement.
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
    v=rpc('combat_ouvrir',('C','mains',req(155000)),cur=cur);cn.commit();return v
   finally:cn.close()
  with ThreadPoolExecutor(2) as pool:
   un=pool.submit(agir);deux=pool.submit(agir);a=exige(un.result(timeout=20));b=exige(deux.result(timeout=20));assert a==b
  q.execute("SELECT pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()[0]==98
  q.execute('SELECT count(*) FROM batailles');assert q.fetchone()[0]==1
  q.execute('SELECT count(*) FROM navigation_requetes');assert q.fetchone()[0]==1
 cas('civil_deux_connexions_un_combat_un_paiement_un_recu',concurrence)
 ctx['preuves_extension']['civil']='Ouverture et paiement atomiques, mêmes rounds civils/militaires et composition ; PNJ unique, mort/défaite/fuite/reddition réelles, cinq rounds puis décisions, chef neutralisé, armes, concurrence, panne et installation partielle. Base jetable ; aucun essai authentifié de production.'
if __name__=='__main__':sys.exit(c.f.d.c.c.lancer(lambda ctx:c.f.suite(ctx,lambda ctx:c.suite(ctx,suite))))
