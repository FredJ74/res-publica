#!/usr/bin/env python3
"""Contrat administratif reel, PostgreSQL jetable, identite JWT de fixture."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import tempfile,json

def main():
 import pgserver,psycopg2
 root=Path(__file__).resolve().parents[2]
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-orgcmd-'),cleanup_mode='delete')
 uri=serveur.get_uri();c=psycopg2.connect(uri);c.autocommit=True;q=c.cursor()
 q.execute('CREATE ROLE anon; CREATE ROLE authenticated; CREATE TABLE organisations(id text PRIMARY KEY,data text);')
 q.execute("CREATE TABLE personnages_donnees(name text PRIMARY KEY,day integer);INSERT INTO personnages_donnees VALUES ('Alice',2),('Bob',2),('Charlie',2)")
 q.execute("CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$ SELECT nullif(current_setting('hg.acteur',true),'') $$")
 migration=(root/'migrations/20261019094425_organisations_commandes_administratives.sql').read_text()
 q.execute(migration);q.execute(migration)
 initial={'chef':'Alice','type':'criminelle','caisse':100.5,'election':{'votes':{'Bob':'Alice'}},'membres':[{'nom':'Alice'},{'nom':'Bob'},{'nom':'Charlie'}],'inconnu':{'ancien':True}}
 q.execute('INSERT INTO organisations VALUES (%s,%s)',('o',json.dumps(initial)))
 q.execute("SELECT set_config('hg.acteur','Alice',false)")
 def lire():
  q.execute("SELECT data::jsonb FROM organisations WHERE id='o'");return q.fetchone()[0]
 def acte(action,params=None,key=None,cur=q):
  cur.execute('SELECT organisation_commande_administrative(%s,%s,%s,%s::jsonb)',(key or 'orgcmd-'+action.replace('_','-')+'-000001','o',action,json.dumps(params or {})));return cur.fetchone()[0]
 def refus(action,params=None,key=None,motif=None):
  avant=lire()
  try:acte(action,params,key);raise AssertionError('refus attendu')
  except psycopg2.Error as e:
   if motif:assert motif in str(e),str(e)
  assert lire()==avant
 n=0
 assert acte('informations',{'nom':'Nouveau','devise':'D'})['ok'];n+=1
 assert lire()['caisse']==100.5 and lire()['election']==initial['election'] and lire()['inconnu']==initial['inconnu'];n+=1
 # Un credit serveur plus recent reste intact lors du rejeu et d'une autre information.
 q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{caisse}','2100.5')::text")
 assert acte('informations',{'nom':'Nouveau','devise':'D'})['rejeu'];assert lire()['caisse']==2100.5;n+=1
 assert acte('informations',{'avatar':'https://example.test/a'},'orgcmd-avatar-000001')['ok'];assert lire()['caisse']==2100.5;n+=1
 refus('informations',{'nom':'Autre'},'orgcmd-informations-000001','requete_reutilisee');n+=1
 for champs in [{'caisse':0},{'chef':'Bob'},{'membres':[]},{'nom':None},{'nom':'x'}]:refus('informations',champs,key='orgcmd-invalide-000001');n+=1
 q.execute("SELECT set_config('hg.acteur','Bob',false)")
 refus('informations',{'nom':'Pirate'},key='orgcmd-pirate-000001',motif='reserve_au_chef');refus('nommer_tresorier',{'nom':'Charlie'},motif='reserve_au_chef');n+=1
 refus('informations',{'nom':'Nouveau','devise':'D'},motif='requete_reutilisee');n+=1
 refus('exclure',{'nom':'Charlie'},motif='membre_non_autorise');n+=1
 q.execute("SELECT set_config('hg.acteur','Alice',false)")
 assert acte('nommer_tresorier',{'nom':' Bob '})['ok'] and lire()['tresorier']=='Bob';n+=1
 refus('nommer_tresorier',{'nom':'Alice'},'orgcmd-chef-000001','chef_deja_gestionnaire');n+=1
 refus('nommer_tresorier',{'nom':'Intrus'},'orgcmd-intrus-000001','pas_membre');n+=1
 assert acte('revoquer_tresorier')['ok'] and lire()['tresorierPrecedent']=='Bob' and lire()['tresorier'] is None;n+=1
 assert acte('visibilite',{'visible':False})['ok'] and lire()['visible'] is False;n+=1
 refus('visibilite',{'visible':True,'caisse':0},'orgcmd-visible-000002');n+=1
 refus('quitter',{'nom':'Alice'},motif='direction_a_transmettre');n+=1
 q.execute("SELECT set_config('hg.acteur','Charlie',false)")
 refus('quitter',{'nom':'Bob'},motif='membre_non_autorise');assert acte('quitter',{'nom':'Charlie'})['ok'];n+=1
 q.execute("SELECT set_config('hg.acteur','Alice',false)")
 # Les erreurs tardives du registre annulent aussi la modification.
 q.execute("CREATE FUNCTION panne() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_fixture';END$$;CREATE TRIGGER panne BEFORE INSERT ON organisation_commandes_recus FOR EACH ROW EXECUTE FUNCTION panne()")
 refus('informations',{'nom':'Annule'},'orgcmd-panne-000001','panne_fixture');q.execute('DROP TRIGGER panne ON organisation_commandes_recus');n+=1
 def concurrent(i):
  with psycopg2.connect(uri) as c2:
   with c2.cursor() as q2:
    q2.execute("SELECT set_config('hg.acteur','Alice',true)")
    return acte('informations',{'devise':'Concurrent'},'orgcmd-concurrent-000001',cur=q2)
 with ThreadPoolExecutor(2) as pool:r=list(pool.map(concurrent,range(2)))
 assert all(x['ok'] for x in r) and sum(bool(x.get('rejeu')) for x in r)==1;n+=1
 q.execute("GRANT USAGE ON SCHEMA public TO authenticated,anon; SET ROLE authenticated")
 assert acte('informations',{'devise':'Autorise'},'orgcmd-authentifie-000001')['ok'];n+=1
 try:q.execute('SELECT * FROM organisation_commandes_recus');raise AssertionError('registre prive')
 except psycopg2.Error:pass
 q.execute('RESET ROLE; SET ROLE anon')
 try:acte('informations',{'nom':'Anonyme'});raise AssertionError('appel anon')
 except psycopg2.Error:pass
 q.execute('RESET ROLE');n+=1
 assert lire()['caisse']==2100.5 and lire()['election']==initial['election'];n+=1
 # Candidatures et votes : acteur/jour exclusivement depuis le serveur.
 election={'enCours':True,'phase':'candidatures','dateFinCandidatures':4,'dateFinVote':7,'candidats':[],'votes':{}}
 q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{election}',%s::jsonb)::text",(json.dumps(election),))
 assert acte('candidature')['ok'];assert acte('candidature')['rejeu'];n+=1
 refus('candidature',{},'orgcmd-candidature-000002','deja_candidat');n+=1
 q.execute("SELECT set_config('hg.acteur','Charlie',false)")
 refus('candidature',{},'orgcmd-charlie-000001','reserve_aux_membres');n+=1
 q.execute("SELECT set_config('hg.acteur','Bob',false)")
 assert acte('candidature',{},'orgcmd-bob-candidat-000001')['ok'];n+=1
 refus('vote',{'nom':'Alice'},'orgcmd-bob-vote-000001','vote_ferme');n+=1
 q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{election,phase}','\"vote\"')::text;UPDATE personnages_donnees SET day=4")
 refus('vote',{'nom':'Intrus'},'orgcmd-bob-vote-000001','candidat_absent');n+=1
 refus('vote',{'nom':'Alice','acteur':'Alice'},'orgcmd-bob-vote-000001','candidat_requis');n+=1
 def voter(nom):
  with psycopg2.connect(uri) as c2:
   with c2.cursor() as q2:
    q2.execute("SELECT set_config('hg.acteur',%s,true)",(nom,))
    return acte('vote',{'nom':nom},'orgcmd-vote-'+nom+'-000001',cur=q2)
 with ThreadPoolExecutor(2) as pool:r=list(pool.map(voter,['Alice','Bob']))
 assert all(x['ok'] for x in r) and lire()['election']['votes']=={'Alice':'Alice','Bob':'Bob'};n+=1
 q.execute("UPDATE personnages_donnees SET day=7")
 refus('vote',{'nom':'Alice'},'orgcmd-fin-vote-000001','vote_ferme');n+=1
 q.execute("SELECT set_config('hg.acteur','Alice',false)")
 q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{election}',%s::jsonb)::text",(json.dumps(initial['election']),))
 assert lire()['caisse']==2100.5;n+=1
 # Dissolution reservee au chef, puis rejeu possible apres disparition de la ligne.
 q.execute("SELECT set_config('hg.acteur','Bob',false)");refus('dissoudre',motif='reserve_au_chef');n+=1
 q.execute("SELECT set_config('hg.acteur','Alice',false)")
 assert acte('dissoudre')['dissoute']=='o';assert acte('dissoudre')['rejeu'];n+=1
 q.execute("SELECT count(*) FROM organisations");assert q.fetchone()[0]==0;n+=1
 # Une definition ou un registre inconnus ne sont jamais ecrases.
 q.execute("SELECT pg_get_functiondef('organisation_commande_administrative(text,text,text,jsonb)'::regprocedure)")
 definition=q.fetchone()[0];q.execute(definition.replace('BEGIN','BEGIN\n-- source inconnue',1))
 try:q.execute(migration);raise AssertionError('garde source attendue')
 except psycopg2.Error as e:assert 'definition_a_reexaminer' in str(e),str(e)
 q.execute('ROLLBACK');q.execute(definition);n+=1
 q.execute("COMMENT ON TABLE organisation_commandes_recus IS 'inconnu'")
 try:q.execute(migration);raise AssertionError('garde registre attendue')
 except psycopg2.Error as e:assert 'registre_commandes_inconnu' in str(e),str(e)
 q.execute('ROLLBACK');q.execute("COMMENT ON TABLE organisation_commandes_recus IS 'HG commandes administratives v1'");n+=1
 print(f'{n}/{n} groupes administratifs SQL reussis ; aucun Supabase, identite de fixture.')
 c.close();serveur.cleanup()
if __name__=='__main__':main()
