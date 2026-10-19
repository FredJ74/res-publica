#!/usr/bin/env python3
"""Vraies migrations et verrous, aucune connexion Supabase. Identite de fixture."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import tempfile,json,subprocess

def main():
 import pgserver,psycopg2
 r=Path(__file__).resolve().parents[2];serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-membres-'),cleanup_mode='delete');uri=serveur.get_uri()
 c=psycopg2.connect(uri);c.autocommit=True;q=c.cursor()
 q.execute('CREATE ROLE anon;CREATE ROLE authenticated;CREATE TABLE organisations(id text PRIMARY KEY,data text);CREATE TABLE personnages_donnees(name text PRIMARY KEY,day integer);')
 q.execute("INSERT INTO personnages_donnees VALUES ('Alice',4),('Bob',5),('Charlie',6)")
 q.execute("CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT nullif(current_setting('hg.acteur',true),'')$$")
 q.execute((r/'migrations/20261019094425_organisations_commandes_administratives.sql').read_text())
 m=(r/'migrations/20261019130213_organisations_adhesions_grades.sql').read_text();q.execute(m);q.execute(m)
 election_sql=(r/'migrations/20261019133500_organisations_progression_elections.sql').read_text();q.execute(election_sql);q.execute(election_sql)
 regles=json.loads(subprocess.check_output(['node','-e',"console.log(JSON.stringify(require('./outils/generateurs/generer_organisations_regles.cjs').regles()))"],cwd=r))
 def acteur(nom):q.execute("SELECT set_config('hg.acteur',%s,false)",(nom,))
 def creer(id,typ='politique',pays='republic',secret=False):
  d={'id':id,'chef':'Alice','type':typ,'country_origine':pays,'membres':[{'nom':'Alice','gradeIdx':3,'grade':'Chef'}],'caisse':2050.5,'visible':not secret,'election':{'ancien':True},'inconnu':{'a':0}}
  q.execute('INSERT INTO organisations VALUES(%s,%s)',(id,json.dumps(d)))
 def lire(id):q.execute('SELECT data::jsonb FROM organisations WHERE id=%s',(id,));return q.fetchone()[0]
 def acte(id,action,params=None,key=None,cur=q):
  cur.execute('SELECT organisation_commande_membres(%s,%s,%s,%s::jsonb)',(key or 'orgcmd-'+id+'-'+action.replace('_','-'),id,action,json.dumps(params or {})));return cur.fetchone()[0]
 def refus(id,action,params=None,key=None,motif=None):
  avant=lire(id)
  try:acte(id,action,params,key);raise AssertionError('refus attendu')
  except psycopg2.Error as e:
   if motif:assert motif in str(e),str(e)
  assert lire(id)==avant
 n=0
 for type,regle in regles.items():
  for pays,grades in regle['grades'].items():
   id='test-'+type+'-'+pays;creer(id,type,pays);acteur('Bob')
   assert acte(id,'demander')['ok'];assert acte(id,'demander')['rejeu'];acteur('Alice')
   assert acte(id,'admettre',{'nom':'Bob'})['ok'];d=lire(id)
   assert d['membres'][-1]=={'nom':'Bob','grade':grades[0],'gradeIdx':0,'rejointLe':4}
   assert acte(id,'promouvoir',{'nom':'Bob'})['ok'];assert lire(id)['membres'][-1]['grade']==grades[1]
   assert acte(id,'retrograder',{'nom':'Bob'})['ok'];assert lire(id)['membres'][-1]['grade']==grades[0]
   assert lire(id)['caisse']==2050.5 and lire(id)['inconnu']=={'a':0} and lire(id)['election']=={'ancien':True};n+=1
   # Isoler chaque cas sans constituer des adhesions simultanees artificielles.
   q.execute('DELETE FROM organisations WHERE id=%s',(id,))
 creer('publique');creer('secrete',secret=True);acteur('Bob')
 refus('secrete','demander',motif='invitation_requise');n+=1
 assert acte('publique','demander')['ok'];refus('publique','demander',key='orgcmd-demande-autre',motif='demande_en_cours');n+=1
 refus('publique','admettre',{'nom':'Bob'},motif='reserve_au_chef');refus('publique','promouvoir',{'nom':'Alice'},motif='reserve_au_chef');n+=1
 refus('publique','demander',{'nom':'Charlie'},key='orgcmd-usurpation-0001',motif='champs_interdits');n+=1
 acteur('Alice');refus('publique','admettre',{'nom':'Charlie'},key='orgcmd-cible-absente',motif='demande_ou_invitation_absente');n+=1
 assert acte('publique','refuser_demande',{'nom':'Bob'})['ok'];assert lire('publique')['demandesAdhesion']==[];n+=1
 acteur('Bob');assert acte('publique','demander',key='orgcmd-demande-reprise')['ok'];acteur('Alice')
 assert acte('publique','admettre',{'nom':'Bob'},key='orgcmd-admission-valide')['ok'];n+=1
 # Pas d'ecrasement d'un credit depuis la preparation de la commande.
 q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{caisse}','4050.5')::text WHERE id='publique'")
 assert acte('publique','promouvoir',{'nom':'Bob'})['ok'];assert lire('publique')['caisse']==4050.5;n+=1
 refus('publique','promouvoir',{'nom':'Charlie'},key='orgcmd-grade-absent',motif='membre_absent');n+=1
 refus('publique','promouvoir',{'nom':'Bob'},key='orgcmd-admission-valide',motif='requete_reutilisee');n+=1
 # Invitation historique reelle, aucune auto-invitation autorisee par les parametres.
 q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{invitationsEnvoyees}','[{\"nom\":\"Bob\"},{\"nom\":\"Charlie\"}]')::text WHERE id='secrete'")
 acteur('Bob');refus('secrete','accepter_invitation',motif='limite_adhesion');n+=1
 acteur('Charlie');assert acte('secrete','accepter_invitation')['ok'];assert acte('secrete','accepter_invitation')['rejeu'];n+=1
 acteur('Bob');assert acte('secrete','refuser_invitation')['ok'];assert lire('secrete')['invitationsEnvoyees']==[];n+=1
 # Deux admissions concurrentes du meme membre vers deux structures : une seule gagne.
 creer('concurrente1','religieuse');creer('concurrente2','religieuse')
 for id in ['concurrente1','concurrente2']:q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{demandesAdhesion}','[{\"nom\":\"Charlie\"}]')::text WHERE id=%s",(id,))
 def admission(id):
  try:
   with psycopg2.connect(uri) as cc:
    with cc.cursor() as qq:
     qq.execute("SELECT set_config('hg.acteur','Alice',true)");return acte(id,'admettre',{'nom':'Charlie'},cur=qq)['ok']
  except psycopg2.Error as e:assert 'limite_adhesion' in str(e),str(e);return False
 with ThreadPoolExecutor(2) as pool:resultats=list(pool.map(admission,['concurrente1','concurrente2']))
 assert sum(resultats)==1;n+=1
 acteur('Alice');creer('rollback','syndicale');q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{demandesAdhesion}','[{\"nom\":\"Bob\"}]')::text WHERE id='rollback'")
 q.execute("CREATE FUNCTION panne() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_fixture';END$$;CREATE TRIGGER panne BEFORE INSERT ON organisation_commandes_recus FOR EACH ROW EXECUTE FUNCTION panne()")
 refus('rollback','admettre',{'nom':'Bob'},motif='panne_fixture');q.execute('DROP TRIGGER panne ON organisation_commandes_recus');n+=1
 q.execute('GRANT USAGE ON SCHEMA public TO authenticated,anon; SET ROLE authenticated')
 assert acte('rollback','admettre',{'nom':'Bob'})['ok'];q.execute('RESET ROLE;SET ROLE anon')
 try:acte('rollback','promouvoir',{'nom':'Bob'});raise AssertionError('anon interdit')
 except psycopg2.Error:pass
 q.execute('RESET ROLE');n+=1
 # Progression electorale depuis les echeances serveur, sans frais nouveaux.
 creer('election');acteur('Charlie')
 def election(candidats,votes,phase='candidatures'):
  e={'enCours':True,'phase':phase,'dateFinCandidatures':4,'dateFinVote':7,'candidats':[{'nom':nom} for nom in candidats],'votes':votes}
  q.execute("UPDATE organisations SET data=(data::jsonb||%s::jsonb)::text WHERE id='election'",(json.dumps({'chef':'Alice','membres':[{'nom':'Alice','gradeIdx':3},{'nom':'Bob','gradeIdx':0}],'election':e}),))
 election(['Bob','Alice'],{'Alice':'Bob','Bob':'Alice'})
 assert acte('election','avancer_election')['ok'];assert lire('election')['election']['phase']=='vote';assert lire('election')['chef']=='Alice';n+=1
 q.execute("UPDATE personnages_donnees SET day=7 WHERE name='Charlie'")
 assert acte('election','avancer_election',key='orgcmd-depouiller-000001')['ok'];d=lire('election')
 assert d['chef']=='Bob' and d['membres'][1]['gradeIdx']==3 and d['election']['enCours'] is False and d['election']['derniereElection']==7;n+=1
 assert acte('election','avancer_election',key='orgcmd-depouiller-000001')['rejeu'];assert lire('election')['caisse']==2050.5;n+=1
 election(['Alice','Bob'],{})
 assert acte('election','avancer_election',key='orgcmd-zero-voix-0001')['ok'];assert lire('election')['chef']=='Alice';n+=1
 election([],{})
 assert acte('election','avancer_election',key='orgcmd-zero-candidat')['ok'];assert lire('election')['chef']=='Alice';assert lire('election')['election']['enCours'] is False;n+=1
 election(['Bob'],{'Alice':'Bob'})
 q.execute("CREATE TRIGGER panne BEFORE INSERT ON organisation_commandes_recus FOR EACH ROW EXECUTE FUNCTION panne()")
 refus('election','avancer_election',key='orgcmd-election-annulee',motif='panne_fixture');assert lire('election')['election']['phase']=='candidatures';q.execute('DROP TRIGGER panne ON organisation_commandes_recus');n+=1
 refus('election','avancer_election',{'chef':'Charlie'},key='orgcmd-election-injection',motif='champs_interdits');n+=1
 print(f'{n}/{n} groupes membres SQL reussis ; aucun Supabase.')
 c.close();serveur.cleanup()
if __name__=='__main__':main()
