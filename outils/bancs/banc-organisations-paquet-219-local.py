#!/usr/bin/env python3
"""Cinq préparations ensemble, identités fictives, appels authenticated, jamais production."""
import importlib.util,json,tempfile
from pathlib import Path
R=Path(__file__).resolve().parents[2]
def charger(n,p):
 s=importlib.util.spec_from_file_location(n,R/p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m

def main():
 import pgserver,psycopg2
 from psycopg2.extras import Json
 a=charger('sources','outils/bancs/banc-audit-securite-135-local.py');base=charger('inventaire','outils/bancs/banc-inventaire-receptions-local.py');lot=charger('lotorg','outils/livraison/preparer-organisations-219.py')
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-org219-paquet-'),cleanup_mode='delete');c=psycopg2.connect(server.get_uri());c.autocommit=True;q=c.cursor();base.initialiser(q)
 q.execute('CREATE ROLE service_role;CREATE SCHEMA supabase_migrations;CREATE TABLE supabase_migrations.schema_migrations(version text PRIMARY KEY,name text,statements text[])')
 for dom,tab in [('personnage-et-presence','organisations'),('communication','mails'),('communication','mails_envois_systeme'),('communication','forum_topics'),('communication','forum_posts')]:a.creer_table(q,(R/f'baseline/domaines/{dom}/10_tables.sql').read_text(),tab)
 q.execute('ALTER TABLE organisations ADD PRIMARY KEY(id);ALTER TABLE organisations ENABLE ROW LEVEL SECURITY;ALTER TABLE mails ADD PRIMARY KEY(id);ALTER TABLE forum_topics ADD PRIMARY KEY(id);ALTER TABLE forum_posts ADD PRIMARY KEY(id)')
 for nom in ['mails_journaliser_envoi_systeme','forum_verrou_compte_rendu_journee','forum_verrou_local_territorial','forum_verrou_message_ligue','forum_verrou_programme_officiel']:q.execute(a.fonction('baseline/domaines/communication/20_fonctions.sql',nom))
 q.execute("CREATE TRIGGER audit BEFORE INSERT ON mails FOR EACH ROW EXECUTE FUNCTION mails_journaliser_envoi_systeme();CREATE TRIGGER territorial BEFORE INSERT ON forum_topics FOR EACH ROW EXECUTE FUNCTION forum_verrou_local_territorial();CREATE TRIGGER compte_rendu BEFORE INSERT ON forum_topics FOR EACH ROW EXECUTE FUNCTION forum_verrou_compte_rendu_journee();CREATE TRIGGER programme BEFORE INSERT ON forum_topics FOR EACH ROW EXECUTE FUNCTION forum_verrou_programme_officiel();CREATE TRIGGER message_ligue BEFORE INSERT ON forum_posts FOR EACH ROW EXECUTE FUNCTION forum_verrou_message_ligue()")
 q.execute(a.fonction('baseline/domaines/economie/20_fonctions-2.sql','payer_ordre'))
 q.execute("INSERT INTO ordres_couts VALUES('declencher_election_club',1,0),('declencher_election_syndicat',1,0)")
 org={'chef':'Fixture','nom':'Structure fictive','type':'criminelle','visible':False,'country_origine':'republic','city':'capitale','membres':[{'nom':'Fixture','gradeIdx':3}],'caisse':700,'inconnu':{'conserver':True}}
 q.execute('INSERT INTO organisations(id,country_origine,data) VALUES(%s,%s,%s)',('o','republic',json.dumps(org)))
 n=0
 def check(v,msg):
  nonlocal n;n+=1;assert v,msg
 def photo():
  q.execute('RESET ROLE');q.execute("SELECT jsonb_build_array((SELECT jsonb_agg(to_jsonb(p) ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(to_jsonb(o) ORDER BY id) FROM organisations o),(SELECT jsonb_agg(to_jsonb(b)) FROM comptes_bancaires b))");return q.fetchone()[0]
 avant=photo();sql=lot.preparer();echec=sql.rsplit('COMMIT;',1)[0]+"DO $$ BEGIN RAISE EXCEPTION 'panne_tardive_fixture';END $$;COMMIT;"
 try:q.execute(echec);raise AssertionError('panne ignorée')
 except psycopg2.Error as e:check('panne_tardive_fixture' in str(e),'la panne doit arriver après les cinq migrations');q.execute('ROLLBACK')
 q.execute("SELECT count(*) FROM supabase_migrations.schema_migrations");check(q.fetchone()[0]==0,'registre annulé intégralement');q.execute("SELECT to_regprocedure('public.organisation_commande_administrative(text,text,text,jsonb)')");check(q.fetchone()[0] is None,'fonction annulée');check(photo()==avant,'données préexistantes conservées après panne')
 q.execute(sql);check(photo()==avant,'installation sans toucher aux données');q.execute('SELECT count(*) FROM supabase_migrations.schema_migrations');check(q.fetchone()[0]==5,'cinq versions seulement')
 try:q.execute(sql);raise AssertionError('rejeu du lot accepté')
 except psycopg2.Error as e:check('versions_deja_presentes' in str(e),'rejeu arrêté au prévol');q.execute('ROLLBACK')
 check(photo()==avant,'prévol de rejeu sans mutation')
 c.autocommit=False
 def call(fn,action,params,key,uid='00000000-0000-4000-8000-000000000001',role='authenticated'):
  q.execute("SELECT set_config('hg.uid',%s,true),set_config('request.path',%s,true),set_config('role',%s,true)",(uid,'/rpc/'+fn,role));q.execute('SELECT public.'+fn+'(%s,%s,%s,%s)',(key,'o',action,Json(params)));return q.fetchone()[0]
 def refus(fn,action,params,key,motif,**kw):
  q.execute('RESET ROLE;SAVEPOINT refus')
  try:call(fn,action,params,key,**kw);raise AssertionError('refus absent '+motif)
  except psycopg2.Error as e:q.execute('ROLLBACK TO SAVEPOINT refus');check(motif in str(e),str(e))
  q.execute('RESET ROLE;RELEASE SAVEPOINT refus')
 fn='organisation_commande_administrative';r=call(fn,'informations',{'nom':'Nom confirmé'},'orgcmd-nom-local-0001');check(r['ok'],'commande administrative authentifiée');p=photo();r=call(fn,'informations',{'nom':'Nom confirmé'},'orgcmd-nom-local-0001');check(r['ok'] and r['rejeu'] and photo()==p,'rejeu sans mutation')
 refus(fn,'informations',{'nom':'Autre nom'},'orgcmd-nom-local-0001','requete_reutilisee');refus(fn,'informations',{'nom':'Intrus'},'orgcmd-intrus-local-001','reserve_au_chef',uid='00000000-0000-4000-8000-000000000002');refus(fn,'informations',{'nom':'Anonyme'},'orgcmd-anonyme-local-001','permission denied',role='anon')
 refus(fn,'informations',{'caisse':9000},'orgcmd-caisse-local-001','champs_interdits')
 r=call('organisation_commande_evenement','inviter',{'nom':'Autre'},'orgcmd-inviter-local-001');check(r['ok'],'invitation par le serveur');p=photo();r=call('organisation_commande_evenement','inviter',{'nom':'Autre'},'orgcmd-inviter-local-001');check(r['ok'] and r['rejeu'] and photo()==p,'invitation rejouable')
 r=call('organisation_commande_membres','accepter_invitation',{},'orgcmd-accepter-local-001',uid='00000000-0000-4000-8000-000000000002');check(r['ok'],'adhésion authentifiée par la troisième RPC')
 # Réutilisation du paiement réel protégé : coût 1 PA, aucune dépense financière.
 q.execute("RESET ROLE;UPDATE organisations SET data=jsonb_set(jsonb_set(data::jsonb,'{type}','\"supporters\"'),'{visible}','true')::text WHERE id='o'")
 avant=photo();v=call('organisation_commande_evenement','declencher_election',{'motivation':'Motif fictif'},'orgcmd-election-local-001');check(v['ok'],'élection via paiement protégé actuel')
 apres=photo();acteur_avant=next(p for p in avant[0] if p['name']=='Fixture');acteur_apres=next(p for p in apres[0] if p['name']=='Fixture');check(acteur_apres['pa']==acteur_avant['pa']-1,'un seul PA prélevé')
 for champ in ['arg','liquide','inventory','inventory_revision']:check(acteur_apres[champ]==acteur_avant[champ],'protection fiche/inventaire '+champ)
 check(apres[2]==avant[2],'comptes bancaires intacts')
 v=call('organisation_commande_evenement','declencher_election',{'motivation':'Motif fictif'},'orgcmd-election-local-001');check(v['rejeu'] and photo()==apres,'élection rejouée sans second PA')
 # Mutation du corps reconnu : refus avant écriture, pas d'élargissement implicite.
 q.execute("SELECT pg_get_functiondef('payer_ordre(text,text,integer,integer)'::regprocedure)");payeur=q.fetchone()[0];q.execute(payeur.replace('BEGIN','BEGIN\n-- mutation de contre-épreuve',1));avant=photo()
 refus('organisation_commande_evenement','declencher_election',{'motivation':'Autre'},'orgcmd-election-inconnue-001','paiement_definition_a_reexaminer');check(photo()==avant,'payeur divergent refusé sans mutation')
 q.execute(payeur)
 # Même acte après adaptation universelle des transports, sans ancienne copie du payeur.
 q.execute((R/'migrations/20261031115805_transport_encaissement_existant.sql').read_text())
 q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{election}','{}')::text WHERE id='o'")
 avant=photo();v=call('organisation_commande_evenement','declencher_election',{'motivation':'Après adaptation'},'orgcmd-election-adaptee-001');check(v['ok'],'élection avec paiement adapté #219')
 apres=photo();check(next(p for p in apres[0] if p['name']=='Fixture')['pa']==next(p for p in avant[0] if p['name']=='Fixture')['pa']-1,'un PA après adaptation')
 for sig in ['payer_ordre_interne(text,text,integer,integer)','payer_ordre_interne(text,text,integer,integer,integer)']:
  q.execute("SELECT has_function_privilege('authenticated',%s,'EXECUTE')",(sig,));check(not q.fetchone()[0],'porte de paiement interne privée')
 q.execute("SELECT pg_get_functiondef('payer_ordre_interne(text,text,integer,integer,integer)'::regprocedure)");interne=q.fetchone()[0];q.execute(interne.replace('BEGIN','BEGIN\n-- mutation interne',1));avant=photo()
 refus('organisation_commande_evenement','declencher_election',{'motivation':'Faux interne'},'orgcmd-election-interne-001','paiement_definition_a_reexaminer');check(photo()==avant,'adaptateur avec corps interne divergent refusé')
 q.execute(interne)
 q.execute('GRANT EXECUTE ON FUNCTION payer_ordre_interne(text,text,integer,integer,integer) TO authenticated');avant=photo()
 refus('organisation_commande_evenement','declencher_election',{'motivation':'ACL altérée'},'orgcmd-election-acl-001','paiement_definition_a_reexaminer');check(photo()==avant,'porte de paiement interne ouverte refusée')
 q.execute('REVOKE EXECUTE ON FUNCTION payer_ordre_interne(text,text,integer,integer,integer) FROM authenticated')
 q.execute("SELECT jsonb_build_object('org_caisse',(SELECT (data::jsonb->>'caisse')::numeric FROM organisations WHERE id='o'),'fonction_paiement_md5',(SELECT md5(prosrc) FROM pg_proc WHERE oid='payer_ordre(text,text,integer,integer)'::regprocedure))");limite=q.fetchone()[0];check(limite['org_caisse']==700,'caisse préservée')
 c.rollback();c.close();server.cleanup();print(json.dumps({'assertions':n,'ok':True,'role_actions':'authenticated','production':False,'limite':'Paiement protégé de la capture 1003 testé ; catalogue 1008 non reçu. Aucune conformité de production revendiquée.','diagnostic':limite},ensure_ascii=False,indent=2))
if __name__=='__main__':main()
