#!/usr/bin/env python3
"""Socle L09 privé natif, non raccordé aux actes : aucun compte ou service distant."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import importlib.util,json,re,subprocess,uuid
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('banque',R/'outils/bancs/banc-terrain-banque-135-local.py');banque=importlib.util.module_from_spec(spec);spec.loader.exec_module(banque)
MIGRATION='migrations/20261024174646_benediction_etat_prive_et_attribution.sql'
def suite(db,q,srv):
 import psycopg2
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK benediction',msg,flush=True)
 def lire(sql,args=(),cur=q):cur.execute(sql,args);return cur.fetchone()[0]
 def fn(path,nom):
  s=(R/path).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
 q.execute('ALTER TABLE personnages_donnees ADD COLUMN current_room text;ALTER TABLE pnj_membres ADD COLUMN nom text,ADD COLUMN pays text,ADD COLUMN ville text,ADD COLUMN building_id text,ADD COLUMN room_id text,ADD COLUMN rue_noeud_id text,ADD COLUMN leader_pnj_id text')
 for nom in ['pnj_position_effective','pnj_co_present']:q.execute(fn('baseline/domaines/socle-PNJ/20_fonctions.sql',nom))
 for _ in range(2):q.execute((R/MIGRATION).read_text())
 attendus=json.loads(subprocess.check_output(['node',str(R/'outils/generateurs/generer_contacts_religieux.cjs')],text=True))
 q.execute('SELECT pays,ville,batiment,piece,nom,fonction FROM religion_contacts_referentiel');reels=set(q.fetchall())
 check(reels=={tuple(x[k] for k in ['pays','ville','batiment','piece','nom','fonction']) for x in attendus},'contacts conformes a data.js')
 def jet(v):q.execute(f'CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT {v}$$')
 def position():q.execute("SET hg.acteur='Fixture';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='tabernacle-impots',current_room='nef_principale',hp=100,pa=30,excommunie=NULL WHERE name='Fixture'")
 def demande(k,nom='Père Ception',cur=q):return lire('SELECT religion_benediction_demander(%s,%s)',(nom,f'90000000-0000-4000-8000-{k:012d}'),cur)
 def etat():return lire('SELECT religion_benediction_lire()')['benediction']
 def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(b ORDER BY acteur) FROM religion_benedictions b),(SELECT jsonb_agg(r ORDER BY acteur,requete) FROM religion_benedictions_recus r),(SELECT count(*) FROM acquisitions_transactions_internes),(SELECT jsonb_agg(c ORDER BY acteur,acte) FROM religion_benedictions_consommations c))")
 position();identite=lire("SELECT id FROM personnages_donnees WHERE name='Fixture'");jet(80)
 sans_bonus=str(uuid.uuid4());check(lire('SELECT religion_benediction_consommer_interne(%s,%s,%s)',(identite,'enquete',sans_bonus))==0,'tentative sans bonus historisee')
 r=demande(1,'Père Ception (PNJ)');check(r['ok'] and r['succes'] and r['jet']==80 and r['benediction']['actif'],'attribution serveur a la borne de 80 pour cent')
 avant=photo()
 try:lire('SELECT religion_benediction_consommer_interne(%s,%s,%s)',(identite,'enquete',sans_bonus));raise AssertionError('rejeu refuse attendu')
 except psycopg2.Error as ex:check('acte_benediction_deja_traite' in str(ex) and photo()==avant,'ancienne tentative sans bonus ne prend pas un bonus ulterieur')
 check(lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==29,'un PA par demande aucun argent')
 courant=etat();q.execute("UPDATE personnages_donnees SET day=day+100 WHERE name='Fixture'");check(etat()==courant,'dormir ne change ni le bonus actif ni son expiration')
 with psycopg2.connect(srv.get_uri()) as autre_connexion:
  qq=autre_connexion.cursor();qq.execute("SET hg.acteur='Fixture'");check(lire('SELECT religion_benediction_lire()',cur=qq)['benediction']==courant,'nouvelle connexion retrouve le bonus actif')
 q.execute("SET hg.acteur='Autre'");check(not etat()['actif'],'un autre personnage ne voit pas le bonus');q.execute("SET hg.acteur='Fixture'")
 check(lire('SELECT extract(epoch FROM expire_at-accordee_at) FROM religion_benedictions WHERE acteur=%s',(identite,))==86400,'vingt quatre heures exactes pas un jour personnel')
 avant=photo();check(demande(1)['rejeu'] and photo()==avant,'reponse perdue meme recu sans nouveau PA ni bonus')
 check(demande(1,'Enfant de chœur Lacroix')['raison']=='requete_reutilisee' and photo()==avant,'nonce avec autre referent refuse')
 for col,value in [('country','narco'),('current_city','ville_a'),('current_building','rue-centrale'),('current_room','absent')]:
  position();q.execute('UPDATE personnages_donnees SET '+col+'=%s WHERE name=\'Fixture\'',(value,));avant=photo();check(not demande(2)['ok'] and photo()==avant,'presence territoriale '+col)
 position();avant=photo();check(demande(2,'Faux Prêtre')['raison']=='religieux_non_habilite_sur_place' and photo()==avant,'faux religieux refuse avant cout')
 q.execute("UPDATE personnages_donnees SET excommunie='{}' WHERE name='Fixture'");avant=photo();check(demande(2)['raison']=='excommunication' and photo()==avant,'excommunication sans cout')
 position();q.execute("UPDATE personnages_donnees SET hp=0 WHERE name='Fixture'");avant=photo();check(demande(2)['raison']=='acteur_indisponible' and photo()==avant,'inconscience sans cout')
 position();q.execute("UPDATE personnages_donnees SET pa=0 WHERE name='Fixture'");avant=photo();check(demande(2)['raison']=='pa_insuffisants' and photo()==avant,'PA insuffisants sans mutation')
 position();q.execute("INSERT INTO pnj_membres(id,nom,pays,ville,building_id,room_id,statut) VALUES('fixture-clerc','Père Ception','republic','capitale','tabernacle-impots','sacristie','actif')");avant=photo();check(demande(2)['raison']=='religieux_absent' and photo()==avant,'position reelle du socle PNJ prioritaire')
 q.execute("UPDATE pnj_membres SET room_id='nef_principale' WHERE id='fixture-clerc'");check(demande(2)['succes'],'religieux effectivement co present')
 check(lire('SELECT count(*) FROM religion_benedictions WHERE acteur=%s',(identite,))==1,'une seule benediction active pas de cumul')
 avant=etat();jet(81);check(not demande(3)['succes'] and etat()==avant,'echec au dessus de 80 preserve le bonus deja acquis')
 def consommer(_):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();return lire('SELECT religion_benediction_consommer_interne(%s,%s,%s)',(identite,'enquete',str(uuid.uuid4())),cur)
 with ThreadPoolExecutor(max_workers=2) as pool:valeurs=list(pool.map(consommer,[0,1]))
 check(sorted(valeurs)==[0,5],'deux sessions ne depensent pas deux fois le bonus')
 check(not etat()['actif'],'etat recharge apres consommation')
 q.execute("UPDATE personnages_donnees SET stats=stats||'{\"benediction\":{\"actif\":true}}',day=day+100 WHERE name='Fixture'");check(not etat()['actif'],'ancienne sauvegarde et sommeil ne restaurent rien')
 avant=photo();r=demande(2);check(r['rejeu'] and not r['benediction']['actif'] and photo()==avant,'rejeu attribution deja consommee ne reactive rien')
 jet(1);check(demande(4)['succes'],'nouvelle demande legitime nouveau bonus')
 acte=str(uuid.uuid4());check(lire('SELECT religion_benediction_consommer_interne(%s,%s,%s)',(identite,'enquete',acte))==5,'acte identifie consomme cinq points')
 check(demande(7)['succes'],'nouvelle generation apres consommation')
 avant=photo()
 try:lire('SELECT religion_benediction_consommer_interne(%s,%s,%s)',(identite,'enquete',acte));raise AssertionError('rejeu refuse attendu')
 except psycopg2.Error as ex:check('acte_benediction_deja_traite' in str(ex) and photo()==avant,'rejeu ancien acte ne consomme jamais une nouvelle generation')
 avant=photo()
 try:q.execute('DO $$BEGIN PERFORM religion_benediction_consommer_interne(\''+str(identite)+'\',\'enquete\',gen_random_uuid());RAISE EXCEPTION \'panne_acte\';END$$');raise AssertionError('panne attendue')
 except psycopg2.Error as ex:check('panne_acte' in str(ex) and etat()['actif'] and photo()==avant,'consommation privee annulee si acte serveur echoue')
 q.execute('UPDATE religion_benedictions SET expire_at=clock_timestamp()-interval \'1 second\',accordee_at=clock_timestamp()-interval \'25 hours\' WHERE acteur=%s',(identite,))
 check(not etat()['actif'] and consommer(0)==0,'expiration serveur aucun bonus')
 q.execute('CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION \'panne_jet\';END$$');avant=photo()
 try:demande(5);raise AssertionError('panne attendue')
 except psycopg2.Error as ex:check('panne_jet' in str(ex) and photo()==avant,'panne apres PA annule paiement benediction et recu')
 jet(1);q.execute("CREATE FUNCTION panne_recu_benediction() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_recu';END$$;CREATE TRIGGER panne_recu BEFORE INSERT ON religion_benedictions_recus FOR EACH ROW EXECUTE FUNCTION panne_recu_benediction()");avant=photo()
 try:demande(5);raise AssertionError('panne attendue')
 except psycopg2.Error as ex:check('panne_recu' in str(ex) and photo()==avant,'panne apres attribution annule aussi les PA')
 q.execute('DROP TRIGGER panne_recu ON religion_benedictions_recus')
 def concurrent(_):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute("SET hg.acteur='Fixture'");return demande(6,cur=cur)
 pa=lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")
 with ThreadPoolExecutor(max_workers=2) as pool:reponses=list(pool.map(concurrent,[0,1]))
 check(all(r['ok'] for r in reponses) and sum(bool(r.get('rejeu')) for r in reponses)==1 and lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==pa-1,'double requete un seul cout et une seule attribution')
 q.execute("SELECT has_function_privilege('authenticated','religion_benediction_consommer_interne(uuid,text,uuid)','EXECUTE'),has_function_privilege('authenticated','religion_benediction_demander(text,uuid)','EXECUTE'),has_table_privilege('authenticated','religion_benedictions','SELECT,INSERT,UPDATE,DELETE')");check(q.fetchone()==(False,False,False),'etat et consommation prives inaccessibles aux clients')
 q.execute("UPDATE personnages_donnees SET id=gen_random_uuid() WHERE name='Fixture'");check(not etat()['actif'],'homonyme nouveau personnage ne reprend pas un ancien bonus')
 q.execute("UPDATE personnages_donnees SET id=%s WHERE name='Fixture'",(identite,))
 for index,contact in enumerate(c for c in attendus if c['fonction']=='pretre'):
  q.execute("UPDATE personnages_donnees SET current_city=%s,current_building=%s,current_room=%s WHERE name='Fixture'",(contact['ville'],contact['batiment'],contact['piece']))
  check(demande(8+index,contact['nom'])['succes'],'contact religieux valide '+contact['ville'])
 q.execute("SET TIME ZONE 'Europe/Paris'");check(lire("SELECT extract(epoch FROM (t+interval '24 hours')-t) FROM (SELECT '2026-10-24 20:00+02'::timestamptz t) a")==86400,'expiration inchangee au passage heure hiver')
 print(json.dumps({'benediction_socle_prive':True,'raccordement_actes':False,'assertions':n,'production':False}))
def tout(db,q,srv):banque.suite(db,q,srv);suite(db,q,srv)
if __name__=='__main__':banque.m.main(tout)
