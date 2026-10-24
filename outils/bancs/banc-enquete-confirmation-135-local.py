#!/usr/bin/env python3
"""Instruction et détention PJ réelles. Adaptateur contre-espionnage simulé, explicitement hors preuve."""
from pathlib import Path
import importlib.util,re,json,sys
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('banque',R/'outils/bancs/banc-terrain-banque-135-local.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
MIGRATION='migrations/20261024185228_enquete_confirmation_detention_transactionnelle.sql'
def suite(db,q,srv):
 import psycopg2
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK enquete confirmation',msg,flush=True)
 def lire(sql,args=()):q.execute(sql,args);return q.fetchone()[0]
 def fn(path,nom):
  s=(R/path).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
 q.execute('ALTER TABLE personnages_donnees ADD COLUMN est_emprisonne jsonb')
 s=(R/'baseline/domaines/justice/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public.actions_tracables \(.*?\n\);',s,re.S)[0]);q.execute('ALTER TABLE actions_tracables ADD PRIMARY KEY(id)')
 q.execute("CREATE FUNCTION contre_espionnage_resoudre(text,text,text,text) RETURNS jsonb LANGUAGE sql AS $$SELECT '{\"ok\":false,\"raison\":\"fixture_pas_agent\"}'::jsonb$$")
 q.execute(fn('baseline/domaines/justice/20_fonctions-1.sql','detention_ouvrir_interne'))
 original=fn('baseline/domaines/justice/20_fonctions-2.sql','plainte_instruire_interne');q.execute(original)
 def acte():q.execute("DELETE FROM actions_tracables;INSERT INTO actions_tracables(id,auteur,type_action,country,city,jour,jour_expiration) VALUES('fixture-trace','Autre','vol','republic','capitale',1,20)")
 def appel():return lire("SELECT plainte_instruire_interne('republic','capitale','Autre','enquete','Fixture')")
 def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(a) FROM actions_tracables a),(SELECT jsonb_agg(d ORDER BY id) FROM detentions d),(SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p))")
 # Reproduction de la fausse réussite historique : cible déjà détenue, aucune nouvelle détention.
 q.execute("UPDATE personnages_donnees SET est_emprisonne='{\"detentionId\":\"historique\"}' WHERE name='Autre'");acte();r=appel()
 check(r['ok'] and r['decision']=='enquete_ouverte' and not r['detention']['ok'],'ancien moteur annonce le succes malgre detention refusee')
 check(lire("SELECT decouvert FROM actions_tracables WHERE id='fixture-trace'"),'ancien moteur perd la trace non instruite')
 sql=(R/MIGRATION).read_text();q.execute(sql);q.execute(sql)
 acte();avant=photo()
 try:appel();raise AssertionError('refus attendu')
 except psycopg2.Error as ex:check('instruction_detention_non_confirmee' in str(ex) and photo()==avant,'refus detention annule aussi le demasquage')
 q.execute("UPDATE personnages_donnees SET est_emprisonne=NULL WHERE name='Autre'");r=appel()
 check(r['ok'] and r['decision']=='enquete_ouverte' and r['detention']['ok'],'moteur detention existant conserve le succes legitime')
 identifiant=r['detention']['detention_id'];check(lire("SELECT est_emprisonne->>'detentionId' FROM personnages_donnees WHERE name='Autre'")==identifiant,'registre et personnage concordent')
 check(lire('SELECT count(*) FROM detentions WHERE id=%s AND nom=%s',(identifiant,'Autre'))==1,'une detention reelle aucun doublon')
 check(appel()['decision']=='classee' and lire('SELECT count(*) FROM detentions WHERE id=%s',(identifiant,))==1,'trace deja instruite ne redemande aucune detention')
 # Simule un trigger historique qui rendrait silencieusement la projection antérieure.
 q.execute("UPDATE personnages_donnees SET est_emprisonne=NULL WHERE name='Autre';CREATE FUNCTION perte_projection_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN NEW.est_emprisonne:=OLD.est_emprisonne;RETURN NEW;END$$;CREATE TRIGGER perte_projection_fixture BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION perte_projection_fixture()")
 acte();avant=photo()
 try:appel();raise AssertionError('projection manquante attendue')
 except psycopg2.Error as ex:check('instruction_detention_non_confirmee' in str(ex) and photo()==avant,'ecriture silencieusement ignoree annule registre trace et projection')
 q.execute('DROP TRIGGER perte_projection_fixture ON personnages_donnees')
 # Deux instructions concurrentes de la même trace : une seule ouverture réelle.
 q.execute("UPDATE detentions SET date_fin_effective=now() WHERE nom='Autre' AND date_fin_effective IS NULL;UPDATE personnages_donnees SET est_emprisonne=NULL WHERE name='Autre'");acte()
 def instruction(_):
  with psycopg2.connect(srv.get_uri()) as connexion:
   cur=connexion.cursor();cur.execute("SELECT plainte_instruire_interne('republic','capitale','Autre','enquete','Fixture')");return cur.fetchone()[0]
 with ThreadPoolExecutor(max_workers=2) as pool:resultats=list(pool.map(instruction,[0,1]))
 check(sorted(r['decision'] for r in resultats)==['classee','enquete_ouverte'],'concurrence une trace instruite une seule fois')
 check(lire("SELECT count(*) FROM detentions WHERE nom='Autre' AND date_fin_effective IS NULL")==1,'concurrence une detention active et projection conservee')
 # Mutation de la garde de postcondition : le test doit reproduire le défaut, pas le masquer.
 definition=lire("SELECT pg_get_functiondef('plainte_instruire_interne(text,text,text,text,text)'::regprocedure)")
 q.execute(definition.replace("RAISE EXCEPTION 'instruction_detention_non_confirmee';","NULL;"))
 q.execute("UPDATE personnages_donnees SET est_emprisonne='{\"detentionId\":\"historique\"}' WHERE name='Autre'");acte();r=appel()
 check(r['ok'] and not r['detention']['ok'] and lire("SELECT decouvert FROM actions_tracables WHERE id='fixture-trace'"),'contre-epreuve garde supprimee reproduit la fausse reussite')
 try:q.execute(sql);raise AssertionError('corps inconnu doit etre refuse')
 except psycopg2.Error as ex:check('definition_non_examinee' in str(ex),'migration refuse le corps modifie sans elargir empreinte')
 print(json.dumps({'assertions_enquete':n,'contre_espionnage_simule':True,'production':False}))
def tout(db,q,srv):base.suite(db,q,srv);suite(db,q,srv)
if __name__=='__main__':base.m.main(tout)
