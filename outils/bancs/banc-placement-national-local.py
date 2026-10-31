#!/usr/bin/env python3
"""Preuve transactionnelle locale de la RPC placements nationale, sans comptes joueurs."""
from pathlib import Path
import tempfile, uuid
from concurrent.futures import ThreadPoolExecutor

def main():
 import pgserver, psycopg2
 root=Path(__file__).resolve().parents[2]
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-placement-'),cleanup_mode='delete')
 db=psycopg2.connect(serveur.get_uri())
 db.autocommit=True
 q=db.cursor()
 q.execute("""CREATE ROLE anon; CREATE ROLE authenticated;
 CREATE TABLE public.personnages_donnees (
   name text primary key, country text, liquide integer, arg integer, updated_at timestamptz);
 CREATE TABLE public.comptes_bancaires (
   id text primary key, personnage text, pays text, banque text, solde numeric NOT NULL, updated_at timestamptz);
 CREATE TABLE public.placements_bancaires (
   id text primary key, personnage text, pays text, ville text,
   banque text, type text, libelle text, montant numeric NOT NULL,
   visible_fiscalement boolean, date_placement timestamptz,
   prochaine_echeance timestamptz, statut text, int_snapshot integer,
   source_fonds text);
 CREATE FUNCTION public.exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$
 BEGIN IF $1 IS DISTINCT FROM current_setting('hg.acteur',true)
 THEN RAISE EXCEPTION 'acteur_refuse'; END IF; END $$;
 INSERT INTO personnages_donnees VALUES ('Alice','republic',800,1800,now()),('Bob','republic',700,700,now()),('Charlie','republic',800,800,now());
 INSERT INTO comptes_bancaires VALUES('a','Alice','republic','nationale',1000,now());""")
 sql=(root/'migrations/20261031113625_placement_national_idempotent.sql').read_text()
 q.execute(sql)
 q.execute("select set_config('hg.acteur','Alice',false)")
 def faire(ident, montant=500, source='liquide', acteur='Alice', ville='capitale'):
  q.execute('select (public.creer_placement_national_securise(%s,%s,%s,%s,%s,%s)).id',
    (acteur,montant,6,ville,source,str(ident)))
  return q.fetchone()[0]
 def stats():
  q.execute("select liquide from personnages_donnees where name='Alice'");a=q.fetchone()[0]
  q.execute("select solde from comptes_bancaires where personnage='Alice'");b=q.fetchone()[0]
  q.execute("select count(*) from placements_bancaires where personnage='Alice'");c=q.fetchone()[0]
  return a,b,c
 i=uuid.uuid4(); original=faire(i)
 assert stats()==(300,1000,1), stats()
 assert faire(i)==original and stats()==(300,1000,1)
 try:faire(i,montant=600);raise AssertionError('rejeu avec autre montant accepté')
 except psycopg2.Error as e:assert 'Intention deja utilisee' in str(e)
 assert stats()==(300,1000,1)
 j=uuid.uuid4();faire(j,source='nationale');assert stats()==(300,500,2)
 k=uuid.uuid4();faire(k,source='nationale');assert stats()==(300,0,3)
 try:faire(uuid.uuid4(),source='nationale');raise AssertionError('solde débiteur accepté')
 except psycopg2.Error as e:assert 'insuffisant' in str(e)
 assert stats()==(300,0,3)
 try:faire(uuid.uuid4(),acteur='Bob');raise AssertionError('identité acceptée')
 except psycopg2.Error as e:assert 'acteur_refuse' in str(e)
 assert stats()==(300,0,3)
 # Deux requêtes concurrentes portant la meme intention doivent retourner UNE seule ligne.
 ident = str(uuid.uuid4())
 def concurrent():
  cx=psycopg2.connect(serveur.get_uri());cx.autocommit=True
  with cx.cursor() as c:
   c.execute("select set_config('hg.acteur','Charlie',false)")
   c.execute('select (public.creer_placement_national_securise(%s,%s,%s,%s,%s,%s)).id',
             ('Charlie',500,6,'capitale','liquide',ident))
   resultat=c.fetchone()[0]
  cx.close();return resultat
 with ThreadPoolExecutor(max_workers=2) as pool:
  a,b=list(pool.map(lambda _:concurrent(),range(2)))
 assert a==b
 q.execute("select liquide from personnages_donnees where name='Charlie'");assert q.fetchone()[0]==300
 q.execute("select count(*) from placements_bancaires where personnage='Charlie'");assert q.fetchone()[0]==1
 print('OK placements nationaux : espèces, compte, 3 actifs, rejeu, concurrence, erreurs et identité')
 db.close()  # pgserver gere le processus avec cleanup_mode=delete

if __name__=='__main__':main()
