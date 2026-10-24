#!/usr/bin/env python3
"""Filature hôte du bonus : vrais moteurs financiers et de lecture, PostgreSQL jetable."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import importlib.util,re,json,subprocess,uuid,sys
R=Path(__file__).resolve().parents[2]
MUTANT=next((x.split('=',1)[1] for x in sys.argv if x.startswith('--mutant=')),None)
sys.argv[:]=[x for x in sys.argv if not x.startswith('--mutant=')]
spec=importlib.util.spec_from_file_location('benediction',R/'outils/bancs/banc-benediction-135-local.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
MIGRATIONS=['migrations/20261024182403_ordres_jets_sites_referentiel.sql','migrations/20261024182404_filature_historique_temps_commun.sql','migrations/20261024183157_filature_commande_transactionnelle.sql']
def suite(db,q,srv):
 import psycopg2
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK filature',msg,flush=True)
 def lire(sql,args=(),cur=q):cur.execute(sql,args);return cur.fetchone()[0]
 def fn(path,nom):
  s=(R/path).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
 def table(dom,nom):
  s=(R/f'baseline/domaines/{dom}/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',s,re.S)[0])
 q.execute('ALTER TABLE personnages_donnees ADD COLUMN poste jsonb,ADD COLUMN user_id uuid,ADD COLUMN inf integer DEFAULT 0;ALTER TABLE pnj_membres ADD COLUMN car_per integer,ADD COLUMN car_dup integer;UPDATE personnages_donnees SET user_id=id')
 for dom,nom in [('immobilier-et-territoire','villes'),('postes-et-institutions','postes_attribues'),('finances-publiques','caisses_batiments'),('finances-publiques','caisses_autorites'),('finances-publiques','caisses_mouvements_clients'),('personnage-et-presence','historique_deplacements')]:table(dom,nom)
 q.execute('ALTER TABLE caisses_batiments ADD PRIMARY KEY(id)')
 q.execute((R/'baseline/seeds/90_socle/caisses_autorites.sql').read_text())
 for path,nom in [('baseline/domaines/socle/20_fonctions.sql','acteur_poste_courant'),('baseline/domaines/socle/20_fonctions.sql','exiger_poste'),('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','ville_est_reelle'),('baseline/domaines/finances-publiques/20_fonctions-1.sql','caisse_postes_requis'),('baseline/domaines/finances-publiques/20_fonctions-1.sql','caisse_territoire'),('baseline/domaines/finances-publiques/20_fonctions-1.sql','caisse_refus_autorite'),('baseline/domaines/finances-publiques/20_fonctions-1.sql','caisse_institution_mouvement'),('baseline/domaines/finances-publiques/20_fonctions-1.sql','caisse_client_mouvement'),('baseline/domaines/renseignement/20_fonctions.sql','filature_deplacements')]:q.execute(fn(path,nom))
 for path in MIGRATIONS:
  sql=(R/path).read_text();q.execute(sql);q.execute(sql)
 mutant=MUTANT
 if mutant:
  definition=lire("SELECT pg_get_functiondef('police_filature_commande(text,uuid)'::regprocedure)")
  remplacements={
   'rejeu':('IF FOUND THEN\n  IF ancien.cible','IF FOUND AND false THEN\n  IF ancien.cible'),
   'caisse':("site.caisse,-site.cout,'organiser_filature'","site.caisse,-site.cout/2,'organiser_filature'"),
   'badge':("IF NOT EXISTS(SELECT 1 FROM public.postes_attribues a WHERE a.country=p.country AND a.poste_id='commissaire' AND a.city=p.current_city AND a.titulaire IN(moi,'pj:'||moi)) THEN","IF false THEN")}
  avant,apres=remplacements[mutant];assert avant in definition; q.execute(definition.replace(avant,apres))
 attendus=json.loads(subprocess.check_output(['node',str(R/'outils/generateurs/generer_ordres_jet_sites.cjs')],text=True))
 q.execute('SELECT pays,ville,batiment,piece,ordre,pa,cout,poste,caisse FROM ordres_jets_sites');check(set(q.fetchall())=={tuple(x[k] for k in ['pays','ville','batiment','piece','ordre','pa','cout','poste','caisse']) for x in attendus},'sites couts postes et caisses identiques au jeu')
 q.execute("INSERT INTO villes VALUES('republic','capitale','Luthécia',true,1),('republic','ville_a','Port-Sainte-Marie',false,2),('republic','ville_b','Montrouge',false,3);INSERT INTO caisses_batiments VALUES('republic_commissariat_capitale','{\"solde\":1000}',now());INSERT INTO postes_attribues(id,country,poste_id,city,titulaire,source) VALUES('fixture-commissaire','republic','commissaire','capitale','pj:Fixture','fixture')")
 def position():q.execute("SET hg.acteur='Fixture';SET hg.serveur='off';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='commissariat',current_room='bureau_commissaire',pa=31,hp=100,stats='{\"PER\":13}',inf=0,stats_affaiblies='{}',excommunie=NULL,poste='{\"id\":\"commissaire\",\"city\":\"capitale\"}' WHERE name='Fixture'")
 def jet(j):q.execute(f'CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT {j}$$')
 def appel(k,cible='Autre',cur=q):return lire('SELECT police_filature_commande(%s,%s)',(cible,f'a0000000-0000-4000-8000-{k:012d}'),cur)
 identite=lire("SELECT id FROM personnages_donnees WHERE name='Fixture'")
 def bonus():
  q.execute("SELECT current_city,current_building,current_room FROM personnages_donnees WHERE name='Fixture'");lieu=q.fetchone()
  q.execute("UPDATE personnages_donnees SET current_city='capitale',current_building='tabernacle-impots',current_room='nef_principale' WHERE name='Fixture'");jet(1)
  r=lire('SELECT religion_benediction_demander(%s,%s)',('Père Ception',str(uuid.uuid4())));assert r['ok'] and r['succes'],r
  q.execute("UPDATE personnages_donnees SET current_city=%s,current_building=%s,current_room=%s WHERE name='Fixture'",lieu)

 def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(c ORDER BY id) FROM caisses_batiments c),(SELECT jsonb_agg(m ORDER BY id) FROM caisses_mouvements_clients m),(SELECT jsonb_agg(b ORDER BY acteur) FROM religion_benedictions b),(SELECT jsonb_agg(c ORDER BY acteur,acte) FROM religion_benedictions_consommations c),(SELECT jsonb_agg(r ORDER BY acteur,requete) FROM police_filatures_recus r),(SELECT count(*) FROM acquisitions_transactions_internes))")
 position();q.execute("UPDATE personnages_donnees SET stats='{\"PER\":8}',inf=0 WHERE name='Autre';UPDATE indices_villes SET data=data||'{\"isn\":30}' WHERE id='republic_capitale';UPDATE personnages_donnees SET day=99999 WHERE name='Fixture'")
 q.execute("INSERT INTO historique_deplacements(name,country,city,building_id,room_id,jour,heure,created_at) VALUES('Autre','republic','capitale','recent','salle',1,'12h',now()-interval '1 hour'),('Autre','republic','capitale','ancien','salle',99999,'13h',now()-interval '25 hours'),('Autre','republic','capitale','futur','salle',99999,'14h',now()+interval '1 hour'),('Autre','republic','capitale','inconnu','salle',99999,'10h',NULL)")
 bonus();jet(56);r=appel(1)
 check(r['ok'] and r['succes'] and r['taux']==56 and r['bonus']==5,'formule conservee groupe PER indice INF et cinq points')
 check(len(r['deplacements'])==1 and r['deplacements'][0]['building_id']=='recent','rapport 24h reelles aucun jour personnel ni trace future')
 check(r['horodatagesInconnus']==1,'horodatage ancien inconnu signale sans date inventee')
 check(lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==28 and lire("SELECT data->>'solde' FROM caisses_batiments WHERE id='republic_commissariat_capitale'")=='850','deux PA personnels et 150 FR institutionnels')
 check(lire('SELECT count(*) FROM caisses_mouvements_clients WHERE delta=-150')==1,'mouvement financier commun journalise une fois')
 avant=photo();check(appel(1)['rejeu'] and photo()==avant,'reponse perdue meme resultat aucun second cout ou bonus')
 check(appel(1,'Fausse cible')['raison']=='requete_reutilisee' and photo()==avant,'nonce cible changee refuse')
 q.execute("UPDATE caisses_batiments SET data='{\"solde\":777}'");r=appel(1);check(r['solde_caisse']==777 and r['deplacements'][0]['building_id']=='recent','rejeu recopie caisse actuelle et rapport historique confirme')
 # Refus avant dépense, dont faux badge sans titre réel.
 q.execute("DELETE FROM postes_attribues");avant=photo();check(appel(2)['raison']=='commissaire_hors_juridiction' and photo()==avant,'badge de presentation ne donne aucun pouvoir')
 q.execute("INSERT INTO postes_attribues(id,country,poste_id,city,titulaire,source) VALUES('fixture-commissaire','republic','commissaire','capitale','Fixture','fixture')")
 for col,valeur in [('current_city','ville_a'),('current_room','accueil'),('current_building','rue-centrale'),('country','soviet')]:
  position();q.execute('UPDATE personnages_donnees SET '+col+'=%s WHERE name=\'Fixture\'',(valeur,));avant=photo();check(not appel(2)['ok'] and photo()==avant,'presence et juridiction '+col)
 position();bonus();q.execute("UPDATE personnages_donnees SET pa=1 WHERE name='Fixture'");avant=photo();check(appel(2)['raison']=='pa_insuffisants' and photo()==avant,'PA insuffisants sans caisse ni bonus depense')
 position();q.execute("UPDATE caisses_batiments SET data='{\"solde\":100}'");avant=photo();check(not appel(2)['ok'] and photo()==avant,'caisse insuffisante annule aussi les PA et le bonus')
 q.execute("UPDATE caisses_batiments SET data='{\"solde\":1000}'");jet(100);r=appel(2);check(r['ok'] and not r['succes'] and r['deplacements'] is None,'jet echoue confirme sans faux rapport ni remboursement invente')
 check(lire('SELECT consommee_at IS NOT NULL FROM religion_benedictions WHERE acteur=%s',(identite,)),'echec de jet consomme le bonus exactement une fois')
 # Une erreur technique après consommation doit tout annuler.
 position();bonus();jet(1);q.execute("CREATE FUNCTION panne_filature() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_filature';END$$;CREATE TRIGGER panne_filature BEFORE INSERT ON police_filatures_recus FOR EACH ROW EXECUTE FUNCTION panne_filature()");avant=photo()
 try:appel(3);raise AssertionError('panne attendue')
 except psycopg2.Error as ex:check('panne_filature' in str(ex) and photo()==avant,'panne apres rapport annule PA caisse consommation et recu')
 q.execute('DROP TRIGGER panne_filature ON police_filatures_recus')
 # Concurrence : mêmes paramètres, une seule opération.
 def concur(_):
  with psycopg2.connect(srv.get_uri()) as cc:
   qq=cc.cursor();qq.execute("SET hg.acteur='Fixture';SET hg.serveur='off'");return appel(3,cur=qq)
 pa=lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'");solde=lire("SELECT (data->>'solde')::numeric FROM caisses_batiments WHERE id='republic_commissariat_capitale'")
 with ThreadPoolExecutor(max_workers=2) as pool:rr=list(pool.map(concur,[0,1]))
 check(all(r['ok'] for r in rr) and sum(bool(r.get('rejeu')) for r in rr)==1,'double clic une seule resolution de filature')
 check(lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==pa-2 and lire("SELECT (data->>'solde')::numeric FROM caisses_batiments WHERE id='republic_commissariat_capitale'")==solde-150,'concurrence aucune double facture')
 # Les réalités de la cible et du groupe changent la probabilité, sans données navigateur.
 position();bonus();q.execute("UPDATE personnages_donnees SET stats='{\"PER\":16}',inf=20 WHERE name='Autre'");jet(42);r=appel(4)
 check(r['ok'] and r['succes'] and r['taux']==42,'caracteristiques et influence reelles de la cible relues')
 q.execute("INSERT INTO pnj_membres(id,nom,pays,proprietaire_pj,leader_pj,statut,car_per) VALUES('filature-employe','Fixture employe','republic','Fixture','Fixture','actif',16),('filature-sans-per','Fixture sans PER','republic','Fixture','Fixture','actif',NULL);INSERT INTO pnj_employes_metier(pnj_id) VALUES('filature-employe'),('filature-sans-per')")
 check(lire("SELECT personnage_stat_jet_interne('Fixture','PER')")==15,'moyenne de groupe sans transformer une caracteristique absente en zero')
 q.execute("UPDATE personnages_donnees SET hp=50,stats_affaiblies='{\"PER\":true}' WHERE name='Fixture'")
 check(lire("SELECT personnage_stat_jet_interne('Fixture','PER')")==7,'affaiblissement apres moyenne et arrondi commun')
 q.execute("DELETE FROM pnj_employes_metier WHERE pnj_id LIKE 'filature-%';DELETE FROM pnj_membres WHERE id LIKE 'filature-%'")
 position();bonus();q.execute("UPDATE personnages_donnees SET day=NULL WHERE name='Fixture';UPDATE religion_benedictions SET accordee_at=now()-interval '25 hours',expire_at=now()-interval '1 second' WHERE acteur=%s",(identite,));jet(37);r=appel(5)
 check(r['ok'] and r['succes'] and r['taux']==37 and r['bonus']==0,'expiration refuse le bonus sans bloquer un jet legitime')
 check(lire('SELECT consommee_at IS NULL FROM religion_benedictions WHERE acteur=%s',(identite,)),'bonus expire non marque consomme a tort')
 check(len(r['deplacements'])==1,'lecture des dernieres 24h independante du jour personnel absent')
 position();bonus();jet('NULL::integer');avant=photo()
 try:appel(6);raise AssertionError('jet invalide attendu')
 except psycopg2.Error as ex:check('jet_invalide' in str(ex) and photo()==avant,'jet invalide annule argent PA bonus et recu')
 # Le lecteur commun peut aussi échouer après le paiement : rien ne doit rester engagé.
 jet(1);original=fn('baseline/domaines/renseignement/20_fonctions.sql','filature_deplacements')
 q.execute("CREATE OR REPLACE FUNCTION filature_deplacements(p_cible text) RETURNS jsonb LANGUAGE sql AS $$SELECT '{\"ok\":false}'::jsonb$$")
 avant=photo()
 try:appel(6);raise AssertionError('rapport invalide attendu')
 except psycopg2.Error as ex:check('rapport_filature_non_confirme' in str(ex) and photo()==avant,'refus lecteur commun annule la transaction complete')
 q.execute(original);q.execute((R/MIGRATIONS[1]).read_text())
 check(lire("SELECT has_function_privilege('authenticated','police_filature_commande(text,uuid)','EXECUTE')") is False,'prototype non expose avant activation L09')
 print(json.dumps({'filature_serveur':True,'client_raccorde':False,'assertions':n,'production':False}))
def tout(db,q,srv):base.tout(db,q,srv);suite(db,q,srv)
if __name__=='__main__':base.banque.m.main(tout)
