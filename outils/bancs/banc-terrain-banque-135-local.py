#!/usr/bin/env python3
"""Contrats releves par MCP, PostgreSQL natif jetable, identites fictives seulement."""
from pathlib import Path
import importlib.util,json,re
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('nego',R/'outils/bancs/banc-negociation-squatteurs-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def suite(db,q,srv):
 import psycopg2
 from psycopg2.extras import Json
 n=0;catalogue={f['signature']:f for f in json.loads((R/'outils/bancs/fixtures/prevol-135-fonctions.json').read_text())}
 def check(v,t):
  nonlocal n
  assert v,t;n+=1;print('OK terrain banque',t,flush=True)
 def fn(path,nom):
  s=(R/path).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');x=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+x.end()]
 def table(dom,nom):
  s=(R/f'baseline/domaines/{dom}/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',s,re.S)[0])
 q.execute("CREATE ROLE service_role;CREATE SCHEMA auth;CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT id FROM personnages_donnees WHERE name=mon_personnage()$$;ALTER TABLE personnages_donnees ADD COLUMN hospitalisation jsonb,ADD COLUMN day integer DEFAULT 1;CREATE VIEW personnages AS SELECT * FROM personnages_donnees")
 for dom,nom in [('banque','prets'),('finances-publiques','fonds_credits_uniques'),('personnage-et-presence','mariages'),('immobilier-et-territoire','terrains_historique_ventes'),('banque','compromis_historique'),('immobilier-et-territoire','dossiers_urbanisme'),('personnage-et-presence','objets_recus'),('justice','detentions')]:table(dom,nom)
 q.execute("CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$SELECT current_setting('hg.serveur',true)='on'$$;CREATE TABLE courrier_fixture(expediteur text,destinataire text,sujet text,corps text);CREATE FUNCTION mail_systeme_poser_interne(text,text,text,text,text DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$INSERT INTO courrier_fixture VALUES($1,$2,$3,$4);SELECT '{\"ok\":true}'::jsonb$$")
 q.execute('ALTER TABLE prets ADD PRIMARY KEY(id);ALTER TABLE objets_recus ADD PRIMARY KEY(id);ALTER TABLE dossiers_urbanisme ADD PRIMARY KEY(id);ALTER TABLE terrains_historique_ventes ADD PRIMARY KEY(id);ALTER TABLE compromis_historique ADD PRIMARY KEY(id);CREATE UNIQUE INDEX credit_unique_fixture ON fonds_credits_uniques(acteur,source,reference);CREATE TABLE entreprises(id text PRIMARY KEY,data jsonb);CREATE TABLE rp_epoques(pays text,jour_un date);INSERT INTO rp_epoques VALUES(\'republic\',current_date-20)')
 for path,nom in [('baseline/domaines/socle/20_fonctions.sql','jour_de_jeu_pays'),('baseline/domaines/socle/20_fonctions.sql','objet_sas_deposer'),('baseline/domaines/banque/20_fonctions.sql','taux_pret_nationale'),('baseline/domaines/banque/20_fonctions.sql','helvetia_crediter_destination'),('baseline/domaines/justice/20_fonctions-1.sql','detention_active'),('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','terrain_etat_verrouiller_interne')]:q.execute(fn(path,nom))
 for nom in ['pret_national_contracter(numeric,integer,text,text)','payer_ordre(text,text,integer,integer)','terrain_compromis_acte(text,text,jsonb)','terrain_proprietaire_muter(text,text,jsonb,text)','compromis_expire_resoudre(text,text)']:q.execute(catalogue[nom]['definition'])
 q.execute("CREATE FUNCTION titulaire_est_moi(text) RETURNS boolean LANGUAGE sql AS $$SELECT $1 IN(mon_personnage(),'pj:'||mon_personnage())$$;INSERT INTO ordres_couts VALUES('deposer_demande_permis',1,100),('emprunter',1,0)")
 q.execute(fn('outils/bancs/banc-fixture-terrain-permis-acte-avant-depot.sql','terrain_permis_acte'))
 q.execute((R/'migrations/20261022220516_permis_depot_transactionnel.sql').read_text())
 q.execute(catalogue['payer_ordre(text,text,integer,integer)']['definition'])
 q.execute((R/'migrations/20261024072349_occupation_actions_et_echeances.sql').read_text())
 if '--apres-location' in __import__('sys').argv:q.execute((R/'migrations/20261023090017_location_lot_legacy_avant_paiement.sql').read_text())
 for f in ['20261024121400_prets_nationaux_moteur_credit_commun.sql','20261024121900_prets_nationaux_commandes_versionnees.sql','20261024122600_acquisitions_capacites_et_gardes.sql','20261024123500_compromis_financement_reel.sql','20261024123600_terrains_referentiel_acquisition.sql','20261024123700_terrain_acquisition_commandes.sql','20261024123800_terrain_banque_relecture_recus.sql','20261024124000_prets_nationaux_echeances_atomiques.sql','20261024124100_prets_versionnes_fermer_ecritures_directes.sql','20261024131720_acquisitions_depots_attestes.sql','20261024132140_financement_compromis_termes_attestes.sql','20261024133310_terrain_vente_archive_reference_acte.sql','20261024134528_permis_instruction_transactionnelle_acquisitions.sql','20261024135353_acquisition_refus_rollback_financement.sql','20261024140140_permis_instruction_compatibilite_archives.sql']:
  sql=(R/'migrations'/f).read_text();q.execute(sql);q.execute(sql)
 # Mutations de contre-épreuve : seulement après installation, dans la base jetable.
 mutant=next((x.split('=',1)[1] for x in __import__('sys').argv if x.startswith('--mutant=')),None)
 if mutant:
  if mutant=='dette_legacy':q.execute('ALTER TABLE prets DISABLE TRIGGER pret_versionne_ecriture')
  else:
   nom,avant,apres={
    'prix_public':('terrain_acquisition_commande(text,text,jsonb,uuid)',"e->>'acquisitionVersion'='2'",'false'),
    'credit_fictif':('pret_national_creer_interne(text,numeric,integer,text,text,text,numeric)','solde=solde+p_montant','solde=solde'),
    'rejeu_banque':('pret_national_contracter_versionne(numeric,integer,text,text,uuid)','IF FOUND THEN','IF false THEN'),
    'echeance_arrondi':('pret_national_jour_traiter(text)','du:=least(p.mensualite,p.montant_restant);','du:=p.mensualite;'),
    'permis_jour_rejoue':('terrain_permis_instruction_jour(text)',"IF p->>'jourInstruction'=jour THEN",'IF false THEN'),
    'archive_collision':('terrain_proprietaire_muter(text,text,jsonb,text)',"|| '-' || v_nouveau || '-' || coalesce(nullif(p_reference,''),'historique'),","|| '-' || v_nouveau,")
   }[mutant]
   q.execute('SELECT pg_get_functiondef(%s::regprocedure)',('public.'+nom,));d=q.fetchone()[0];assert d.count(avant)==1;q.execute(d.replace(avant,apres))
 def lire(s,args=(),cur=q):cur.execute(s,args);return cur.fetchone()[0]
 def reset():
  q.execute("SET hg.acteur='Fixture';UPDATE personnages_donnees SET pa=50,hp=100,country='republic',current_city='capitale',current_building='terrain-a-batir-1',arg=200000,liquide=100000,stats_affaiblies='{}',excommunie=NULL;UPDATE comptes_bancaires SET solde=100000;UPDATE terrains_etat SET data='{\"city\":\"capitale\",\"pnj\":null,\"dateGeneration\":1,\"surface\":2150,\"valeur_totale\":25800}',proprietaire=NULL")
 def cmd(k,action,params=None,cur=q):return lire("SELECT terrain_acquisition_commande('terrain-a-batir-1',%s,%s,%s)",(action,Json(params or {'occupation':'1:'}),f'20000000-0000-4000-8000-{k:012d}'),cur)
 def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(c ORDER BY id) FROM comptes_bancaires c),(SELECT jsonb_agg(t ORDER BY id) FROM terrains_etat t),(SELECT jsonb_agg(p ORDER BY id) FROM prets p),(SELECT count(*) FROM fonds_credits_uniques),(SELECT count(*) FROM terrain_acquisitions_recus),(SELECT count(*) FROM terrains_historique_ventes),(SELECT count(*) FROM courrier_fixture),(SELECT count(*) FROM dossiers_urbanisme),(SELECT count(*) FROM objets_recus))")
 reset();r=cmd(1,'depot');check(r['ok'] and r['montant']==1000,'depot reel 1000 FR')
 check(lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==48,'2 PA du depot')
 check(lire("SELECT count(*) FROM courrier_fixture WHERE sujet='Rendez-vous fixé — achat de terrain'")==1,'courrier de rendez vous serveur conserve')
 avant=photo();check(cmd(1,'depot')['rejeu'] and photo()==avant,'reponse perdue depot sans nouveau debit')
 check(cmd(1,'compromis')['raison']=='requete_reutilisee' and photo()==avant,'UUID parametres differents refuse')
 q.execute("UPDATE terrains_etat SET data=jsonb_set(jsonb_set(data::jsonb,'{achatDirect,dateAchat}',to_jsonb(floor(extract(epoch FROM now())*1000)-1000)),'{achatDirect,dateLimite}',to_jsonb(floor(extract(epoch FROM now())*1000)+86400000))::text;UPDATE personnages_donnees SET current_building='office-notarial' WHERE name='Fixture'")
 q.execute("UPDATE terrains_etat SET data=jsonb_set(jsonb_set(data::jsonb,'{achatDirect,prix}','1000'),'{achatDirect,acompte}','1000')::text")
 r=cmd(2,'acte_direct');check(r['ok'] and r['montant']==24800 and r['etat']['proprietaire']=='Fixture','prix officiel moins le depot exactement une fois')
 check(lire("SELECT liquide FROM personnages_donnees WHERE name='Fixture'")==74200,'cout total 25800, jamais 26800')
 avant=photo();check(cmd(2,'acte_direct')['rejeu'] and photo()==avant,'rejeu du titre ne paye ni archive une seconde fois')
 reset();q.execute("UPDATE personnages_donnees SET liquide=0,arg=0 WHERE name='Fixture';UPDATE comptes_bancaires SET solde=0 WHERE personnage='Fixture'");avant=photo();check(cmd(3,'depot')['raison']=='fonds_insuffisants' and photo()==avant,'fonds insuffisants aucun PA ni reservation')
 reset();q.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{pnj}','\"cadavre\"')::text");avant=photo();check(cmd(4,'depot')['raison']=='terrain_occupe' and photo()==avant,'cadavre aucune depense')
 reset()
 def deux(nom):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute('SET hg.acteur=%s',(nom,));return cmd(5,'depot',cur=cur)
 with ThreadPoolExecutor(max_workers=2) as pool:rr=list(pool.map(deux,['Fixture','Autre']))
 check(sum(bool(r['ok']) for r in rr)==1,'deux acheteurs une seule reservation')
 reset();cmd(6,'depot');q.execute("UPDATE terrains_etat SET data=jsonb_set(jsonb_set(data::jsonb,'{achatDirect,dateAchat}',to_jsonb(floor(extract(epoch FROM now())*1000)-1000)),'{achatDirect,dateLimite}',to_jsonb(floor(extract(epoch FROM now())*1000)+86400000))::text;UPDATE personnages_donnees SET current_building='office-notarial' WHERE name='Fixture'")
 q.execute("CREATE FUNCTION panne_titre() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_titre';END$$;CREATE TRIGGER panne BEFORE INSERT ON terrains_historique_ventes FOR EACH ROW EXECUTE FUNCTION panne_titre()")
 avant=photo()
 try:cmd(7,'acte_direct');raise AssertionError('panne attendue')
 except psycopg2.Error as ex:check('panne_titre' in str(ex),'panne apres debit injectee')
 check(photo()==avant,'rollback fonds PA titre historique recu');q.execute('DROP TRIGGER panne ON terrains_historique_ventes')
 reset();r=cmd(8,'compromis',{'occupation':'1:','pret':{'montant':25000,'duree':30}});check(r['ok'],'compromis financement immobilier distinct des travaux')
 q.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{compromisExpireAt}',to_jsonb(floor(extract(epoch FROM now())*1000)-1000))::text;UPDATE personnages_donnees SET current_building='office-notarial' WHERE name='Fixture'")
 q.execute("UPDATE terrains_etat SET data=jsonb_set(jsonb_set(data::jsonb,'{pretDemande,montant}','150000'),'{pretDemande,duree}','1')::text")
 r=cmd(9,'acte_compromis');check(r['ok'],'credit reel puis acquisition dans la meme commande')
 check(lire('SELECT count(*) FROM terrains_historique_ventes')==2,'deux ventes legitimes meme jour archives distinctes')
 check(lire("SELECT count(*) FROM prets WHERE type_pret='immobilier'")==1,'dette immobiliere conservee')
 check(lire("SELECT solde FROM comptes_bancaires WHERE personnage='Fixture'")==125000,'compte national reellement credite')
 avant=photo();check(cmd(9,'acte_compromis')['rejeu'] and photo()==avant,'rejeu aucun second pret ni versement')
 # Pret consommation : le contrat releve est reutilise, taux fixe historique.
 q.execute("UPDATE personnages_donnees SET current_building='banque-nationale' WHERE name='Fixture'")
 r=lire("SELECT pret_national_contracter_versionne(1000,5,'consommation','banque-nationale','30000000-0000-4000-8000-000000000001')")
 check(r['ok'],'consommation disponible au guichet');check(lire("SELECT montant_restant FROM prets WHERE id=%s",(r['pret_id'],))==1120,'taux consommation 12 pour cent')
 avant=photo();check(lire("SELECT pret_national_contracter_versionne(1000,5,'consommation','banque-nationale','30000000-0000-4000-8000-000000000001')")['rejeu'] and photo()==avant,'credit consommation idempotent')
 # Un second acteur permet de verifier le financement sans purger les contrats precedents.
 reset();q.execute("SET hg.acteur='Autre'");r=cmd(10,'compromis',{'occupation':'1:','pret':{'montant':25000,'duree':30}});check(r['ok'],'second dossier independant')
 q.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{compromisExpireAt}',to_jsonb(floor(extract(epoch FROM now())*1000)-1000))::text;UPDATE personnages_donnees SET current_building='office-notarial' WHERE name='Autre'")
 q.execute('CREATE TRIGGER panne BEFORE INSERT ON terrains_historique_ventes FOR EACH ROW EXECUTE FUNCTION panne_titre()');avant=photo()
 try:cmd(11,'acte_compromis');raise AssertionError('panne attendue')
 except psycopg2.Error as ex:check('panne_titre' in str(ex),'panne apres credit avant titre')
 check(photo()==avant,'credit dette paiement titre et recu annules ensemble');q.execute('DROP TRIGGER panne ON terrains_historique_ventes')
 reset();q.execute("SET hg.acteur='Autre';DELETE FROM comptes_bancaires WHERE personnage='Autre'");check(cmd(12,'compromis',{'occupation':'1:','pret':{'montant':25000,'duree':30}})['ok'],'depot sans compte peut demander un financement')
 q.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{compromisExpireAt}',to_jsonb(floor(extract(epoch FROM now())*1000)-1000))::text")
 r=lire("SELECT compromis_expire_resoudre('terrain','republic_terrain-a-batir-1')");check(r['action']=='rembourse','financement refuse faute de compte')
 check(lire("SELECT liquide FROM personnages_donnees WHERE name='Autre'")==100000,'acompte rembourse reellement sans perte de fonds')
 avant=photo();check(lire("SELECT compromis_expire_resoudre('terrain','republic_terrain-a-batir-1')")['action']=='non_applicable' and photo()==avant,'refus et remboursement non rejouables')
 # Compromis ordinaire expiré : aucun paiement final ni titre.
 reset();check(cmd(14,'compromis')['ok'],'compromis ordinaire');q.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{compromisExpireAt}',to_jsonb(floor(extract(epoch FROM now())*1000)-1000))::text;UPDATE personnages_donnees SET current_building='office-notarial' WHERE name='Fixture'");avant=photo()
 check(cmd(15,'acte_compromis')['raison']=='compromis_expire' and photo()==avant,'compromis expire sans mutation finale')
 q.execute("UPDATE personnages_donnees SET current_building='banque-nationale' WHERE name='Fixture'");avant=photo()
 check(lire("SELECT pret_national_contracter_versionne(2000,5,'consommation','banque-nationale','30000000-0000-4000-8000-000000000001')")['raison']=='requete_reutilisee' and photo()==avant,'UUID bancaire avec montant different refuse')
 check(not lire("SELECT has_function_privilege('authenticated','pret_national_jour_traiter(text)','EXECUTE')"),'echeance reservee au serveur')
 check(not lire("SELECT has_table_privilege('authenticated','terrain_acquisitions_recus','SELECT')"),'recus prives sans lecture croisee')
 # Refus métier après crédit : doit annuler aussi la décision financière, pas seulement le titre.
 q.execute("INSERT INTO comptes_bancaires(id,personnage,banque,solde) VALUES('compte-Autre-retabli','Autre','nationale',100000)")
 reset();q.execute("SET hg.acteur='Autre'");check(cmd(18,'compromis',{'occupation':'1:','pret':{'montant':25000,'duree':30}})['ok'],'compromis avant refus PA a la signature finale')
 q.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{compromisExpireAt}',to_jsonb(floor(extract(epoch FROM now())*1000)-1000))::text;UPDATE personnages_donnees SET pa=0,current_building='office-notarial' WHERE name='Autre'");avant=photo()
 r=cmd(19,'acte_compromis');check(not r['ok'] and r['raison']=='pa_insuffisants' and photo()==avant,'refus PA apres accord annule credit dette et decision')
 q.execute("UPDATE personnages_donnees SET pa=50 WHERE name='Autre'");check(cmd(19,'acte_compromis')['ok'],'meme intention refusee puis PA disponibles un seul financement')
 # Permis joint : meme archive et SAS que le depot individuel, aucune double facturation.
 reset();check(cmd(13,'compromis',{'occupation':'1:','permis':'hangar'})['ok'],'permis joint par le moteur existant')
 check(lire('SELECT count(*) FROM dossiers_urbanisme')==1 and lire('SELECT count(*) FROM objets_recus')==1,'archive et document de permis concordants')
 check(lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==48 and lire("SELECT liquide FROM personnages_donnees WHERE name='Fixture'")==99000,'clause incluse dans les 2 PA et 1000 FR historiques')
 q.execute("SET hg.serveur='off'");avant=photo()
 check(lire("SELECT terrain_permis_instruction_jour('republic_terrain-a-batir-1')")['raison']=='serveur_requis' and photo()==avant,'instruction interdite au navigateur sans mutation')
 # Instruction du permis joint sur l'etat courant : aucun blob de cron ne peut effacer le titre.
 q.execute("SET hg.serveur='on';UPDATE terrains_etat SET data=jsonb_set(jsonb_set(data::jsonb,'{permis,dureeInstruction}','2'),'{permis,joursInstructionFaits}','0')::text")
 check(lire("SELECT terrain_permis_instruction_jour('republic_terrain-a-batir-1')")['instruits']==1,'instruction jour commun sans sommeil')
 avant=photo();check(lire("SELECT terrain_permis_instruction_jour('republic_terrain-a-batir-1')").get('rejeu') and photo()==avant,'rejeu instruction aucun second jour')
 q.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{permis,jourInstruction}',to_jsonb(((now() AT TIME ZONE 'Europe/Paris')::date-1)::text))::text")
 q.execute("CREATE TRIGGER panne_tacite BEFORE INSERT ON objets_recus FOR EACH ROW EXECUTE FUNCTION panne_titre()");avant=photo()
 try:lire("SELECT terrain_permis_instruction_jour('republic_terrain-a-batir-1')");raise AssertionError('panne attendue')
 except psycopg2.Error:check(photo()==avant,'panne document tacite annule archive compteur et autorisation')
 q.execute("DROP TRIGGER panne_tacite ON objets_recus;UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{temoinAutreCommande}','\"courant\"')::text")
 check(lire("SELECT terrain_permis_instruction_jour('republic_terrain-a-batir-1')")['accords_tacites']==1,'accord tacite archive SAS et etat dans une transaction')
 check(lire("SELECT data::jsonb->>'temoinAutreCommande' FROM terrains_etat")=='courant','instruction preserve les changements apres le releve cron')
 check(lire("SELECT count(*) FROM dossiers_urbanisme WHERE type_evenement='accord_tacite'")==1 and lire('SELECT count(*) FROM objets_recus')==2,'attestation tacite persistante unique')
 avant=photo();check(lire("SELECT terrain_permis_instruction_jour('republic_terrain-a-batir-1')")['ignore'] and photo()==avant,'accord tacite non reemis')
 # Même compatibilité que le constructeur de document historique : inconnus restent inconnus.
 q.execute("UPDATE terrains_etat SET data=(data::jsonb||'{\"acquisitionVersion\":0,\"city\":null,\"permis\":{\"statut\":\"instruction\",\"numeroDossier\":null,\"dateDepot\":1,\"demandeur\":null,\"dureeInstruction\":1,\"joursInstructionFaits\":0,\"decoupageInitial\":null}}'::jsonb)::text")
 check(lire("SELECT terrain_permis_instruction_jour('republic_terrain-a-batir-1')")['accords_tacites']==1,'ancien permis sans numero conserve sans numero invente')
 check(lire("SELECT count(*) FROM dossiers_urbanisme WHERE type_evenement='accord_tacite' AND numero_dossier IS NULL")==1 and lire('SELECT count(*) FROM objets_recus')==2,'archive historique inconnue sans faux destinataire ni objet')
 # Echeances : date Paris serveur, reliquat exact, sommeil sans nouveau quota, concurrence.
 q.execute("SET hg.serveur='on'");pretid=r=None
 q.execute("SELECT id FROM prets WHERE type_pret='consommation'");pretid=q.fetchone()[0]
 q.execute("INSERT INTO prets_ecritures_internes VALUES(txid_current());UPDATE prets SET jour_dernier_prelevement=((now() AT TIME ZONE 'Europe/Paris')::date-1)::text WHERE id=%s;DELETE FROM prets_ecritures_internes WHERE transaction_id=txid_current()",(pretid,))
 def echeance(_):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute("SET hg.serveur='on'");return lire('SELECT pret_national_jour_traiter(%s)',(pretid,),cur)
 with ThreadPoolExecutor(max_workers=2) as pool:rr=list(pool.map(echeance,[0,1]))
 check(sum(bool(x.get('rejeu')) for x in rr)==1 and sum(x.get('montant',0) for x in rr)==224,'jour Paris suivant sans sommeil et concurrence une seule echeance')
 paye=224
 for jour in range(4):
  q.execute("INSERT INTO prets_ecritures_internes VALUES(txid_current()) ON CONFLICT DO NOTHING;UPDATE prets SET jour_dernier_prelevement=NULL WHERE id=%s;DELETE FROM prets_ecritures_internes WHERE transaction_id=txid_current()",(pretid,))
  rr=lire('SELECT pret_national_jour_traiter(%s)',(pretid,));paye+=rr.get('montant',0)
  avant=photo();q.execute("UPDATE personnages_donnees SET day=day+1 WHERE name='Fixture'");avant=photo();check(lire('SELECT pret_national_jour_traiter(%s)',(pretid,))['rejeu'] and photo()==avant,'dormir ne donne aucune seconde echeance '+str(jour))
 check(paye==1120 and lire('SELECT montant_restant FROM prets WHERE id=%s',(pretid,))==0,'capital plus interets soldes exactement')
 try:q.execute("UPDATE prets SET montant_restant=0 WHERE type_pret='immobilier'");raise AssertionError('garde attendue')
 except psycopg2.Error as ex:check('pret_commande_versionnee_requise' in str(ex),'ancienne sauvegarde ne reecrit pas une dette versionnee')
 q.execute("UPDATE personnages_donnees SET pa=0,current_building='banque-nationale' WHERE name='Fixture';SET hg.acteur='Fixture'");avant=photo()
 r=lire("SELECT pret_national_contracter_versionne(1001,10,'travaux','banque-nationale','30000000-0000-4000-8000-000000000002')")
 check(not r['ok'] and r['raison']=='pa_insuffisants' and photo()==avant,'PA refuses apres creation interne rollback credit dette et recu')
 q.execute("UPDATE personnages_donnees SET pa=50 WHERE name='Fixture'")
 r=lire("SELECT pret_national_contracter_versionne(1001,10,'travaux','banque-nationale','30000000-0000-4000-8000-000000000002')")
 check(r['ok'],'pret travaux preserve et UUID refuse non consomme')
 q.execute("INSERT INTO prets_ecritures_internes VALUES(txid_current());UPDATE prets SET jour_dernier_prelevement=((now() AT TIME ZONE 'Europe/Paris')::date-1)::text WHERE id=%s;DELETE FROM prets_ecritures_internes WHERE transaction_id=txid_current()",(r['pret_id'],))
 q.execute("CREATE FUNCTION panne_echeance() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_echeance';END$$;CREATE TRIGGER panne_echeance BEFORE UPDATE ON prets FOR EACH ROW EXECUTE FUNCTION panne_echeance()");avant=photo()
 try:lire('SELECT pret_national_jour_traiter(%s)',(r['pret_id'],));raise AssertionError('panne attendue')
 except psycopg2.Error as ex:check('panne_echeance' in str(ex) and photo()==avant,'panne apres debit echeance rollback argent dette et marqueur')
 q.execute('DROP TRIGGER panne_echeance ON prets')
 total=lire('SELECT montant_restant FROM prets WHERE id=%s',(r['pret_id'],));mensualite=lire('SELECT mensualite FROM prets WHERE id=%s',(r['pret_id'],));versements=[]
 for j in range(10):
  q.execute("INSERT INTO prets_ecritures_internes VALUES(txid_current());UPDATE prets SET jour_dernier_prelevement=((now() AT TIME ZONE 'Europe/Paris')::date-1)::text WHERE id=%s;DELETE FROM prets_ecritures_internes WHERE transaction_id=txid_current()",(r['pret_id'],))
  versements.append(lire('SELECT pret_national_jour_traiter(%s)',(r['pret_id'],))['montant'])
 check(sum(versements)==total and versements[-1]<mensualite and lire('SELECT montant_restant FROM prets WHERE id=%s',(r['pret_id'],))==0,'reliquat non divisible solde exactement sans surprelevement')

 print(json.dumps({'terrain_banque':True,'assertions':n,'production':False}))
if __name__=='__main__':m.main(suite)
