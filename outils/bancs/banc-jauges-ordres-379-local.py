#!/usr/bin/env python3
"""Ordres POP/INF, vrais corps payer_ordre et périmètre militaire, cluster détruit.
Aucune connexion distante, aucun joueur réel. Cas annulés sauf concurrence fictive.
"""
import importlib.util,json,os,sys,tempfile,traceback
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('reliquats',R/'outils/bancs/banc-reliquats-379-local.py');h=importlib.util.module_from_spec(sp);sp.loader.exec_module(h)
def main():
 if os.environ.get('HG219_POSTGRES_BIN'):
  s=importlib.util.spec_from_file_location('pg17',R/'outils/baseline/epreuve-postgresql.py');p=importlib.util.module_from_spec(s);s.loader.exec_module(p);p.configurer_binaires(Path(os.environ['HG219_POSTGRES_BIN']))
 import pgserver,psycopg2
 from psycopg2.extras import Json
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-jauges-379-'),cleanup_mode='delete');c=None;cas=[]
 try:
  c=psycopg2.connect(srv.get_uri());q=c.cursor();q.execute('SHOW server_version_num');version=q.fetchone()[0]
  q.execute("CREATE ROLE authenticated;CREATE ROLE anon;CREATE ROLE service_role;CREATE SCHEMA auth;CREATE FUNCTION auth.uid()RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;GRANT USAGE ON SCHEMA public,auth TO authenticated")
  for f,n in [('personnage-et-presence','personnages_donnees'),('economie','ordres_couts'),('economie','ordres_couts_inconnus'),('economie','ordres_couts_ecarts'),('banque','comptes_bancaires'),('politique-et-elections','presidence_memoire_ordres'),('immobilier-et-territoire','acquisitions_transactions_internes'),('immobilier-et-territoire','permis_transactions_internes'),('militaire','compagnies_militaires')]:h.table(q,'baseline/domaines/'+f+'/10_tables.sql',n)
  for domaine,nom in [('finances-publiques',n)for n in ['caisses_batiments','budgets_municipaux','budgets_nationaux','recettes_municipales','salaires_caisses']]+[('immobilier-et-territoire','villes')]:
   h.table(q,'baseline/domaines/'+domaine+'/10_tables.sql',nom)
  q.execute('ALTER TABLE caisses_batiments ADD PRIMARY KEY(id);ALTER TABLE budgets_municipaux ADD PRIMARY KEY(id);ALTER TABLE budgets_nationaux ADD PRIMARY KEY(id);ALTER TABLE salaires_caisses ADD PRIMARY KEY(poste_id);ALTER TABLE villes ADD PRIMARY KEY(pays,ville);ALTER TABLE recettes_municipales ADD PRIMARY KEY(pays,ville,jour,canal)')
  for nom in ['salaire_caisse_de','recette_municipale','appliquer_taxe_transaction','caisse_institution_mouvement']:
   q.execute(h.fonction('baseline/domaines/finances-publiques/20_fonctions-1.sql',nom))
  q.execute(h.fonction('baseline/domaines/finances-publiques/20_fonctions-2.sql','vente_structure_encaisser'))
  for seed in ['95_a-regenerer/villes.sql','90_socle/salaires_caisses.sql']:
   q.execute((R/'baseline/seeds'/seed).read_text())
  q.execute("INSERT INTO budgets_nationaux(id,data)VALUES('republic','{\"tauxNational\":2}')")
  for ville in ['capitale','ville_a','ville_b']:
   q.execute("INSERT INTO budgets_municipaux(id,data)VALUES(%s,'{\"tauxLocal\":2}')",('republic_'+ville,))
   mairie='republic_mairie-capitale'if ville=='capitale'else'republic_mairie_'+ville
   q.execute("INSERT INTO caisses_batiments(id,data)VALUES(%s,'{\"solde\":0}'),(%s,'{\"solde\":0}')",(mairie,'republic_stade_'+ville))
  q.execute('ALTER TABLE personnages_donnees ADD PRIMARY KEY(name);ALTER TABLE personnages_donnees ENABLE ROW LEVEL SECURITY;CREATE VIEW personnages AS SELECT * FROM personnages_donnees;ALTER TABLE ordres_couts_inconnus ADD PRIMARY KEY(fn);ALTER TABLE ordres_couts_ecarts ADD PRIMARY KEY(fn,pa,cost)')
  for n in ['mon_personnage','est_appel_serveur','est_mon_personnage','exiger_acteur']:q.execute(h.fonction('baseline/domaines/socle/20_fonctions.sql',n))
  q.execute(h.fonction('baseline/domaines/economie/20_fonctions-2.sql','payer_ordre'))
  q.execute(h.fonction('baseline/domaines/militaire/20_fonctions-2.sql','militaire_inspection_perimetre'))
  for n in ['forum_topics','forum_posts']:h.table(q,'baseline/domaines/communication/10_tables.sql',n)
  h.table(q,'baseline/domaines/personnage-et-presence/10_tables.sql','organisations')
  q.execute('ALTER TABLE forum_topics ADD PRIMARY KEY(id);ALTER TABLE forum_posts ADD PRIMARY KEY(id);ALTER TABLE forum_posts ADD FOREIGN KEY(topic_id)REFERENCES forum_topics(id);ALTER TABLE organisations ADD PRIMARY KEY(id)')
  for n in ['hospitalisation_jour_pa0','hospitalisation_ecriture_j0_garder']:q.execute(h.fonction('migrations/20261101171000_hospitalisation_pa0.sql',n))
  for n in ['forum_topics','forum_posts']:q.execute('CREATE TRIGGER trg_hospitalisation_ecriture_j0 BEFORE INSERT ON '+n+' FOR EACH ROW EXECUTE FUNCTION hospitalisation_ecriture_j0_garder()')
  q.execute((R/'migrations/20261103010231_forum_publications_jauges_serveur.sql').read_text())
  q.execute((R/'baseline/seeds/95_a-regenerer/ordres_couts.sql').read_text())
  q.execute("INSERT INTO personnages_donnees(name,country,user_id,current_city,current_building,career,pa,hp,moral,resources,arg,liquide,stats)VALUES('Fixture','republic','00000000-0000-4000-9000-000000000001','capitale','assemblee','press',20,70,60,'{\"pop\":10,\"inf\":10,\"dis\":42}',100,100,'{\"INT\":12}');")
  q.execute("INSERT INTO personnages_donnees(name,country,user_id,archetype,poste,pa,hp,moral,resources,arg,liquide)VALUES('AncienneFixture','republic','00000000-0000-4000-9000-000000000002','ambitieux','{\"id\":\"president\"}',20,70,60,'{\"pop\":10,\"inf\":85}',100,100)")
  q.execute((R/'migrations/20261103011234_objectifs_secrets_jauges_serveur.sql').read_text())
  migration=(R/'migrations/20261103004219_jauges_ordres_transactionnels.sql').read_text();q.execute('SAVEPOINT installation');q.execute(migration);q.execute('ROLLBACK TO SAVEPOINT installation');q.execute("SELECT to_regprocedure('public.jauges_ordre_executer(text,uuid,jsonb)')IS NULL");assert q.fetchone()[0]
  q.execute(migration);q.execute(migration);cas.append({'cas':'installation_rollback_double_rejeu','ok':True})
  q.execute(h.re.search(r'CREATE TABLE IF NOT EXISTS public.organisation_commandes_recus \(.*?\n\);',(R/'migrations/20261031113600_organisations_commandes_administratives.sql').read_text(),h.re.S)[0])
  q.execute('ALTER TABLE organisation_commandes_recus ENABLE ROW LEVEL SECURITY')
  q.execute(h.fonction('migrations/20261102001000_organisations_vie_commandes_serveur.sql','organisation_vie_commande'))
  q.execute('REVOKE ALL ON FUNCTION organisation_vie_commande(text,text,text,jsonb)FROM PUBLIC,anon;GRANT EXECUTE ON FUNCTION organisation_vie_commande(text,text,text,jsonb)TO authenticated')
  orgmigration=(R/'migrations/20261103015011_organisations_jauges_commandes.sql').read_text()
  q.execute('SAVEPOINT org_install');q.execute(orgmigration);q.execute('ROLLBACK TO SAVEPOINT org_install')
  q.execute(orgmigration);q.execute(orgmigration);cas.append({'cas':'organisation_patch_garde_rollback_double_rejeu','ok':True})
  if '--contre-rejeu-organisation'in sys.argv:
   q.execute("SELECT pg_get_functiondef('organisation_vie_commande(text,text,text,jsonb)'::regprocedure)")
   definition=q.fetchone()[0];avant="v_rec.resultat || public.organisation_jauges_fiche_interne(v_moi) || jsonb_build_object('rejeu',true)"
   assert definition.count(avant)==1
   q.execute(definition.replace(avant,"v_rec.resultat || jsonb_build_object('rejeu',true)"))

  def own(sql,args=None):
   if sql.startswith('ROLLBACK'):q.execute(sql);q.execute('RESET ROLE');return
   q.execute('RESET ROLE');q.execute(sql,args)if args else q.execute(sql);return q.fetchone()[0]if q.description else None
  def rpc(ordre,ident=1,ctx=None,cur=None,qui=1):
   cc=cur or q;cc.execute("SELECT set_config('role','authenticated',true),set_config('request.path','/rpc/jauges_ordre_executer',true),set_config('request.jwt.claim.sub',%s,true)",(f'00000000-0000-4000-9000-{qui:012d}',));cc.execute('SELECT public.jauges_ordre_executer(%s,%s,%s)',(ordre,f'00000000-0000-4000-9000-{ident:012d}',Json(ctx or {})));return cc.fetchone()[0]
  def photo():return own("SELECT to_jsonb(d)FROM personnages_donnees d WHERE name='Fixture'")
  def case(n,fn):
   own('SAVEPOINT scenario')
   try:fn();cas.append({'cas':n,'ok':True})
   except Exception as e:cas.append({'cas':n,'ok':False,'erreur':str(e),'trace':traceback.format_exc(limit=4)})
   finally:own('ROLLBACK TO SAVEPOINT scenario')
  def journaliste():
   a=photo();v=rpc('observer_debats');b=photo();assert v['ok']and v['inf']==11 and b['pa']==19
   for k in a:
    if k not in ['resources','pa']:assert a[k]==b[k],k
   assert b['resources']==dict(a['resources'],inf=11)
  case('observer_paiement_et_gain_sans_autre_mutation',journaliste)
  def deux():
   assert rpc('observer_debats')['inf']==11;assert rpc('observer_debats',2)['inf']==12;assert photo()['pa']==18
  case('deux_gains_legitimes_deux_requetes',deux)
  def perdu():
   rpc('observer_debats');v=rpc('observer_debats');assert v['rejeu']and v['inf']==11 and photo()['pa']==19
   rpc('observer_debats',2);v=rpc('observer_debats');assert v['rejeu']and v['inf']==12
  case('reponse_perdue_rejeu_et_recu_ancien_ne_retablit_pas_snapshot',perdu)
  def triche():
   p=photo();v=rpc('observer_debats',ctx={'inf':500});assert v['raison']=='contexte_invalide'and photo()==p
  case('delta_falsifie_refuse_sans_paiement',triche)
  def manque():
   own("UPDATE personnages_donnees SET pa=0");p=photo();assert rpc('observer_debats')['raison']=='pa_insuffisants'and photo()==p
  case('fonds_PA_refus_sans_effet',manque)
  def rue():
   own("UPDATE personnages_donnees SET current_building=NULL");p=photo();assert rpc('observer_debats')['raison']=='pas_sur_place'and photo()==p
  case('presence_serveur',rue)
  def autre():
   own("UPDATE personnages_donnees SET career='craft'");v=rpc('observer_debats');assert v['inf']==10 and v['pa']==19
  case('non_journaliste_observe_sans_bonus',autre)
  def haut():
   own("UPDATE personnages_donnees SET resources='{\"pop\":100,\"inf\":99.5}'");v=rpc('observer_debats');assert v['inf']==100 and v['pop']==100
  case('plafond_et_fraction_historique',haut)
  def inspection():
   own("UPDATE personnages_donnees SET poste='{\"id\":\"min_def\"}'")
   a=rpc('inspecter_troupes',ctx={'niveau':'revue'});b=rpc('inspecter_troupes',2,{'niveau':'detaillee'});assert a['inf']==13 and b['inf']==18 and b['pa']==17
  case('inspection_meme_perimetre_revue_et_detaillee',inspection)
  def refuse():
   p=photo();assert rpc('inspecter_troupes',ctx={'niveau':'revue'})['ok']is False and photo()==p
  case('inspection_citoyen_refuse',refuse)
  def faim():
   p=photo();assert rpc('greve_faim')['raison']=='detention_requise'and photo()==p
   own("UPDATE personnages_donnees SET current_building='qhs-prison',est_emprisonne='{\"motif\":\"fixture\"}',hp=3")
   v=rpc('greve_faim');assert v['hp']==1 and v['pop']==13 and v['pa']==20;assert rpc('greve_faim')['pop']==13
  case('faim_detention_HP_plancher_et_rejeu',faim)
  def dossier():
   own("UPDATE personnages_donnees SET current_building='palais-gouvernement'");p=photo();assert rpc('consulter_dossiers_gouv')['raison']=='poste_requis'and photo()==p
   own("UPDATE personnages_donnees SET poste='{\"id\":\"min_info\"}'");v=rpc('consulter_dossiers_gouv');assert v['inf']==12 and v['pa']==18
  case('dossier_poste_serveur',dossier)
  def lie():
   rpc('observer_debats');p=photo();assert rpc('inspecter_troupes',ctx={'niveau':'revue'})['raison']=='requete_reutilisee'and photo()==p
  case('requete_liee_a_intention',lie)
  def panne():
   own("CREATE FUNCTION fixture_panne_recu()RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_recu';END$$;CREATE TRIGGER fixture_panne_recu BEFORE INSERT ON jauges_actions_recus FOR EACH ROW EXECUTE FUNCTION fixture_panne_recu()")
   p=photo();own('SAVEPOINT panne')
   try:rpc('observer_debats');raise AssertionError('panne absente')
   except psycopg2.Error as e:assert 'panne_recu'in str(e);own('ROLLBACK TO SAVEPOINT panne')
   assert photo()==p
  case('panne_recu_annule_PA_et_gain',panne)
  def droits():
   assert own("SELECT has_function_privilege('authenticated','jauges_ordre_executer(text,uuid,jsonb)','EXECUTE')")
   assert not own("SELECT has_function_privilege('anon','jauges_ordre_executer(text,uuid,jsonb)','EXECUTE')")
   assert not own("SELECT has_table_privilege('authenticated','jauges_actions_recus','INSERT')")
  case('recu_non_fabricable_par_client',droits)
  def message(**kw):
   return dict({'forum':'national','topic':None,'titre':'Sujet de fixture','contenu':'Texte réel fictif','blocs':[],'mise_en_page':None,'organisation':None,'secret':False,'icone':None},**kw)
  def forum():
   v=rpc('forum_publier',ctx=message());assert v['pop']==12 and v['pa']==20
   r=rpc('forum_publier',2,message(topic=v['topic'],titre=None));assert r['pop']==13
   assert own('SELECT count(*)FROM forum_topics')==1 and own('SELECT count(*)FROM forum_posts')==2
   assert own('SELECT replies FROM forum_topics')==1
   r=rpc('forum_publier',ctx=message());assert r['rejeu']and r['pop']==13 and own('SELECT count(*)FROM forum_posts')==2
  case('forum_sujet_reponse_rejeu_meme_transaction',forum)
  def forumdeux():
   assert rpc('forum_publier',ctx=message())['pop']==12
   assert rpc('forum_publier',2,message())['pop']==14
  case('forum_deux_publications_legitimes_distinctes',forumdeux)
  def forumfaux():
   p=photo();assert rpc('forum_publier',ctx=message(pop=900))['raison']=='champs_interdits'and photo()==p
   rpc('forum_publier',ctx=message());p=photo();assert rpc('forum_publier',ctx=message(contenu='autre'))['raison']=='requete_reutilisee'and photo()==p
  case('forum_delta_et_requete_recyclee_refuses',forumfaux)
  def forumprive():
   p=photo();assert rpc('forum_publier',ctx=message(forum='gouvernement'))['raison']=='poste_requis'and photo()==p
   own("UPDATE personnages_donnees SET career='craft'");assert rpc('forum_publier',ctx=message(forum='presse'))['raison']=='carriere_requise'
   assert rpc('forum_publier',ctx=message(forum='presidence'))['raison']=='poste_requis'
   own("INSERT INTO forum_topics(id,forum_id,title,author,country)VALUES('presse','presse','Autre sujet','AutreFixture','republic')")
   assert rpc('forum_publier',ctx=message(topic='presse',titre=None))['pop']==11
  case('forum_presse_presidence_reponses_publiques_gouvernement_prive',forumprive)
  def forumterritoire():
   for f in ['local_ville_a','tribunal_ville_b','inconnu']:
    p=photo();assert rpc('forum_publier',ctx=message(forum=f))['raison']=='forum_inconnu'and photo()==p
   own("INSERT INTO forum_topics(id,forum_id,title,author,country)VALUES('etranger','national','Sujet étranger','AutreFixture','soviet')")
   assert rpc('forum_publier',ctx=message(topic='etranger',titre=None))['raison']=='territoire_invalide'
  case('forum_restrictions_territoriales_et_sujet_absent',forumterritoire)
  def organisation():
   own("INSERT INTO organisations(id,country_origine,data)VALUES('o','republic','{\"nom\":\"Orga fixture\",\"chef\":\"AutreFixture\",\"membres\":[]}')")
   assert rpc('forum_publier',ctx=message(organisation='o'))['raison']=='chef_organisation_requis'
   assert rpc('forum_publier',ctx=message(forum='org_o'))['raison']=='membre_requis'
   own("UPDATE organisations SET data='{\"nom\":\"Orga fixture\",\"chef\":\"Fixture\",\"membres\":[{\"nom\":\"Fixture\"}]}'")
   v=rpc('forum_publier',ctx=message(forum='org_o',organisation='o',secret=True));assert v['pop']==12
   assert own('SELECT author FROM forum_posts')=='Orga fixture'and own('SELECT author_real FROM forum_posts')=='Fixture'
  case('forum_identite_organisation_et_membre_attestes',organisation)
  def forumpanne():
   own("CREATE FUNCTION fixture_refuser_post()RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RETURN NULL;END$$;CREATE TRIGGER fixture_refuser_post BEFORE INSERT ON forum_posts FOR EACH ROW EXECUTE FUNCTION fixture_refuser_post()")
   p=photo();assert rpc('forum_publier',ctx=message())['raison']=='publication_refusee'and photo()==p
   assert own('SELECT count(*)FROM forum_topics')==0 and own('SELECT count(*)FROM jauges_actions_recus')==0
  case('forum_refus_post_annule_sujet_POP_et_recu',forumpanne)
  def hospitalise():
   own("UPDATE personnages_donnees SET hospitalisation=jsonb_build_object('regime','pa0','dateDebutParis',(now()AT TIME ZONE'Europe/Paris')::date::text)")
   p=photo();assert rpc('forum_publier',ctx=message())['raison']=='publication_refusee'and photo()==p
   assert own('SELECT count(*)FROM forum_topics')==0
  case('forum_declencheur_hospitalisation_j0_preserve',hospitalise)
  def layout():
   v=rpc('forum_publier',ctx=message(mise_en_page={'version':1,'elements':[{'type':'image','src':'fixture.webp'}]}));assert v['pop']==12
   assert own("SELECT content_layout->>'version'FROM forum_posts")=='1'
  case('forum_composition_et_images_preservees',layout)
  def objectifsanciens():
   v=rpc('objectifs_actualiser',qui=2);assert v['inf']==85 and v['gain_inf']==0 and len(v['objectifs_completes'])==3
  case('objectifs_eligibles_avant_bascule_aucun_recredit',objectifsanciens)
  def objectifsnouveaux():
   own("UPDATE personnages_donnees SET archetype='ambitieux',poste='{\"id\":\"president\"}'WHERE name='Fixture'")
   v=rpc('objectifs_actualiser');assert v['inf']==12 and v['gain_inf']==2 and len(v['objectifs_nouveaux'])==2 and v['pa']==20
   assert rpc('objectifs_actualiser',2)['gain_inf']==0 and rpc('objectifs_actualiser')['inf']==12
   own("UPDATE personnages_donnees SET resources=jsonb_set(resources,'{inf}','80')WHERE name='Fixture'")
   v=rpc('objectifs_actualiser',3);assert v['inf']==82 and v['gain_inf']==2 and v['objectifs_nouveaux']==['obj_inf80']
   v=rpc('objectifs_actualiser');assert v['inf']==82 and len(v['objectifs_completes'])==3
   own("UPDATE personnages_donnees SET resources=jsonb_set(resources,'{inf}','70')WHERE name='Fixture'");assert rpc('objectifs_actualiser',4)['gain_inf']==0
   own("UPDATE personnages_donnees SET resources=jsonb_set(resources,'{inf}','80')WHERE name='Fixture'");assert rpc('objectifs_actualiser',5)['gain_inf']==0
  case('objectifs_2_INF_par_lot_une_fois_meme_en_redevenant_eligible',objectifsnouveaux)
  def objectifsrejeu():
   own("UPDATE personnages_donnees SET archetype='ambitieux',poste='{\"id\":\"president\"}'WHERE name='Fixture'")
   own((R/'migrations/20261103011234_objectifs_secrets_jauges_serveur.sql').read_text())
   v=rpc('objectifs_actualiser');assert v['inf']==12 and v['gain_inf']==2
  case('objectifs_rejouer_migration_ne_mange_pas_nouvelle_eligibilite',objectifsrejeu)
  def objectifsfaux():
   p=photo();assert rpc('objectifs_actualiser',ctx={'gain_inf':99,'acquis':['obj_inf80']})['raison']=='contexte_invalide'and photo()==p
  case('objectifs_criteres_client_non_acceptes',objectifsfaux)
  def objectifsplafond():
   own("UPDATE personnages_donnees SET archetype='ambitieux',poste='{\"id\":\"president\"}',resources=jsonb_set(resources,'{inf}','99')WHERE name='Fixture'")
   v=rpc('objectifs_actualiser');assert v['inf']==100 and v['gain_inf']==2 and len(v['objectifs_nouveaux'])==3
   assert rpc('objectifs_actualiser',2)['gain_inf']==0 and photo()['resources']['inf']==100
  case('objectifs_plafond_100_lot_acquis_sans_recompense_retardee',objectifsplafond)
  def objectifscopie():
   own("UPDATE personnages_donnees SET archetype='ambitieux',poste='{\"id\":\"president\"}'WHERE name='Fixture'")
   assert rpc('objectifs_actualiser')['inf']==12
   own("UPDATE personnages_donnees SET resources=jsonb_set(resources,'{inf}','40')WHERE name='Fixture'")
   v=rpc('objectifs_actualiser');assert v['rejeu'] and v['inf']==40
  case('objectifs_reponse_perdue_rejeu_ne_recopie_pas_ancienne_jauge',objectifscopie)
  def objectifsprives():
   for f in ['objectifs_secrets_actualiser_interne(text)','objectifs_secrets_eligibles_interne(text)']:
    assert not own("SELECT has_function_privilege('authenticated',%s,'EXECUTE')",(f,))
   for table in ['jauges_objectifs_etats','jauges_objectifs_bascule']:
    assert not own("SELECT has_table_privilege('authenticated',%s,'INSERT,UPDATE,DELETE,SELECT')",(table,))
  case('objectifs_suivi_et_helpers_inaccessibles_au_navigateur',objectifsprives)
  def objectifspanne():
   own("UPDATE personnages_donnees SET archetype='ambitieux',poste='{\"id\":\"president\"}'WHERE name='Fixture'")
   own("CREATE FUNCTION fixture_panne_objectifs()RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_objectifs';END$$;CREATE TRIGGER fixture_panne_objectifs BEFORE INSERT ON jauges_actions_recus FOR EACH ROW EXECUTE FUNCTION fixture_panne_objectifs()")
   p=photo();suivi=own("SELECT to_jsonb(e)FROM jauges_objectifs_etats e WHERE acteur='Fixture'")
   own('SAVEPOINT panne_objectifs')
   try:rpc('objectifs_actualiser');raise AssertionError('panne absente')
   except psycopg2.Error as e:assert 'panne_objectifs'in str(e);own('ROLLBACK TO SAVEPOINT panne_objectifs')
   assert photo()==p and own("SELECT to_jsonb(e)FROM jauges_objectifs_etats e WHERE acteur='Fixture'")==suivi
  case('objectifs_panne_annule_gain_suivi_et_recu',objectifspanne)
  def stade(ville='capitale'):
   own("UPDATE personnages_donnees SET current_building='stade',current_room='buvette',current_city=%s WHERE name='Fixture'",(ville,))
  def caisses():return own("SELECT jsonb_object_agg(id,data)FROM caisses_batiments")
  for ville in ['capitale','ville_a','ville_b']:
   def consommation(ville=ville):
    stade(ville);v=rpc('consommer_buvette');assert v['ok']and v['pop']==12 and v['pa']==19 and v['arg']==50,v
    assert v['montant_preleve']==50 and v['taxe']['taxeLocale']==v['taxe']['taxeNationale']==1
    assert own("SELECT (data->>'solde')::numeric FROM caisses_batiments WHERE id=%s",('republic_stade_'+ville,))==48
    assert rpc('consommer_buvette')['pop']==12 and photo()['arg']==50
   case('buvette_'+ville+'_un_debit_taxes_caisse_POP_et_rejeu',consommation)
  def staderefus():
   p=photo();caisse=caisses();assert rpc('consommer_buvette')['raison']=='pas_sur_place'and photo()==p and caisses()==caisse
   stade();own("UPDATE personnages_donnees SET arg=0,liquide=0 WHERE name='Fixture'");p=photo()
   assert rpc('consommer_buvette')['raison']=='fonds_insuffisants'and photo()==p and caisses()==caisse
  case('buvette_rue_et_fonds_insuffisants_aucune_mutation',staderefus)
  def stadepanne():
   stade();p=photo();cash=caisses()
   own("CREATE FUNCTION fixture_panne_stade()RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_stade';END$$;CREATE TRIGGER fixture_panne_stade BEFORE INSERT ON jauges_actions_recus FOR EACH ROW EXECUTE FUNCTION fixture_panne_stade()")
   own('SAVEPOINT panne_stade')
   try:rpc('consommer_buvette');raise AssertionError('panne absente')
   except psycopg2.Error as e:assert 'panne_stade'in str(e);own('ROLLBACK TO SAVEPOINT panne_stade')
   assert photo()==p and caisses()==cash
   assert own('SELECT count(*)FROM recettes_municipales')==0 and own("SELECT (data->>'reserveJour')::numeric FROM budgets_nationaux WHERE id='republic'")is None
  case('buvette_panne_recu_annule_debit_taxes_caisse_et_gain',stadepanne)
  def orga(fn='orga_meeting',ident=1,org='o',params=None,cur=None):
   cc=cur or q
   cc.execute("SELECT set_config('role','authenticated',true),set_config('request.path','/rpc/organisation_vie_commande',true),set_config('request.jwt.claim.sub','00000000-0000-4000-9000-000000000001',true)")
   cc.execute('SELECT organisation_vie_commande(%s,%s,%s,%s)',('orgcmd-fixture-'+str(ident),org,'ordre_jauges',Json(params if params is not None else {'fn':fn})));return cc.fetchone()[0]
  def preparerorga(type='politique'):
   own("UPDATE personnages_donnees SET arg=10000,liquide=10000 WHERE name='Fixture'")
   own("INSERT INTO organisations(id,country_origine,data)VALUES('o','republic',%s)",(json.dumps({'type':type,'nom':'Orga Fixture','chef':'Fixture','membres':[{'nom':'Fixture'}]}),))
  regles=[('orga_petition','politique',2,0,None,0,0),('orga_meeting','politique',3,500,5,3,0),('orga_benediction','religieuse',2,200,5,0,10),('orga_pelerinage','religieuse',3,1000,8,0,0),('orga_cooptation','loge',2,1000,0,5,0),('orga_rituel','loge',2,500,0,6,0),('orga_reseau','loge',2,300,0,8,0),('orga_campagne_presse','mediatique',2,500,6,5,0),('orga_scoop','mediatique',2,0,0,10,0)]
  for fn,type,pa,cout,pop,inf,moral in regles:
   def scenario(fn=fn,type=type,pa=pa,cout=cout,pop=pop,inf=inf,moral=moral):
    preparerorga(type);v=orga(fn);assert v['ok'],v
    assert v['pa']==20-pa and v['arg']==10000-cout and v['inf']==10+inf and v['moral']==60+moral,v
    assert v['pop']==10+pop if pop is not None else 13<=v['pop']<=20,v
    assert orga(fn)['pop']==v['pop'] and own('SELECT count(*)FROM organisation_commandes_recus')==1
   case('organisation_'+fn+'_paiement_effets_et_rejeu',scenario)
  def orgrefus():
   preparerorga();p=photo()
   own("UPDATE organisations SET data='{\"type\":\"politique\",\"chef\":\"AutreFixture\",\"membres\":[]}'")
   assert orga()['raison']=='membre_requis'and photo()==p
   own("UPDATE organisations SET data='{\"type\":\"religieuse\",\"chef\":\"Fixture\"}'")
   assert orga()['raison']=='type_invalide'and photo()==p
   own("UPDATE organisations SET data='{\"type\":\"politique\",\"chef\":\"Fixture\",\"dissoute\":true}'")
   assert orga()['raison']=='organisation_dissoute'and photo()==p
  case('organisation_autorite_fraiche_avant_tout_debit',orgrefus)
  def orglie():
   preparerorga();assert orga()['ok'];p=photo()
   own("INSERT INTO organisations(id,country_origine,data)SELECT 'autre',country_origine,data FROM organisations WHERE id='o'")
   assert orga(org='autre')['raison']=='requete_reutilisee'and photo()==p
   assert orga(params={'fn':'orga_meeting','gain_inf':99})['raison']=='requete_reutilisee'and photo()==p
  case('organisation_recu_lie_a_org_et_parametres',orglie)
  def orgdeux():
   preparerorga();a=orga();b=orga(ident=2)
   assert a['inf']==13 and b['inf']==16 and b['pa']==14 and b['arg']==9000
  case('organisation_deux_gains_legitimes_deux_requetes',orgdeux)
  def orgfonds():
   preparerorga();own("UPDATE personnages_donnees SET arg=0,liquide=0 WHERE name='Fixture'");p=photo()
   assert orga()['raison']=='fonds_insuffisants'and photo()==p
   assert own('SELECT count(*)FROM organisation_commandes_recus')==0
  case('organisation_fonds_insuffisants_aucune_mutation',orgfonds)
  def orgretard():
   preparerorga();v=orga();assert v['inf']==13
   own("UPDATE personnages_donnees SET pa=7,resources=jsonb_set(resources,'{inf}','40')WHERE name='Fixture'")
   v=orga();assert v['rejeu']and v['inf']==40 and v['pa']==7 and v['paiement']['pa']==7
  case('organisation_rejeu_retourne_fiche_courante_pas_snapshot_ancien',orgretard)
  def orgpanne():
   preparerorga();p=photo()
   own("CREATE FUNCTION fixture_panne_org()RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_org';END$$;CREATE TRIGGER fixture_panne_org BEFORE INSERT ON organisation_commandes_recus FOR EACH ROW EXECUTE FUNCTION fixture_panne_org()")
   own('SAVEPOINT panne_org')
   try:orga();raise AssertionError('panne absente')
   except psycopg2.Error as e:assert 'panne_org'in str(e);own('ROLLBACK TO SAVEPOINT panne_org')
   assert photo()==p
  case('organisation_panne_recu_annule_paiement_et_jauges',orgpanne)
  def orggarde():
   own("CREATE OR REPLACE FUNCTION organisation_vie_commande(p_requete text,p_organisation text,p_action text,p_parametres jsonb)RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$")
   own('SAVEPOINT garde_org')
   try:own(orgmigration);raise AssertionError('garde absente')
   except psycopg2.Error as e:assert 'organisation_vie_definition_a_reexaminer'in str(e);own('ROLLBACK TO SAVEPOINT garde_org')
  case('organisation_corps_inconnu_refuse_pas_ecrase',orggarde)
  c.commit()
  def agir():
   cc=psycopg2.connect(srv.get_uri())
   try:
    v=rpc('observer_debats',777,cur=cc.cursor());cc.commit();return v
   finally:cc.close()
  with ThreadPoolExecutor(2)as pool:a,b=list(pool.map(lambda _:agir(),range(2)))
  assert a['inf']==b['inf']==11 and own("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==19
  cas.append({'cas':'deux_connexions_un_gain_un_paiement','ok':True})
  own("UPDATE personnages_donnees SET archetype='ambitieux',poste='{\"id\":\"president\"}'WHERE name='Fixture'");c.commit()
  def objectifconcurrent(i):
   cc=psycopg2.connect(srv.get_uri())
   try:
    v=rpc('objectifs_actualiser',880+i,cur=cc.cursor());cc.commit();return v
   finally:cc.close()
  with ThreadPoolExecutor(2)as pool:a,b=list(pool.map(objectifconcurrent,range(2)))
  assert sorted([a['gain_inf'],b['gain_inf']])==[0,2] and a['inf']==b['inf']==13
  cas.append({'cas':'objectifs_deux_connexions_requetes_distinctes_un_seul_lot','ok':True})
  preparerorga();avant=photo();c.commit()
  def orgconcurrent(_):
   cc=psycopg2.connect(srv.get_uri())
   try:
    v=orga(ident=999,cur=cc.cursor());cc.commit();return v
   finally:cc.close()
  with ThreadPoolExecutor(2)as pool:a,b=list(pool.map(orgconcurrent,range(2)))
  assert a['inf']==b['inf']==avant['resources']['inf']+3 and photo()['pa']==avant['pa']-3 and photo()['arg']==avant['arg']-500
  cas.append({'cas':'organisation_deux_connexions_un_recu_un_paiement','ok':True})
  print(json.dumps({'production':False,'contre_rejeu_organisation':'--contre-rejeu-organisation'in sys.argv,'moteur':version,'tests':cas,'limites':['Payer_ordre et inspection réels du baseline ; pas un clone du catalogue vivant ni son interception blocus ajoutée ensuite.','Concurrence committée seulement dans le cluster détruit.']},ensure_ascii=False,indent=2));return 0 if all(t['ok']for t in cas)else 1
 finally:
  if c:c.rollback();c.close()
  srv.cleanup()
if __name__=='__main__':sys.exit(main())
