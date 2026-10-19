#!/usr/bin/env python3
"""SQL, payer_ordre et triggers archives reels ; identite/banque de fixture, jamais Supabase."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import tempfile,json,re

def main():
 import pgserver,psycopg2
 r=Path(__file__).resolve().parents[2];serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-evenements-'),cleanup_mode='delete');uri=serveur.get_uri()
 c=psycopg2.connect(uri);c.autocommit=True;q=c.cursor()
 q.execute('CREATE ROLE anon;CREATE ROLE authenticated;CREATE TABLE organisations(id text PRIMARY KEY,data text);CREATE TABLE personnages_donnees(name text PRIMARY KEY,country text,day integer,pa integer,liquide numeric,arg numeric);CREATE TABLE comptes_bancaires(id text,personnage text,banque text,solde numeric,updated_at timestamptz);')
 q.execute("INSERT INTO personnages_donnees VALUES ('Alice','republic',10,10,2000,2500),('Bob','republic',10,0,100,100),('Charlie','narco',10,3,0,0)")
 q.execute("CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT nullif(current_setting('hg.acteur',true),'')$$;CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$SELECT false$$;CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF $1 IS DISTINCT FROM mon_personnage() THEN RAISE EXCEPTION 'acteur_refuse'; END IF;END$$")
 def table(domaine,nom):
  s=(r/f'baseline/domaines/{domaine}/10_tables.sql').read_text();a=s.index('CREATE TABLE public.'+nom+' (');b=s.index('\n);',a)+3;q.execute(s[a:b])
 for nom in ['mails','mails_envois_systeme','forum_topics','forum_posts']:table('communication',nom)
 for nom in ['ordres_couts','ordres_couts_inconnus','ordres_couts_ecarts']:table('economie',nom)
 table('politique-et-elections','presidence_memoire_ordres')
 for nom in ['mails','forum_topics','forum_posts']:q.execute(f'ALTER TABLE {nom} ADD PRIMARY KEY(id)')
 q.execute("INSERT INTO ordres_couts VALUES ('declencher_election_club',1,0),('declencher_election_syndicat',1,0)")
 def fonction(fichier,nom):
  s=(r/fichier).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');b=s.index('$function$;',a)+len('$function$;');q.execute(s[a:b])
 fonction('baseline/domaines/economie/20_fonctions-2.sql','payer_ordre')
 for nom in ['mails_journaliser_envoi_systeme','forum_verrou_compte_rendu_journee','forum_verrou_local_territorial','forum_verrou_message_ligue','forum_verrou_programme_officiel']:
  fonction('baseline/domaines/communication/20_fonctions.sql',nom)
 q.execute("CREATE TRIGGER audit BEFORE INSERT ON mails FOR EACH ROW EXECUTE FUNCTION mails_journaliser_envoi_systeme();CREATE TRIGGER territorial BEFORE INSERT ON forum_topics FOR EACH ROW EXECUTE FUNCTION forum_verrou_local_territorial();CREATE TRIGGER compte_rendu BEFORE INSERT ON forum_topics FOR EACH ROW EXECUTE FUNCTION forum_verrou_compte_rendu_journee();CREATE TRIGGER programme BEFORE INSERT ON forum_topics FOR EACH ROW EXECUTE FUNCTION forum_verrou_programme_officiel();CREATE TRIGGER message_ligue BEFORE INSERT ON forum_posts FOR EACH ROW EXECUTE FUNCTION forum_verrou_message_ligue()")
 q.execute((r/'migrations/20261019094425_organisations_commandes_administratives.sql').read_text())
 sql=(r/'migrations/20261019132431_organisations_invitations_elections_atomiques.sql').read_text();q.execute(sql);q.execute(sql)
 def acteur(nom):q.execute("SELECT set_config('hg.acteur',%s,false)",(nom,))
 def creer(id,type='supporters',visible=True):
  q.execute('INSERT INTO organisations VALUES(%s,%s)',(id,json.dumps({'id':id,'chef':'Alice','nom':'<Club>','country_origine':'republic','type':type,'visible':visible,'caisse':1050.5,'membres':[{'nom':'Alice'},{'nom':'Bob'}]})))
 def lire(id):q.execute('SELECT data::jsonb FROM organisations WHERE id=%s',(id,));return q.fetchone()[0]
 def pa():q.execute("SELECT pa,liquide,arg FROM personnages_donnees WHERE name='Alice'");return q.fetchone()
 def compte(table):q.execute('SELECT count(*) FROM '+table);return q.fetchone()[0]
 def acte(id,action,params,key,cur=q):
  cur.execute('SELECT organisation_commande_evenement(%s,%s,%s,%s::jsonb)',(key,id,action,json.dumps(params)));return cur.fetchone()[0]
 def refus(id,action,params,key,motif):
  avant=(lire(id),pa(),compte('mails'),compte('forum_topics'),compte('forum_posts'),compte('organisation_commandes_recus'))
  try:acte(id,action,params,key);raise AssertionError('refus attendu')
  except psycopg2.Error as e:assert motif in str(e),str(e)
  assert (lire(id),pa(),compte('mails'),compte('forum_topics'),compte('forum_posts'),compte('organisation_commandes_recus'))==avant
 n=0;acteur('Alice');creer('s','criminelle',False)
 # Alice chef, Bob membre donc inviter Bob refuse ; choisir un autre citoyen.
 q.execute("INSERT INTO personnages_donnees VALUES ('Diane','republic',10,2,0,0)")
 res=acte('s','inviter',{'nom':'Diane'},'orgcmd-invitation-0001');assert res['ok'];assert compte('mails')==1 and lire('s')['invitationsEnvoyees'][0]['nom']=='Diane';n+=1
 q.execute('SELECT body,from_real,from_org_id FROM mails');body,real,org=q.fetchone();assert '&lt;Club&gt;' in body and '[[act:orga_oui|s|Alice]]' in body and real=='Alice' and org=='s';n+=1
 assert acte('s','inviter',{'nom':'Diane'},'orgcmd-invitation-0001')['rejeu'];assert compte('mails')==1;n+=1
 refus('s','inviter',{'nom':'Charlie'},'orgcmd-invitation-0001','requete_reutilisee');n+=1
 refus('s','inviter',{'nom':'Diane'},'orgcmd-invitation-0002','invitation_en_cours');n+=1
 refus('s','inviter',{'nom':'Charlie'},'orgcmd-etranger-000001','destinataire_ineligible');n+=1
 acteur('Bob');refus('s','inviter',{'nom':'Diane'},'orgcmd-non-chef-000001','reserve_au_chef');acteur('Alice');n+=1
 creer('e');avant=pa();res=acte('e','declencher_election',{'motivation':'<script>motif</script>'},'orgcmd-election-000001')
 assert res['ok'] and pa()==(avant[0]-1,avant[1],avant[2]) and compte('forum_topics')==1 and compte('forum_posts')==1;n+=1
 assert lire('e')['election']['dateFinCandidatures']==13 and lire('e')['election']['dateFinVote']==16 and lire('e')['caisse']==1050.5;n+=1
 q.execute('SELECT content FROM forum_posts');assert '&lt;script&gt;' in q.fetchone()[0];n+=1
 assert acte('e','declencher_election',{'motivation':'<script>motif</script>'},'orgcmd-election-000001')['rejeu'];assert pa()[0]==avant[0]-1;n+=1
 refus('e','declencher_election',{'motivation':'autre'},'orgcmd-election-000002','election_en_cours');n+=1
 creer('pa');acteur('Bob');rpa=acte('pa','declencher_election',{'motivation':'motif'},'orgcmd-sans-pa-00001');assert not rpa['ok'] and rpa['raison']=='pa_insuffisants' and 'election' not in lire('pa');acteur('Alice');n+=1
 creer('recent');q.execute("UPDATE organisations SET data=(data::jsonb||'{\"election\":{\"derniereElection\":5}}')::text WHERE id='recent'")
 refus('recent','declencher_election',{'motivation':'motif'},'orgcmd-recent-000001','election_trop_recente');n+=1
 creer('syndicat','syndicale');assert acte('syndicat','declencher_election',{'motivation':'motif'},'orgcmd-syndicat-00001')['ok'];n+=1
 # Toute ecriture annexe qui leve OU ignore la ligne doit annuler cout et etat.
 q.execute("CREATE FUNCTION erreur() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_fixture';END$$;CREATE FUNCTION ignorer() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RETURN NULL;END$$")
 for table in ['forum_topics','forum_posts','organisation_commandes_recus','organisations']:
  for fonction_trigger in ['erreur','ignorer']:
   id='cas'+str(n);creer(id);operation='UPDATE' if table=='organisations' else 'INSERT'
   q.execute(f'CREATE TRIGGER panne BEFORE {operation} ON {table} FOR EACH ROW EXECUTE FUNCTION {fonction_trigger}()')
   refus(id,'declencher_election',{'motivation':'motif'},'orgcmd-'+id+'-000001','panne_fixture' if fonction_trigger=='erreur' else 'non_')
   q.execute(f'DROP TRIGGER panne ON {table}');n+=1
 creer('mailannule','criminelle',False);q.execute('CREATE TRIGGER panne BEFORE INSERT ON mails FOR EACH ROW EXECUTE FUNCTION ignorer()')
 refus('mailannule','inviter',{'nom':'Diane'},'orgcmd-mail-annule-001','courrier_non_insere');q.execute('DROP TRIGGER panne ON mails');n+=1
 creer('concurrent')
 def double(i):
  with psycopg2.connect(uri) as cc:
   with cc.cursor() as qq:
    qq.execute("SELECT set_config('hg.acteur','Alice',true)");return acte('concurrent','declencher_election',{'motivation':'motif'},'orgcmd-concurrent-00001',cur=qq)
 avant=pa()[0]
 with ThreadPoolExecutor(2) as pool:res=list(pool.map(double,[0,1]))
 assert sum(bool(x.get('rejeu')) for x in res)==1 and pa()[0]==avant-1;n+=1
 print(f'{n}/{n} groupes evenements reussis ; payer_ordre et triggers archives, aucune production.')
 c.close();serveur.cleanup()
if __name__=='__main__':main()
