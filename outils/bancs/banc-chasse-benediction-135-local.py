#!/usr/bin/env python3
"""Chasse : mêmes recherches/exécution/détention, caisse et bonus transactionnels.
Aucun compte réel ; définition personnelle absente non simulée ni reconstruite.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import importlib.util,re,json,uuid,sys
R=Path(__file__).resolve().parents[2]
MUTANT=next((x.split('=',1)[1] for x in sys.argv if x.startswith('--mutant=')),None)
sys.argv[:]=[x for x in sys.argv if not x.startswith('--mutant=')]
spec=importlib.util.spec_from_file_location('enquete',R/'outils/bancs/banc-enquete-benediction-135-local.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
MIGRATIONS=['migrations/20261025005521_execution_condamnation_continuite.sql','migrations/20261025005717_chasse_commande_transactionnelle.sql']
def suite(db,q,srv):
 import psycopg2
 from psycopg2.extras import Json
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK chasse hote',msg,flush=True)
 def lire(sql,args=(),cur=q):cur.execute(sql,args or None);return cur.fetchone()[0]
 def fn(path,nom):
  s=(R/path).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
 s=(R/'baseline/domaines/justice/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public.jugements \(.*?\n\);',s,re.S)[0]);q.execute('ALTER TABLE jugements ADD PRIMARY KEY(id)')
 for nom in ['justice_recherches','justice_executer_condamnation']:q.execute(fn('baseline/domaines/justice/20_fonctions-2.sql',nom))
 def fermer():lire("SELECT detention_clore_interne('Autre','fixture_fin')")
 def position():q.execute("SET hg.acteur='Fixture';SET hg.serveur='off';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='commissariat',current_room='bureau_commissaire',hp=100,pa=50,stats='{\"PER\":13}',stats_affaiblies='{}',inf=0,hospitalisation=NULL,poste='{\"id\":\"commissaire\",\"city\":\"capitale\"}' WHERE name='Fixture';UPDATE personnages_donnees SET stats='{\"PER\":8}',inf=0 WHERE name='Autre';UPDATE indices_villes SET data=data||'{\"isn\":45}' WHERE id='republic_capitale';UPDATE caisses_batiments SET data='{\"solde\":10000}' WHERE id='republic_commissariat_capitale'")
 def jet(v):q.execute(f'CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT {v}$$')
 def bonus():
  q.execute("UPDATE personnages_donnees SET current_building='tabernacle-impots',current_room='nef_principale' WHERE name='Fixture'");jet(1)
  r=lire('SELECT religion_benediction_demander(%s,%s)',('Père Ception',str(uuid.uuid4())));assert r['ok'] and r['succes'],r
  q.execute("UPDATE personnages_donnees SET current_building='commissariat',current_room='bureau_commissaire' WHERE name='Fixture'")
 def jugement(id,data=None,cible='Autre',pays='republic'):
  data=data or {'motifs':[{'type':'Peine fixture','jours':3}]}
  q.execute("INSERT INTO jugements(id,country,city,accuse,motif,jour,data) VALUES(%s,%s,'ville_a',%s,'Motif fixture',1,%s)",(id,pays,cible,Json(data)))
 reliquat={'motifs':[{'type':'Peine initiale','jours':20,'source':'jugement'},{'type':'Évasion','jours':2,'source':'evasion'}],'reliquat_jours':5,'detention_precedente_id':'det-ancienne-fixture','jour_affaire':3}
 fermer();position();jugement('preuve-reliquat-original',reliquat)
 r=lire("SELECT justice_executer_condamnation('preuve-reliquat-original','capitale')")
 check(r['ok'] and r['jours']==22,'defaut historique reproduit peine entiere au lieu du reliquat')
 fermer()
 for migration in MIGRATIONS:q.execute((R/migration).read_text());q.execute((R/migration).read_text())
 if MUTANT:
  nom,avant,apres={
   'reliquat_ignore':('justice_executer_condamnation(text,text)',"IF v_j.data->>'reliquat_jours' IS NOT NULL THEN",'IF false THEN'),
   'cible_reutilisee':('police_chasse_commande(text,uuid)','IF ancien.cible IS DISTINCT FROM v_cible THEN','IF false THEN'),
   'bonus_reutilise':('police_chasse_commande(text,uuid)',"bonus:=public.religion_benediction_consommer_interne(p.id,'organiser_chasse_homme',p_requete)",'bonus:=5')
  }[MUTANT]
  d=lire('SELECT pg_get_functiondef(%s::regprocedure)',('public.'+nom,));assert d.count(avant)==1;q.execute(d.replace(avant,apres))
 def appel(k,cible='Autre',cur=q):return lire('SELECT police_chasse_commande(%s,%s)',(cible,f'd0000000-0000-4000-8000-{k:012d}'),cur)
 def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(c ORDER BY id) FROM caisses_batiments c),(SELECT jsonb_agg(m ORDER BY id) FROM caisses_mouvements_clients m),(SELECT jsonb_agg(j ORDER BY id) FROM jugements j),(SELECT jsonb_agg(d ORDER BY id) FROM detentions d),(SELECT jsonb_agg(r ORDER BY acteur,requete) FROM police_chasses_recus r),(SELECT jsonb_agg(b ORDER BY acteur) FROM religion_benedictions b),(SELECT jsonb_agg(c ORDER BY acteur,acte) FROM religion_benedictions_consommations c),(SELECT count(*) FROM courrier_fixture),(SELECT jsonb_agg(e ORDER BY id) FROM evenements_globaux e),(SELECT count(*) FROM acquisitions_transactions_internes))")
 position();avant=photo();check(appel(99)['raison']=='cible_non_recherchee' and photo()==avant,'aucune condamnation executable aucun cout ni bonus')
 jugement('normal-cible');bonus();jet(60);r=appel(1)
 check(r['ok'] and r['succes'] and r['taux']==60 and r['bonus']==5,'formule existante et bonus au seuil exact de chasse')
 check(r['pa']==46 and r['solde_caisse']==9700,'cout un PA attribution puis trois PA et 300 FR institutionnels')
 check(r['execution']['jours']==3 and lire("SELECT executee FROM jugements WHERE id='normal-cible'"),'condamnation vraiment executee par le moteur commun')
 check(lire('SELECT city FROM detentions WHERE id=%s',(r['execution']['detention_id'],))=='capitale','incarceration dans ville du commissaire et non du jugement')
 check(lire('SELECT count(*) FROM evenements_globaux WHERE id=%s',(r['evenementPublic'],))==1,'annonce publique seulement apres arrestation confirmee')
 avant=photo();check(appel(1)['rejeu'] and photo()==avant,'reponse perdue aucun second debit peine ou evenement')
 check(appel(1,'Autre cible')['raison']=='requete_reutilisee' and photo()==avant,'nonce ne change pas de cible')
 jugement('reliquat-cible',reliquat);avant=photo();check(appel(2)['raison']=='cible_deja_detenue' and photo()==avant,'deja detenu refuse avant paiement et jet')
 fermer();position();bonus();jet(100);r=appel(2)
 check(r['ok'] and not r['succes'] and r['execution'] is None and not lire("SELECT executee FROM jugements WHERE id='reliquat-cible'"),'echec du jet paye sans arrestation ni execution fictives')
 position();bonus();jet(1);q.execute("CREATE FUNCTION panne_chasse_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_chasse_fixture';END$$;CREATE TRIGGER panne_chasse_fixture BEFORE INSERT ON police_chasses_recus FOR EACH ROW EXECUTE FUNCTION panne_chasse_fixture()")
 avant=photo()
 try:appel(3);raise AssertionError('panne attendue')
 except psycopg2.Error as ex:check('panne_chasse_fixture' in str(ex) and photo()==avant,'panne finale annule PA caisse bonus detention jugement courrier et evenement')
 q.execute('DROP TRIGGER panne_chasse_fixture ON police_chasses_recus')
 def concurrent(_):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute("SET hg.acteur='Fixture';SET hg.serveur='off'");return appel(3,cur=cur)
 with ThreadPoolExecutor(max_workers=2) as pool:rr=list(pool.map(concurrent,[0,1]))
 check(all(r['ok'] for r in rr) and sum(bool(r.get('rejeu')) for r in rr)==1,'deux chasses simultanees meme requete une seule peine')
 r=next(r for r in rr if not r.get('rejeu'))
 check(r['execution']['jours']==7,'reliquat cinq plus sanction evasion deux sans reprendre vingt jours')
 d=lire('SELECT to_jsonb(d) FROM detentions d WHERE id=%s',(r['execution']['detention_id'],))
 check(d['jour_fin']-d['jour_debut']==7 and d['ville_condamnation']=='ville_a' and d['city']=='capitale' and d['detention_precedente_id']=='det-ancienne-fixture' and d['reliquat_jours']==5,'duree effective et liens historiques conserves dans le registre')
 check(d['motifs']==reliquat['motifs'],'motifs historiques restent intacts au lieu de les remplacer par le reliquat')
 # Toute écriture écartée doit annuler l'ensemble, pas seulement afficher un refus.
 fermer();jugement('controle-ecritures');position();bonus();jet(1)
 q.execute("CREATE FUNCTION ignorer_chasse_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RETURN NULL;END$$")
 for table,evenement,condition,preuve in [
  ('personnages_donnees','UPDATE',"NEW.name='Fixture' AND NEW.pa<OLD.pa",'paiement_chasse_non_confirme'),
  ('caisses_batiments','UPDATE',"NEW.id='republic_commissariat_capitale'",'caisse_chasse_non_confirmee'),
  ('jugements','UPDATE','NEW.executee IS TRUE','execution_condamnation_non_confirmee'),
  ('personnages_donnees','UPDATE',"NEW.name='Autre' AND NEW.est_emprisonne IS NOT NULL",'execution_condamnation_non_confirmee'),
  ('evenements_globaux','INSERT','true','evenement_chasse_non_confirme')]:
  q.execute(f'CREATE TRIGGER ignorer_chasse_fixture BEFORE {evenement} ON {table} FOR EACH ROW WHEN ({condition}) EXECUTE FUNCTION ignorer_chasse_fixture()');avant=photo()
  try:appel(40);raise AssertionError('ecriture ignoree acceptee')
  except psycopg2.Error as ex:check(preuve in str(ex) and photo()==avant,'ecriture ignoree rollback complet '+preuve)
  q.execute(f'DROP TRIGGER ignorer_chasse_fixture ON {table}')
 jet('NULL::integer');avant=photo()
 try:appel(41);raise AssertionError('jet NULL accepte')
 except psycopg2.Error as ex:check('jet_invalide' in str(ex) and photo()==avant,'jet absent annule paiement et consommation du bonus')
 jet(100);r=appel(42);check(r['ok'] and not r['succes'] and r['bonus']==5,'bonus intact apres tous les rollbacks')
 position();jet(100);r=appel(43);check(r['ok'] and r['bonus']==0,'bonus consomme une seule fois entre deux ordres distincts')
 for mutation,raison in [
  ("UPDATE personnages_donnees SET current_room='accueil' WHERE name='Fixture'",'pas_sur_place'),
  ("UPDATE personnages_donnees SET current_city='ville_a' WHERE name='Fixture'",'commissaire_hors_juridiction'),
  ("UPDATE personnages_donnees SET hp=0 WHERE name='Fixture'",'acteur_indisponible'),
  ("UPDATE caisses_batiments SET data='{\"solde\":299}' WHERE id='republic_commissariat_capitale'",'caisse_insuffisante')]:
  position();q.execute(mutation);avant=photo();r=appel(44);check(r.get('raison')==raison and photo()==avant,'refus sans mutation '+raison)
 # Reliquat invalide : refus métier du moteur commun, payé puis entièrement annulé.
 position();jet(1)
 for v in [-1,1.5]:
  q.execute("UPDATE jugements SET data=jsonb_set(data,'{reliquat_jours}',%s) WHERE id='controle-ecritures'",(Json(v),));avant=photo();r=appel(45)
  check(r.get('raison')=='reliquat_invalide' and photo()==avant,'reliquat invalide refuse sans cout '+str(v))
 q.execute("UPDATE jugements SET executee=true WHERE id='controle-ecritures'")
 # Le moteur personnel absent du dépôt n'est ni inventé ni simulé.
 jugement('personnel-cible',cible='Fixture');position();avant=photo()
 check(appel(4,'Fixture')['raison']=='moteur_execution_personnelle_indisponible' and photo()==avant,'dependance personnelle absente refuse sans cout ni simulation')
 fermer();jugement('autre-empire',pays='soviet');position();avant=photo()
 check(appel(5)['raison']=='cible_non_recherchee' and photo()==avant,'pas d extradition sur condamnation d un autre empire')
 check(lire("SELECT has_function_privilege('authenticated','police_chasse_commande(text,uuid)','EXECUTE')") is False,'hote prive sans activation prematuree')
 print(json.dumps({'chasse_serveur':True,'assertions':n,'execution_personnelle_non_verifiee':True,'client_raccorde':False,'production':False}))
def tout(db,q,srv):base.tout(db,q,srv);suite(db,q,srv)
if __name__=='__main__':base.base.base.banque.m.main(tout)
